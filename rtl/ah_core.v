// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
`include "ah_defines.vh"
//
// ah_core : 5-stage pipelined RV64I core  (IF -> ID -> EX -> MEM -> WB).
// Includes a forwarding unit, a load-use hazard stall, and branch/jump flush.
// Same port interface as the single-cycle version, so ah_top is unchanged.
// ebreak/ecall stop fetching and the core halts once it drains.
//
module ah_core (
    input         clk,
    input         rst,
    output [63:0] pc_out,
    output        halted_out,
    output [63:0] dbg_result,
    input  [4:0]  dbg_regsel,
    output [63:0] dbg_regval,
    output [63:0] sig_out,
    // memory-mapped store bus (MEM stage) for external peripherals
    // e.g. the video framebuffer. Mirrors what feeds the data memory.
    output [63:0] o_mem_addr,
    output [63:0] o_mem_wdata,
    output [2:0]  o_mem_funct3,
    output        o_mem_write,
    output        o_mem_read,         // load in progress (MEM stage)
    input  [63:0] i_mmio_rdata,       // data for loads from the MMIO region
    input         i_mtip              // machine timer interrupt pending (CLINT)
);
    localparam [31:0] NOP = 32'h00000013;   // addi x0,x0,0

    // ================= IF (synchronous instruction memory) ============
    reg  [63:0] pc;
    wire [31:0] if_instr;                 // imem output: valid one cycle after addr
    ah_imem u_imem (.clk(clk), .addr(pc), .instr(if_instr));

    // ===================== IF/ID ======================
    reg [63:0] ifid_pc;
    reg        ifid_bubble;               // 1 => the ID slot is a flushed/invalid bubble
    reg        hold_valid;                // skid buffer occupied (held across a stall)
    reg [31:0] hold_instr;
    // Instruction presented to ID: a bubble reads as NOP; otherwise the held
    // instruction (during a stall) or the fresh memory output.
    wire [31:0] id_instr = ifid_bubble ? NOP : (hold_valid ? hold_instr : if_instr);

    // ======================= ID =======================
    wire [6:0] id_opcode = id_instr[6:0];
    wire [4:0] id_rd     = id_instr[11:7];
    wire [2:0] id_funct3 = id_instr[14:12];
    wire [4:0] id_rs1    = id_instr[19:15];
    wire [4:0] id_rs2    = id_instr[24:20];
    // ---- SYSTEM instruction sub-decode (ecall / ebreak / mret / CSR ops) ----
    wire        id_is_sys  = (id_opcode == `OPC_SYSTEM);
    wire [11:0] id_funct12 = id_instr[31:20];
    wire        id_csr     = id_is_sys && (id_funct3 != 3'b000);   // csrr*/csrw*
    wire        id_priv    = id_is_sys && (id_funct3 == 3'b000);
    wire        id_ecall   = id_priv && (id_funct12 == 12'h000);
    wire        id_ebreak  = id_priv && (id_funct12 == 12'h001);
    wire        id_mret    = id_priv && (id_funct12 == 12'h302);
    wire [11:0] id_csr_addr= id_instr[31:20];
    wire [1:0]  id_csr_cmd = id_funct3[1:0];     // 01=write 10=set 11=clear
    wire        id_csr_imm = id_funct3[2];       // immediate form (zimm in rs1 field)

    wire [3:0] id_aluctrl;
    wire       id_aluword, id_alusrcb, id_regwrite, id_memread, id_memwrite;
    wire       id_branch, id_jump, id_jalr, id_halt;
    wire [2:0] id_wbsel;
    ah_control u_ctrl (
        .opcode(id_opcode), .funct3(id_funct3), .instr30(id_instr[30]),
        .alu_ctrl(id_aluctrl), .alu_word(id_aluword), .alu_src_b(id_alusrcb),
        .reg_write(id_regwrite), .mem_read(id_memread), .mem_write(id_memwrite),
        .branch(id_branch), .jump(id_jump), .jalr(id_jalr), .halt(id_halt),
        .wb_sel(id_wbsel)
    );

    wire [63:0] id_imm;
    ah_imm_gen u_imm (.instr(id_instr), .imm(id_imm));

    // a CSR instruction writes rd (with the old CSR value) -> regwrite + WB_CSR
    wire        id_regwrite_eff = id_regwrite | id_csr | id_is_amo;
    wire [2:0]  id_wbsel_eff    = id_csr ? `WB_CSR : id_wbsel;
    // ---- M extension (mul/div) sub-decode: R-type OP/OP-32 with funct7=0000001 ----
    wire        id_is_muldiv = ((id_opcode==`OPC_OP) || (id_opcode==`OPC_OP32))
                              && (id_instr[31:25] == 7'b0000001);
    wire        id_md_word   = (id_opcode == `OPC_OP32);
    // ---- A extension (atomics) sub-decode ----
    wire        id_is_amo   = (id_opcode == `OPC_AMO);
    wire [4:0]  id_amo_f5   = id_instr[31:27];
    wire        id_amo_word = (id_funct3 == 3'b010);   // .w (vs .d = 011)

    // register file (write in WB) + WB->ID bypass
    wire [63:0] rf_rs1, rf_rs2, wb_data;
    reg  [4:0]  memwb_rd; reg memwb_we;     // declared early for bypass
    ah_regfile u_rf (
        .clk(clk), .rs1(id_rs1), .rs2(id_rs2), .rd(memwb_rd),
        .rd_data(wb_data), .reg_write(memwb_we),
        .rs1_data(rf_rs1), .rs2_data(rf_rs2),
        .dbg_addr(dbg_regsel), .dbg_data(dbg_regval)
    );
    wire [63:0] id_rs1d = (memwb_we && memwb_rd != 0 && memwb_rd == id_rs1) ? wb_data : rf_rs1;
    wire [63:0] id_rs2d = (memwb_we && memwb_rd != 0 && memwb_rd == id_rs2) ? wb_data : rf_rs2;

    // ===================== ID/EX ======================
    reg [63:0] idex_pc, idex_rs1d, idex_rs2d, idex_imm;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg [2:0]  idex_funct3, idex_wbsel;
    reg [3:0]  idex_aluctrl;
    reg        idex_aluword, idex_alusrcb, idex_regwrite, idex_memread, idex_memwrite;
    reg        idex_branch, idex_jump, idex_jalr, idex_ebreak;
    reg        idex_valid;                          // 1 = real instruction (not a bubble)
    reg        idex_csr, idex_ecall, idex_mret, idex_csr_imm;
    reg [11:0] idex_csr_addr;
    reg [1:0]  idex_csr_cmd;
    reg        idex_is_muldiv, idex_md_word;
    reg        idex_is_amo, idex_amo_word;
    reg [4:0]  idex_amo_f5;

    // ======================= EX =======================
    reg  [4:0] exmem_rd; reg exmem_we, exmem_is_load;
    reg [63:0] exmem_result;
    wire [1:0] fwdA, fwdB;
    ah_forward u_fwd (
        .idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
        .exmem_rd(exmem_rd), .exmem_we(exmem_we), .exmem_is_load(exmem_is_load),
        .memwb_rd(memwb_rd), .memwb_we(memwb_we), .fwdA(fwdA), .fwdB(fwdB)
    );

    reg [63:0] memwb_result;   // forward source from MEM/WB (declared early)
    wire [63:0] ex_a   = (fwdA == 2'b10) ? exmem_result :
                         (fwdA == 2'b01) ? memwb_result : idex_rs1d;
    wire [63:0] ex_rs2 = (fwdB == 2'b10) ? exmem_result :
                         (fwdB == 2'b01) ? memwb_result : idex_rs2d;
    wire [63:0] ex_b   = idex_alusrcb ? idex_imm : ex_rs2;

    wire [63:0] alu_y;
    ah_alu u_alu (.alu_ctrl(idex_aluctrl), .word(idex_aluword), .a(ex_a), .b(ex_b), .y(alu_y));

    // ---- M extension: sequential multiply/divide, holds the op in EX while it runs ----
    wire        md_active = idex_is_muldiv & idex_valid;
    reg         md_started;
    wire        md_busy;
    wire [63:0] md_result;
    wire        md_start = md_active & ~md_started;
    wire        md_stall = md_active & (md_start | md_busy) & ~ex_trap;
    ah_muldiv u_md (.clk(clk), .rst(rst), .start(md_start), .funct3(idex_funct3),
                    .word(idex_md_word), .a(ex_a), .b(ex_rs2), .busy(md_busy), .result(md_result));

    // ---- A extension: atomics (lr / sc / amo*) via a read-modify-write FSM ----
    // The op is held in EX while a small state machine drives the data memory:
    // read the word, compute, write it back. Single hart, so read-then-write is
    // atomic with respect to anything else (interrupts are taken between ops).
    wire        amo_active = idex_is_amo & idex_valid;
    wire        amo_is_lr  = (idex_amo_f5 == 5'b00010);
    wire        amo_is_sc  = (idex_amo_f5 == 5'b00011);
    wire        amo_w      = idex_amo_word;
    wire [63:0] mem_load;                          // data-memory read (driven below)
    wire [63:0] amo_old_c  = mem_load;             // freshly-read word (sign-ext for .w)
    wire [63:0] amo_src    = amo_w ? {{32{ex_rs2[31]}}, ex_rs2[31:0]} : ex_rs2;
    wire [63:0] amo_old_u  = amo_w ? {32'd0, amo_old_c[31:0]} : amo_old_c;
    wire [63:0] amo_src_u  = amo_w ? {32'd0, ex_rs2[31:0]}    : ex_rs2;
    reg  [63:0] amo_newval;
    always @(*) begin
        case (idex_amo_f5)
            5'b00001: amo_newval = amo_src;                                            // swap
            5'b00000: amo_newval = amo_old_c + amo_src;                                // add
            5'b00100: amo_newval = amo_old_c ^ amo_src;                                // xor
            5'b01100: amo_newval = amo_old_c & amo_src;                                // and
            5'b01000: amo_newval = amo_old_c | amo_src;                                // or
            5'b10000: amo_newval = ($signed(amo_old_c) < $signed(amo_src)) ? amo_old_c : amo_src; // min
            5'b10100: amo_newval = ($signed(amo_old_c) < $signed(amo_src)) ? amo_src : amo_old_c; // max
            5'b11000: amo_newval = (amo_old_u < amo_src_u) ? amo_old_c : amo_src;      // minu
            5'b11100: amo_newval = (amo_old_u < amo_src_u) ? amo_src : amo_old_c;      // maxu
            default:  amo_newval = amo_src;
        endcase
    end
    localparam AMO_IDLE=2'd0, AMO_RD=2'd1, AMO_WR=2'd2, AMO_FIN=2'd3;
    reg [1:0]  amo_state;
    reg [63:0] amo_addr, amo_result, resv_addr;
    reg        resv_valid;
    wire       sc_hit = resv_valid & (resv_addr == ex_a);
    wire [2:0] amo_f3 = amo_w ? 3'b010 : 3'b011;
    wire amo_do_read  = amo_active & (amo_state==AMO_IDLE) & ~amo_is_sc;            // lr / amo read
    wire amo_do_write = (amo_active & (amo_state==AMO_RD)   & ~amo_is_lr) |         // amo write-back
                        (amo_active & (amo_state==AMO_IDLE) & amo_is_sc & sc_hit);  // sc store
    wire [63:0] amo_addr_c  = (amo_state==AMO_IDLE) ? ex_a : amo_addr;
    wire [63:0] amo_wdata_c = amo_is_sc ? ex_rs2 : amo_newval;
    wire        amo_done    = amo_active & ((amo_state==AMO_WR) | (amo_state==AMO_FIN));
    wire        amo_stall   = amo_active & ~amo_done & ~ex_trap;
    wire        ex_busy_stall = md_stall | amo_stall;

    // branch comparison (forwarded operands)
    reg ex_take;
    always @(*) begin
        case (idex_funct3)
            3'b000: ex_take = (ex_a == ex_rs2);
            3'b001: ex_take = (ex_a != ex_rs2);
            3'b100: ex_take = ($signed(ex_a) <  $signed(ex_rs2));
            3'b101: ex_take = ($signed(ex_a) >= $signed(ex_rs2));
            3'b110: ex_take = (ex_a <  ex_rs2);
            3'b111: ex_take = (ex_a >= ex_rs2);
            default: ex_take = 1'b0;
        endcase
    end
    wire ex_br_redirect = (idex_branch & ex_take) | idex_jump;
    wire [63:0] ex_target = idex_jalr ? ((ex_a + idex_imm) & ~64'd1) : (idex_pc + idex_imm);

    // ---------------- CSRs + traps ----------------
    wire [63:0] csr_rdata, mtvec_o, mepc_o;
    wire        irq_timer;
    // operand for set/clear/write: register rs1 (forwarded) or the 5-bit zimm
    wire [63:0] csr_operand = idex_csr_imm ? {59'd0, idex_rs1} : ex_a;
    wire [63:0] csr_new = (idex_csr_cmd==2'b01) ? csr_operand :
                          (idex_csr_cmd==2'b10) ? (csr_rdata | csr_operand) :
                                                  (csr_rdata & ~csr_operand);
    wire ex_is_ecall = idex_ecall & idex_valid;
    wire ex_is_mret  = idex_mret  & idex_valid;
    // a timer interrupt is taken on the valid instruction in EX (re-run later);
    // it does not pre-empt an ecall or mret instruction.
    wire ex_take_irq = irq_timer & idex_valid & ~ex_is_ecall & ~ex_is_mret;
    wire ex_trap     = ex_take_irq | ex_is_ecall;
    wire ex_mret_go  = ex_is_mret;
    wire [63:0] trap_cause = ex_take_irq ? {1'b1, 63'd7} : 64'd11;  // m-timer irq : ecall-from-M
    wire        csr_we = idex_csr & idex_valid & ~ex_trap;          // squashed instr doesn't write

    ah_csr u_csr (
        .clk(clk), .rst(rst),
        .raddr(idex_csr_addr), .rdata(csr_rdata),
        .we(csr_we), .waddr(idex_csr_addr), .wdata(csr_new),
        .trap_set(ex_trap), .trap_epc(idex_pc), .trap_cause(trap_cause),
        .mret_set(ex_mret_go), .i_mtip(i_mtip),
        .mtvec_o(mtvec_o), .mepc_o(mepc_o), .irq_timer(irq_timer)
    );

    // unified redirect: trap (-> mtvec) > mret (-> mepc) > branch/jump
    wire        ex_redirect_any = ex_trap | ex_mret_go | ex_br_redirect;
    wire [63:0] ex_redirect_tgt = ex_trap   ? mtvec_o :
                                  ex_mret_go ? mepc_o  : ex_target;

    reg [63:0] ex_result;
    always @(*) begin
        if      (idex_is_muldiv) ex_result = md_result;   // M-extension result
        else if (idex_is_amo)    ex_result = amo_result;  // A-extension result (rd)
        else case (idex_wbsel)
            `WB_PC4  : ex_result = idex_pc + 64'd4;
            `WB_IMM  : ex_result = idex_imm;
            `WB_PCIMM: ex_result = idex_pc + idex_imm;
            `WB_CSR  : ex_result = csr_rdata;
            default  : ex_result = alu_y;     // WB_ALU / WB_MEM(placeholder)
        endcase
    end

    // ===================== EX/MEM =====================
    reg [63:0] exmem_addr, exmem_store;
    reg [2:0]  exmem_funct3, exmem_wbsel;
    reg        exmem_memread, exmem_memwrite, exmem_ebreak;

    // ======================= MEM ======================
    // The data memory is fed from the EX stage (address = ALU result) so its
    // registered read data is valid in MEM. Writes go to RAM only (MMIO stores
    // leave via o_mem_*); a trapped store is squashed.
    wire        ex_is_mmio = (alu_y[31:28] == 4'h1);
    wire        dmem_we_n = idex_memwrite & idex_valid & ~ex_is_mmio & ~ex_trap;
    wire        dmem_re_n = idex_memread  & idex_valid;
    wire        dmem_amo  = amo_do_read | amo_do_write;
    ah_dmem u_dmem (
        .clk(clk),
        .addr   ( dmem_amo ? amo_addr_c  : alu_y ),
        .wdata  ( dmem_amo ? amo_wdata_c : ex_rs2 ),
        .funct3 ( dmem_amo ? amo_f3      : idex_funct3 ),
        .mem_read ( dmem_re_n | amo_do_read ),
        .mem_write( dmem_we_n | amo_do_write ),
        .rdata(mem_load)
    );
    // loads from the MMIO region (0x1000_0000..0x1FFF_FFFF) take their data
    // from the external peripheral bus instead of the data memory.
    wire        exmem_is_mmio = (exmem_addr[31:28] == 4'h1);
    wire [63:0] load_data     = exmem_is_mmio ? i_mmio_rdata : mem_load;
    wire [63:0] mem_result    = exmem_is_load ? load_data : exmem_result;

    // expose the MEM-stage memory interface for memory-mapped peripherals
    assign o_mem_addr   = exmem_addr;
    assign o_mem_wdata  = exmem_store;
    assign o_mem_funct3 = exmem_funct3;
    assign o_mem_write  = exmem_memwrite;
    assign o_mem_read   = exmem_memread;

    // ===================== MEM/WB =====================
    reg memwb_ebreak;
    assign wb_data    = memwb_result;
    assign dbg_result = memwb_result;

    // ================= hazards / control ==============
    wire stall;
    ah_hazard u_haz (
        .idex_memread(idex_memread), .idex_rd(idex_rd),
        .ifid_rs1(id_rs1), .ifid_rs2(id_rs2), .stall(stall)
    );
    reg halted, stop_fetch;
    wire fetch_off = stop_fetch | id_ebreak;
    assign pc_out     = pc;
    assign halted_out = halted;

    // ================= pipeline registers =============
    integer dummy;
    always @(posedge clk) begin
        if (rst) begin
            pc <= 64'd0; halted <= 1'b0; stop_fetch <= 1'b0;
            ifid_pc <= 0; ifid_bubble <= 1'b1; hold_valid <= 0; hold_instr <= NOP;
            idex_regwrite<=0; idex_memread<=0; idex_memwrite<=0;
            idex_branch<=0; idex_jump<=0; idex_jalr<=0; idex_ebreak<=0;
            idex_rd<=0; idex_wbsel<=0;
            idex_valid<=0; idex_csr<=0; idex_ecall<=0; idex_mret<=0;
            idex_is_muldiv<=0; md_started<=0;
            idex_is_amo<=0; amo_state<=AMO_IDLE; resv_valid<=0;
            exmem_we<=0; exmem_memread<=0; exmem_memwrite<=0; exmem_is_load<=0;
            exmem_rd<=0; exmem_ebreak<=0; exmem_wbsel<=0;
            memwb_we<=0; memwb_rd<=0; memwb_ebreak<=0; memwb_result<=0;
        end else begin
            // ---- IF / IFID (synchronous fetch) ----
            // The instruction memory is registered, so the word arriving in ID
            // belongs to the address presented last cycle. A redirect therefore
            // leaves one extra wrong-path slot to flush (ifid_bubble); a stall
            // parks the current instruction in the skid buffer (hold_*).
            if (ex_redirect_any) begin
                pc <= ex_redirect_tgt; ifid_pc <= pc; ifid_bubble <= 1'b1; hold_valid <= 0;
            end else if (stall || ex_busy_stall) begin
                pc <= pc; ifid_pc <= ifid_pc; ifid_bubble <= ifid_bubble;
                if (!hold_valid) hold_instr <= if_instr;   // park the held instruction
                hold_valid <= 1'b1;
            end else if (fetch_off) begin
                pc <= pc; ifid_pc <= pc; ifid_bubble <= 1'b1; hold_valid <= 0;
            end else begin
                pc <= pc + 64'd4; ifid_pc <= pc; ifid_bubble <= 1'b0; hold_valid <= 0;
            end

            // ---- IDEX ----
            if (ex_busy_stall) begin
                // hold the multi-cycle op (muldiv or atomic) in EX until it finishes
            end else if (ex_redirect_any || stall || ifid_bubble) begin   // insert bubble
                idex_regwrite<=0; idex_memread<=0; idex_memwrite<=0;
                idex_branch<=0; idex_jump<=0; idex_jalr<=0; idex_ebreak<=0;
                idex_rd<=0; idex_wbsel<=0;
                idex_valid<=0; idex_csr<=0; idex_ecall<=0; idex_mret<=0;
                idex_is_muldiv<=0; idex_is_amo<=0;
            end else begin
                idex_pc<=ifid_pc; idex_rs1d<=id_rs1d; idex_rs2d<=id_rs2d; idex_imm<=id_imm;
                idex_rs1<=id_rs1; idex_rs2<=id_rs2; idex_rd<=id_rd; idex_funct3<=id_funct3;
                idex_aluctrl<=id_aluctrl; idex_aluword<=id_aluword; idex_alusrcb<=id_alusrcb;
                idex_regwrite<=id_regwrite_eff; idex_memread<=id_memread; idex_memwrite<=id_memwrite;
                idex_branch<=id_branch; idex_jump<=id_jump; idex_jalr<=id_jalr;
                idex_wbsel<=id_wbsel_eff; idex_ebreak<=id_ebreak;
                idex_valid<=1'b1; idex_csr<=id_csr; idex_ecall<=id_ecall; idex_mret<=id_mret;
                idex_csr_addr<=id_csr_addr; idex_csr_cmd<=id_csr_cmd; idex_csr_imm<=id_csr_imm;
                idex_is_muldiv<=id_is_muldiv; idex_md_word<=id_md_word;
                idex_is_amo<=id_is_amo; idex_amo_f5<=id_amo_f5; idex_amo_word<=id_amo_word;
            end

            // ---- A-extension read-modify-write FSM ----
            case (amo_state)
                AMO_IDLE: if (amo_active) begin
                    amo_addr <= ex_a;
                    if (amo_is_sc) begin
                        amo_result <= sc_hit ? 64'd0 : 64'd1;     // 0 = success, 1 = fail
                        resv_valid <= 1'b0;                       // sc always clears reservation
                        amo_state  <= sc_hit ? AMO_WR : AMO_FIN;
                    end else begin
                        amo_state  <= AMO_RD;                     // lr / amo: read issued this cycle
                    end
                end
                AMO_RD: begin                                     // mem_load now valid (= old word)
                    amo_result <= amo_old_c;                      // rd = old value
                    if (amo_is_lr) begin
                        resv_valid <= 1'b1; resv_addr <= amo_addr;
                        amo_state  <= AMO_FIN;
                    end else begin
                        amo_state  <= AMO_WR;                     // amo write-back issued this cycle
                    end
                end
                AMO_WR:  amo_state <= AMO_IDLE;                   // write committed; op advances
                AMO_FIN: amo_state <= AMO_IDLE;                   // result ready; op advances
            endcase
            // a normal store to the reserved word breaks the reservation
            if (dmem_we_n && resv_valid && (alu_y == resv_addr)) resv_valid <= 1'b0;

            // track multiply/divide start so 'start' is a single pulse
            if (md_active & ~ex_busy_stall) md_started <= 1'b0;   // op advanced -> ready for next
            else if (md_start)              md_started <= 1'b1;

            // ---- EXMEM ---- (squashed on trap or while a multi-cycle op is still running)
            if (ex_trap || ex_busy_stall) begin
                exmem_we<=0; exmem_memread<=0; exmem_memwrite<=0; exmem_is_load<=0;
                exmem_rd<=0; exmem_ebreak<=0;
            end else begin
                exmem_result<=ex_result; exmem_addr<=alu_y; exmem_store<=ex_rs2;
                exmem_funct3<=idex_funct3; exmem_rd<=idex_rd; exmem_wbsel<=idex_wbsel;
                exmem_we<=idex_regwrite; exmem_memread<=idex_memread; exmem_memwrite<=idex_memwrite;
                exmem_is_load<=idex_memread; exmem_ebreak<=idex_ebreak;
            end

            // ---- MEMWB ----
            memwb_result<=mem_result; memwb_rd<=exmem_rd; memwb_we<=exmem_we;
            memwb_ebreak<=exmem_ebreak;

            // ---- halt bookkeeping ----
            // ebreak still halts the core (debug aid); ignore one that is being
            // flushed by a taken branch/jump/trap (flush-shadow false positive).
            if (id_ebreak && !ex_redirect_any) stop_fetch <= 1'b1;
            if (memwb_ebreak) halted <= 1'b1;
        end
    end

    // ===================== signature ==================
    wire [63:0] sig; wire [15:0] yr;
    ah_signature u_sig (.sig(sig), .year(yr));
    assign sig_out = sig;
endmodule

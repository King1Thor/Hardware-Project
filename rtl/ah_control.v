// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
`include "ah_defines.vh"
// Main decoder: turns the opcode/funct3/funct7 into datapath control signals.
module ah_control (
    input  [6:0]     opcode,
    input  [2:0]     funct3,
    input            instr30,        // SUB vs ADD, SRA vs SRL
    output reg [3:0] alu_ctrl,
    output           alu_word,       // *W instructions operate on 32 bits
    output           alu_src_b,      // 1 = immediate, 0 = rs2
    output           reg_write,
    output           mem_read,
    output           mem_write,
    output           branch,         // conditional branch
    output           jump,           // jal / jalr (unconditional)
    output           jalr,           // target = rs1 + imm  (vs pc + imm)
    output           halt,           // ebreak / ecall : stop
    output reg [2:0] wb_sel
);
    wire is_op    = (opcode == `OPC_OP);
    wire is_opi   = (opcode == `OPC_OPIMM);
    wire is_op32  = (opcode == `OPC_OP32);
    wire is_opi32 = (opcode == `OPC_OPIMM32);
    wire is_load  = (opcode == `OPC_LOAD);
    wire is_store = (opcode == `OPC_STORE);
    wire is_br    = (opcode == `OPC_BRANCH);
    wire is_jal   = (opcode == `OPC_JAL);
    wire is_jalr  = (opcode == `OPC_JALR);
    wire is_lui   = (opcode == `OPC_LUI);
    wire is_auipc = (opcode == `OPC_AUIPC);
    wire is_sys   = (opcode == `OPC_SYSTEM);

    wire is_alu_op = is_op | is_opi | is_op32 | is_opi32;

    assign alu_word  = is_op32 | is_opi32;
    assign alu_src_b = is_opi | is_opi32 | is_load | is_store | is_jalr;
    assign reg_write = is_alu_op | is_load | is_jal | is_jalr | is_lui | is_auipc;
    assign mem_read  = is_load;
    assign mem_write = is_store;
    assign branch    = is_br;
    assign jump      = is_jal | is_jalr;
    assign jalr      = is_jalr;
    assign halt      = is_sys;

    always @(*) begin
        if      (is_load)  wb_sel = `WB_MEM;
        else if (is_jal | is_jalr) wb_sel = `WB_PC4;
        else if (is_lui)   wb_sel = `WB_IMM;
        else if (is_auipc) wb_sel = `WB_PCIMM;
        else               wb_sel = `WB_ALU;
    end

    // ALU function
    wire sub_op = (is_op | is_op32) & instr30;   // SUB only for register ADD/SUB
    always @(*) begin
        if (is_alu_op) begin
            case (funct3)
                3'b000: alu_ctrl = sub_op ? `ALU_SUB : `ALU_ADD;
                3'b001: alu_ctrl = `ALU_SLL;
                3'b010: alu_ctrl = `ALU_SLT;
                3'b011: alu_ctrl = `ALU_SLTU;
                3'b100: alu_ctrl = `ALU_XOR;
                3'b101: alu_ctrl = instr30 ? `ALU_SRA : `ALU_SRL;
                3'b110: alu_ctrl = `ALU_OR;
                3'b111: alu_ctrl = `ALU_AND;
                default: alu_ctrl = `ALU_ADD;
            endcase
        end else begin
            alu_ctrl = `ALU_ADD;   // address calc for load/store/jalr/auipc
        end
    end
endmodule

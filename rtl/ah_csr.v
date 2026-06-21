// =============================================================================
//  AH-RISCV : machine-mode CSRs + trap unit. (c) 2026 Ali Hussein. GPL-3.0.
//  Hardware signature: "AHUSSEIN".
// =============================================================================
//
// ah_csr : the machine-mode control/status registers and the trap state.
//   - CSR instructions read (combinational) and write (clocked) here.
//   - on a trap: save mepc/mcause, push mstatus (MPIE<=MIE, MIE<=0, MPP<=11).
//   - on mret : pop  mstatus (MIE<=MPIE, MPIE<=1), return target = mepc.
//   - irq_timer asserts when a timer interrupt is pending AND enabled.
// Implemented CSRs: mstatus, mie, mtvec, mscratch, mepc, mcause, mip, mhartid.
//
module ah_csr (
    input             clk, rst,
    // CSR-instruction access
    input      [11:0] raddr,
    output reg [63:0] rdata,
    input             we,
    input      [11:0] waddr,
    input      [63:0] wdata,
    // trap / mret events (from EX)
    input             trap_set,
    input      [63:0] trap_epc,
    input      [63:0] trap_cause,
    input             mret_set,
    // timer interrupt line (from the CLINT in the SoC)
    input             i_mtip,
    // to the pipeline
    output     [63:0] mtvec_o,
    output     [63:0] mepc_o,
    output            irq_timer
);
    reg        st_mie, st_mpie;     // mstatus.MIE / .MPIE
    reg [1:0]  st_mpp;              // mstatus.MPP
    reg [63:0] mtvec, mepc, mcause, mscratch;
    reg        mie_mtie;            // mie.MTIE (bit 7)

    assign mtvec_o   = mtvec;
    assign mepc_o    = mepc;
    assign irq_timer = st_mie & mie_mtie & i_mtip;

    wire [63:0] mstatus_v = (st_mie<<3) | (st_mpie<<7) | ({62'd0,st_mpp}<<11);

    always @(*) begin
        case (raddr)
            12'h300: rdata = mstatus_v;
            12'h304: rdata = {56'd0, mie_mtie, 7'd0};
            12'h305: rdata = mtvec;
            12'h340: rdata = mscratch;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            12'h344: rdata = {56'd0, i_mtip, 7'd0};   // mip.MTIP (read-only)
            12'hF14: rdata = 64'd0;                    // mhartid = 0
            default: rdata = 64'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            st_mie<=0; st_mpie<=0; st_mpp<=0;
            mtvec<=0; mepc<=0; mcause<=0; mscratch<=0; mie_mtie<=0;
        end else if (trap_set) begin
            mepc<=trap_epc; mcause<=trap_cause;
            st_mpie<=st_mie; st_mie<=1'b0; st_mpp<=2'b11;
        end else if (mret_set) begin
            st_mie<=st_mpie; st_mpie<=1'b1; st_mpp<=2'b00;
        end else if (we) begin
            case (waddr)
                12'h300: begin st_mie<=wdata[3]; st_mpie<=wdata[7]; st_mpp<=wdata[12:11]; end
                12'h304: mie_mtie<=wdata[7];
                12'h305: mtvec<=wdata;
                12'h340: mscratch<=wdata;
                12'h341: mepc<=wdata;
                12'h342: mcause<=wdata;
                default: ;
            endcase
        end
    end
endmodule

// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
// 32 x 64-bit register file. x0 hardwired to 0. Two read ports + one write
// port, plus a debug read port (dbg_addr/dbg_data) for board display.
module ah_regfile (
    input             clk,
    input      [4:0]  rs1, rs2, rd,
    input      [63:0] rd_data,
    input             reg_write,
    output     [63:0] rs1_data, rs2_data,
    input      [4:0]  dbg_addr,
    output     [63:0] dbg_data
);
    reg [63:0] regs [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 64'd0;

    assign rs1_data = (rs1 == 5'd0) ? 64'd0 : regs[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 64'd0 : regs[rs2];
    assign dbg_data = (dbg_addr == 5'd0) ? 64'd0 : regs[dbg_addr];

    always @(posedge clk)
        if (reg_write && rd != 5'd0)
            regs[rd] <= rd_data;
endmodule

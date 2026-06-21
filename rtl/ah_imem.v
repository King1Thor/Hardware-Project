// ============================================================================
//  AH-RISCV : synchronous instruction ROM.  (c) 2026 Ali Hussein.  GPL-3.0.
//  Registered read: the instruction for `addr` appears on `instr` next cycle.
//  Program (board demo): x4 = 13, x6 = 1+2+3+4+5 = 15, then ebreak (halt).
// ============================================================================
module ah_imem (
    input             clk,
    input      [63:0] addr,
    output reg [31:0] instr
);
    reg [31:0] rom [0:1023];
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) rom[i] = 32'h00000013; // NOP fill
        rom[0] = 32'h00d00213;   // li   x4, 13
        rom[1] = 32'h00000313;   // li   x6, 0
        rom[2] = 32'h00100293;   // li   x5, 1
        rom[3] = 32'h00530333;   // add  x6, x6, x5
        rom[4] = 32'h00128293;   // addi x5, x5, 1
        rom[5] = 32'h00600393;   // li   x7, 6
        rom[6] = 32'hfe72cae3;   // blt  x5, x7, -8   (loop while i < 6)
        rom[7] = 32'h00100073;   // ebreak           (halt)
    end
    always @(posedge clk) instr <= rom[addr[11:2]];
endmodule

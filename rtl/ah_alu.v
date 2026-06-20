// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
`include "ah_defines.vh"
// 64-bit ALU. When 'word' is set, the operation is done on the low 32 bits and
// the 32-bit result is sign-extended to 64 (RV64 *W instructions).
module ah_alu (
    input      [3:0]  alu_ctrl,
    input             word,
    input      [63:0] a, b,
    output reg [63:0] y
);
    wire [5:0] sh   = word ? {1'b0, b[4:0]} : b[5:0];
    reg  [63:0] full;
    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD : full = a + b;
            `ALU_SUB : full = a - b;
            `ALU_SLL : full = a << sh;
            `ALU_SLT : full = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0;
            `ALU_SLTU: full = (a < b) ? 64'd1 : 64'd0;
            `ALU_XOR : full = a ^ b;
            `ALU_SRL : full = word ? ({32'b0, a[31:0]} >> sh) : (a >> sh);
            `ALU_SRA : full = word ? ($signed(a[31:0]) >>> sh) : ($signed(a) >>> sh);
            `ALU_OR  : full = a | b;
            `ALU_AND : full = a & b;
            default  : full = 64'd0;
        endcase
        // word ops: sign-extend the low 32 bits of the result
        y = word ? {{32{full[31]}}, full[31:0]} : full;
    end
endmodule

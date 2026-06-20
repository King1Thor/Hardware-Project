// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
`include "ah_defines.vh"
// Produces the correctly-formatted, sign-extended immediate for the opcode.
module ah_imm_gen (
    input  [31:0] instr,
    output reg [63:0] imm
);
    wire [6:0] opcode = instr[6:0];
    wire [63:0] i_imm = {{52{instr[31]}}, instr[31:20]};
    wire [63:0] s_imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};
    wire [63:0] b_imm = {{51{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [63:0] u_imm = {{32{instr[31]}}, instr[31:12], 12'b0};
    wire [63:0] j_imm = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    always @(*) begin
        case (opcode)
            `OPC_STORE:                 imm = s_imm;
            `OPC_BRANCH:                imm = b_imm;
            `OPC_LUI, `OPC_AUIPC:        imm = u_imm;
            `OPC_JAL:                   imm = j_imm;
            default:                    imm = i_imm;  // OP-IMM, LOAD, JALR
        endcase
    end
endmodule

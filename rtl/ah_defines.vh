// =============================================================================
//  AH-RISCV : a 64-bit RISC-V (RV64I) CPU, built from scratch.
//  Copyright (c) 2026 Ali Hussein.   Licensed under GPL-3.0 (see LICENSE).
//  Author signature embedded in hardware: "AHUSSEIN" (see ah_signature.v).
// =============================================================================
`ifndef AH_DEFINES_VH
`define AH_DEFINES_VH
// ALU operation codes
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLL  4'd2
`define ALU_SLT  4'd3
`define ALU_SLTU 4'd4
`define ALU_XOR  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_OR   4'd8
`define ALU_AND  4'd9
// Writeback source select
`define WB_ALU   3'd0
`define WB_MEM   3'd1
`define WB_PC4   3'd2
`define WB_IMM   3'd3
`define WB_PCIMM 3'd4
`define WB_CSR   3'd5
// RV64I major opcodes
`define OPC_OP      7'b0110011
`define OPC_OPIMM   7'b0010011
`define OPC_OP32    7'b0111011
`define OPC_OPIMM32 7'b0011011
`define OPC_LOAD    7'b0000011
`define OPC_STORE   7'b0100011
`define OPC_BRANCH  7'b1100011
`define OPC_JAL     7'b1101111
`define OPC_JALR    7'b1100111
`define OPC_LUI     7'b0110111
`define OPC_AUIPC   7'b0010111
`define OPC_SYSTEM  7'b1110011
`define OPC_AMO     7'b0101111
`endif

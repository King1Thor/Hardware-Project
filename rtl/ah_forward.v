// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
// Forwarding unit: resolves data hazards by bypassing results from the
// EX/MEM and MEM/WB stages back to the ALU inputs in EX.
//   2'b10 = forward from EX/MEM   2'b01 = forward from MEM/WB   2'b00 = none
module ah_forward (
    input  [4:0] idex_rs1, idex_rs2,
    input  [4:0] exmem_rd, input exmem_we, input exmem_is_load,
    input  [4:0] memwb_rd, input memwb_we,
    output reg [1:0] fwdA, fwdB
);
    always @(*) begin
        // operand A
        if (exmem_we && exmem_rd != 5'd0 && !exmem_is_load && exmem_rd == idex_rs1)
            fwdA = 2'b10;
        else if (memwb_we && memwb_rd != 5'd0 && memwb_rd == idex_rs1)
            fwdA = 2'b01;
        else fwdA = 2'b00;
        // operand B
        if (exmem_we && exmem_rd != 5'd0 && !exmem_is_load && exmem_rd == idex_rs2)
            fwdB = 2'b10;
        else if (memwb_we && memwb_rd != 5'd0 && memwb_rd == idex_rs2)
            fwdB = 2'b01;
        else fwdB = 2'b00;
    end
endmodule

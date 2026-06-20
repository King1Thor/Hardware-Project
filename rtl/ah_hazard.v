// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".
// =============================================================================
// Hazard detection unit: a load's result is not ready in time for an
// immediately-following dependent instruction, so we stall one cycle.
module ah_hazard (
    input        idex_memread,
    input  [4:0] idex_rd,
    input  [4:0] ifid_rs1, ifid_rs2,
    output       stall
);
    assign stall = idex_memread && (idex_rd != 5'd0) &&
                   ((idex_rd == ifid_rs1) || (idex_rd == ifid_rs2));
endmodule

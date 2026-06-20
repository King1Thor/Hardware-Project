// =============================================================================
//  AH-RISCV : a 64-bit RISC-V (RV64I) CPU, built from scratch.
//  Copyright (c) 2026 Ali Hussein.
//
//  This file is part of AH-RISCV.
//  AH-RISCV is free software: you can redistribute it and/or modify it under
//  the terms of the GNU General Public License v3 as published by the Free
//  Software Foundation. See the LICENSE file in the project root.
//
//  Distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.
//  Author signature embedded in hardware: "AHUSSEIN" (see ah_signature.v).
// =============================================================================
//
// ah_signature : read-only authorship register.
// Returns the ASCII bytes "AHUSSEIN" (A.Hussein) as a 64-bit constant, plus
// the creation year on a second output. Because this value is USED (wired to a
// real output / readable register), it survives synthesis into the bitstream,
// making the core's authorship provable even if source headers are removed.
//
module ah_signature (
    output [63:0] sig,    // "AHUSSEIN" = 0x41485553_5345494E
    output [15:0] year    // 2026
);
    assign sig  = 64'h4148_5553_5345_494E;  // 'A','H','U','S','S','E','I','N'
    assign year = 16'd2026;
endmodule

// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".  Zybo Z7-10 wrapper.
// =============================================================================
// Slow clock for the CPU. free_run=1 -> continuous slow square wave;
// free_run=0 -> emits exactly one full period per 'step' pulse (single-step).
module ah_clkgen (
    input clk, input free_run, input step, input [31:0] half, output reg cpu_clk
);
    reg [31:0] cnt; reg [3:0] toggles;
    initial begin cnt=0; cpu_clk=0; toggles=0; end
    wire tick = (cnt >= half-1);
    wire run  = free_run | (toggles != 0);
    always @(posedge clk) begin
        if (run && tick) cnt <= 0; else if (run) cnt <= cnt+1; else cnt <= 0;
        if (run && tick) cpu_clk <= ~cpu_clk;
        case ({step, (run && tick && ~free_run)})
            2'b01: toggles <= toggles-1;
            2'b10: toggles <= toggles+2;
            2'b11: toggles <= toggles+1;
            default: toggles <= toggles;
        endcase
    end
endmodule

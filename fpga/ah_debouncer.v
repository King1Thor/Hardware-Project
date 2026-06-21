// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".  Zybo Z7-10 wrapper.
// =============================================================================
module ah_debouncer #(parameter N = 20)(
    input clk, input noisy, output reg clean, output reg rise
);
    reg s0, s1; reg [N-1:0] cnt;
    initial begin clean=0; rise=0; cnt=0; s0=0; s1=0; end
    always @(posedge clk) begin
        s0<=noisy; s1<=s0; rise<=1'b0;
        if (s1==clean) cnt<=0;
        else begin
            cnt<=cnt+1'b1;
            if (&cnt) begin clean<=s1; if (~clean & s1) rise<=1'b1; end
        end
    end
endmodule

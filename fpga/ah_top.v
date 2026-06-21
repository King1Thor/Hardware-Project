// =============================================================================
//  AH-RISCV : 64-bit RISC-V (RV64I) CPU.  Copyright (c) 2026 Ali Hussein.
//  Licensed under GPL-3.0.  Hardware signature: "AHUSSEIN".  Zybo Z7-10 wrapper.
// =============================================================================
//
// ah_top : board wrapper that runs the RV64I core on the Zybo Z7-10 and maps
// it to the LEDs / switches / buttons (only a handful of pins, so it fits).
//
// CONTROLS
//   sw[0] : run mode   0 = auto-run (slow clock)   1 = single-step (BTN0)
//   sw[1] : speed      0 = ~2 Hz                    1 = ~12 Hz
//   sw[2] : LED show   0 = PC index (pc[5:2])       1 = a register (low nibble)
//   sw[3] : register   0 = x6 (loop sum = 15)       1 = x4 (loaded value = 13)
//   btn[3]: RESET (restart program)   btn[0]: STEP (single-step)
// OUTPUTS
//   led[3:0] : selected value     led6_g : heartbeat     led6_b : halted
//
module ah_top #(
    parameter [31:0] HALF_SLOW = 32'd31_250_000,  // ~2 Hz
    parameter [31:0] HALF_FAST = 32'd5_208_333,   // ~12 Hz
    parameter        DB_N      = 20
)(
    input        clk,
    input  [3:0] sw,
    input  [3:0] btn,
    output [3:0] led,
    output       led6_g,
    output       led6_b
);
    wire reset_clean, reset_rise, step_clean, step_rise;
    ah_debouncer #(.N(DB_N)) db_rst (.clk(clk), .noisy(btn[3]), .clean(reset_clean), .rise(reset_rise));
    ah_debouncer #(.N(DB_N)) db_stp (.clk(clk), .noisy(btn[0]), .clean(step_clean),  .rise(step_rise));

    wire [63:0] pc, dbg_result, dbg_regval, sig;
    wire        halted;
    wire        cpu_clk;

    wire auto_go  = (~sw[0]) & ~halted;
    wire free_run = auto_go | reset_clean;          // reset forces the clock to tick
    wire step_req = sw[0] & ~halted & step_rise;
    wire [31:0] half = sw[1] ? HALF_FAST : HALF_SLOW;

    ah_clkgen clkgen (.clk(clk), .free_run(free_run), .step(step_req), .half(half), .cpu_clk(cpu_clk));

    // pick the register to expose: x6 (sum) or x4 (loaded value)
    wire [4:0] regsel = sw[3] ? 5'd4 : 5'd6;

    ah_core cpu (
        .clk(cpu_clk), .rst(reset_clean),
        .pc_out(pc), .halted_out(halted), .dbg_result(dbg_result),
        .dbg_regsel(regsel), .dbg_regval(dbg_regval), .sig_out(sig),
        // no SoC peripherals on this board build: tie off the MMIO/timer ports
        .o_mem_addr(), .o_mem_wdata(), .o_mem_funct3(),
        .o_mem_write(), .o_mem_read(),
        .i_mmio_rdata(64'd0), .i_mtip(1'b0)
    );

    assign led    = sw[2] ? dbg_regval[3:0] : pc[5:2];
    assign led6_g = cpu_clk;     // heartbeat
    assign led6_b = halted;      // lit when program has finished (ebreak)
endmodule

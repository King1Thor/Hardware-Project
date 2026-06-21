// ============================================================================
//  AH-RISCV core testbench.  (c) 2026 Ali Hussein.  GPL-3.0.
//  Runs the program in ah_imem.v on the full pipelined core and checks the
//  result: x4 == 13 (loaded value) and x6 == 15 (sum 1..5), then halt.
// ============================================================================
`timescale 1ns/1ps
module ah_core_tb;
    reg         clk = 0, rst = 1;
    reg  [4:0]  regsel = 0;
    wire [63:0] pc, dbg_regval, sig;
    wire        halted;

    ah_core dut (
        .clk(clk), .rst(rst),
        .pc_out(pc), .halted_out(halted), .dbg_result(),
        .dbg_regsel(regsel), .dbg_regval(dbg_regval), .sig_out(sig),
        .o_mem_addr(), .o_mem_wdata(), .o_mem_funct3(),
        .o_mem_write(), .o_mem_read(),
        .i_mmio_rdata(64'd0), .i_mtip(1'b0)
    );

    always #5 clk = ~clk;

    integer cyc = 0;
    initial begin
        repeat (4) @(posedge clk);
        rst = 0;
        while (!halted && cyc < 2000) begin @(posedge clk); cyc = cyc + 1; end
        if (!halted) begin $display("FAIL: core never halted"); $finish; end

        regsel = 5'd4; @(posedge clk); #1;
        if (dbg_regval !== 64'd13) begin
            $display("FAIL: x4 = %0d (expected 13)", dbg_regval); $finish; end
        regsel = 5'd6; @(posedge clk); #1;
        if (dbg_regval !== 64'd15) begin
            $display("FAIL: x6 = %0d (expected 15)", dbg_regval); $finish; end

        $display("ah_core: halted at pc=0x%0h after %0d cycles; x4=13, x6=15",
                 pc, cyc);
        $display("hardware signature = 0x%016h (\"AHUSSEIN\")", sig);
        $display("AH-RISCV CORE: ALL TESTS PASSED");
        $finish;
    end
endmodule

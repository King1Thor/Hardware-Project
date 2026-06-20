`timescale 1ns/1ps
module ptw_tb;
  reg clk=0,rst=1; always #5 clk=~clk;
  reg start=0; reg [63:0] va, satp;
  wire o_req; wire [63:0] o_addr; reg [63:0] i_pte; reg i_valid=0;
  wire done, fault; wire [63:0] pa; wire [7:0] perm;
  ah_ptw u(.clk(clk),.rst(rst),.start(start),.va(va),.satp(satp),
    .o_req(o_req),.o_addr(o_addr),.i_pte(i_pte),.i_valid(i_valid),
    .done(done),.fault(fault),.pa(pa),.perm(perm));
  // behavioural page-table memory: respond one cycle after a request
  always @(posedge clk) begin
    i_valid <= 1'b0;
    if (o_req) begin
      i_valid <= 1'b1;
      case (o_addr)
        64'h1000: i_pte <= 64'h00000801;  // root[0] -> PPN2 (pointer)
        64'h1008: i_pte <= 64'h00000000;  // root[1] invalid
        64'h2048: i_pte <= 64'h00000C01;  // L1[9]  -> PPN3 (pointer)
        64'h2050: i_pte <= 64'h0008000F;  // L1[10] leaf 2MB PPN=0x200 RWXV
        64'h31A0: i_pte <= 64'h0000140F;  // L0[52] leaf 4KB PPN=5 RWXV
        default:  i_pte <= 64'h00000000;  // anything else invalid
      endcase
    end
  end
  integer fails=0;
  task walk(input [63:0] v, input efault, input [63:0] epa, input [127:0] nm);
    begin
      @(negedge clk); va=v; satp=64'h8000000000000001; start=1;  // MODE=Sv39, root PPN=1
      @(negedge clk); start=0;
      wait(done); @(negedge clk);
      if (fault===efault && (efault || pa===epa))
        $display("  ok   %0s: fault=%0d pa=0x%010x", nm, fault, pa);
      else begin $display("  FAIL %0s: fault=%0d pa=0x%010x (exp fault=%0d pa=0x%010x)",nm,fault,pa,efault,epa); fails=fails+1; end
    end
  endtask
  initial begin
    @(negedge clk); rst=0; @(negedge clk);
    walk(64'h01234000, 1'b0, 64'h5000,   "4KB  VA=0x1234000");
    walk(64'h01405123, 1'b0, 64'h205123, "2MB  VA=0x1405123");
    walk(64'h40000000, 1'b1, 64'h0,      "fault VA=0x40000000");
    if (fails==0) $display("\nPTW: ALL TESTS PASSED"); else $display("\nPTW: %0d FAILED", fails);
    $finish;
  end
endmodule

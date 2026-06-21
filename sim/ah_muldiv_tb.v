`timescale 1ns/1ps
module md_tb;
  reg clk=0,rst=1; always #5 clk=~clk;
  reg start=0,word=0; reg [2:0] f3; reg [63:0] a,b; wire busy; wire [63:0] result;
  ah_muldiv u(.clk(clk),.rst(rst),.start(start),.funct3(f3),.word(word),.a(a),.b(b),.busy(busy),.result(result));
  integer fails=0;
  task run(input [2:0] ff, input w, input [63:0] aa, input [63:0] bb, input [63:0] exp, input [127:0] name);
    begin
      @(negedge clk); f3=ff; word=w; a=aa; b=bb; start=1;
      @(negedge clk); start=0;
      wait(!busy); @(negedge clk);
      if (result===exp) $display("  ok   %0s = 0x%016x", name, result);
      else begin $display("  FAIL %0s = 0x%016x (exp 0x%016x)", name, result, exp); fails=fails+1; end
    end
  endtask
  initial begin
    @(negedge clk); rst=0; @(negedge clk);
    run(3'b000,0,64'd6,64'd7,64'd42,"mul 6*7");
    run(3'b000,0,-64'd3,64'd5,-64'd15,"mul -3*5");
    run(3'b001,0,-64'd1,-64'd1,64'd0,"mulh -1*-1");          // hi of 1 = 0
    run(3'b011,0,64'hFFFFFFFFFFFFFFFF,64'hFFFFFFFFFFFFFFFF,64'hFFFFFFFFFFFFFFFE,"mulhu max*max");
    run(3'b010,0,-64'd1,64'd2,64'hFFFFFFFFFFFFFFFF,"mulhsu -1*2");
    run(3'b100,0,64'd100,64'd7,64'd14,"div 100/7");
    run(3'b110,0,64'd100,64'd7,64'd2,"rem 100%7");
    run(3'b100,0,-64'd100,64'd7,-64'd14,"div -100/7");
    run(3'b110,0,-64'd100,64'd7,-64'd2,"rem -100%7");
    run(3'b100,0,64'd100,-64'd7,-64'd14,"div 100/-7");
    run(3'b101,0,64'd100,64'd7,64'd14,"divu 100/7");
    run(3'b100,0,64'd5,64'd0,64'hFFFFFFFFFFFFFFFF,"div 5/0");
    run(3'b110,0,64'd5,64'd0,64'd5,"rem 5%0");
    run(3'b100,0,64'h8000000000000000,-64'd1,64'h8000000000000000,"div MIN/-1");
    run(3'b110,0,64'h8000000000000000,-64'd1,64'd0,"rem MIN%-1");
    run(3'b000,1,64'd100000,64'd100000,64'h00000000540BE400,"mulw 1e5*1e5");
    run(3'b100,1,-64'd100,64'd7,-64'd14,"divw -100/7");
    run(3'b110,1,-64'd100,64'd7,-64'd2,"remw -100%7");
    if (fails==0) $display("\nMULDIV: ALL TESTS PASSED"); else $display("\nMULDIV: %0d FAILED", fails);
    $finish;
  end
endmodule

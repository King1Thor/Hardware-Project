`timescale 1ns/1ps
module uni_tb; localparam DIV=8;
  reg clk=0,rst=1; always #5 clk=~clk;
  wire [63:0] maddr,mwdata,mmio_rd; wire [2:0] mf3; wire mwr,mrd;
  ah_core u(.clk(clk),.rst(rst),.pc_out(),.halted_out(),.dbg_result(),.dbg_regsel(5'd0),
    .dbg_regval(),.sig_out(),.o_mem_addr(maddr),.o_mem_wdata(mwdata),.o_mem_funct3(mf3),
    .o_mem_write(mwr),.o_mem_read(mrd),.i_mmio_rdata(mmio_rd),.i_mtip(1'b0));
  wire is_mmio=(maddr[31:28]==4'h1), sel_tx=is_mmio&&(maddr[7:0]==8'h00), sel_st=is_mmio&&(maddr[7:0]==8'h08);
  wire txr; wire serial;
  ah_uart #(.DIV(DIV)) U(.clk(clk),.rst(rst),.tx_we(mwr&&sel_tx),.tx_data(mwdata[7:0]),
    .tx_ready(txr),.rx_re(1'b0),.rx_data(),.rx_valid(),.tx(serial),.rx(1'b1));
  assign mmio_rd = sel_st ? {62'd0,1'b0,txr} : 64'd0;
  wire [7:0] md; wire mv; reg mre=0;
  ah_uart #(.DIV(DIV)) M(.clk(clk),.rst(rst),.tx_we(1'b0),.tx_data(8'd0),.tx_ready(),
    .rx_re(mre),.rx_data(md),.rx_valid(mv),.tx(),.rx(serial));
  integer cyc=0; reg done=0;
  initial begin repeat(3)@(posedge clk); rst=0;
    while(!done && cyc<200000) begin @(posedge clk); cyc=cyc+1;
      if(mv&&!mre) begin if(md=="#") done=1; else if(md>=32&&md<127||md==10||md==13) $write("%c",md); mre<=1; end else mre<=0; end
    $write("\n(done=%0d cyc=%0d)\n",done,cyc); $finish; end
endmodule

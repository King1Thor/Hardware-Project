// =============================================================================
//  AH-RISCV : SoC peripheral.  Copyright (c) 2026 Ali Hussein.  GPL-3.0.
//  Hardware signature: "AHUSSEIN".
// =============================================================================
//
// ah_uart : 8N1 serial UART (no parity, 1 stop bit). Parameterised baud
// divisor DIV = clk_freq / baud_rate.  TX and RX, each LSB-first.
//   - pulse tx_we with tx_data when tx_ready=1 to send a byte
//   - rx_valid=1 when a byte has arrived; read rx_data, pulse rx_re to clear
//
module ah_uart #(parameter integer DIV = 217) (
    input            clk, rst,
    // transmit
    input            tx_we,
    input  [7:0]     tx_data,
    output           tx_ready,
    // receive
    input            rx_re,
    output [7:0]     rx_data,
    output           rx_valid,
    // serial pins
    output           tx,
    input            rx
);
    // ---------------- transmit ----------------
    reg [15:0] tbaud; reg [3:0] tbit; reg [9:0] tsh; reg tbusy;
    assign tx_ready = ~tbusy;
    assign tx       = tbusy ? tsh[0] : 1'b1;     // idle line is high
    always @(posedge clk) begin
        if (rst) begin tbusy<=1'b0; tbaud<=0; tbit<=0; tsh<=10'h3FF; end
        else if (!tbusy) begin
            if (tx_we) begin tsh<={1'b1,tx_data,1'b0}; tbusy<=1'b1; tbaud<=0; tbit<=0; end
        end else if (tbaud==DIV-1) begin
            tbaud<=0; tsh<={1'b1,tsh[9:1]};
            if (tbit==9) tbusy<=1'b0; else tbit<=tbit+1'b1;
        end else tbaud<=tbaud+1'b1;
    end

    // ---------------- receive ----------------
    reg [1:0] rsync; always @(posedge clk) rsync<={rsync[0],rx};
    wire rxs = rsync[1];
    reg [15:0] rbaud; reg [3:0] rbit; reg [7:0] rsh, rdat; reg rbusy, rval;
    assign rx_valid = rval; assign rx_data = rdat;
    always @(posedge clk) begin
        if (rst) begin rbusy<=1'b0; rval<=1'b0; rbaud<=0; rbit<=0; end
        else begin
            if (rx_re) rval<=1'b0;
            if (!rbusy) begin
                if (!rxs) begin rbusy<=1'b1; rbaud<=DIV/2; rbit<=0; end   // start edge -> aim mid-bit
            end else if (rbaud==DIV-1) begin
                rbaud<=0;
                if (rbit==0)      rbit<=rbit+1'b1;                 // middle of start bit
                else if (rbit<=8) begin rsh<={rxs,rsh[7:1]}; rbit<=rbit+1'b1; end
                else begin rdat<=rsh; rval<=1'b1; rbusy<=1'b0; end // stop bit -> done
            end else rbaud<=rbaud+1'b1;
        end
    end
endmodule

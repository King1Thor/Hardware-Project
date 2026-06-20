// =============================================================================
//  AH-RISCV : RV64M multiply / divide unit. (c) 2026 Ali Hussein. GPL-3.0.
//  Hardware signature: "AHUSSEIN".
//
//  Sequential, so it stays synthesizable at speed. Operands are latched at
//  'start' (the pipeline may stall and shift its forwarding sources while we
//  run). Implements MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU and the RV64 *W
//  forms, including the architectural div-by-zero and signed-overflow results.
//
//  funct3 : 000 MUL  001 MULH  010 MULHSU  011 MULHU
//           100 DIV  101 DIVU  110 REM     111 REMU
//  word=1 -> low 32 bits, 32-bit result sign-extended to 64.
// =============================================================================
module ah_muldiv (
    input             clk, rst,
    input             start,
    input      [2:0]  funct3,
    input             word,
    input      [63:0] a, b,
    output reg        busy,
    output reg [63:0] result
);
    localparam IDLE=2'd0, SETUP=2'd1, DIV=2'd2, FIN=2'd3;
    reg [1:0]  state;
    reg [2:0]  f3;  reg w;  reg [63:0] a_r, b_r;     // latched operands

    wire        a_signed = (f3==3'b001)||(f3==3'b010)||(f3==3'b100)||(f3==3'b110);
    wire        b_signed = (f3==3'b001)||(f3==3'b100)||(f3==3'b110);
    wire [63:0] a_use = w ? {{32{a_r[31] & a_signed}}, a_r[31:0]} : a_r;
    wire [63:0] b_use = w ? {{32{b_r[31] & b_signed}}, b_r[31:0]} : b_r;
    wire [127:0] a_ext = a_signed ? {{64{a_use[63]}}, a_use} : {64'd0, a_use};
    wire [127:0] b_ext = b_signed ? {{64{b_use[63]}}, b_use} : {64'd0, b_use};
    wire [127:0] prod  = a_ext * b_ext;

    wire        div_signed = (f3==3'b100)||(f3==3'b110);
    wire        sa = div_signed & a_use[63];
    wire        sb = div_signed & b_use[63];
    wire [63:0] a_mag = sa ? (~a_use + 64'd1) : a_use;
    wire [63:0] b_mag = sb ? (~b_use + 64'd1) : b_use;
    wire        by_zero = (b_use == 64'd0);
    wire        ov = div_signed && (a_use==64'h8000000000000000) && (b_use==64'hFFFFFFFFFFFFFFFF);

    reg [63:0] q, r, dvsr, dvnd;  reg q_neg, r_neg, is_rem;  reg [6:0] cnt;
    function [63:0] sx32; input [63:0] v; sx32 = {{32{v[31]}}, v[31:0]}; endfunction

    always @(posedge clk) begin
        if (rst) begin state<=IDLE; busy<=0; result<=0; end
        else case (state)
        IDLE: begin
            busy <= 0;
            if (start) begin a_r<=a; b_r<=b; f3<=funct3; w<=word; busy<=1; state<=SETUP; end
        end
        SETUP: begin                                   // operands now latched
            if (f3[2]==1'b0) begin                      // MUL*
                result <= (f3[1:0]==2'b00) ? (w ? sx32(prod[63:0]) : prod[63:0])
                                           : prod[127:64];
                busy <= 0; state <= IDLE;
            end else begin                              // DIV* / REM*
                is_rem <= f3[1];
                if (by_zero) begin
                    result <= w ? sx32(f3[1] ? a_use : 64'hFFFFFFFFFFFFFFFF)
                                : (f3[1] ? a_use : 64'hFFFFFFFFFFFFFFFF);
                    busy <= 0; state <= IDLE;
                end else if (ov) begin
                    result <= w ? sx32(f3[1] ? 64'd0 : 64'h8000000000000000)
                                : (f3[1] ? 64'd0 : 64'h8000000000000000);
                    busy <= 0; state <= IDLE;
                end else begin
                    q<=0; r<=0; dvsr<=b_mag; dvnd<=a_mag;
                    q_neg<=sa^sb; r_neg<=sa; cnt<=7'd64; state<=DIV;
                end
            end
        end
        DIV: begin
            begin : step
                reg [63:0] rs; rs = {r[62:0], dvnd[63]}; dvnd <= {dvnd[62:0],1'b0};
                if (rs >= dvsr) begin r <= rs - dvsr; q <= {q[62:0],1'b1}; end
                else            begin r <= rs;        q <= {q[62:0],1'b0}; end
            end
            cnt <= cnt - 7'd1;
            if (cnt == 7'd1) state <= FIN;
        end
        FIN: begin
            begin : fix
                reg [63:0] qf, rf;
                qf = q_neg ? (~q + 64'd1) : q;
                rf = r_neg ? (~r + 64'd1) : r;
                result <= is_rem ? (w ? sx32(rf) : rf) : (w ? sx32(qf) : qf);
            end
            busy <= 0; state <= IDLE;
        end
        endcase
    end
endmodule

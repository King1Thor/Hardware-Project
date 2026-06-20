// =============================================================================
//  AH-RISCV : Sv39 page-table walker. (c) 2026 Ali Hussein. GPL-3.0.
//  Hardware signature: "AHUSSEIN".
//
//  Given a 39-bit virtual address and satp, walks the 3-level Sv39 page table
//  (reading PTEs from physical memory) and produces a physical address, the
//  leaf permission bits, or a page fault. Supports 4 KB / 2 MB / 1 GB pages.
//
//  Sv39 VA:  [38:30]=VPN2 [29:21]=VPN1 [20:12]=VPN0 [11:0]=offset
//  PTE:      [0]=V [1]=R [2]=W [3]=X [4]=U [5]=G [6]=A [7]=D, [53:10]=PPN
// =============================================================================
module ah_ptw (
    input             clk, rst,
    input             start,        // pulse to begin a walk
    input      [63:0] va,
    input      [63:0] satp,
    // physical-memory read port (returns the 64-bit PTE at o_addr)
    output reg        o_req,
    output reg [63:0] o_addr,
    input      [63:0] i_pte,
    input             i_valid,
    // result
    output reg        done,         // pulse: walk complete
    output reg        fault,        // page fault (invalid PTE / bad level)
    output reg [63:0] pa,
    output reg [7:0]  perm          // leaf flags V,R,W,X,U,G,A,D
);
    localparam IDLE=2'd0, ISSUE=2'd1, WAIT=2'd2;
    reg [1:0]  state;
    reg [1:0]  lvl;                 // 2,1,0
    reg [43:0] base_ppn;

    wire [8:0] vpn2 = va[38:30], vpn1 = va[29:21], vpn0 = va[20:12];
    wire [11:0] off = va[11:0];
    reg  [8:0] vpn_sel;
    always @(*) case (lvl) 2'd2: vpn_sel=vpn2; 2'd1: vpn_sel=vpn1; default: vpn_sel=vpn0; endcase

    wire        v_v  = i_pte[0], v_r = i_pte[1], v_w = i_pte[2], v_x = i_pte[3];
    wire        leaf = v_r | v_x;
    wire [43:0] ppn  = i_pte[53:10];

    always @(posedge clk) begin
        if (rst) begin state<=IDLE; o_req<=0; done<=0; fault<=0; end
        else begin
            done<=0; o_req<=0;
            case (state)
            IDLE: if (start) begin
                lvl<=2'd2; base_ppn<=satp[43:0]; fault<=0; state<=ISSUE;
            end
            ISSUE: begin
                o_addr <= {base_ppn, 12'd0} + {vpn_sel, 3'd0};   // base*4096 + vpn*8
                o_req  <= 1'b1;
                state  <= WAIT;
            end
            WAIT: if (i_valid) begin
                perm <= i_pte[7:0];
                if (!v_v || (!v_r && v_w)) begin          // invalid PTE
                    fault<=1'b1; done<=1'b1; state<=IDLE;
                end else if (leaf) begin                  // leaf: form PA
                    case (lvl)
                        2'd2: pa <= {8'd0, ppn[43:18], vpn1, vpn0, off};  // 1 GB page
                        2'd1: pa <= {8'd0, ppn[43:9],  vpn0, off};        // 2 MB page
                        default: pa <= {8'd0, ppn, off};                  // 4 KB page
                    endcase
                    fault<=1'b0; done<=1'b1; state<=IDLE;
                end else if (lvl==2'd0) begin             // non-leaf at level 0 -> fault
                    fault<=1'b1; done<=1'b1; state<=IDLE;
                end else begin                            // descend a level
                    base_ppn<=ppn; lvl<=lvl-2'd1; state<=ISSUE;
                end
            end
            endcase
        end
    end
endmodule

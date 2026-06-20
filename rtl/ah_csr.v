// =============================================================================
//  AH-RISCV : M + S privilege CSRs, trap delegation, and trap state.
//  (c) 2026 Ali Hussein. GPL-3.0.  Hardware signature: "AHUSSEIN".
//
//  Adds supervisor mode on top of the original machine-mode unit:
//    - a privilege register `priv` (11=M, 01=S, 00=U), reset to M;
//    - the S-mode CSRs (sstatus/sie/stvec/sscratch/sepc/scause/stval/sip/satp);
//    - medeleg/mideleg: a trap taken in S/U mode whose cause bit is delegated
//      goes to S-mode (stvec) instead of M-mode (mtvec);
//    - mret pops mstatus.MPP into priv; sret pops sstatus.SPP into priv;
//    - satp + sstatus.SUM/MXR are exported for the Sv39 MMU.
// =============================================================================
module ah_csr (
    input             clk, rst,
    input      [11:0] raddr,
    output reg [63:0] rdata,
    input             we,
    input      [11:0] waddr,
    input      [63:0] wdata,
    input             trap_set,
    input      [63:0] trap_epc,
    input      [63:0] trap_cause,    // bit63 = interrupt, low bits = cause code
    input      [63:0] trap_tval,
    input             ret_set,
    input             ret_is_sret,   // 1 = sret, 0 = mret
    input             i_mtip,
    output     [63:0] trap_vec_o,    // target for the current trap (mtvec or stvec)
    output     [63:0] ret_target_o,  // mepc or sepc
    output     [1:0]  priv_o,
    output     [63:0] satp_o,
    output            sum_o, mxr_o,
    output            irq_timer
);
    localparam M=2'b11, S=2'b01, U=2'b00;
    reg [1:0]  priv;
    reg        st_sie, st_mie, st_spie, st_mpie, st_spp, st_sum, st_mxr;
    reg [1:0]  st_mpp;
    reg [63:0] mtvec, mepc, mcause, mscratch, mtval;
    reg [63:0] stvec, sepc, scause, sscratch, stval;
    reg [11:0] mie, mip_sw;          // mip_sw = software-writable mip bits
    reg [63:0] medeleg, mideleg, satp;

    assign priv_o = priv;
    assign satp_o = satp;
    assign sum_o  = st_sum;
    assign mxr_o  = st_mxr;

    wire [63:0] mstatus_v = (st_sie<<1)|(st_mie<<3)|(st_spie<<5)|(st_mpie<<7)|
                            (st_spp<<8)|({62'd0,st_mpp}<<11)|(st_sum<<18)|(st_mxr<<19);
    wire [63:0] sstatus_v = (st_sie<<1)|(st_spie<<5)|(st_spp<<8)|(st_sum<<18)|(st_mxr<<19);
    wire [11:0] mip_v     = mip_sw | (i_mtip ? 12'h080 : 12'h000);
    wire [11:0] sie_v     = mie   & 12'h222;
    wire [11:0] sip_v     = mip_v & 12'h222;

    wire        t_is_int  = trap_cause[63];
    wire [5:0]  t_code    = trap_cause[5:0];
    wire        deleg     = (priv != M) &&
                            (t_is_int ? mideleg[t_code] : medeleg[t_code]);
    assign trap_vec_o   = deleg ? stvec : mtvec;
    assign ret_target_o = ret_is_sret ? sepc : mepc;

    wire m_ints_on = (priv != M) || st_mie;
    assign irq_timer = mie[7] & i_mtip & m_ints_on;

    always @(*) begin
        case (raddr)
            12'h100: rdata = sstatus_v;
            12'h104: rdata = {52'd0, sie_v};
            12'h105: rdata = stvec;
            12'h140: rdata = sscratch;
            12'h141: rdata = sepc;
            12'h142: rdata = scause;
            12'h143: rdata = stval;
            12'h144: rdata = {52'd0, sip_v};
            12'h180: rdata = satp;
            12'h300: rdata = mstatus_v;
            12'h302: rdata = medeleg;
            12'h303: rdata = mideleg;
            12'h304: rdata = {52'd0, mie};
            12'h305: rdata = mtvec;
            12'h340: rdata = mscratch;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            12'h343: rdata = mtval;
            12'h344: rdata = {52'd0, mip_v};
            12'hF14: rdata = 64'd0;
            default: rdata = 64'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            priv<=M;
            st_sie<=0; st_mie<=0; st_spie<=0; st_mpie<=0; st_spp<=0; st_mpp<=0;
            st_sum<=0; st_mxr<=0;
            mtvec<=0; mepc<=0; mcause<=0; mscratch<=0; mtval<=0;
            stvec<=0; sepc<=0; scause<=0; sscratch<=0; stval<=0;
            mie<=0; mip_sw<=0; medeleg<=0; mideleg<=0; satp<=0;
        end else if (trap_set) begin
            if (deleg) begin
                sepc<=trap_epc; scause<=trap_cause; stval<=trap_tval;
                st_spp<=(priv==S); st_spie<=st_sie; st_sie<=1'b0;
                priv<=S;
            end else begin
                mepc<=trap_epc; mcause<=trap_cause; mtval<=trap_tval;
                st_mpp<=priv; st_mpie<=st_mie; st_mie<=1'b0;
                priv<=M;
            end
        end else if (ret_set) begin
            if (ret_is_sret) begin
                priv<={1'b0,st_spp}; st_sie<=st_spie; st_spie<=1'b1; st_spp<=1'b0;
            end else begin
                priv<=st_mpp; st_mie<=st_mpie; st_mpie<=1'b1; st_mpp<=U;
            end
        end else if (we) begin
            case (waddr)
                12'h100: begin
                    st_sie<=wdata[1]; st_spie<=wdata[5]; st_spp<=wdata[8];
                    st_sum<=wdata[18]; st_mxr<=wdata[19];
                end
                12'h104: mie<=(mie & ~12'h222) | (wdata[11:0] & 12'h222);
                12'h105: stvec<=wdata;
                12'h140: sscratch<=wdata;
                12'h141: sepc<=wdata;
                12'h142: scause<=wdata;
                12'h143: stval<=wdata;
                12'h144: mip_sw<=(mip_sw & ~12'h002) | (wdata[11:0] & 12'h002);
                12'h180: satp<=wdata;
                12'h300: begin
                    st_sie<=wdata[1]; st_mie<=wdata[3]; st_spie<=wdata[5];
                    st_mpie<=wdata[7]; st_spp<=wdata[8]; st_mpp<=wdata[12:11];
                    st_sum<=wdata[18]; st_mxr<=wdata[19];
                end
                12'h302: medeleg<=wdata;
                12'h303: mideleg<=wdata;
                12'h304: mie<=wdata[11:0];
                12'h305: mtvec<=wdata;
                12'h340: mscratch<=wdata;
                12'h341: mepc<=wdata;
                12'h342: mcause<=wdata;
                12'h343: mtval<=wdata;
                12'h344: mip_sw<=(mip_sw & ~12'h022) | (wdata[11:0] & 12'h022);
                default: ;
            endcase
        end
    end
endmodule

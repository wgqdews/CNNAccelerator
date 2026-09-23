`include "params.vh"

module weight_bank #(
    parameter DEPTH = 1
) (
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       we,
    input  wire [`WGT_ADDR_WIDTH-1:0] waddr,
    input  wire [`WGT_WIDTH-1:0]      wdata,
    input  wire [`WGT_ADDR_WIDTH-1:0] raddr,
    output wire [`WGT_WIDTH-1:0]      rdata
);
`ifdef SRAM_MACRO
    localparam MACRO_DEPTH = 19968; 

    wire sel_hi_r = (raddr >= MACRO_DEPTH);
    wire sel_hi_w = (waddr >= MACRO_DEPTH);
    wire [14:0] local_raddr = sel_hi_r ? (raddr - MACRO_DEPTH) : raddr;
    wire [14:0] local_waddr = sel_hi_w ? (waddr - MACRO_DEPTH) : waddr;
    wire        wr_en       = we;


    reg sel_hi_r_d = 1'b0;  
    always @(posedge clk) sel_hi_r_d <= sel_hi_r;

    wire [7:0] rdata_lo, rdata_hi;
    assign rdata = sel_hi_r_d ? rdata_hi : rdata_lo;

    SJMA180_19968X8X1BM8 u_mem_lo (
        .A0(local_raddr[0]),   .A1(local_raddr[1]),   .A2(local_raddr[2]),
        .A3(local_raddr[3]),   .A4(local_raddr[4]),   .A5(local_raddr[5]),
        .A6(local_raddr[6]),   .A7(local_raddr[7]),   .A8(local_raddr[8]),
        .A9(local_raddr[9]),   .A10(local_raddr[10]), .A11(local_raddr[11]),
        .A12(local_raddr[12]), .A13(local_raddr[13]), .A14(local_raddr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rdata_lo[0]), .DOA1(rdata_lo[1]), .DOA2(rdata_lo[2]), .DOA3(rdata_lo[3]),
        .DOA4(rdata_lo[4]), .DOA5(rdata_lo[5]), .DOA6(rdata_lo[6]), .DOA7(rdata_lo[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(wr_en & ~sel_hi_w)),
        .CKA(clk), .CKB(clk),

        .CSA(rst_n & ~sel_hi_r), .CSB(~sel_hi_w),
        .OEA(1'b1), .OEB(1'b0)
    );

    SJMA180_19968X8X1BM8 u_mem_hi (
        .A0(local_raddr[0]),   .A1(local_raddr[1]),   .A2(local_raddr[2]),
        .A3(local_raddr[3]),   .A4(local_raddr[4]),   .A5(local_raddr[5]),
        .A6(local_raddr[6]),   .A7(local_raddr[7]),   .A8(local_raddr[8]),
        .A9(local_raddr[9]),   .A10(local_raddr[10]), .A11(local_raddr[11]),
        .A12(local_raddr[12]), .A13(local_raddr[13]), .A14(local_raddr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rdata_hi[0]), .DOA1(rdata_hi[1]), .DOA2(rdata_hi[2]), .DOA3(rdata_hi[3]),
        .DOA4(rdata_hi[4]), .DOA5(rdata_hi[5]), .DOA6(rdata_hi[6]), .DOA7(rdata_hi[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(wr_en & sel_hi_w)),
        .CKA(clk), .CKB(clk),
        .CSA(rst_n & sel_hi_r), .CSB(sel_hi_w),
        .OEA(1'b1), .OEB(1'b0)
    );
`else
    reg [`WGT_WIDTH-1:0] mem [0:DEPTH-1];
    assign rdata = mem[raddr];
    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end
`endif
endmodule

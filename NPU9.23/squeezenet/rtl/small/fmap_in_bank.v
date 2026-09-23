`include "params.vh"


module fmap_in_bank #(
    parameter DEPTH = 1
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire [`FMAP_ADDR_WIDTH-1:0] raddr,
    output wire [`ACT_WIDTH-1:0]       rdata,
    input  wire                        we,
    input  wire [`FMAP_ADDR_WIDTH-1:0] waddr,
    input  wire [`ACT_WIDTH-1:0]       wdata
);
`ifdef SRAM_MACRO
    localparam [`FMAP_ADDR_WIDTH-1:0] OFF0 = 0;
    localparam [`FMAP_ADDR_WIDTH-1:0] OFF1 = 32768;
    localparam [`FMAP_ADDR_WIDTH-1:0] OFF2 = 65536;
    localparam [`FMAP_ADDR_WIDTH-1:0] OFF3 = 98304;
    localparam [`FMAP_ADDR_WIDTH-1:0] OFF4 = 131072;

    wire sel0 = (raddr < OFF1);
    wire sel1 = (raddr >= OFF1) && (raddr < OFF2);
    wire sel2 = (raddr >= OFF2) && (raddr < OFF3);
    wire sel3 = (raddr >= OFF3) && (raddr < OFF4);
    wire sel4 = (raddr >= OFF4);

    wire [14:0] local_addr = sel0 ? raddr[14:0] :
                              sel1 ? (raddr - OFF1) :
                              sel2 ? (raddr - OFF2) :
                              sel3 ? (raddr - OFF3) :
                                     (raddr - OFF4);
    wire sel0_w = (waddr < OFF1);
    wire sel1_w = (waddr >= OFF1) && (waddr < OFF2);
    wire sel2_w = (waddr >= OFF2) && (waddr < OFF3);
    wire sel3_w = (waddr >= OFF3) && (waddr < OFF4);
    wire sel4_w = (waddr >= OFF4);

    wire [14:0] local_waddr = sel0_w ? waddr[14:0] :
                               sel1_w ? (waddr - OFF1) :
                               sel2_w ? (waddr - OFF2) :
                               sel3_w ? (waddr - OFF3) :
                                        (waddr - OFF4);
    reg sel0_d = 1'b0, sel1_d = 1'b0, sel2_d = 1'b0, sel3_d = 1'b0, sel4_d = 1'b0;
    always @(posedge clk) begin
        sel0_d <= sel0; sel1_d <= sel1; sel2_d <= sel2; sel3_d <= sel3; sel4_d <= sel4;
    end

    wire [7:0] rd0, rd1, rd2, rd3, rd4;
    assign rdata = sel0_d ? rd0 : sel1_d ? rd1 : sel2_d ? rd2 : sel3_d ? rd3 : rd4;

    // 4 顆一模一樣的 FMI180_32768X8(前段)+ 1 顆 FMI180_19456X8(尾段餘數)
    FMI180_32768X8 u_mem0 (
        .A0(local_addr[0]),   .A1(local_addr[1]),   .A2(local_addr[2]),
        .A3(local_addr[3]),   .A4(local_addr[4]),   .A5(local_addr[5]),
        .A6(local_addr[6]),   .A7(local_addr[7]),   .A8(local_addr[8]),
        .A9(local_addr[9]),   .A10(local_addr[10]), .A11(local_addr[11]),
        .A12(local_addr[12]), .A13(local_addr[13]), .A14(local_addr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rd0[0]), .DOA1(rd0[1]), .DOA2(rd0[2]), .DOA3(rd0[3]),
        .DOA4(rd0[4]), .DOA5(rd0[5]), .DOA6(rd0[6]), .DOA7(rd0[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(we & sel0_w)),
        .CKA(clk), .CKB(clk),
        .CSA(rst_n & sel0), .CSB(sel0_w),
        .OEA(1'b1), .OEB(1'b0)
    );
    FMI180_32768X8 u_mem1 (
        .A0(local_addr[0]),   .A1(local_addr[1]),   .A2(local_addr[2]),
        .A3(local_addr[3]),   .A4(local_addr[4]),   .A5(local_addr[5]),
        .A6(local_addr[6]),   .A7(local_addr[7]),   .A8(local_addr[8]),
        .A9(local_addr[9]),   .A10(local_addr[10]), .A11(local_addr[11]),
        .A12(local_addr[12]), .A13(local_addr[13]), .A14(local_addr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rd1[0]), .DOA1(rd1[1]), .DOA2(rd1[2]), .DOA3(rd1[3]),
        .DOA4(rd1[4]), .DOA5(rd1[5]), .DOA6(rd1[6]), .DOA7(rd1[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(we & sel1_w)),
        .CKA(clk), .CKB(clk),
        .CSA(rst_n & sel1), .CSB(sel1_w),
        .OEA(1'b1), .OEB(1'b0)
    );
    FMI180_32768X8 u_mem2 (
        .A0(local_addr[0]),   .A1(local_addr[1]),   .A2(local_addr[2]),
        .A3(local_addr[3]),   .A4(local_addr[4]),   .A5(local_addr[5]),
        .A6(local_addr[6]),   .A7(local_addr[7]),   .A8(local_addr[8]),
        .A9(local_addr[9]),   .A10(local_addr[10]), .A11(local_addr[11]),
        .A12(local_addr[12]), .A13(local_addr[13]), .A14(local_addr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rd2[0]), .DOA1(rd2[1]), .DOA2(rd2[2]), .DOA3(rd2[3]),
        .DOA4(rd2[4]), .DOA5(rd2[5]), .DOA6(rd2[6]), .DOA7(rd2[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(we & sel2_w)),
        .CKA(clk), .CKB(clk),
        .CSA(rst_n & sel2), .CSB(sel2_w),
        .OEA(1'b1), .OEB(1'b0)
    );
    FMI180_32768X8 u_mem3 (
        .A0(local_addr[0]),   .A1(local_addr[1]),   .A2(local_addr[2]),
        .A3(local_addr[3]),   .A4(local_addr[4]),   .A5(local_addr[5]),
        .A6(local_addr[6]),   .A7(local_addr[7]),   .A8(local_addr[8]),
        .A9(local_addr[9]),   .A10(local_addr[10]), .A11(local_addr[11]),
        .A12(local_addr[12]), .A13(local_addr[13]), .A14(local_addr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rd3[0]), .DOA1(rd3[1]), .DOA2(rd3[2]), .DOA3(rd3[3]),
        .DOA4(rd3[4]), .DOA5(rd3[5]), .DOA6(rd3[6]), .DOA7(rd3[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(we & sel3_w)),
        .CKA(clk), .CKB(clk),
        .CSA(rst_n & sel3), .CSB(sel3_w),
        .OEA(1'b1), .OEB(1'b0)
    );
    FMI180_19456X8 u_mem4 (
        .A0(local_addr[0]),   .A1(local_addr[1]),   .A2(local_addr[2]),
        .A3(local_addr[3]),   .A4(local_addr[4]),   .A5(local_addr[5]),
        .A6(local_addr[6]),   .A7(local_addr[7]),   .A8(local_addr[8]),
        .A9(local_addr[9]),   .A10(local_addr[10]), .A11(local_addr[11]),
        .A12(local_addr[12]), .A13(local_addr[13]), .A14(local_addr[14]),
        .B0(local_waddr[0]),   .B1(local_waddr[1]),   .B2(local_waddr[2]),
        .B3(local_waddr[3]),   .B4(local_waddr[4]),   .B5(local_waddr[5]),
        .B6(local_waddr[6]),   .B7(local_waddr[7]),   .B8(local_waddr[8]),
        .B9(local_waddr[9]),   .B10(local_waddr[10]), .B11(local_waddr[11]),
        .B12(local_waddr[12]), .B13(local_waddr[13]), .B14(local_waddr[14]),
        .DOA0(rd4[0]), .DOA1(rd4[1]), .DOA2(rd4[2]), .DOA3(rd4[3]),
        .DOA4(rd4[4]), .DOA5(rd4[5]), .DOA6(rd4[6]), .DOA7(rd4[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~(we & sel4_w)),
        .CKA(clk), .CKB(clk),
        .CSA(rst_n & sel4), .CSB(sel4_w),
        .OEA(1'b1), .OEB(1'b0)
    );
`else
    reg [`ACT_WIDTH-1:0] mem [0:DEPTH-1];
    assign rdata = mem[raddr];
    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end
`endif
endmodule

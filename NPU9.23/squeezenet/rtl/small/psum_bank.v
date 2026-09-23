`include "params.vh"

module psum_bank #(
    parameter DEPTH = 1
) (
    input  wire                          clk,
    input  wire                          we,
    input  wire [`PSUM_ADDR_WIDTH-1:0]   addr,
`ifdef SRAM_MACRO
    input  wire [`PSUM_ADDR_WIDTH-1:0]   raddr,
`endif
    input  wire signed [`ACC_WIDTH-1:0]  wdata,
    output wire signed [`ACC_WIDTH-1:0]  rdata
);
`ifdef SRAM_MACRO
    PSUM180_12352X32 u_mem (
        .A0(raddr[0]),   .A1(raddr[1]),   .A2(raddr[2]),   .A3(raddr[3]),
        .A4(raddr[4]),   .A5(raddr[5]),   .A6(raddr[6]),   .A7(raddr[7]),
        .A8(raddr[8]),   .A9(raddr[9]),   .A10(raddr[10]), .A11(raddr[11]),
        .A12(raddr[12]), .A13(raddr[13]),
        .B0(addr[0]),    .B1(addr[1]),    .B2(addr[2]),    .B3(addr[3]),
        .B4(addr[4]),    .B5(addr[5]),    .B6(addr[6]),    .B7(addr[7]),
        .B8(addr[8]),    .B9(addr[9]),    .B10(addr[10]),  .B11(addr[11]),
        .B12(addr[12]),  .B13(addr[13]),
        .DOA0(rdata[0]),   .DOA1(rdata[1]),   .DOA2(rdata[2]),   .DOA3(rdata[3]),
        .DOA4(rdata[4]),   .DOA5(rdata[5]),   .DOA6(rdata[6]),   .DOA7(rdata[7]),
        .DOA8(rdata[8]),   .DOA9(rdata[9]),   .DOA10(rdata[10]), .DOA11(rdata[11]),
        .DOA12(rdata[12]), .DOA13(rdata[13]), .DOA14(rdata[14]), .DOA15(rdata[15]),
        .DOA16(rdata[16]), .DOA17(rdata[17]), .DOA18(rdata[18]), .DOA19(rdata[19]),
        .DOA20(rdata[20]), .DOA21(rdata[21]), .DOA22(rdata[22]), .DOA23(rdata[23]),
        .DOA24(rdata[24]), .DOA25(rdata[25]), .DOA26(rdata[26]), .DOA27(rdata[27]),
        .DOA28(rdata[28]), .DOA29(rdata[29]), .DOA30(rdata[30]), .DOA31(rdata[31]),
        .DOB0(),  .DOB1(),  .DOB2(),  .DOB3(),  .DOB4(),  .DOB5(),  .DOB6(),  .DOB7(),
        .DOB8(),  .DOB9(),  .DOB10(), .DOB11(), .DOB12(), .DOB13(), .DOB14(), .DOB15(),
        .DOB16(), .DOB17(), .DOB18(), .DOB19(), .DOB20(), .DOB21(), .DOB22(), .DOB23(),
        .DOB24(), .DOB25(), .DOB26(), .DOB27(), .DOB28(), .DOB29(), .DOB30(), .DOB31(),
        .DIA0(1'b0),  .DIA1(1'b0),  .DIA2(1'b0),  .DIA3(1'b0),  .DIA4(1'b0),  .DIA5(1'b0),
        .DIA6(1'b0),  .DIA7(1'b0),  .DIA8(1'b0),  .DIA9(1'b0),  .DIA10(1'b0), .DIA11(1'b0),
        .DIA12(1'b0), .DIA13(1'b0), .DIA14(1'b0), .DIA15(1'b0), .DIA16(1'b0), .DIA17(1'b0),
        .DIA18(1'b0), .DIA19(1'b0), .DIA20(1'b0), .DIA21(1'b0), .DIA22(1'b0), .DIA23(1'b0),
        .DIA24(1'b0), .DIA25(1'b0), .DIA26(1'b0), .DIA27(1'b0), .DIA28(1'b0), .DIA29(1'b0),
        .DIA30(1'b0), .DIA31(1'b0),
        .DIB0(wdata[0]),   .DIB1(wdata[1]),   .DIB2(wdata[2]),   .DIB3(wdata[3]),
        .DIB4(wdata[4]),   .DIB5(wdata[5]),   .DIB6(wdata[6]),   .DIB7(wdata[7]),
        .DIB8(wdata[8]),   .DIB9(wdata[9]),   .DIB10(wdata[10]), .DIB11(wdata[11]),
        .DIB12(wdata[12]), .DIB13(wdata[13]), .DIB14(wdata[14]), .DIB15(wdata[15]),
        .DIB16(wdata[16]), .DIB17(wdata[17]), .DIB18(wdata[18]), .DIB19(wdata[19]),
        .DIB20(wdata[20]), .DIB21(wdata[21]), .DIB22(wdata[22]), .DIB23(wdata[23]),
        .DIB24(wdata[24]), .DIB25(wdata[25]), .DIB26(wdata[26]), .DIB27(wdata[27]),
        .DIB28(wdata[28]), .DIB29(wdata[29]), .DIB30(wdata[30]), .DIB31(wdata[31]),
        .WEAN(1'b1), .WEBN(~we),
        .CKA(clk), .CKB(clk),
        .CSA(1'b1), .CSB(we),
        .OEA(1'b1), .OEB(1'b0)
    );
`else
    reg signed [`ACC_WIDTH-1:0] mem [0:DEPTH-1];
    assign rdata = mem[addr];
    always @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;
    end
`endif
endmodule

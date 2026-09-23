`include "params.vh"

module fmap_out_bank #(
    parameter DEPTH = 1
) (
    input  wire                        clk,
    input  wire                        we,
    input  wire [`FMAP_ADDR_WIDTH-1:0] waddr,
    input  wire [`OUT_WIDTH-1:0]       wdata,
    input  wire [`FMAP_ADDR_WIDTH-1:0] raddr,
    output wire [`OUT_WIDTH-1:0]       rdata
);
`ifdef SRAM_MACRO
    FMO180_24642X8 u_mem (
        .A0(raddr[0]),   .A1(raddr[1]),   .A2(raddr[2]),   .A3(raddr[3]),
        .A4(raddr[4]),   .A5(raddr[5]),   .A6(raddr[6]),   .A7(raddr[7]),
        .A8(raddr[8]),   .A9(raddr[9]),   .A10(raddr[10]), .A11(raddr[11]),
        .A12(raddr[12]), .A13(raddr[13]), .A14(raddr[14]),
        .B0(waddr[0]),   .B1(waddr[1]),   .B2(waddr[2]),   .B3(waddr[3]),
        .B4(waddr[4]),   .B5(waddr[5]),   .B6(waddr[6]),   .B7(waddr[7]),
        .B8(waddr[8]),   .B9(waddr[9]),   .B10(waddr[10]), .B11(waddr[11]),
        .B12(waddr[12]), .B13(waddr[13]), .B14(waddr[14]),
        .DOA0(rdata[0]), .DOA1(rdata[1]), .DOA2(rdata[2]), .DOA3(rdata[3]),
        .DOA4(rdata[4]), .DOA5(rdata[5]), .DOA6(rdata[6]), .DOA7(rdata[7]),
        .DOB0(), .DOB1(), .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(),
        .DIA0(1'b0), .DIA1(1'b0), .DIA2(1'b0), .DIA3(1'b0),
        .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
        .DIB0(wdata[0]), .DIB1(wdata[1]), .DIB2(wdata[2]), .DIB3(wdata[3]),
        .DIB4(wdata[4]), .DIB5(wdata[5]), .DIB6(wdata[6]), .DIB7(wdata[7]),
        .WEAN(1'b1), .WEBN(~we),
        .CKA(clk), .CKB(clk),
        .CSA(1'b1), .CSB(we),
        .OEA(1'b1), .OEB(1'b0)
    );
`else
    reg [`OUT_WIDTH-1:0] mem [0:DEPTH-1];
    assign rdata = mem[raddr];
    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end
`endif
endmodule

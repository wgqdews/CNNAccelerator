`timescale 1ns / 1ps
`include "../../inc/config.vh"
module tb;

logic clk;
always #5 clk=~clk;
logic rst_n;

logic wr_en,rd_en;

logic [`DATA_WIDTH-1:0] i_data [0:150527];
logic [`DATA_WIDTH-1:0] i_pixel[`sramnum-1:0];
logic [`DATA_WIDTH-1:0] o_pixel[`sramnum-1:0];
logic [`ADDR_WIDTH-1:0] wr_addr [`sramnum-1:0];
logic [`ADDR_WIDTH-1:0] rd_addr [`sramnum-1:0];

integer i;

logic S;
logic k;
logic [`ADDR_WIDTH-1:0]img_size;
logic mod;
logic vld;

initial begin
    $dumpfile("wave1.vcd");
    $dumpvars(0, tb);
    $readmemh("../../input/input_0.txt", i_data, 0, 150527);
    
    clk   = 0;
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    //test
    mod=1;

    for (i = 0; i < `sramnum; i = i + 1) begin
        i_pixel[i] = 0;
        wr_addr[i] = 0;
        rd_addr[i] = 0;
    end
    #20;
    rst_n = 1;
    vld   = 1; 
    wr_en = 1;
    for (i = 0; i < 50176; i = i + 1) begin
        wr_addr[0] <= i;
        i_pixel[0] <= i_data[i];
        wr_addr[1] <= i;
        i_pixel[1] <= i_data[i+50176];
        wr_addr[2] <= i;
        i_pixel[2] <= i_data[i+100352];
        @(posedge clk);
    end
    $display("test done");
    $finish;
end
    sram_1r1w_bank sram(
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(i_pixel),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(o_pixel)
    );
    control c(
        .mod(mod),
        .S(S),
        .k(k),
        .img_size(img_size),
        .vld()
    );
    coord_gen u_coord (
        .i_clk   (clk),
        .i_rst_n (rst_n),
        .img_size(img_size),
        .i_vld   (vld),
        .coord(),
        .o_done()
    );
endmodule

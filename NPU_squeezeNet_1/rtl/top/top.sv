`timescale 1ns/1ps
`include "../../inc/config.vh"

module top #(
    parameter N = 9,
    parameter M = 4
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          i_vld,
    input  wire signed [`DATA_WIDTH-1:0] i_pixel,
    input  wire signed [`DATA_WIDTH-1:0] i_weight [0:N-1][0:M-1],
    input  wire signed [`ADD_WIDTH-1:0]  i_add    [0:M-1],
    input  wire        [`DATA_WIDTH-1:0] i_bias   [0:M-1],

    output wire [`ADDR_WIDTH-1:0]        o_x,
    output wire [`ADDR_WIDTH:0]          o_y,
    output wire                          o_vld,          // conv_data_path 的 vld，未對齊 out 的延遲
    output wire [`MUL_WIDTH-1:0]         out      [0:M-1]
);

    // ---- internal wires ----
    wire [`DATA_WIDTH-1:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;
    wire [`ADDR_WIDTH-1:0] w_mid_x;
    wire [`ADDR_WIDTH-1:0] w_mid_y;
    wire data_path_vld;

    wire signed [`DATA_WIDTH-1:0] tmp_pixel    [0:N-1];
    wire         [`DATA_WIDTH-1:0] skewed_pixel [0:N-1];

    wire signed [`DATA_WIDTH-1:0] o_pixel [0:N-1];
    wire signed [`ADD_WIDTH-1:0]  o_add   [0:M-1];

    // ---- pixel remap (九宮格 -> 陣列順序) ----
    assign tmp_pixel[8] = p11;
    assign tmp_pixel[7] = p12;
    assign tmp_pixel[6] = p13;
    assign tmp_pixel[5] = p21;
    assign tmp_pixel[4] = p22;
    assign tmp_pixel[3] = p23;
    assign tmp_pixel[2] = p31;
    assign tmp_pixel[1] = p32;
    assign tmp_pixel[0] = p33;

    // ---- 座標產生 ----
    coord_gen u_coord (
        .i_clk   (clk),
        .i_rst_n (rst_n),
        .img_w   (`img_W),
        .img_h   (`img_H),
        .i_vld   (i_vld),
        .r_x_cnt (o_x),
        .r_y_cnt (o_y)
    );

    // ---- 九宮格資料路徑 ----
    conv_data_path u_path (
        .i_clk    (clk),
        .i_rst_n  (rst_n),
        .img_w    (`img_W),
        .img_h    (`img_H),
        .i_x_cnt  (o_x),
        .i_y_cnt  (o_y),
        .i_vld    (i_vld),
        .i_pixel  (i_pixel),
        .o_p11(p11), .o_p12(p12), .o_p13(p13),
        .o_p21(p21), .o_p22(p22), .o_p23(p23),
        .o_p31(p31), .o_p32(p32), .o_p33(p33),
        .o_sync_x (w_mid_x),
        .o_sync_y (w_mid_y),
        .o_vld    (data_path_vld)
    );

    assign o_vld = data_path_vld;

    // ---- skew 延遲對齊 ----
    skew_delay #(
        .N(N)
    ) u_skew (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_pixel (tmp_pixel),
        .o_pixel (skewed_pixel)
    );

    // ---- PE 陣列運算 ----
    PE_Array #(
        .N(N),
        .M(M)
    ) u_pe (
        .clk      (clk),
        .rst_n    (rst_n),
        .i_pixel  (skewed_pixel),
        .i_weight (i_weight),
        .i_add    (i_add),
        .o_pixel  (o_pixel),
        .o_add    (o_add)
    );

    // ---- 加 bias 輸出 ----
    PE_array_output #(
        .M(M)
    ) u_o (
        .i_add  (o_add),
        .i_bias (i_bias),
        .out    (out)
    );

endmodule
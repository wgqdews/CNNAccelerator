`timescale 1ns/1ps
`include "../../inc/config.vh"

module tb_top;

    parameter N = 9;
    parameter M = 4;

    reg clk;
    reg rst_n;
    reg i_vld;

    reg signed [`DATA_WIDTH-1:0] kernel [0:35];
    reg signed [`DATA_WIDTH-1:0] i_data [0:783];
    reg signed [`DATA_WIDTH-1:0] i_bias_mem [0:3];

    reg signed [`DATA_WIDTH-1:0] i_pixel;
    reg signed [`DATA_WIDTH-1:0] i_weight [0:N-1][0:M-1];
    reg signed [`ADD_WIDTH-1:0]  i_add    [0:M-1];
    reg        [`DATA_WIDTH-1:0] i_bias   [0:M-1];

    wire [`ADDR_WIDTH-1:0] o_x;
    wire [`ADDR_WIDTH:0]   o_y;
    wire                   o_vld;
    wire [`MUL_WIDTH-1:0]  out [0:M-1];

    integer i, j;
    integer pix_idx;

    top #(
        .N(N),
        .M(M)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .i_vld    (i_vld),
        .i_pixel  (i_pixel),
        .i_weight (i_weight),
        .i_add    (i_add),
        .i_bias   (i_bias),
        .o_x      (o_x),
        .o_y      (o_y),
        .o_vld    (o_vld),
        .out      (out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        $readmemh("../input/conv_weights.txt", kernel);
        $readmemh("../input/input.txt", i_data);
        $readmemh("../input/conv_bias.txt", i_bias_mem);

        clk   = 0;
        rst_n = 0;
        i_vld = 0;

        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < M; j = j + 1) begin
                i_weight[N-i-1][j] = kernel[i + 9*j];
                i_add[j] = 0;
            end
        end

        for (j = 0; j < M; j = j + 1) begin
            i_bias[j] = i_bias_mem[j];
        end

        #20;
        rst_n = 1;

        for (pix_idx = 0; pix_idx < 784; pix_idx = pix_idx + 1) begin
            i_pixel <= i_data[pix_idx];
            i_vld   <= 1'b1;
            @(posedge clk);
        end

        i_vld <= 1'b0;

        #200;
        $finish;
    end

endmodule
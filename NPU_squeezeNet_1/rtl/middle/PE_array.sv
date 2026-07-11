`include "../../inc/config.vh"

module PE_Array #(
    parameter N = 9,   // number of rows
    parameter M = 4    // number of columns
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire signed [`DATA_WIDTH-1:0] i_pixel [0:N-1],
    input  wire signed [`DATA_WIDTH-1:0] i_weight [0:N-1][0:M-1],
    input  wire signed [`ADD_WIDTH-1:0]  i_add   [0:M-1],
    output wire signed [`DATA_WIDTH-1:0] o_pixel [0:N-1],
    output wire signed [`ADD_WIDTH-1:0]  o_add   [0:M-1]
);


    wire signed [`DATA_WIDTH-1:0] w_pixel [0:N-1][0:M];
    wire signed [`ADD_WIDTH-1:0]  w_add   [0:N][0:M-1];

    genvar r, c;
    
    generate
        for (c = 0; c < M; c = c + 1) begin : add_io_gen
            assign w_add[0][c] = i_add[c];   // 最上面一列的初始 add 輸入
            assign o_add[c]    = w_add[N][c]; // 最下面一列的輸出接到 o_add
        end
        for (r = 0; r < N; r = r + 1) begin : row_gen
            // Connect array inputs to stage 0
            assign w_pixel[r][0] = i_pixel[r];

            for (c = 0; c < M; c = c + 1) begin : col_gen
                PE u_pe (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .i_pixel (w_pixel[r][c]),
                    .i_weight(i_weight[r][c]),
                    .i_add   (w_add[r][c]),
                    .o_pixel (w_pixel[r][c+1]),
                    .o_add   (w_add[r+1][c])
                );
            end

            // Connect last stage to array outputs
            assign o_pixel[r] = w_pixel[r][M];
        end
    endgenerate

endmodule
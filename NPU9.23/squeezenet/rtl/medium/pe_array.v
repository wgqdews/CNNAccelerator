`include "params.vh"

module pe_array (
    input  wire                                          clk,
    input  wire                                          rst_n,

    input  wire                                          load_row_en,
    input  wire [`ROW_IDX_WIDTH-1:0]                     load_row_idx,
    input  wire signed [`ARRAY_COLS*`WGT_WIDTH-1:0]      load_row_data_flat,

    input  wire                                          shadow_load_row_en,
    input  wire [`ROW_IDX_WIDTH-1:0]                     shadow_load_row_idx,
    input  wire signed [`ARRAY_COLS*`WGT_WIDTH-1:0]      shadow_load_row_data_flat,

    input  wire                                          swap_all,

    input  wire signed [`ARRAY_ROWS*`ACT_SIGNED_WIDTH-1:0] act_in_flat,

    output wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]      psum_out_flat
);
    genvar r, c;


    wire signed [`ACT_SIGNED_WIDTH-1:0] act_wire [0:`ARRAY_ROWS-1][0:`ARRAY_COLS];
    wire signed [`ACC_WIDTH-1:0]        psum_wire [0:`ARRAY_ROWS][0:`ARRAY_COLS-1];

    generate
        for (r = 0; r < `ARRAY_ROWS; r = r + 1) begin : row_in
            assign act_wire[r][0] = act_in_flat[(r+1)*`ACT_SIGNED_WIDTH-1 -: `ACT_SIGNED_WIDTH];
        end
        for (c = 0; c < `ARRAY_COLS; c = c + 1) begin : col_in
            assign psum_wire[0][c] = {`ACC_WIDTH{1'b0}};
        end

        for (r = 0; r < `ARRAY_ROWS; r = r + 1) begin : gen_row
            for (c = 0; c < `ARRAY_COLS; c = c + 1) begin : gen_col
                pe u_pe (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .weight_load (load_row_en && (load_row_idx == r[`ROW_IDX_WIDTH-1:0])),
                    .w_in        (load_row_data_flat[(c+1)*`WGT_WIDTH-1 -: `WGT_WIDTH]),
                    .shadow_load (shadow_load_row_en && (shadow_load_row_idx == r[`ROW_IDX_WIDTH-1:0])),
                    .shadow_w_in (shadow_load_row_data_flat[(c+1)*`WGT_WIDTH-1 -: `WGT_WIDTH]),
                    .swap        (swap_all),
                    .act_in      (act_wire[r][c]),
                    .psum_in     (psum_wire[r][c]),
                    .act_out     (act_wire[r][c+1]),
                    .psum_out    (psum_wire[r+1][c])
                );
            end
        end

        for (c = 0; c < `ARRAY_COLS; c = c + 1) begin : col_out
            assign psum_out_flat[(c+1)*`ACC_WIDTH-1 -: `ACC_WIDTH] = psum_wire[`ARRAY_ROWS][c];
        end
    endgenerate
endmodule

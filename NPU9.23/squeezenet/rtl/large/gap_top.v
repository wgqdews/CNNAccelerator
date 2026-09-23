`include "params.vh"

module gap_top (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire done,

    input  wire [`CNT_WIDTH-1:0]           cfg_h_in,
    input  wire [`CNT_WIDTH-1:0]           cfg_w_in,
    input  wire [`CNT_WIDTH-1:0]           cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0]           cfg_act_zp,
    input  wire [`CNT_WIDTH-1:0]           cfg_y_zp,
    input  wire [`REQUANT_MULT_WIDTH-1:0]  cfg_mult,
    input  wire [`REQUANT_SHIFT_WIDTH-1:0] cfg_shift,

    output wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] raddr_in_flat,
    input  wire [`ARRAY_COLS*`ACT_WIDTH-1:0]       rdata_in_flat,

    output wire [`ARRAY_COLS-1:0]                  we_out_flat,
    output wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] waddr_out_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       wdata_out_flat
);
    wire [`CNT_WIDTH-1:0] spatial_idx, n_tile, n_tile_d;
    wire                   commit;

    gap_ctrl_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_h_in(cfg_h_in), .cfg_w_in(cfg_w_in), .cfg_n_tiles(cfg_n_tiles),
        .spatial_idx(spatial_idx), .n_tile(n_tile), .n_tile_d(n_tile_d), .commit(commit)
    );

    genvar i;
    generate
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : lane
            gap_lane u_gap_lane (
                .clk(clk), .rst_n(rst_n),
                .spatial_idx(spatial_idx), .n_tile(n_tile), .n_tile_d(n_tile_d), .commit(commit),
                .cfg_n_tiles(cfg_n_tiles), .cfg_act_zp(cfg_act_zp), .cfg_y_zp(cfg_y_zp),
                .cfg_mult(cfg_mult), .cfg_shift(cfg_shift),
                .rdata_in(rdata_in_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH]),
                .raddr_in(raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .we_out(we_out_flat[i]),
                .waddr_out(waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata_out(wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH])
            );
        end
    endgenerate
endmodule

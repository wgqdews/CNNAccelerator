`include "params.vh"

module maxpool_top (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire done,

    input  wire [`CNT_WIDTH-1:0] cfg_h_in,
    input  wire [`CNT_WIDTH-1:0] cfg_w_in,
    input  wire [`CNT_WIDTH-1:0] cfg_h_out,
    input  wire [`CNT_WIDTH-1:0] cfg_w_out,
    input  wire [`CNT_WIDTH-1:0] cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0] cfg_kh,
    input  wire [`CNT_WIDTH-1:0] cfg_kw,
    input  wire [`CNT_WIDTH-1:0] cfg_stride,
    input  wire [`CNT_WIDTH-1:0] cfg_pad,

    input  wire                  cfg_fused,
    input  wire [`CNT_WIDTH-1:0] producer_n_tiles_done,

    output wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] raddr_in_flat,
    input  wire [`ARRAY_COLS*`ACT_WIDTH-1:0]       rdata_in_flat,

    output wire [`ARRAY_COLS-1:0]                  we_out_flat,
    output wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] waddr_out_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       wdata_out_flat
);
    wire [`CNT_WIDTH-1:0] oh, ow, tap, n_tile, oh_d, ow_d, n_tile_d;
    wire                   commit;

    maxpool_ctrl_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_h_out(cfg_h_out), .cfg_w_out(cfg_w_out), .cfg_n_tiles(cfg_n_tiles),
        .cfg_kh(cfg_kh), .cfg_kw(cfg_kw),
        .cfg_fused(cfg_fused), .producer_n_tiles_done(producer_n_tiles_done),
        .oh(oh), .ow(ow), .tap(tap), .n_tile(n_tile),
        .oh_d(oh_d), .ow_d(ow_d), .n_tile_d(n_tile_d), .commit(commit)
    );

    genvar i;
    generate
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : lane
            pool_lane u_pool_lane (
                .clk(clk), .rst_n(rst_n),
                .oh(oh), .ow(ow), .tap(tap), .n_tile(n_tile),
                .oh_d(oh_d), .ow_d(ow_d), .n_tile_d(n_tile_d), .commit(commit),
                .cfg_h_in(cfg_h_in), .cfg_w_in(cfg_w_in), .cfg_w_out(cfg_w_out),
                .cfg_kw(cfg_kw), .cfg_stride(cfg_stride), .cfg_pad(cfg_pad), .cfg_n_tiles(cfg_n_tiles),
                .rdata_in(rdata_in_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH]),
                .raddr_in(raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .we_out(we_out_flat[i]),
                .waddr_out(waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata_out(wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH])
            );
        end
    endgenerate
endmodule

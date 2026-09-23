`include "params.vh"


module post_process #(
    parameter NT_DEPTH = 1
) (
    input  wire                                      clk,
    input  wire                                      rst_n,

    input  wire [`CNT_WIDTH-1:0]                     cycle_cnt,
    input  wire [`CNT_WIDTH-1:0]                     n_tile,
    input  wire                                      is_first_k_tile,
    input  wire                                      is_last_k_tile,

    input  wire [`CNT_WIDTH-1:0]                     cfg_h_out,
    input  wire [`CNT_WIDTH-1:0]                     cfg_w_out,
    input  wire [`CNT_WIDTH-1:0]                     cfg_cout,
    input  wire [`CNT_WIDTH-1:0]                     cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0]                     cfg_y_zp,
    input  wire [`CNT_WIDTH-1:0]                     cfg_out_n_tile_offset,
    input  wire [`CNT_WIDTH-1:0]                     cfg_out_n_tiles_total,
    input  wire [`CNT_WIDTH-1:0]                     cfg_bias_base_offset,

    input  wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]  psum_col_flat,
    input  wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]  psum_rdata_flat,

    output wire [`ARRAY_COLS-1:0]                    we_psum,
    output wire [`ARRAY_COLS*`PSUM_ADDR_WIDTH-1:0]   addr_psum_flat,
`ifdef SRAM_MACRO
    output wire [`ARRAY_COLS*`PSUM_ADDR_WIDTH-1:0]   raddr_psum_flat,
`endif
    output wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]  wdata_psum_flat,

    output wire [`ARRAY_COLS-1:0]                    we_fmap,
    output wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0]   waddr_fmap_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]         wdata_fmap_flat,
    output wire [`ARRAY_COLS-1:0]                    we_fmap_dup
);
    genvar n;
    generate
        for (n = 0; n < `ARRAY_COLS; n = n + 1) begin : lane
            requant_lane #(.LANE(n), .NT_DEPTH(NT_DEPTH)) u_requant_lane (
                .clk             (clk),
                .rst_n           (rst_n),
                .cycle_cnt       (cycle_cnt),
                .n_tile          (n_tile),
                .is_first_k_tile (is_first_k_tile),
                .is_last_k_tile  (is_last_k_tile),
                .cfg_h_out       (cfg_h_out),
                .cfg_w_out       (cfg_w_out),
                .cfg_cout        (cfg_cout),
                .cfg_n_tiles     (cfg_n_tiles),
                .cfg_y_zp        (cfg_y_zp),
                .cfg_out_n_tile_offset (cfg_out_n_tile_offset),
                .cfg_out_n_tiles_total (cfg_out_n_tiles_total),
                .cfg_bias_base_offset  (cfg_bias_base_offset),
                .psum_col        (psum_col_flat[(n+1)*`ACC_WIDTH-1 -: `ACC_WIDTH]),
                .psum_rdata      (psum_rdata_flat[(n+1)*`ACC_WIDTH-1 -: `ACC_WIDTH]),
                .we_psum         (we_psum[n]),
                .addr_psum       (addr_psum_flat[(n+1)*`PSUM_ADDR_WIDTH-1 -: `PSUM_ADDR_WIDTH]),
`ifdef SRAM_MACRO
                .raddr_psum      (raddr_psum_flat[(n+1)*`PSUM_ADDR_WIDTH-1 -: `PSUM_ADDR_WIDTH]),
`endif
                .wdata_psum      (wdata_psum_flat[(n+1)*`ACC_WIDTH-1 -: `ACC_WIDTH]),
                .we_fmap         (we_fmap[n]),
                .waddr_fmap      (waddr_fmap_flat[(n+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata_fmap      (wdata_fmap_flat[(n+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]),
                .we_fmap_dup     (we_fmap_dup[n])
            );
        end
    endgenerate
endmodule

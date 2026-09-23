`include "params.vh"


module chain2_top (
    input  wire clk,
    input  wire rst_n,

    // ---- conv1 ----
    input  wire conv_start,
    output wire conv_done,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_cin,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_cout,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_h_in,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_w_in,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_kw,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_stride,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_pad,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_h_out,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_w_out,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_k_real,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_k_tiles,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_act_zp,
    input  wire [`CNT_WIDTH-1:0] conv_cfg_y_zp,

    input  wire pool_start,
    output wire pool_done,
    input  wire [`CNT_WIDTH-1:0] pool_cfg_h_out,
    input  wire [`CNT_WIDTH-1:0] pool_cfg_w_out,
    input  wire [`CNT_WIDTH-1:0] pool_cfg_kh,
    input  wire [`CNT_WIDTH-1:0] pool_cfg_kw,
    input  wire [`CNT_WIDTH-1:0] pool_cfg_stride,
    input  wire [`CNT_WIDTH-1:0] pool_cfg_pad,

    input  wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]        rd_data_b_flat
);
    // ---- conv1 ----
    wire [`ARRAY_COLS-1:0]                  conv_fmap_b_we;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] conv_fmap_b_waddr_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       conv_fmap_b_wdata_flat;

    wire [`CNT_WIDTH-1:0]                   conv_n_tiles_done;

    top_conv_layer u_conv1 (
        .clk(clk), .rst_n(rst_n), .start(conv_start), .done(conv_done),
        .cfg_cin(conv_cfg_cin), .cfg_cout(conv_cfg_cout),
        .cfg_h_in(conv_cfg_h_in), .cfg_w_in(conv_cfg_w_in), .cfg_kw(conv_cfg_kw),
        .cfg_stride(conv_cfg_stride), .cfg_pad(conv_cfg_pad),
        .cfg_h_out(conv_cfg_h_out), .cfg_w_out(conv_cfg_w_out),
        .cfg_k_real(conv_cfg_k_real), .cfg_k_tiles(conv_cfg_k_tiles), .cfg_n_tiles(conv_cfg_n_tiles),
        .cfg_act_zp(conv_cfg_act_zp), .cfg_y_zp(conv_cfg_y_zp),
        .cfg_out_n_tile_offset({`CNT_WIDTH{1'b0}}), .cfg_out_n_tiles_total(conv_cfg_n_tiles),
        .cfg_weight_base_offset({`WGT_ADDR_WIDTH{1'b0}}), .cfg_bias_base_offset({`CNT_WIDTH{1'b0}}),
        .cfg_input_mode(1'b0), .fmap_a_addr_out_flat(),
        .fmap_a_rdata_ext_flat({(`ARRAY_ROWS*`ACT_WIDTH){1'b0}}),
        .fmap_a_we({`ARRAY_ROWS{1'b0}}), .fmap_a_waddr_flat({(`ARRAY_ROWS*`FMAP_ADDR_WIDTH){1'b0}}),
        .fmap_a_wdata_flat({(`ARRAY_ROWS*`ACT_WIDTH){1'b0}}),
        .wgt_we({`ARRAY_COLS{1'b0}}),
        .wgt_waddr_flat({(`ARRAY_COLS*`WGT_ADDR_WIDTH){1'b0}}),
        .wgt_wdata_flat({(`ARRAY_COLS*`WGT_WIDTH){1'b0}}),
        .rd_addr_b_flat({(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}}),
        .rd_data_b_flat(),
        .fmap_b_we_out(conv_fmap_b_we),
        .fmap_b_waddr_out_flat(conv_fmap_b_waddr_flat),
        .fmap_b_wdata_out_flat(conv_fmap_b_wdata_flat),
        .fmap_b_we_dup_out(),
        .n_tiles_done(conv_n_tiles_done)
    );

    wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] pool_raddr_in_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       pool_rdata_in_flat;

    genvar i;
    generate
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : buf0
            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk),
                .we(conv_fmap_b_we[i]),
                .waddr(conv_fmap_b_waddr_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata(conv_fmap_b_wdata_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]),
                .raddr(pool_raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata(pool_rdata_in_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH])
            );
        end
    endgenerate

    wire [`ARRAY_COLS-1:0]                  pool_we_out_flat;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] pool_waddr_out_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       pool_wdata_out_flat;

    maxpool_top u_maxpool (
        .clk(clk), .rst_n(rst_n), .start(pool_start), .done(pool_done),
        .cfg_h_in(conv_cfg_h_out), .cfg_w_in(conv_cfg_w_out),   
        .cfg_h_out(pool_cfg_h_out), .cfg_w_out(pool_cfg_w_out),
        .cfg_n_tiles(conv_cfg_n_tiles),                          
        .cfg_kh(pool_cfg_kh), .cfg_kw(pool_cfg_kw),
        .cfg_stride(pool_cfg_stride), .cfg_pad(pool_cfg_pad),
        .cfg_fused(1'b1), .producer_n_tiles_done(conv_n_tiles_done),
        .raddr_in_flat(pool_raddr_in_flat), .rdata_in_flat(pool_rdata_in_flat),
        .we_out_flat(pool_we_out_flat), .waddr_out_flat(pool_waddr_out_flat), .wdata_out_flat(pool_wdata_out_flat)
    );

    generate
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : buf1
            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk),
                .we(pool_we_out_flat[i]),
                .waddr(pool_waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata(pool_wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]),
                .raddr(rd_addr_b_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata(rd_data_b_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH])
            );
        end
    endgenerate
endmodule

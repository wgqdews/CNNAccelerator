`include "params.vh"

module top_conv_layer (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire done,

    input  wire [`CNT_WIDTH-1:0] cfg_cin,
    input  wire [`CNT_WIDTH-1:0] cfg_cout,
    input  wire [`CNT_WIDTH-1:0] cfg_h_in,
    input  wire [`CNT_WIDTH-1:0] cfg_w_in,
    input  wire [`CNT_WIDTH-1:0] cfg_kw,
    input  wire [`CNT_WIDTH-1:0] cfg_stride,
    input  wire [`CNT_WIDTH-1:0] cfg_pad,
    input  wire [`CNT_WIDTH-1:0] cfg_h_out,
    input  wire [`CNT_WIDTH-1:0] cfg_w_out,
    input  wire [`CNT_WIDTH-1:0] cfg_k_real,
    input  wire [`CNT_WIDTH-1:0] cfg_k_tiles,
    input  wire [`CNT_WIDTH-1:0] cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0] cfg_act_zp,
    input  wire [`CNT_WIDTH-1:0] cfg_y_zp,

    input  wire [`CNT_WIDTH-1:0] cfg_out_n_tile_offset,
    input  wire [`CNT_WIDTH-1:0] cfg_out_n_tiles_total,
    input  wire [`WGT_ADDR_WIDTH-1:0] cfg_weight_base_offset,
    input  wire [`CNT_WIDTH-1:0]      cfg_bias_base_offset,

    input  wire cfg_input_mode,
    input  wire [`CNT_WIDTH-1:0] cfg_pack_factor,
    input  wire [`CNT_WIDTH-1:0] cfg_pack_remainder,
    input  wire [`CNT_WIDTH-1:0] cfg_pack_base_group,
    output wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] fmap_a_addr_out_flat,
    input  wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       fmap_a_rdata_ext_flat,

    input  wire [`ARRAY_ROWS-1:0]                   fmap_a_we,
    input  wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0]  fmap_a_waddr_flat,
    input  wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]        fmap_a_wdata_flat,

    input  wire [`ARRAY_COLS-1:0]                   wgt_we,
    input  wire [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0]   wgt_waddr_flat,
    input  wire [`ARRAY_COLS*`WGT_WIDTH-1:0]        wgt_wdata_flat,

    input  wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]        rd_data_b_flat,

    output wire [`ARRAY_COLS-1:0]                   fmap_b_we_out,
    output wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0]  fmap_b_waddr_out_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]        fmap_b_wdata_out_flat,

    output wire [`ARRAY_COLS-1:0]                   fmap_b_we_dup_out,

    output wire [`CNT_WIDTH-1:0]                    n_tiles_done
);

    wire [`ROW_IDX_WIDTH-1:0]  load_row_idx;
    wire                       load_row_en;
    wire [`WGT_ADDR_WIDTH-1:0] weight_row_index;
    wire [`ROW_IDX_WIDTH-1:0]  shadow_load_row_idx;
    wire                       shadow_load_row_en;
    wire                       swap_all;
    wire [`CNT_WIDTH-1:0]      oh, ow, cycle_cnt, n_tile, k_tile;
    wire                       is_first_k_tile, is_last_k_tile;

    conv_ctrl_fsm u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_k_tiles(cfg_k_tiles), .cfg_n_tiles(cfg_n_tiles),
        .cfg_h_out(cfg_h_out), .cfg_w_out(cfg_w_out),
        .cfg_weight_base_offset(cfg_weight_base_offset),
        .load_row_en(load_row_en), .load_row_idx(load_row_idx),
        .weight_row_index(weight_row_index),
        .shadow_load_row_en(shadow_load_row_en), .shadow_load_row_idx(shadow_load_row_idx),
        .swap_all(swap_all),
        .oh(oh), .ow(ow), .cycle_cnt(cycle_cnt), .streaming(),
        .n_tile(n_tile), .k_tile(k_tile),
        .is_first_k_tile(is_first_k_tile), .is_last_k_tile(is_last_k_tile),
        .n_tiles_done(n_tiles_done)
    );

    wire [`ARRAY_COLS*`WGT_WIDTH-1:0] weight_row_data_flat;

`ifdef SRAM_MACRO
    reg                        load_row_en_d;
    reg  [`ROW_IDX_WIDTH-1:0]  load_row_idx_d;
    reg                        shadow_load_row_en_d;
    reg  [`ROW_IDX_WIDTH-1:0]  shadow_load_row_idx_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_row_en_d          <= 1'b0;
            load_row_idx_d         <= {`ROW_IDX_WIDTH{1'b0}};
            shadow_load_row_en_d   <= 1'b0;
            shadow_load_row_idx_d  <= {`ROW_IDX_WIDTH{1'b0}};
        end else begin
            load_row_en_d          <= load_row_en;
            load_row_idx_d         <= load_row_idx;
            shadow_load_row_en_d   <= shadow_load_row_en;
            shadow_load_row_idx_d  <= shadow_load_row_idx;
        end
    end
    wire                       pe_load_row_en          = load_row_en_d;
    wire [`ROW_IDX_WIDTH-1:0]  pe_load_row_idx         = load_row_idx_d;
    wire                       pe_shadow_load_row_en   = shadow_load_row_en_d;
    wire [`ROW_IDX_WIDTH-1:0]  pe_shadow_load_row_idx  = shadow_load_row_idx_d;
`else
    wire                       pe_load_row_en          = load_row_en;
    wire [`ROW_IDX_WIDTH-1:0]  pe_load_row_idx         = load_row_idx;
    wire                       pe_shadow_load_row_en   = shadow_load_row_en;
    wire [`ROW_IDX_WIDTH-1:0]  pe_shadow_load_row_idx  = shadow_load_row_idx;
`endif

    weight_sram #(.BANK_DEPTH(`MAX_WGT_BANK_DEPTH)) u_weight_sram (
        .clk(clk), .rst_n(rst_n),
        .we(wgt_we), .waddr_flat(wgt_waddr_flat), .wdata_flat(wgt_wdata_flat),
        .row_index(weight_row_index),
        .row_data_flat(weight_row_data_flat)
    );

    wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0]   fmap_a_addr_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]         fmap_a_raw_internal_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]         fmap_a_raw_muxed_flat;
    wire signed [`ARRAY_ROWS*`ACT_SIGNED_WIDTH-1:0] act_signed_flat;

    assign fmap_a_addr_out_flat  = fmap_a_addr_flat;
    assign fmap_a_raw_muxed_flat = cfg_input_mode ? fmap_a_rdata_ext_flat : fmap_a_raw_internal_flat;

    im2col_addr_gen u_im2col (
`ifdef SRAM_MACRO
        .clk(clk), .rst_n(rst_n),
`endif
        .oh(oh), .ow(ow), .k_tile(k_tile),
        .cfg_cin(cfg_cin), .cfg_kw(cfg_kw), .cfg_stride(cfg_stride), .cfg_pad(cfg_pad),
        .cfg_h_in(cfg_h_in), .cfg_w_in(cfg_w_in), .cfg_k_real(cfg_k_real), .cfg_act_zp(cfg_act_zp),
        .cfg_input_mode(cfg_input_mode),
        .cfg_pack_factor(cfg_pack_factor),
        .cfg_pack_remainder(cfg_pack_remainder),
        .cfg_pack_base_group(cfg_pack_base_group),
        .raw_data_flat(fmap_a_raw_muxed_flat),
        .addr_flat(fmap_a_addr_flat),
        .act_signed_flat(act_signed_flat)
    );

    wire signed [`ARRAY_ROWS*`ACT_SIGNED_WIDTH-1:0] act_skewed_flat;

    skew_buffer u_skew (
        .clk(clk), .rst_n(rst_n),
        .data_in_flat(act_signed_flat),
        .data_out_flat(act_skewed_flat)
    );

    wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0] psum_col_flat;

    pe_array u_pe_array (
        .clk(clk), .rst_n(rst_n),
        .load_row_en(pe_load_row_en), .load_row_idx(pe_load_row_idx),
        .load_row_data_flat(weight_row_data_flat),

        .shadow_load_row_en(pe_shadow_load_row_en), .shadow_load_row_idx(pe_shadow_load_row_idx),
        .shadow_load_row_data_flat(weight_row_data_flat),
        .swap_all(swap_all),
        .act_in_flat(act_skewed_flat),
        .psum_out_flat(psum_col_flat)
    );

    wire [`ARRAY_COLS-1:0]                    psum_we;
    wire [`ARRAY_COLS*`PSUM_ADDR_WIDTH-1:0]   psum_addr_flat;
`ifdef SRAM_MACRO
    wire [`ARRAY_COLS*`PSUM_ADDR_WIDTH-1:0]   psum_raddr_flat;
`endif
    wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]  psum_wdata_flat, psum_rdata_flat;

    psum_sram #(.DEPTH(`MAX_PSUM_BANK_DEPTH)) u_psum_sram (
        .clk(clk),
        .we(psum_we), .addr_flat(psum_addr_flat),
`ifdef SRAM_MACRO
        .raddr_flat(psum_raddr_flat),
`endif
        .wdata_flat(psum_wdata_flat), .rdata_flat(psum_rdata_flat)
    );

    wire [`ARRAY_COLS-1:0]                  fmap_b_we;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] fmap_b_waddr_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       fmap_b_wdata_flat;
    wire [`ARRAY_COLS-1:0]                  fmap_b_we_dup;

    post_process #(.NT_DEPTH(`MAX_N_TILES)) u_post_process (
        .clk(clk), .rst_n(rst_n),
        .cycle_cnt(cycle_cnt), .n_tile(n_tile),
        .is_first_k_tile(is_first_k_tile), .is_last_k_tile(is_last_k_tile),
        .cfg_h_out(cfg_h_out), .cfg_w_out(cfg_w_out), .cfg_cout(cfg_cout),
        .cfg_n_tiles(cfg_n_tiles), .cfg_y_zp(cfg_y_zp),
        .cfg_out_n_tile_offset(cfg_out_n_tile_offset), .cfg_out_n_tiles_total(cfg_out_n_tiles_total),
        .cfg_bias_base_offset(cfg_bias_base_offset),
        .psum_col_flat(psum_col_flat), .psum_rdata_flat(psum_rdata_flat),
        .we_psum(psum_we), .addr_psum_flat(psum_addr_flat),
`ifdef SRAM_MACRO
        .raddr_psum_flat(psum_raddr_flat),
`endif
        .wdata_psum_flat(psum_wdata_flat),
        .we_fmap(fmap_b_we), .waddr_fmap_flat(fmap_b_waddr_flat), .wdata_fmap_flat(fmap_b_wdata_flat),
        .we_fmap_dup(fmap_b_we_dup)
    );

    assign fmap_b_we_out         = fmap_b_we;
    assign fmap_b_waddr_out_flat = fmap_b_waddr_flat;
    assign fmap_b_wdata_out_flat = fmap_b_wdata_flat;
    assign fmap_b_we_dup_out     = fmap_b_we_dup;

    fmap_sram #(.DEPTH_A(`MAX_FMAP_IN_BANK_DEPTH), .DEPTH_B(`MAX_FMAP_OUT_BANK_DEPTH)) u_fmap_sram (
        .clk(clk), .rst_n(rst_n),
        .we_a(fmap_a_we), .waddr_a_flat(fmap_a_waddr_flat), .wdata_a_flat(fmap_a_wdata_flat),
        .rd_addr_a_flat(fmap_a_addr_flat), .rd_data_a_flat(fmap_a_raw_internal_flat),
        .we_b(fmap_b_we), .waddr_b_flat(fmap_b_waddr_flat), .wdata_b_flat(fmap_b_wdata_flat),
        .rd_addr_b_flat(rd_addr_b_flat), .rd_data_b_flat(rd_data_b_flat)
    );
endmodule

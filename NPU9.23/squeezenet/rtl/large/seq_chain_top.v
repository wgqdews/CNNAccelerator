`include "params.vh"

module seq_chain_top (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire all_done,

    input  wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_a_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]        rd_data_a_flat,
    input  wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]        rd_data_b_flat,

    input  wire [`ARRAY_COLS-1:0]                  wgt_we,
    input  wire [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0]  wgt_waddr_flat,
    input  wire [`ARRAY_COLS*`WGT_WIDTH-1:0]       wgt_wdata_flat,
    input  wire [`ARRAY_ROWS-1:0]                  fmap_a_we,
    input  wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] fmap_a_waddr_flat,
    input  wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       fmap_a_wdata_flat
);

    wire                   conv_start, conv_done, conv_out_sel, conv_in_sel, conv_cfg_input_mode;
    wire [`CNT_WIDTH-1:0]  conv_cfg_cin, conv_cfg_cout, conv_cfg_h_in, conv_cfg_w_in, conv_cfg_kw,
                            conv_cfg_stride, conv_cfg_pad, conv_cfg_h_out, conv_cfg_w_out,
                            conv_cfg_k_real, conv_cfg_k_tiles, conv_cfg_n_tiles,
                            conv_cfg_act_zp, conv_cfg_y_zp,
                            conv_cfg_out_n_tile_offset, conv_cfg_out_n_tiles_total,
                            conv_cfg_bias_base_offset,
                            conv_cfg_pack_factor, conv_cfg_pack_remainder,
                            conv_cfg_pack_base_group, conv_cfg_replicate_remainder;
    wire [`WGT_ADDR_WIDTH-1:0] conv_cfg_weight_base_offset;


    wire                   pool_start, pool_done, pool_in_sel, pool_out_sel;
    wire [`CNT_WIDTH-1:0]  pool_cfg_h_in, pool_cfg_w_in, pool_cfg_n_tiles, pool_cfg_h_out,
                            pool_cfg_w_out, pool_cfg_kh, pool_cfg_kw, pool_cfg_stride, pool_cfg_pad;


    wire                   gap_start, gap_done, gap_in_sel, gap_out_sel;
    wire [`CNT_WIDTH-1:0]  gap_cfg_h_in, gap_cfg_w_in, gap_cfg_n_tiles, gap_cfg_act_zp, gap_cfg_y_zp;
    wire [`REQUANT_MULT_WIDTH-1:0]  gap_cfg_mult;
    wire [`REQUANT_SHIFT_WIDTH-1:0] gap_cfg_shift;

    wire [1:0] cur_op_type;

    layer_sequencer #(.N_STAGES(30), .N_CONV_STAGES(26), .N_POOL_STAGES(3), .N_GAP_STAGES(1)) u_seq (
        .clk(clk), .rst_n(rst_n), .start(start), .all_done(all_done),
        .cur_op_type(cur_op_type),
        .conv_start(conv_start), .conv_done(conv_done),
        .conv_cfg_cin(conv_cfg_cin), .conv_cfg_cout(conv_cfg_cout),
        .conv_cfg_h_in(conv_cfg_h_in), .conv_cfg_w_in(conv_cfg_w_in), .conv_cfg_kw(conv_cfg_kw),
        .conv_cfg_stride(conv_cfg_stride), .conv_cfg_pad(conv_cfg_pad),
        .conv_cfg_h_out(conv_cfg_h_out), .conv_cfg_w_out(conv_cfg_w_out),
        .conv_cfg_k_real(conv_cfg_k_real), .conv_cfg_k_tiles(conv_cfg_k_tiles),
        .conv_cfg_n_tiles(conv_cfg_n_tiles),
        .conv_cfg_act_zp(conv_cfg_act_zp), .conv_cfg_y_zp(conv_cfg_y_zp),
        .conv_cfg_out_n_tile_offset(conv_cfg_out_n_tile_offset),
        .conv_cfg_out_n_tiles_total(conv_cfg_out_n_tiles_total),
        .conv_cfg_input_mode(conv_cfg_input_mode),
        .conv_cfg_weight_base_offset(conv_cfg_weight_base_offset),
        .conv_cfg_bias_base_offset(conv_cfg_bias_base_offset),
        .conv_cfg_pack_factor(conv_cfg_pack_factor),
        .conv_cfg_pack_remainder(conv_cfg_pack_remainder),
        .conv_cfg_pack_base_group(conv_cfg_pack_base_group),
        .conv_cfg_replicate_remainder(conv_cfg_replicate_remainder),
        .conv_in_sel(conv_in_sel), .conv_out_sel(conv_out_sel),
        .pool_start(pool_start), .pool_done(pool_done),
        .pool_cfg_h_in(pool_cfg_h_in), .pool_cfg_w_in(pool_cfg_w_in), .pool_cfg_n_tiles(pool_cfg_n_tiles),
        .pool_cfg_h_out(pool_cfg_h_out), .pool_cfg_w_out(pool_cfg_w_out),
        .pool_cfg_kh(pool_cfg_kh), .pool_cfg_kw(pool_cfg_kw),
        .pool_cfg_stride(pool_cfg_stride), .pool_cfg_pad(pool_cfg_pad),
        .pool_in_sel(pool_in_sel), .pool_out_sel(pool_out_sel),
        .gap_start(gap_start), .gap_done(gap_done),
        .gap_cfg_h_in(gap_cfg_h_in), .gap_cfg_w_in(gap_cfg_w_in), .gap_cfg_n_tiles(gap_cfg_n_tiles),
        .gap_cfg_act_zp(gap_cfg_act_zp), .gap_cfg_y_zp(gap_cfg_y_zp),
        .gap_cfg_mult(gap_cfg_mult), .gap_cfg_shift(gap_cfg_shift),
        .gap_in_sel(gap_in_sel), .gap_out_sel(gap_out_sel)
    );

    wire [`ARRAY_COLS-1:0]                  conv_fmap_b_we;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] conv_fmap_b_waddr_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       conv_fmap_b_wdata_flat;
    wire [`ARRAY_COLS-1:0]                  conv_fmap_b_we_dup;
    wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] conv_fmap_a_addr_out_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       conv_fmap_a_rdata_ext_flat;

    top_conv_layer u_conv (
        .clk(clk), .rst_n(rst_n), .start(conv_start), .done(conv_done),
        .cfg_cin(conv_cfg_cin), .cfg_cout(conv_cfg_cout),
        .cfg_h_in(conv_cfg_h_in), .cfg_w_in(conv_cfg_w_in), .cfg_kw(conv_cfg_kw),
        .cfg_stride(conv_cfg_stride), .cfg_pad(conv_cfg_pad),
        .cfg_h_out(conv_cfg_h_out), .cfg_w_out(conv_cfg_w_out),
        .cfg_k_real(conv_cfg_k_real), .cfg_k_tiles(conv_cfg_k_tiles), .cfg_n_tiles(conv_cfg_n_tiles),
        .cfg_act_zp(conv_cfg_act_zp), .cfg_y_zp(conv_cfg_y_zp),
        .cfg_out_n_tile_offset(conv_cfg_out_n_tile_offset),
        .cfg_out_n_tiles_total(conv_cfg_out_n_tiles_total),
        .cfg_weight_base_offset(conv_cfg_weight_base_offset),
        .cfg_bias_base_offset(conv_cfg_bias_base_offset),
        .cfg_input_mode(conv_cfg_input_mode),
        .cfg_pack_factor(conv_cfg_pack_factor),
        .cfg_pack_remainder(conv_cfg_pack_remainder),
        .cfg_pack_base_group(conv_cfg_pack_base_group),
        .fmap_a_addr_out_flat(conv_fmap_a_addr_out_flat),
        .fmap_a_rdata_ext_flat(conv_fmap_a_rdata_ext_flat),

        .fmap_a_we(fmap_a_we), .fmap_a_waddr_flat(fmap_a_waddr_flat),
        .fmap_a_wdata_flat(fmap_a_wdata_flat),
        .wgt_we(wgt_we),
        .wgt_waddr_flat(wgt_waddr_flat),
        .wgt_wdata_flat(wgt_wdata_flat),
        .rd_addr_b_flat({(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}}),
        .rd_data_b_flat(),
        .fmap_b_we_out(conv_fmap_b_we),
        .fmap_b_waddr_out_flat(conv_fmap_b_waddr_flat),
        .fmap_b_wdata_out_flat(conv_fmap_b_wdata_flat),
        .fmap_b_we_dup_out(conv_fmap_b_we_dup)
    );

    wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] pool_raddr_in_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       pool_rdata_in_flat;
    wire [`ARRAY_COLS-1:0]                  pool_we_out_flat;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] pool_waddr_out_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       pool_wdata_out_flat;

    maxpool_top u_maxpool (
        .clk(clk), .rst_n(rst_n), .start(pool_start), .done(pool_done),
        .cfg_h_in(pool_cfg_h_in), .cfg_w_in(pool_cfg_w_in),
        .cfg_h_out(pool_cfg_h_out), .cfg_w_out(pool_cfg_w_out), .cfg_n_tiles(pool_cfg_n_tiles),
        .cfg_kh(pool_cfg_kh), .cfg_kw(pool_cfg_kw),
        .cfg_stride(pool_cfg_stride), .cfg_pad(pool_cfg_pad),

        .cfg_fused(1'b0), .producer_n_tiles_done({`CNT_WIDTH{1'b0}}),
        .raddr_in_flat(pool_raddr_in_flat), .rdata_in_flat(pool_rdata_in_flat),
        .we_out_flat(pool_we_out_flat), .waddr_out_flat(pool_waddr_out_flat), .wdata_out_flat(pool_wdata_out_flat)
    );

    wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] gap_raddr_in_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       gap_rdata_in_flat;
    wire [`ARRAY_COLS-1:0]                  gap_we_out_flat;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] gap_waddr_out_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       gap_wdata_out_flat;

    gap_top u_gap (
        .clk(clk), .rst_n(rst_n), .start(gap_start), .done(gap_done),
        .cfg_h_in(gap_cfg_h_in), .cfg_w_in(gap_cfg_w_in), .cfg_n_tiles(gap_cfg_n_tiles),
        .cfg_act_zp(gap_cfg_act_zp), .cfg_y_zp(gap_cfg_y_zp),
        .cfg_mult(gap_cfg_mult), .cfg_shift(gap_cfg_shift),
        .raddr_in_flat(gap_raddr_in_flat), .rdata_in_flat(gap_rdata_in_flat),
        .we_out_flat(gap_we_out_flat), .waddr_out_flat(gap_waddr_out_flat), .wdata_out_flat(gap_wdata_out_flat)
    );

    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0] bufA_rdata_flat, bufB_rdata_flat;

    wire out_sel_active = (cur_op_type == 2'd0) ? conv_out_sel :
                           (cur_op_type == 2'd1) ? pool_out_sel : gap_out_sel;
    wire in_sel_active  = (cur_op_type == 2'd0) ? conv_in_sel :
                           (cur_op_type == 2'd1) ? pool_in_sel : gap_in_sel;

    wire raddr_from_conv_valid = (cur_op_type == 2'd0) && (conv_cfg_input_mode == 1'b1);

    genvar i;
    generate
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : bufA
            wire we_active_own = (cur_op_type == 2'd0) ? conv_fmap_b_we[i] :
                              (cur_op_type == 2'd1) ? pool_we_out_flat[i] :
                                                        gap_we_out_flat[i];
            wire [`FMAP_ADDR_WIDTH-1:0] waddr_own = (cur_op_type == 2'd0)
                       ? conv_fmap_b_waddr_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                       : (cur_op_type == 2'd1)
                         ? pool_waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                         : gap_waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH];
            wire [`OUT_WIDTH-1:0] wdata_own = (cur_op_type == 2'd0)
                       ? conv_fmap_b_wdata_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]
                       : (cur_op_type == 2'd1)
                         ? pool_wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]
                         : gap_wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH];

            wire donor_applicable = (cur_op_type == 2'd0) && (conv_cfg_replicate_remainder != 0)
                                    && (i >= conv_cfg_replicate_remainder);
            wire [`CNT_WIDTH-1:0] donor_col = i % conv_cfg_replicate_remainder;
            wire we_dup = donor_applicable && conv_fmap_b_we_dup[donor_col];
            wire [`FMAP_ADDR_WIDTH-1:0] waddr_dup =
                conv_fmap_b_waddr_flat[donor_col*`FMAP_ADDR_WIDTH +: `FMAP_ADDR_WIDTH];
            wire [`OUT_WIDTH-1:0] wdata_dup =
                conv_fmap_b_wdata_flat[donor_col*`OUT_WIDTH +: `OUT_WIDTH];

            wire we_active = we_active_own || we_dup;
            wire [`FMAP_ADDR_WIDTH-1:0] waddr = we_dup ? waddr_dup : waddr_own;
            wire [`OUT_WIDTH-1:0] wdata = we_dup ? wdata_dup : wdata_own;
            wire we = (out_sel_active == 1'b0) && we_active;
            wire [`FMAP_ADDR_WIDTH-1:0] raddr_active = raddr_from_conv_valid
                       ? conv_fmap_a_addr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                       : (cur_op_type == 2'd1)
                         ? pool_raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                         : (cur_op_type == 2'd2)
                           ? gap_raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                           : {`FMAP_ADDR_WIDTH{1'b0}};
            wire [`FMAP_ADDR_WIDTH-1:0] raddr = all_done
                       ? rd_addr_a_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                       : ((in_sel_active == 1'b0) ? raddr_active : {`FMAP_ADDR_WIDTH{1'b0}});

            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
                .raddr(raddr), .rdata(bufA_rdata_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH])
            );
        end

        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : bufB
            wire we_active_own = (cur_op_type == 2'd0) ? conv_fmap_b_we[i] :
                              (cur_op_type == 2'd1) ? pool_we_out_flat[i] :
                                                        gap_we_out_flat[i];
            wire [`FMAP_ADDR_WIDTH-1:0] waddr_own = (cur_op_type == 2'd0)
                       ? conv_fmap_b_waddr_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                       : (cur_op_type == 2'd1)
                         ? pool_waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                         : gap_waddr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH];
            wire [`OUT_WIDTH-1:0] wdata_own = (cur_op_type == 2'd0)
                       ? conv_fmap_b_wdata_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]
                       : (cur_op_type == 2'd1)
                         ? pool_wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]
                         : gap_wdata_out_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH];

            wire donor_applicable = (cur_op_type == 2'd0) && (conv_cfg_replicate_remainder != 0)
                                    && (i >= conv_cfg_replicate_remainder);
            wire [`CNT_WIDTH-1:0] donor_col = i % conv_cfg_replicate_remainder;
            wire we_dup = donor_applicable && conv_fmap_b_we_dup[donor_col];
            wire [`FMAP_ADDR_WIDTH-1:0] waddr_dup =
                conv_fmap_b_waddr_flat[donor_col*`FMAP_ADDR_WIDTH +: `FMAP_ADDR_WIDTH];
            wire [`OUT_WIDTH-1:0] wdata_dup =
                conv_fmap_b_wdata_flat[donor_col*`OUT_WIDTH +: `OUT_WIDTH];

            wire we_active = we_active_own || we_dup;
            wire [`FMAP_ADDR_WIDTH-1:0] waddr = we_dup ? waddr_dup : waddr_own;
            wire [`OUT_WIDTH-1:0] wdata = we_dup ? wdata_dup : wdata_own;
            wire we = (out_sel_active == 1'b1) && we_active;
            wire [`FMAP_ADDR_WIDTH-1:0] raddr_active = raddr_from_conv_valid
                       ? conv_fmap_a_addr_out_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                       : (cur_op_type == 2'd1)
                         ? pool_raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                         : (cur_op_type == 2'd2)
                           ? gap_raddr_in_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                           : {`FMAP_ADDR_WIDTH{1'b0}};
            wire [`FMAP_ADDR_WIDTH-1:0] raddr = all_done
                       ? rd_addr_b_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]
                       : ((in_sel_active == 1'b1) ? raddr_active : {`FMAP_ADDR_WIDTH{1'b0}});

            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
                .raddr(raddr), .rdata(bufB_rdata_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH])
            );
        end
    endgenerate

    assign pool_rdata_in_flat        = (pool_in_sel == 1'b0) ? bufA_rdata_flat : bufB_rdata_flat;
    assign conv_fmap_a_rdata_ext_flat = (conv_in_sel == 1'b0) ? bufA_rdata_flat : bufB_rdata_flat;
    assign gap_rdata_in_flat         = (gap_in_sel == 1'b0) ? bufA_rdata_flat : bufB_rdata_flat;
    assign rd_data_a_flat = bufA_rdata_flat;
    assign rd_data_b_flat = bufB_rdata_flat;
endmodule

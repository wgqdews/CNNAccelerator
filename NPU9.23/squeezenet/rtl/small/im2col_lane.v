`include "params.vh"


module im2col_lane #(
    parameter LANE = 0
) (
`ifdef SRAM_MACRO
    input  wire                                  clk,
    input  wire                                  rst_n,
`endif
    input  wire [`CNT_WIDTH-1:0]                 oh,
    input  wire [`CNT_WIDTH-1:0]                 ow,
    input  wire [`CNT_WIDTH-1:0]                 k_tile,

    input  wire [`CNT_WIDTH-1:0]                 cfg_cin,
    input  wire [`CNT_WIDTH-1:0]                 cfg_kw,
    input  wire [`CNT_WIDTH-1:0]                 cfg_stride,
    input  wire [`CNT_WIDTH-1:0]                 cfg_pad,
    input  wire [`CNT_WIDTH-1:0]                 cfg_h_in,
    input  wire [`CNT_WIDTH-1:0]                 cfg_w_in,
    input  wire [`CNT_WIDTH-1:0]                 cfg_k_real,
    input  wire [`CNT_WIDTH-1:0]                 cfg_act_zp,
    input  wire                                  cfg_input_mode,
    input  wire [`CNT_WIDTH-1:0]                 cfg_pack_factor,
    input  wire [`CNT_WIDTH-1:0]                 cfg_pack_remainder,
    input  wire [`CNT_WIDTH-1:0]                 cfg_pack_base_group,


    input  wire [`CNT_WIDTH-1:0]                 shared_outer,
    input  wire [`CNT_WIDTH-1:0]                 shared_inner,

    input  wire [`ACT_WIDTH-1:0]                 raw_data,
    output wire [`FMAP_ADDR_WIDTH-1:0]           addr,
    output wire signed [`ACT_SIGNED_WIDTH-1:0]   act_signed
);
    wire signed [`CNT_WIDTH+3:0] cin_s, kw_s, stride_s, pad_s, h_in_s, w_in_s, k_real_s, act_zp_s;
    assign cin_s    = $signed({1'b0, cfg_cin});
    assign kw_s     = $signed({1'b0, cfg_kw});
    assign stride_s = $signed({1'b0, cfg_stride});
    assign pad_s    = $signed({1'b0, cfg_pad});
    assign h_in_s   = $signed({1'b0, cfg_h_in});
    assign w_in_s   = $signed({1'b0, cfg_w_in});
    assign k_real_s = $signed({1'b0, cfg_k_real});
    assign act_zp_s = $signed({1'b0, cfg_act_zp});

    wire signed [`CNT_WIDTH+3:0] pack_factor_s, pack_remainder_s, pack_base_group_s;
    assign pack_factor_s     = $signed({1'b0, cfg_pack_factor});
    assign pack_remainder_s  = $signed({1'b0, cfg_pack_remainder});
    assign pack_base_group_s = $signed({1'b0, cfg_pack_base_group});

    wire signed [`CNT_WIDTH+3:0] abs_k, tap, cin, kh, kw, ih, iw;
    wire                          valid;
    wire                          interleaved_mode;

    assign interleaved_mode = cfg_input_mode;


    wire signed [`CNT_WIDTH+3:0] cin_groups = (cin_s + `ARRAY_ROWS - 1) / `ARRAY_ROWS;
    wire signed [`CNT_WIDTH+3:0] cin_pad    = cin_groups * `ARRAY_ROWS;
    wire signed [`CNT_WIDTH+3:0] tap_stride = interleaved_mode ? cin_pad : cin_s;

    assign abs_k = $signed({1'b0, k_tile}) * `ARRAY_ROWS + LANE;


    wire pack_enabled = interleaved_mode && (pack_factor_s != 0);
    wire signed [`CNT_WIDTH+3:0] taps_total = kw_s * kw_s;
    wire signed [`CNT_WIDTH+3:0] full_group_k_tiles = pack_base_group_s * taps_total;
    wire pack_tile_active = pack_enabled && ($signed({1'b0, k_tile}) >= full_group_k_tiles);


    wire signed [`CNT_WIDTH+3:0] full_group_idx = $signed({1'b0, shared_outer});
    wire signed [`CNT_WIDTH+3:0] tap_full_group = $signed({1'b0, shared_inner});
    wire signed [`CNT_WIDTH+3:0] cin_full_group = full_group_idx * `ARRAY_ROWS + LANE;


    wire signed [`CNT_WIDTH+3:0] copy_group = LANE / pack_remainder_s;
    wire signed [`CNT_WIDTH+3:0] cin_local  = LANE % pack_remainder_s;
    wire signed [`CNT_WIDTH+3:0] tap_packed =
        ($signed({1'b0, k_tile}) - full_group_k_tiles) * pack_factor_s + copy_group;
    wire signed [`CNT_WIDTH+3:0] cin_packed = pack_base_group_s * `ARRAY_ROWS + cin_local;


    wire signed [`CNT_WIDTH+3:0] lane_s  = $signed({1'b0, LANE[`CNT_WIDTH-1:0]});
    wire signed [`CNT_WIDTH+3:0] tap_dup = lane_s / tap_stride;
    wire signed [`CNT_WIDTH+3:0] cin_dup = lane_s % tap_stride;
    wire signed [`CNT_WIDTH+3:0] tap_nonpacked = interleaved_mode ? $signed({1'b0, shared_outer}) : tap_dup;
    wire signed [`CNT_WIDTH+3:0] cin_nonpacked = interleaved_mode
        ? ($signed({1'b0, shared_inner}) * `ARRAY_ROWS + LANE) : cin_dup;

    assign tap = pack_enabled ? (pack_tile_active ? tap_packed : tap_full_group)
                              : tap_nonpacked;
    assign cin = pack_enabled ? (pack_tile_active ? cin_packed : cin_full_group)
                              : cin_nonpacked;

    reg signed [`CNT_WIDTH+3:0] kh_lut, kw_lut;
    always @(*) begin
        if (kw_s == 3) begin
            case (tap[3:0])
                4'd0: begin kh_lut = 0; kw_lut = 0; end
                4'd1: begin kh_lut = 0; kw_lut = 1; end
                4'd2: begin kh_lut = 0; kw_lut = 2; end
                4'd3: begin kh_lut = 1; kw_lut = 0; end
                4'd4: begin kh_lut = 1; kw_lut = 1; end
                4'd5: begin kh_lut = 1; kw_lut = 2; end
                4'd6: begin kh_lut = 2; kw_lut = 0; end
                4'd7: begin kh_lut = 2; kw_lut = 1; end
                4'd8: begin kh_lut = 2; kw_lut = 2; end
                default: begin kh_lut = tap; kw_lut = 0; end
            endcase
        end else begin

            kh_lut = tap;
            kw_lut = 0;
        end
    end
    assign kh = kh_lut;
    assign kw = kw_lut;
    assign ih    = $signed({1'b0, oh}) * stride_s - pad_s + kh;
    assign iw    = $signed({1'b0, ow}) * stride_s - pad_s + kw;

    assign valid = (interleaved_mode ? (cin < cin_s) : (abs_k < k_real_s)) &&
                   (tap < kw_s * kw_s) &&
                   (ih >= 0) && (ih < h_in_s) &&
                   (iw >= 0) && (iw < w_in_s);

    wire signed [`CNT_WIDTH+3:0] addr_interleaved = (ih * w_in_s + iw) * cin_groups + (cin / `ARRAY_ROWS);
    wire signed [`CNT_WIDTH+3:0] addr_duplicated  = (ih * w_in_s + iw) * cin_s + cin;

    assign addr = !valid ? {`FMAP_ADDR_WIDTH{1'b0}} :
                  interleaved_mode ? addr_interleaved[`FMAP_ADDR_WIDTH-1:0] :
                                      addr_duplicated[`FMAP_ADDR_WIDTH-1:0];

`ifdef SRAM_MACRO

    reg valid_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_d <= 1'b0;
        else
            valid_d <= valid;
    end
    assign act_signed = valid_d ? ($signed({1'b0, raw_data}) - act_zp_s) : {`ACT_SIGNED_WIDTH{1'b0}};
`else
    assign act_signed = valid ? ($signed({1'b0, raw_data}) - act_zp_s) : {`ACT_SIGNED_WIDTH{1'b0}};
`endif
endmodule

`include "params.vh"

module im2col_addr_gen (
`ifdef SRAM_MACRO
    input  wire                                             clk,
    input  wire                                             rst_n,
`endif
    input  wire [`CNT_WIDTH-1:0]                            oh,
    input  wire [`CNT_WIDTH-1:0]                            ow,
    input  wire [`CNT_WIDTH-1:0]                            k_tile,

    input  wire [`CNT_WIDTH-1:0]                            cfg_cin,
    input  wire [`CNT_WIDTH-1:0]                            cfg_kw,
    input  wire [`CNT_WIDTH-1:0]                            cfg_stride,
    input  wire [`CNT_WIDTH-1:0]                            cfg_pad,
    input  wire [`CNT_WIDTH-1:0]                            cfg_h_in,
    input  wire [`CNT_WIDTH-1:0]                            cfg_w_in,
    input  wire [`CNT_WIDTH-1:0]                            cfg_k_real,
    input  wire [`CNT_WIDTH-1:0]                            cfg_act_zp,
    input  wire                                             cfg_input_mode,
    input  wire [`CNT_WIDTH-1:0]                            cfg_pack_factor,
    input  wire [`CNT_WIDTH-1:0]                            cfg_pack_remainder,
    input  wire [`CNT_WIDTH-1:0]                            cfg_pack_base_group,

    input  wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]                raw_data_flat,
    output wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0]          addr_flat,
    output wire signed [`ARRAY_ROWS*`ACT_SIGNED_WIDTH-1:0]  act_signed_flat
);

    wire [`CNT_WIDTH-1:0] cin_groups   = (cfg_cin + `ARRAY_ROWS - 1) / `ARRAY_ROWS;
    wire [`CNT_WIDTH-1:0] taps_total   = cfg_kw * cfg_kw;
    wire                  pack_enabled = cfg_input_mode && (cfg_pack_factor != 0);
    wire [`CNT_WIDTH-1:0] inner_limit  = pack_enabled ? taps_total : cin_groups;

    wire [`CNT_WIDTH-1:0] shared_outer, shared_inner;

`ifdef SRAM_MACRO
    im2col_group_ctr u_group_ctr (
        .clk(clk), .rst_n(rst_n),
        .k_tile(k_tile), .inner_limit(inner_limit),
        .outer_ctr(shared_outer), .inner_ctr(shared_inner)
    );
`else

    assign shared_outer = k_tile / inner_limit;
    assign shared_inner = k_tile % inner_limit;
`endif

    genvar j;
    generate
        for (j = 0; j < `ARRAY_ROWS; j = j + 1) begin : lane
            im2col_lane #(.LANE(j)) u_im2col_lane (
`ifdef SRAM_MACRO
                .clk        (clk),
                .rst_n      (rst_n),
`endif
                .oh         (oh),
                .ow         (ow),
                .k_tile     (k_tile),
                .cfg_cin    (cfg_cin),
                .cfg_kw     (cfg_kw),
                .cfg_stride (cfg_stride),
                .cfg_pad    (cfg_pad),
                .cfg_h_in   (cfg_h_in),
                .cfg_w_in   (cfg_w_in),
                .cfg_k_real (cfg_k_real),
                .cfg_act_zp (cfg_act_zp),
                .cfg_input_mode (cfg_input_mode),
                .cfg_pack_factor     (cfg_pack_factor),
                .cfg_pack_remainder  (cfg_pack_remainder),
                .cfg_pack_base_group (cfg_pack_base_group),
                .shared_outer (shared_outer),
                .shared_inner (shared_inner),
                .raw_data   (raw_data_flat[(j+1)*`ACT_WIDTH-1 -: `ACT_WIDTH]),
                .addr       (addr_flat[(j+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .act_signed (act_signed_flat[(j+1)*`ACT_SIGNED_WIDTH-1 -: `ACT_SIGNED_WIDTH])
            );
        end
    endgenerate
endmodule

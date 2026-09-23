`include "params.vh"

module requant_lane #(
    parameter LANE     = 0,
    parameter NT_DEPTH = 1
) (
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire [`CNT_WIDTH-1:0]         cycle_cnt,
    input  wire [`CNT_WIDTH-1:0]         n_tile,
    input  wire                          is_first_k_tile,
    input  wire                          is_last_k_tile,

    input  wire [`CNT_WIDTH-1:0]         cfg_h_out,
    input  wire [`CNT_WIDTH-1:0]         cfg_w_out,
    input  wire [`CNT_WIDTH-1:0]         cfg_cout,
    input  wire [`CNT_WIDTH-1:0]         cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0]         cfg_y_zp,
    input  wire [`CNT_WIDTH-1:0]         cfg_out_n_tile_offset,
    input  wire [`CNT_WIDTH-1:0]         cfg_out_n_tiles_total,
    input  wire [`CNT_WIDTH-1:0]         cfg_bias_base_offset,

    input  wire signed [`ACC_WIDTH-1:0]  psum_col,
    input  wire signed [`ACC_WIDTH-1:0]  psum_rdata,

    output wire                          we_psum,
    output wire [`PSUM_ADDR_WIDTH-1:0]   addr_psum,
`ifdef SRAM_MACRO
    output wire [`PSUM_ADDR_WIDTH-1:0]   raddr_psum,
`endif
    output wire signed [`ACC_WIDTH-1:0]  wdata_psum,

    output wire                          we_fmap,
    output wire [`FMAP_ADDR_WIDTH-1:0]   waddr_fmap,
    output wire [`OUT_WIDTH-1:0]         wdata_fmap,
    output wire                          we_fmap_dup
);
    wire [`CNT_WIDTH+3:0] M_MAX   = cfg_h_out * cfg_w_out;
    wire [`CNT_WIDTH-1:0] COUT    = cfg_cout;

    reg signed [`BIAS_WIDTH-1:0]          bias_mem  [0:NT_DEPTH-1];
    reg        [`REQUANT_MULT_WIDTH-1:0]  mult_mem  [0:NT_DEPTH-1];
    reg        [`REQUANT_SHIFT_WIDTH-1:0] shift_mem [0:NT_DEPTH-1];

`ifdef SRAM_MACRO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            `include "requant_lane_rom.vh"
        end
    end
`endif

    wire signed [`CNT_WIDTH+3:0] m_signed;
    wire                          m_valid;
    wire [`CNT_WIDTH-1:0]         m;
    wire [`CNT_WIDTH-1:0]         chan_idx;

`ifdef SRAM_MACRO
    assign m_signed = $signed({4'b0, cycle_cnt}) - (`ARRAY_ROWS + 1) - LANE;
`else
    assign m_signed = $signed({4'b0, cycle_cnt}) - `ARRAY_ROWS - LANE;
`endif
    assign m_valid  = (m_signed >= 0) && (m_signed < M_MAX);
    assign m        = m_signed[`CNT_WIDTH-1:0];
    assign chan_idx = n_tile * `ARRAY_COLS + LANE;

    wire signed [`ACC_WIDTH-1:0] acc = is_first_k_tile ? psum_col : (psum_rdata + psum_col);

    wire [`CNT_WIDTH-1:0] bias_idx = cfg_bias_base_offset + n_tile;

    wire signed [`ACC_WIDTH-1:0]                   acc_with_bias = acc + bias_mem[bias_idx];
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] product =
         $signed(acc_with_bias) * $signed({1'b0, mult_mem[bias_idx]});
    wire [`REQUANT_SHIFT_WIDTH-1:0]                shift_amt = shift_mem[bias_idx];
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] round_bias =
         (shift_amt == 0) ? {(`ACC_WIDTH+`REQUANT_MULT_WIDTH+1){1'b0}}
                          : ({{(`ACC_WIDTH+`REQUANT_MULT_WIDTH){1'b0}}, 1'b1} <<< (shift_amt - 1));
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] rounded = (product + round_bias) >>> shift_amt;
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] with_zp = rounded + $signed({1'b0, cfg_y_zp});
    wire [`OUT_WIDTH-1:0] clamped = (with_zp < 0)   ? {`OUT_WIDTH{1'b0}} :
                                     (with_zp > 255) ? {`OUT_WIDTH{1'b1}} :
                                     with_zp[`OUT_WIDTH-1:0];

    assign we_psum = m_valid && !is_last_k_tile;
    assign we_fmap = m_valid && is_last_k_tile && (chan_idx < COUT);
    assign we_fmap_dup = we_fmap && (n_tile == cfg_n_tiles - 1'b1);

    assign addr_psum  = m;
    assign wdata_psum = acc;

`ifdef SRAM_MACRO
    wire signed [`CNT_WIDTH+3:0] m_next_signed = m_signed + 1'b1;
    wire m_next_valid = (m_next_signed >= 0) && (m_next_signed < M_MAX);
    assign raddr_psum = m_next_valid ? m_next_signed[`PSUM_ADDR_WIDTH-1:0]
                                      : {`PSUM_ADDR_WIDTH{1'b0}};
`endif

    assign waddr_fmap = m * cfg_out_n_tiles_total + (cfg_out_n_tile_offset + n_tile);
    assign wdata_fmap = clamped;
endmodule

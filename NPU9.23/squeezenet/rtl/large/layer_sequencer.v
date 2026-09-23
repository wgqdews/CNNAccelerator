`include "params.vh"

module layer_sequencer #(
    parameter N_STAGES       = 2,
    parameter N_CONV_STAGES  = 1,
    parameter N_POOL_STAGES  = 1,
    parameter N_GAP_STAGES   = 1
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg  all_done,
    output reg  [1:0] cur_op_type,

    output reg                    conv_start,
    input  wire                   conv_done,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_cin,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_cout,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_h_in,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_w_in,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_kw,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_stride,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_pad,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_h_out,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_w_out,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_k_real,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_k_tiles,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_n_tiles,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_act_zp,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_y_zp,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_out_n_tile_offset,
    output reg  [`CNT_WIDTH-1:0]  conv_cfg_out_n_tiles_total,
    output reg                    conv_cfg_input_mode,
    output reg  [`WGT_ADDR_WIDTH-1:0] conv_cfg_weight_base_offset,
    output reg  [`CNT_WIDTH-1:0]      conv_cfg_bias_base_offset,
    output reg  [`CNT_WIDTH-1:0]      conv_cfg_pack_factor,
    output reg  [`CNT_WIDTH-1:0]      conv_cfg_pack_remainder,
    output reg  [`CNT_WIDTH-1:0]      conv_cfg_pack_base_group,
    output reg  [`CNT_WIDTH-1:0]      conv_cfg_replicate_remainder,
    output reg                    conv_in_sel,  
    output reg                    conv_out_sel,   

    output reg                    pool_start,
    input  wire                   pool_done,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_h_in,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_w_in,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_n_tiles,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_h_out,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_w_out,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_kh,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_kw,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_stride,
    output reg  [`CNT_WIDTH-1:0]  pool_cfg_pad,
    output reg                    pool_in_sel,     
    output reg                    pool_out_sel,  

    output reg                    gap_start,
    input  wire                   gap_done,
    output reg  [`CNT_WIDTH-1:0]  gap_cfg_h_in,
    output reg  [`CNT_WIDTH-1:0]  gap_cfg_w_in,
    output reg  [`CNT_WIDTH-1:0]  gap_cfg_n_tiles,
    output reg  [`CNT_WIDTH-1:0]  gap_cfg_act_zp,
    output reg  [`CNT_WIDTH-1:0]  gap_cfg_y_zp,
    output reg  [`REQUANT_MULT_WIDTH-1:0]  gap_cfg_mult,
    output reg  [`REQUANT_SHIFT_WIDTH-1:0] gap_cfg_shift,
    output reg                    gap_in_sel, 
    output reg                    gap_out_sel 
);
    reg [1:0] stage_op_type [0:N_STAGES-1];
    reg stage_in_buf  [0:N_STAGES-1];
    reg stage_out_buf [0:N_STAGES-1];

    reg [`CNT_WIDTH-1:0] t_conv_cin    [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_cout   [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_h_in   [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_w_in   [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_kw     [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_stride [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_pad    [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_h_out  [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_w_out  [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_k_real [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_k_tiles[0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_n_tiles[0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_act_zp [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_y_zp   [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_out_n_tile_offset [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_conv_out_n_tiles_total [0:N_CONV_STAGES-1];
    reg                   t_conv_input_mode        [0:N_CONV_STAGES-1];
    reg [`WGT_ADDR_WIDTH-1:0] t_conv_weight_base_offset [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0]      t_conv_bias_base_offset   [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0]      t_conv_pack_factor          [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0]      t_conv_pack_remainder       [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0]      t_conv_pack_base_group      [0:N_CONV_STAGES-1];
    reg [`CNT_WIDTH-1:0]      t_conv_replicate_remainder  [0:N_CONV_STAGES-1];

    // ---- maxpool 子表 ----
    reg [`CNT_WIDTH-1:0] t_pool_h_in   [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_w_in   [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_n_tiles[0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_h_out  [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_w_out  [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_kh     [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_kw     [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_stride [0:N_POOL_STAGES-1];
    reg [`CNT_WIDTH-1:0] t_pool_pad    [0:N_POOL_STAGES-1];

    reg [`CNT_WIDTH-1:0]           t_gap_h_in    [0:N_GAP_STAGES-1];
    reg [`CNT_WIDTH-1:0]           t_gap_w_in    [0:N_GAP_STAGES-1];
    reg [`CNT_WIDTH-1:0]           t_gap_n_tiles [0:N_GAP_STAGES-1];
    reg [`CNT_WIDTH-1:0]           t_gap_act_zp  [0:N_GAP_STAGES-1];
    reg [`CNT_WIDTH-1:0]           t_gap_y_zp    [0:N_GAP_STAGES-1];
    reg [`REQUANT_MULT_WIDTH-1:0]  t_gap_mult    [0:N_GAP_STAGES-1];
    reg [`REQUANT_SHIFT_WIDTH-1:0] t_gap_shift   [0:N_GAP_STAGES-1];

`ifdef SRAM_MACRO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            `include "seq_chain_table_rom.vh"
        end
    end
`endif

    localparam integer SW = `CNT_WIDTH;
    reg [SW-1:0] stage, conv_idx, pool_idx, gap_idx;

    localparam S_IDLE = 3'd0, S_DISPATCH = 3'd1, S_WAIT_CONV = 3'd2,
               S_WAIT_POOL = 3'd3, S_ADVANCE = 3'd4, S_DONE = 3'd5, S_WAIT_GAP = 3'd6;
    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            all_done <= 1'b0;
            conv_start <= 1'b0;
            pool_start <= 1'b0;
            stage <= 0; conv_idx <= 0; pool_idx <= 0; gap_idx <= 0;
            conv_in_sel <= 1'b0; conv_out_sel <= 1'b0; conv_cfg_input_mode <= 1'b0;
            conv_cfg_pack_factor <= 0; conv_cfg_pack_remainder <= 0;
            conv_cfg_pack_base_group <= 0; conv_cfg_replicate_remainder <= 0;
            pool_in_sel <= 1'b0; pool_out_sel <= 1'b0;
            gap_in_sel <= 1'b0; gap_out_sel <= 1'b0;
            cur_op_type <= 2'd0;
        end else begin
            conv_start <= 1'b0;
            pool_start <= 1'b0;
            gap_start  <= 1'b0;

            case (state)
                S_IDLE: begin
                    all_done <= 1'b0;
                    if (start) begin
                        stage <= 0; conv_idx <= 0; pool_idx <= 0; gap_idx <= 0;
                        state <= S_DISPATCH;
                    end
                end

                S_DISPATCH: begin
                    cur_op_type <= stage_op_type[stage];
                    case (stage_op_type[stage])
                        2'd0: begin
                            conv_cfg_cin     <= t_conv_cin[conv_idx];
                            conv_cfg_cout    <= t_conv_cout[conv_idx];
                            conv_cfg_h_in    <= t_conv_h_in[conv_idx];
                            conv_cfg_w_in    <= t_conv_w_in[conv_idx];
                            conv_cfg_kw      <= t_conv_kw[conv_idx];
                            conv_cfg_stride  <= t_conv_stride[conv_idx];
                            conv_cfg_pad     <= t_conv_pad[conv_idx];
                            conv_cfg_h_out   <= t_conv_h_out[conv_idx];
                            conv_cfg_w_out   <= t_conv_w_out[conv_idx];
                            conv_cfg_k_real  <= t_conv_k_real[conv_idx];
                            conv_cfg_k_tiles <= t_conv_k_tiles[conv_idx];
                            conv_cfg_n_tiles <= t_conv_n_tiles[conv_idx];
                            conv_cfg_act_zp  <= t_conv_act_zp[conv_idx];
                            conv_cfg_y_zp    <= t_conv_y_zp[conv_idx];
                            conv_cfg_out_n_tile_offset <= t_conv_out_n_tile_offset[conv_idx];
                            conv_cfg_out_n_tiles_total <= t_conv_out_n_tiles_total[conv_idx];
                            conv_cfg_input_mode <= t_conv_input_mode[conv_idx];
                            conv_cfg_weight_base_offset <= t_conv_weight_base_offset[conv_idx];
                            conv_cfg_bias_base_offset   <= t_conv_bias_base_offset[conv_idx];
                            conv_cfg_pack_factor         <= t_conv_pack_factor[conv_idx];
                            conv_cfg_pack_remainder      <= t_conv_pack_remainder[conv_idx];
                            conv_cfg_pack_base_group     <= t_conv_pack_base_group[conv_idx];
                            conv_cfg_replicate_remainder <= t_conv_replicate_remainder[conv_idx];
                            conv_in_sel      <= stage_in_buf[stage];
                            conv_out_sel     <= stage_out_buf[stage];
                            conv_start       <= 1'b1;
                            state            <= S_WAIT_CONV;
                        end

                        2'd1: begin
                            pool_cfg_h_in    <= t_pool_h_in[pool_idx];
                            pool_cfg_w_in    <= t_pool_w_in[pool_idx];
                            pool_cfg_n_tiles <= t_pool_n_tiles[pool_idx];
                            pool_cfg_h_out   <= t_pool_h_out[pool_idx];
                            pool_cfg_w_out   <= t_pool_w_out[pool_idx];
                            pool_cfg_kh      <= t_pool_kh[pool_idx];
                            pool_cfg_kw      <= t_pool_kw[pool_idx];
                            pool_cfg_stride  <= t_pool_stride[pool_idx];
                            pool_cfg_pad     <= t_pool_pad[pool_idx];
                            pool_in_sel      <= stage_in_buf[stage];
                            pool_out_sel     <= stage_out_buf[stage];
                            pool_start       <= 1'b1;
                            state            <= S_WAIT_POOL;
                        end

                        default: begin
                            gap_cfg_h_in    <= t_gap_h_in[gap_idx];
                            gap_cfg_w_in    <= t_gap_w_in[gap_idx];
                            gap_cfg_n_tiles <= t_gap_n_tiles[gap_idx];
                            gap_cfg_act_zp  <= t_gap_act_zp[gap_idx];
                            gap_cfg_y_zp    <= t_gap_y_zp[gap_idx];
                            gap_cfg_mult    <= t_gap_mult[gap_idx];
                            gap_cfg_shift   <= t_gap_shift[gap_idx];
                            gap_in_sel      <= stage_in_buf[stage];
                            gap_out_sel     <= stage_out_buf[stage];
                            gap_start       <= 1'b1;
                            state           <= S_WAIT_GAP;
                        end
                    endcase
                end

                S_WAIT_CONV: begin
                    if (conv_done) begin
                        conv_idx <= conv_idx + 1'b1;
                        state <= S_ADVANCE;
                    end
                end

                S_WAIT_POOL: begin
                    if (pool_done) begin
                        pool_idx <= pool_idx + 1'b1;
                        state <= S_ADVANCE;
                    end
                end

                S_WAIT_GAP: begin
                    if (gap_done) begin
                        gap_idx <= gap_idx + 1'b1;
                        state <= S_ADVANCE;
                    end
                end

                S_ADVANCE: begin
                    if (stage < N_STAGES - 1) begin
                        stage <= stage + 1'b1;
                        state <= S_DISPATCH;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    all_done <= 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

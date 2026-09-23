`include "params.vh"

module conv_ctrl_fsm (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,
    output reg                       done,

    input  wire [`CNT_WIDTH-1:0]     cfg_k_tiles,
    input  wire [`CNT_WIDTH-1:0]     cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0]     cfg_h_out,
    input  wire [`CNT_WIDTH-1:0]     cfg_w_out,

    input  wire [`WGT_ADDR_WIDTH-1:0] cfg_weight_base_offset,

    output reg                       load_row_en,
    output reg  [`ROW_IDX_WIDTH-1:0] load_row_idx,
    output reg  [`WGT_ADDR_WIDTH-1:0] weight_row_index,


    output reg                       shadow_load_row_en,
    output reg  [`ROW_IDX_WIDTH-1:0] shadow_load_row_idx,
    output reg                       swap_all,

    output reg  [`CNT_WIDTH-1:0]     oh,
    output reg  [`CNT_WIDTH-1:0]     ow,
    output reg  [`CNT_WIDTH-1:0]     cycle_cnt,
    output reg                       streaming,

    output reg  [`CNT_WIDTH-1:0]     n_tile,
    output reg  [`CNT_WIDTH-1:0]     k_tile,
    output wire                      is_first_k_tile,
    output wire                      is_last_k_tile,

    output reg  [`CNT_WIDTH-1:0]     n_tiles_done
);
    wire [`CNT_WIDTH-1:0] K_TILES = cfg_k_tiles;
    wire [`CNT_WIDTH-1:0] N_TILES = cfg_n_tiles;
    wire [`CNT_WIDTH-1:0] W_OUT   = cfg_w_out;
    wire [`CNT_WIDTH+3:0] M_MAX         = cfg_h_out * cfg_w_out;

`ifdef SRAM_MACRO
    wire [`CNT_WIDTH+3:0] STREAM_CYCLES = M_MAX + `ARRAY_ROWS + `ARRAY_COLS + 1;
`else
    wire [`CNT_WIDTH+3:0] STREAM_CYCLES = M_MAX + `ARRAY_ROWS + `ARRAY_COLS; 
`endif

`ifdef SRAM_MACRO
    localparam S_IDLE = 3'd0, S_LOAD = 3'd1, S_STREAM = 3'd2, S_ADVANCE = 3'd3, S_DONE = 3'd4,
               S_LOAD_SYNC = 3'd5;
`else
    localparam S_IDLE = 3'd0, S_LOAD = 3'd1, S_STREAM = 3'd2, S_ADVANCE = 3'd3, S_DONE = 3'd4;
`endif
    reg [2:0] state;
    reg [`ROW_IDX_WIDTH:0] prefetch_row_idx;

    assign is_first_k_tile = (k_tile == 0);
    assign is_last_k_tile  = (k_tile == K_TILES - 1);

    wire has_next_k = (k_tile < K_TILES - 1);
    wire has_next_n = (n_tile < N_TILES - 1);
    wire has_next   = has_next_n || has_next_k;
    wire [`WGT_ADDR_WIDTH-1:0] next_weight_base =
        has_next_k ? (cfg_weight_base_offset + (n_tile * K_TILES + (k_tile + 1'b1)) * `ARRAY_ROWS)
                   : (cfg_weight_base_offset + ((n_tile + 1'b1) * K_TILES) * `ARRAY_ROWS);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= S_IDLE;
            done                  <= 1'b0;
            load_row_en           <= 1'b0;
            load_row_idx          <= {`ROW_IDX_WIDTH{1'b0}};
            weight_row_index      <= {`WGT_ADDR_WIDTH{1'b0}};
            shadow_load_row_en    <= 1'b0;
            shadow_load_row_idx   <= {`ROW_IDX_WIDTH{1'b0}};
            swap_all              <= 1'b0;
            prefetch_row_idx      <= {(`ROW_IDX_WIDTH+1){1'b0}};
            oh                    <= {`CNT_WIDTH{1'b0}};
            ow                    <= {`CNT_WIDTH{1'b0}};
            cycle_cnt             <= {`CNT_WIDTH{1'b0}};
            streaming             <= 1'b0;
            n_tile                <= {`CNT_WIDTH{1'b0}};
            k_tile                <= {`CNT_WIDTH{1'b0}};
            n_tiles_done          <= {`CNT_WIDTH{1'b0}};
        end else begin
            swap_all <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_tile <= 0;
                        k_tile <= 0;
                        n_tiles_done <= 0;
                        load_row_idx <= 0;
                        weight_row_index <= cfg_weight_base_offset;
                        load_row_en <= 1'b1;
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (load_row_idx == `ARRAY_ROWS - 1) begin
                        load_row_en <= 1'b0;
`ifdef SRAM_MACRO
                        state <= S_LOAD_SYNC;
`else
                        oh <= 0;
                        ow <= 0;
                        cycle_cnt <= 0;
                        prefetch_row_idx <= 0;
                        streaming <= 1'b1;
                        state <= S_STREAM;
`endif
                    end else begin
                        load_row_idx <= load_row_idx + 1'b1;
                        weight_row_index <= cfg_weight_base_offset
                                             + ((n_tile * K_TILES + k_tile) * `ARRAY_ROWS)
                                             + (load_row_idx + 1'b1);
                    end
                end

`ifdef SRAM_MACRO
                S_LOAD_SYNC: begin
                    oh <= 0;
                    ow <= 0;
                    cycle_cnt <= 0;
                    prefetch_row_idx <= 0;
                    streaming <= 1'b1;
                    state <= S_STREAM;
                end
`endif

                S_STREAM: begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                    if (cycle_cnt < M_MAX - 1) begin
                        if (ow == W_OUT - 1) begin
                            ow <= 0;
                            oh <= oh + 1'b1;
                        end else begin
                            ow <= ow + 1'b1;
                        end
                    end

                    if (has_next && (prefetch_row_idx < `ARRAY_ROWS)) begin
                        weight_row_index    <= next_weight_base + prefetch_row_idx[`ROW_IDX_WIDTH-1:0];
                        shadow_load_row_en  <= 1'b1;
                        shadow_load_row_idx <= prefetch_row_idx[`ROW_IDX_WIDTH-1:0];
                        prefetch_row_idx    <= prefetch_row_idx + 1'b1;
                    end else begin
                        shadow_load_row_en <= 1'b0;
                    end

                    if (cycle_cnt == STREAM_CYCLES - 1) begin
                        streaming <= 1'b0;
                        if (is_last_k_tile)
                            n_tiles_done <= n_tiles_done + 1'b1;
                        if (has_next)
                            swap_all <= 1'b1;
                        state <= S_ADVANCE;
                    end
                end

                S_ADVANCE: begin
                    if (has_next) begin
                        if (has_next_k) begin
                            k_tile <= k_tile + 1'b1;
                        end else begin
                            n_tile <= n_tile + 1'b1;
                            k_tile <= 0;
                        end
                        oh <= 0; ow <= 0; cycle_cnt <= 0; prefetch_row_idx <= 0;
                        streaming        <= 1'b1;
                        state            <= S_STREAM;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

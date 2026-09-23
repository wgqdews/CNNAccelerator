`include "params.vh"


module maxpool_ctrl_fsm (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    output reg                   done,

    input  wire [`CNT_WIDTH-1:0] cfg_h_out,
    input  wire [`CNT_WIDTH-1:0] cfg_w_out,
    input  wire [`CNT_WIDTH-1:0] cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0] cfg_kh,
    input  wire [`CNT_WIDTH-1:0] cfg_kw,


    input  wire                  cfg_fused,
    input  wire [`CNT_WIDTH-1:0] producer_n_tiles_done,

    output reg  [`CNT_WIDTH-1:0] oh,
    output reg  [`CNT_WIDTH-1:0] ow,
    output reg  [`CNT_WIDTH-1:0] tap,
    output reg  [`CNT_WIDTH-1:0] n_tile,

    output reg  [`CNT_WIDTH-1:0] oh_d,
    output reg  [`CNT_WIDTH-1:0] ow_d,
    output reg  [`CNT_WIDTH-1:0] n_tile_d,
    output reg                   commit
);
`ifdef SRAM_MACRO

    reg [`CNT_WIDTH-1:0] oh_d1, ow_d1, n_tile_d1;
    reg                   commit_d1;
`endif
    wire [`CNT_WIDTH-1:0] tap_max = cfg_kh * cfg_kw - 1'b1;

    localparam S_IDLE = 3'd0, S_WAIT = 3'd1, S_RUN = 3'd2, S_DRAIN = 3'd3, S_DONE = 3'd4;
    reg [2:0] state;

    wire is_last_tap = (tap == tap_max);
    wire [`CNT_WIDTH-1:0] n_tile_next = n_tile + 1'b1;
    wire ready_for_current = !cfg_fused || (producer_n_tiles_done > n_tile);
    wire ready_for_next    = !cfg_fused || (producer_n_tiles_done > n_tile_next);
    wire ready_for_zero    = !cfg_fused || (producer_n_tiles_done > {`CNT_WIDTH{1'b0}});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            done     <= 1'b0;
            oh       <= {`CNT_WIDTH{1'b0}};
            ow       <= {`CNT_WIDTH{1'b0}};
            tap      <= {`CNT_WIDTH{1'b0}};
            n_tile   <= {`CNT_WIDTH{1'b0}};
            oh_d     <= {`CNT_WIDTH{1'b0}};
            ow_d     <= {`CNT_WIDTH{1'b0}};
            n_tile_d <= {`CNT_WIDTH{1'b0}};
            commit   <= 1'b0;
`ifdef SRAM_MACRO
            oh_d1     <= {`CNT_WIDTH{1'b0}};
            ow_d1     <= {`CNT_WIDTH{1'b0}};
            n_tile_d1 <= {`CNT_WIDTH{1'b0}};
            commit_d1 <= 1'b0;
`endif
        end else begin
`ifdef SRAM_MACRO
            oh_d1     <= oh;
            ow_d1     <= ow;
            n_tile_d1 <= n_tile;
            commit_d1 <= (state == S_RUN) && is_last_tap;
            oh_d      <= oh_d1;
            ow_d      <= ow_d1;
            n_tile_d  <= n_tile_d1;
            commit    <= commit_d1;
`else
            oh_d     <= oh;
            ow_d     <= ow;
            n_tile_d <= n_tile;
            commit   <= (state == S_RUN) && is_last_tap;
`endif

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        oh <= 0; ow <= 0; tap <= 0; n_tile <= 0;
                        state <= ready_for_zero ? S_RUN : S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (ready_for_current) begin
                        state <= S_RUN;
                    end
                end

                S_RUN: begin
                    if (!is_last_tap) begin
                        tap <= tap + 1'b1;
                    end else begin
                        tap <= 0;
                        if (ow < cfg_w_out - 1'b1) begin
                            ow <= ow + 1'b1;
                        end else begin
                            ow <= 0;
                            if (oh < cfg_h_out - 1'b1) begin
                                oh <= oh + 1'b1;
                            end else begin
                                oh <= 0;
                                if (n_tile < cfg_n_tiles - 1'b1) begin
                                    n_tile <= n_tile_next;
                                    state <= ready_for_next ? S_RUN : S_WAIT;
                                end else begin
                                    state <= S_DRAIN;
                                end
                            end
                        end
                    end
                end

                S_DRAIN: begin
                    state <= S_DONE;
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

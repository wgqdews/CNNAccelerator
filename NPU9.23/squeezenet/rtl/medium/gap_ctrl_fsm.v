`include "params.vh"


module gap_ctrl_fsm (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    output reg                   done,

    input  wire [`CNT_WIDTH-1:0] cfg_h_in,
    input  wire [`CNT_WIDTH-1:0] cfg_w_in,
    input  wire [`CNT_WIDTH-1:0] cfg_n_tiles,

    output reg  [`CNT_WIDTH-1:0] spatial_idx,
    output reg  [`CNT_WIDTH-1:0] n_tile,
    output reg  [`CNT_WIDTH-1:0] n_tile_d,
    output reg                   commit
);
`ifdef SRAM_MACRO

    reg [`CNT_WIDTH-1:0] n_tile_d1;
    reg                   commit_d1;
`endif
    wire [`CNT_WIDTH-1:0] spatial_max = cfg_h_in * cfg_w_in - 1'b1;

    localparam S_IDLE = 2'd0, S_RUN = 2'd1, S_DRAIN = 2'd2, S_DONE = 2'd3;
    reg [1:0] state;

    wire is_last_spatial = (spatial_idx == spatial_max);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            done         <= 1'b0;
            spatial_idx  <= {`CNT_WIDTH{1'b0}};
            n_tile       <= {`CNT_WIDTH{1'b0}};
            n_tile_d     <= {`CNT_WIDTH{1'b0}};
            commit       <= 1'b0;
`ifdef SRAM_MACRO
            n_tile_d1 <= {`CNT_WIDTH{1'b0}};
            commit_d1 <= 1'b0;
`endif
        end else begin

`ifdef SRAM_MACRO
            n_tile_d1 <= n_tile;
            commit_d1 <= (state == S_RUN) && is_last_spatial;
            n_tile_d  <= n_tile_d1;
            commit    <= commit_d1;
`else
            n_tile_d <= n_tile;
            commit   <= (state == S_RUN) && is_last_spatial;
`endif

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        spatial_idx <= 0; n_tile <= 0;
                        state <= S_RUN;
                    end
                end

                S_RUN: begin
                    if (!is_last_spatial) begin
                        spatial_idx <= spatial_idx + 1'b1;
                    end else begin
                        spatial_idx <= 0;
                        if (n_tile < cfg_n_tiles - 1'b1) begin
                            n_tile <= n_tile + 1'b1;
                        end else begin
                            state <= S_DRAIN;
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

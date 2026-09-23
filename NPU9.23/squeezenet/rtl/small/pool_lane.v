`include "params.vh"

module pool_lane (
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire [`CNT_WIDTH-1:0]         oh,
    input  wire [`CNT_WIDTH-1:0]         ow,
    input  wire [`CNT_WIDTH-1:0]         tap,
    input  wire [`CNT_WIDTH-1:0]         n_tile,

    input  wire [`CNT_WIDTH-1:0]         oh_d,
    input  wire [`CNT_WIDTH-1:0]         ow_d,
    input  wire [`CNT_WIDTH-1:0]         n_tile_d,
    input  wire                          commit,

    input  wire [`CNT_WIDTH-1:0]         cfg_h_in,
    input  wire [`CNT_WIDTH-1:0]         cfg_w_in,
    input  wire [`CNT_WIDTH-1:0]         cfg_w_out,
    input  wire [`CNT_WIDTH-1:0]         cfg_kw,
    input  wire [`CNT_WIDTH-1:0]         cfg_stride,
    input  wire [`CNT_WIDTH-1:0]         cfg_pad,
    input  wire [`CNT_WIDTH-1:0]         cfg_n_tiles,

    input  wire [`ACT_WIDTH-1:0]         rdata_in,
    output wire [`FMAP_ADDR_WIDTH-1:0]   raddr_in,

    output wire                          we_out,
    output wire [`FMAP_ADDR_WIDTH-1:0]   waddr_out,
    output wire [`OUT_WIDTH-1:0]         wdata_out
);
    wire signed [`CNT_WIDTH+3:0] kh_idx, kw_idx, ih, iw, addr_in_s, addr_out_s;
    wire                          valid;

    assign kh_idx = $signed({1'b0, tap}) / $signed({1'b0, cfg_kw});
    assign kw_idx = $signed({1'b0, tap}) % $signed({1'b0, cfg_kw});
    assign ih     = $signed({1'b0, oh}) * $signed({1'b0, cfg_stride}) - $signed({1'b0, cfg_pad}) + kh_idx;
    assign iw     = $signed({1'b0, ow}) * $signed({1'b0, cfg_stride}) - $signed({1'b0, cfg_pad}) + kw_idx;

    assign valid  = (ih >= 0) && (ih < $signed({1'b0, cfg_h_in})) &&
                    (iw >= 0) && (iw < $signed({1'b0, cfg_w_in}));

    assign addr_in_s = (ih * $signed({1'b0, cfg_w_in}) + iw) * $signed({1'b0, cfg_n_tiles})
                        + $signed({1'b0, n_tile});
    assign raddr_in  = valid ? addr_in_s[`FMAP_ADDR_WIDTH-1:0] : {`FMAP_ADDR_WIDTH{1'b0}};

    reg [`ACT_WIDTH-1:0] running_max;
    wire is_first_tap = (tap == 0);

`ifdef SRAM_MACRO

    reg valid_d, is_first_tap_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_d        <= 1'b0;
            is_first_tap_d <= 1'b0;
        end else begin
            valid_d        <= valid;
            is_first_tap_d <= is_first_tap;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_max <= {`ACT_WIDTH{1'b0}};
        end else begin
            if (is_first_tap_d)
                running_max <= valid_d ? rdata_in : {`ACT_WIDTH{1'b0}};
            else if (valid_d && (rdata_in > running_max))
                running_max <= rdata_in;
        end
    end
`else
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_max <= {`ACT_WIDTH{1'b0}};
        end else begin
            if (is_first_tap)
                running_max <= valid ? rdata_in : {`ACT_WIDTH{1'b0}};
            else if (valid && (rdata_in > running_max))
                running_max <= rdata_in;
        end
    end
`endif

    assign addr_out_s = ($signed({1'b0, oh_d}) * $signed({1'b0, cfg_w_out}) + $signed({1'b0, ow_d}))
                          * $signed({1'b0, cfg_n_tiles}) + $signed({1'b0, n_tile_d});

    assign we_out    = commit;
    assign waddr_out = addr_out_s[`FMAP_ADDR_WIDTH-1:0];
    assign wdata_out = running_max;
endmodule

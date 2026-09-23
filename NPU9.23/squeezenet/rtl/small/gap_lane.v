`include "params.vh"

module gap_lane (
    input  wire                              clk,
    input  wire                              rst_n,

    input  wire [`CNT_WIDTH-1:0]             spatial_idx,
    input  wire [`CNT_WIDTH-1:0]             n_tile,
    input  wire [`CNT_WIDTH-1:0]             n_tile_d,
    input  wire                              commit,

    input  wire [`CNT_WIDTH-1:0]             cfg_n_tiles,
    input  wire [`CNT_WIDTH-1:0]             cfg_act_zp,
    input  wire [`CNT_WIDTH-1:0]             cfg_y_zp,
    input  wire [`REQUANT_MULT_WIDTH-1:0]    cfg_mult,
    input  wire [`REQUANT_SHIFT_WIDTH-1:0]   cfg_shift,

    input  wire [`ACT_WIDTH-1:0]             rdata_in,
    output wire [`FMAP_ADDR_WIDTH-1:0]       raddr_in,

    output wire                              we_out,
    output wire [`FMAP_ADDR_WIDTH-1:0]       waddr_out,
    output wire [`OUT_WIDTH-1:0]             wdata_out
);
    wire [`CNT_WIDTH+3:0] addr_in_s = spatial_idx * cfg_n_tiles + n_tile;
    assign raddr_in = addr_in_s[`FMAP_ADDR_WIDTH-1:0];

    wire is_first_spatial = (spatial_idx == 0);
    wire signed [`ACT_SIGNED_WIDTH-1:0] x_signed =
         $signed({1'b0, rdata_in}) - $signed({1'b0, cfg_act_zp});

    reg signed [`ACC_WIDTH-1:0] running_sum;
`ifdef SRAM_MACRO

    reg is_first_spatial_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            is_first_spatial_d <= 1'b0;
        else
            is_first_spatial_d <= is_first_spatial;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_sum <= {`ACC_WIDTH{1'b0}};
        end else begin
            if (is_first_spatial_d)
                running_sum <= x_signed;
            else
                running_sum <= running_sum + x_signed;
        end
    end
`else
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_sum <= {`ACC_WIDTH{1'b0}};
        end else begin
            if (is_first_spatial)
                running_sum <= x_signed;
            else
                running_sum <= running_sum + x_signed;
        end
    end
`endif

    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] product =
         $signed(running_sum) * $signed({1'b0, cfg_mult});
    wire [`REQUANT_SHIFT_WIDTH-1:0] shift_amt = cfg_shift;
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] round_bias =
         (shift_amt == 0) ? {(`ACC_WIDTH+`REQUANT_MULT_WIDTH+1){1'b0}}
                          : ({{(`ACC_WIDTH+`REQUANT_MULT_WIDTH){1'b0}}, 1'b1} <<< (shift_amt - 1));
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] rounded = (product + round_bias) >>> shift_amt;
    wire signed [`ACC_WIDTH+`REQUANT_MULT_WIDTH:0] with_zp = rounded + $signed({1'b0, cfg_y_zp});
    wire [`OUT_WIDTH-1:0] clamped = (with_zp < 0)   ? {`OUT_WIDTH{1'b0}} :
                                     (with_zp > 255) ? {`OUT_WIDTH{1'b1}} :
                                     with_zp[`OUT_WIDTH-1:0];

    assign we_out    = commit;
    assign waddr_out = {{(`FMAP_ADDR_WIDTH-`CNT_WIDTH){1'b0}}, n_tile_d};
    assign wdata_out = clamped;
endmodule

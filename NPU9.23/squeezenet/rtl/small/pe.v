`include "params.vh"

module pe (
    input  wire                                clk,
    input  wire                                rst_n,
    input  wire                                weight_load,
    input  wire signed [`WGT_WIDTH-1:0]        w_in,
    input  wire                                shadow_load,
    input  wire signed [`WGT_WIDTH-1:0]        shadow_w_in,
    input  wire                                swap,
    input  wire signed [`ACT_SIGNED_WIDTH-1:0] act_in,
    input  wire signed [`ACC_WIDTH-1:0]        psum_in,
    output reg  signed [`ACT_SIGNED_WIDTH-1:0] act_out,
    output reg  signed [`ACC_WIDTH-1:0]        psum_out
);
    reg signed [`WGT_WIDTH-1:0] weight_reg;
    reg signed [`WGT_WIDTH-1:0] weight_reg_shadow;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg        <= {`WGT_WIDTH{1'b0}};
            weight_reg_shadow <= {`WGT_WIDTH{1'b0}};
            act_out            <= {`ACT_SIGNED_WIDTH{1'b0}};
            psum_out           <= {`ACC_WIDTH{1'b0}};
        end else begin
            if (weight_load)
                weight_reg <= w_in;
            else if (swap)
                weight_reg <= weight_reg_shadow;
            if (shadow_load)
                weight_reg_shadow <= shadow_w_in;
            act_out  <= act_in;
            psum_out <= psum_in + act_in * weight_reg;
        end
    end
endmodule

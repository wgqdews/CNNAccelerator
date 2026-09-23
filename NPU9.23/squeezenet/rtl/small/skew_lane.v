`include "params.vh"

module skew_lane #(
    parameter DEPTH = 0
) (
    input  wire                                clk,
    input  wire                                rst_n,
    input  wire signed [`ACT_SIGNED_WIDTH-1:0] data_in,
    output wire signed [`ACT_SIGNED_WIDTH-1:0] data_out
);
    generate
        if (DEPTH == 0) begin : no_delay
            assign data_out = data_in;
        end else begin : delay
            reg signed [`ACT_SIGNED_WIDTH-1:0] sr [0:DEPTH-1];
            integer i;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (i = 0; i < DEPTH; i = i + 1)
                        sr[i] <= {`ACT_SIGNED_WIDTH{1'b0}};
                end else begin
                    sr[0] <= data_in;
                    for (i = 1; i < DEPTH; i = i + 1)
                        sr[i] <= sr[i-1];
                end
            end
            assign data_out = sr[DEPTH-1];
        end
    endgenerate
endmodule

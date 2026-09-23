`include "params.vh"

module skew_buffer (
    input  wire                                            clk,
    input  wire                                            rst_n,
    input  wire signed [`ARRAY_ROWS*`ACT_SIGNED_WIDTH-1:0] data_in_flat,
    output wire signed [`ARRAY_ROWS*`ACT_SIGNED_WIDTH-1:0] data_out_flat
);
    genvar k;
    generate
        for (k = 0; k < `ARRAY_ROWS; k = k + 1) begin : lane
            skew_lane #(.DEPTH(k)) u_skew_lane (
                .clk      (clk),
                .rst_n    (rst_n),
                .data_in  (data_in_flat[(k+1)*`ACT_SIGNED_WIDTH-1 -: `ACT_SIGNED_WIDTH]),
                .data_out (data_out_flat[(k+1)*`ACT_SIGNED_WIDTH-1 -: `ACT_SIGNED_WIDTH])
            );
        end
    endgenerate
endmodule

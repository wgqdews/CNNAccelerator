`include "../../inc/config.vh"

module PE_array_output #(
    parameter M = 4   // number of rows
)(
    input  wire signed [`ADD_WIDTH-1:0]  i_add   [0:M-1],
    input  wire signed [`DATA_WIDTH-1:0] i_bias  [0:M-1],
    output wire signed [`MUL_WIDTH-1:0]  out     [0:M-1]
);
    wire signed [`ADD_WIDTH-1:0] o_add [0:M-1];
    genvar c;
    generate
        for (c = 0; c < M; c = c + 1) begin : col_gen
            reLU o(
                .i_bias(i_bias[c]),
                .i_add(i_add[c]),
                .out(out[c])
            );
        end
    endgenerate
endmodule
`include "../../inc/config.vh"

module reLU (
    input  wire signed [`ADD_WIDTH-1:0]  i_add   ,
    input  wire signed [`DATA_WIDTH-1:0] i_bias  ,
    output wire signed [`MUL_WIDTH-1:0]  out     
);
    wire signed [`ADD_WIDTH-1:0] o_add;

            assign o_add = i_bias + i_add;
            assign out = (o_add > 32'sd32767) ? {1'b0, {(`MUL_WIDTH-1){1'b1}}} :
                         (o_add < 32'sd0)     ? {`MUL_WIDTH{1'b0}}             :
                          o_add[`MUL_WIDTH-1:0];
endmodule
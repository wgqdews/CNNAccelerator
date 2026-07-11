`include "../../inc/config.vh"

module PE(
    input wire                      clk,
    input wire                      rst_n,
    
    input wire signed [`ADD_WIDTH-1:0]    i_add,
    input wire signed [`DATA_WIDTH-1:0]    i_pixel,
    input wire signed [`DATA_WIDTH-1:0]    i_weight,

    output reg signed [`DATA_WIDTH-1:0]    o_pixel,
    output reg signed [`ADD_WIDTH-1:0]     o_add
);
    wire signed [`MUL_WIDTH-1:0] w_mul;
    assign w_mul = i_pixel * i_weight;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            o_pixel <= 0;
            o_add <= 0;
        end        
        else begin
            o_pixel <= i_pixel;
            o_add   <= w_mul + i_add;    
        end
    end
endmodule
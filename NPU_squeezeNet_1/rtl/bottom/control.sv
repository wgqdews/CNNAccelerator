`include "../../inc/config.vh"
module control(
    input   logic   mod,
    output  logic   S,
    output  logic   k,
    output  logic   [`ADDR_WIDTH-1:0] img_size, 
    output  logic   vld
);
    always_comb begin
        case (mod)
            1'b1: begin
                vld   = 1;
                S     = 1;
                k     = 0;
                img_size = 50176;
            end

            default: begin
                vld   = 0;
                S     = 0;
                k     = 0;
                img_size = 0;
            end
        endcase
    end
endmodule
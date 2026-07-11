`include "../../inc/config.vh"
module coord_gen (
    input  logic                   i_clk,
    input  logic                   i_rst_n,
    
    input  logic [`ADDR_WIDTH-1:0] img_size,     // image大小

    input  logic                   i_vld,        
    // output coord
    output logic  [`ADDR_WIDTH-1:0] coord,
    // output state
    output logic                   o_done
);
    always @(posedge i_clk or negedge i_rst_n) begin
        // reset
        if (!i_rst_n) begin
            coord  <= 0;
            o_done <= 0;
        end 
        // when enable
        else begin
            o_done <= 1'b0; 
            if (i_vld) begin
                if (coord == img_size - 1) begin
                    coord  <= 0;
                    o_done <= 1;  
                end 
                else begin
                    coord  <= coord + 1;
                end
            end
        end
    end
endmodule
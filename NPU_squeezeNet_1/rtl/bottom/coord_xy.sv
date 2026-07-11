`include "../../inc/config.vh"
module coord_gen (
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    
    input  wire [`ADDR_WIDTH-1:0] img_w,     // image width
    input  wire [`ADDR_WIDTH-1:0] img_h,     // image high
    input  wire                   i_vld,

    // output coord
    output reg  [`ADDR_WIDTH-1:0] r_x_cnt,
    output reg  [`ADDR_WIDTH:0]   r_y_cnt,
    // output state
    output wire                   o_done
);
    // Boundary Detection
    wire w_x_end = (r_x_cnt == img_w - 1'b1);
    wire w_y_end = (r_y_cnt == img_h);

    always @(posedge i_clk or negedge i_rst_n) begin
        // reset
        if (!i_rst_n) begin
            r_x_cnt <= {`ADDR_WIDTH{1'b0}};
            r_y_cnt <= {`ADDR_WIDTH{1'b0}};
        end 
        // when enable
        else if (i_vld) begin
            if (w_x_end) begin
                r_x_cnt <= {`ADDR_WIDTH{1'b0}};

                if (w_y_end) begin
                    r_y_cnt <= {`ADDR_WIDTH{1'b0}};
                end 
                else begin
                    r_y_cnt <= r_y_cnt + 1'b1;
                end
            end 
            else begin
                r_x_cnt <= r_x_cnt + 1'b1;
            end
        end
    end

    // done
    assign o_done = i_vld && w_x_end && w_y_end;

endmodule
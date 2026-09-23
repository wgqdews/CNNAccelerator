`include "params.vh"


module im2col_group_ctr (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [`CNT_WIDTH-1:0] k_tile,
    input  wire [`CNT_WIDTH-1:0] inner_limit,  
    output reg  [`CNT_WIDTH-1:0] outer_ctr,    
    output reg  [`CNT_WIDTH-1:0] inner_ctr    
);
    reg [`CNT_WIDTH-1:0] k_tile_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_tile_d  <= {`CNT_WIDTH{1'b0}};
            outer_ctr <= {`CNT_WIDTH{1'b0}};
            inner_ctr <= {`CNT_WIDTH{1'b0}};
        end else begin
            k_tile_d <= k_tile;
            if (k_tile == {`CNT_WIDTH{1'b0}} && k_tile_d != {`CNT_WIDTH{1'b0}}) begin
                outer_ctr <= {`CNT_WIDTH{1'b0}};
                inner_ctr <= {`CNT_WIDTH{1'b0}};
            end else if (k_tile == k_tile_d + 1'b1) begin
                if (inner_ctr == inner_limit - 1'b1) begin
                    inner_ctr <= {`CNT_WIDTH{1'b0}};
                    outer_ctr <= outer_ctr + 1'b1;
                end else begin
                    inner_ctr <= inner_ctr + 1'b1;
                end
            end
        end
    end
endmodule

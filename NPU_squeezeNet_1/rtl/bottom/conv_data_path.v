`include "../../inc/config.vh"

module conv_data_path (
    input  wire                   i_clk,
    input  wire                   i_rst_n,

    input  wire [`ADDR_WIDTH-1:0] img_w,     // image width
    input  wire [`ADDR_WIDTH-1:0] img_h,     // image high
    // generated from 'coord_gen'
    input  wire [`ADDR_WIDTH-1:0] i_x_cnt,
    input  wire [`ADDR_WIDTH:0]   i_y_cnt,

    input  wire                   i_vld,

    input  wire [`DATA_WIDTH-1:0] i_pixel,

    output wire signed[`DATA_WIDTH-1:0] o_p11, o_p12, o_p13,
    output wire signed[`DATA_WIDTH-1:0] o_p21, o_p22, o_p23,
    output wire signed[`DATA_WIDTH-1:0] o_p31, o_p32, o_p33,
    
    output reg [`ADDR_WIDTH-1:0]  o_sync_x,
    output reg [`ADDR_WIDTH-1:0]  o_sync_y,
    output reg                    o_vld
); 

    // line buffer
    reg [`DATA_WIDTH-1:0] line_buf_0 [0:`MAX_WIDTH-1];
    reg [`DATA_WIDTH-1:0] line_buf_1 [0:`MAX_WIDTH-1];
    reg [`DATA_WIDTH-1:0] r_p11, r_p12, r_p13;
    reg [`DATA_WIDTH-1:0] r_p21, r_p22, r_p23;
    reg [`DATA_WIDTH-1:0] r_p31, r_p32, r_p33;
    reg [`ADDR_WIDTH-1:0] d_y;


    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            {r_p11, r_p12, r_p13} <= {`DATA_WIDTH{1'b0}};
            {r_p21, r_p22, r_p23} <= {`DATA_WIDTH{1'b0}};
            {r_p31, r_p32, r_p33} <= {`DATA_WIDTH{1'b0}};
            o_sync_x              <= {`ADDR_WIDTH{1'b0}};
            o_sync_y              <= {`ADDR_WIDTH{1'b0}};
            o_vld                 <= 1'b0;
        end 
        else if (i_vld) begin
            // Line buffer
            line_buf_0[i_x_cnt] <= i_pixel;
            line_buf_1[i_x_cnt] <= line_buf_0[i_x_cnt];

            
            
               r_p31 <= r_p32; r_p32 <= r_p33; r_p33 <= i_pixel;          
            if (i_y_cnt <= 0) begin
                r_p21 <= r_p22; r_p22 <= r_p23; r_p23 <= {`DATA_WIDTH{1'b0}};
            end else begin
                r_p21 <= r_p22; r_p22 <= r_p23; r_p23 <= line_buf_0[i_x_cnt];
            end
            if (i_y_cnt <= 1) begin
                r_p11 <= r_p12; r_p12 <= r_p13; r_p13 <= {`DATA_WIDTH{1'b0}};
            end else begin
                r_p11 <= r_p12; r_p12 <= r_p13; r_p13 <= line_buf_1[i_x_cnt];
            end

                if(o_sync_x == img_w - 1'b1 && o_sync_y == img_h - 1'b1)
                o_vld    <= 1'b0;
                if(i_y_cnt == 1'b1 && i_x_cnt == 1'b0)
                o_vld    <= 1'b1;
                o_sync_x <= i_x_cnt;
                d_y      <= i_y_cnt;
                if(d_y != i_y_cnt) begin
                    if(o_sync_y != img_h - 1'b1)
                        o_sync_y <= d_y;
                    else
                        o_sync_y <= {`DATA_WIDTH{1'b0}};
                end
        end
    end

    assign o_p11 = (o_sync_x == 0)                                         ? {`DATA_WIDTH{1'b0}} : r_p11;
    assign o_p12 = r_p12;
    assign o_p13 = (o_sync_x == img_w-1'b1)                                ? {`DATA_WIDTH{1'b0}} : r_p13;
    assign o_p21 = (o_sync_x == 0)                                         ? {`DATA_WIDTH{1'b0}} : r_p21;
    assign o_p22 = r_p22;
    assign o_p23 = (o_sync_x == img_w-1'b1)                                ? {`DATA_WIDTH{1'b0}} : r_p23;
    assign o_p31 = (!o_vld || o_sync_x == 0 || o_sync_y == img_h-1'b1)     ? {`DATA_WIDTH{1'b0}} : r_p31;
    assign o_p32 = (!o_vld || o_sync_y == img_h-1'b1)                      ? {`DATA_WIDTH{1'b0}} : r_p32;
    assign o_p33 = (!o_vld || o_sync_x == img_w || o_sync_y == img_h-1'b1) ? {`DATA_WIDTH{1'b0}} : r_p33;

endmodule

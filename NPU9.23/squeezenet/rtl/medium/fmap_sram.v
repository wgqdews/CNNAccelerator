`include "params.vh"

module fmap_sram #(
    parameter DEPTH_A = 1,
    parameter DEPTH_B = 1
) (
    input  wire                                    clk,
    input  wire                                    rst_n,

    input  wire [`ARRAY_ROWS-1:0]                  we_a,
    input  wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] waddr_a_flat,
    input  wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       wdata_a_flat,

    input  wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] rd_addr_a_flat,
    output wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       rd_data_a_flat,

    input  wire [`ARRAY_COLS-1:0]                  we_b,
    input  wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] waddr_b_flat,
    input  wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       wdata_b_flat,

    input  wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat,
    output wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat
);
    genvar i;
    generate
        for (i = 0; i < `ARRAY_ROWS; i = i + 1) begin : bank_a
            fmap_in_bank #(.DEPTH(DEPTH_A)) u_mem (
                .clk   (clk),
                .rst_n (rst_n),
                .raddr (rd_addr_a_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata (rd_data_a_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH]),
                .we    (we_a[i]),
                .waddr (waddr_a_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata (wdata_a_flat[(i+1)*`ACT_WIDTH-1 -: `ACT_WIDTH])
            );
        end
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin : bank_b
            fmap_out_bank #(.DEPTH(DEPTH_B)) u_mem (
                .clk   (clk),
                .we    (we_b[i]),
                .waddr (waddr_b_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata (wdata_b_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]),
                .raddr (rd_addr_b_flat[(i+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata (rd_data_b_flat[(i+1)*`OUT_WIDTH-1 -: `OUT_WIDTH])
            );
        end
    endgenerate
endmodule

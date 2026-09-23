`include "params.vh"

module weight_sram #(
    parameter BANK_DEPTH = 1
) (
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire [`ARRAY_COLS-1:0]             we,
    input  wire [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0] waddr_flat,
    input  wire [`ARRAY_COLS*`WGT_WIDTH-1:0]  wdata_flat,
    input  wire [`WGT_ADDR_WIDTH-1:0]         row_index,
    output wire [`ARRAY_COLS*`WGT_WIDTH-1:0]  row_data_flat
);
    genvar n;
    generate
        for (n = 0; n < `ARRAY_COLS; n = n + 1) begin : bank
            weight_bank #(.DEPTH(BANK_DEPTH)) u_mem (
                .clk   (clk),
                .rst_n (rst_n),
                .we    (we[n]),
                .waddr (waddr_flat[(n+1)*`WGT_ADDR_WIDTH-1 -: `WGT_ADDR_WIDTH]),
                .wdata (wdata_flat[(n+1)*`WGT_WIDTH-1 -: `WGT_WIDTH]),
                .raddr (row_index),
                .rdata (row_data_flat[(n+1)*`WGT_WIDTH-1 -: `WGT_WIDTH])
            );
        end
    endgenerate
endmodule

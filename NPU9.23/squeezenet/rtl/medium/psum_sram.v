`include "params.vh"

module psum_sram #(
    parameter DEPTH = 1
) (
    input  wire                                      clk,
    input  wire [`ARRAY_COLS-1:0]                    we,
    input  wire [`ARRAY_COLS*`PSUM_ADDR_WIDTH-1:0]   addr_flat,
`ifdef SRAM_MACRO
    input  wire [`ARRAY_COLS*`PSUM_ADDR_WIDTH-1:0]   raddr_flat,
`endif
    input  wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]  wdata_flat,
    output wire signed [`ARRAY_COLS*`ACC_WIDTH-1:0]  rdata_flat
);
    genvar n;
    generate
        for (n = 0; n < `ARRAY_COLS; n = n + 1) begin : bank
            psum_bank #(.DEPTH(DEPTH)) u_mem (
                .clk   (clk),
                .we    (we[n]),
                .addr  (addr_flat[(n+1)*`PSUM_ADDR_WIDTH-1 -: `PSUM_ADDR_WIDTH]),
`ifdef SRAM_MACRO
                .raddr (raddr_flat[(n+1)*`PSUM_ADDR_WIDTH-1 -: `PSUM_ADDR_WIDTH]),
`endif
                .wdata (wdata_flat[(n+1)*`ACC_WIDTH-1 -: `ACC_WIDTH]),
                .rdata (rdata_flat[(n+1)*`ACC_WIDTH-1 -: `ACC_WIDTH])
            );
        end
    endgenerate
endmodule


`include "../../inc/config.vh"

module sram_1r1w_bank (

    input  logic                    clk,

    // Write port
    input  logic                    wr_en,
    input  wire  [`ADDR_WIDTH-1:0]  wr_addr [`sramnum-1:0],
    input  wire  [`DATA_WIDTH-1:0]  wr_data [`sramnum-1:0],

    // Read port
    input  logic                    rd_en,
    input  wire  [`ADDR_WIDTH-1:0]  rd_addr [`sramnum-1:0],
    output logic [`DATA_WIDTH-1:0]  rd_data [`sramnum-1:0]
);
genvar i;
    generate
        for (i = 0; i < `sramnum; i = i + 1) begin : gen_sram_bank
            sram_1r1w u_sram_1r1w (
                .clk     (clk),
                .wr_en   (wr_en),
                .wr_addr (wr_addr[i]), 
                .wr_data (wr_data[i]),
                .rd_en   (rd_en),
                .rd_addr (rd_addr[i]),
                .rd_data (rd_data[i])
            );
        end
    endgenerate
endmodule
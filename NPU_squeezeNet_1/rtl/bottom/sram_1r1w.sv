
`include "../../inc/config.vh"

module sram_1r1w (
    input  logic                    clk,

    // Write port
    input  logic                    wr_en,
    input  logic [`ADDR_WIDTH-1:0]             wr_addr,
    input  logic [`DATA_WIDTH-1:0]  wr_data,

    // Read port
    input  logic                    rd_en,
    input  logic [`ADDR_WIDTH-1:0]             rd_addr,
    output logic [`DATA_WIDTH-1:0]  rd_data
);
    // 2^17
    logic [`DATA_WIDTH-1:0] mem [0:131071];

    // Write logic
    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end
    // Read logic
    always_ff @(posedge clk) begin
        if (rd_en) begin
                rd_data <= mem[rd_addr];
        end
    end
endmodule
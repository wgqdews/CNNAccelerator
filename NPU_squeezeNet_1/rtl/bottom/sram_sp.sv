// ============================================================
// sram_sp.sv
// Single-Port SRAM (單埠:同一 cycle 只能 read 或 write 其中一種)
// - en=1 且 wr_en=1  -> write
// - en=1 且 wr_en=0  -> read
// - en=0             -> idle (rd_data 維持上一筆有效值)
// ============================================================
`include "../../inc/config.vh"

module sram_sp #(
    parameter int DEPTH      = 262144,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic                    clk,

    input  logic                    en,         // chip enable
    input  logic                    wr_en,      // 1=write, 0=read (en=1 時才有意義)
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [`DATA_WIDTH-1:0]   wr_data,
    output logic [`DATA_WIDTH-1:0]   rd_data
);

    // ---------------------------------------------------------
    // Memory array (behavioral model, 實際會替換成 SP SRAM hard macro)
    // ---------------------------------------------------------
    logic [`DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ---------------------------------------------------------
    // 單埠邏輯:同一 cycle 只允許一種操作
    // ---------------------------------------------------------
    always_ff @(posedge clk) begin
        if (en) begin
            if (wr_en) begin
                mem[addr] <= wr_data;
                // 大部分單埠 SRAM compiler:write cycle 時 rd_data 為 don't care
                // 這裡不更動 rd_data,維持前一筆讀值
            end else begin
                rd_data <= mem[addr];
            end
        end
    end

endmodule
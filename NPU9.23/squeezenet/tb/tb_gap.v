`timescale 1ns/1ps
`include "gap_select.vh"

// GlobalAveragePool 獨立驗證用 testbench(不接完整鏈,先用 conv10 的真實輸出當合成輸入,
// 證明 gap_lane/gap_ctrl_fsm 正確)。結構比照 tb_maxpool.v:genvar-generate 載入輸入 bank ->
// reset -> start -> 等 done -> 透過 rd_addr_b_flat/rd_data_b_flat 讀回埠比對黃金輸出
// (黃金輸出來自 export_gap_golden.py,自己重算過一次並跟真實 onnxruntime QLinearGlobalAveragePool
// 輸出比對 bit-exact,見該腳本檔頭說明)。
module tb_gap;
    localparam integer CIN     = `GAP_CIN;
    localparam integer N_TILES = `GAP_N_TILES;
    localparam integer TIMEOUT_CYCLES = 1_000_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    wire done;

    wire [`CNT_WIDTH-1:0]           cfg_h_in    = `GAP_H_IN;
    wire [`CNT_WIDTH-1:0]           cfg_w_in    = `GAP_W_IN;
    wire [`CNT_WIDTH-1:0]           cfg_n_tiles = `GAP_N_TILES;
    wire [`CNT_WIDTH-1:0]           cfg_act_zp  = `GAP_ACT_ZP;
    wire [`CNT_WIDTH-1:0]           cfg_y_zp    = `GAP_Y_ZP;
    wire [`REQUANT_MULT_WIDTH-1:0]  cfg_mult    = `GAP_MULT;
    wire [`REQUANT_SHIFT_WIDTH-1:0] cfg_shift   = `GAP_SHIFT;

    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat;

    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] raddr_in_flat;
    wire [`ARRAY_COLS*`ACT_WIDTH-1:0]       rdata_in_flat;
    wire [`ARRAY_COLS-1:0]                  we_out_flat;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] waddr_out_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       wdata_out_flat;

    gap_top dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_h_in(cfg_h_in), .cfg_w_in(cfg_w_in), .cfg_n_tiles(cfg_n_tiles),
        .cfg_act_zp(cfg_act_zp), .cfg_y_zp(cfg_y_zp), .cfg_mult(cfg_mult), .cfg_shift(cfg_shift),
        .raddr_in_flat(raddr_in_flat), .rdata_in_flat(rdata_in_flat),
        .we_out_flat(we_out_flat), .waddr_out_flat(waddr_out_flat), .wdata_out_flat(wdata_out_flat)
    );

    always #5 clk = ~clk;

    genvar gi;
    generate
        for (gi = 0; gi < `ARRAY_ROWS; gi = gi + 1) begin : in_bank
            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk), .we(1'b0),
                .waddr({`FMAP_ADDR_WIDTH{1'b0}}), .wdata({`OUT_WIDTH{1'b0}}),
                .raddr(raddr_in_flat[(gi+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata(rdata_in_flat[(gi+1)*`ACT_WIDTH-1 -: `ACT_WIDTH])
            );
            initial begin
                reg [8*128-1:0] fname;
                $sformat(fname, "%0s/input_bank%02d.hex", `GOLDEN_DIR, gi);
`ifdef SRAM_MACRO
                $readmemh(fname, u_mem.u_mem.Memory);
`else
                $readmemh(fname, u_mem.mem);
`endif
            end
        end
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : out_bank
            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk), .we(we_out_flat[gi]),
                .waddr(waddr_out_flat[(gi+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .wdata(wdata_out_flat[(gi+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]),
                .raddr(rd_addr_b_flat[(gi+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata(rd_data_b_flat[(gi+1)*`OUT_WIDTH-1 -: `OUT_WIDTH])
            );
        end
    endgenerate

    reg [`OUT_WIDTH-1:0] expected_output [0:CIN-1];

    integer nt, n, c, mismatches, cyc;
    reg [`OUT_WIDTH-1:0] exp_v, act_v;
    reg dump_on;

    initial begin
        if ($test$plusargs("dump")) begin
            dump_on = 1'b1;
            $dumpfile("sim.vcd");
            $dumpvars(0, tb_gap);
        end else begin
            dump_on = 1'b0;
        end

        $readmemh({`GOLDEN_DIR, "/expected_output.hex"}, expected_output);

        rst_n = 1'b0;
        start = 1'b0;
        rd_addr_b_flat = {(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}};
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        cyc = 0;
        while (!done && cyc < TIMEOUT_CYCLES) begin
            @(posedge clk);
            cyc = cyc + 1;
        end

        if (!done) begin
            $display("[FAIL] TIMEOUT: done never asserted after %0d cycles", TIMEOUT_CYCLES);
            $finish;
        end
        $display("[INFO] done asserted after %0d cycles", cyc);

        mismatches = 0;
        for (nt = 0; nt < N_TILES; nt = nt + 1) begin
`ifdef SRAM_MACRO
            @(negedge clk);
            rd_addr_b_flat = {`ARRAY_COLS{nt[`FMAP_ADDR_WIDTH-1:0]}};
            @(negedge clk);
`else
            rd_addr_b_flat = {`ARRAY_COLS{nt[`FMAP_ADDR_WIDTH-1:0]}};
            #1;
`endif
            for (n = 0; n < `ARRAY_COLS; n = n + 1) begin
                c = nt * `ARRAY_COLS + n;
                if (c < CIN) begin
                    exp_v = expected_output[c];
                    act_v = rd_data_b_flat[(n+1)*`OUT_WIDTH-1 -: `OUT_WIDTH];
                    if (exp_v !== act_v) begin
                        mismatches = mismatches + 1;
                        if (mismatches <= 64)
                            $display("[MISMATCH] (c=%0d) expected=%0d actual=%0d", c, exp_v, act_v);
                    end
                end
            end
        end

        if (mismatches == 0)
            $display("[PASS] all %0d output elements match golden reference", CIN);
        else
            $display("[FAIL] %0d / %0d output elements mismatched", mismatches, CIN);

        $finish;
    end
endmodule

`timescale 1ns/1ps
`include "maxpool_select.vh"

// MaxPool 獨立驗證用 testbench(不接 conv1,先用合成資料證明 pool_lane/maxpool_ctrl_fsm 正確)。
// 結構比照 tb_conv_layer.v:genvar-generate 載入各 bank -> reset -> start -> 等 done ->
// 透過 rd_addr_b_flat/rd_data_b_flat 讀回埠逐一比對黃金輸出(對照 onnxruntime 真實 MaxPool)。
module tb_maxpool;
    localparam integer H_OUT   = `MAXPOOL_H_OUT;
    localparam integer W_OUT   = `MAXPOOL_W_OUT;
    localparam integer CIN     = `MAXPOOL_CIN;
    localparam integer N_TILES = `MAXPOOL_N_TILES;
    localparam integer OUT_LEN = H_OUT * W_OUT * CIN;
    localparam integer TIMEOUT_CYCLES = 5_000_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    wire done;

    wire [`CNT_WIDTH-1:0] cfg_h_in   = `MAXPOOL_H_IN;
    wire [`CNT_WIDTH-1:0] cfg_w_in   = `MAXPOOL_W_IN;
    wire [`CNT_WIDTH-1:0] cfg_h_out  = `MAXPOOL_H_OUT;
    wire [`CNT_WIDTH-1:0] cfg_w_out  = `MAXPOOL_W_OUT;
    wire [`CNT_WIDTH-1:0] cfg_n_tiles= `MAXPOOL_N_TILES;
    wire [`CNT_WIDTH-1:0] cfg_kh     = `MAXPOOL_KH;
    wire [`CNT_WIDTH-1:0] cfg_kw     = `MAXPOOL_KW;
    wire [`CNT_WIDTH-1:0] cfg_stride = `MAXPOOL_STRIDE;
    wire [`CNT_WIDTH-1:0] cfg_pad    = `MAXPOOL_PAD;

    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat;

    // Phase 2c:maxpool_top 改成純運算(bank 由外部接),testbench 這裡自己擁有輸入/輸出 bank,
    // 跟 chain2_top.v 的角色一樣(只是那邊輸入 bank 換成 conv1 的輸出 buf0)。
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] raddr_in_flat;
    wire [`ARRAY_COLS*`ACT_WIDTH-1:0]       rdata_in_flat;
    wire [`ARRAY_COLS-1:0]                  we_out_flat;
    wire [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] waddr_out_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       wdata_out_flat;

    maxpool_top dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_h_in(cfg_h_in), .cfg_w_in(cfg_w_in),
        .cfg_h_out(cfg_h_out), .cfg_w_out(cfg_w_out), .cfg_n_tiles(cfg_n_tiles),
        .cfg_kh(cfg_kh), .cfg_kw(cfg_kw), .cfg_stride(cfg_stride), .cfg_pad(cfg_pad),
        // Phase 3e:獨立測試不套用融合機制,明確關閉(避免浮接成 x 導致卡死)
        .cfg_fused(1'b0), .producer_n_tiles_done({`CNT_WIDTH{1'b0}}),
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

    reg [`OUT_WIDTH-1:0] expected_output [0:OUT_LEN-1];

    integer h, w, nt, n, c, mval, bank_addr, idx, mismatches, cyc;
    reg [`OUT_WIDTH-1:0] exp_v, act_v;
    reg dump_on;

    initial begin
        if ($test$plusargs("dump")) begin
            dump_on = 1'b1;
            $dumpfile("sim.vcd");
            $dumpvars(0, tb_maxpool);
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
        for (h = 0; h < H_OUT; h = h + 1) begin
            for (w = 0; w < W_OUT; w = w + 1) begin
                mval = h * W_OUT + w;
                for (nt = 0; nt < N_TILES; nt = nt + 1) begin
                    bank_addr = mval * N_TILES + nt;
`ifdef SRAM_MACRO
                    @(negedge clk);
                    rd_addr_b_flat = {`ARRAY_COLS{bank_addr[`FMAP_ADDR_WIDTH-1:0]}};
                    @(negedge clk);
`else
                    rd_addr_b_flat = {`ARRAY_COLS{bank_addr[`FMAP_ADDR_WIDTH-1:0]}};
                    #1;
`endif
                    for (n = 0; n < `ARRAY_COLS; n = n + 1) begin
                        c = nt * `ARRAY_COLS + n;
                        if (c < CIN) begin
                            idx = (h * W_OUT + w) * CIN + c;
                            exp_v = expected_output[idx];
                            act_v = rd_data_b_flat[(n+1)*`OUT_WIDTH-1 -: `OUT_WIDTH];
                            if (exp_v !== act_v) begin
                                mismatches = mismatches + 1;
                                if (mismatches <= 64)
                                    $display("[MISMATCH] (h=%0d,w=%0d,c=%0d) expected=%0d actual=%0d",
                                              h, w, c, exp_v, act_v);
                            end
                        end
                    end
                end
            end
        end

        if (mismatches == 0)
            $display("[PASS] all %0d output elements match golden reference", OUT_LEN);
        else
            $display("[FAIL] %0d / %0d output elements mismatched", mismatches, OUT_LEN);

        $finish;
    end
endmodule

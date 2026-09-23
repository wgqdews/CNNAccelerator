`timescale 1ns/1ps
`include "chain2_select.vh"

// Phase 2c 驗證用 testbench:conv1 -> MaxPool 真正串接(中間 buf0 是 chain2_top.v 內部的
// SRAM,不透過這裡搬資料)。載入 conv1 的權重/量化參數/輸入圖片 -> 拉 conv1 start、等 done ->
// 拉 MaxPool start、等 done -> 讀 buf1(MaxPool 輸出)跟 onnxruntime 真實跑完兩層的結果比對。
module tb_chain2;
    localparam integer H_OUT   = `CHAIN2_POOL_H_OUT;
    localparam integer W_OUT   = `CHAIN2_POOL_W_OUT;
    localparam integer COUT    = `CHAIN2_CONV_COUT;
    localparam integer N_TILES = `CHAIN2_CONV_N_TILES;
    localparam integer OUT_LEN = H_OUT * W_OUT * COUT;
    localparam integer TIMEOUT_CYCLES = 5_000_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg conv_start = 1'b0;
    reg pool_start = 1'b0;
    wire conv_done, pool_done;

    wire [`CNT_WIDTH-1:0] conv_cfg_cin    = `CHAIN2_CONV_CIN;
    wire [`CNT_WIDTH-1:0] conv_cfg_cout   = `CHAIN2_CONV_COUT;
    wire [`CNT_WIDTH-1:0] conv_cfg_h_in   = `CHAIN2_CONV_H_IN;
    wire [`CNT_WIDTH-1:0] conv_cfg_w_in   = `CHAIN2_CONV_W_IN;
    wire [`CNT_WIDTH-1:0] conv_cfg_kw     = `CHAIN2_CONV_KW;
    wire [`CNT_WIDTH-1:0] conv_cfg_stride = `CHAIN2_CONV_STRIDE;
    wire [`CNT_WIDTH-1:0] conv_cfg_pad    = `CHAIN2_CONV_PAD;
    wire [`CNT_WIDTH-1:0] conv_cfg_h_out  = `CHAIN2_CONV_H_OUT;
    wire [`CNT_WIDTH-1:0] conv_cfg_w_out  = `CHAIN2_CONV_W_OUT;
    wire [`CNT_WIDTH-1:0] conv_cfg_k_real = `CHAIN2_CONV_K_REAL;
    wire [`CNT_WIDTH-1:0] conv_cfg_k_tiles= `CHAIN2_CONV_K_TILES;
    wire [`CNT_WIDTH-1:0] conv_cfg_n_tiles= `CHAIN2_CONV_N_TILES;
    wire [`CNT_WIDTH-1:0] conv_cfg_act_zp = `CHAIN2_CONV_ACT_ZP;
    wire [`CNT_WIDTH-1:0] conv_cfg_y_zp   = `CHAIN2_CONV_Y_ZP;

    wire [`CNT_WIDTH-1:0] pool_cfg_h_out  = `CHAIN2_POOL_H_OUT;
    wire [`CNT_WIDTH-1:0] pool_cfg_w_out  = `CHAIN2_POOL_W_OUT;
    wire [`CNT_WIDTH-1:0] pool_cfg_kh     = `CHAIN2_POOL_KH;
    wire [`CNT_WIDTH-1:0] pool_cfg_kw     = `CHAIN2_POOL_KW;
    wire [`CNT_WIDTH-1:0] pool_cfg_stride = `CHAIN2_POOL_STRIDE;
    wire [`CNT_WIDTH-1:0] pool_cfg_pad    = `CHAIN2_POOL_PAD;

    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat;

    chain2_top dut (
        .clk(clk), .rst_n(rst_n),
        .conv_start(conv_start), .conv_done(conv_done),
        .conv_cfg_cin(conv_cfg_cin), .conv_cfg_cout(conv_cfg_cout),
        .conv_cfg_h_in(conv_cfg_h_in), .conv_cfg_w_in(conv_cfg_w_in), .conv_cfg_kw(conv_cfg_kw),
        .conv_cfg_stride(conv_cfg_stride), .conv_cfg_pad(conv_cfg_pad),
        .conv_cfg_h_out(conv_cfg_h_out), .conv_cfg_w_out(conv_cfg_w_out),
        .conv_cfg_k_real(conv_cfg_k_real), .conv_cfg_k_tiles(conv_cfg_k_tiles),
        .conv_cfg_n_tiles(conv_cfg_n_tiles),
        .conv_cfg_act_zp(conv_cfg_act_zp), .conv_cfg_y_zp(conv_cfg_y_zp),
        .pool_start(pool_start), .pool_done(pool_done),
        .pool_cfg_h_out(pool_cfg_h_out), .pool_cfg_w_out(pool_cfg_w_out),
        .pool_cfg_kh(pool_cfg_kh), .pool_cfg_kw(pool_cfg_kw),
        .pool_cfg_stride(pool_cfg_stride), .pool_cfg_pad(pool_cfg_pad),
        .rd_addr_b_flat(rd_addr_b_flat), .rd_data_b_flat(rd_data_b_flat)
    );

    always #5 clk = ~clk;

    // ---- 逐 bank 灌 conv1 的權重 / bias / requant 參數 / 輸入圖片(genvar 常數索引展開) ----
    genvar gi;
    generate
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : load_weight_bank
            initial begin
                reg [8*128-1:0] fname;
                $sformat(fname, "%0s/weights_bank%02d.hex", `GOLDEN_DIR, gi);
`ifdef SRAM_MACRO
                begin : wgt_stage_blk
                    reg [`WGT_WIDTH-1:0] stage [0:`MAX_WGT_BANK_DEPTH-1];
                    integer k;
                    $readmemh(fname, stage);
                    for (k = 0; k < 19968; k = k + 1)
                        dut.u_conv1.u_weight_sram.bank[gi].u_mem.u_mem_lo.Memory[k] = stage[k];
                    for (k = 19968; k < `MAX_WGT_BANK_DEPTH; k = k + 1)
                        dut.u_conv1.u_weight_sram.bank[gi].u_mem.u_mem_hi.Memory[k-19968] = stage[k];
                end
`else
                $readmemh(fname, dut.u_conv1.u_weight_sram.bank[gi].u_mem.mem);
`endif
            end
        end
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : load_requant_bank
            initial begin
                reg [8*128-1:0] fname_b, fname_m, fname_s;
                $sformat(fname_b, "%0s/bias_bank%02d.hex", `GOLDEN_DIR, gi);
                $sformat(fname_m, "%0s/requant_mult_bank%02d.hex", `GOLDEN_DIR, gi);
                $sformat(fname_s, "%0s/requant_shift_bank%02d.hex", `GOLDEN_DIR, gi);
                $readmemh(fname_b, dut.u_conv1.u_post_process.lane[gi].u_requant_lane.bias_mem);
                $readmemh(fname_m, dut.u_conv1.u_post_process.lane[gi].u_requant_lane.mult_mem);
                $readmemh(fname_s, dut.u_conv1.u_post_process.lane[gi].u_requant_lane.shift_mem);
            end
        end
        for (gi = 0; gi < `ARRAY_ROWS; gi = gi + 1) begin : load_fmap_a_bank
            initial begin
                reg [8*128-1:0] fname;
                $sformat(fname, "%0s/input_bank%02d.hex", `GOLDEN_DIR, gi);
`ifdef SRAM_MACRO
                begin : fmi_stage_blk
                    reg [`ACT_WIDTH-1:0] stage [0:`MAX_FMAP_IN_BANK_DEPTH-1];
                    integer k;
                    $readmemh(fname, stage);
                    for (k = 0; k < 32768; k = k + 1)
                        dut.u_conv1.u_fmap_sram.bank_a[gi].u_mem.u_mem0.Memory[k] = stage[k];
                    for (k = 32768; k < 65536; k = k + 1)
                        dut.u_conv1.u_fmap_sram.bank_a[gi].u_mem.u_mem1.Memory[k-32768] = stage[k];
                    for (k = 65536; k < 98304; k = k + 1)
                        dut.u_conv1.u_fmap_sram.bank_a[gi].u_mem.u_mem2.Memory[k-65536] = stage[k];
                    for (k = 98304; k < 131072; k = k + 1)
                        dut.u_conv1.u_fmap_sram.bank_a[gi].u_mem.u_mem3.Memory[k-98304] = stage[k];
                    for (k = 131072; k < `MAX_FMAP_IN_BANK_DEPTH; k = k + 1)
                        dut.u_conv1.u_fmap_sram.bank_a[gi].u_mem.u_mem4.Memory[k-131072] = stage[k];
                end
`else
                $readmemh(fname, dut.u_conv1.u_fmap_sram.bank_a[gi].u_mem.mem);
`endif
            end
        end
    endgenerate

    reg [`OUT_WIDTH-1:0] expected_output [0:OUT_LEN-1];

    integer h, w, nt, n, c, mval, bank_addr, idx, mismatches, cyc;
    reg [`OUT_WIDTH-1:0] exp_v, act_v;
    reg dump_on;
    reg conv_done_seen;

    initial begin
        if ($test$plusargs("dump")) begin
            dump_on = 1'b1;
            $dumpfile("sim.vcd");
            $dumpvars(0, tb_chain2);
        end else begin
            dump_on = 1'b0;
        end

        $readmemh({`GOLDEN_DIR, "/expected_output.hex"}, expected_output);

        rst_n = 1'b0;
        conv_start = 1'b0;
        pool_start = 1'b0;
        rd_addr_b_flat = {(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}};
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // ---- Phase 3e:conv1 跟 MaxPool 同時啟動,channel-group 級管線化(MaxPool 內部
        //      的 S_WAIT 會自己卡住,直到 conv1 回報對應的 n_tile 已經寫完才會真的往下跑,
        //      見 maxpool_ctrl_fsm.v/chain2_top.v)。不再是「等 conv_done 才拉 pool_start」。
        conv_start = 1'b1;
        pool_start = 1'b1;
        @(posedge clk);
        conv_start = 1'b0;
        pool_start = 1'b0;
        cyc = 0;
        conv_done_seen = 1'b0;
        while (!pool_done && cyc < TIMEOUT_CYCLES) begin
            @(posedge clk);
            cyc = cyc + 1;
            if (conv_done && !conv_done_seen) begin
                conv_done_seen = 1'b1;
                $display("[INFO] conv1 done asserted after %0d cycles", cyc);
            end
        end
        if (!pool_done) begin
            $display("[FAIL] TIMEOUT: pool_done never asserted after %0d cycles", TIMEOUT_CYCLES);
            $finish;
        end
        $display("[INFO] maxpool done asserted after %0d cycles", cyc);

        // ---- 比對 buf1(最終結果) ----
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
                        if (c < COUT) begin
                            idx = (h * W_OUT + w) * COUT + c;
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

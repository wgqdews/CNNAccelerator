`timescale 1ns/1ps
`include "params.vh"
`include "golden_dir.vh"
`include "seq_chain_cfg.vh"

// Phase 3a 驗證用 testbench:整條 SqueezeNet 骨幹(conv1 -> ... -> conv10 ->
// GlobalAveragePool,30 個階段,26 層 conv、3 個 MaxPool、1 個 GlobalAveragePool)。
// 同一顆 conv 引擎依序服務全部 26 層,每層的權重/bias/mult/shift 都灌進同一份記憶體的
// 不同位址範圍(offset 直接烘焙成 seq_chain_weight_loads.vh/seq_chain_bias_loads.vh 裡的
// Verilog 字面值,由 export_seq_chain_golden.py 產生,跟 conv_weight_base_offset.hex/
// conv_bias_base_offset.hex 裡的值保證一致,不會對不上)。
// testbench 只拉一次 start、等一次 all_done,硬體自己跑完全部 30 個階段。
module tb_seq_chain;
    localparam integer H_OUT   = `SEQ_CHAIN_H_OUT;
    localparam integer W_OUT   = `SEQ_CHAIN_W_OUT;
    localparam integer COUT    = `SEQ_CHAIN_COUT;
    localparam integer N_TILES = `SEQ_CHAIN_N_TILES;
    localparam integer OUT_LEN = H_OUT * W_OUT * COUT;
    localparam integer TIMEOUT_CYCLES = 5_000_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    wire all_done;

    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_a_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_a_flat;
    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat;

    // ---- 模組層級的共用暫存陣列 + 真正的權重/conv1 私有 bufImg 寫入埠(Phase 5,
    //      取代舊的 hierarchical path 直接戳 macro 內部 `Memory` 的後門載入方式;
    //      跟 tb_conv_layer.v 用的是同一套設計,理由見 squeezenet/README.md
    //      Phase 5 (a)(b)(c) 三段排查記錄)。 ----
    reg [`WGT_WIDTH-1:0] wgt_stage_shared    [0:`ARRAY_COLS-1][0:`MAX_WGT_BANK_DEPTH-1];
    reg [`ACT_WIDTH-1:0] fmap_a_stage_shared [0:`ARRAY_ROWS-1][0:`MAX_FMAP_IN_BANK_DEPTH-1];

    reg  [`ARRAY_COLS-1:0]                 wgt_we         = {`ARRAY_COLS{1'b0}};
    reg  [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0] wgt_waddr_flat = {(`ARRAY_COLS*`WGT_ADDR_WIDTH){1'b0}};
    reg  [`ARRAY_COLS*`WGT_WIDTH-1:0]      wgt_wdata_flat = {(`ARRAY_COLS*`WGT_WIDTH){1'b0}};

    reg  [`ARRAY_ROWS-1:0]                  fmap_a_we         = {`ARRAY_ROWS{1'b0}};
    reg  [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] fmap_a_waddr_flat = {(`ARRAY_ROWS*`FMAP_ADDR_WIDTH){1'b0}};
    reg  [`ARRAY_ROWS*`ACT_WIDTH-1:0]       fmap_a_wdata_flat = {(`ARRAY_ROWS*`ACT_WIDTH){1'b0}};

    seq_chain_top dut (
        .clk(clk), .rst_n(rst_n), .start(start), .all_done(all_done),
        .rd_addr_a_flat(rd_addr_a_flat), .rd_data_a_flat(rd_data_a_flat),
        .rd_addr_b_flat(rd_addr_b_flat), .rd_data_b_flat(rd_data_b_flat),
        .wgt_we(wgt_we), .wgt_waddr_flat(wgt_waddr_flat), .wgt_wdata_flat(wgt_wdata_flat),
        .fmap_a_we(fmap_a_we), .fmap_a_waddr_flat(fmap_a_waddr_flat), .fmap_a_wdata_flat(fmap_a_wdata_flat)
    );

    always #5 clk = ~clk;

    // ---- 26 層的權重/bias/requant,各自灌進同一份記憶體的不同位址範圍(genvar 常數索引展開)。
    //      每層的 $sformat/$readmemh 呼叫都是 export_seq_chain_golden.py 自動產生的
    //      (seq_chain_weight_loads.vh/seq_chain_bias_loads.vh),offset 直接烘焙成字面值,
    //      跟 conv_weight_base_offset.hex/conv_bias_base_offset.hex 保證一致。權重讀進來後
    //      只是複製進 wgt_stage_shared,真正驅動寫入埠的動作交給下面集中的 task。
    //      bias/mult/shift 不是 SRAM macro,沒有 P1735 保護,維持原本直接 $readmemh
    //      進 DUT 內部陣列的寫法不受影響。 ----
    genvar gi;
    generate
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : load_weight_bank
            initial begin
                reg [8*160-1:0] fname;
                `include "seq_chain_weight_loads.vh"
            end
        end
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : load_requant_bank
            initial begin
                reg [8*160-1:0] fname;
                `include "seq_chain_bias_loads.vh"
            end
        end
        for (gi = 0; gi < `ARRAY_ROWS; gi = gi + 1) begin : load_fmap_a_bank
            initial begin
                reg [8*128-1:0] fname;
                reg [`ACT_WIDTH-1:0] stage [0:`MAX_FMAP_IN_BANK_DEPTH-1];
                integer k;
                $sformat(fname, "%0s/input_bank%02d.hex", `GOLDEN_DIR, gi);
                $readmemh(fname, stage);
                for (k = 0; k < `MAX_FMAP_IN_BANK_DEPTH; k = k + 1)
                    fmap_a_stage_shared[gi][k] = stage[k];
            end
        end
    endgenerate

    // ---- 集中驅動寫入埠(單一個 process,見檔頭 Phase 5 的說明) ----
    task load_weights_via_port;
        integer row, lane;
        begin
            for (row = 0; row < `MAX_WGT_BANK_DEPTH; row = row + 1) begin
                @(negedge clk);
                wgt_we = {`ARRAY_COLS{1'b1}};
                for (lane = 0; lane < `ARRAY_COLS; lane = lane + 1) begin
                    wgt_waddr_flat[(lane+1)*`WGT_ADDR_WIDTH-1 -: `WGT_ADDR_WIDTH] = row[`WGT_ADDR_WIDTH-1:0];
                    wgt_wdata_flat[(lane+1)*`WGT_WIDTH-1 -: `WGT_WIDTH]          = wgt_stage_shared[lane][row];
                end
            end
            @(negedge clk);
            wgt_we = {`ARRAY_COLS{1'b0}};
        end
    endtask

    task load_fmap_a_via_port;
        integer row, lane;
        begin
            for (row = 0; row < `MAX_FMAP_IN_BANK_DEPTH; row = row + 1) begin
                @(negedge clk);
                fmap_a_we = {`ARRAY_ROWS{1'b1}};
                for (lane = 0; lane < `ARRAY_ROWS; lane = lane + 1) begin
                    fmap_a_waddr_flat[(lane+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH] = row[`FMAP_ADDR_WIDTH-1:0];
                    fmap_a_wdata_flat[(lane+1)*`ACT_WIDTH-1 -: `ACT_WIDTH]            = fmap_a_stage_shared[lane][row];
                end
            end
            @(negedge clk);
            fmap_a_we = {`ARRAY_ROWS{1'b0}};
        end
    endtask

    // ---- layer_sequencer 的表格(主表 + conv/maxpool 子表) ----
    initial begin
        reg [8*128-1:0] fn;
        $sformat(fn, "%0s/stage_op_type.hex", `GOLDEN_DIR);  $readmemh(fn, dut.u_seq.stage_op_type);
        $sformat(fn, "%0s/stage_in_buf.hex", `GOLDEN_DIR);   $readmemh(fn, dut.u_seq.stage_in_buf);
        $sformat(fn, "%0s/stage_out_buf.hex", `GOLDEN_DIR);  $readmemh(fn, dut.u_seq.stage_out_buf);

        $sformat(fn, "%0s/conv_cin.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_conv_cin);
        $sformat(fn, "%0s/conv_cout.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_conv_cout);
        $sformat(fn, "%0s/conv_h_in.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_conv_h_in);
        $sformat(fn, "%0s/conv_w_in.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_conv_w_in);
        $sformat(fn, "%0s/conv_kw.hex", `GOLDEN_DIR);        $readmemh(fn, dut.u_seq.t_conv_kw);
        $sformat(fn, "%0s/conv_stride.hex", `GOLDEN_DIR);    $readmemh(fn, dut.u_seq.t_conv_stride);
        $sformat(fn, "%0s/conv_pad.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_conv_pad);
        $sformat(fn, "%0s/conv_h_out.hex", `GOLDEN_DIR);     $readmemh(fn, dut.u_seq.t_conv_h_out);
        $sformat(fn, "%0s/conv_w_out.hex", `GOLDEN_DIR);     $readmemh(fn, dut.u_seq.t_conv_w_out);
        $sformat(fn, "%0s/conv_k_real.hex", `GOLDEN_DIR);    $readmemh(fn, dut.u_seq.t_conv_k_real);
        $sformat(fn, "%0s/conv_k_tiles.hex", `GOLDEN_DIR);   $readmemh(fn, dut.u_seq.t_conv_k_tiles);
        $sformat(fn, "%0s/conv_n_tiles.hex", `GOLDEN_DIR);   $readmemh(fn, dut.u_seq.t_conv_n_tiles);
        $sformat(fn, "%0s/conv_act_zp.hex", `GOLDEN_DIR);    $readmemh(fn, dut.u_seq.t_conv_act_zp);
        $sformat(fn, "%0s/conv_y_zp.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_conv_y_zp);
        $sformat(fn, "%0s/conv_out_n_tile_offset.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_out_n_tile_offset);
        $sformat(fn, "%0s/conv_out_n_tiles_total.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_out_n_tiles_total);
        $sformat(fn, "%0s/conv_input_mode.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_input_mode);
        $sformat(fn, "%0s/conv_weight_base_offset.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_weight_base_offset);
        $sformat(fn, "%0s/conv_bias_base_offset.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_bias_base_offset);
        $sformat(fn, "%0s/conv_pack_factor.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_pack_factor);
        $sformat(fn, "%0s/conv_pack_remainder.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_pack_remainder);
        $sformat(fn, "%0s/conv_pack_base_group.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_pack_base_group);
        $sformat(fn, "%0s/conv_replicate_remainder.hex", `GOLDEN_DIR);
        $readmemh(fn, dut.u_seq.t_conv_replicate_remainder);

        $sformat(fn, "%0s/pool_h_in.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_pool_h_in);
        $sformat(fn, "%0s/pool_w_in.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_pool_w_in);
        $sformat(fn, "%0s/pool_n_tiles.hex", `GOLDEN_DIR);   $readmemh(fn, dut.u_seq.t_pool_n_tiles);
        $sformat(fn, "%0s/pool_h_out.hex", `GOLDEN_DIR);     $readmemh(fn, dut.u_seq.t_pool_h_out);
        $sformat(fn, "%0s/pool_w_out.hex", `GOLDEN_DIR);     $readmemh(fn, dut.u_seq.t_pool_w_out);
        $sformat(fn, "%0s/pool_kh.hex", `GOLDEN_DIR);        $readmemh(fn, dut.u_seq.t_pool_kh);
        $sformat(fn, "%0s/pool_kw.hex", `GOLDEN_DIR);        $readmemh(fn, dut.u_seq.t_pool_kw);
        $sformat(fn, "%0s/pool_stride.hex", `GOLDEN_DIR);    $readmemh(fn, dut.u_seq.t_pool_stride);
        $sformat(fn, "%0s/pool_pad.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_pool_pad);

        $sformat(fn, "%0s/gap_h_in.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_gap_h_in);
        $sformat(fn, "%0s/gap_w_in.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_gap_w_in);
        $sformat(fn, "%0s/gap_n_tiles.hex", `GOLDEN_DIR);    $readmemh(fn, dut.u_seq.t_gap_n_tiles);
        $sformat(fn, "%0s/gap_act_zp.hex", `GOLDEN_DIR);     $readmemh(fn, dut.u_seq.t_gap_act_zp);
        $sformat(fn, "%0s/gap_y_zp.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_gap_y_zp);
        $sformat(fn, "%0s/gap_mult.hex", `GOLDEN_DIR);       $readmemh(fn, dut.u_seq.t_gap_mult);
        $sformat(fn, "%0s/gap_shift.hex", `GOLDEN_DIR);      $readmemh(fn, dut.u_seq.t_gap_shift);
    end

    reg [`OUT_WIDTH-1:0] expected_output [0:OUT_LEN-1];

    integer h, w, nt, n, c, mval, bank_addr, idx, mismatches, cyc;
    reg [`OUT_WIDTH-1:0] exp_v, act_v;
    reg dump_on;

    initial begin
        if ($test$plusargs("dump")) begin
            dump_on = 1'b1;
            $dumpfile("sim.vcd");
            $dumpvars(0, tb_seq_chain);
        end else begin
            dump_on = 1'b0;
        end

        $readmemh({`GOLDEN_DIR, "/expected_output.hex"}, expected_output);

        rst_n = 1'b0;
        start = 1'b0;
        rd_addr_a_flat = {(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}};
        rd_addr_b_flat = {(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}};
        repeat (4) @(posedge clk);

        load_weights_via_port();
        load_fmap_a_via_port();

        rst_n = 1'b1;
        @(posedge clk);

        // ---- 只拉一次 start,硬體自己跑完全部 30 個階段 ----
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        cyc = 0;
        while (!all_done && cyc < TIMEOUT_CYCLES) begin
            @(posedge clk);
            cyc = cyc + 1;
        end
        if (!all_done) begin
            $display("[FAIL] TIMEOUT: all_done never asserted after %0d cycles", TIMEOUT_CYCLES);
            $finish;
        end
        $display("[INFO] all_done asserted after %0d cycles", cyc);

        // ---- 最終結果在哪塊 buffer 是由 export_seq_chain_golden.py 記錄的真實值決定
        //      (SEQ_CHAIN_FINAL_BUF,不是手算 parity -- 每加一個新 stage 就會把 parity
        //      翻一次,手算容易錯,同時驅動 rd_addr_a_flat/rd_addr_b_flat 兩邊、只挑對的那個讀) ----
        mismatches = 0;
        for (h = 0; h < H_OUT; h = h + 1) begin
            for (w = 0; w < W_OUT; w = w + 1) begin
                mval = h * W_OUT + w;
                for (nt = 0; nt < N_TILES; nt = nt + 1) begin
                    bank_addr = mval * N_TILES + nt;
`ifdef SRAM_MACRO
                    // bufA/bufB(fmap_out_bank)換成同步 macro 後讀取有 1 個 clock cycle
                    // 延遲,位址要在 negedge 剛過之後才變動,避免跟緊接著的 posedge 產生
                    // 競爭關係(比照 tb_conv_layer.v 的做法)。
                    @(negedge clk);
                    rd_addr_a_flat = {`ARRAY_COLS{bank_addr[`FMAP_ADDR_WIDTH-1:0]}};
                    rd_addr_b_flat = {`ARRAY_COLS{bank_addr[`FMAP_ADDR_WIDTH-1:0]}};
                    @(negedge clk);
`else
                    rd_addr_a_flat = {`ARRAY_COLS{bank_addr[`FMAP_ADDR_WIDTH-1:0]}};
                    rd_addr_b_flat = {`ARRAY_COLS{bank_addr[`FMAP_ADDR_WIDTH-1:0]}};
                    #1;
`endif
                    for (n = 0; n < `ARRAY_COLS; n = n + 1) begin
                        c = nt * `ARRAY_COLS + n;
                        if (c < COUT) begin
                            idx = (h * W_OUT + w) * COUT + c;
                            exp_v = expected_output[idx];
                            act_v = `SEQ_CHAIN_FINAL_BUF
                                    ? rd_data_b_flat[(n+1)*`OUT_WIDTH-1 -: `OUT_WIDTH]
                                    : rd_data_a_flat[(n+1)*`OUT_WIDTH-1 -: `OUT_WIDTH];
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

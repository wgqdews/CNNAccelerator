`timescale 1ns/1ps
`include "layer_select.vh"

// 單層 conv 的自我檢查 testbench:
//   1. 每個 lane 各自在自己的 genvar 範圍內用 $readmemh 把 tb/golden/<layer>/ 下的權重/
//      輸入資料讀進一個「genvar 範圍內的本機暫存陣列」,再逐筆複製進「模組層級的共用
//      2D 陣列」(wgt_stage_shared/fmap_a_stage_shared)——iverilog 不支援把 2D 陣列的
//      單一 row 直接當整體傳給 $readmemh(只能整個陣列一起讀),所以第一步一定要留在
//      genvar 常數範圍內單獨讀;但複製進共用陣列只是單純的逐元素陣列索引賦值,不是
//      generate instance 參照,不受那個限制。
//   2. reset 保持拉低期間,由**單一個**主 initial block(不是 32 個各自獨立的 process)
//      集中把共用陣列的內容一拍一拍寫進 DUT 真正的寫入埠(wgt_we/wgt_waddr_flat/
//      wgt_wdata_flat、fmap_a_we/fmap_a_waddr_flat/fmap_a_wdata_flat)——早期版本讓
//      32 個 lane 各自獨立的 initial block 直接對同一條 flat bus 的不同 bit range 做
//      blocking assignment,這在 iverilog 上恰好沒事,但在 VCS 上會讀回全部 X(推測是
//      多個 process 對同一個 reg vector 不同 bit range 同時做 read-modify-write 時的
//      排程/實作差異,不同模擬器對這種寫法的行為沒有強保證),改成只用一個 process
//      集中驅動,徹底避開這個風險。Phase 5 之前這裡是直接用 hierarchical path 戳進
//      SRAM macro 內部的 `Memory`(繞過 IEEE P1735 保護區塊),iverilog 不理會 P1735
//      所以沒事,但正規遵守 P1735 的模擬器(VCS)會擋下對保護區塊內部訊號的外部存取、
//      連 $readmemh 這個系統任務都不例外,寫入完全不會生效、讀回永遠是 X。改成透過
//      真正的埠位寫入後,iverilog/VCS 都能正確運作,也更貼近真實硬體要有資料載入介面
//      時的樣子(`squeezenet/README.md` Phase 5 記錄了這兩輪問題的完整排查過程)。
//      bias/mult/shift(requant_lane.v)不是 SRAM macro,沒有 P1735 保護區塊,維持原本
//      直接 $readmemh 進 DUT 內部陣列的寫法不受影響。
//   3. 把 `LAYER_* 編譯期巨集值接到 DUT 的執行期 cfg_* port 上(Phase 2a:DUT 本身不再吃巨集,
//      這裡才是測試唯一還維持「編譯期選一層」的地方)
//   4. reset -> 拉一拍 start -> 等 done
//   5. 透過 top_conv_layer 的 rd_addr_b_flat/rd_data_b_flat 讀回埠逐一比對黃金輸出
// GOLDEN_DIR / LAYER_CFG_FILE 由 run.bat 透過產生 .vh 檔傳入,換層只需換命令列參數。
module tb_conv_layer;
    localparam integer H_OUT   = `LAYER_H_OUT;
    localparam integer W_OUT   = `LAYER_W_OUT;
    localparam integer COUT    = `LAYER_COUT;
    localparam integer N_TILES = `LAYER_N_TILES;
    localparam integer OUT_LEN = H_OUT * W_OUT * COUT;
    localparam integer TIMEOUT_CYCLES = 5_000_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    wire done;

    // ---- 執行期層設定,值來自編譯期 `LAYER_* 巨集(這次還是一次選一層) ----
    wire [`CNT_WIDTH-1:0] cfg_cin    = `LAYER_CIN;
    wire [`CNT_WIDTH-1:0] cfg_cout   = `LAYER_COUT;
    wire [`CNT_WIDTH-1:0] cfg_h_in   = `LAYER_H_IN;
    wire [`CNT_WIDTH-1:0] cfg_w_in   = `LAYER_W_IN;
    wire [`CNT_WIDTH-1:0] cfg_kw     = `LAYER_KW;
    wire [`CNT_WIDTH-1:0] cfg_stride = `LAYER_STRIDE;
    wire [`CNT_WIDTH-1:0] cfg_pad    = `LAYER_PAD;
    wire [`CNT_WIDTH-1:0] cfg_h_out  = `LAYER_H_OUT;
    wire [`CNT_WIDTH-1:0] cfg_w_out  = `LAYER_W_OUT;
    wire [`CNT_WIDTH-1:0] cfg_k_real = `LAYER_K_REAL;
    wire [`CNT_WIDTH-1:0] cfg_k_tiles= `LAYER_K_TILES;
    wire [`CNT_WIDTH-1:0] cfg_n_tiles= `LAYER_N_TILES;
    wire [`CNT_WIDTH-1:0] cfg_act_zp = `LAYER_ACT_ZP;
    wire [`CNT_WIDTH-1:0] cfg_y_zp   = `LAYER_Y_ZP;

    // 每個 lane 要寫幾筆
    wire [31:0] wgt_row_count    = cfg_k_tiles * cfg_n_tiles * `ARRAY_ROWS;
    wire [31:0] fmap_a_row_count = cfg_h_in * cfg_w_in * cfg_cin;

    // 模組層級的共用暫存陣列(不在任何 generate 範圍內,所以可以用執行期變數同時索引
    // 「哪個 lane」跟「哪一筆」兩個維度)——各 lane 的 $readmemh 結果先複製進這裡,
    // 真正驅動寫入埠的動作統一交給下面單一個 initial block 集中處理。
    reg [`WGT_WIDTH-1:0] wgt_stage_shared    [0:`ARRAY_COLS-1][0:`MAX_WGT_BANK_DEPTH-1];
    reg [`ACT_WIDTH-1:0] fmap_a_stage_shared [0:`ARRAY_ROWS-1][0:`MAX_FMAP_IN_BANK_DEPTH-1];

    // ---- weight SRAM 真正的寫入埠(見檔頭說明) ----
    reg  [`ARRAY_COLS-1:0]                 wgt_we         = {`ARRAY_COLS{1'b0}};
    reg  [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0] wgt_waddr_flat = {(`ARRAY_COLS*`WGT_ADDR_WIDTH){1'b0}};
    reg  [`ARRAY_COLS*`WGT_WIDTH-1:0]      wgt_wdata_flat = {(`ARRAY_COLS*`WGT_WIDTH){1'b0}};

    // ---- 私有 bufImg 真正的寫入埠(duplicated 模式,這個測試固定用這個模式) ----
    reg  [`ARRAY_ROWS-1:0]                  fmap_a_we         = {`ARRAY_ROWS{1'b0}};
    reg  [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] fmap_a_waddr_flat = {(`ARRAY_ROWS*`FMAP_ADDR_WIDTH){1'b0}};
    reg  [`ARRAY_ROWS*`ACT_WIDTH-1:0]       fmap_a_wdata_flat = {(`ARRAY_ROWS*`ACT_WIDTH){1'b0}};

    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat;

    top_conv_layer dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_cin(cfg_cin), .cfg_cout(cfg_cout), .cfg_h_in(cfg_h_in), .cfg_w_in(cfg_w_in),
        .cfg_kw(cfg_kw), .cfg_stride(cfg_stride), .cfg_pad(cfg_pad),
        .cfg_h_out(cfg_h_out), .cfg_w_out(cfg_w_out), .cfg_k_real(cfg_k_real),
        .cfg_k_tiles(cfg_k_tiles), .cfg_n_tiles(cfg_n_tiles),
        .cfg_act_zp(cfg_act_zp), .cfg_y_zp(cfg_y_zp),
        // 單層獨立測試沒有 concat,offset=0、total=cfg_n_tiles(等同不偏移)
        .cfg_out_n_tile_offset({`CNT_WIDTH{1'b0}}), .cfg_out_n_tiles_total(cfg_n_tiles),
        .cfg_weight_base_offset({`WGT_ADDR_WIDTH{1'b0}}), .cfg_bias_base_offset({`CNT_WIDTH{1'b0}}),
        // 單層獨立測試用內部 bufImg(跟 Phase 2a 之前完全一樣),不用外部匯流排
        .cfg_input_mode(1'b0), .fmap_a_addr_out_flat(),
        .fmap_a_rdata_ext_flat({(`ARRAY_ROWS*`ACT_WIDTH){1'b0}}),
        .fmap_a_we(fmap_a_we), .fmap_a_waddr_flat(fmap_a_waddr_flat), .fmap_a_wdata_flat(fmap_a_wdata_flat),
        .wgt_we(wgt_we), .wgt_waddr_flat(wgt_waddr_flat), .wgt_wdata_flat(wgt_wdata_flat),
        .rd_addr_b_flat(rd_addr_b_flat), .rd_data_b_flat(rd_data_b_flat)
    );

    always #5 clk = ~clk;

    // ---- 逐 bank 讀黃金資料,複製進共用陣列。bias/mult/shift 不是 SRAM macro,
    //      沒有 P1735 保護,維持原本直接 $readmemh 進 DUT 內部陣列的寫法。 ----
    genvar gi;
    generate
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : load_weight_bank
            initial begin
                reg [8*128-1:0] fname;
                reg [`WGT_WIDTH-1:0] stage [0:`MAX_WGT_BANK_DEPTH-1];
                integer row;
                $sformat(fname, "%0s/weights_bank%02d.hex", `GOLDEN_DIR, gi);
                $readmemh(fname, stage);
                for (row = 0; row < `MAX_WGT_BANK_DEPTH; row = row + 1)
                    wgt_stage_shared[gi][row] = stage[row];
            end
        end
        for (gi = 0; gi < `ARRAY_COLS; gi = gi + 1) begin : load_requant_bank
            initial begin
                reg [8*128-1:0] fname_b, fname_m, fname_s;
                $sformat(fname_b, "%0s/bias_bank%02d.hex", `GOLDEN_DIR, gi);
                $sformat(fname_m, "%0s/requant_mult_bank%02d.hex", `GOLDEN_DIR, gi);
                $sformat(fname_s, "%0s/requant_shift_bank%02d.hex", `GOLDEN_DIR, gi);
                $readmemh(fname_b, dut.u_post_process.lane[gi].u_requant_lane.bias_mem);
                $readmemh(fname_m, dut.u_post_process.lane[gi].u_requant_lane.mult_mem);
                $readmemh(fname_s, dut.u_post_process.lane[gi].u_requant_lane.shift_mem);
            end
        end
        // bank-interleaved(Cin>=ARRAY_ROWS)或 duplicated(Cin<ARRAY_ROWS,目前只有 conv1)
        // 統一由 export_golden.py 產生 32 個 per-bank 檔案(內容彼此相同,duplicated 模式
        // 就是每個 lane 各自持有一份完整拷貝),testbench 不用分兩種載入方式。
        for (gi = 0; gi < `ARRAY_ROWS; gi = gi + 1) begin : load_fmap_a_bank
            initial begin
                reg [8*128-1:0] fname;
                reg [`ACT_WIDTH-1:0] stage [0:`MAX_FMAP_IN_BANK_DEPTH-1];
                integer row;
                $sformat(fname, "%0s/input_bank%02d.hex", `GOLDEN_DIR, gi);
                $readmemh(fname, stage);
                for (row = 0; row < `MAX_FMAP_IN_BANK_DEPTH; row = row + 1)
                    fmap_a_stage_shared[gi][row] = stage[row];
            end
        end
    endgenerate

    // ---- 集中驅動寫入埠(單一個 process,見檔頭 Phase 5 第二輪的說明) ----
    task load_weights_via_port;
        integer row, lane;
        begin
            for (row = 0; row < wgt_row_count; row = row + 1) begin
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
            for (row = 0; row < fmap_a_row_count; row = row + 1) begin
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

    reg [`OUT_WIDTH-1:0] expected_output [0:OUT_LEN-1];

    integer h, w, nt, n, c, mval, bank_addr, idx, mismatches, cyc;
    reg [`OUT_WIDTH-1:0] exp_v, act_v;
    reg dump_on;

    initial begin
        if ($test$plusargs("dump")) begin
            dump_on = 1'b1;
            $dumpfile("sim.vcd");
            $dumpvars(0, tb_conv_layer);
        end else begin
            dump_on = 1'b0;
        end

        $readmemh({`GOLDEN_DIR, "/expected_output.hex"}, expected_output);

        // ---- reset(留時間讓上面所有 genvar-generate initial 區塊的 $readmemh 跑完,
        //      它們都是時間 0 的零延遲系統呼叫,會在第一個 clock edge 前全部完成),
        //      接著在 reset 仍拉低的期間,觸發 go 訊號、用真正的埠位把權重/輸入圖片
        //      寫進 DUT(先等 wgt_row_count+2、fmap_a_row_count+2 個週期,確保所有 lane
        //      的寫入迴圈都真的跑完,+2 是安全餘裕) ----
        rst_n = 1'b0;
        start = 1'b0;
        rd_addr_b_flat = {(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}};
        repeat (4) @(posedge clk);

        load_weights_via_port();
        load_fmap_a_via_port();

        rst_n = 1'b1;
        @(posedge clk);

        // ---- start pulse ----
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // ---- 等 done(有 timeout 保護) ----
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

        // ---- 比對輸出:每個 (m, n_tile) 一次讀回 16 個 channel ----
        mismatches = 0;
        for (h = 0; h < H_OUT; h = h + 1) begin
            for (w = 0; w < W_OUT; w = w + 1) begin
                mval = h * W_OUT + w;
                for (nt = 0; nt < N_TILES; nt = nt + 1) begin
                    bank_addr = mval * N_TILES + nt;
`ifdef SRAM_MACRO
                    // fmap_out_bank 換成同步 macro 後讀取有 1 個 clock cycle 延遲,
                    // 不能再用 #1 純延遲假設組合邏輯零延遲讀取,改成等滿一個完整週期。
                    // 位址要在 negedge 剛過之後才變動(不是先變位址才等 negedge),避免跟
                    // 緊接著的 posedge 之間產生競爭關係(race condition)。
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

`timescale 1ns/1ps
`include "params.vh"

// im2col_group_ctr.v 的獨立單元測試——完全不碰 im2col_lane.v/im2col_addr_gen.v/
// layer_sequencer.v,只驗證新的巢狀計數器模組本身的數學是否跟原本的除法公式
// (k_tile/inner_limit、k_tile%inner_limit)在全部 26 層真實的 (Cin,Kw,pack_factor,
// K_TILES) 組合下逐一 cycle 比對一致。通過之後才進到下一步:把這個模組接進
// im2col_addr_gen.v(32 個 lane 共用一份),取代原本 32 份重複的全位寬除法。
//
// k_tile 的驅動方式刻意模擬 conv_ctrl_fsm.v 的真實行為:每個值停留 2 個 cycle
// (模擬 LOAD 階段「不會動」的那段時間),然後 +1 或歸零(STREAM 結束才前進),
// 每一層都額外跑兩輪「跑完整個 K_TILES 範圍後歸零重來」,確保「k_tile 從非 0
// 歸零」這個重置路徑也被真的踩過,不是只測到單調遞增的部分。
module tb_im2col_group_ctr;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [`CNT_WIDTH-1:0] k_tile = {`CNT_WIDTH{1'b0}};
    reg [`CNT_WIDTH-1:0] inner_limit = {`CNT_WIDTH{1'b0}};
    wire [`CNT_WIDTH-1:0] outer_ctr, inner_ctr;

    im2col_group_ctr dut (
        .clk(clk), .rst_n(rst_n),
        .k_tile(k_tile), .inner_limit(inner_limit),
        .outer_ctr(outer_ctr), .inner_ctr(inner_ctr)
    );

    always #5 clk = ~clk;

    localparam integer NUM_LAYERS = 26;
    reg [`CNT_WIDTH-1:0] cin_arr        [0:NUM_LAYERS-1];
    reg [`CNT_WIDTH-1:0] kw_arr         [0:NUM_LAYERS-1];
    reg [`CNT_WIDTH-1:0] pack_factor_arr[0:NUM_LAYERS-1];
    reg [`CNT_WIDTH-1:0] k_tiles_arr    [0:NUM_LAYERS-1];

    integer layer, round, exp_outer, exp_inner, cin_groups, taps_total, limit;
    integer checks, mismatches;
    reg pack_enabled;

    task settle_and_check;
        begin
            @(posedge clk);
            #1;
            if (outer_ctr !== exp_outer[`CNT_WIDTH-1:0] || inner_ctr !== exp_inner[`CNT_WIDTH-1:0]) begin
                mismatches = mismatches + 1;
                if (mismatches <= 40)
                    $display("[MISMATCH] layer=%0d k_tile=%0d inner_limit=%0d expected(outer=%0d,inner=%0d) got(outer=%0d,inner=%0d)",
                              layer, k_tile, inner_limit, exp_outer, exp_inner, outer_ctr, inner_ctr);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        $readmemh("tb/golden_seq_chain/conv_cin.hex", cin_arr);
        $readmemh("tb/golden_seq_chain/conv_kw.hex", kw_arr);
        $readmemh("tb/golden_seq_chain/conv_pack_factor.hex", pack_factor_arr);
        $readmemh("tb/golden_seq_chain/conv_k_tiles.hex", k_tiles_arr);

        checks = 0;
        mismatches = 0;

        for (layer = 0; layer < NUM_LAYERS; layer = layer + 1) begin
            cin_groups   = (cin_arr[layer] + `ARRAY_ROWS - 1) / `ARRAY_ROWS;
            taps_total   = kw_arr[layer] * kw_arr[layer];
            pack_enabled = (pack_factor_arr[layer] != 0);
            limit        = pack_enabled ? taps_total : cin_groups;

            // ---- reset:每層重新來過,確保層與層之間的殘留狀態不會互相污染 ----
            rst_n = 1'b0;
            k_tile = {`CNT_WIDTH{1'b0}};
            inner_limit = limit[`CNT_WIDTH-1:0];
            repeat (2) @(posedge clk);
            rst_n = 1'b1;

            exp_outer = 0;
            exp_inner = 0;
            settle_and_check();

            // ---- 跑兩輪完整的 K_TILES 範圍,涵蓋「單調遞增」跟「歸零重來」兩種路徑 ----
            for (round = 0; round < 2; round = round + 1) begin
                for (k_tile = 1; k_tile < k_tiles_arr[layer]; k_tile = k_tile + 1) begin
                    exp_outer = k_tile / limit;
                    exp_inner = k_tile % limit;
                    settle_and_check();  // 這一拍是轉換點,計數器應該剛好進位/歸零成新值
                    // 模擬 LOAD 階段停留 1 個 cycle 不動(k_tile 沒變,計數器也不該變)
                    settle_and_check();
                end
                // 跑完一輪,歸零換下一輪(模擬 n_tile 換下一個)
                k_tile = {`CNT_WIDTH{1'b0}};
                exp_outer = 0;
                exp_inner = 0;
                settle_and_check();
            end
        end

        if (mismatches == 0)
            $display("[PASS] im2col_group_ctr: all %0d checks across %0d layers match old division formula",
                      checks, NUM_LAYERS);
        else
            $display("[FAIL] im2col_group_ctr: %0d / %0d checks mismatched", mismatches, checks);

        $finish;
    end
endmodule

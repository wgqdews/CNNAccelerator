`include "params.vh"
`timescale 1ns/1ps

// Phase 4f 補測:專門驗證 cfg_input_mode=1(interleaved,從外部匯流排讀,25/26 層 conv
// 實際使用的路徑)在真實 macro 下正不正確——之前只驗證過 conv1 專用的 cfg_input_mode=0
// (duplicated,內部 fmap_in_bank)這條路,全連鏈測試第一次真正踩到 interleaved 才發現
// 全部輸出是 X,用這個小測試快速定位問題,不用跑全連鏈(16+ 小時)。
//
// 配置:Cin=32(=ARRAY_ROWS,剛好整除、不用管 Cin_pad),Cout=32(=ARRAY_COLS,1 個 n_tile),
// 1x1 kernel,H=W=1(M_MAX=1,K_TILES=1)。外部 32 個 bank(fmap_a_rdata_ext_flat)各自
// 用真實 fmap_out_bank macro 模擬(bufA 的角色),位址 0 放一個已知值。權重用「對角矩陣」
// (weight[row][col] = (row==col)?5:0),讓輸出直接等於輸入乘以 5,方便驗證。
module scratch_tb;
    reg clk = 0;
    reg rst_n = 0;
    reg start;
    wire done;

    reg [`ARRAY_COLS-1:0]                 wgt_we;
    reg [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0] wgt_waddr_flat;
    reg [`ARRAY_COLS*`WGT_WIDTH-1:0]      wgt_wdata_flat;

    wire [`ARRAY_ROWS*`FMAP_ADDR_WIDTH-1:0] fmap_a_addr_out_flat;
    wire [`ARRAY_ROWS*`ACT_WIDTH-1:0]       fmap_a_rdata_ext_flat;

    reg  [`ARRAY_COLS*`FMAP_ADDR_WIDTH-1:0] rd_addr_b_flat;
    wire [`ARRAY_COLS*`OUT_WIDTH-1:0]       rd_data_b_flat;

    integer i, c;

    top_conv_layer dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_cin(20'd32), .cfg_cout(20'd32), .cfg_h_in(20'd1), .cfg_w_in(20'd1),
        .cfg_kw(20'd1), .cfg_stride(20'd1), .cfg_pad(20'd0),
        .cfg_h_out(20'd1), .cfg_w_out(20'd1),
        .cfg_k_real(20'd32), .cfg_k_tiles(20'd1), .cfg_n_tiles(20'd1),
        .cfg_act_zp(20'd0), .cfg_y_zp(20'd0),
        .cfg_out_n_tile_offset(20'd0), .cfg_out_n_tiles_total(20'd1),
        .cfg_weight_base_offset(20'd0), .cfg_bias_base_offset(20'd0),
        .cfg_input_mode(1'b1),  // <-- 關鍵:interleaved 模式,讀外部匯流排
        .cfg_pack_factor(20'd0), .cfg_pack_remainder(20'd0), .cfg_pack_base_group(20'd0),
        .fmap_a_addr_out_flat(fmap_a_addr_out_flat),
        .fmap_a_rdata_ext_flat(fmap_a_rdata_ext_flat),
        .wgt_we(wgt_we), .wgt_waddr_flat(wgt_waddr_flat), .wgt_wdata_flat(wgt_wdata_flat),
        .rd_addr_b_flat(rd_addr_b_flat), .rd_data_b_flat(rd_data_b_flat),
        .fmap_b_we_out(), .fmap_b_waddr_out_flat(), .fmap_b_wdata_out_flat(),
        .fmap_b_we_dup_out(), .n_tiles_done()
    );

    // 外部 bufA:32 個真實 fmap_out_bank macro,模擬 seq_chain_top.v 的 bufA 角色
    genvar gi;
    generate
        for (gi = 0; gi < `ARRAY_ROWS; gi = gi + 1) begin : ext_buf
            fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) u_mem (
                .clk(clk), .we(1'b0),
                .waddr({`FMAP_ADDR_WIDTH{1'b0}}), .wdata({`OUT_WIDTH{1'b0}}),
                .raddr(fmap_a_addr_out_flat[(gi+1)*`FMAP_ADDR_WIDTH-1 -: `FMAP_ADDR_WIDTH]),
                .rdata(fmap_a_rdata_ext_flat[(gi+1)*`ACT_WIDTH-1 -: `ACT_WIDTH])
            );
        end
    endgenerate

    always #5 clk = ~clk;

    task write_weight_row(input [`WGT_ADDR_WIDTH-1:0] addr, input [`ARRAY_COLS-1:0] onehot_col);
        begin
            @(negedge clk);
            wgt_we = {`ARRAY_COLS{1'b1}};
            for (c = 0; c < `ARRAY_COLS; c = c + 1) begin
                wgt_waddr_flat[(c+1)*`WGT_ADDR_WIDTH-1 -: `WGT_ADDR_WIDTH] = addr;
                wgt_wdata_flat[(c+1)*`WGT_WIDTH-1 -: `WGT_WIDTH] = onehot_col[c] ? 8'd5 : 8'd0;
            end
            @(negedge clk);
            wgt_we = {`ARRAY_COLS{1'b0}};
        end
    endtask

    integer errors;
    reg [`OUT_WIDTH-1:0] act_v;

    initial begin
        start = 0; wgt_we = 0; wgt_waddr_flat = 0; wgt_wdata_flat = 0;
        rd_addr_b_flat = 0;
        errors = 0;

        // 外部輸入:bank i(=channel i)的位址 0 放值 (i+1),用真實寫入埠(不是後門)
        // 灌不進去(ext_buf 沒有真正的寫入路徑給我們用,we 固定 0),改用 macro 內部
        // Memory 後門,跟之前驗證 fmap_in_bank 用的方式一樣。generate 陣列只認常數索引,
        // 逐一寫死展開。
        ext_buf[0].u_mem.u_mem.Memory[0]  = 1;
        ext_buf[1].u_mem.u_mem.Memory[0]  = 2;
        ext_buf[2].u_mem.u_mem.Memory[0]  = 3;
        ext_buf[3].u_mem.u_mem.Memory[0]  = 4;
        ext_buf[4].u_mem.u_mem.Memory[0]  = 5;
        ext_buf[5].u_mem.u_mem.Memory[0]  = 6;
        ext_buf[6].u_mem.u_mem.Memory[0]  = 7;
        ext_buf[7].u_mem.u_mem.Memory[0]  = 8;
        ext_buf[8].u_mem.u_mem.Memory[0]  = 9;
        ext_buf[9].u_mem.u_mem.Memory[0]  = 10;
        ext_buf[10].u_mem.u_mem.Memory[0] = 11;
        ext_buf[11].u_mem.u_mem.Memory[0] = 12;
        ext_buf[12].u_mem.u_mem.Memory[0] = 13;
        ext_buf[13].u_mem.u_mem.Memory[0] = 14;
        ext_buf[14].u_mem.u_mem.Memory[0] = 15;
        ext_buf[15].u_mem.u_mem.Memory[0] = 16;
        ext_buf[16].u_mem.u_mem.Memory[0] = 17;
        ext_buf[17].u_mem.u_mem.Memory[0] = 18;
        ext_buf[18].u_mem.u_mem.Memory[0] = 19;
        ext_buf[19].u_mem.u_mem.Memory[0] = 20;
        ext_buf[20].u_mem.u_mem.Memory[0] = 21;
        ext_buf[21].u_mem.u_mem.Memory[0] = 22;
        ext_buf[22].u_mem.u_mem.Memory[0] = 23;
        ext_buf[23].u_mem.u_mem.Memory[0] = 24;
        ext_buf[24].u_mem.u_mem.Memory[0] = 25;
        ext_buf[25].u_mem.u_mem.Memory[0] = 26;
        ext_buf[26].u_mem.u_mem.Memory[0] = 27;
        ext_buf[27].u_mem.u_mem.Memory[0] = 28;
        ext_buf[28].u_mem.u_mem.Memory[0] = 29;
        ext_buf[29].u_mem.u_mem.Memory[0] = 30;
        ext_buf[30].u_mem.u_mem.Memory[0] = 31;
        ext_buf[31].u_mem.u_mem.Memory[0] = 32;

        // 對角矩陣權重:row r 只有 col r 是 5,其餘是 0 -> output[c] = input[c] * 5
        for (i = 0; i < `ARRAY_ROWS; i = i + 1)
            write_weight_row(i[`WGT_ADDR_WIDTH-1:0], (1 << i));

        // bias=0, mult=1(identity), shift=0 -- 避免未初始化的 X 汙染結果,32 個 lane 都要設
        for (i = 0; i < `ARRAY_COLS; i = i + 1) begin
            case (i)
                0:  begin dut.u_post_process.lane[0].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[0].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[0].u_requant_lane.shift_mem[0]=0; end
                1:  begin dut.u_post_process.lane[1].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[1].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[1].u_requant_lane.shift_mem[0]=0; end
                2:  begin dut.u_post_process.lane[2].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[2].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[2].u_requant_lane.shift_mem[0]=0; end
                3:  begin dut.u_post_process.lane[3].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[3].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[3].u_requant_lane.shift_mem[0]=0; end
                4:  begin dut.u_post_process.lane[4].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[4].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[4].u_requant_lane.shift_mem[0]=0; end
                5:  begin dut.u_post_process.lane[5].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[5].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[5].u_requant_lane.shift_mem[0]=0; end
                6:  begin dut.u_post_process.lane[6].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[6].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[6].u_requant_lane.shift_mem[0]=0; end
                7:  begin dut.u_post_process.lane[7].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[7].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[7].u_requant_lane.shift_mem[0]=0; end
                8:  begin dut.u_post_process.lane[8].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[8].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[8].u_requant_lane.shift_mem[0]=0; end
                9:  begin dut.u_post_process.lane[9].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[9].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[9].u_requant_lane.shift_mem[0]=0; end
                10: begin dut.u_post_process.lane[10].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[10].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[10].u_requant_lane.shift_mem[0]=0; end
                11: begin dut.u_post_process.lane[11].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[11].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[11].u_requant_lane.shift_mem[0]=0; end
                12: begin dut.u_post_process.lane[12].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[12].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[12].u_requant_lane.shift_mem[0]=0; end
                13: begin dut.u_post_process.lane[13].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[13].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[13].u_requant_lane.shift_mem[0]=0; end
                14: begin dut.u_post_process.lane[14].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[14].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[14].u_requant_lane.shift_mem[0]=0; end
                15: begin dut.u_post_process.lane[15].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[15].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[15].u_requant_lane.shift_mem[0]=0; end
                16: begin dut.u_post_process.lane[16].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[16].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[16].u_requant_lane.shift_mem[0]=0; end
                17: begin dut.u_post_process.lane[17].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[17].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[17].u_requant_lane.shift_mem[0]=0; end
                18: begin dut.u_post_process.lane[18].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[18].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[18].u_requant_lane.shift_mem[0]=0; end
                19: begin dut.u_post_process.lane[19].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[19].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[19].u_requant_lane.shift_mem[0]=0; end
                20: begin dut.u_post_process.lane[20].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[20].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[20].u_requant_lane.shift_mem[0]=0; end
                21: begin dut.u_post_process.lane[21].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[21].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[21].u_requant_lane.shift_mem[0]=0; end
                22: begin dut.u_post_process.lane[22].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[22].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[22].u_requant_lane.shift_mem[0]=0; end
                23: begin dut.u_post_process.lane[23].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[23].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[23].u_requant_lane.shift_mem[0]=0; end
                24: begin dut.u_post_process.lane[24].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[24].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[24].u_requant_lane.shift_mem[0]=0; end
                25: begin dut.u_post_process.lane[25].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[25].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[25].u_requant_lane.shift_mem[0]=0; end
                26: begin dut.u_post_process.lane[26].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[26].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[26].u_requant_lane.shift_mem[0]=0; end
                27: begin dut.u_post_process.lane[27].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[27].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[27].u_requant_lane.shift_mem[0]=0; end
                28: begin dut.u_post_process.lane[28].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[28].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[28].u_requant_lane.shift_mem[0]=0; end
                29: begin dut.u_post_process.lane[29].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[29].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[29].u_requant_lane.shift_mem[0]=0; end
                30: begin dut.u_post_process.lane[30].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[30].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[30].u_requant_lane.shift_mem[0]=0; end
                31: begin dut.u_post_process.lane[31].u_requant_lane.bias_mem[0]=0; dut.u_post_process.lane[31].u_requant_lane.mult_mem[0]=1; dut.u_post_process.lane[31].u_requant_lane.shift_mem[0]=0; end
            endcase
        end

        #12 rst_n = 1;
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done == 1'b1);

`ifdef SRAM_MACRO
        @(negedge clk);
        rd_addr_b_flat = {`ARRAY_COLS{`FMAP_ADDR_WIDTH'd0}};
        @(negedge clk);
`else
        rd_addr_b_flat = {`ARRAY_COLS{`FMAP_ADDR_WIDTH'd0}};
        #1;
`endif

        for (c = 0; c < `ARRAY_COLS; c = c + 1) begin
            act_v = rd_data_b_flat[(c+1)*`OUT_WIDTH-1 -: `OUT_WIDTH];
            if (act_v !== ((c + 1) * 5)) begin
                $display("[FAIL] c=%0d expected=%0d got=%0d", c, (c+1)*5, act_v);
                errors = errors + 1;
            end else begin
                $display("[OK]   c=%0d got=%0d", c, act_v);
            end
        end

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

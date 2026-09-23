`include "params.vh"
`timescale 1ns/1ps

// Phase 4b 驗證:conv_ctrl_fsm.v 的 S_LOAD_SYNC bubble + top_conv_layer.v 的 1 拍延遲
// wrapper,搭配真正的 weight_bank macro,確認 PE 陣列裡每一列真正收到的權重跟寫入的值
// 一致(不是 1 拍前的舊值、也不是 X)。K_TILES=1/N_TILES=1,只測 S_LOAD 冷啟動路徑,
// 不牽涉 shadow prefetch/swap_all(那條路徑理論上有充裕 margin,見對話裡的推導)。
module scratch_tb;
    reg clk = 0;
    reg rst_n = 0;
    reg start;
    wire done;

    reg [`ARRAY_COLS-1:0]                 wgt_we;
    reg [`ARRAY_COLS*`WGT_ADDR_WIDTH-1:0] wgt_waddr_flat;
    reg [`ARRAY_COLS*`WGT_WIDTH-1:0]      wgt_wdata_flat;

    integer errors = 0;
    integer i, c;
    reg [`WGT_WIDTH-1:0] captured [0:`ARRAY_ROWS-1];

    top_conv_layer dut (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .cfg_cin(32), .cfg_cout(32), .cfg_h_in(1), .cfg_w_in(1),
        .cfg_kw(1), .cfg_stride(1), .cfg_pad(0),
        .cfg_h_out(1), .cfg_w_out(1),
        .cfg_k_real(32), .cfg_k_tiles(1), .cfg_n_tiles(1),
        .cfg_act_zp(0), .cfg_y_zp(0),
        .cfg_out_n_tile_offset(0), .cfg_out_n_tiles_total(1),
        .cfg_weight_base_offset(0), .cfg_bias_base_offset(0),
        .cfg_input_mode(1'b0),
        .cfg_pack_factor(0), .cfg_pack_remainder(0), .cfg_pack_base_group(0),
        .fmap_a_addr_out_flat(), .fmap_a_rdata_ext_flat({(`ARRAY_ROWS*`ACT_WIDTH){1'b0}}),
        .wgt_we(wgt_we), .wgt_waddr_flat(wgt_waddr_flat), .wgt_wdata_flat(wgt_wdata_flat),
        .rd_addr_b_flat({(`ARRAY_COLS*`FMAP_ADDR_WIDTH){1'b0}}), .rd_data_b_flat(),
        .fmap_b_we_out(), .fmap_b_waddr_out_flat(), .fmap_b_wdata_out_flat(),
        .fmap_b_we_dup_out(), .n_tiles_done()
    );

    always #5 clk = ~clk;

    task write_weight_row(input [`WGT_ADDR_WIDTH-1:0] addr, input [7:0] val);
        begin
            @(negedge clk);
            wgt_we = {`ARRAY_COLS{1'b1}};
            for (c = 0; c < `ARRAY_COLS; c = c + 1) begin
                wgt_waddr_flat[(c+1)*`WGT_ADDR_WIDTH-1 -: `WGT_ADDR_WIDTH] = addr;
                wgt_wdata_flat[(c+1)*`WGT_WIDTH-1 -: `WGT_WIDTH] = val;
            end
            @(negedge clk);
            wgt_we = {`ARRAY_COLS{1'b0}};
        end
    endtask

    initial begin
        start = 0; wgt_we = 0; wgt_waddr_flat = 0; wgt_wdata_flat = 0;
        #12 rst_n = 1;

        // 寫入 32 列權重(位址 0..31,值 = row index),用真正的寫入埠,不是後門
        for (i = 0; i < `ARRAY_ROWS; i = i + 1)
            write_weight_row(i[`WGT_ADDR_WIDTH-1:0], i[7:0]);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done == 1'b1);
        @(negedge clk); // 讓 done 那拍完全穩定

        // genvar 常數索引才能存取 generate 陣列,先逐一(硬寫死索引,不是迴圈變數)搬進
        // 自己的陣列,再用一般的執行期迴圈比對。
        captured[0]  = dut.u_pe_array.gen_row[0].gen_col[0].u_pe.weight_reg;
        captured[1]  = dut.u_pe_array.gen_row[1].gen_col[0].u_pe.weight_reg;
        captured[2]  = dut.u_pe_array.gen_row[2].gen_col[0].u_pe.weight_reg;
        captured[3]  = dut.u_pe_array.gen_row[3].gen_col[0].u_pe.weight_reg;
        captured[4]  = dut.u_pe_array.gen_row[4].gen_col[0].u_pe.weight_reg;
        captured[5]  = dut.u_pe_array.gen_row[5].gen_col[0].u_pe.weight_reg;
        captured[6]  = dut.u_pe_array.gen_row[6].gen_col[0].u_pe.weight_reg;
        captured[7]  = dut.u_pe_array.gen_row[7].gen_col[0].u_pe.weight_reg;
        captured[8]  = dut.u_pe_array.gen_row[8].gen_col[0].u_pe.weight_reg;
        captured[9]  = dut.u_pe_array.gen_row[9].gen_col[0].u_pe.weight_reg;
        captured[10] = dut.u_pe_array.gen_row[10].gen_col[0].u_pe.weight_reg;
        captured[11] = dut.u_pe_array.gen_row[11].gen_col[0].u_pe.weight_reg;
        captured[12] = dut.u_pe_array.gen_row[12].gen_col[0].u_pe.weight_reg;
        captured[13] = dut.u_pe_array.gen_row[13].gen_col[0].u_pe.weight_reg;
        captured[14] = dut.u_pe_array.gen_row[14].gen_col[0].u_pe.weight_reg;
        captured[15] = dut.u_pe_array.gen_row[15].gen_col[0].u_pe.weight_reg;
        captured[16] = dut.u_pe_array.gen_row[16].gen_col[0].u_pe.weight_reg;
        captured[17] = dut.u_pe_array.gen_row[17].gen_col[0].u_pe.weight_reg;
        captured[18] = dut.u_pe_array.gen_row[18].gen_col[0].u_pe.weight_reg;
        captured[19] = dut.u_pe_array.gen_row[19].gen_col[0].u_pe.weight_reg;
        captured[20] = dut.u_pe_array.gen_row[20].gen_col[0].u_pe.weight_reg;
        captured[21] = dut.u_pe_array.gen_row[21].gen_col[0].u_pe.weight_reg;
        captured[22] = dut.u_pe_array.gen_row[22].gen_col[0].u_pe.weight_reg;
        captured[23] = dut.u_pe_array.gen_row[23].gen_col[0].u_pe.weight_reg;
        captured[24] = dut.u_pe_array.gen_row[24].gen_col[0].u_pe.weight_reg;
        captured[25] = dut.u_pe_array.gen_row[25].gen_col[0].u_pe.weight_reg;
        captured[26] = dut.u_pe_array.gen_row[26].gen_col[0].u_pe.weight_reg;
        captured[27] = dut.u_pe_array.gen_row[27].gen_col[0].u_pe.weight_reg;
        captured[28] = dut.u_pe_array.gen_row[28].gen_col[0].u_pe.weight_reg;
        captured[29] = dut.u_pe_array.gen_row[29].gen_col[0].u_pe.weight_reg;
        captured[30] = dut.u_pe_array.gen_row[30].gen_col[0].u_pe.weight_reg;
        captured[31] = dut.u_pe_array.gen_row[31].gen_col[0].u_pe.weight_reg;

        for (i = 0; i < `ARRAY_ROWS; i = i + 1) begin
            if (captured[i] !== i[7:0]) begin
                $display("[FAIL] row=%0d expected=%0d got=%0d", i, i, captured[i]);
                errors = errors + 1;
            end else begin
                $display("[OK]   row=%0d weight_reg=%0d", i, captured[i]);
            end
        end

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

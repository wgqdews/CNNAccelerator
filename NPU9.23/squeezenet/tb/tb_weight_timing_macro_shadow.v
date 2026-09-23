`include "params.vh"
`timescale 1ns/1ps

// Phase 4b 驗證(第二輪):K_TILES=2,驗證 STREAM 期間的 shadow 預取 + swap_all 路徑
// 在 SRAM macro 的 1 拍延遲下還是正確——tile0 用值 i,tile1 用值 100+i,分別在兩次
// STREAM 期間檢查 pe_array 的現役 weight_reg 對不對。
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
        .cfg_k_real(32), .cfg_k_tiles(2), .cfg_n_tiles(1),
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

    task capture_all;
        begin
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
        end
    endtask

    task check_all(input [7:0] base, input [127:0] label);
        begin
            for (i = 0; i < `ARRAY_ROWS; i = i + 1) begin
                if (captured[i] !== (base + i[7:0])) begin
                    $display("[FAIL] %0s row=%0d expected=%0d got=%0d", label, i, base+i, captured[i]);
                    errors = errors + 1;
                end else begin
                    $display("[OK]   %0s row=%0d weight_reg=%0d", label, i, captured[i]);
                end
            end
        end
    endtask

    initial begin
        start = 0; wgt_we = 0; wgt_waddr_flat = 0; wgt_wdata_flat = 0;
        #12 rst_n = 1;

        // tile0(k_tile=0): 位址 0..31, 值 = row
        for (i = 0; i < `ARRAY_ROWS; i = i + 1)
            write_weight_row(i[`WGT_ADDR_WIDTH-1:0], i[7:0]);
        // tile1(k_tile=1): 位址 32..63, 值 = 100+row
        for (i = 0; i < `ARRAY_ROWS; i = i + 1)
            write_weight_row((32+i), (100+i));

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        // 等到進入第一次 STREAM(k_tile=0) 且已經過了 S_LOAD_SYNC 那拍
        wait (dut.u_fsm.streaming == 1'b1 && dut.u_fsm.k_tile == 0);
        @(negedge clk);
        capture_all;
        check_all(8'd0, "tile0");

        // 等到 k_tile 進位成 1(代表 swap_all 已經切換過,S_ADVANCE 已經跑完進了第二次 STREAM)
        wait (dut.u_fsm.k_tile == 1 && dut.u_fsm.streaming == 1'b1);
        @(negedge clk);
        capture_all;
        check_all(8'd100, "tile1");

        wait (done == 1'b1);

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`include "params.vh"
`timescale 1ns/1ps

// Phase 4b 補測:K_TILES=1, N_TILES=2(跨 n_tile 的 shadow 切換,conv1 的實際情境),
// 之前只測過跨 k_tile(K_TILES=2, N_TILES=1),這個組合完全沒驗證過。
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
        .cfg_k_real(32), .cfg_k_tiles(1), .cfg_n_tiles(2),
        .cfg_act_zp(0), .cfg_y_zp(0),
        .cfg_out_n_tile_offset(0), .cfg_out_n_tiles_total(2),
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
        end
    endtask

    initial begin
        start = 0; wgt_we = 0; wgt_waddr_flat = 0; wgt_wdata_flat = 0;
        #12 rst_n = 1;

        // n_tile0(位址 0..31): 值 = row; n_tile1(位址 32..63): 值 = 100+row
        for (i = 0; i < `ARRAY_ROWS; i = i + 1)
            write_weight_row(i[`WGT_ADDR_WIDTH-1:0], i[7:0]);
        for (i = 0; i < `ARRAY_ROWS; i = i + 1)
            write_weight_row((32+i), (100+i));

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (dut.u_fsm.streaming == 1'b1 && dut.u_fsm.n_tile == 0);
        @(negedge clk);
        capture_all;
        if (captured[0]!==0 || captured[1]!==1 || captured[2]!==2 || captured[3]!==3) begin
            $display("[FAIL] n_tile0: got %0d %0d %0d %0d (expect 0 1 2 3)",
                      captured[0], captured[1], captured[2], captured[3]);
            errors = errors + 1;
        end else
            $display("[OK] n_tile0: %0d %0d %0d %0d", captured[0], captured[1], captured[2], captured[3]);

        wait (dut.u_fsm.n_tile == 1 && dut.u_fsm.streaming == 1'b1);
        @(negedge clk);
        capture_all;
        if (captured[0]!==100 || captured[1]!==101 || captured[2]!==102 || captured[3]!==103) begin
            $display("[FAIL] n_tile1: got %0d %0d %0d %0d (expect 100 101 102 103)",
                      captured[0], captured[1], captured[2], captured[3]);
            errors = errors + 1;
        end else
            $display("[OK] n_tile1: %0d %0d %0d %0d", captured[0], captured[1], captured[2], captured[3]);

        wait (done == 1'b1);

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

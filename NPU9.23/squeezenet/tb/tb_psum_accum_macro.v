`include "params.vh"
`timescale 1ns/1ps

// Phase 4c 驗證:requant_lane.v 的讀位址提前一拍(raddr_psum=m+1)搭配真實 psum macro,
// 驗證兩個 k_tile pass 之間的累加值正確——pass0(is_first_k_tile)寫入 psum_col,
// pass1(is_last_k_tile)讀回 pass0 的值 + 這次的 psum_col,驗證最終輸出等於兩者之和。
module scratch_tb;
    localparam M_MAX = 4;

    reg clk = 0;
    reg rst_n = 0;
    reg [`CNT_WIDTH-1:0] cycle_cnt;
    reg is_first_k_tile, is_last_k_tile;
    reg signed [`ACC_WIDTH-1:0] psum_col;

    wire we_psum;
    wire [`PSUM_ADDR_WIDTH-1:0] addr_psum;
    wire [`PSUM_ADDR_WIDTH-1:0] raddr_psum;
    wire signed [`ACC_WIDTH-1:0] wdata_psum;
    wire signed [`ACC_WIDTH-1:0] psum_rdata;
    wire we_fmap;
    wire [`FMAP_ADDR_WIDTH-1:0] waddr_fmap;
    wire [`OUT_WIDTH-1:0] wdata_fmap;

    integer errors = 0;
    integer m;
    reg [`OUT_WIDTH-1:0] fmap_captured [0:M_MAX-1];
    reg fmap_seen [0:M_MAX-1];

    requant_lane #(.LANE(0), .NT_DEPTH(1)) u_lane (
        .clk(clk), .rst_n(rst_n),
        .cycle_cnt(cycle_cnt), .n_tile(20'd0),
        .is_first_k_tile(is_first_k_tile), .is_last_k_tile(is_last_k_tile),
        .cfg_h_out(20'd1), .cfg_w_out(M_MAX[19:0]), .cfg_cout(20'd32),
        .cfg_n_tiles(20'd1), .cfg_y_zp(20'd0),
        .cfg_out_n_tile_offset(20'd0), .cfg_out_n_tiles_total(20'd1),
        .cfg_bias_base_offset(20'd0),
        .psum_col(psum_col), .psum_rdata(psum_rdata),
        .we_psum(we_psum), .addr_psum(addr_psum), .raddr_psum(raddr_psum),
        .wdata_psum(wdata_psum),
        .we_fmap(we_fmap), .waddr_fmap(waddr_fmap), .wdata_fmap(wdata_fmap),
        .we_fmap_dup()
    );

    // bias=0, mult=1(identity), shift=0 -- clamped 輸出直接等於 acc 的飽和結果,方便驗證
    initial begin
        u_lane.bias_mem[0]  = 0;
        u_lane.mult_mem[0]  = 1;
        u_lane.shift_mem[0] = 0;
    end

    psum_bank #(.DEPTH(`MAX_PSUM_BANK_DEPTH)) u_psum (
        .clk(clk), .we(we_psum), .addr(addr_psum), .raddr(raddr_psum),
        .wdata(wdata_psum), .rdata(psum_rdata)
    );

    always #5 clk = ~clk;

    // 把整個 k_tile pass(cycle_cnt 從 0 跑到 ARRAY_ROWS+M_MAX,含 pipeline 對齊的空拍)
    // 跑一輪,psum_col 依 m 給值:pass0 給 (m+1),pass1 給 (m+1)*10
    task run_pass(input is_first, input is_last, input integer mult_factor);
        integer cc;
        integer mm;
        begin
            is_first_k_tile = is_first;
            is_last_k_tile  = is_last;
            // requant_lane.v 在 `SRAM_MACRO 下用 ARRAY_ROWS+1 當像素管線延遲校準常數
            // (見該檔案 m_signed 的說明),這裡驅動 cycle_cnt 要跟 DUT 內部算法一致。
            for (cc = 0; cc < `ARRAY_ROWS + 1 + M_MAX + 2; cc = cc + 1) begin
                @(negedge clk);
                cycle_cnt = cc[`CNT_WIDTH-1:0];
                mm = cc - (`ARRAY_ROWS + 1); // LANE=0
                if (mm >= 0 && mm < M_MAX)
                    psum_col = (mm + 1) * mult_factor;
                else
                    psum_col = 0;
            end
        end
    endtask

    initial begin
        cycle_cnt = 0; is_first_k_tile = 0; is_last_k_tile = 0; psum_col = 0;
        for (m = 0; m < M_MAX; m = m + 1) fmap_seen[m] = 0;
        #12 rst_n = 1;

        // 監看 we_fmap,只有 pass1(finalize)才會真的寫 fmap
        fork
            begin : monitor_fmap
                forever begin
                    @(posedge clk);
                    if (we_fmap && waddr_fmap < M_MAX) begin
                        fmap_captured[waddr_fmap] = wdata_fmap;
                        fmap_seen[waddr_fmap] = 1;
                    end
                end
            end
        join_none

        // pass0: k_tile=0(is_first),寫入 psum_col=(m+1)*1
        run_pass(1'b1, 1'b0, 1);
        // pass1: k_tile=1(is_last),讀回 pass0 的值 + psum_col=(m+1)*10,finalize 寫 fmap
        run_pass(1'b0, 1'b1, 10);

        #20;

        for (m = 0; m < M_MAX; m = m + 1) begin
            if (!fmap_seen[m]) begin
                $display("[FAIL] m=%0d: we_fmap 從未觸發", m);
                errors = errors + 1;
            end else if (fmap_captured[m] !== ((m+1) + (m+1)*10)) begin
                $display("[FAIL] m=%0d expected=%0d got=%0d", m, (m+1)+(m+1)*10, fmap_captured[m]);
                errors = errors + 1;
            end else begin
                $display("[OK]   m=%0d fmap=%0d (expected %0d)", m, fmap_captured[m], (m+1)+(m+1)*10);
            end
        end

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

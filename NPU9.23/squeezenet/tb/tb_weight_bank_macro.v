`include "params.vh"
`timescale 1ns/1ps

module scratch_tb;
    reg clk = 0;
    reg rst_n = 1'b1;
    reg we;
    reg [`WGT_ADDR_WIDTH-1:0] waddr, raddr;
    reg [`WGT_WIDTH-1:0] wdata;
    wire [`WGT_WIDTH-1:0] rdata;

    integer errors = 0;

    weight_bank #(.DEPTH(`MAX_WGT_BANK_DEPTH)) dut (
        .clk(clk), .rst_n(rst_n), .we(we), .waddr(waddr), .wdata(wdata),
        .raddr(raddr), .rdata(rdata)
    );

    always #5 clk = ~clk;

    task write_one(input [`WGT_ADDR_WIDTH-1:0] a, input [`WGT_WIDTH-1:0] d);
        begin
            @(negedge clk);
            we = 1; waddr = a; wdata = d;
            @(negedge clk);
            we = 0;
        end
    endtask

    task check_one(input [`WGT_ADDR_WIDTH-1:0] a, input [`WGT_WIDTH-1:0] expected);
        begin
            @(negedge clk);
            raddr = a;
            @(negedge clk);  // 同步讀取,給一個完整 clock cycle 讓資料反映出來
            #1;
            if (rdata !== expected) begin
                $display("[FAIL] addr=%0d expected=%0d got=%0d", a, expected, rdata);
                errors = errors + 1;
            end else begin
                $display("[OK]   addr=%0d data=%0d", a, rdata);
            end
        end
    endtask

    initial begin
        we = 0; waddr = 0; wdata = 0;
        raddr = 20'd39800;  // 停在一個測試中不會被寫入的安全位址,避免跟寫入位址衝突

        // 低位址段邊界
        write_one(20'd0,     8'h11);
        write_one(20'd1,     8'h22);
        write_one(20'd19966, 8'h33);
        write_one(20'd19967, 8'h44);   // 低位址段最後一個
        // 跨過切割邊界,高位址段開頭
        write_one(20'd19968, 8'h55);   // 高位址段第一個
        write_one(20'd19969, 8'h66);
        // 高位址段接近實際使用上限(MAX_WGT_BANK_DEPTH-1 = 39807)
        write_one(20'd39806, 8'h77);
        write_one(20'd39807, 8'h88);

        #10;

        check_one(20'd0,     8'h11);
        check_one(20'd1,     8'h22);
        check_one(20'd19966, 8'h33);
        check_one(20'd19967, 8'h44);
        check_one(20'd19968, 8'h55);
        check_one(20'd19969, 8'h66);
        check_one(20'd39806, 8'h77);
        check_one(20'd39807, 8'h88);

        // 再檢查一次寫入不會互相污染(例如低位址段寫入跑去動到高位址段)
        check_one(20'd0,     8'h11);
        check_one(20'd19968, 8'h55);

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

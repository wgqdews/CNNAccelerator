`include "params.vh"
`timescale 1ns/1ps

module scratch_tb;
    reg clk = 0;
    reg rst_n = 1'b1;
    reg [`FMAP_ADDR_WIDTH-1:0] raddr;
    wire [`ACT_WIDTH-1:0] rdata;

    integer errors = 0;

    fmap_in_bank #(.DEPTH(`MAX_FMAP_IN_BANK_DEPTH)) dut (
        .clk(clk), .rst_n(rst_n), .raddr(raddr), .rdata(rdata)
    );

    always #5 clk = ~clk;

    task check_one(input [`FMAP_ADDR_WIDTH-1:0] a, input [`ACT_WIDTH-1:0] expected);
        begin
            @(negedge clk);
            raddr = a;
            @(negedge clk);
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
        raddr = 0;
        #12;

        // 後門直接寫 5 顆 macro 各自的內部 Memory 陣列(這顆 bank 本來就沒有寫入埠,
        // 唯讀,跟真正的 $readmemh 載入方式同樣性質,只是換成 macro 內部訊號名稱)
        dut.u_mem0.Memory[0]     = 8'h11; // macro0 開頭
        dut.u_mem0.Memory[32767] = 8'h22; // macro0 結尾(local addr 32767 = 全域 addr 32767)
        dut.u_mem1.Memory[0]     = 8'h33; // macro1 開頭(全域 addr 32768)
        dut.u_mem1.Memory[32767] = 8'h44; // macro1 結尾(全域 addr 65535)
        dut.u_mem2.Memory[0]     = 8'h55; // macro2 開頭(全域 addr 65536)
        dut.u_mem3.Memory[32767] = 8'h66; // macro3 結尾(全域 addr 131071)
        dut.u_mem4.Memory[0]     = 8'h77; // macro4 開頭(全域 addr 131072)
        dut.u_mem4.Memory[19455] = 8'h88; // macro4 結尾 = 全域 addr 150527(MAX_FMAP_IN_BANK_DEPTH-1)

        check_one(20'd0,      8'h11);
        check_one(20'd32767,  8'h22);
        check_one(20'd32768,  8'h33);
        check_one(20'd65535,  8'h44);
        check_one(20'd65536,  8'h55);
        check_one(20'd131071, 8'h66);
        check_one(20'd131072, 8'h77);
        check_one(20'd150527, 8'h88);
        check_one(20'd0,      8'h11); // 交叉檢查不同 macro 之間沒有互相污染

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

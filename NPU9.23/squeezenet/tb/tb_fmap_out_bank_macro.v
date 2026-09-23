`include "params.vh"
`timescale 1ns/1ps

module scratch_tb;
    reg clk = 0;
    reg we;
    reg [`FMAP_ADDR_WIDTH-1:0] waddr, raddr;
    reg [`OUT_WIDTH-1:0] wdata;
    wire [`OUT_WIDTH-1:0] rdata;

    integer errors = 0;

    fmap_out_bank #(.DEPTH(`MAX_FMAP_OUT_BANK_DEPTH)) dut (
        .clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
        .raddr(raddr), .rdata(rdata)
    );

    always #5 clk = ~clk;

    task write_one(input [`FMAP_ADDR_WIDTH-1:0] a, input [`OUT_WIDTH-1:0] d);
        begin
            @(negedge clk);
            we = 1; waddr = a; wdata = d;
            @(negedge clk);
            we = 0;
        end
    endtask

    task check_one(input [`FMAP_ADDR_WIDTH-1:0] a, input [`OUT_WIDTH-1:0] expected);
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
        we = 0; waddr = 0; wdata = 0; raddr = 20'd0;

        write_one(20'd0,     8'h11);
        write_one(20'd1,     8'h22);
        write_one(20'd24641, 8'hAB); // 需求的最後一個真正位址(MAX_FMAP_OUT_BANK_DEPTH-1)
        write_one(20'd24703, 8'hCD); // macro 實際容量的最後一個位址(進位後多出來的)

        #10;

        check_one(20'd0,     8'h11);
        check_one(20'd1,     8'h22);
        check_one(20'd24641, 8'hAB);
        check_one(20'd24703, 8'hCD);
        check_one(20'd0,     8'h11); // 再驗一次沒有互相污染

        if (errors == 0)
            $display("ALL PASS");
        else
            $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule

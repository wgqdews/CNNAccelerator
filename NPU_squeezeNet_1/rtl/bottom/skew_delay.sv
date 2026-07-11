`include "../../inc/config.vh"

module skew_delay #(
    parameter N          = 9
)(
    input  clk, rst_n,
    input  wire signed [`DATA_WIDTH-1:0] i_pixel [0:N-1],
    output signed [`DATA_WIDTH-1:0] o_pixel [0:N-1]
);
    // i_pixel[k] 需要 k 個 cycle 的 delay
    // 最多 N-1 = 8 級

    reg signed [`DATA_WIDTH-1:0] sr [0:N-1][0:N-2];
    // sr[k][0] = i_pixel[k] 打一拍
    // sr[k][d] = 第 d+1 拍

    integer k, d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < N; k++)
                for (d = 0; d < N-1; d++)
                    sr[k][d] <= 0;
        end else begin
            for (k = 0; k < N; k++) begin
                sr[k][0] <= i_pixel[k];
                for (d = 1; d < N-1; d++)
                    sr[k][d] <= sr[k][d-1];
            end
        end
    end

    genvar gk;
    generate
        for (gk = 0; gk < N; gk++) begin : gen_skew
            if (gk == 0)
                assign o_pixel[gk] = i_pixel[gk];          // 0 delay 直接穿透
            else
                assign o_pixel[gk] = sr[gk][gk-1];         // 取第 gk 拍
        end
    endgenerate

endmodule
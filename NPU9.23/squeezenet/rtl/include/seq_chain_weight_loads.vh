$sformat(fname, "%0s/conv1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_conv1
    reg [`WGT_WIDTH-1:0] stage [0:63];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 64; k = k + 1)
        wgt_stage_shared[gi][0+k] = stage[k];
end
$sformat(fname, "%0s/fire2_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire2_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:63];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 64; k = k + 1)
        wgt_stage_shared[gi][64+k] = stage[k];
end
$sformat(fname, "%0s/fire2_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire2_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:63];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 64; k = k + 1)
        wgt_stage_shared[gi][128+k] = stage[k];
end
$sformat(fname, "%0s/fire2_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire2_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:319];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 320; k = k + 1)
        wgt_stage_shared[gi][192+k] = stage[k];
end
$sformat(fname, "%0s/fire3_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire3_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:127];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 128; k = k + 1)
        wgt_stage_shared[gi][512+k] = stage[k];
end
$sformat(fname, "%0s/fire3_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire3_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:63];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 64; k = k + 1)
        wgt_stage_shared[gi][640+k] = stage[k];
end
$sformat(fname, "%0s/fire3_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire3_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:319];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 320; k = k + 1)
        wgt_stage_shared[gi][704+k] = stage[k];
end
$sformat(fname, "%0s/fire4_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire4_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:127];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 128; k = k + 1)
        wgt_stage_shared[gi][1024+k] = stage[k];
end
$sformat(fname, "%0s/fire4_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire4_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:127];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 128; k = k + 1)
        wgt_stage_shared[gi][1152+k] = stage[k];
end
$sformat(fname, "%0s/fire4_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire4_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:1151];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 1152; k = k + 1)
        wgt_stage_shared[gi][1280+k] = stage[k];
end
$sformat(fname, "%0s/fire5_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire5_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:255];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 256; k = k + 1)
        wgt_stage_shared[gi][2432+k] = stage[k];
end
$sformat(fname, "%0s/fire5_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire5_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:127];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 128; k = k + 1)
        wgt_stage_shared[gi][2688+k] = stage[k];
end
$sformat(fname, "%0s/fire5_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire5_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:1151];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 1152; k = k + 1)
        wgt_stage_shared[gi][2816+k] = stage[k];
end
$sformat(fname, "%0s/fire6_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire6_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:511];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 512; k = k + 1)
        wgt_stage_shared[gi][3968+k] = stage[k];
end
$sformat(fname, "%0s/fire6_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire6_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:383];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 384; k = k + 1)
        wgt_stage_shared[gi][4480+k] = stage[k];
end
$sformat(fname, "%0s/fire6_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire6_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:2687];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 2688; k = k + 1)
        wgt_stage_shared[gi][4864+k] = stage[k];
end
$sformat(fname, "%0s/fire7_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire7_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:767];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 768; k = k + 1)
        wgt_stage_shared[gi][7552+k] = stage[k];
end
$sformat(fname, "%0s/fire7_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire7_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:383];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 384; k = k + 1)
        wgt_stage_shared[gi][8320+k] = stage[k];
end
$sformat(fname, "%0s/fire7_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire7_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:2687];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 2688; k = k + 1)
        wgt_stage_shared[gi][8704+k] = stage[k];
end
$sformat(fname, "%0s/fire8_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire8_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:767];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 768; k = k + 1)
        wgt_stage_shared[gi][11392+k] = stage[k];
end
$sformat(fname, "%0s/fire8_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire8_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:511];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 512; k = k + 1)
        wgt_stage_shared[gi][12160+k] = stage[k];
end
$sformat(fname, "%0s/fire8_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire8_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:4607];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 4608; k = k + 1)
        wgt_stage_shared[gi][12672+k] = stage[k];
end
$sformat(fname, "%0s/fire9_squeeze_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire9_squeeze
    reg [`WGT_WIDTH-1:0] stage [0:1023];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 1024; k = k + 1)
        wgt_stage_shared[gi][17280+k] = stage[k];
end
$sformat(fname, "%0s/fire9_expand1x1_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire9_expand1x1
    reg [`WGT_WIDTH-1:0] stage [0:511];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 512; k = k + 1)
        wgt_stage_shared[gi][18304+k] = stage[k];
end
$sformat(fname, "%0s/fire9_expand3x3_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_fire9_expand3x3
    reg [`WGT_WIDTH-1:0] stage [0:4607];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 4608; k = k + 1)
        wgt_stage_shared[gi][18816+k] = stage[k];
end
$sformat(fname, "%0s/conv10_weights_bank%02d.hex", `GOLDEN_DIR, gi);
begin : wgt_seq_stage_conv10
    reg [`WGT_WIDTH-1:0] stage [0:16383];
    integer k;
    $readmemh(fname, stage);
    for (k = 0; k < 16384; k = k + 1)
        wgt_stage_shared[gi][23424+k] = stage[k];
end

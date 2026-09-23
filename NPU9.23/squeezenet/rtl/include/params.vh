`ifndef PARAMS_VH
`define PARAMS_VH

`define ARRAY_ROWS          32  
`define ARRAY_COLS          32  

`define ACT_WIDTH           8   
`define ACT_SIGNED_WIDTH    9   
`define WGT_WIDTH            8  
`define ACC_WIDTH            32   
`define BIAS_WIDTH           32  
`define REQUANT_MULT_WIDTH   32  
`define REQUANT_SHIFT_WIDTH  6   
`define OUT_WIDTH            8   

`define ROW_IDX_WIDTH  $clog2(`ARRAY_ROWS)
`define COL_IDX_WIDTH  $clog2(`ARRAY_COLS)

`define FMAP_ADDR_WIDTH  20
`define WGT_ADDR_WIDTH   20
`define PSUM_ADDR_WIDTH  20
`define CNT_WIDTH        20

`define MAX_WGT_BANK_DEPTH      39808  
`define MAX_N_TILES             126    
`define MAX_FMAP_IN_BANK_DEPTH  150528 
`define MAX_FMAP_OUT_BANK_DEPTH 24642  
`define MAX_PSUM_BANK_DEPTH     12321 

`endif

`ifndef CONFIG_VH

`define DATA_WIDTH 8
`define MUL_WIDTH  (`DATA_WIDTH * 2)
`define ADD_WIDTH  (`DATA_WIDTH * 4)

`define ADDR_WIDTH 17
`define MEM_DEPTH  (1 << `ADDR_WIDTH)
`define MAX_WIDTH 256

`define sramnum 32
`define COEFF_WIDTH 8

`define MAX_IMG_WIDTH  512
`define IMG_ADDR_WIDTH $clog2(`MAX_IMG_WIDTH)

`define img_W 17'd28
`define img_H 17'd28
`endif


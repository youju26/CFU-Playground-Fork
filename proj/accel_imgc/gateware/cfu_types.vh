// <--- ALU ---> (for testing purposes)

// funct3
`define ALU      3'd7      

// funct7
`define ALU_ADD  7'd0
`define ALU_SUB  7'd1
`define ALU_MUL  7'd2

// <--- MAC --->

// funct3
`define MAC          3'd0      

// funct7
`define MAC_ACC      7'd0
`define MAC_CLEAR    7'd1
`define MAC_SET_OFF  7'd2
`define MAC_SET_INPUT_VALS      7'd3 // Load input_vals into CFU FiFo buffer
`define MAC_ON_BUFFER           7'd4 // Apply filter_vals on the input_vals, which are saved in the CFU input_val FiFo
`define MAC_CLEAR_INPUT_VALS    7'd5 // Clear the input_val FiFo

// <--- QNT --->

// funct3
`define QNT         3'd1

// funct7
`define SET_BIAS    7'd0 
`define SET_MUL_AND_SHIFT   7'd1
`define SET_OFFSET  7'd2
`define SET_MIN_AND_MAX     7'd3
`define GET         7'd4
`define STAGE_1     7'd5
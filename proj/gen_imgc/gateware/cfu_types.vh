// <--- MAC --->

// funct3
`define MAC          3'd0      

// funct7
`define MAC_ACC      7'd0
`define MAC_CLEAR    7'd1
`define MAC_SET_OFF  7'd2
`define MAC_GET      7'd3
`define MAC_SET_INPUT_VALS      7'd4 // Load input_vals into CFU FiFo buffer
`define MAC_ON_BUFFER           7'd5 // Apply filter_vals on the input_vals, which are saved in the CFU input_val FiFo
`define MAC_CLEAR_INPUT_VALS    7'd6 // Clear the input_val FiFo
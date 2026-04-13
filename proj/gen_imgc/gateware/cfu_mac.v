module cfu_mac (
    input         [31:0] a,

    input signed  [8:0]  input_0_and_offset,
    input signed  [8:0]  input_1_and_offset,
    input signed  [8:0]  input_2_and_offset,
    input signed  [8:0]  input_3_and_offset,

    output signed [15:0] prod_0,
    output signed [15:0] prod_1,
    output signed [15:0] prod_2,
    output signed [15:0] prod_3
);
  
  assign prod_0 = $signed(a[7 : 0]) * input_0_and_offset;
  assign prod_1 = $signed(a[15: 8]) * input_1_and_offset;
  assign prod_2 = $signed(a[23:16]) * input_2_and_offset;
  assign prod_3 = $signed(a[31:24]) * input_3_and_offset;
    
endmodule

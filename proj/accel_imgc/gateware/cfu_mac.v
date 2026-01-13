module cfu_mac (
    input signed  [31:0] a,
    input signed  [31:0] b,
    input signed  [31:0] offset,
    output signed [31:0] sum
);
  
  wire signed [31:0] prod;
  assign prod = a * (b + offset);
  assign sum = prod;

  /*wire signed [31:0] prod_0, prod_1, prod_2, prod_3; // TODO: 16 bit should be enough
  
  assign prod_0 = ($signed(a[7 : 0]) * ($signed(b[7 : 0]) + offset)); // TODO: Check if signed necessary
  assign prod_1 = ($signed(a[15: 8]) * ($signed(b[15: 8]) + offset));
  assign prod_2 = ($signed(a[23:16]) * ($signed(b[23:16]) + offset));
  assign prod_3 = ($signed(a[31:24]) * ($signed(b[31:24]) + offset));

  assign sum = prod_0 + prod_1 + prod_2 + prod_3;*/

  // TODO Combat Timing issues with pipelining
    
endmodule
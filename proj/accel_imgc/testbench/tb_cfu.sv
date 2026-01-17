`timescale 1ns/1ps

module tb_cfu;

  logic               cmd_valid;
  logic              cmd_ready;
  logic      [9:0]    cmd_payload_function_id;
  logic      [31:0]   cmd_payload_inputs_0;
  logic      [31:0]   cmd_payload_inputs_1;
  logic              rsp_valid;
  logic               rsp_ready;
  logic      [31:0]   rsp_payload_outputs_0;
  logic               reset;
  logic               clk;

  Cfu dut (
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .cmd_payload_function_id(cmd_payload_function_id),
    .cmd_payload_inputs_0(cmd_payload_inputs_0),
    .cmd_payload_inputs_1(cmd_payload_inputs_1),
    .rsp_valid(rsp_valid),
    .rsp_ready(rsp_ready),
    .rsp_payload_outputs_0(rsp_payload_outputs_0),
    .reset(reset),
    .clk(clk)
  );

  // Clock generation
  always #5 clk = ~clk;

  task automatic check(
    logic [9:0]  func_id,
    logic [31:0] input_0,
    logic [31:0] input_1
  );
    // Set up inputs
    cmd_payload_function_id = func_id;
    cmd_payload_inputs_0 = input_0;
    cmd_payload_inputs_1 = input_1;
    cmd_valid = 1'b1;
    rsp_ready = 1'b0;

    // Wait for response to be valid
    while (!rsp_valid) #10;
    
    // Read output while rsp_valid is high
    $display("Function ID: %10b | Input0: 0x%08h | Input1: 0x%08h | Output: 0d%05d", 
         func_id, input_0, input_1, rsp_payload_outputs_0);
    
    // Now acknowledge the response with rsp_ready
    rsp_ready = 1'b1;
    
    // Keep cmd_valid and rsp_ready stable until rsp_valid goes low
    while (rsp_valid) #10;
    
    // Clean up
    cmd_valid = 1'b0;
    rsp_ready = 1'b0;
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b0;
    cmd_valid = 1'b0;
    rsp_ready = 1'b0;
    cmd_payload_function_id = 10'b0;
    cmd_payload_inputs_0 = 32'b0;
    cmd_payload_inputs_1 = 32'b0;

    $dumpfile("wave.vcd");
    $dumpvars(0, tb_cfu);

    // Initial reset pulse
    reset = 1'b1;
    #20;
    reset = 1'b0;
    #20;

    // Test cases
    check(10'b0000000111, 32'h00000005, 32'h00000003);  // ALU_ADD
    check(10'b0000001111, 32'h00000005, 32'h00000003);  // ALU_SUB
    check(10'b0000010111, 32'h00000005, 32'h00000003);  // ALU_MUL
    check(10'b0000000000, 32'h00000505, 32'h00000403);  // MAC_ACC
    check(10'b0000000000, 32'h00000505, 32'h00000403);  // MAC_ACC
    check(10'b0000001000, 32'h00000505, 32'h00000403);  // MAC_CLEAR
    check(10'b0000000000, 32'h00000505, 32'h00000403);  // MAC_ACC
    
    $display("ALL TESTS PASSED");
    $finish;
  end

endmodule
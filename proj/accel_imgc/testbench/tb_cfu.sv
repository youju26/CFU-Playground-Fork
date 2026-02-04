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
    $display("  Func: %10b | In0: 0x%08h | In1: 0x%08h | Out: %05d | Cnt: %0d", 
         func_id, input_0, input_1, $signed(rsp_payload_outputs_0), dut.u_input_buffer.cnt);
    
    // Now acknowledge the response with rsp_ready
    rsp_ready = 1'b1;
    
    // Keep cmd_valid and rsp_ready stable until rsp_valid goes low
    while (rsp_valid) #10;
    
    // Clean up
    cmd_valid = 1'b0;
    rsp_ready = 1'b0;
    
    // Add small delay to simulate real CPU instruction spacing
    #10;
  endtask

  task automatic check_expect(
    logic [9:0]  func_id,
    logic [31:0] input_0,
    logic [31:0] input_1,
    logic signed [31:0] expected
  );
    // Set up inputs
    cmd_payload_function_id = func_id;
    cmd_payload_inputs_0 = input_0;
    cmd_payload_inputs_1 = input_1;
    cmd_valid = 1'b1;
    rsp_ready = 1'b0;

    // Wait for response to be valid
    while (!rsp_valid) #10;
    
    // Check result
    if ($signed(rsp_payload_outputs_0) == expected) begin
      $display("  ✓ PASS | Expected: %0d, Got: %0d | Cnt: %0d", 
               expected, $signed(rsp_payload_outputs_0), dut.u_input_buffer.cnt);
    end else begin
      $display("  ✗ FAIL | Expected: %0d, Got: %0d | Cnt: %0d", 
               expected, $signed(rsp_payload_outputs_0), dut.u_input_buffer.cnt);
      $display("         Func: %10b | In0: 0x%08h | In1: 0x%08h", func_id, input_0, input_1);
    end
    
    // Now acknowledge the response with rsp_ready
    rsp_ready = 1'b1;
    
    // Keep cmd_valid and rsp_ready stable until rsp_valid goes low
    while (rsp_valid) #10;
    
    // Clean up
    cmd_valid = 1'b0;
    rsp_ready = 1'b0;
    
    // Add small delay to simulate real CPU instruction spacing
    #10;
  endtask

  initial begin
    // Initialize signals
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
    $display("\n=== Basic ALU/MAC Tests ===");
    check_expect(10'b0000000111, 32'h00000005, 32'h00000003, 32'd8);
    check_expect(10'b0000001111, 32'h00000005, 32'h00000003, 32'd2);
    check_expect(10'b0000010111, 32'h00000005, 32'h00000003, 32'd15);
    
    check(10'b0000001000, 32'h00000000, 32'h00000000);  // MAC_CLEAR
    check_expect(10'b0000000000, 32'h01010101, 32'h01010101, 32'd4);
    check_expect(10'b0000000000, 32'h01010101, 32'h01010101, 32'd8);
    check(10'b0000001000, 32'h00000000, 32'h00000000);  // MAC_CLEAR
    
    $display("\n=== Buffer Fill Test ===");
    check(10'b0000101000, 32'h00000000, 32'h00000000);  // MAC_CLEAR_INPUT_VALS
    check(10'b0000011000, 32'h01010101, 32'h00000000);  // MAC_SET_INPUT_VALS
    check(10'b0000011000, 32'h02020202, 32'h00000000);  // MAC_SET_INPUT_VALS
    check(10'b0000011000, 32'h03030303, 32'h00000000);  // MAC_SET_INPUT_VALS
    check(10'b0000011000, 32'h04040404, 32'h00000000);  // MAC_SET_INPUT_VALS
    if (dut.u_input_buffer.cnt == 4)
      $display("  ✓ PASS: Buffer filled correctly (count=4)");
    else
      $display("  ✗ FAIL: Buffer count=%0d, expected 4", dut.u_input_buffer.cnt);
    
    $display("\n=== Buffer Reuse Test - Filter Set 1 ===");
    check(10'b0000010000, 32'h00000000, 32'h00000000);  // MAC_SET_OFF (offset=0)
    check(10'b0000001000, 32'h00000000, 32'h00000000);  // MAC_CLEAR
    
    // Expected: (1*1 + 1*1 + 1*1 + 1*1) = 4 per call, accumulating
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, 32'd4);  // 0 + (1*4) = 4
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, 32'd12); // 4 + (2*4) = 12
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, 32'd24); // 12 + (3*4) = 24
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, 32'd40); // 24 + (4*4) = 40
    
    if (dut.u_input_buffer.cnt == 4)
      $display("  ✓ PASS: Buffer count unchanged after reuse (count=4)");
    else
      $display("  ✗ FAIL: Buffer count=%0d, expected 4", dut.u_input_buffer.cnt);
    
    $display("\n=== Buffer Reuse Test - Filter Set 2 ===");
    check(10'b0000001000, 32'h00000000, 32'h00000000);  // MAC_CLEAR
    
    // Expected: (2*1 + 2*1 + 2*1 + 2*1) = 8, (2*2...)= 16, (2*3...)=24, (2*4...)=32
    check_expect(10'b0000100000, 32'h02020202, 32'h00000000, 32'd8);
    check_expect(10'b0000100000, 32'h02020202, 32'h00000000, 32'd24);   // 8 + 16
    check_expect(10'b0000100000, 32'h02020202, 32'h00000000, 32'd48);   // 24 + 24
    check_expect(10'b0000100000, 32'h02020202, 32'h00000000, 32'd80);   // 48 + 32
    
    if (dut.u_input_buffer.cnt == 4)
      $display("  ✓ PASS: Buffer still has 4 elements");
    else
      $display("  ✗ FAIL: Buffer count=%0d, expected 4", dut.u_input_buffer.cnt);
    
    $display("\n=== Negative Value Test ===");
    check(10'b0000101000, 32'h00000000, 32'h00000000);  // MAC_CLEAR_INPUT_VALS
    check(10'b0000011000, 32'hFFFEFDFC, 32'h00000000);  // MAC_SET_INPUT_VALS (-1,-2,-3,-4)
    check(10'b0000011000, 32'hFBFAF9F8, 32'h00000000);  // MAC_SET_INPUT_VALS (-5,-6,-7,-8)
    
    check(10'b0000010000, 32'h00000001, 32'h00000000);  // MAC_SET_OFF (offset=1)
    check(10'b0000001000, 32'h00000000, 32'h00000000);  // MAC_CLEAR
    
    // buffer[0] = 0xFFFEFDFC = (-1,-2,-3,-4)
    // weights = 0x01010101 = (1,1,1,1)
    // Expected: (1)*(1-1) + (1)*(1-2) + (1)*(1-3) + (1)*(1-4) = 0 - 1 - 2 - 3 = -6
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, -32'sd6);
    // buffer[1] = 0xFBFAF9F8 = (-5,-6,-7,-8)
    // weights = 0x01010101 = (1,1,1,1)
    // Expected: (1)*(1-5) + (1)*(1-6) + (1)*(1-7) + (1)*(1-8) = -4 + -5 + -6 + -7 = -22
    // Accumulated: (-6) + -(22) = -28
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, -32'sd28);
    
    $display("\n=== Mixed Positive/Negative Test ===");
    check(10'b0000101000, 32'h00000000, 32'h00000000);  // MAC_CLEAR_INPUT_VALS
    check(10'b0000011000, 32'h7F80FF00, 32'h00000000);  // MAC_SET_INPUT_VALS (127,-128,-1,0)
    
    check(10'b0000010000, 32'h00000000, 32'h00000000);  // MAC_SET_OFF (offset=0)
    check(10'b0000001000, 32'h00000000, 32'h00000000);  // MAC_CLEAR
    
    // Expected: 1*127 + 1*(-128) + 1*(-1) + 1*0 = -2
    check_expect(10'b0000100000, 32'h01010101, 32'h00000000, -32'sd2);
    
    $display("\n=== ALL TESTS COMPLETED ===");
    $finish;
  end

endmodule
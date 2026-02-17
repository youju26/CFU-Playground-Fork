`timescale 1ns/1ps

module tb_cfu_quantizer_hardcoded;

  // DUT IO
  logic clk;
  logic rst;
  logic signed [31:0] data_in;
  logic signed [31:0] bias;
  logic signed [31:0] mul;
  logic signed [5:0]  shift;
  logic signed [31:0] offset;
  logic signed [31:0] minv;
  logic signed [31:0] maxv;
  logic [1:0] control;
  wire signed [31:0] data_out;

  // Instantiate DUT
  cfu_quantizer dut (
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .bias(bias),
    .mul(mul),
    .shift(shift),
    .offset(offset),
    .min(minv),
    .max(maxv),
    .data_out(data_out),
    .control(control)
  );

  // Clock generation
  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic apply_and_check(
    input logic signed [31:0] t_data_in,
    input logic signed [31:0] t_bias,
    input logic signed [31:0] t_mul,
    input logic signed [5:0]  t_shift,
    input logic signed [31:0] t_offset,
    input logic signed [31:0] t_min,
    input logic signed [31:0] t_max,
    input logic signed [31:0] t_expected
  );
    begin
      data_in = t_data_in;
      bias    = t_bias;
      mul     = t_mul;
      shift   = t_shift;
      offset  = t_offset;
      minv    = t_min;
      maxv    = t_max;

      // Extern controlled stages 0 -> 1
      @(negedge clk); control = 2'd0; @(posedge clk);
      @(negedge clk); control = 2'd1; @(posedge clk);
      #1;

      if (data_out !== t_expected) begin
        $display("FAIL: got=%0d exp=%0d | acc=%0d bias=%0d mul=%0d shift=%0d off=%0d min=%0d max=%0d",
                 data_out, t_expected, t_data_in, t_bias, t_mul, t_shift, t_offset, t_min, t_max);
        $display("DEBUG: reg_ab_64=%0d reg_scaled_pre=%0d",
                 dut.reg_ab_64, dut.reg_scaled_pre);
        $display("DEBUG: ab_64=%0d nudge=%0d ab_rounded=%0d scaled_raw=%0d scaled_pre=%0d scaled=%0d",
                 dut.ab_64, dut.nudge, dut.ab_rounded, dut.scaled_raw, dut.scaled_pre, dut.scaled);
        $display("DEBUG: left_shift=%0d right_shift=%0d mask=%0d remainder=%0d threshold=%0d with_offset=%0d",
                 dut.left_shift, dut.right_shift, dut.mask, dut.remainder, dut.threshold, dut.with_offset);
        $fatal(1);
      end else begin
        $display("PASS: out=%0d | acc=%0d bias=%0d mul=%0d shift=%0d off=%0d min=%0d max=%0d",
                 data_out, t_data_in, t_bias, t_mul, t_shift, t_offset, t_min, t_max);
      end
    end
  endtask

  initial begin
    rst = 1'b1;
    control = 3'd0;
    data_in = 32'd0;
    bias = 32'd0;
    mul = 32'd0;
    shift = 6'd0;
    offset = 32'd0;
    minv = 32'd0;
    maxv = 32'd0;

    repeat (2) @(posedge clk);
    rst = 1'b0;

    // Vector 1:
    // -16113 18377 1459272781 -8 -128 -128 127 -122
    apply_and_check(
      -16113, 18377, 1459272781, -8,
      -128, -128, 127, -122
    );

    // Vector 2:
    // -17704 -13074 1201775990 -9 -128 -128 127 -128
    apply_and_check(
      -17704, -13074, 1201775990, -9,
      -128, -128, 127, -128
    );

    // Vector 3:
    // 8918 18642 2061439064 -9 -128 -128 127 -76
    apply_and_check(
      8918, 18642, 2061439064, -9,
      -128, -128, 127, -76
    );

    $display("All tests PASSED.");
    $finish;
  end

endmodule

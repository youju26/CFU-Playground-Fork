`include "gateware/cfu_types.vh"
`include "gateware/cfu_mac.v"
`include "gateware/cfu_input_buffer.v"

module Cfu (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid,
  input               rsp_ready,
  output reg [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);

  // <--- Buffer for Input Vals --->
  reg flag_buffer_clear;
  reg flag_buffer_write_en;
  reg flag_buffer_read_en;
  
  wire flag_buffer_read_valid;
  wire [8:0] buffer_count;
  wire buffer_write_full;
  wire buffer_read_empty;

  reg signed [31:0] buffer_write_data;
  wire signed [31:0] buffer_read_data;
  wire signed [8:0] input_0_and_offset;
  wire signed [8:0] input_1_and_offset;
  wire signed [8:0] input_2_and_offset;
  wire signed [8:0] input_3_and_offset;

  cfu_input_buffer u_input_buffer (
    .clk(clk),
    .rst(reset),
    .clear(flag_buffer_clear),
    .write_en(flag_buffer_write_en),
    .write_data(buffer_write_data),
    .write_full(buffer_write_full),
    .read_en(flag_buffer_read_en),
    .read_data(buffer_read_data),
    .offset(mac_offset),
    .input_0_and_offset(input_0_and_offset),
    .input_1_and_offset(input_1_and_offset),
    .input_2_and_offset(input_2_and_offset),
    .input_3_and_offset(input_3_and_offset),
    .read_data_valid(flag_buffer_read_valid),
    .read_empty(buffer_read_empty),
    .count(buffer_count)
  );

  // <--- Buffer B for Input Vals --->
  reg flag_buffer_clear_b;
  reg flag_buffer_write_en_b;
  reg flag_buffer_read_en_b;
  
  wire flag_buffer_read_valid_b;
  wire [8:0] buffer_count_b;
  wire buffer_write_full_b;
  wire buffer_read_empty_b;

  reg signed [31:0] buffer_write_data_b;
  wire signed [31:0] buffer_read_data_b;
  wire signed [8:0] input_0_and_offset_b;
  wire signed [8:0] input_1_and_offset_b;
  wire signed [8:0] input_2_and_offset_b;
  wire signed [8:0] input_3_and_offset_b;

  cfu_input_buffer u_input_buffer_b (
    .clk(clk),
    .rst(reset),
    .clear(flag_buffer_clear_b),
    .write_en(flag_buffer_write_en_b),
    .write_data(buffer_write_data_b),
    .write_full(buffer_write_full_b),
    .read_en(flag_buffer_read_en_b),
    .read_data(buffer_read_data_b),
    .offset(mac_offset),
    .input_0_and_offset(input_0_and_offset_b),
    .input_1_and_offset(input_1_and_offset_b),
    .input_2_and_offset(input_2_and_offset_b),
    .input_3_and_offset(input_3_and_offset_b),
    .read_data_valid(flag_buffer_read_valid_b),
    .read_empty(buffer_read_empty_b),
    .count(buffer_count_b)
  );

  // <--- MAC --->
  wire signed [15:0] prod_0;
  wire signed [15:0] prod_1;
  wire signed [15:0] prod_2;
  wire signed [15:0] prod_3;
  reg signed [8:0] mac_offset;
  reg signed [31:0] mac_acc_0;
  reg signed [31:0] mac_acc_1;
  reg signed [31:0] mac_acc_2;
  reg signed [31:0] mac_acc_3;

  cfu_mac u_mac_buffer(
    .a(cmd_payload_inputs_0),  // Weights
    .input_0_and_offset(input_0_and_offset),
    .input_1_and_offset(input_1_and_offset),
    .input_2_and_offset(input_2_and_offset),
    .input_3_and_offset(input_3_and_offset),
    .prod_0(prod_0),
    .prod_1(prod_1),
    .prod_2(prod_2),
    .prod_3(prod_3)
  );

    // <--- MAC B--->
  wire signed [15:0] prod_0_b;
  wire signed [15:0] prod_1_b;
  wire signed [15:0] prod_2_b;
  wire signed [15:0] prod_3_b;
  //reg signed [31:0] mac_acc_0;
  //reg signed [31:0] mac_acc_1;
  //reg signed [31:0] mac_acc_2;
  //reg signed [31:0] mac_acc_3;

  cfu_mac u_mac_buffer_b(
    .a(cmd_payload_inputs_1),  // Weights
    .input_0_and_offset(input_0_and_offset_b),
    .input_1_and_offset(input_1_and_offset_b),
    .input_2_and_offset(input_2_and_offset_b),
    .input_3_and_offset(input_3_and_offset_b),
    .prod_0(prod_0_b),
    .prod_1(prod_1_b),
    .prod_2(prod_2_b),
    .prod_3(prod_3_b)
  );

  // <--- Control --->
  assign cmd_ready = ~rsp_valid; // Ready to receive new command if no pending output

  always @(posedge clk) begin

    // Default: 
    flag_buffer_clear <= 1'b0;
    flag_buffer_read_en <= 1'b0;
    flag_buffer_write_en <= 1'b0;
    flag_buffer_clear_b <= 1'b0;
    flag_buffer_read_en_b <= 1'b0;
    flag_buffer_write_en_b <= 1'b0;

    if (reset) begin
      rsp_valid <= 1'b0; // Output not valid
      rsp_payload_outputs_0 <= 32'd0;
      mac_offset <= 32'd0;
      mac_acc_0 <= 32'd0;
      mac_acc_1 <= 32'd0;
      mac_acc_2 <= 32'd0;
      mac_acc_3 <= 32'd0;
      
    end else if (rsp_valid) begin
      // Check if CPU accepted response, if yes, pull down rsp_valid and implicitly set cmd_ready to 1
      rsp_valid <= ~rsp_ready;

    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;

      // Default
      rsp_payload_outputs_0 <= 32'b0;

      case (cmd_payload_function_id[2:0])
        `MAC: begin
          case (cmd_payload_function_id[9:3])
            `MAC_CLEAR: begin
              mac_acc_0 <= 32'd0;
              mac_acc_1 <= 32'd0;
              mac_acc_2 <= 32'd0;
              mac_acc_3 <= 32'd0;
            end
            `MAC_SET_OFF: begin
              mac_offset <= cmd_payload_inputs_0[8:0];
            end
            `MAC_GET: begin
              rsp_payload_outputs_0 <= mac_acc_0 + mac_acc_1 + mac_acc_2 + mac_acc_3;
            end
            `MAC_SET_INPUT_VALS: begin
              buffer_write_data <= cmd_payload_inputs_0;
              buffer_write_data_b <= cmd_payload_inputs_1;
              flag_buffer_write_en <= 1'b1;
              flag_buffer_write_en_b <= 1'b1;
            end
            `MAC_ON_BUFFER: begin             
              flag_buffer_read_en <= 1'b1;
              flag_buffer_read_en_b <= 1'b1;
              // Add MAC sum to each acc
              mac_acc_0 <= mac_acc_0 + prod_0 + prod_0_b;
              mac_acc_1 <= mac_acc_1 + prod_1 + prod_1_b;
              mac_acc_2 <= mac_acc_2 + prod_2 + prod_2_b;
              mac_acc_3 <= mac_acc_3 + prod_3 + prod_3_b;
              // Re-append the value to keep it in the buffer for multiple filter sets
              flag_buffer_write_en <= 1'b1;
              buffer_write_data <= buffer_read_data;
              flag_buffer_write_en_b <= 1'b1;
              buffer_write_data_b <= buffer_read_data_b;
            end
            `MAC_CLEAR_INPUT_VALS: begin
              flag_buffer_clear <= 1'b1;
              flag_buffer_clear_b <= 1'b1;
            end
          endcase
        end
      endcase
    end
  end
endmodule

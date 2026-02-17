`include "gateware/cfu_types.vh"
`include "gateware/cfu_regs.v"
`include "gateware/cfu_mac.v"
`include "gateware/cfu_input_buffer.v"
`include "gateware/cfu_quantizer.v"

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

  // <--- Register File --->
  wire signed [31:0] offset;
  wire signed [31:0] acc;

  reg flag_write_offset;
  reg flag_add_acc;
  reg flag_clear_acc;
  reg signed [31:0] input_value;

  cfu_regs u_regs (
    .clk(clk),
    .reset(reset),
    .flag_write_offset(flag_write_offset),
    .flag_add_acc(flag_add_acc),
    .flag_clear_acc(flag_clear_acc),
    .input_value(input_value),
    .offset(offset),
    .acc(acc)
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

  cfu_input_buffer u_input_buffer (
    .clk(clk),
    .rst(reset),
    .clear(flag_buffer_clear),
    .write_en(flag_buffer_write_en),
    .write_data(buffer_write_data),
    .write_full(buffer_write_full),
    .read_en(flag_buffer_read_en),
    .read_data(buffer_read_data),
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

  cfu_input_buffer u_input_buffer_b (
    .clk(clk),
    .rst(reset),
    .clear(flag_buffer_clear_b),
    .write_en(flag_buffer_write_en_b),
    .write_data(buffer_write_data_b),
    .write_full(buffer_write_full_b),
    .read_en(flag_buffer_read_en_b),
    .read_data(buffer_read_data_b),
    .read_data_valid(flag_buffer_read_valid_b),
    .read_empty(buffer_read_empty_b),
    .count(buffer_count_b)
  );

  // <--- MAC --->
  wire signed [31:0] mac_sum;

  cfu_mac u_mac(
    .a(cmd_payload_inputs_0),  // Activations
    .b(cmd_payload_inputs_1),  // Weights
    .offset(offset),
    .sum(mac_sum)
  );

   // <--- MAC 2 (for buffer calc) --->
  wire signed [31:0] mac2_sum;

  cfu_mac u_mac_buffer(
    .a(cmd_payload_inputs_0),  // Weights
    .b(buffer_read_data),  // Activations
    .offset(offset),
    .sum(mac2_sum)
  );

  // <--- MAC 2 B (for buffer B calc) --->
  wire signed [31:0] mac2_sum_b;

  cfu_mac u_mac_buffer_b(
    .a(cmd_payload_inputs_1),  // Weights
    .b(buffer_read_data_b),  // Activations
    .offset(offset),
    .sum(mac2_sum_b)
  );

  // <--- Quantizer --->
  reg signed [31:0] qnt_bias;
  reg signed [31:0] qnt_mul;
  reg signed [5:0] qnt_shift;
  reg signed [31:0] qnt_offset;
  reg signed [31:0] qnt_min;
  reg signed [31:0] qnt_max;
  wire signed [31:0] qnt_out;
  reg [1:0] control;

  cfu_quantizer u_quantizer(
    .clk(clk),
    .rst(reset),
    .data_in(acc),
    .bias(qnt_bias),
    .mul(qnt_mul),
    .shift(qnt_shift),
    .offset(qnt_offset),
    .min(qnt_min),
    .max(qnt_max),
    .data_out(qnt_out),
    .control(control)
  );

  // <--- Control --->
  assign cmd_ready = ~rsp_valid; // Ready to receive new command if no pending output

  always @(posedge clk) begin
    // Default: No register write
    flag_write_offset <= 1'b0;
    flag_add_acc <= 1'b0;
    flag_clear_acc <= 1'b0;
    flag_buffer_clear <= 1'b0;
    flag_buffer_write_en <= 1'b0;
    flag_buffer_read_en <= 1'b0;
    flag_buffer_clear_b <= 1'b0;
    flag_buffer_write_en_b <= 1'b0;
    flag_buffer_read_en_b <= 1'b0;
    control <= 2'b00;

    if (reset) begin
      rsp_valid <= 1'b0; // Output not valid
      rsp_payload_outputs_0 <= 32'b0;
      // Initialize QNT registers
      qnt_bias <= 32'sd0;
      qnt_mul <= 32'sd0;
      qnt_shift <= 6'sd0;
      qnt_offset <= 32'sd0;
      qnt_min <= 32'sd0;
      qnt_max <= 32'sd0;
      control <= 2'b00;
    end else if (rsp_valid) begin
      // Check if CPU accepted response, if yes, pull down rsp_valid and implicitly set cmd_ready to 1
      rsp_valid <= ~rsp_ready; 
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;

      case (cmd_payload_function_id[2:0])
        `ALU: begin
          case (cmd_payload_function_id[9:3])
            `ALU_ADD: rsp_payload_outputs_0 <= cmd_payload_inputs_0 + cmd_payload_inputs_1;
            `ALU_SUB: rsp_payload_outputs_0 <= cmd_payload_inputs_0 - cmd_payload_inputs_1;
            `ALU_MUL: rsp_payload_outputs_0 <= cmd_payload_inputs_0 * cmd_payload_inputs_1;
            default: rsp_payload_outputs_0 <= 32'b0;
          endcase
          end

        `MAC: begin
          case (cmd_payload_function_id[9:3])
            `MAC_ACC: begin
              // Acc + MAC_Sum
              flag_add_acc <= 1'b1;
              input_value <= mac_sum;
              rsp_payload_outputs_0 <= acc + mac_sum;
            end
            `MAC_CLEAR: begin
              flag_clear_acc <= 1'b1;
              rsp_payload_outputs_0 <= 32'd0; 
            end
            `MAC_SET_OFF: begin
              flag_write_offset <= 1'b1;
              input_value <= cmd_payload_inputs_0;
              rsp_payload_outputs_0 <= acc;
            end
            `MAC_SET_INPUT_VALS: begin
              buffer_write_data <= cmd_payload_inputs_0;
              buffer_write_data_b <= cmd_payload_inputs_1;
              flag_buffer_write_en <= 1'b1;
              flag_buffer_write_en_b <= 1'b1;
              rsp_payload_outputs_0 <= 32'd0;
            end
            `MAC_ON_BUFFER: begin
              if (flag_buffer_read_valid && flag_buffer_read_valid_b) begin               
                flag_buffer_read_en <= 1'b1;
                flag_buffer_read_en_b <= 1'b1;
                flag_add_acc <= 1'b1;
                input_value <= mac2_sum + mac2_sum_b;
                rsp_payload_outputs_0 <= acc + mac2_sum + mac2_sum_b;
                // Re-append the value to keep it in the buffer for multiple filter sets
                flag_buffer_write_en <= 1'b1;
                flag_buffer_write_en_b <= 1'b1;
                buffer_write_data <= buffer_read_data;
                buffer_write_data_b <= buffer_read_data_b;
              end else begin
                rsp_payload_outputs_0 <= acc;
              end
            end
            `MAC_CLEAR_INPUT_VALS: begin
              flag_buffer_clear <= 1'b1;
              flag_buffer_clear_b <= 1'b1;
              rsp_payload_outputs_0 <= 32'd0;
            end
            default: rsp_payload_outputs_0 <= 32'b0;
          endcase
        end

        `QNT: begin
          case (cmd_payload_function_id[9:3])
            `SET_BIAS: begin
              qnt_bias <= cmd_payload_inputs_0;
              rsp_payload_outputs_0 <= 32'd0;
            end
            `SET_MUL_AND_SHIFT: begin
              qnt_mul <= cmd_payload_inputs_0;
              qnt_shift <= cmd_payload_inputs_1;
              rsp_payload_outputs_0 <= 32'd0;
            end
            `SET_OFFSET: begin
              qnt_offset <= cmd_payload_inputs_0;
              rsp_payload_outputs_0 <= 32'd0;
            end
            `SET_MIN_AND_MAX: begin
              qnt_min <= cmd_payload_inputs_0;
              qnt_max <= cmd_payload_inputs_1;
              rsp_payload_outputs_0 <= 32'd0;
            end
            `GET: begin
              rsp_payload_outputs_0 <= qnt_out;
              control <= 2'b00;
            end
            `STAGE_1: begin
              control <= 2'b01;
              rsp_payload_outputs_0 <= 32'b0;
            end
            default: rsp_payload_outputs_0 <= 32'b0;
          endcase
        end
      endcase
    end
  end

endmodule

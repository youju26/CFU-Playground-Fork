`include "gateware/cfu_types.vh"
`include "gateware/cfu_regs.v"
`include "gateware/cfu_mac.v"

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

  // <--- MAC --->
  wire signed [31:0] mac_sum;

  cfu_mac u_mac(
    .a(cmd_payload_inputs_0),  // Activations
    .b(cmd_payload_inputs_1),  // Weights
    .offset(offset),
    .sum(mac_sum)
  );

  // <--- Control --->
  assign cmd_ready = ~rsp_valid; // Ready to receive new command if no pending output

  always @(posedge clk) begin
    if (reset) begin
      rsp_valid <= 1'b0; // Output not valid
      rsp_payload_outputs_0 <= 32'b0;
      flag_write_offset <= 1'b0;
      flag_add_acc <= 1'b0;
      flag_clear_acc <= 1'b0;
    end else if (rsp_valid) begin
      // Check if CPU accepted response, if yes, pull down rsp_valid and implicitly set cmd_ready to 1
      rsp_valid <= ~rsp_ready; 
      // Clear flags
      flag_write_offset <= 1'b0;
      flag_add_acc <= 1'b0;
      flag_clear_acc <= 1'b0;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;

      // Default: No register write
      flag_write_offset <= 1'b0;
      flag_add_acc <= 1'b0;
      flag_clear_acc <= 1'b0;

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
            default: rsp_payload_outputs_0 <= 32'b0;
          endcase
        end
      endcase
    end
  end

endmodule

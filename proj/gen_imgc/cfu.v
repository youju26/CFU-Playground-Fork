`include "gateware/cfu_types.vh"
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

  cfu_mac u_mac(
    .a(cmd_payload_inputs_0),  // Weights
    .b(cmd_payload_inputs_1),  // Activations
    .offset(mac_offset),
    .prod_0(prod_0),
    .prod_1(prod_1),
    .prod_2(prod_2),
    .prod_3(prod_3)
  );

  // <--- Control --->
  assign cmd_ready = ~rsp_valid; // Ready to receive new command if no pending output

  always @(posedge clk) begin

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
            `MAC_ACC: begin
              // Add MAC sum to each acc
              mac_acc_0 <= mac_acc_0 + prod_0;
              mac_acc_1 <= mac_acc_1 + prod_1;
              mac_acc_2 <= mac_acc_2 + prod_2;
              mac_acc_3 <= mac_acc_3 + prod_3;
            end
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
          endcase
        end
      endcase
    end
  end
endmodule

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
  assign cmd_ready = ~rsp_valid;

  reg [31:0] mul, acc;
  reg mul_valid, acc_valid;

  always @(posedge clk) begin

    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
      mul_valid <= 1'b0;
      acc_valid <= 1'b0;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      // Calculation step
      mul_valid <= 1'b1;
      mul <= cmd_payload_inputs_0 * cmd_payload_inputs_1;
      rsp_payload_outputs_0 <= cmd_payload_inputs_0 * cmd_payload_inputs_1;
      rsp_valid <= 1'b1;
    end /*else if (mul_valid) begin
      // Accumulation Step
      acc_valid <= 1'b1;
      acc <= acc + mul;
    end else if (acc_valid) begin
      rsp_valid <= 1'b1;
      rsp_payload_outputs_0 <= |cmd_payload_function_id[9:3]
        ? 32'b0
        : acc;
    end*/
  end
endmodule


// Previous code from playing around
/*case (cmd_payload_function_id[2:0])
        3'd0: rsp_payload_outputs_0 <= cmd_payload_inputs_0 + cmd_payload_inputs_1; // Add
        3'd1: rsp_payload_outputs_0 <= cmd_payload_inputs_0 - cmd_payload_inputs_1; // Sub
        3'd2: rsp_payload_outputs_0 <= cmd_payload_inputs_0 * cmd_payload_inputs_1; // Mul/MAC
        
        // MAC for Convolution
        3'd3: rsp_payload_outputs_0 <= |cmd_payload_function_id[9:3]
          ? 32'b0
          //: rsp_payload_outputs_0 + mul_wire;
          : cmd_payload_inputs_0 * cmd_payload_inputs_1;

        default: rsp_payload_outputs_0 <= 0; // Not defined
      endcase*/
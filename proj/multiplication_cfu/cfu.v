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

  reg signed [31:0] input_offset;

  // MAC computation
  wire signed [31:0] prod_0;
  assign prod_0 = ($signed(cmd_payload_inputs_0[7 : 0]) * ($signed(cmd_payload_inputs_1[7 : 0]) + input_offset));
  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0;

  // If we have a response, not ready to accept a new command.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
      //input_offset <= 32'b0; TODO: Check if reset is needed
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      // Calculation step
      case (cmd_payload_function_id[2:0])
        3'd0: rsp_payload_outputs_0 <= cmd_payload_inputs_0 + cmd_payload_inputs_1; // Add
        3'd1: rsp_payload_outputs_0 <= cmd_payload_inputs_0 - cmd_payload_inputs_1; // Sub
        3'd2: rsp_payload_outputs_0 <= cmd_payload_inputs_0 * cmd_payload_inputs_1; // Mul
        
        // MAC for Convolution
        3'd3: begin
          case (cmd_payload_function_id[9:3])
            7'd0: rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods; // MAC Accumulate
            7'd1: rsp_payload_outputs_0 <= 32'b0;
            7'd2: input_offset <= cmd_payload_inputs_0;
            default: rsp_payload_outputs_0 <= 0; // Not defined
          endcase
        end
        default: rsp_payload_outputs_0 <= 0; // Not defined
      endcase
    end
  end
endmodule



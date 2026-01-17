module cfu_regs (
  input                      clk,
  input                      reset,
  input                      flag_write_offset,
  input                      flag_add_acc,
  input                      flag_clear_acc,
  input      signed [31:0]   input_value,
  output reg signed [31:0]   offset,
  output reg signed [31:0]   acc
);

  always @(posedge clk) begin
    if (reset) begin
      offset <= 0;
      acc <= 0;
    end else begin
      if (flag_write_offset) begin
        offset <= input_value;
      end 
      
      if (flag_clear_acc) begin
        acc <= 0;
        //$display("REGS: flag_clear_acc=1, acc <= 0");
      end else if (flag_add_acc) begin
        acc <= acc + input_value;
        //$display("REGS: flag_add_acc=1, acc <= %0d + %0d = %0d", acc, input_value, acc + input_value);
      end
    end
  end 

endmodule
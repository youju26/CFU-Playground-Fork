`timescale 1ns/1ps

module cfu_decode_tb;

  logic [9:0] function_id;
  logic [2:0] op;
  logic [6:0] subop;

  cfu_decode dut (
    .function_id(function_id),
    .op(op),
    .subop(subop)
  );

  task automatic check(input logic [9:0] in);
    function_id = in;
    #1;

    assert (op == in[2:0])
      else $fatal(1, "op mismatch: in=%b op=%b exp=%b", in, op, in[2:0]);

    assert (subop == in[9:3])
      else $fatal(1, "subop mismatch: in=%b subop=%b exp=%b", in, subop, in[9:3]);

    $display("PASS: in=%10b op=%3b subop=%7b", in, op, subop);
  endtask

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, cfu_decode_tb);

    check(10'b0000000000);
    check(10'b0001010111);
    check(10'b1111111001);
    $display("ALL TESTS PASSED");
    $finish;
  end

endmodule
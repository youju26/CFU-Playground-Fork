module cfu_decode (
    input           [9:0]   function_id,
    output          [2:0]   op,
    output          [6:0]   subop
);

    assign op    = function_id[2:0];
    assign subop = function_id[9:3];
    
endmodule
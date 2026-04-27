`include "gateware/cfu_types.vh"
`include "gateware/cfu_mac.v"
`include "gateware/cfu_input_buffer.v"
`include "gateware/cfu_quantizer.v"
`include "gateware/cfu_filter_buffer.v"

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

  // <--- Quantizer --->
  reg signed [31:0] qnt_bias;
  reg signed [31:0] qnt_mul;
  reg signed [5:0] qnt_shift;
  reg signed [31:0] qnt_offset;
  reg signed [31:0] qnt_min;
  reg signed [31:0] qnt_max;
  wire signed [31:0] qnt_out;
  wire qnt_status;
  reg flag_qnt_start;
  reg flag_qnt_pending;

  cfu_quantizer u_quantizer(
    .clk(clk),
    .rst(reset),
    .data_in(mac_acc_0 + mac_acc_1 + mac_acc_2 + mac_acc_3),
    .bias(qnt_bias),
    .mul(qnt_mul),
    .shift(qnt_shift),
    .offset(qnt_offset),
    .min(qnt_min),
    .max(qnt_max),
    .data_out(qnt_out),
    .start(flag_qnt_start),
    .status(qnt_status)
  );

  localparam integer FILTER_BANKS = 32;
  localparam integer FILTER_BANK_ADDR_W = 5;

  // <--- Buffer for Input Vals --->
  reg flag_input_buffer_clear;
  reg flag_input_buffer_write_en;
  reg flag_input_buffer_read_en;
  reg signed [8:0] mac_offset;
  
  wire flag_input_buffer_read_valid;
  wire [8:0] input_buffer_count;
  wire input_buffer_write_full;
  wire input_buffer_read_empty;

  reg signed [31:0] input_buffer_write_data;
  wire signed [31:0] input_buffer_read_data;
  wire signed [8:0] input_0_and_offset;
  wire signed [8:0] input_1_and_offset;
  wire signed [8:0] input_2_and_offset;
  wire signed [8:0] input_3_and_offset;

  cfu_input_buffer u_input_buffer (
    .clk(clk),
    .rst(reset),
    .clear(flag_input_buffer_clear),
    .write_en(flag_input_buffer_write_en),
    .write_data(input_buffer_write_data),
    .write_full(input_buffer_write_full),
    .read_en(flag_input_buffer_read_en),
    .read_data(input_buffer_read_data),
    .offset(mac_offset),
    .input_0_and_offset(input_0_and_offset),
    .input_1_and_offset(input_1_and_offset),
    .input_2_and_offset(input_2_and_offset),
    .input_3_and_offset(input_3_and_offset),
    .read_data_valid(flag_input_buffer_read_valid),
    .read_empty(input_buffer_read_empty),
    .count(input_buffer_count)
  );

  // <--- Buffer B for Input Vals --->
  reg flag_input_buffer_clear_b;
  reg flag_input_buffer_write_en_b;
  reg flag_input_buffer_read_en_b;

  wire flag_input_buffer_read_valid_b;
  wire [8:0] input_buffer_count_b;
  wire input_buffer_write_full_b;
  wire input_buffer_read_empty_b;

  reg signed [31:0] input_buffer_write_data_b;
  wire signed [31:0] input_buffer_read_data_b;
  wire signed [8:0] input_0_and_offset_b;
  wire signed [8:0] input_1_and_offset_b;
  wire signed [8:0] input_2_and_offset_b;
  wire signed [8:0] input_3_and_offset_b;

  cfu_input_buffer u_input_buffer_b (
    .clk(clk),
    .rst(reset),
    .clear(flag_input_buffer_clear_b),
    .write_en(flag_input_buffer_write_en_b),
    .write_data(input_buffer_write_data_b),
    .write_full(input_buffer_write_full_b),
    .read_en(flag_input_buffer_read_en_b),
    .read_data(input_buffer_read_data_b),
    .offset(mac_offset),
    .input_0_and_offset(input_0_and_offset_b),
    .input_1_and_offset(input_1_and_offset_b),
    .input_2_and_offset(input_2_and_offset_b),
    .input_3_and_offset(input_3_and_offset_b),
    .read_data_valid(flag_input_buffer_read_valid_b),
    .read_empty(input_buffer_read_empty_b),
    .count(input_buffer_count_b)
  );

  // <--- Filter/Weight Buffer Banks --->
  reg  [FILTER_BANKS-1:0] flag_filter_buffer_clear;
  reg  [FILTER_BANKS-1:0] flag_filter_buffer_write_en;
  reg  [FILTER_BANKS-1:0] flag_filter_buffer_read_en;
  reg  [31:0]             filter_buffer_write_data;
  reg  [FILTER_BANKS-1:0] flag_filter_buffer_clear_b;
  reg  [FILTER_BANKS-1:0] flag_filter_buffer_write_en_b;
  reg  [FILTER_BANKS-1:0] flag_filter_buffer_read_en_b;
  reg  [31:0]             filter_buffer_write_data_b;
  reg  [FILTER_BANK_ADDR_W-1:0] filter_bank_wr_idx;
  reg  [FILTER_BANK_ADDR_W-1:0] filter_bank_rd_idx;

  wire [FILTER_BANKS-1:0] filter_buffer_write_full;
  wire [FILTER_BANKS-1:0] filter_buffer_read_empty;
  wire [FILTER_BANKS-1:0] flag_filter_buffer_read_valid;
  wire [31:0]             filter_buffer_read_data [0:FILTER_BANKS-1];
  wire [8:0]              filter_buffer_count [0:FILTER_BANKS-1];
  wire [FILTER_BANKS-1:0] filter_buffer_write_full_b;
  wire [FILTER_BANKS-1:0] filter_buffer_read_empty_b;
  wire [FILTER_BANKS-1:0] flag_filter_buffer_read_valid_b;
  wire [31:0]             filter_buffer_read_data_b [0:FILTER_BANKS-1];
  wire [8:0]              filter_buffer_count_b [0:FILTER_BANKS-1];
  wire [FILTER_BANKS-1:0] filter_bank_wr_sel;
  wire [FILTER_BANKS-1:0] filter_bank_rd_sel;

  reg [31:0] selected_filter_data;
  reg [31:0] selected_filter_data_b;
  integer selected_filter_bank_idx;

  always @(*) begin
    selected_filter_data = 32'b0;
    selected_filter_data_b = 32'b0;
    for (selected_filter_bank_idx = 0;
         selected_filter_bank_idx < FILTER_BANKS;
         selected_filter_bank_idx = selected_filter_bank_idx + 1) begin
      if (filter_bank_rd_idx == selected_filter_bank_idx[FILTER_BANK_ADDR_W-1:0]) begin
        selected_filter_data = filter_buffer_read_data[selected_filter_bank_idx];
        selected_filter_data_b = filter_buffer_read_data_b[selected_filter_bank_idx];
      end
    end
  end

  assign filter_bank_wr_sel = ({{(FILTER_BANKS-1){1'b0}}, 1'b1}
                               << filter_bank_wr_idx[FILTER_BANK_ADDR_W-1:0]);
  assign filter_bank_rd_sel = ({{(FILTER_BANKS-1){1'b0}}, 1'b1}
                               << filter_bank_rd_idx[FILTER_BANK_ADDR_W-1:0]);

  genvar filter_bank_i;
  generate
    for (filter_bank_i = 0; filter_bank_i < FILTER_BANKS; filter_bank_i = filter_bank_i + 1) begin : g_filter_buffer
      cfu_filter_buffer u_filter_buffer (
        .clk(clk),
        .rst(reset),
        .clear(flag_filter_buffer_clear[filter_bank_i]),
        .write_en(flag_filter_buffer_write_en[filter_bank_i]),
        .write_data(filter_buffer_write_data),
        .write_full(filter_buffer_write_full[filter_bank_i]),
        .read_en(flag_filter_buffer_read_en[filter_bank_i]),
        .read_data(filter_buffer_read_data[filter_bank_i]),
        .read_data_valid(flag_filter_buffer_read_valid[filter_bank_i]),
        .read_empty(filter_buffer_read_empty[filter_bank_i]),
        .count(filter_buffer_count[filter_bank_i])
      );

      cfu_filter_buffer u_filter_buffer_b (
        .clk(clk),
        .rst(reset),
        .clear(flag_filter_buffer_clear_b[filter_bank_i]),
        .write_en(flag_filter_buffer_write_en_b[filter_bank_i]),
        .write_data(filter_buffer_write_data_b),
        .write_full(filter_buffer_write_full_b[filter_bank_i]),
        .read_en(flag_filter_buffer_read_en_b[filter_bank_i]),
        .read_data(filter_buffer_read_data_b[filter_bank_i]),
        .read_data_valid(flag_filter_buffer_read_valid_b[filter_bank_i]),
        .read_empty(filter_buffer_read_empty_b[filter_bank_i]),
        .count(filter_buffer_count_b[filter_bank_i])
      );
    end
  endgenerate

  // <--- MAC --->
  wire signed [15:0] prod_0;
  wire signed [15:0] prod_1;
  wire signed [15:0] prod_2;
  wire signed [15:0] prod_3;
  wire signed [15:0] prod_0_b;
  wire signed [15:0] prod_1_b;
  wire signed [15:0] prod_2_b;
  wire signed [15:0] prod_3_b;
  reg signed [31:0] mac_acc_0;
  reg signed [31:0] mac_acc_1;
  reg signed [31:0] mac_acc_2;
  reg signed [31:0] mac_acc_3;

  cfu_mac u_mac_buffer(
    .a(selected_filter_data),  // Weights
    .input_0_and_offset(input_0_and_offset),
    .input_1_and_offset(input_1_and_offset),
    .input_2_and_offset(input_2_and_offset),
    .input_3_and_offset(input_3_and_offset),
    .prod_0(prod_0),
    .prod_1(prod_1),
    .prod_2(prod_2),
    .prod_3(prod_3)
  );

  cfu_mac u_mac_buffer_b(
    .a(selected_filter_data_b),  // Weights lane B
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
  assign cmd_ready = ~rsp_valid && ~flag_qnt_pending; // Block new commands while quantizer result is pending

  always @(posedge clk) begin

    // Default: 
    flag_input_buffer_clear <= 1'b0;
    flag_input_buffer_read_en <= 1'b0;
    flag_input_buffer_write_en <= 1'b0;
    flag_input_buffer_clear_b <= 1'b0;
    flag_input_buffer_read_en_b <= 1'b0;
    flag_input_buffer_write_en_b <= 1'b0;
    flag_filter_buffer_clear <= {FILTER_BANKS{1'b0}};
    flag_filter_buffer_read_en <= {FILTER_BANKS{1'b0}};
    flag_filter_buffer_write_en <= {FILTER_BANKS{1'b0}};
    flag_filter_buffer_clear_b <= {FILTER_BANKS{1'b0}};
    flag_filter_buffer_read_en_b <= {FILTER_BANKS{1'b0}};
    flag_filter_buffer_write_en_b <= {FILTER_BANKS{1'b0}};
    flag_qnt_start <= 1'b0;

    if (reset) begin
      rsp_valid <= 1'b0; // Output not valid
      rsp_payload_outputs_0 <= 32'd0;
      mac_offset <= 32'd0;
      mac_acc_0 <= 32'd0;
      mac_acc_1 <= 32'd0;
      mac_acc_2 <= 32'd0;
      mac_acc_3 <= 32'd0;
      filter_bank_wr_idx <= {FILTER_BANK_ADDR_W{1'b0}};
      filter_bank_rd_idx <= {FILTER_BANK_ADDR_W{1'b0}};
      // Initialize QNT registers
      qnt_bias <= 32'sd0;
      qnt_mul <= 32'sd0;
      qnt_shift <= 6'sd0;
      qnt_offset <= 32'sd0;
      qnt_min <= 32'sd0;
      qnt_max <= 32'sd0;
      flag_qnt_pending <= 1'b0;
      
    end else if (rsp_valid) begin
      // Check if CPU accepted response, if yes, pull down rsp_valid and implicitly set cmd_ready to 1
      rsp_valid <= ~rsp_ready;

    // Handle multi cycle operations
    end else if (flag_qnt_pending) begin
      if (qnt_status) begin
        rsp_payload_outputs_0 <= qnt_out;
        rsp_valid <= 1'b1;
        flag_qnt_pending <= 1'b0;
        filter_bank_rd_idx <= filter_bank_rd_idx + 1'b1;
      end

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
            `MAC_SET_INPUT_VALS: begin
              input_buffer_write_data <= cmd_payload_inputs_0;
              input_buffer_write_data_b <= cmd_payload_inputs_1;
              flag_input_buffer_write_en <= 1'b1;
              flag_input_buffer_write_en_b <= 1'b1;
            end
            `MAC_ON_BUFFER: begin             
              flag_input_buffer_read_en <= 1'b1;
              flag_input_buffer_read_en_b <= 1'b1;
              flag_filter_buffer_read_en <= filter_bank_rd_sel;
              flag_filter_buffer_read_en_b <= filter_bank_rd_sel;
              // Add MAC sum to each acc
              mac_acc_0 <= mac_acc_0 + prod_0 + prod_0_b;
              mac_acc_1 <= mac_acc_1 + prod_1 + prod_1_b;
              mac_acc_2 <= mac_acc_2 + prod_2 + prod_2_b;
              mac_acc_3 <= mac_acc_3 + prod_3 + prod_3_b;
              // Re-append the values to keep them in the buffer
              flag_input_buffer_write_en <= 1'b1;
              input_buffer_write_data <= input_buffer_read_data;
              flag_input_buffer_write_en_b <= 1'b1;
              input_buffer_write_data_b <= input_buffer_read_data_b;
              flag_filter_buffer_write_en <= filter_bank_rd_sel;
              filter_buffer_write_data <= selected_filter_data;
              flag_filter_buffer_write_en_b <= filter_bank_rd_sel;
              filter_buffer_write_data_b <= selected_filter_data_b;
            end
            `MAC_CLEAR_INPUT_VALS: begin
              flag_input_buffer_clear <= 1'b1;
              flag_input_buffer_clear_b <= 1'b1;
            end
            `MAC_SET_FILTER_VALS: begin
              filter_buffer_write_data <= cmd_payload_inputs_0;
              filter_buffer_write_data_b <= cmd_payload_inputs_1;
              flag_filter_buffer_write_en <= filter_bank_wr_sel;
              flag_filter_buffer_write_en_b <= filter_bank_wr_sel;
            end
            `MAC_CLEAR_FILTER_VALS: begin
              flag_filter_buffer_clear <= {FILTER_BANKS{1'b1}};
              flag_filter_buffer_clear_b <= {FILTER_BANKS{1'b1}};
              filter_bank_wr_idx <= {FILTER_BANK_ADDR_W{1'b0}};
              filter_bank_rd_idx <= {FILTER_BANK_ADDR_W{1'b0}};
            end
            `MAC_NEXT_FILTER_SET: begin
                filter_bank_wr_idx <= filter_bank_wr_idx + 1'b1;
            end
            `MAC_REWIND_FILTER_SET: begin
              filter_bank_rd_idx <= {FILTER_BANK_ADDR_W{1'b0}};
            end
          endcase
        end

        `QNT: begin
          case (cmd_payload_function_id[9:3])
            `SET_BIAS: begin
              qnt_bias <= cmd_payload_inputs_0;
            end
            `SET_MUL_AND_SHIFT: begin
              qnt_mul <= cmd_payload_inputs_0;
              qnt_shift <= cmd_payload_inputs_1;
            end
            `SET_OFFSET: begin
              qnt_offset <= cmd_payload_inputs_0;
            end
            `SET_MIN_AND_MAX: begin
              qnt_min <= cmd_payload_inputs_0;
              qnt_max <= cmd_payload_inputs_1;
            end
            `GET: begin
              flag_qnt_start <= 1'b1;
              flag_qnt_pending <= 1'b1;
              rsp_valid <= 1'b0;
            end
          endcase
        end


      endcase
    end
  end
endmodule
module cfu_quantizer (
    input clk, rst,
    input signed [31:0] data_in,
    input signed [31:0] bias,
    input signed [31:0] mul,
    input signed [5:0] shift,
    input signed [31:0] offset,
    input signed [31:0] min,
    input signed [31:0] max,
    output signed [31:0] data_out,

    // Staging
    input start,
    output reg status
);
    // Regs
    reg signed [63:0] reg_ab_64;
    reg signed [31:0] reg_scaled_pre;
    reg stage;

    // Step 1: acc = data_in + bias
    wire signed [31:0] acc = data_in + bias;

    // Step 2: Calculate shift
    wire [5:0] left_shift = (shift > 0) ? shift : 6'h0;
    wire [5:0] right_shift = (shift > 0) ? 6'h0 : (-shift);
    wire signed [31:0] shifted = acc << left_shift;

    // Step 3: SaturatingRoundingDoublingHighMul
    wire signed [63:0] ab_64 = $signed(shifted) * $signed(mul);  // 64 bit sign-extend
    
    wire signed [63:0] nudge;
    assign nudge = (reg_ab_64 >= 0) ? (64'd1 << 30) : (64'd1 - (64'd1 << 30));
    
    wire signed [63:0] ab_rounded;
    assign ab_rounded = reg_ab_64 + nudge;

    // Match C semantics exactly:
    // scaled = (int32_t)((ab_64 + nudge) / (1ll << 31))
    // C signed division truncates toward zero.
    wire signed [63:0] scaled_floor_64 = (ab_rounded >>> 31);
    wire has_fractional_bits = |ab_rounded[30:0];
    wire signed [63:0] scaled_trunc_64 =
        (ab_rounded < 0 && has_fractional_bits) ? (scaled_floor_64 + 64'sd1) : scaled_floor_64;
    wire signed [31:0] scaled_raw = scaled_trunc_64[31:0];
    wire mul_overflow = (shifted == 32'sh80000000) && (mul == 32'sh80000000); // Handle overflow
    wire signed [31:0] scaled_pre = mul_overflow ? 32'sh7fffffff : scaled_raw;

    // Step 4: Rounding Division by power of 2
    wire signed [31:0] scaled;
    wire [31:0] mask = ((32'd1 << right_shift) - 1);
    wire [31:0] remainder = reg_scaled_pre & mask;
    wire [31:0] threshold = (mask >> 1) + reg_scaled_pre[31];
    
    assign scaled = (right_shift == 0) ? reg_scaled_pre : 
                    ((reg_scaled_pre >>> right_shift) + (remainder > threshold ? 1 : 0));

    // Step 5: Offset and clamping
    wire signed [31:0] with_offset = scaled + offset;
    
    assign data_out = (with_offset < min) ? min :
                      (with_offset > max) ? max :
                      with_offset;

    // Separate execution into 2 cycles (critical path)
    always @(posedge clk) begin
        status <= 1'd0;
        if (rst) begin
            reg_ab_64 <= 64'sd0;
            reg_scaled_pre <= 32'sd0;
            stage <= 1'b0;
        end else begin
            if (!stage) begin
                if (start) begin
                    reg_ab_64 <= ab_64;
                    stage <= 1'b1;
                end
            end else begin
                reg_scaled_pre <= scaled_pre;
                status <= 1'd1;
                stage <= 1'b0;
            end
        end
    end

endmodule
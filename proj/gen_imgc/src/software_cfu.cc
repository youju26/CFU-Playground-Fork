/*
 * Copyright 2021 The CFU-Playground Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdint.h>
#include "software_cfu.h"
#include "custom_cfu.h"

// <--- registers --->

// MAC
static int32_t reg_offset = 0;
static int32_t reg_acc    = 0;

// QNT
static int32_t reg_qnt_bias = 0;
static int32_t reg_qnt_mul = 0;
static int32_t reg_qnt_shift = 0;
static int32_t reg_qnt_offset = 0;
static int32_t reg_qnt_min = 0;
static int32_t reg_qnt_max = 0;

// Simple ring buffer (input buffer) - fixed size, no dynamic allocation
#define BUFFER_SIZE 256
#define FILTER_BANKS 64

static uint32_t buffer_input_data[BUFFER_SIZE];
static uint32_t buffer_count = 0;

static uint32_t filter_bank_data[FILTER_BANKS][BUFFER_SIZE];
static uint32_t filter_bank_count[FILTER_BANKS];
static uint32_t filter_bank_rd_ptr[FILTER_BANKS];
static uint32_t filter_bank_wr_idx = 0;
static uint32_t filter_bank_rd_idx = 0;

// Clear input buffer
static inline void input_buffer_clear() {
  buffer_count = 0;
}

// Clear all filter banks and reset indices
static inline void filter_banks_clear() {
  for (int b = 0; b < FILTER_BANKS; ++b) {
    filter_bank_count[b] = 0;
    filter_bank_rd_ptr[b] = 0;
  }
  filter_bank_wr_idx = 0;
  filter_bank_rd_idx = 0;
}

// Rewind all bank read pointers and restart reading from bank 0
static inline void filter_banks_rewind() {
  for (int b = 0; b < FILTER_BANKS; ++b) {
    filter_bank_rd_ptr[b] = 0;
  }
  filter_bank_rd_idx = 0;
}

// MAC4
static inline int32_t mac(uint32_t a, uint32_t b) {
  int32_t sum = 0;

  for (int i = 0; i < 4; i++) {
    int32_t ai = (int8_t)(a & 0xFF);   // sign-extend 8->32
    int32_t bi = (int8_t)(b & 0xFF);
    sum += ai * (bi + reg_offset);
    a >>= 8;
    b >>= 8;
  }

  return sum;
}

static inline int32_t quantize() {
  // Post-Processing of Conv-Acc (int32)
  // Goal: q_out = clamp( round( (acc + bias) * effective_scale ) + output_offset )

  int32_t acc = reg_acc + reg_qnt_bias;

  // The following code implements tflite::MultiplyByQuantizedMultiplier(acc, reg_qnt_mul, reg_qnt_shift)
  // Theory: acc_scaled ~ round( acc * effective_scale )
  // with effective_scale ~ (M / 2^31) * 2^shift

  // left and right shift
  // shift > 0 => multiply by 2^shift before the Q31 multiply (left_shift)
  // shift <= 0 => divide by 2^{-shift} after the Q31 multiply (right_shift)
  int left_shift = reg_qnt_shift > 0 ? reg_qnt_shift : 0;
  int right_shift = reg_qnt_shift > 0 ? 0 : -reg_qnt_shift;
  int32_t shifted = acc * (1 << left_shift);

  // Implementation of gemmlowp::SaturatingRoundingDoublingHighMul(shifted, reg_qnt_mul)
  // fixedpoint.h lines 327-339
  // Theory: scaled ~ round( (shifted * M) / 2^31 )
  // M is Q31: M ~ effective_scale * 2^31
  int32_t scaled;
  if (shifted == INT32_MIN && reg_qnt_mul == INT32_MIN) {
    // Overflow case: -1 * -1 should saturate to max
    scaled = INT32_MAX;
  } else {
    int64_t ab_64 = (int64_t)shifted * (int64_t)reg_qnt_mul;
    // Theory: rounding-to-nearest for division with 2^31
    int32_t nudge = ab_64 >= 0 ? (1 << 30) : (1 - (1 << 30));
    // Theory: scaled = round( ab_64 / 2^31 )
    scaled = (int32_t)((ab_64 + nudge) / (1ll << 31));
  }

  // Implementation of gemmlowp::RoundingDivideByPOT(scaled, right_shift)
  // fixedpoint.h lines 357-368
  // Theory: If shift was negative, division with 2^{right_shift}:
  // scaled = round( scaled / 2^{right_shift} )
  if (right_shift > 0) {
    int32_t mask = (1 << right_shift) - 1;
    int32_t remainder = scaled & mask;
    int32_t threshold = (mask >> 1) + (scaled < 0 ? 1 : 0);
    scaled = (scaled >> right_shift) + (remainder > threshold ? 1 : 0);
  }

  acc = scaled;

  // <-- End of MultiplyByQuantizedMultiplier

  acc += reg_qnt_offset;
  acc = (acc < reg_qnt_min) ? reg_qnt_min : acc;
  acc = (acc > reg_qnt_max) ? reg_qnt_max : acc;
  return acc;
}

static uint32_t alu_op(int funct7, uint32_t in0, uint32_t in1) {
  switch (funct7) {
    case 0:  // ADD
      return in0 + in1;
    case 1:  // SUB
      return in0 - in1;
    case 2:  // MUL
      return in0 * in1;
    default:
      return 0;
  }
}

static uint32_t mac_op(int funct7, uint32_t in0, uint32_t in1) {
  switch (funct7) {
    case 0: {  // MAC_ACC (legacy, not used)
      (void)in0;
      (void)in1;
      return 0;
    }
    case 1:{ // MAC_CLEAR
      reg_acc = 0;
      return reg_acc;
    }
    case 2:{ // MAC_SET_OFFSET
      reg_offset = (int32_t)in0;
      return reg_acc;
    }
    case 3: { // MAC_GET
      const uint32_t bank = filter_bank_rd_idx;

      if (buffer_count == 0 || filter_bank_count[bank] == 0) {
        // No buffers to process; advance to next bank
        filter_bank_rd_idx = (filter_bank_rd_idx + 1) % FILTER_BANKS;
        return 0;
      }

      // Compute: apply all available filter values to inputs
      uint32_t steps = buffer_count;
      const uint32_t bank_available = filter_bank_count[bank] - filter_bank_rd_ptr[bank];
      if (steps > bank_available) {
        steps = bank_available;
      }

      int32_t result = 0;
      for (uint32_t i = 0; i < steps; ++i) {
        const uint32_t input_val = buffer_input_data[i];
        const uint32_t filter_val = filter_bank_data[bank][filter_bank_rd_ptr[bank] + i];
        result += mac(filter_val, input_val);
      }

      filter_bank_rd_ptr[bank] += steps;
      filter_bank_rd_idx = (filter_bank_rd_idx + 1) % FILTER_BANKS;
      return (uint32_t)result;
    }
    case 4: { // MAC_SET_INPUT_VALS
      // Hardware uses buffer A for compute; keep software path aligned and store in0 only.
      if (buffer_count < BUFFER_SIZE) {
        buffer_input_data[buffer_count++] = in0;
      }
      return 0;
    }

    case 5: { // MAC_ON_BUFFER (legacy/deprecated)
      (void)in0;
      (void)in1;
      return 0;
    }

    case 6: { // MAC_CLEAR_INPUT_VALS
      input_buffer_clear();
      return 0;
    }

    case 7: { // MAC_SET_FILTER_VALS
      const uint32_t bank = filter_bank_wr_idx;
      if (filter_bank_count[bank] < BUFFER_SIZE) {
        filter_bank_data[bank][filter_bank_count[bank]++] = in0;
      }
      return 0;
    }

    case 8: { // MAC_NEXT_FILTER_SET
      if (filter_bank_wr_idx + 1 < FILTER_BANKS) {
        filter_bank_wr_idx++;
      }
      return 0;
    }

    case 9: { // MAC_CLEAR_FILTER_VALS
      filter_banks_clear(); // Reset all filter banks
      return 0;
    }

    case 10: { // MAC_REWIND_FILTER_SET
      filter_banks_rewind(); // Reset read pointers of all banks and start again at bank 0
      return 0;
    }

    default:
      return 0;
  }
}

static uint32_t qnt_op(int funct7, uint32_t in0, uint32_t in1) {
  switch (funct7) {
    case 0:  // SET_BIAS
      reg_qnt_bias = (int32_t)in0;
      return 0;
    case 1:  // SET_MUL_AND_SHIFT
      reg_qnt_mul = (int32_t)in0;
      reg_qnt_shift = (int32_t)in1;
      return 0;
    case 2: // SET_OFFSET
      reg_qnt_offset = (int32_t)in0;
      return 0;
    case 3: // SET_MIN_AND_MAX
      reg_qnt_min = (int32_t)in0;
      reg_qnt_max = (int32_t)in1;
      return 0;
    case 4: // GET
      return quantize();
    default:
      return 0;
  }
}

//
// In this function, place C code to emulate your CFU. You can switch between
// hardware and emulated CFU by setting the CFU_SOFTWARE_DEFINED DEFINE in
// the Makefile.
uint32_t software_cfu(int funct3, int funct7, uint32_t in0, uint32_t in1)
{
  switch (funct3) {
    case 0:  // MAC
      return mac_op(funct7, in0, in1);

    case 1: // QNT (Quantization)
      return qnt_op(funct7, in0, in1);

    case 7:  // ALU (test)
      return alu_op(funct7, in0, in1);

    default:
      return 0;
  }
}
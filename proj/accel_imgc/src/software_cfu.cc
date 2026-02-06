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
#include "imgc_cfu.h"

// registers
static int32_t reg_offset = 0;
static int32_t reg_acc    = 0;

// Simple ring buffer (input buffer) - fixed size, no dynamic allocation
#define BUFFER_SIZE 256
static uint32_t buffer_input_data[BUFFER_SIZE];
static uint32_t buffer_head = 0;
static uint32_t buffer_tail = 0;
static uint32_t buffer_count = 0;

// Clear the ring buffer, reset indices and count
static inline void buffer_clear() {
  buffer_head = 0;
  buffer_tail = 0;
  buffer_count = 0;
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
    case 0: {  // MAC_ACC
      int32_t v = mac(in0, in1);
      reg_acc += v;
      return reg_acc;
    }
    case 1:{ // MAC_CLEAR
      reg_acc = 0;
      return reg_acc;
    }
    case 2:{ // MAC_SET_OFFSET
      reg_offset = (int32_t)in0;
      return reg_acc;
    }
    case 3: { // MAC_SET_INPUT_VALS
      // Store input_vals in ring buffer
      if (buffer_count < BUFFER_SIZE) {
        buffer_input_data[buffer_tail] = in0;
        buffer_tail = (buffer_tail + 1) % BUFFER_SIZE;
        buffer_count++;
      }
      if (buffer_count < BUFFER_SIZE) {
        buffer_input_data[buffer_tail] = in1;
        buffer_tail = (buffer_tail + 1) % BUFFER_SIZE;
        buffer_count++;
      }
      return 0;
    }

    case 4: { // MAC_ON_BUFFER
      // Use filter_vals on input_vals in FiFo buffer
      // Re-append the value to keep it in the buffer for multiple filter sets
      if (buffer_count > 0) {
        uint32_t input_val = buffer_input_data[buffer_head];
        int32_t v = mac(in0, input_val);
        
        // Move to next position
        buffer_head = (buffer_head + 1) % BUFFER_SIZE;
        
        // Re-append the value at the tail
        // Count stays the same (removed from front, added to back)
        buffer_input_data[buffer_tail] = input_val;
        buffer_tail = (buffer_tail + 1) % BUFFER_SIZE;
        
        reg_acc += v;
      }
      if (buffer_count > 0) {
        uint32_t input_val = buffer_input_data[buffer_head];
        int32_t v = mac(in1, input_val);
        
        // Move to next position
        buffer_head = (buffer_head + 1) % BUFFER_SIZE;
        
        // Re-append the value at the tail
        // Count stays the same (removed from front, added to back)
        buffer_input_data[buffer_tail] = input_val;
        buffer_tail = (buffer_tail + 1) % BUFFER_SIZE;
        
        reg_acc += v;
      }
      return reg_acc;
    }

    case 5: { // MAC_CLEAR_INPUT_VALS
      buffer_clear();
      return 0;
    }

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

    case 7:  // ALU (test)
      return alu_op(funct7, in0, in1);

    default:
      return 0;
  }
}

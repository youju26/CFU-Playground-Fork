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
    case 1:  // MAC_CLEAR
      reg_acc = 0;
      return reg_acc;

    case 2:  // MAC_SET_OFFSET
      reg_offset = (int32_t)in0;
      return reg_acc;

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

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

static int32_t accumulator = 0;
static int32_t input_offset = 0;

//
// In this function, place C code to emulate your CFU. You can switch between
// hardware and emulated CFU by setting the CFU_SOFTWARE_DEFINED DEFINE in
// the Makefile.
uint32_t software_cfu(int funct3, int funct7, uint32_t rs1, uint32_t rs2)
{
  // funct3 is bits [2:0], funct7 is bits [9:3]
  switch (funct3) {
    case 0:  // Add
      return rs1 + rs2;
      
    case 1:  // Sub
      return rs1 - rs2;
      
    case 2:  // Mul
      return rs1 * rs2;
      
    case 3: {  // MAC for Convolution
      switch (funct7) {
        case 0: {  // MAC Accumulate
          // SIMD multiply step
          int8_t filter_0 = (int8_t)((rs1 >>  0) & 0xFF);
          int8_t filter_1 = (int8_t)((rs1 >>  8) & 0xFF);
          int8_t filter_2 = (int8_t)((rs1 >> 16) & 0xFF);
          int8_t filter_3 = (int8_t)((rs1 >> 24) & 0xFF);
          
          int8_t input_0 = (int8_t)((rs2 >>  0) & 0xFF);
          int8_t input_1 = (int8_t)((rs2 >>  8) & 0xFF);
          int8_t input_2 = (int8_t)((rs2 >> 16) & 0xFF);
          int8_t input_3 = (int8_t)((rs2 >> 24) & 0xFF);
          
          int32_t prod_0 = filter_0 * (input_0 + input_offset);
          int32_t prod_1 = filter_1 * (input_1 + input_offset);
          int32_t prod_2 = filter_2 * (input_2 + input_offset);
          int32_t prod_3 = filter_3 * (input_3 + input_offset);
          
          accumulator += (prod_0 + prod_1 + prod_2 + prod_3);
          return accumulator;
        }
        
        case 1:  // Reset accumulator
          accumulator = 0;
          return 0;
          
        case 2:  // Set input_offset
          input_offset = (int32_t)rs1;
          return 0;
          
        default:
          return 0;  // Not defined
      }
    }
    
    default:
      return 0;  // Not defined
  }
}

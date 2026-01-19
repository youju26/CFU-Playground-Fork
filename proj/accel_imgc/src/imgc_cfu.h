#ifndef IMGC_CFU_H
#define IMGC_CFU_H

#include "cfu.h"

#ifdef __cplusplus
extern "C" {
#endif

// <--- ALU ---> (for testing purposes)
#define CFU_ALU_ADD(in0, in1) cfu_op7(0, in0, in1)
#define CFU_ALU_SUB(in0, in1) cfu_op7(1, in0, in1)
#define CFU_ALU_MUL(in0, in1) cfu_op7(2, in0, in1)

// <--- MAC --->
#define CFU_MAC_ACC(in0, in1) cfu_op0(0, in0, in1)
#define CFU_MAC_CLEAR() cfu_op0(1, 0, 0)
#define CFU_MAC_SET_OFFSET(in0) cfu_op0(2, in0, 0)
#define CFU_MAC_SET_INPUT_VALS(in0) cfu_op0(3, in0, 0)  // Load input_vals into CFU FiFo buffer
#define CFU_MAC_ON_BUFFER(in0) cfu_op0(4, in0, 0)   // Apply filter_vals on the input_vals, which are saved in the CFU input_val FiFo
#define CFU_MAC_CLEAR_INPUT_VALS() cfu_op0(5, 0, 0) // Clear the input_val FiFo

#ifdef __cplusplus
}
#endif

#endif  // IMGC_CFU_H
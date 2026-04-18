#ifndef CUSTOM_CFU_H
#define CUSTOM_CFU_H

#include "cfu.h"

#ifdef __cplusplus
extern "C" {
#endif

// <--- MAC --->
#define CFU_MAC_ACC(in0, in1) cfu_op0(0, in0, in1)
#define CFU_MAC_CLEAR() cfu_op0(1, 0, 0)
#define CFU_MAC_SET_OFFSET(in0) cfu_op0(2, in0, 0)
#define CFU_MAC_GET() cfu_op0(3, 0, 0)
#define CFU_MAC_SET_INPUT_VALS(in0, in1) cfu_op0(4, in0, in1)  // Load input_vals into CFU FiFo buffer
#define CFU_MAC_ON_BUFFER(in0, in1) cfu_op0(5, in0, in1)       // Apply filter_vals on the input_vals, which are saved in the CFU input_val FiFo
#define CFU_MAC_CLEAR_INPUT_VALS() cfu_op0(6, 0, 0)     // Clear the input_val FiFo

// <--- QNT ---> (Quantization)
#define CFU_QNT_SET_BIAS(in0) cfu_op1(0, in0, 0)
#define CFU_QNT_SET_MUL_AND_SHIFT(in0, in1) cfu_op1(1, in0, in1)
#define CFU_QNT_SET_OFFSET(in0) cfu_op1(2, in0, 0)
#define CFU_QNT_SET_MIN_AND_MAX(in0, in1) cfu_op1(3, in0, in1)
#define CFU_QNT_GET() cfu_op1(4, 0, 0)

#ifdef __cplusplus
}
#endif

#endif  // CUSTOM_CFU_H
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

#ifdef __cplusplus
}
#endif

#endif  // CUSTOM_CFU_H
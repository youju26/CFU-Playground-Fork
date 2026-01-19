/* Copyright 2019 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#include "tensorflow/lite/kernels/internal/reference/integer_ops/imgc_conv.h"

#include "playground_util/print_params.h"
#include "perf.h"
#include "imgc_cfu.h"

#ifdef SHOW_CONV_PERF
#define PERF_START(n) perf_enable_counter(n)
#define PERF_END(n) perf_disable_counter(n)
#else
#define PERF_START(n)
#define PERF_END(n)
#endif


namespace tflite {
namespace reference_integer_ops {

// CFU accelerated Conv2D loop
// Fixed-point per-channel-quantization convolution reference kernel.
void CFUConvPerChannel(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int8_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_data, const RuntimeShape& bias_shape,
    const int32_t* bias_data, const RuntimeShape& output_shape,
    int8_t* output_data) {
  #ifdef SHOW_CONV_PARAMS
  print_conv_params(params, input_shape, filter_shape, output_shape);
  #endif
  // Get parameters.
  // Replace constant parameters with literal values for acceleration.
  const int32_t input_offset = 128;  // r = s(q - Z)
  const int stride_width = params.stride_width;
  const int stride_height = params.stride_height;
  const int pad_width = params.padding_values.width;
  const int pad_height = params.padding_values.height;
  const int32_t output_offset = params.output_offset;

  // Set min and max value of the output.
  const int32_t output_activation_min = -128;
  const int32_t output_activation_max = 127;

  // Consistency check.
  TFLITE_DCHECK_LE(output_activation_min, output_activation_max);
  TFLITE_DCHECK_EQ(input_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(filter_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(output_shape.DimensionsCount(), 4);
  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_depth = input_shape.Dims(3);
  const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
  if (bias_data) {
    TFLITE_DCHECK_EQ(bias_shape.FlatSize(), output_depth);
  }
  
  // Load input_offset into CFU
  CFU_MAC_SET_OFFSET(input_offset);

  // Check dimensions of the tensors.
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int filter_input_depth = filter_shape.Dims(3);
  TFLITE_DCHECK_EQ(input_depth % filter_input_depth, 0);
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);

  PERF_START(0);
  for (int batch = 0; batch < batches; ++batch) {
    for (int out_y = 0; out_y < output_height; ++out_y) {
      const int in_y_origin = (out_y * stride_height) - pad_height;
      for (int out_x = 0; out_x < output_width; ++out_x) {
        const int in_x_origin = (out_x * stride_width) - pad_width;

        // Load input_vals into FiFo buffer
        CFU_MAC_CLEAR_INPUT_VALS(); // Clear input vals from last iteration
        for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
            const int in_y = in_y_origin + filter_y;
            for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
              const int in_x = in_x_origin + filter_x;

              // Zero padding by omitting the areas outside the image.
              const bool is_point_inside_image =
                  (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                  (in_y < input_height);

              if (!is_point_inside_image) {
                continue;
              }
              // Loop unrolling and filling FiFo
              for (int in_channel = 0; in_channel < filter_input_depth; in_channel += 16) {
                // Offset: ((i0 * dims_data[1] + i1) * dims_data[2] + i2) * dims_data[3] + i3
                uint32_t input_val = *((uint32_t *)(input_data + Offset(input_shape, batch, in_y, in_x, in_channel)));
                CFU_MAC_SET_INPUT_VALS(input_val);          
                input_val = *((uint32_t *)(input_data + Offset(input_shape, batch, in_y, in_x, in_channel + 4)));               
                CFU_MAC_SET_INPUT_VALS(input_val);
                input_val = *((uint32_t *)(input_data + Offset(input_shape, batch, in_y, in_x, in_channel + 8)));
                CFU_MAC_SET_INPUT_VALS(input_val);
                input_val = *((uint32_t *)(input_data + Offset(input_shape, batch, in_y, in_x, in_channel + 12)));
                CFU_MAC_SET_INPUT_VALS(input_val);     
              }
            }
        }
  

        for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
          CFU_MAC_CLEAR();
          for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
            const int in_y = in_y_origin + filter_y;
            for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
              const int in_x = in_x_origin + filter_x;

              // Zero padding by omitting the areas outside the image.
              const bool is_point_inside_image =
                  (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                  (in_y < input_height);

              if (!is_point_inside_image) {
                continue;
              }

              // Loop unrolling and MAC4
              for (int in_channel = 0; in_channel < filter_input_depth; in_channel += 16) {
                // Offset: ((i0 * dims_data[1] + i1) * dims_data[2] + i2) * dims_data[3] + i3
                uint32_t filter_val = *((uint32_t *)(filter_data + Offset(filter_shape, out_channel, filter_y, filter_x, in_channel)));
                CFU_MAC_ON_BUFFER(filter_val);
                filter_val = *((uint32_t *)(filter_data + Offset(filter_shape, out_channel, filter_y, filter_x, in_channel + 4)));
                CFU_MAC_ON_BUFFER(filter_val);
                filter_val = *((uint32_t *)(filter_data + Offset(filter_shape, out_channel, filter_y, filter_x, in_channel + 8)));
                CFU_MAC_ON_BUFFER(filter_val);
                filter_val = *((uint32_t *)(filter_data + Offset(filter_shape, out_channel, filter_y, filter_x, in_channel + 12)));
                CFU_MAC_ON_BUFFER(filter_val);
              }
            }
          }

          int32_t acc = CFU_MAC_ACC(0, 0);

          if (bias_data) {
            acc += bias_data[out_channel];
          }
          acc = MultiplyByQuantizedMultiplier(
              acc, output_multiplier[out_channel], output_shift[out_channel]);
          acc += output_offset;
          acc = std::max(acc, output_activation_min);
          acc = std::min(acc, output_activation_max);
          output_data[Offset(output_shape, batch, out_y, out_x, out_channel)] =
              static_cast<int8_t>(acc);
        }
      }
    }
  }
  PERF_END(0);

}   
}   // namespace reference_integer_ops
}   // namespace tflite
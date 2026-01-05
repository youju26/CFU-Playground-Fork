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

#include "models/mcunet/vww/mcunet_vww.h"

#include <stdio.h>

#include "menu.h"
#include "models/mcunet/vww/test_data/person.h"
#include "models/mcunet/vww/test_data/no_person.h"
#include "tflite.h"
#include "models/mcunet/vww/model_mcunet_vww.h"

#define NUM_GOLDEN 2

struct {
  const unsigned char* data;
  int32_t actual;
} mlcommons_tiny_v01_vww_dataset[NUM_GOLDEN] = {
    {person, 165},
    {no_person, -9},
};

static void vww_init(void) {
  tflite_load_model(model_mcunet_vww, model_mcunet_vww_len);
}

int32_t mcunet_vww_classify() {
  printf("Running vww\n");
  tflite_classify();

  int8_t* output = tflite_get_output();
  return (int32_t)output[1] - output[0];
}

#define MLCOMMONS_TINY_V01_VWW_TEST(name, test_index)                  \
  static void name() {                                                 \
    puts(#name);                                                       \
    tflite_set_input(mlcommons_tiny_v01_vww_dataset[test_index].data); \
    printf("  result-- score: %ld\n", mcunet_vww_classify());                 \
  }

MLCOMMONS_TINY_V01_VWW_TEST(do_classify_no_person, 5);
MLCOMMONS_TINY_V01_VWW_TEST(do_classify_person, 4);

#undef MLCOMMONS_TINY_V01_VWW_TEST

static void do_golden_tests() {
  bool failed = false;
  for (size_t i = 0; i < NUM_GOLDEN; i++) {
    tflite_set_input(mlcommons_tiny_v01_vww_dataset[i].data);
    int32_t res = mcunet_vww_classify();
    int32_t exp = mlcommons_tiny_v01_vww_dataset[i].actual;
    if (res != exp) {
      failed = true;
      printf("*** Golden test %d failed: \n", i);
      printf("actual-- score: %ld\n", res);
      printf("expected-- score: %ld\n", exp);
    }
  }

  if (failed) {
    puts("FAIL Golden tests failed");
  } else {
    puts("OK   Golden tests passed");
  }
}

static struct Menu MENU = {
    "Tests for MCUNet vww model",
    "MCUNet vww",
    {
        MENU_ITEM('0', "Run with no person input", do_classify_no_person),
        MENU_ITEM('1', "Run with person input", do_classify_person),
        MENU_ITEM('g', "Run golden tests (check for expected outputs)",
                  do_golden_tests),
        MENU_END,
    },
};

// For integration into menu system
void mcunet_vww_menu() {
  vww_init();
  menu_run(&MENU);
}

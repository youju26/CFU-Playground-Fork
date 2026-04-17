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

#include "proj_menu.h"

#include <stdio.h>
#include <stdint.h>

#include "cfu.h"
#include "custom_cfu.h"
#include "menu.h"

namespace {

// ============== Helper Functions ==============

// Extract 8-bit signed value at byte position i from 32-bit word
static int8_t lane(uint32_t x, int i) {
  return (int8_t)((x >> (8 * i)) & 0xFF);
}

// Pretty-print 32-bit word as 4 signed 8-bit lanes
static void print_lanes(const char* name, uint32_t x) {
  printf("%s=[%4d %4d %4d %4d] (0x%08lx)",
         name,
         (int)lane(x, 0), (int)lane(x, 1), (int)lane(x, 2), (int)lane(x, 3),
         (unsigned long)x);
}

// ============== CFU Status Check ==============

void do_test_cfu_status(void) {
  puts("\n========== CFU Implementation Status ==========\n");
  
  printf("Testing CFU infrastructure:\n\n");
  
  // Test 1: MAC_CLEAR
  printf("Test 1: CFU_MAC_CLEAR()\n");
  CFU_MAC_CLEAR();
  printf("  Status: OK - no error\n\n");
  
  // Test 2: MAC_SET_OFFSET
  printf("Test 2: CFU_MAC_SET_OFFSET(offset)\n");
  CFU_MAC_SET_OFFSET(2);
  printf("  Status: OK - offset set to 2\n\n");
  
  // Test 3: Set input values
  printf("Test 3: CFU_MAC_SET_INPUT_VALS(in0, in1)\n");
  uint32_t test_val_0 = 0x01020304;
  uint32_t test_val_1 = 0x05060708;
  CFU_MAC_SET_INPUT_VALS(test_val_0, test_val_1);
  printf("  Loaded input_0=0x%08lx ", (unsigned long)test_val_0);
  print_lanes("", test_val_0);
  printf("\n");
  printf("         input_1=0x%08lx ", (unsigned long)test_val_1);
  print_lanes("", test_val_1);
  printf("\n  Status: OK\n\n");
  
  // Test 4: Clear input values
  printf("Test 4: CFU_MAC_CLEAR_INPUT_VALS()\n");
  CFU_MAC_CLEAR_INPUT_VALS();
  printf("  Status: OK - input buffers cleared\n\n");
  
  puts("========== Filter Buffer Tests ==========\n");
}

// ============== Filter Buffer Tests ==============

static void test_filter_buffer_basic(void) {
  puts("\n========== Filter Buffer Basic Tests ==========\n");
  
  // Test: Load filter values, read them back via MAC computation
  printf("Test 1: Load filter values into buffer\n");
  
  CFU_MAC_CLEAR_FILTER_VALS();
  
  // Load some filter values (4 packed 8-bit values per call)
  uint32_t filter_val_1 = 0x01020304;  // [4, 3, 2, 1]
  uint32_t filter_val_2 = 0x05060708;  // [8, 7, 6, 5]
  uint32_t filter_val_3 = 0xFCFDFEFF;  // [-1, -2, -3, -4]
  
  printf("  Loading filter_val_1=0x%08lx ", (unsigned long)filter_val_1);
  print_lanes("", filter_val_1);
  printf("\n");
  CFU_MAC_SET_FILTER_VALS(filter_val_1);
  
  printf("  Loading filter_val_2=0x%08lx ", (unsigned long)filter_val_2);
  print_lanes("", filter_val_2);
  printf("\n");
  CFU_MAC_SET_FILTER_VALS(filter_val_2);
  
  printf("  Loading filter_val_3=0x%08lx ", (unsigned long)filter_val_3);
  print_lanes("", filter_val_3);
  printf("\n");
  CFU_MAC_SET_FILTER_VALS(filter_val_3);
  
  printf("  Filter values loaded successfully.\n");
  printf("  Next: User can call CFU_MAC_NEXT_FILTER_SET() to move to next bank.\n\n");
}

static void test_filter_rewind(void) {
  puts("Test 2: Filter set rewind\n");
  
  // Load multiple filter sets
  printf("  Loading filter set 1...\n");
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x01010101);
  CFU_MAC_SET_FILTER_VALS(0x02020202);
  CFU_MAC_NEXT_FILTER_SET();
  
  printf("  Loading filter set 2...\n");
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x03030303);
  CFU_MAC_SET_FILTER_VALS(0x04040404);
  CFU_MAC_NEXT_FILTER_SET();
  
  printf("  Rewinding filter pointer to start...\n");
  CFU_MAC_REWIND_FILTER_SET();
  
  printf("  Filter pointer reset. Can now re-read first filter set.\n\n");
}

static void test_input_buffer_basic(void) {
  puts("Test 3: Input buffer with filter computation\n");
  
  // Clear everything
  CFU_MAC_CLEAR();
  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_CLEAR_FILTER_VALS();
  
  // Load input values
  printf("  Loading input values...\n");
  uint32_t input_1 = 0x02020202;
  uint32_t input_2 = 0x03030303;
  
  printf("    input_1=0x%08lx ", (unsigned long)input_1);
  print_lanes("", input_1);
  printf("\n");
  CFU_MAC_SET_INPUT_VALS(input_1, 0);
  
  printf("    input_2=0x%08lx ", (unsigned long)input_2);
  print_lanes("", input_2);
  printf("\n");
  CFU_MAC_SET_INPUT_VALS(input_2, 0);
  
  // Load filter values
  printf("  Loading filter values...\n");
  uint32_t filter_1 = 0x01010101;
  
  printf("    filter_1=0x%08lx ", (unsigned long)filter_1);
  print_lanes("", filter_1);
  printf("\n");
  CFU_MAC_SET_FILTER_VALS(filter_1);
  
  printf("  Input and filter buffers loaded.\n");
  printf("  In actual convolution: CFU_MAC_GET() would process these values.\n\n");
}

void do_test_filter_buffer(void) {
  puts("\n========== Filter Buffer & Input Management Tests ==========\n");
  
  test_filter_buffer_basic();
  test_filter_rewind();
  test_input_buffer_basic();
  
  printf("Filter buffer test sequence completed.\n");
  printf("NOTE: These are functional checks; actual compute is verified via MAC_GET in conv.h\n\n");
}

// ============== Diagnostic Tests ==============

static void test_mac_direct_computation(void) {
  puts("\n========== Direct MAC Computation Test ==========\n");
  
  // Test: Load input and filter via buffers, then get result
  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(0);
  
  // Load some inputs: 4 lanes of value 2
  printf("Loading input values: 0x02020202 [2, 2, 2, 2]\n");
  CFU_MAC_SET_INPUT_VALS(0x02020202, 0);
  
  // Load filter values: 4 lanes of value 3
  printf("Loading filter values: 0x03030303 [3, 3, 3, 3]\n");
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x03030303);
  
  // Try to get result (this uses internal compute)
  printf("Calling CFU_MAC_GET()...\n");
  int mac_result = CFU_MAC_GET();
  
  // Expected: 4 * (2 * 3) = 24
  printf("Result: %d (expected ~24 if computed, or 0 if not yet)\n", mac_result);
  printf("(Note: MAC_GET accumulates and may need multiple cycles)\n\n");
}

static void test_buffer_persistence(void) {
  puts("\n========== Buffer Persistence Test ==========\n");
  
  // Test: Load multiple items, verify they persist
  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_CLEAR_FILTER_VALS();
  
  printf("Round 1: Loading 3 input values\n");
  CFU_MAC_SET_INPUT_VALS(0x01010101, 0);
  CFU_MAC_SET_INPUT_VALS(0x02020202, 0);
  CFU_MAC_SET_INPUT_VALS(0x03030303, 0);
  puts("  3 values loaded\n");
  
  printf("Round 2: Loading 3 filter values to bank 0\n");
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x10101010);
  CFU_MAC_SET_FILTER_VALS(0x20202020);
  CFU_MAC_SET_FILTER_VALS(0x30303030);
  puts("  3 values loaded\n");
  
  printf("Round 3: Moving to filter bank 1\n");
  CFU_MAC_NEXT_FILTER_SET();
  
  printf("Round 4: Loading 3 filter values to bank 1\n");
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x11111111);
  CFU_MAC_SET_FILTER_VALS(0x22222222);
  CFU_MAC_SET_FILTER_VALS(0x33333333);
  puts("  3 values loaded\n");
  
  printf("Round 5: Rewinding to bank 0\n");
  CFU_MAC_REWIND_FILTER_SET();
  puts("  Rewind complete - bank 0 should be readable again\n\n");
}

static void test_offset_effect(void) {
  puts("\n========== MAC Offset Effect Test ==========\n");

  // Test with different offsets from a clean state each time.
  printf("Test 1: offset = 0\n");
  CFU_MAC_CLEAR();
  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_SET_OFFSET(0);
  CFU_MAC_SET_INPUT_VALS(0x05050505, 0);
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x02020202);
  int r1 = CFU_MAC_GET();  // (5+0)*2 = 10 per lane, 4 lanes = 40
  printf("  Result: %d (expected ~40)\n\n", r1);
  
  CFU_MAC_CLEAR();
  CFU_MAC_CLEAR_INPUT_VALS();
  
  printf("Test 2: offset = 1\n");
  CFU_MAC_SET_OFFSET(1);
  CFU_MAC_SET_INPUT_VALS(0x05050505, 0);
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x02020202);
  int r2 = CFU_MAC_GET();  // (5+1)*2 = 12 per lane, 4 lanes = 48
  printf("  Result: %d (expected ~48)\n\n", r2);
  
  CFU_MAC_CLEAR();
  CFU_MAC_CLEAR_INPUT_VALS();
  
  printf("Test 3: offset = -1\n");
  CFU_MAC_SET_OFFSET(-1);
  CFU_MAC_SET_INPUT_VALS(0x05050505, 0);
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x02020202);
  int r3 = CFU_MAC_GET();  // (5-1)*2 = 8 per lane, 4 lanes = 32
  printf("  Result: %d (expected ~32)\n\n", r3);
}

static void test_sequential_loads(void) {
  puts("\n========== Sequential Load Test ==========\n");

  struct Case {
    const char* name;
    int32_t offset;
    uint32_t input;
    uint32_t filter;
    int expected;
  } cases[] = {
      {"run 1", 0, 0x01010101, 0x02020202, 8},
      {"run 2", 0, 0x01010101, 0x02020202, 8},
      {"run 3", 1, 0x05050505, 0x02020202, 48},
      {"run 4", -1, 0x05050505, 0x02020202, 32},
  };

  for (unsigned int i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
    CFU_MAC_CLEAR();
    CFU_MAC_CLEAR_INPUT_VALS();
    CFU_MAC_CLEAR_FILTER_VALS();

    CFU_MAC_SET_OFFSET(cases[i].offset);
    CFU_MAC_SET_INPUT_VALS(cases[i].input, 0);
    CFU_MAC_SET_FILTER_VALS(cases[i].filter);

    int seq_result = CFU_MAC_GET();

    printf("%-8s off=%4ld input=0x%08lx filter=0x%08lx => got=%4d exp=%4d %s\n",
           cases[i].name,
           (long)cases[i].offset,
           (unsigned long)cases[i].input,
           (unsigned long)cases[i].filter,
           seq_result,
           cases[i].expected,
           (seq_result == cases[i].expected) ? "OK" : "FAIL");
  }

  puts("");
}

static int32_t expected_packed_dot(uint32_t input_word, uint32_t filter_word,
                                   int32_t offset) {
  int32_t total = 0;
  for (int lane_index = 0; lane_index < 4; ++lane_index) {
    const int32_t input_lane = lane(input_word, lane_index) + offset;
    const int32_t filter_lane = lane(filter_word, lane_index);
    total += input_lane * filter_lane;
  }
  return total;
}

static void test_conv_like_two_bank_sequence(void) {
  puts("\n========== Conv-Like Two-Bank Sequence ==========\n");

  const int32_t offset = 0;
  const uint32_t input_words[] = {0x05050505, 0x06060606};
  const uint32_t bank0_words[] = {0x01010101, 0x02020202};
  const uint32_t bank1_words[] = {0x03030303, 0x04040404};

  const int32_t expected_bank0 =
      expected_packed_dot(input_words[0], bank0_words[0], offset) +
      expected_packed_dot(input_words[1], bank0_words[1], offset);
  const int32_t expected_bank1 =
      expected_packed_dot(input_words[0], bank1_words[0], offset) +
      expected_packed_dot(input_words[1], bank1_words[1], offset);

  CFU_MAC_CLEAR();
  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_OFFSET(offset);

  puts("Loading bank 0 filters (like conv.h output channel 0)...");
  CFU_MAC_SET_FILTER_VALS(bank0_words[0]);
  CFU_MAC_SET_FILTER_VALS(bank0_words[1]);
  CFU_MAC_NEXT_FILTER_SET();

  puts("Loading bank 1 filters (like conv.h output channel 1)...");
  CFU_MAC_SET_FILTER_VALS(bank1_words[0]);
  CFU_MAC_SET_FILTER_VALS(bank1_words[1]);
  CFU_MAC_NEXT_FILTER_SET();

  puts("Rewinding filters before output pass...");
  CFU_MAC_REWIND_FILTER_SET();

  puts("Loading input stream (like conv.h per-output-pixel input fill)...");
  CFU_MAC_SET_INPUT_VALS(input_words[0], 0);
  CFU_MAC_SET_INPUT_VALS(input_words[1], 0);

  puts("Computing bank 0...");
  const int32_t got_bank0 = CFU_MAC_GET();
    printf("  bank0 got=%ld exp=%ld %s\n",
      (long)got_bank0, (long)expected_bank0,
         (got_bank0 == expected_bank0) ? "OK" : "FAIL");

  puts("Computing bank 1...");
  const int32_t got_bank1 = CFU_MAC_GET();
    printf("  bank1 got=%ld exp=%ld %s\n",
      (long)got_bank1, (long)expected_bank1,
         (got_bank1 == expected_bank1) ? "OK" : "FAIL");

  puts("");
}

static void test_buffer_clearing(void) {
  puts("\n========== Buffer Clearing Test ==========\n");
  
  printf("Step 1: Load input and filter values\n");
  CFU_MAC_SET_INPUT_VALS(0xABCDEF00, 0);
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x12345678);
  puts("  Data loaded\n\n");
  
  printf("Step 2: Clear input buffers\n");
  CFU_MAC_CLEAR_INPUT_VALS();
  puts("  Input buffers cleared\n\n");
  
  printf("Step 3: Clear filter buffers and reset indices\n");
  CFU_MAC_CLEAR_FILTER_VALS();
  puts("  Filter buffers cleared and indices reset\n\n");
  
  printf("Step 4: Load new values (should start fresh)\n");
  CFU_MAC_SET_INPUT_VALS(0x11111111, 0);
  CFU_MAC_CLEAR_FILTER_VALS();
  CFU_MAC_SET_FILTER_VALS(0x22222222);
  puts("  New data loaded (should be independent of old data)\n\n");
}

void do_diagnostic_tests(void) {
  puts("\n========== CFU Diagnostic Tests ==========\n");
  
  test_mac_direct_computation();
  test_sequential_loads();
  test_conv_like_two_bank_sequence();
  test_buffer_persistence();
  test_offset_effect();
  test_buffer_clearing();
  
  printf("Diagnostic tests completed.\n\n");
}

void do_test_filter_load_only(void) {
  puts("\n=== FILTER LOAD ONLY TEST ===\n");

  CFU_MAC_CLEAR_FILTER_VALS();

  uint32_t f = 0x04030201;

  CFU_MAC_SET_FILTER_VALS(f);

  // Dummy Input, damit MAC_GET überhaupt was macht
  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_SET_INPUT_VALS(0x01010101, 0);

  CFU_MAC_REWIND_FILTER_SET();
  CFU_MAC_CLEAR();

  int r = CFU_MAC_GET();

  printf("Result = %d (expected 10)\n", r);

  if (r != 10) {
    puts("*** FAIL: Filter wird falsch geladen oder gelesen!");
  } else {
    puts("OK");
  }
}

void do_test_filter_fifo_order(void) {
  puts("\n=== FILTER FIFO ORDER TEST ===\n");

  CFU_MAC_CLEAR_FILTER_VALS();

  // zwei 32-bit words
  CFU_MAC_SET_FILTER_VALS(0x01010101); // sum = 4
  CFU_MAC_SET_FILTER_VALS(0x02020202); // sum = 8

  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_SET_INPUT_VALS(0x01010101, 0);
  CFU_MAC_SET_INPUT_VALS(0x01010101, 0);

  CFU_MAC_REWIND_FILTER_SET();
  CFU_MAC_CLEAR();

  int r = CFU_MAC_GET();

  printf("Result = %d (expected 12)\n", r);

  if (r != 12) {
    puts("*** FAIL: Reihenfolge im Filter FIFO falsch!");
  } else {
    puts("OK");
  }
}

void do_test_filter_mutation(void) {
  puts("\n=== FILTER MUTATION TEST ===\n");

  CFU_MAC_CLEAR_FILTER_VALS();

  CFU_MAC_SET_FILTER_VALS(0x04030201);

  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_SET_INPUT_VALS(0x01010101, 0);

  for (int i = 0; i < 5; i++) {
    CFU_MAC_REWIND_FILTER_SET();
    CFU_MAC_CLEAR();

    int r = CFU_MAC_GET();
    printf("Run %d -> %d\n", i, r);
  }

  puts("Wenn Werte sich ändern → Filter wird überschrieben!");
}

void do_test_lane_alignment(void) {
  puts("\n=== LANE ALIGNMENT TEST ===\n");

  CFU_MAC_CLEAR_FILTER_VALS();

  // Filter: [1 0 0 0]
  CFU_MAC_SET_FILTER_VALS(0x00000001);

  CFU_MAC_CLEAR_INPUT_VALS();

  // Input: [5 6 7 8]
  CFU_MAC_SET_INPUT_VALS(0x08070605, 0);

  CFU_MAC_REWIND_FILTER_SET();
  CFU_MAC_CLEAR();

  int r = CFU_MAC_GET();

  printf("Result = %d (expected 5)\n", r);

  if (r != 5) {
    puts("*** FAIL: Lane-Reihenfolge falsch!");
  } else {
    puts("OK");
  }
}

void do_test_offset(void) {
  puts("\n=== OFFSET TEST ===\n");

  CFU_MAC_CLEAR_FILTER_VALS();

  CFU_MAC_SET_FILTER_VALS(0x01010101);

  CFU_MAC_CLEAR_INPUT_VALS();
  CFU_MAC_SET_INPUT_VALS(0x01010101, 0);

  CFU_MAC_SET_OFFSET(-1);

  CFU_MAC_REWIND_FILTER_SET();
  CFU_MAC_CLEAR();

  int r = CFU_MAC_GET();

  // Erwartung: (1-1)*1 * 4 = 0
  printf("Result = %d (expected 0)\n", r);

  if (r != 0) {
    puts("*** FAIL: Offset wird falsch angewendet!");
  } else {
    puts("OK");
  }
}

// ============== Hello World ==============

void do_hello_world(void) { 
  puts("\nHello from gen_imgc CFU!\n"); 
}

// ============== Menu Structure ==============

struct Menu MENU = {
    "Project Menu - gen_imgc CFU Tests",
    "project",
    {
        MENU_ITEM('0', "CFU status check", do_test_cfu_status),
        MENU_ITEM('1', "run filter buffer tests", do_test_filter_buffer),
        MENU_ITEM('2', "run diagnostic tests", do_diagnostic_tests),
        MENU_ITEM('3', "test filter load", do_test_filter_load_only),
        MENU_ITEM('4', "test filter fifo order", do_test_filter_fifo_order),
        MENU_ITEM('5', "test filter mutation", do_test_filter_mutation),
        MENU_ITEM('6', "test lane alignment", do_test_lane_alignment),
        MENU_ITEM('7', "test offset", do_test_offset),
        MENU_ITEM('h', "say Hello", do_hello_world),
        MENU_END,
    },
};

};  // namespace

extern "C" void do_proj_menu() { menu_run(&MENU); }

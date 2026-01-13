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

#include "cfu.h"
#include "menu.h"
#include "imgc_cfu.h"

namespace {

// Template Fn

void do_hello_world(void) { puts("Hello, World!!!\n"); }

void do_test_alu(void) {
  puts("\n=== ALU test ===\n");

  for (int a = -3; a <= 3; a++) {
    for (int b = -3; b <= 3; b++) {
      int add = CFU_ALU_ADD(a, b);
      int sub = CFU_ALU_SUB(a, b);
      int mul = CFU_ALU_MUL(a, b);

      if (add != a + b || sub != a - b || mul != a * b) {
        printf("*** ALU FAIL a=%d b=%d\n", a, b);
        return;
      }
    }
  }

  puts("ALU TESTS OK");
}

static bool check_mac(const char* name, int got, int expected) {
  printf("%s: got=%d expected=%d\n", name, got, expected);
  if (got != expected) {
    puts("*** FAIL");
    return false;
  }
  return true;
}

void do_test_mac(void) {
  puts("\n=== MAC test suite ===\n");

  // ------------------------------------------------------------
  // Test 1: simple
  // ------------------------------------------------------------
  puts("[1] simple MAC");

  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(0);

  {
    uint32_t a = 0x01010101;
    uint32_t b = 0x02020202;
    int mac_res = CFU_MAC_ACC(a, b);
    if (!check_mac("simple", mac_res, 8)) return;
  }

  // ------------------------------------------------------------
  // Test 2: accumulate + offset
  // ------------------------------------------------------------
  puts("\n[2] accumulate + offset");

  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(1);

  {
    uint32_t a = 0x01010101;
    uint32_t b = 0x01010101;

    int r1 = CFU_MAC_ACC(a, b);
    int r2 = CFU_MAC_ACC(a, b);

    if (!check_mac("acc 1", r1, 8)) return;
    if (!check_mac("acc 2", r2, 16)) return;
  }

  // ------------------------------------------------------------
  // Test 3: negative values
  // ------------------------------------------------------------
  puts("\n[3] negative values");

  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(0);

  {
    uint32_t a = 0xFCFDFEFF;  // [-1,-2,-3,-4]
    uint32_t b = 0x04030201;  // [ 1, 2, 3, 4]
    int mac_res = CFU_MAC_ACC(a, b);
    if (!check_mac("negative", mac_res, -30)) return;
  }

  // ------------------------------------------------------------
  // Test 4: negative offset
  // ------------------------------------------------------------
  puts("\n[4] negative offset");

  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(-1);

  {
    uint32_t a = 0x01010101;
    uint32_t b = 0x01010101;
    int mac_res = CFU_MAC_ACC(a, b);
    if (!check_mac("neg offset", mac_res, 0)) return;
  }

  puts("\nMAC TESTS OK");
}

struct Menu MENU = {
    "Project Menu",
    "project",
    {
        MENU_ITEM('0', "run ALU tests", do_test_alu),
        MENU_ITEM('1', "run MAC tests", do_test_mac),
        MENU_ITEM('h', "say Hello", do_hello_world),
        MENU_END,
    },
};

};  // anonymous namespace

extern "C" void do_proj_menu() { menu_run(&MENU); }

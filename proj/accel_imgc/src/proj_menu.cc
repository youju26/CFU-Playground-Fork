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

static int8_t lane(uint32_t x, int i) {
  return (int8_t)((x >> (8 * i)) & 0xFF);
}

static void print_lanes(const char* name, uint32_t x) {
  printf("%s=[%4d %4d %4d %4d] (0x%08lx)",
         name,
         (int)lane(x, 0), (int)lane(x, 1), (int)lane(x, 2), (int)lane(x, 3),
         (unsigned long)x);
}

static bool run_mac_case(const char* name,
                         int32_t offset,
                         uint32_t a, uint32_t b,
                         int expected) {
  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(offset);

  int got = CFU_MAC_ACC(a, b);

  printf("%-14s off=%4ld | ", name, (long)offset);
  print_lanes("a", a);
  printf("  ");
  print_lanes("b", b);
  printf("  => got=%4d exp=%4d %s\n",
         got, expected, (got == expected) ? "OK" : "FAIL");

  return got == expected;
}

static bool run_mac_acc2_case(const char* name,
                              int32_t offset,
                              uint32_t a, uint32_t b,
                              int exp1, int exp2) {
  CFU_MAC_CLEAR();
  CFU_MAC_SET_OFFSET(offset);

  int r1 = CFU_MAC_ACC(a, b);
  int r2 = CFU_MAC_ACC(a, b);

  printf("%-14s off=%4ld | ", name, (long)offset);
  print_lanes("a", a);
  printf("  ");
  print_lanes("b", b);
  printf("  => r1=%4d exp=%4d  r2=%4d exp=%4d %s\n",
         r1, exp1, r2, exp2, (r1 == exp1 && r2 == exp2) ? "OK" : "FAIL");

  return (r1 == exp1 && r2 == exp2);
}

void do_test_mac(void) {
  puts("\n=== MAC tests (quick view) ===\n");
  puts("name           offset | a lanes               b lanes               => result\n");
  puts("-----------------------------------------------------------------------------------------");

  // [1] simple
  if (!run_mac_case("simple", 0, 0x01010101, 0x02020202, 8)) return;

  // [2] accumulate + offset (two calls)
  if (!run_mac_acc2_case("acc+offset", 1, 0x01010101, 0x01010101, 8, 16)) return;

  // [3] negative values
  if (!run_mac_case("negative", 0, 0xFCFDFEFF, 0x04030201, -30)) return;

  // [4] negative offset
  if (!run_mac_case("neg offset", -1, 0x01010101, 0x01010101, 0)) return;

  puts("-----------------------------------------------------------------------------------------");
  puts("MAC TESTS OK");
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

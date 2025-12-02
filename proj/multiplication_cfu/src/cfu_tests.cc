#include <stdio.h>
#include <stdint.h>
#include "cfu.h"

// Enable this in Makefile
#ifdef ENABLE_CFU_TESTS

// Forward declaration
void reset_acc(void);

// Global counter for total test results
static int g_total_tests_passed = 0;

// Run int32_t multiplication tests
int run_int32_tests(void) {
  puts("Testing CFU behavior with int32_t:\n");

  int passed = 0;
  int total = 0;

  // Test 1: Small positive values
  puts("[Test 1] Small positive values:");
  int32_t a = 6;
  int32_t b = 7;
  int32_t cfu_result = (int32_t)cfu_op3(0, a, b);
  int32_t expected_val = 6 * 7;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 2: Medium positive values
  puts("[Test 2] Medium positive values:");
  a = 100;
  b = 50;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = 100 * 50;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 3: Positive * zero
  puts("[Test 3] Positive * zero:");
  a = 123;
  b = 0;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = 123 * 0;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 4: Negative * positive
  puts("[Test 4] Negative * positive:");
  a = -5;
  b = 10;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -5 * 10;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 5: Negative * negative
  puts("[Test 5] Negative * negative:");
  a = -6;
  b = -7;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -6 * -7;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 6: Larger negative values
  puts("[Test 6] Larger negative values:");
  a = -100;
  b = -50;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -100 * -50;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 7: One negative, one large positive
  puts("[Test 7] One negative, one large positive:");
  a = -8;
  b = 1000;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -8 * 1000;
  printf("  %ld * %ld = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  printf("\nint32_t Results: %d / %d tests passed\n", passed, total);
  g_total_tests_passed += passed;
  return passed;
}

// Run int8_t multiplication tests
int run_int8_tests(void) {
  puts("\nTesting CFU behavior with int8_t:\n");

  int passed = 0;
  int total = 0;

  // Test 1: Small positive values
  puts("[Test 1] Small positive values:");
  int8_t a = 6;
  int8_t b = 7;
  int32_t cfu_result = (int32_t)cfu_op3(0, a, b);
  int32_t expected_val = 6 * 7;
  printf("  %d * %d = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 2: Maximum int8_t positive
  puts("[Test 2] Maximum int8_t positive:");
  a = 127;
  b = 2;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = 127 * 2;
  printf("  %d * %d = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 3: Small * zero
  puts("[Test 3] Small * zero:");
  a = 42;
  b = 0;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = 42 * 0;
  printf("  %d * %d = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 4: Negative * positive (int8_t)
  puts("[Test 4] Negative * positive (int8_t):");
  a = -5;
  b = 10;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -5 * 10;
  printf("  %d * %d = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 5: Minimum int8_t negative
  puts("[Test 5] Minimum int8_t negative:");
  a = -128;
  b = 1;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -128 * 1;
  printf("  %d * %d = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  // Test 6: Negative * negative (int8_t)
  puts("[Test 6] Negative * negative (int8_t):");
  a = -6;
  b = -7;
  cfu_result = (int32_t)cfu_op3(0, a, b);
  expected_val = -6 * -7;
  printf("  %d * %d = %ld (expected %ld) %s\n", a, b, cfu_result, expected_val, cfu_result == expected_val ? "PASS" : "FAIL");
  if (cfu_result == expected_val) { passed++; }
  total++;
  reset_acc();

  printf("\nint8_t Results: %d / %d tests passed\n", passed, total);
  g_total_tests_passed += passed;
  return passed;
}

// Run all CFU tests and print results
void run_all_cfu_tests(void) {
  puts("TESTING: \n");
  puts("=======================================\n");

  run_int32_tests();
  run_int8_tests();

  printf("\n=======================================\n");
  printf("TOTAL: %d tests passed\n", g_total_tests_passed);
  printf("=======================================\n\n");
  
  // Reset counter for next run
  g_total_tests_passed = 0;
}

#endif  // ENABLE_CFU_TESTS

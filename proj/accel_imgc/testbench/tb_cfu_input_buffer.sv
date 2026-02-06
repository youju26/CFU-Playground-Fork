`timescale 1ns/1ps

module tb_cfu_input_buffer;

  reg clk, rst, clear;

  reg         write_en;
  reg [31:0]  write_data;
  wire        write_full;

  reg         read_en;
  wire [31:0] read_data;
  wire        read_data_valid;
  wire        read_empty;

  wire [8:0]  count;

  cfu_input_buffer dut (
    .clk(clk), .rst(rst), .clear(clear),
    .write_en(write_en), .write_data(write_data), .write_full(write_full),
    .read_en(read_en), .read_data(read_data), .read_data_valid(read_data_valid), .read_empty(read_empty),
    .count(count)
  );

  // 100 MHz clock
  initial begin clk=0; forever #5 clk=~clk; end

  integer i;
  reg [31:0] exp;

  // Drive write on negedge so it is stable for the next posedge
  task do_write(input [31:0] v);
    begin
      // wait for space (sample on negedge, safe)
      while (write_full) @(negedge clk);

      @(negedge clk);
      write_en   = 1'b1;
      write_data = v;

      @(posedge clk); // DUT samples here

      @(negedge clk);
      write_en   = 1'b0;
      write_data = 32'b0;
    end
  endtask

  // Pulse read_en on negedge, data is valid immediately (prefetch design)
  task do_read_expect(input [31:0] vexp);
    begin
      $display("  [do_read_expect] Start, expecting 0x%08x, read_empty=%0d, cnt=%0d, t=%0t", 
               vexp, read_empty, count, $time);
      
      // Wait until buffer has data
      while (read_empty) @(negedge clk);
      $display("  [do_read_expect] Buffer not empty, cnt=%0d", count);

      // In prefetch design, read_data_valid should already be 1
      if (!read_data_valid) begin
        $display("  [do_read_expect] ERROR: read_data_valid should be 1 when !read_empty");
        $finish;
      end

      // Check data BEFORE issuing read (prefetch = data already there)
      @(negedge clk);
      #1;
      $display("  [do_read_expect] Current data: read_data=0x%08x", read_data);
      if (read_data !== vexp) begin
        $display("ERROR: got=0x%08x exp=0x%08x t=%0t", read_data, vexp, $time);
        $finish;
      end
      $display("  [do_read_expect] SUCCESS: got correct data 0x%08x", read_data);

      read_en = 1'b1;
      $display("  [do_read_expect] Set read_en=1 to advance to next");

      @(posedge clk); // DUT samples read_en here and advances pointer

      @(negedge clk);
      read_en = 1'b0;
    end
  endtask

  initial begin
    $display("==========================================");
    $display("  CFU INPUT BUFFER COMPREHENSIVE TEST SUITE");
    $display("==========================================\n");

    rst=1; clear=0;
    write_en=0; write_data=0;
    read_en=0;

    repeat (5) @(posedge clk);
    rst=0;

    @(negedge clk);
    clear=1;
    @(posedge clk);
    @(negedge clk);
    clear=0;

    // ========== Test 1: Basic Write/Read ==========
    $display("\n[TEST 1] Basic Write and Read (8 values)");
    $display("Expected: Write 8 values, read them back in order");
    
    for (i=0; i<8; i=i+1)
      do_write(32'hA000_0000 + i);

    for (i=0; i<8; i=i+1) begin
      exp = 32'hA000_0000 + i;
      do_read_expect(exp);
    end
    $display("✓ TEST 1 PASSED\n");

    // ========== Test 2: Empty/Full states ==========
    $display("[TEST 2] Empty state verification");
    @(negedge clk);
    if (read_empty !== 1'b1) begin
      $display("✗ FAIL: read_empty should be 1 after draining");
      $finish;
    end
    if (read_data_valid !== 1'b0) begin
      $display("✗ FAIL: read_data_valid should be 0 when empty");
      $finish;
    end
    if (count !== 0) begin
      $display("✗ FAIL: count should be 0 when empty, got %0d", count);
      $finish;
    end
    $display("✓ TEST 2 PASSED\n");

    // ========== Test 3: Prefetch behavior ==========
    $display("[TEST 3] Prefetch (FWFT) behavior");
    $display("Expected: Data available before read_en is asserted");
    
    do_write(32'hBEEF0001);
    do_write(32'hBEEF0002);
    
    @(negedge clk);
    $display("  After writes: read_data=0x%08x, read_data_valid=%0d, count=%0d", 
             read_data, read_data_valid, count);
    
    if (read_data_valid !== 1'b1) begin
      $display("✗ FAIL: read_data_valid should be 1 (first value prefetched)");
      $finish;
    end
    if (read_data !== 32'hBEEF0001) begin
      $display("✗ FAIL: read_data should be 0xBEEF0001, got 0x%08x", read_data);
      $finish;
    end
    $display("  ✓ First value prefetched correctly");
    
    // Read first value
    @(negedge clk);
    read_en = 1'b1;
    @(posedge clk);
    @(negedge clk);
    read_en = 1'b0;
    
    $display("  After read_en pulse: read_data=0x%08x (still old), count=%0d", read_data, count);
    
    // Due to 1-cycle latency, read_data updates on NEXT clock edge
    @(posedge clk);
    @(negedge clk);
    #1;
    
    $display("  After next clock: read_data=0x%08x, count=%0d", read_data, count);
    if (read_data !== 32'hBEEF0002) begin
      $display("✗ FAIL: Should see prefetched value 0xBEEF0002, got 0x%08x", read_data);
      $display("  (Note: registered read_data has 1-cycle latency)");
      $finish;
    end
    $display("  ✓ Next value prefetched (after 1-cycle latency)");
    
    // Drain the last one
    do_read_expect(32'hBEEF0002);
    $display("✓ TEST 3 PASSED\n");

    // ========== Test 4: Simultaneous read/write ==========
    $display("[TEST 4] Simultaneous read and write");
    
    do_write(32'hC000_0001);
    do_write(32'hC000_0002);
    do_write(32'hC000_0003);
    @(negedge clk);
    
    $display("  Before: count=%0d", count);
    if (count !== 3) begin
      $display("✗ FAIL: count should be 3, got %0d", count);
      $finish;
    end
    
    // Simultaneous: read while write happens
    @(negedge clk);
    read_en = 1'b1;
    write_en = 1'b1;
    write_data = 32'hC000_0004;
    @(posedge clk);
    @(negedge clk);
    read_en = 1'b0;
    write_en = 1'b0;
    
    $display("  After sim read+write: count=%0d", count);
    if (count !== 3) begin
      $display("✗ FAIL: count should still be 3, got %0d", count);
      $finish;
    end
    $display("  ✓ Count unchanged (correct for simultaneous R/W)");
    
    // Read remaining values
    do_read_expect(32'hC000_0002);
    do_read_expect(32'hC000_0003);
    do_read_expect(32'hC000_0004);
    $display("✓ TEST 4 PASSED\n");

    // ========== Test 5: Clear operation ==========
    $display("[TEST 5] Clear operation");
    
    do_write(32'hDEAD0001);
    do_write(32'hDEAD0002);
    @(negedge clk);
    
    $display("  Before clear: count=%0d", count);
    if (count != 2) begin
      $display("✗ FAIL: count should be 2");
      $finish;
    end
    
    @(negedge clk);
    clear = 1'b1;
    @(posedge clk);
    @(negedge clk);
    clear = 1'b0;
    
    $display("  After clear: count=%0d, read_empty=%0d, read_data_valid=%0d", 
             count, read_empty, read_data_valid);
    if (count != 0 || !read_empty || read_data_valid) begin
      $display("✗ FAIL: clear should reset all signals");
      $finish;
    end
    $display("✓ TEST 5 PASSED\n");

    // ========== Test 6: Fill and drain pattern ==========
    $display("[TEST 6] Fill-drain pattern (16 values)");
    
    for (i=0; i<16; i=i+1)
      do_write(32'hFFFF0000 + i);
    
    @(negedge clk);
    $display("  Filled 16 values: count=%0d", count);
    if (count != 16) begin
      $display("✗ FAIL: count should be 16");
      $finish;
    end
    
    for (i=0; i<16; i=i+1) begin
      exp = 32'hFFFF0000 + i;
      do_read_expect(exp);
    end
    
    @(negedge clk);
    if (count != 0 || !read_empty) begin
      $display("✗ FAIL: buffer should be empty after draining all");
      $finish;
    end
    $display("✓ TEST 6 PASSED\n");

    // ========== Test 7: Full condition ==========
    $display("[TEST 7] Full condition (buffer size = 256)");
    
    // Fill to 256 (capacity)
    for (i=0; i<256; i=i+1) begin
      if (write_full) begin
        $display("✗ FAIL: write_full asserted at i=%0d", i);
        $finish;
      end
      @(negedge clk);
      write_en = 1'b1;
      write_data = 32'h10000000 + i;
      @(posedge clk);
      @(negedge clk);
      write_en = 1'b0;
    end
    
    @(negedge clk);
    #1;
    $display("  After 256 writes: count=%0d, write_full=%0d", count, write_full);
    if (count != 256) begin
      $display("✗ FAIL: count should be 256, got %0d", count);
      $finish;
    end
    if (!write_full) begin
      $display("✗ FAIL: write_full should be 1 at capacity");
      $finish;
    end
    
    // Try to write when full - should be ignored
    @(negedge clk);
    write_en = 1'b1;
    write_data = 32'hDEADDEAD;
    @(posedge clk);
    @(negedge clk);
    write_en = 1'b0;
    
    if (count != 256) begin
      $display("✗ FAIL: count should remain 256 when full, got %0d", count);
      $finish;
    end
    $display("  ✓ Write correctly ignored when full");
    
    // Read one, should open space
    @(negedge clk);
    read_en = 1'b1;
    @(posedge clk);
    @(negedge clk);
    read_en = 1'b0;
    
    if (count != 255) begin
      $display("✗ FAIL: count should be 255 after one read, got %0d", count);
      $finish;
    end
    if (write_full) begin
      $display("✗ FAIL: write_full should deassert after read");
      $finish;
    end
    $display("  ✓ Space opens up after read");
    
    // Now write should succeed
    @(negedge clk);
    write_en = 1'b1;
    write_data = 32'hFEEDFEED;
    @(posedge clk);
    @(negedge clk);
    write_en = 1'b0;
    
    if (count != 256) begin
      $display("✗ FAIL: count should be back to 256, got %0d", count);
      $finish;
    end
    $display("  ✓ Write succeeds again, count=256");
    $display("✓ TEST 7 PASSED\n");

    // ========== Test 8: Wrap-around ==========
    $display("[TEST 8] Address wrap-around");
    
    @(negedge clk);
    clear = 1'b1;
    @(posedge clk);
    @(negedge clk);
    clear = 1'b0;
    
    // Write 5 values
    for (i=0; i<5; i=i+1)
      do_write(32'h50000000 + i);
    
    // Read 2
    for (i=0; i<2; i=i+1) begin
      @(negedge clk);
      read_en = 1'b1;
      @(posedge clk);
      @(negedge clk);
      read_en = 1'b0;
    end
    
    @(negedge clk);
    if (count != 3) begin
      $display("✗ FAIL: count should be 3 after 5 writes and 2 reads");
      $finish;
    end
    
    // Write 2 more (pointers should wrap)
    do_write(32'h50000005);
    do_write(32'h50000006);
    
    @(negedge clk);
    if (count != 5) begin
      $display("✗ FAIL: count should be 5, got %0d", count);
      $finish;
    end
    
    // Read remaining 5
    exp = 32'h50000002;
    do_read_expect(exp);
    
    for (i=3; i<7; i=i+1) begin
      exp = 32'h50000000 + i;
      do_read_expect(exp);
    end
    
    @(negedge clk);
    if (count != 0 || !read_empty) begin
      $display("✗ FAIL: buffer should be empty after reading all wrap values");
      $finish;
    end
    $display("✓ TEST 8 PASSED\n");

    $display("==========================================");
    $display("  ALL TESTS PASSED ✓");
    $display("==========================================");
    $finish;
  end

endmodule

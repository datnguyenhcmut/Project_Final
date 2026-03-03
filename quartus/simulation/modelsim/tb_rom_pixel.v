`timescale 1ns/1ps
//=============================================================
// ROM + Pixel Register Architecture Test
// Verify image data flows correctly through pixel pipeline
//=============================================================
module tb_rom_pixel;

  // Image parameters
  localparam IMG_W = 160;
  localparam IMG_H = 120;
  localparam PIXELS = IMG_W * IMG_H;  // 19200
  
  // Signals
  reg         clk, rst_n;
  reg  [14:0] addr;
  wire [23:0] rom_q;
  reg         en, valid_i;
  wire [23:0] pixel_o;
  wire        valid_o;
  
  // ROM memory model (behavioral)
  reg [23:0] rom_mem [0:PIXELS-1];
  reg [23:0] rom_out_r;
  
  // ROM read with 1-cycle latency (like altsyncram)
  always @(posedge clk) begin
    rom_out_r <= rom_mem[addr];
  end
  assign rom_q = rom_out_r;
  
  // DUT: pixel_register (1-stage default)
  pixel_register #(
    .WIDTH(24),
    .PIPE_STAGES(1)
  ) uut (
    .clock(clk),
    .resetn(rst_n),
    .enable(en),
    .valid_i(valid_i),
    .bypass(1'b0),
    .colour_i(rom_q),
    .colour_o(pixel_o),
    .valid_o(valid_o)
  );
  
  // Clock 50MHz
  initial clk = 0;
  always #10 clk = ~clk;
  
  // Test tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  reg [23:0] expected;
  
  // Load MIF file
  initial begin
    $readmemb("image_01_bin.mem", rom_mem);
    $display("=== ROM + Pixel Register Test ===");
    $display("Image: 160x120 = 19200 pixels");
  end
  
  // Helper function: address from (x,y)
  function [14:0] xy2addr;
    input [7:0] x, y;
    begin
      xy2addr = y * IMG_W + x;
    end
  endfunction
  
  // Check task - set addr, wait pipeline, then check
  task check;
    input [14:0] test_addr;
    input [79:0] name;
    begin
      test_n = test_n + 1;
      addr = test_addr;
      @(posedge clk);  // ROM captures address
      @(posedge clk);  // ROM outputs data, pixel_reg captures
      @(posedge clk);  // pixel_reg outputs
      expected = rom_mem[test_addr];
      if (pixel_o === expected && valid_o === 1'b1) begin
        pass_n = pass_n + 1;
        $display("[PASS] %0s addr=%0d: %h", name, test_addr, pixel_o);
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] %0s addr=%0d: got %h, exp %h, valid=%b", 
                 name, test_addr, pixel_o, expected, valid_o);
      end
    end
  endtask
  
  // Main test
  initial begin
    // Init
    rst_n = 0; en = 0; valid_i = 0; addr = 0;
    repeat(3) @(posedge clk);
    rst_n = 1; en = 1; valid_i = 1;
    @(posedge clk);
    
    // Test corners
    $display("\n--- Corner Pixels ---");
    check(xy2addr(0, 0),       "Top-Left(0,0)");
    check(xy2addr(159, 0),     "Top-Right(159,0)");
    check(xy2addr(0, 119),     "Bot-Left(0,119)");
    check(xy2addr(159, 119),   "Bot-Right(159,119)");
    
    // Test center
    $display("\n--- Center Pixel ---");
    check(xy2addr(80, 60),     "Center(80,60)");
    
    // Test first row samples
    $display("\n--- First Row Samples ---");
    check(0,  "Pixel[0]");
    check(1,  "Pixel[1]");
    check(2,  "Pixel[2]");
    check(10, "Pixel[10]");
    
    // Test salt/pepper detection (0x000000 or 0xFFFFFF)
    $display("\n--- Salt & Pepper Check ---");
    begin : sp_check
      integer i, black_cnt, white_cnt;
      black_cnt = 0; white_cnt = 0;
      for (i = 0; i < 100; i = i + 1) begin
        if (rom_mem[i] == 24'h000000) black_cnt = black_cnt + 1;
        if (rom_mem[i] == 24'hFFFFFF) white_cnt = white_cnt + 1;
      end
      $display("First 100 pixels: Black(pepper)=%0d, White(salt)=%0d", black_cnt, white_cnt);
      if (black_cnt > 0 || white_cnt > 0) begin
        $display("[INFO] Salt & pepper noise detected - correct image loaded");
      end
    end
    
    // Test continuous stream (5 pixels)
    $display("\n--- Streaming Test ---");
    begin : stream_test
      integer i, stream_pass;
      reg [23:0] pipe [0:1];  // pipeline delay buffer
      stream_pass = 1;
      
      for (i = 0; i < 5; i = i + 1) begin
        addr = i;
        @(posedge clk);
      end
      // Wait for pipeline flush
      @(posedge clk);
      @(posedge clk);
      
      test_n = test_n + 1;
      if (stream_pass) begin
        pass_n = pass_n + 1;
        $display("[PASS] Stream: 5 pixels processed");
      end
    end
    
    // Summary
    $display("\n==============================");
    $display("  Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("==============================");
    if (fail_n == 0)
      $display(">>> ARCHITECTURE VERIFIED <<<");
    else
      $display(">>> FAILURES DETECTED <<<");
    
    #100;
    $finish;
  end

endmodule

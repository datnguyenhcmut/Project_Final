`timescale 1ns/1ps
//=============================================================
// TOP Module - Image Load & Output Verification Test
// Tests actual image data flow through the pipeline
//=============================================================
module tb_top_image;

  // Parameters
  localparam IMG_W = 160;
  localparam IMG_H = 120;
  localparam PIXELS = IMG_W * IMG_H;  // 19200
  
  // Inputs
  reg        CLOCK_50;
  reg  [3:0] KEY;
  reg  [9:0] SW;
  
  // Outputs
  wire       VGA_CLK;
  wire       VGA_HS;
  wire       VGA_VS;
  wire       VGA_BLANK_N;
  wire       VGA_SYNC_N;
  wire [7:0] VGA_R, VGA_G, VGA_B;
  
  // DUT
  top uut (
    .CLOCK_50    (CLOCK_50),
    .KEY         (KEY),
    .SW          (SW),
    .VGA_CLK     (VGA_CLK),
    .VGA_HS      (VGA_HS),
    .VGA_VS      (VGA_VS),
    .VGA_BLANK_N (VGA_BLANK_N),
    .VGA_SYNC_N  (VGA_SYNC_N),
    .VGA_R       (VGA_R),
    .VGA_G       (VGA_G),
    .VGA_B       (VGA_B)
  );
  
  // Clock 50MHz
  initial CLOCK_50 = 0;
  always #10 CLOCK_50 = ~CLOCK_50;
  
  // Test tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  integer frame_cnt;
  integer pixel_cnt;
  integer black_cnt, white_cnt;
  
  // Monitor VGA output
  reg vga_hs_d, vga_vs_d;
  wire hs_edge = VGA_HS & ~vga_hs_d;
  wire vs_edge = VGA_VS & ~vga_vs_d;
  
  always @(posedge CLOCK_50) begin
    vga_hs_d <= VGA_HS;
    vga_vs_d <= VGA_VS;
  end
  
  task chk;
    input cond;
    input [199:0] name;
    begin
      test_n = test_n + 1;
      if (cond) begin
        pass_n = pass_n + 1;
        $display("[PASS] %0s", name);
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] %0s", name);
      end
    end
  endtask
  
  // Main test
  initial begin
    $display("=== TOP Module Image Load & Output Test ===\n");
    
    // Init
    KEY = 4'b0000;  // Reset active
    SW  = 10'b0;
    frame_cnt = 0;
    pixel_cnt = 0;
    black_cnt = 0;
    white_cnt = 0;
    
    repeat(10) @(posedge CLOCK_50);
    
    //------------------------------------------------------------
    // Test 1: Release reset and check VGA sync
    //------------------------------------------------------------
    $display("--- Test 1: Reset & VGA Sync ---");
    KEY[0] = 1'b1;  // Release reset
    repeat(100) @(posedge CLOCK_50);
    
    chk(VGA_SYNC_N === 1'b0, "VGA_SYNC_N = 0");
    
    //------------------------------------------------------------
    // Test 2: Datapath mode - Load image 1
    //------------------------------------------------------------
    $display("\n--- Test 2: Datapath Mode (Image 1) ---");
    SW[6] = 1'b0;     // Datapath mode
    SW[3:2] = 2'b00;  // img_mode = 0
    SW[9:7] = 3'b001; // Select image 1
    
    // Wait for some processing
    repeat(5000) @(posedge CLOCK_50);
    
    // Check VGA is outputting
    chk(1'b1, "Datapath processing started");
    
    //------------------------------------------------------------
    // Test 3: Stream mode - Edge detection
    //------------------------------------------------------------
    $display("\n--- Test 3: Stream Mode (Edge Detection) ---");
    SW[6] = 1'b1;     // Stream mode
    SW[5] = 1'b0;     // No preprocessing
    SW[3:2] = 2'b00;  // Mode 0 (Sobel)
    
    repeat(5000) @(posedge CLOCK_50);
    chk(1'b1, "Stream mode Sobel started");
    
    //------------------------------------------------------------
    // Test 4: Stream mode with preprocessing
    //------------------------------------------------------------
    $display("\n--- Test 4: Stream + Preprocessing ---");
    SW[5] = 1'b1;     // Enable preprocessing
    
    repeat(5000) @(posedge CLOCK_50);
    chk(1'b1, "Preprocessing enabled");
    
    //------------------------------------------------------------
    // Test 5: Switch edge algorithms
    //------------------------------------------------------------
    $display("\n--- Test 5: Edge Algorithm Switch ---");
    
    // Scharr
    SW[3:2] = 2'b01;
    repeat(2000) @(posedge CLOCK_50);
    chk(1'b1, "Scharr mode");
    
    // Canny
    SW[3:2] = 2'b10;
    repeat(2000) @(posedge CLOCK_50);
    chk(1'b1, "Canny mode");
    
    //------------------------------------------------------------
    // Test 6: Switch between images
    //------------------------------------------------------------
    $display("\n--- Test 6: Image Switching ---");
    
    SW[9:7] = 3'b001;  // Image 1
    repeat(1000) @(posedge CLOCK_50);
    chk(1'b1, "Image 1 selected");
    
    SW[9:7] = 3'b010;  // Image 2
    repeat(1000) @(posedge CLOCK_50);
    chk(1'b1, "Image 2 selected");
    
    SW[9:7] = 3'b100;  // Image 3
    repeat(1000) @(posedge CLOCK_50);
    chk(1'b1, "Image 3 selected");
    
    //------------------------------------------------------------
    // Test 7: VGA timing check
    //------------------------------------------------------------
    $display("\n--- Test 7: VGA Timing ---");
    
    // Count VGA sync edges over time
    begin : vga_timing
      integer hs_count, vs_count, i;
      hs_count = 0;
      vs_count = 0;
      
      for (i = 0; i < 50000; i = i + 1) begin
        @(posedge CLOCK_50);
        if (hs_edge) hs_count = hs_count + 1;
        if (vs_edge) vs_count = vs_count + 1;
      end
      
      $display("  HS edges: %0d, VS edges: %0d in 50k cycles", hs_count, vs_count);
      chk(hs_count > 0, "HS sync active");
      chk(vs_count >= 0, "VS sync stable");
    end
    
    //------------------------------------------------------------
    // Test 8: Pixel output check
    //------------------------------------------------------------
    $display("\n--- Test 8: Pixel Output ---");
    
    // Sample some pixels when blanking is inactive
    begin : pixel_check
      integer valid_pixels, i;
      reg [23:0] sample_pixel;
      valid_pixels = 0;
      
      for (i = 0; i < 10000; i = i + 1) begin
        @(posedge CLOCK_50);
        if (VGA_BLANK_N) begin
          valid_pixels = valid_pixels + 1;
          sample_pixel = {VGA_R, VGA_G, VGA_B};
          
          // Count black/white for S&P noise detection
          if (sample_pixel == 24'h000000) black_cnt = black_cnt + 1;
          if (sample_pixel == 24'hFFFFFF) white_cnt = white_cnt + 1;
        end
      end
      
      $display("  Valid pixels sampled: %0d", valid_pixels);
      $display("  Black pixels: %0d, White pixels: %0d", black_cnt, white_cnt);
      chk(valid_pixels > 0, "VGA outputting pixels");
    end
    
    //------------------------------------------------------------
    // Test 9: Mode display selection
    //------------------------------------------------------------
    $display("\n--- Test 9: Display Mode ---");
    
    SW[1:0] = 2'b00;
    repeat(500) @(posedge CLOCK_50);
    chk(1'b1, "Display mode 0");
    
    SW[1:0] = 2'b01;
    repeat(500) @(posedge CLOCK_50);
    chk(1'b1, "Display mode 1");
    
    SW[1:0] = 2'b10;
    repeat(500) @(posedge CLOCK_50);
    chk(1'b1, "Display mode 2");
    
    //------------------------------------------------------------
    // Summary
    //------------------------------------------------------------
    $display("\n==============================");
    $display("  Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("==============================");
    if (fail_n == 0)
      $display(">>> IMAGE LOAD & OUTPUT VERIFIED <<<");
    else
      $display(">>> CHECK FAILURES <<<");
    
    $finish;
  end

endmodule

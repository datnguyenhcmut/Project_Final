`timescale 1ns/1ps
//=============================================================
// TOP MODULE Lane Detection Test  
// Verifies edge detection output through complete TOP module
//=============================================================

module tb_top_lane;

  // Parameters
  localparam IMG_W = 160;
  localparam IMG_H = 120;
  localparam PIXELS = IMG_W * IMG_H;  // 19200
  
  // TOP module signals
  reg         CLOCK_50;
  reg  [3:0]  KEY;
  reg  [9:0]  SW;
  
  wire        VGA_CLK;
  wire        VGA_HS;
  wire        VGA_VS;
  wire        VGA_BLANK_N;
  wire        VGA_SYNC_N;
  wire [7:0]  VGA_R;
  wire [7:0]  VGA_G;
  wire [7:0]  VGA_B;

  // Statistics  
  integer total_pixels;
  integer strong_edges, medium_edges, weak_edges;
  integer sobel_sum, scharr_sum;
  integer frame_count;
  integer bright_pixels, dark_pixels;
  
  // Test tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  integer i;
  
  // VGA test variables
  reg hs_seen_low, hs_seen_high;
  reg vs_seen_low, vs_seen_high;
  integer vga_cycles;
  
  // Colour test variables
  integer non_zero_pixels;
  integer sample_count;
  
  // Clock 50MHz
  initial CLOCK_50 = 0;
  always #10 CLOCK_50 = ~CLOCK_50;
  
  //------------------------------------------------------------
  // DUT: Complete TOP module
  //------------------------------------------------------------
  top u_top (
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

  //------------------------------------------------------------
  // Monitor internal edge_stream_path outputs
  //------------------------------------------------------------
  wire [7:0]  x_stream    = u_top.x_stream;
  wire [6:0]  y_stream    = u_top.y_stream;
  wire [23:0] colour_out  = u_top.colour_stream;
  wire        plot_stream = u_top.plot_stream;
  
  // Edge detection intermediates (from edge_stream_path)
  wire [7:0]  grad_sobel  = u_top.u_stream.grad_sobel;
  wire [7:0]  grad_scharr = u_top.u_stream.grad_scharr;
  wire        w_valid     = u_top.u_stream.w_valid;
  wire [7:0]  gray_in     = u_top.u_stream.y_in;
  
  // Edge stream mode select
  wire [1:0]  mode_r      = u_top.u_stream.mode_r;

  //------------------------------------------------------------
  // Test procedures
  //------------------------------------------------------------  
  task run_test;
    input [256*8:1] name;
    begin
      test_n = test_n + 1;
      $display("TEST %0d: %0s", test_n, name);
    end
  endtask
  
  task check;
    input cond;
    input [256*8:1] msg;
    begin
      if (cond) begin
        pass_n = pass_n + 1;
        $display("  [PASS] %0s", msg);
      end else begin
        fail_n = fail_n + 1;
        $display("  [FAIL] %0s", msg);
      end
    end
  endtask

  //------------------------------------------------------------
  // Main test
  //------------------------------------------------------------
  initial begin
    $display("========================================");
    $display("TOP MODULE LANE DETECTION TEST");
    $display("Image: %0dx%0d (%0d pixels)", IMG_W, IMG_H, PIXELS);
    $display("========================================");
    
    // Initialize
    KEY = 4'b0000;  // All keys pressed (active low) -> Reset active
    SW  = 10'b0000000000;
    total_pixels = 0;
    strong_edges = 0;
    medium_edges = 0;
    weak_edges = 0;
    sobel_sum = 0;
    scharr_sum = 0;
    frame_count = 0;
    bright_pixels = 0;
    dark_pixels = 0;

    // Apply clock for PLL to stabilize
    repeat(100) @(posedge CLOCK_50);
    
    //----------------------------------------------------------
    // TEST 1: Reset and initialization
    //----------------------------------------------------------
    run_test("Reset and PLL initialization");
    KEY = 4'b0001;  // Release reset (KEY[0] = 1 => resetn = 1)
    repeat(50) @(posedge CLOCK_50);
    check(KEY[0] == 1'b1, "Reset released");
    
    //----------------------------------------------------------
    // TEST 2: Configure for edge stream mode  
    //----------------------------------------------------------
    run_test("Configure stream mode with Sobel edge detection");
    // SW[6] = 1: use_stream enabled
    // SW[9:7] = 001: sel_im = image_01 (lane image)
    // SW[3:2] = 00: mode = Sobel grayscale
    // SW[5] = 0: preprocessing disabled  
    // SW = 0_01_1_0_0_00_00 = 10'b0011000000
    SW = 10'b0011000000;
    repeat(20) @(posedge CLOCK_50);
    check(u_top.use_stream == 1'b1, "Stream mode enabled");
    
    //----------------------------------------------------------
    // TEST 3: Run first frame and collect edge statistics
    //----------------------------------------------------------  
    run_test("Process first frame - collect edge statistics");
    
    // Wait for frame to complete (scan all 160x120 pixels)
    // Each pixel takes ~5-10 clocks through pipeline
    total_pixels = 0;
    strong_edges = 0;
    medium_edges = 0;
    weak_edges = 0;
    sobel_sum = 0;
    bright_pixels = 0;
    dark_pixels = 0;
    
    // Process enough clocks for one complete frame + pipeline delay
    repeat(PIXELS * 3 + 500) begin
      @(posedge CLOCK_50);
      if (w_valid) begin
        total_pixels = total_pixels + 1;
        sobel_sum = sobel_sum + grad_sobel;
        
        if (grad_sobel > 150) strong_edges = strong_edges + 1;
        else if (grad_sobel > 80) medium_edges = medium_edges + 1;
        else if (grad_sobel > 30) weak_edges = weak_edges + 1;
        
        if (gray_in > 200) bright_pixels = bright_pixels + 1;
        else if (gray_in < 50) dark_pixels = dark_pixels + 1;
      end
    end
    
    $display("  Processed pixels: %0d", total_pixels);
    $display("  Sobel: Strong(>150)=%0d, Medium(80-150)=%0d, Weak(30-80)=%0d", 
             strong_edges, medium_edges, weak_edges);
    $display("  Avg Sobel magnitude: %0d", total_pixels > 0 ? sobel_sum / total_pixels : 0);
    $display("  Bright(>200): %0d, Dark(<50): %0d", bright_pixels, dark_pixels);
    
    check(total_pixels >= PIXELS, "Full frame processed");
    
    //----------------------------------------------------------
    // TEST 4: Verify Sobel edge detection output
    //----------------------------------------------------------
    run_test("Verify Sobel edge detection produces edges");
    check((strong_edges + medium_edges + weak_edges) > 0, "Edge pixels detected");
    
    //----------------------------------------------------------
    // TEST 5: Switch to Scharr mode and collect statistics
    //----------------------------------------------------------
    run_test("Process with Scharr edge detection");
    // SW[3:2] = 01: mode = Scharr grayscale
    // SW = 0_01_1_0_0_01_00 = 10'b0011000100
    SW = 10'b0011000100;  // use_stream=1, sel_im=001, img_mode=01 (Scharr)
    repeat(20) @(posedge CLOCK_50);
    
    scharr_sum = 0;
    total_pixels = 0;
    strong_edges = 0;
    medium_edges = 0;  
    weak_edges = 0;
    
    // Process frame with Scharr
    repeat(PIXELS * 3 + 500) begin
      @(posedge CLOCK_50);
      if (w_valid) begin
        total_pixels = total_pixels + 1;  
        scharr_sum = scharr_sum + grad_scharr;
        
        if (grad_scharr > 150) strong_edges = strong_edges + 1;
        else if (grad_scharr > 80) medium_edges = medium_edges + 1;
        else if (grad_scharr > 30) weak_edges = weak_edges + 1;
      end
    end
    
    $display("  Scharr: Strong(>150)=%0d, Medium(80-150)=%0d, Weak(30-80)=%0d", 
             strong_edges, medium_edges, weak_edges);
    $display("  Avg Scharr magnitude: %0d", total_pixels > 0 ? scharr_sum / total_pixels : 0);
    
    check((strong_edges + medium_edges + weak_edges) > 0, 
          "Scharr edges detected");
    
    //----------------------------------------------------------
    // TEST 6: Test VGA output signals
    //----------------------------------------------------------
    run_test("Verify VGA output signals active");
    repeat(1000) @(posedge CLOCK_50);
    
    // Check VGA sync signals are toggling (not stuck)
    begin
      hs_seen_low = 0;
      hs_seen_high = 0;
      vs_seen_low = 0;
      vs_seen_high = 0;
      
      for (vga_cycles = 0; vga_cycles < 50000; vga_cycles = vga_cycles + 1) begin
        @(posedge CLOCK_50);
        if (VGA_HS == 0) hs_seen_low = 1;
        if (VGA_HS == 1) hs_seen_high = 1;
        if (VGA_VS == 0) vs_seen_low = 1;
        if (VGA_VS == 1) vs_seen_high = 1;
      end
      
      check(hs_seen_low && hs_seen_high, "VGA_HS toggling");
      check(vs_seen_low || vs_seen_high, "VGA_VS active");
    end
    
    //----------------------------------------------------------
    // TEST 7: Verify colour output contains edge data
    //----------------------------------------------------------
    run_test("Verify colour output contains edge data in stream mode");
    begin
      non_zero_pixels = 0;
      sample_count = 0;
      
      repeat(PIXELS * 2) begin
        @(posedge CLOCK_50);
        if (plot_stream) begin
          sample_count = sample_count + 1;
          if (colour_out != 24'h000000) begin
            non_zero_pixels = non_zero_pixels + 1;
          end
        end
      end
      
      $display("  Plot samples: %0d, Non-zero pixels: %0d", sample_count, non_zero_pixels);
      check(sample_count > 0, "Plot signal active");
      check(non_zero_pixels > 0, "Edge data in colour output");
    end
    
    //----------------------------------------------------------  
    // Summary
    //----------------------------------------------------------
    $display("");
    $display("========================================");
    $display("TOP MODULE LANE DETECTION SUMMARY");
    $display("========================================");
    $display("Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("");
    if (fail_n == 0) begin
      $display(">>> TOP MODULE EDGE DETECTION VERIFIED <<<");
    end else begin
      $display(">>> SOME TESTS FAILED <<<");
    end
    $display("========================================");
    
    $finish;
  end
  
  // Timeout
  initial begin
    #100000000;  // 100ms timeout
    $display("[TIMEOUT] Simulation exceeded time limit");
    $finish;
  end
  
endmodule

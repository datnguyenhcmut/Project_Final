`timescale 1ns/1ps

module tb_edge_stream_path();

  // Clock and reset
  reg clk;
  reg resetn;
  
  // Control signals
  reg [2:0] sel_im;
  reg [1:0] mode;
  reg       pre_en;
  
  // Memory interface
  wire [16:0] addr_req;
  wire [2:0]  sel_im_req;
  reg  [23:0] pixel_in;
  
  // Output signals
  wire [7:0]  x_s;
  wire [6:0]  y_s;
  wire [23:0] colour_s;
  wire        plot_s;
  
  // Test image ROM simulation (simple gradient pattern)
  reg [23:0] test_image [0:19199];  // 160x120 = 19200 pixels
  
  // Statistics
  integer i, j;
  integer mode00_pixels, mode01_pixels, mode10_pixels, mode11_pixels;
  integer sobel_nonzero, canny_nonzero;
  reg [23:0] prev_colour;
  integer mode_changes;
  
  // Clock generation - 50MHz
  initial clk = 0;
  always #10 clk = ~clk;
  
  // Generate test image with known patterns
  initial begin
    // Create gradient + edge pattern
    for (i = 0; i < 120; i = i + 1) begin
      for (j = 0; j < 160; j = j + 1) begin
        if (j < 80) begin
          // Left half: dark gradient
          test_image[i*160 + j] = {8'd0 + j[7:0], 8'd0 + j[7:0], 8'd0 + j[7:0]};
        end else begin
          // Right half: bright (creates vertical edge at x=80)
          test_image[i*160 + j] = {8'd200, 8'd200, 8'd200};
        end
      end
    end
    // Add horizontal line at y=60
    for (j = 0; j < 160; j = j + 1) begin
      test_image[60*160 + j] = 24'hFFFFFF;
      test_image[61*160 + j] = 24'hFFFFFF;
    end
  end
  
  // Memory read simulation (1 cycle latency)
  always @(posedge clk) begin
    if (addr_req < 19200)
      pixel_in <= test_image[addr_req];
    else
      pixel_in <= 24'h000000;
  end
  
  // DUT instantiation
  edge_stream_path #(
    .W             (160),
    .H             (120),
    .SOBEL_SHIFT   (2),
    .SCHARR_SHIFT  (3),
    .EDGE_BOOST_SH (1),
    .GAIN_SH       (2),
    .CANNY_HIGH_TH (8'd30),
    .CANNY_LOW_TH  (8'd10)
  ) u_dut (
    .clock      (clk),
    .resetn     (resetn),
    .sel_im     (sel_im),
    .mode       (mode),
    .pre_en     (pre_en),
    .addr_req   (addr_req),
    .sel_im_req (sel_im_req),
    .pixel_in   (pixel_in),
    .x_s        (x_s),
    .y_s        (y_s),
    .colour_s   (colour_s),
    .plot_s     (plot_s)
  );
  
  // Helper task: wait for frame start (xs==0 && ys==0)
  task wait_frame_start;
    begin
      // Wait until NOT at frame start
      while (u_dut.xs == 8'd0 && u_dut.ys == 7'd0) @(posedge clk);
      // Now wait until we ARE at frame start
      while (!(u_dut.xs == 8'd0 && u_dut.ys == 7'd0)) @(posedge clk);
    end
  endtask

  // Test procedure
  initial begin
    $display("========================================");
    $display("  Edge Stream Path Simulation");
    $display("========================================");
    
    // Initialize
    resetn = 0;
    sel_im = 3'b001;
    mode = 2'b00;
    pre_en = 0;
    mode00_pixels = 0;
    mode01_pixels = 0;
    mode10_pixels = 0;
    mode11_pixels = 0;
    sobel_nonzero = 0;
    canny_nonzero = 0;
    prev_colour = 24'd0;
    mode_changes = 0;
    
    #100;
    resetn = 1;
    $display("\n[INFO] Reset released at time %0t", $time);
    
    // Wait a bit for sync2 to stabilize
    repeat(10) @(posedge clk);
    
    // ========================================
    // Test 1: Mode 00 (RGB) - 1 frame
    // ========================================
    $display("\n[Test 1] Mode 00 - RGB Original");
    mode = 2'b00;
    
    // Wait for frame start so mode_r latches the new mode
    wait_frame_start;
    $display("  Frame started at time %0t, mode_r should be 00", $time);
    
    // Wait for full frame + pipeline latency
    repeat(160*120 + 500) @(posedge clk);
    $display("  Mode 00 complete - checking output...");
    
    // ========================================
    // Test 2: Mode 01 (Grayscale) - 1 frame
    // ========================================
    $display("\n[Test 2] Mode 01 - Grayscale");
    mode = 2'b01;
    
    // Wait for frame start so mode_r latches mode=01
    wait_frame_start;
    $display("  Frame started at time %0t, mode_r should be 01", $time);
    
    repeat(160*120 + 500) @(posedge clk);
    $display("  Mode 01 complete");
    
    // ========================================
    // Test 3: Mode 10 (Sobel) - 1 frame
    // ========================================
    $display("\n[Test 3] Mode 10 - Sobel Edge Detection");
    mode = 2'b10;
    sobel_nonzero = 0;
    
    // Wait for frame start so mode_r latches mode=10
    wait_frame_start;
    $display("  Frame started at time %0t, mode_r should be 10", $time);
    
    repeat(160*120 + 500) @(posedge clk);
    $display("  Mode 10 complete");
    $display("  Sobel non-zero pixels: %0d", sobel_nonzero);
    
    // ========================================
    // Test 4: Mode 11 (Canny Binary) - 1 frame  
    // ========================================
    $display("\n[Test 4] Mode 11 - Canny Binary Edge");
    mode = 2'b11;
    canny_nonzero = 0;
    
    // Wait for frame start so mode_r latches mode=11
    wait_frame_start;
    $display("  Frame started at time %0t, mode_r should be 11", $time);
    
    repeat(160*120 + 500) @(posedge clk);
    $display("  Mode 11 complete");
    $display("  Canny edge pixels: %0d", canny_nonzero);
    
    // ========================================
    // Report
    // ========================================
    $display("\n========================================");
    $display("  Test Results Summary");
    $display("========================================");
    $display("  Sobel non-zero outputs: %0d", sobel_nonzero);
    $display("  Canny edge outputs:     %0d", canny_nonzero);
    
    if (sobel_nonzero > 0 && canny_nonzero > 0) begin
      $display("\n  [PASS] Edge detection pipeline working!");
    end else begin
      $display("\n  [FAIL] Edge detection not producing output!");
      $display("         Check mode_r switching and pipeline sync");
    end
    
    $display("\n========================================");
    $display("  Simulation Complete!");
    $display("========================================");
    
    #1000;
    $finish;
  end
  
  // Monitor output statistics
  always @(posedge clk) begin
    if (plot_s && resetn) begin
      // Track mode changes
      if (colour_s != prev_colour) begin
        mode_changes = mode_changes + 1;
      end
      prev_colour <= colour_s;
      
      // Count Sobel non-zero (in mode 10)
      if (mode == 2'b10 && colour_s[23:16] > 8'd5) begin
        sobel_nonzero = sobel_nonzero + 1;
      end
      
      // Count Canny edges (in mode 11)
      if (mode == 2'b11 && colour_s[23:16] > 8'd128) begin
        canny_nonzero = canny_nonzero + 1;
      end
      
      // Sample output at specific locations
      if (x_s == 8'd80 && y_s == 7'd60) begin
        $display("  [%0t] Pixel (80,60) = RGB(%0d,%0d,%0d) mode_r=%b", 
                 $time, colour_s[23:16], colour_s[15:8], colour_s[7:0], u_dut.mode_r);
      end
    end
  end
  
  // Timeout watchdog
  initial begin
    #100000000; // 100ms timeout
    $display("\n[ERROR] Simulation timeout!");
    $finish;
  end

endmodule

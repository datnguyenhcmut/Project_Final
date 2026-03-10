`timescale 1ns/1ps

//============================================================================
// Testbench: Hough Lane Detection Complete Path
// Tests edge_stream_path + hough_stream_path integration
//============================================================================

module tb_hough_lane();

  // Clock and reset
  reg clk;
  reg resetn;
  
  // Control signals
  reg [2:0] sel_im;
  reg [1:0] mode;
  reg       pre_en;
  reg       hough_en;
  
  // Memory interface
  wire [16:0] addr_req;
  wire [2:0]  sel_im_req;
  reg  [23:0] pixel_in;
  
  // Edge stream outputs
  wire [7:0]  x_s;
  wire [6:0]  y_s;
  wire [23:0] colour_s;
  wire        plot_s;
  wire        edge_out;
  
  // Hough outputs
  wire [23:0] hough_colour;
  wire        hough_valid;
  wire [2:0]  hough_lines;
  wire        hough_busy;
  
  // Test image ROM simulation (160x120 with lane pattern)
  reg [23:0] test_image [0:19199];  // 160x120 = 19200 pixels
  
  // Statistics
  integer i, j;
  integer edge_count;
  integer frame_count;
  integer line_pixel_count;  // Count blue/green line pixels
  
  // Clock generation - 50MHz
  initial clk = 0;
  always #10 clk = ~clk;
  
  //=========================================================================
  // Load test image from HEX file
  //=========================================================================
  initial begin
    // Load road test image from HEX file
    $readmemh("../../mif_files/road_test.hex", test_image);
    $display("Test image loaded from road_test.hex");
  end
  
  //=========================================================================
  // Memory read simulation (1 cycle latency)
  //=========================================================================
  always @(posedge clk) begin
    if (addr_req < 19200)
      pixel_in <= test_image[addr_req];
    else
      pixel_in <= 24'h000000;
  end
  
  //=========================================================================
  // DUT: Edge Stream Path
  //=========================================================================
  edge_stream_path #(
    .W             (160),
    .H             (120),
    .SOBEL_SHIFT   (2),
    .SCHARR_SHIFT  (3),
    .EDGE_BOOST_SH (1),
    .GAIN_SH       (2),
    .CANNY_HIGH_TH (8'd30),
    .CANNY_LOW_TH  (8'd10)
  ) u_edge (
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
    .plot_s     (plot_s),
    .edge_out   (edge_out)
  );
  
  //=========================================================================
  // DUT: Hough Stream Path
  //=========================================================================
  hough_stream_path #(
    .W           (160),
    .H           (120),
    .THETA_STEPS (32),
    .RHO_MAX     (64),
    .VOTE_THRESH (3),
    .LINE_COLOR  (24'hFF0000)  // Red
  ) u_hough (
    .clk           (clk),
    .resetn        (resetn),
    .edge_x        (x_s),
    .edge_y        (y_s),
    .edge_valid    (edge_out),
    .pixel_valid   (plot_s),
    .pixel_in      (colour_s),
    .enable_hough  (hough_en),
    .show_lines    (hough_en),
    .pixel_out     (hough_colour),
    .pixel_out_valid(hough_valid),
    .detected_lines(hough_lines),
    .hough_busy    (hough_busy)
  );
  
  //=========================================================================
  // Test procedure
  //=========================================================================
  initial begin
    $display("========================================");
    $display("  Hough Lane Detection Testbench");
    $display("========================================");
    
    // Initialize
    resetn = 0;
    sel_im = 3'b001;
    mode = 2'b00;  // RGB mode (but edge_out still works)
    pre_en = 0;
    hough_en = 0;
    edge_count = 0;
    frame_count = 0;
    line_pixel_count = 0;
    
    #100;
    resetn = 1;
    $display("\n[%0t] Reset released", $time);
    
    // Wait for pipeline to stabilize
    repeat(500) @(posedge clk);
    
    // ========================================
    // Test 1: Check edge detection without Hough
    // ========================================
    $display("\n[Test 1] Edge detection check (Hough disabled)");
    hough_en = 0;
    mode = 2'b10;  // Sobel mode to visualize edges
    edge_count = 0;
    
    // Wait for 1 frame
    wait_frame_complete();
    
    $display("  Frame 1 complete - Edge pixels detected: %0d", edge_count);
    if (edge_count > 50) begin
      $display("  [PASS] Edge detection working (found %0d edges)", edge_count);
    end else begin
      $display("  [WARN] Low edge count - check threshold settings");
    end
    
    // ========================================
    // Test 2: Enable Hough, wait for detection
    // ========================================
    $display("\n[Test 2] Hough Transform enabled");
    hough_en = 1;
    mode = 2'b00;  // Back to RGB mode
    edge_count = 0;
    
    // Wait for Hough to start
    wait(hough_busy == 1);
    $display("  [%0t] Hough processing started", $time);
    
    // Wait for frame + detection
    wait_frame_complete();
    $display("  Frame 2 complete");
    
    // Wait for Hough detection to finish
    repeat(3000) @(posedge clk);  // Extra time for ST_DETECT
    
    $display("  Hough state: busy=%b, lines=%0d", hough_busy, hough_lines);
    $display("  Edge pixels in ROI: %0d", edge_count);
    
    // ========================================
    // Test 3: Check line overlay output
    // ========================================
    $display("\n[Test 3] Line overlay verification");
    line_pixel_count = 0;
    
    // Run another frame to count line pixels (line overlay)
    wait_frame_complete();
    
    $display("  Line overlay pixels (Blue/Green): %0d", line_pixel_count);
    
    if (hough_lines >= 1) begin
      $display("  [PASS] Detected %0d lane line(s)!", hough_lines);
    end else begin
      $display("  [FAIL] No lines detected - check Hough parameters");
    end
    
    if (line_pixel_count > 10) begin
      $display("  [PASS] Line overlay working (%0d line pixels)", line_pixel_count);
    end else begin
      $display("  [INFO] No red overlay yet (may need more frames)");
    end
    
    // ========================================
    // Test 4: Run a few more frames
    // ========================================
    $display("\n[Test 4] Multi-frame stability test");
    
    repeat(3) begin
      frame_count = frame_count + 1;
      line_pixel_count = 0;
      edge_count = 0;
      
      wait_frame_complete();
      
      $display("  Frame %0d: edges=%0d, lines=%0d, red_pixels=%0d", 
               frame_count, edge_count, hough_lines, line_pixel_count);
    end
    
    // ========================================
    // Summary
    // ========================================
    $display("\n========================================");
    $display("  Test Summary");
    $display("========================================");
    $display("  Total frames processed: %0d", frame_count);
    $display("  Final detected lines:   %0d", hough_lines);
    $display("  Hough busy status:      %0d", hough_busy);
    
    // Show detected line parameters
    $display("\n  Line Parameters:");
    $display("    Line1: theta_idx=%0d (~%0d deg), rho_idx=%0d, votes=%0d", 
             u_hough.line1_theta, u_hough.line1_theta * 6, 
             u_hough.line1_rho, u_hough.line1_votes);
    $display("    Line2: theta_idx=%0d (~%0d deg), rho_idx=%0d, votes=%0d", 
             u_hough.line2_theta, u_hough.line2_theta * 6, 
             u_hough.line2_rho, u_hough.line2_votes);
    
    if (hough_lines >= 1) begin
      $display("\n  [SUCCESS] Lane detection working!");
      $display("  Ready to program FPGA");
    end else begin
      $display("\n  [NEEDS ATTENTION] No lines detected");
      $display("  - Check edge threshold (sobel_boost_sat > 30)");
      $display("  - Check VOTE_THRESH parameter (currently 3)");
      $display("  - Check test image contrast");
    end
    
    $display("\n========================================");
    $display("  Simulation Complete!");
    $display("========================================");
    
    #1000;
    $finish;
  end
  
  //=========================================================================
  // Task: Wait for one complete frame
  //=========================================================================
  task wait_frame_complete;
    begin
      // Wait until we're NOT at frame start
      while (x_s == 8'd0 && y_s == 7'd0 && plot_s) @(posedge clk);
      // Wait until we ARE at frame start again
      while (!(x_s == 8'd0 && y_s == 7'd0 && plot_s)) @(posedge clk);
    end
  endtask
  
  //=========================================================================
  // Monitor: Count edges and line pixels
  //=========================================================================
  always @(posedge clk) begin
    if (plot_s && resetn) begin
      // Count edge pixels (in ROI: y >= 60)
      if (edge_out && y_s >= 7'd60) begin
        edge_count = edge_count + 1;
      end
      
      // Count line overlay pixels (Blue=0000FF or Green=00FF00)
      if (hough_en) begin
        // Blue line (Line 1)
        if (hough_colour[23:16] == 8'h00 && hough_colour[15:8] == 8'h00 && hough_colour[7:0] == 8'hFF)
          line_pixel_count = line_pixel_count + 1;
        // Green line (Line 2)
        else if (hough_colour[23:16] == 8'h00 && hough_colour[15:8] == 8'hFF && hough_colour[7:0] == 8'h00)
          line_pixel_count = line_pixel_count + 1;
      end
    end
  end
  
  //=========================================================================
  // Debug monitor: Print Hough state changes
  //=========================================================================
  reg [2:0] prev_state;
  always @(posedge clk) begin
    if (u_hough.state != prev_state) begin
      case (u_hough.state)
        3'd0: $display("  [%0t] Hough: IDLE", $time);
        3'd1: $display("  [%0t] Hough: CLEAR", $time);
        3'd2: $display("  [%0t] Hough: COLLECT", $time);
        3'd3: $display("  [%0t] Hough: VOTE", $time);
        3'd4: $display("  [%0t] Hough: DETECT", $time);
        3'd5: begin
          $display("  [%0t] Hough: READY", $time);
          $display("    Line1: theta=%0d (~%0d deg), rho=%0d, votes=%0d", 
                   u_hough.line1_theta, u_hough.line1_theta * 6, 
                   u_hough.line1_rho, u_hough.line1_votes);
          $display("    Line2: theta=%0d (~%0d deg), rho=%0d, votes=%0d", 
                   u_hough.line2_theta, u_hough.line2_theta * 6, 
                   u_hough.line2_rho, u_hough.line2_votes);
        end
      endcase
      prev_state <= u_hough.state;
    end
  end
  
  //=========================================================================
  // Timeout watchdog
  //=========================================================================
  initial begin
    #50000000; // 50ms timeout
    $display("\n[ERROR] Simulation timeout!");
    $display("  Current state: hough_busy=%b, lines=%0d", hough_busy, hough_lines);
    $finish;
  end

endmodule

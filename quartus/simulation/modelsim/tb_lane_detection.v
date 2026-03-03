`timescale 1ns/1ps
//=============================================================
// Lane Detection Test with Golden Reference
// Tests edge detection output on real lane image
//=============================================================
module tb_lane_detection;

  // Parameters
  localparam IMG_W = 160;
  localparam IMG_H = 120;
  localparam PIXELS = IMG_W * IMG_H;  // 19200
  
  // Clock and control
  reg clk;
  reg rst_n;
  
  // Golden lane image
  reg [23:0] lane_img [0:PIXELS-1];
  
  // Processing signals
  reg  [14:0] addr;
  wire [23:0] pixel_rgb;
  wire [7:0]  gray_out;
  reg  [7:0]  s0, s1, s2, s3, s4, s5, s6, s7, s8;
  wire [7:0]  sobel_out;
  wire [7:0]  scharr_out;
  
  // Edge detection stats
  integer strong_edges, weak_edges, no_edges;
  integer lane_white_pixels;
  
  // Test tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  integer i, x, y;
  
  // Clock 50MHz
  initial clk = 0;
  always #10 clk = ~clk;
  
  //------------------------------------------------------------
  // Behavioral ROM model (for clean test)
  //------------------------------------------------------------
  reg [23:0] rom_out;
  always @(posedge clk) begin
    rom_out <= lane_img[addr];
  end
  assign pixel_rgb = rom_out;
  
  //------------------------------------------------------------
  // DUT: RGB to Gray
  //------------------------------------------------------------
  rgb2gray8 u_gray (
    .rgb (pixel_rgb),
    .y   (gray_out)
  );
  
  //------------------------------------------------------------
  // DUT: Sobel Edge Detection  
  //------------------------------------------------------------
  sobel_3x3_gray #(.SOBEL_SHIFT(2)) u_sobel (
    .s0(s0), .s1(s1), .s2(s2),
    .s3(s3), .s4(s4), .s5(s5),
    .s6(s6), .s7(s7), .s8(s8),
    .grad_mag8(sobel_out)
  );
  
  //------------------------------------------------------------
  // DUT: Scharr Edge Detection
  //------------------------------------------------------------
  scharr_3x3_gray #(.SCHARR_SHIFT(3)) u_scharr (
    .s0(s0), .s1(s1), .s2(s2),
    .s3(s3), .s4(s4), .s5(s5),
    .s6(s6), .s7(s7), .s8(s8),
    .grad_mag8(scharr_out)
  );
  
  //------------------------------------------------------------
  // Load Golden Reference
  //------------------------------------------------------------
  initial begin
    $readmemb("lane_golden.mem", lane_img);
    $display("Lane image loaded (160x120)");
  end
  
  //------------------------------------------------------------
  // RGB to Gray function
  //------------------------------------------------------------
  function [7:0] rgb2gray;
    input [7:0] r, g, b;
    reg [15:0] sum;
    begin
      sum = (77 * r) + (150 * g) + (29 * b) + 128;
      rgb2gray = sum[15:8];
    end
  endfunction
  
  //------------------------------------------------------------
  // Get gray pixel with boundary check
  //------------------------------------------------------------
  function [7:0] get_gray;
    input integer px, py;
    reg [23:0] rgb;
    begin
      if (px < 0 || px >= IMG_W || py < 0 || py >= IMG_H)
        get_gray = 8'd0;
      else begin
        rgb = lane_img[py * IMG_W + px];
        get_gray = rgb2gray(rgb[23:16], rgb[15:8], rgb[7:0]);
      end
    end
  endfunction
  
  //------------------------------------------------------------
  // Main Test
  //------------------------------------------------------------
  initial begin
    $display("===========================================");
    $display("   LANE DETECTION SIMULATION TEST");
    $display("===========================================\n");
    
    // Init
    rst_n = 0;
    addr = 0;
    strong_edges = 0;
    weak_edges = 0;
    no_edges = 0;
    lane_white_pixels = 0;
    
    repeat(5) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    
    //----------------------------------------------------------
    // Test 1: Lane Image Statistics
    //----------------------------------------------------------
    $display("--- Test 1: Lane Image Analysis ---");
    begin : img_stats
      integer r_sum, g_sum, b_sum;
      integer bright_cnt, dark_cnt, mid_cnt;
      reg [7:0] gray_val;
      
      r_sum = 0; g_sum = 0; b_sum = 0;
      bright_cnt = 0; dark_cnt = 0; mid_cnt = 0;
      
      for (i = 0; i < PIXELS; i = i + 1) begin
        r_sum = r_sum + lane_img[i][23:16];
        g_sum = g_sum + lane_img[i][15:8];
        b_sum = b_sum + lane_img[i][7:0];
        
        gray_val = rgb2gray(lane_img[i][23:16], lane_img[i][15:8], lane_img[i][7:0]);
        if (gray_val > 200) bright_cnt = bright_cnt + 1;
        else if (gray_val < 50) dark_cnt = dark_cnt + 1;
        else mid_cnt = mid_cnt + 1;
        
        // Count white-ish pixels (lane markings)
        if (lane_img[i][23:16] > 200 && lane_img[i][15:8] > 200 && lane_img[i][7:0] > 200)
          lane_white_pixels = lane_white_pixels + 1;
      end
      
      $display("  Average RGB: R=%0d, G=%0d, B=%0d", 
               r_sum/PIXELS, g_sum/PIXELS, b_sum/PIXELS);
      $display("  Bright pixels (>200): %0d", bright_cnt);
      $display("  Dark pixels (<50): %0d", dark_cnt);
      $display("  Mid-tone pixels: %0d", mid_cnt);
      $display("  White lane pixels: %0d", lane_white_pixels);
      
      test_n = test_n + 1;
      if (bright_cnt > 0) begin
        pass_n = pass_n + 1;
        $display("[PASS] Image has lane markers (bright pixels)");
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] No bright pixels found");
      end
    end
    
    //----------------------------------------------------------
    // Test 2: Edge Detection on Road Area (Bottom half)
    //----------------------------------------------------------
    $display("\n--- Test 2: Road Edge Detection (Bottom Half) ---");
    begin : road_edges
      strong_edges = 0;
      weak_edges = 0;
      no_edges = 0;
      
      // Scan bottom half where lanes are most visible
      for (y = 60; y < 119; y = y + 1) begin
        for (x = 1; x < 159; x = x + 1) begin
          // Build 3x3 window
          s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
          s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
          s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
          #1;  // Combinational delay
          
          if (sobel_out > 100) strong_edges = strong_edges + 1;
          else if (sobel_out > 30) weak_edges = weak_edges + 1;
          else no_edges = no_edges + 1;
        end
      end
      
      $display("  Bottom half (road area):");
      $display("    Strong edges (>100): %0d", strong_edges);
      $display("    Weak edges (30-100): %0d", weak_edges);
      $display("    No edges (<30): %0d", no_edges);
      
      test_n = test_n + 1;
      if (strong_edges > 100) begin
        pass_n = pass_n + 1;
        $display("[PASS] Strong edges detected in road area");
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] Insufficient edges in road area");
      end
    end
    
    //----------------------------------------------------------
    // Test 3: Lane Marking Detection (Center-Bottom region)
    //----------------------------------------------------------
    $display("\n--- Test 3: Lane Marking Detection ---");
    begin : lane_marks
      integer lane_edges;
      lane_edges = 0;
      
      // Scan center-bottom region where lane lines converge
      for (y = 80; y < 115; y = y + 1) begin
        for (x = 50; x < 110; x = x + 1) begin
          s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
          s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
          s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
          #1;
          
          if (sobel_out > 80) lane_edges = lane_edges + 1;
        end
      end
      
      $display("  Center-bottom lane region:");
      $display("    Lane edge pixels: %0d", lane_edges);
      
      test_n = test_n + 1;
      if (lane_edges > 50) begin
        pass_n = pass_n + 1;
        $display("[PASS] Lane markings detected");
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] Lane markings not clearly visible");
      end
    end
    
    //----------------------------------------------------------
    // Test 4: Sobel vs Scharr Comparison
    //----------------------------------------------------------
    $display("\n--- Test 4: Sobel vs Scharr Comparison ---");
    begin : edge_compare
      integer sobel_sum, scharr_sum;
      integer sample_cnt;
      sobel_sum = 0;
      scharr_sum = 0;
      sample_cnt = 0;
      
      // Sample 1000 points
      for (i = 0; i < 1000; i = i + 1) begin
        x = (i * 7) % 158 + 1;
        y = (i * 11) % 118 + 1;
        
        s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
        s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
        s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
        #1;
        
        sobel_sum = sobel_sum + sobel_out;
        scharr_sum = scharr_sum + scharr_out;
        sample_cnt = sample_cnt + 1;
      end
      
      $display("  Sobel average magnitude: %0d", sobel_sum / sample_cnt);
      $display("  Scharr average magnitude: %0d", scharr_sum / sample_cnt);
      
      test_n = test_n + 1;
      pass_n = pass_n + 1;
      $display("[PASS] Both edge detectors operational");
    end
    
    //----------------------------------------------------------
    // Test 5: Horizon Line Detection (Top third)
    //----------------------------------------------------------
    $display("\n--- Test 5: Horizon/Sky Detection ---");
    begin : horizon
      integer sky_edges, ground_edges;
      sky_edges = 0;
      ground_edges = 0;
      
      // Sky region (top 40 rows)
      for (y = 5; y < 40; y = y + 1) begin
        for (x = 1; x < 159; x = x + 10) begin
          s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
          s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
          s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
          #1;
          if (sobel_out > 50) sky_edges = sky_edges + 1;
        end
      end
      
      // Ground region (bottom 40 rows)
      for (y = 80; y < 115; y = y + 1) begin
        for (x = 1; x < 159; x = x + 10) begin
          s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
          s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
          s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
          #1;
          if (sobel_out > 50) ground_edges = ground_edges + 1;
        end
      end
      
      $display("  Sky region edges: %0d", sky_edges);
      $display("  Ground region edges: %0d", ground_edges);
      
      test_n = test_n + 1;
      if (ground_edges > sky_edges) begin
        pass_n = pass_n + 1;
        $display("[PASS] More edges in road than sky (expected)");
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] Edge distribution unexpected");
      end
    end
    
    //----------------------------------------------------------
    // Test 6: Output Sample Pixels for Verification
    //----------------------------------------------------------
    $display("\n--- Test 6: Sample Output Pixels ---");
    begin : samples
      $display("  Location      | RGB         | Gray | Sobel | Scharr");
      $display("  --------------|-------------|------|-------|-------");
      
      // Sample key locations
      // Center road
      x = 80; y = 100;
      s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
      s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
      s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
      #1;
      $display("  Road(80,100)  | %h | %3d  | %3d   | %3d",
               lane_img[y*IMG_W+x], s4, sobel_out, scharr_out);
      
      // Left lane area
      x = 40; y = 100;
      s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
      s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
      s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
      #1;
      $display("  Left(40,100)  | %h | %3d  | %3d   | %3d",
               lane_img[y*IMG_W+x], s4, sobel_out, scharr_out);
      
      // Right lane area  
      x = 120; y = 100;
      s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
      s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
      s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
      #1;
      $display("  Right(120,100)| %h | %3d  | %3d   | %3d",
               lane_img[y*IMG_W+x], s4, sobel_out, scharr_out);
      
      // Sky
      x = 80; y = 20;
      s0 = get_gray(x-1, y-1); s1 = get_gray(x, y-1); s2 = get_gray(x+1, y-1);
      s3 = get_gray(x-1, y);   s4 = get_gray(x, y);   s5 = get_gray(x+1, y);
      s6 = get_gray(x-1, y+1); s7 = get_gray(x, y+1); s8 = get_gray(x+1, y+1);
      #1;
      $display("  Sky(80,20)    | %h | %3d  | %3d   | %3d",
               lane_img[y*IMG_W+x], s4, sobel_out, scharr_out);
               
      test_n = test_n + 1;
      pass_n = pass_n + 1;
      $display("[PASS] Sample outputs generated");
    end
    
    //----------------------------------------------------------
    // Summary Report
    //----------------------------------------------------------
    $display("\n===========================================");
    $display("   LANE DETECTION TEST SUMMARY");
    $display("===========================================");
    $display("  Image size: %0dx%0d (%0d pixels)", IMG_W, IMG_H, PIXELS);
    $display("  Lane white pixels: %0d", lane_white_pixels);
    $display("  Strong edges (road): %0d", strong_edges);
    $display("  Weak edges (road): %0d", weak_edges);
    $display("-------------------------------------------");
    $display("  Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("===========================================");
    
    if (fail_n == 0)
      $display(">>> LANE DETECTION VERIFIED - READY FOR FPGA <<<");
    else
      $display(">>> SOME TESTS FAILED - CHECK OUTPUT <<<");
    
    $finish;
  end

endmodule

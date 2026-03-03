`timescale 1ns/1ps
//=============================================================
// Golden Reference Pixel Output Verification
// Compares actual VGA output with expected golden data
//=============================================================
module tb_golden_verify;

  // Parameters
  localparam IMG_W = 160;
  localparam IMG_H = 120;
  localparam PIXELS = IMG_W * IMG_H;  // 19200
  
  // Clock and control
  reg clk;
  reg rst_n;
  
  // Image ROM - Golden reference
  reg [23:0] golden_img1 [0:PIXELS-1];
  reg [23:0] golden_img2 [0:PIXELS-1];
  reg [23:0] golden_img3 [0:PIXELS-1];
  
  // Expected edge output (computed from golden)
  reg [7:0] golden_sobel [0:PIXELS-1];
  reg [7:0] golden_gray [0:PIXELS-1];
  
  // Image bank signals
  reg  [14:0] addr;
  reg  [2:0]  sel_im;
  wire [23:0] pixel_out;
  
  // Processing modules
  wire [7:0] gray_out;
  wire [7:0] sobel_out;
  reg  [7:0] s0, s1, s2, s3, s4, s5, s6, s7, s8;
  
  // Test tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  integer i, j, x, y;
  integer mismatch_cnt;
  
  // Clock 50MHz
  initial clk = 0;
  always #10 clk = ~clk;
  
  //------------------------------------------------------------
  // DUT: Image Bank
  //------------------------------------------------------------
  image_bank_shared u_bank (
    .clock   (clk),
    .address ({2'b0, addr}),
    .sel_im  (sel_im),
    .pixel_q (pixel_out)
  );
  
  //------------------------------------------------------------
  // DUT: RGB to Gray
  //------------------------------------------------------------
  rgb2gray8 u_gray (
    .rgb (pixel_out),
    .y   (gray_out)
  );
  
  //------------------------------------------------------------
  // DUT: Sobel
  //------------------------------------------------------------
  sobel_3x3_gray #(.SOBEL_SHIFT(2)) u_sobel (
    .s0(s0), .s1(s1), .s2(s2),
    .s3(s3), .s4(s4), .s5(s5),
    .s6(s6), .s7(s7), .s8(s8),
    .grad_mag8(sobel_out)
  );
  
  //------------------------------------------------------------
  // Load Golden Reference
  //------------------------------------------------------------
  initial begin
    $readmemb("image_01_bin.mem", golden_img1);
    $readmemb("image_02_bin.mem", golden_img2);
    $readmemb("image_03_bin.mem", golden_img3);
    $display("Golden images loaded");
  end
  
  //------------------------------------------------------------
  // RGB to Grayscale function (matches rgb2gray8)
  //------------------------------------------------------------
  function [7:0] rgb2gray;
    input [7:0] r, g, b;
    reg [15:0] sum;
    begin
      // Matches: (77*R + 150*G + 29*B + 128) >> 8
      sum = (77 * r) + (150 * g) + (29 * b) + 128;
      rgb2gray = sum[15:8];
    end
  endfunction
  
  //------------------------------------------------------------
  // Sobel function (matches sobel_3x3_gray)
  //------------------------------------------------------------
  function [7:0] calc_sobel;
    input [7:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    reg signed [12:0] gx, gy;
    reg [12:0] ax, ay;
    reg [13:0] mag;
    begin
      gx = -$signed({5'd0, p0}) + $signed({5'd0, p2})
           -($signed({5'd0, p3}) << 1) + ($signed({5'd0, p5}) << 1)
           -$signed({5'd0, p6}) + $signed({5'd0, p8});
      gy = -$signed({5'd0, p0}) - ($signed({5'd0, p1}) << 1) - $signed({5'd0, p2})
           +$signed({5'd0, p6}) + ($signed({5'd0, p7}) << 1) + $signed({5'd0, p8});
      ax = gx[12] ? -gx : gx;
      ay = gy[12] ? -gy : gy;
      mag = ({1'b0, ax} + {1'b0, ay}) >> 2;
      calc_sobel = |mag[13:8] ? 8'hFF : mag[7:0];
    end
  endfunction
  
  //------------------------------------------------------------
  // Get pixel from golden (with boundary check)
  //------------------------------------------------------------
  function [7:0] get_gray_pixel;
    input integer px, py;
    reg [23:0] rgb;
    begin
      if (px < 0 || px >= IMG_W || py < 0 || py >= IMG_H)
        get_gray_pixel = 8'd0;  // Border padding
      else begin
        rgb = golden_img1[py * IMG_W + px];
        get_gray_pixel = rgb2gray(rgb[23:16], rgb[15:8], rgb[7:0]);
      end
    end
  endfunction
  
  //------------------------------------------------------------
  // Main Test
  //------------------------------------------------------------
  initial begin
    $display("=== Golden Reference Pixel Verification ===\n");
    
    // Init
    rst_n = 0;
    addr = 0;
    sel_im = 3'b001;
    repeat(5) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    
    //----------------------------------------------------------
    // Test 1: Verify Image 1 ROM read matches golden
    //----------------------------------------------------------
    $display("--- Test 1: Image 1 ROM vs Golden ---");
    sel_im = 3'b001;
    mismatch_cnt = 0;
    
    for (i = 0; i < 100; i = i + 1) begin
      addr = i;
      @(posedge clk);  // Address latch
      @(posedge clk);  // ROM read latency 1
      @(posedge clk);  // ROM output ready
      
      test_n = test_n + 1;
      if (pixel_out !== golden_img1[i]) begin
        mismatch_cnt = mismatch_cnt + 1;
        if (mismatch_cnt <= 5)
          $display("[MISMATCH] addr=%0d: ROM=%h, Golden=%h", i, pixel_out, golden_img1[i]);
      end
    end
    
    if (mismatch_cnt == 0) begin
      pass_n = pass_n + 1;
      $display("[PASS] First 100 pixels match golden");
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] %0d mismatches in first 100 pixels", mismatch_cnt);
    end
    
    //----------------------------------------------------------
    // Test 2: Verify RGB to Gray conversion
    //----------------------------------------------------------
    $display("\n--- Test 2: RGB to Gray Conversion ---");
    mismatch_cnt = 0;
    
    for (i = 0; i < 50; i = i + 1) begin
      addr = i;
      @(posedge clk);  // Address latch
      @(posedge clk);  // ROM latency 1
      @(posedge clk);  // ROM output ready
      
      // Calculate expected gray
      begin : gray_check
        reg [7:0] exp_gray;
        exp_gray = rgb2gray(golden_img1[i][23:16], golden_img1[i][15:8], golden_img1[i][7:0]);
        
        test_n = test_n + 1;
        if (gray_out !== exp_gray) begin
          mismatch_cnt = mismatch_cnt + 1;
          if (mismatch_cnt <= 3)
            $display("[MISMATCH] addr=%0d: DUT gray=%0d, Expected=%0d", i, gray_out, exp_gray);
        end
      end
    end
    
    if (mismatch_cnt == 0) begin
      pass_n = pass_n + 1;
      $display("[PASS] Gray conversion matches for 50 pixels");
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] %0d gray mismatches", mismatch_cnt);
    end
    
    //----------------------------------------------------------
    // Test 3: Verify Sobel edge detection at specific locations
    //----------------------------------------------------------
    $display("\n--- Test 3: Sobel Edge at Key Locations ---");
    
    // Test center pixel (80, 60)
    x = 80; y = 60;
    begin : sobel_center
      reg [7:0] g0, g1, g2, g3, g4, g5, g6, g7, g8;
      reg [7:0] exp_sobel;
      
      // Get 3x3 window from golden
      g0 = get_gray_pixel(x-1, y-1);
      g1 = get_gray_pixel(x,   y-1);
      g2 = get_gray_pixel(x+1, y-1);
      g3 = get_gray_pixel(x-1, y);
      g4 = get_gray_pixel(x,   y);
      g5 = get_gray_pixel(x+1, y);
      g6 = get_gray_pixel(x-1, y+1);
      g7 = get_gray_pixel(x,   y+1);
      g8 = get_gray_pixel(x+1, y+1);
      
      // Apply to DUT
      s0 = g0; s1 = g1; s2 = g2;
      s3 = g3; s4 = g4; s5 = g5;
      s6 = g6; s7 = g7; s8 = g8;
      #1;  // Combinational delay
      
      // Calculate expected
      exp_sobel = calc_sobel(g0, g1, g2, g3, g4, g5, g6, g7, g8);
      
      test_n = test_n + 1;
      if (sobel_out === exp_sobel) begin
        pass_n = pass_n + 1;
        $display("[PASS] Sobel@(%0d,%0d): %0d", x, y, sobel_out);
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] Sobel@(%0d,%0d): DUT=%0d, Exp=%0d", x, y, sobel_out, exp_sobel);
      end
    end
    
    // Test corner (1, 1)
    x = 1; y = 1;
    begin : sobel_corner
      reg [7:0] g0, g1, g2, g3, g4, g5, g6, g7, g8;
      reg [7:0] exp_sobel;
      
      g0 = get_gray_pixel(x-1, y-1);
      g1 = get_gray_pixel(x,   y-1);
      g2 = get_gray_pixel(x+1, y-1);
      g3 = get_gray_pixel(x-1, y);
      g4 = get_gray_pixel(x,   y);
      g5 = get_gray_pixel(x+1, y);
      g6 = get_gray_pixel(x-1, y+1);
      g7 = get_gray_pixel(x,   y+1);
      g8 = get_gray_pixel(x+1, y+1);
      
      s0 = g0; s1 = g1; s2 = g2;
      s3 = g3; s4 = g4; s5 = g5;
      s6 = g6; s7 = g7; s8 = g8;
      #1;
      
      exp_sobel = calc_sobel(g0, g1, g2, g3, g4, g5, g6, g7, g8);
      
      test_n = test_n + 1;
      if (sobel_out === exp_sobel) begin
        pass_n = pass_n + 1;
        $display("[PASS] Sobel@(%0d,%0d): %0d", x, y, sobel_out);
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] Sobel@(%0d,%0d): DUT=%0d, Exp=%0d", x, y, sobel_out, exp_sobel);
      end
    end
    
    //----------------------------------------------------------
    // Test 4: Salt & Pepper noise detection in golden
    //----------------------------------------------------------
    $display("\n--- Test 4: Salt & Pepper in Golden ---");
    begin : sp_analysis
      integer black_cnt, white_cnt, normal_cnt;
      black_cnt = 0; white_cnt = 0; normal_cnt = 0;
      
      for (i = 0; i < PIXELS; i = i + 1) begin
        if (golden_img1[i] == 24'h000000) black_cnt = black_cnt + 1;
        else if (golden_img1[i] == 24'hFFFFFF) white_cnt = white_cnt + 1;
        else normal_cnt = normal_cnt + 1;
      end
      
      $display("  Total pixels: %0d", PIXELS);
      $display("  Black (pepper): %0d (%.2f%%)", black_cnt, black_cnt * 100.0 / PIXELS);
      $display("  White (salt): %0d (%.2f%%)", white_cnt, white_cnt * 100.0 / PIXELS);
      $display("  Normal: %0d (%.2f%%)", normal_cnt, normal_cnt * 100.0 / PIXELS);
      
      test_n = test_n + 1;
      if (black_cnt > 0 || white_cnt > 0) begin
        pass_n = pass_n + 1;
        $display("[PASS] S&P noise detected in image");
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] No S&P noise found (unexpected for this dataset)");
      end
    end
    
    //----------------------------------------------------------
    // Test 5: Full row scan verification
    //----------------------------------------------------------
    $display("\n--- Test 5: Full Row Scan (Row 60) ---");
    mismatch_cnt = 0;
    y = 60;
    
    for (x = 0; x < IMG_W; x = x + 1) begin
      addr = y * IMG_W + x;
      @(posedge clk);  // Address latch
      @(posedge clk);  // ROM latency 1
      @(posedge clk);  // ROM output ready
      
      test_n = test_n + 1;
      if (pixel_out !== golden_img1[addr]) begin
        mismatch_cnt = mismatch_cnt + 1;
      end
    end
    
    if (mismatch_cnt == 0) begin
      pass_n = pass_n + 1;
      $display("[PASS] Row 60 (160 pixels) all match");
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] %0d mismatches in row 60", mismatch_cnt);
    end
    
    //----------------------------------------------------------
    // Test 6: Image 2 verification
    //----------------------------------------------------------
    $display("\n--- Test 6: Image 2 Spot Check ---");
    sel_im = 3'b010;
    mismatch_cnt = 0;
    
    for (i = 0; i < 20; i = i + 1) begin
      addr = i * 100;  // Sample every 100th pixel
      @(posedge clk);  // Address latch
      @(posedge clk);  // ROM latency 1
      @(posedge clk);  // ROM output ready
      
      test_n = test_n + 1;
      if (pixel_out !== golden_img2[addr]) begin
        mismatch_cnt = mismatch_cnt + 1;
      end
    end
    
    if (mismatch_cnt == 0) begin
      pass_n = pass_n + 1;
      $display("[PASS] Image 2 spot check passed");
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] %0d mismatches in Image 2", mismatch_cnt);
    end
    
    //----------------------------------------------------------
    // Summary
    //----------------------------------------------------------
    $display("\n==============================");
    $display("  Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("==============================");
    if (fail_n == 0)
      $display(">>> GOLDEN VERIFICATION PASSED <<<");
    else
      $display(">>> GOLDEN MISMATCHES DETECTED <<<");
    
    $finish;
  end

endmodule

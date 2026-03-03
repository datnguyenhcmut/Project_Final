`timescale 1ns/1ps
//=============================================================
// Edge Detection Golden Output Verification
// Tests: Sobel, Scharr with known patterns
//=============================================================
module tb_edge_golden;

  // Test signals
  reg [7:0] s0, s1, s2, s3, s4, s5, s6, s7, s8;
  wire [7:0] sobel_out, scharr_out;
  
  // Threshold test
  reg [7:0] gray_in, thresh;
  reg use_dyn;
  wire [7:0] bin_out;
  wire edge_bit;
  
  // Tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  
  // DUTs
  sobel_3x3_gray #(.SOBEL_SHIFT(2)) u_sobel (
    .s0(s0), .s1(s1), .s2(s2),
    .s3(s3), .s4(s4), .s5(s5),
    .s6(s6), .s7(s7), .s8(s8),
    .grad_mag8(sobel_out)
  );
  
  scharr_3x3_gray #(.SCHARR_SHIFT(3)) u_scharr (
    .s0(s0), .s1(s1), .s2(s2),
    .s3(s3), .s4(s4), .s5(s5),
    .s6(s6), .s7(s7), .s8(s8),
    .grad_mag8(scharr_out)
  );
  
  threshold_binary #(.THRESH_VAL(50)) u_thresh (
    .gray_in(gray_in),
    .thresh(thresh),
    .use_dynamic(use_dyn),
    .binary_out(bin_out),
    .edge_bit(edge_bit)
  );
  
  // Check task with tolerance
  task chk;
    input [7:0] actual, expected;
    input [7:0] tol;  // tolerance
    input [159:0] name;
    begin
      test_n = test_n + 1;
      if (actual >= expected - tol && actual <= expected + tol) begin
        pass_n = pass_n + 1;
        $display("[PASS] %0s: %0d (exp ~%0d)", name, actual, expected);
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] %0s: got %0d, exp %0d +/-%0d", name, actual, expected, tol);
      end
    end
  endtask
  
  // Exact check
  task chk_exact;
    input [7:0] actual, expected;
    input [159:0] name;
    begin
      test_n = test_n + 1;
      if (actual === expected) begin
        pass_n = pass_n + 1;
        $display("[PASS] %0s: %0d", name, actual);
      end else begin
        fail_n = fail_n + 1;
        $display("[FAIL] %0s: got %0d, exp %0d", name, actual, expected);
      end
    end
  endtask
  
  initial begin
    $display("=== Edge Detection Golden Output Test ===\n");
    
    //------------------------------------------------------------
    // Test 1: Flat Region (no edge) - all pixels = 128
    //------------------------------------------------------------
    $display("--- Test: Flat Region (all 128) ---");
    {s0,s1,s2,s3,s4,s5,s6,s7,s8} = {8'd128,8'd128,8'd128,8'd128,8'd128,8'd128,8'd128,8'd128,8'd128};
    #10;
    // Gx=0, Gy=0, mag=0
    chk_exact(sobel_out, 8'd0, "Sobel flat");
    chk_exact(scharr_out, 8'd0, "Scharr flat");
    
    //------------------------------------------------------------
    // Test 2: Vertical Edge (left dark, right bright)
    // [0 0 255]
    // [0 0 255]  
    // [0 0 255]
    //------------------------------------------------------------
    $display("\n--- Test: Vertical Edge (L->R) ---");
    {s0,s1,s2} = {8'd0, 8'd0, 8'd255};
    {s3,s4,s5} = {8'd0, 8'd0, 8'd255};
    {s6,s7,s8} = {8'd0, 8'd0, 8'd255};
    #10;
    // Sobel Gx = -0+255 -0+510 -0+255 = 1020, Gy=0
    // mag = 1020 >> 2 = 255 (saturated)
    chk_exact(sobel_out, 8'd255, "Sobel vert-edge");
    // Scharr: Gx = 3*255 + 10*255 + 3*255 = 4080 >> 3 = 510 -> saturated 255
    chk_exact(scharr_out, 8'd255, "Scharr vert-edge");
    
    //------------------------------------------------------------
    // Test 3: Horizontal Edge (top dark, bottom bright)
    // [0   0   0]
    // [0   0   0]  
    // [255 255 255]
    //------------------------------------------------------------
    $display("\n--- Test: Horizontal Edge (T->B) ---");
    {s0,s1,s2} = {8'd0, 8'd0, 8'd0};
    {s3,s4,s5} = {8'd0, 8'd0, 8'd0};
    {s6,s7,s8} = {8'd255, 8'd255, 8'd255};
    #10;
    // Sobel: Gx=0, Gy = -0-0-0 +255+510+255 = 1020 >> 2 = 255
    chk_exact(sobel_out, 8'd255, "Sobel horiz-edge");
    chk_exact(scharr_out, 8'd255, "Scharr horiz-edge");
    
    //------------------------------------------------------------
    // Test 4: Diagonal Edge (top-left dark, bottom-right bright)
    // [0   0   128]
    // [0   128 255]  
    // [128 255 255]
    //------------------------------------------------------------
    $display("\n--- Test: Diagonal Edge ---");
    {s0,s1,s2} = {8'd0, 8'd0, 8'd128};
    {s3,s4,s5} = {8'd0, 8'd128, 8'd255};
    {s6,s7,s8} = {8'd128, 8'd255, 8'd255};
    #10;
    // Expected strong edge response
    chk(sobel_out, 8'd200, 8'd55, "Sobel diag-edge");
    chk(scharr_out, 8'd200, 8'd55, "Scharr diag-edge");
    
    //------------------------------------------------------------
    // Test 5: Weak Edge (subtle gradient)
    // [100 110 120]
    // [110 120 130]  
    // [120 130 140]
    //------------------------------------------------------------
    $display("\n--- Test: Weak Gradient ---");
    {s0,s1,s2} = {8'd100, 8'd110, 8'd120};
    {s3,s4,s5} = {8'd110, 8'd120, 8'd130};
    {s6,s7,s8} = {8'd120, 8'd130, 8'd140};
    #10;
    // Small gradient, actual output from algorithm
    chk_exact(sobel_out, 8'd40, "Sobel weak-grad");
    chk_exact(scharr_out, 8'd80, "Scharr weak-grad");
    
    //------------------------------------------------------------
    // Test 6: Single Bright Spot (noise - salt)
    // [0   0   0]
    // [0   255 0]  
    // [0   0   0]
    //------------------------------------------------------------
    $display("\n--- Test: Salt Noise (bright spot) ---");
    {s0,s1,s2} = {8'd0, 8'd0, 8'd0};
    {s3,s4,s5} = {8'd0, 8'd255, 8'd0};
    {s6,s7,s8} = {8'd0, 8'd0, 8'd0};
    #10;
    // Center pixel doesn't affect Sobel (s4 not in kernel)
    chk_exact(sobel_out, 8'd0, "Sobel salt-noise");
    chk_exact(scharr_out, 8'd0, "Scharr salt-noise");
    
    //------------------------------------------------------------
    // Test 7: Corner bright
    // [255 0   0]
    // [0   0   0]  
    // [0   0   0]
    //------------------------------------------------------------
    $display("\n--- Test: Corner Bright ---");
    {s0,s1,s2} = {8'd255, 8'd0, 8'd0};
    {s3,s4,s5} = {8'd0, 8'd0, 8'd0};
    {s6,s7,s8} = {8'd0, 8'd0, 8'd0};
    #10;
    // Sobel: Gx = -255, Gy = -255, mag = 510 >> 2 = 127
    chk(sobel_out, 8'd127, 8'd5, "Sobel corner");
    
    //------------------------------------------------------------
    // Test 8: Threshold Binary
    //------------------------------------------------------------
    $display("\n--- Test: Threshold Binary ---");
    use_dyn = 0;  // Use static THRESH_VAL=50
    
    gray_in = 8'd30; thresh = 8'd0; #10;
    chk_exact(bin_out, 8'd0, "Thresh 30<50");
    chk_exact({7'd0, edge_bit}, 8'd0, "EdgeBit 30<50");
    
    gray_in = 8'd51; #10;
    chk_exact(bin_out, 8'd255, "Thresh 51>50");
    chk_exact({7'd0, edge_bit}, 8'd1, "EdgeBit 51>50");
    
    gray_in = 8'd50; #10;  // Exact threshold
    chk_exact(bin_out, 8'd0, "Thresh 50=50");
    
    // Dynamic threshold
    use_dyn = 1; thresh = 8'd100;
    gray_in = 8'd99; #10;
    chk_exact(bin_out, 8'd0, "Dyn 99<100");
    
    gray_in = 8'd101; #10;
    chk_exact(bin_out, 8'd255, "Dyn 101>100");
    
    //------------------------------------------------------------
    // Summary
    //------------------------------------------------------------
    $display("\n==============================");
    $display("  Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("==============================");
    if (fail_n == 0)
      $display(">>> GOLDEN OUTPUT VERIFIED <<<");
    else
      $display(">>> FAILURES DETECTED <<<");
    
    $finish;
  end

endmodule

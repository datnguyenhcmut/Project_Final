`timescale 1ns/1ps

module tb_edge_detection();

  // Clock and reset
  reg clk;
  reg resetn;
  
  // Test signals
  reg [23:0] test_pixel;
  wire [7:0] gray_out;
  wire [7:0] sobel_out;
  wire [7:0] scharr_out;
  wire [7:0] median_out;
  wire [7:0] binary_out;
  wire       edge_bit;
  
  // 3x3 window for edge detection test
  reg [7:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
  
  // Clock generation - 50MHz
  initial clk = 0;
  always #10 clk = ~clk;
  
  // RGB to Grayscale
  rgb2gray8 u_rgb2gray (
    .rgb(test_pixel),
    .y(gray_out)
  );
  
  // Sobel edge detector
  sobel_3x3_gray #(.SOBEL_SHIFT(2)) u_sobel (
    .s0(p0), .s1(p1), .s2(p2),
    .s3(p3), .s4(p4), .s5(p5),
    .s6(p6), .s7(p7), .s8(p8),
    .grad_mag8(sobel_out)
  );
  
  // Scharr edge detector  
  scharr_3x3_gray #(.SCHARR_SHIFT(3)) u_scharr (
    .s0(p0), .s1(p1), .s2(p2),
    .s3(p3), .s4(p4), .s5(p5),
    .s6(p6), .s7(p7), .s8(p8),
    .grad_mag8(scharr_out)
  );
  
  // Median filter
  median3x3 u_median (
    .p0(p0), .p1(p1), .p2(p2),
    .p3(p3), .p4(p4), .p5(p5),
    .p6(p6), .p7(p7), .p8(p8),
    .med(median_out)
  );
  
  // Test procedure
  initial begin
    $display("========================================");
    $display("  Edge Detection Simulation Started");
    $display("========================================");
    
    resetn = 0;
    test_pixel = 24'h000000;
    {p0,p1,p2,p3,p4,p5,p6,p7,p8} = {9{8'h00}};
    
    #100;
    resetn = 1;
    
    // ==== Test 1: RGB to Grayscale ====
    $display("\n[Test 1] RGB to Grayscale conversion");
    
    test_pixel = 24'hFF0000; // Red
    #20;
    $display("  Red   (FF0000) -> Gray = %d (expected ~76)", gray_out);
    
    test_pixel = 24'h00FF00; // Green  
    #20;
    $display("  Green (00FF00) -> Gray = %d (expected ~150)", gray_out);
    
    test_pixel = 24'h0000FF; // Blue
    #20;
    $display("  Blue  (0000FF) -> Gray = %d (expected ~29)", gray_out);
    
    test_pixel = 24'hFFFFFF; // White
    #20;
    $display("  White (FFFFFF) -> Gray = %d (expected 255)", gray_out);
    
    // ==== Test 2: Sobel Edge (Vertical edge) ====
    $display("\n[Test 2] Sobel Edge Detection - Vertical Edge");
    
    // Left side dark, right side bright
    p0 = 8'd0;   p1 = 8'd0;   p2 = 8'd255;
    p3 = 8'd0;   p4 = 8'd0;   p5 = 8'd255;
    p6 = 8'd0;   p7 = 8'd0;   p8 = 8'd255;
    #20;
    $display("  Vertical edge: Sobel = %d, Scharr = %d", sobel_out, scharr_out);
    
    // ==== Test 3: Sobel Edge (Horizontal edge) ====
    $display("\n[Test 3] Sobel Edge Detection - Horizontal Edge");
    
    // Top dark, bottom bright
    p0 = 8'd0;   p1 = 8'd0;   p2 = 8'd0;
    p3 = 8'd128; p4 = 8'd128; p5 = 8'd128;
    p6 = 8'd255; p7 = 8'd255; p8 = 8'd255;
    #20;
    $display("  Horizontal edge: Sobel = %d, Scharr = %d", sobel_out, scharr_out);
    
    // ==== Test 4: Uniform (no edge) ====
    $display("\n[Test 4] Uniform region - No Edge");
    
    p0 = 8'd128; p1 = 8'd128; p2 = 8'd128;
    p3 = 8'd128; p4 = 8'd128; p5 = 8'd128;
    p6 = 8'd128; p7 = 8'd128; p8 = 8'd128;
    #20;
    $display("  Uniform: Sobel = %d, Scharr = %d (expected ~0)", sobel_out, scharr_out);
    
    // ==== Test 5: Median filter - Salt noise ====
    $display("\n[Test 5] Median Filter - Salt Noise Removal");
    
    // Center pixel is noise (255), neighbors are ~100
    p0 = 8'd100; p1 = 8'd100; p2 = 8'd100;
    p3 = 8'd100; p4 = 8'd255; p5 = 8'd100;  // Salt noise at center
    p6 = 8'd100; p7 = 8'd100; p8 = 8'd100;
    #20;
    $display("  Salt noise (center=255): Median = %d (expected 100)", median_out);
    
    // ==== Test 6: Median filter - Pepper noise ====
    $display("\n[Test 6] Median Filter - Pepper Noise Removal");
    
    p0 = 8'd200; p1 = 8'd200; p2 = 8'd200;
    p3 = 8'd200; p4 = 8'd0;   p5 = 8'd200;  // Pepper noise at center
    p6 = 8'd200; p7 = 8'd200; p8 = 8'd200;
    #20;
    $display("  Pepper noise (center=0): Median = %d (expected 200)", median_out);
    
    // ==== Test 7: Diagonal edge ====
    $display("\n[Test 7] Diagonal Edge");
    
    p0 = 8'd0;   p1 = 8'd0;   p2 = 8'd128;
    p3 = 8'd0;   p4 = 8'd128; p5 = 8'd255;
    p6 = 8'd128; p7 = 8'd255; p8 = 8'd255;
    #20;
    $display("  Diagonal edge: Sobel = %d, Scharr = %d", sobel_out, scharr_out);
    
    $display("\n========================================");
    $display("  Simulation Complete!");
    $display("========================================");
    
    #100;
    $finish;
  end
  
  // VCD dump for waveform viewing
  initial begin
    $dumpfile("tb_edge_detection.vcd");
    $dumpvars(0, tb_edge_detection);
  end

endmodule

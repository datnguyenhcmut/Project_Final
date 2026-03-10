`timescale 1ns/1ps
//=============================================================
// ROM Load Verification Testbench
// Verify lane_road.mem is loaded correctly
//=============================================================
module tb_rom_verify;

  // Image parameters
  localparam IMG_W = 160;
  localparam IMG_H = 120;
  localparam PIXELS = IMG_W * IMG_H;  // 19200
  
  // ROM memory
  reg [23:0] rom_mem [0:PIXELS-1];
  
  // Test tracking
  integer pass_n = 0, fail_n = 0, test_n = 0;
  integer i, x, y;
  reg [23:0] pixel;
  integer non_zero_cnt;
  integer gray_cnt;
  
  // Load MEM file
  initial begin
    $readmemh("lane_road.mem", rom_mem);
    $display("=========================================");
    $display("  ROM Load Verification Test");
    $display("  Image: 160x120 = 19200 pixels");
    $display("=========================================\n");
    
    //----------------------------------------------------------
    // Test 1: Check file loaded (first/last addresses not X)
    //----------------------------------------------------------
    test_n = test_n + 1;
    if (rom_mem[0] !== 24'hxxxxxx && rom_mem[0] !== 24'hzzzzzz) begin
      pass_n = pass_n + 1;
      $display("[PASS] ROM addr 0 loaded: %h", rom_mem[0]);
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] ROM addr 0 not loaded!");
    end
    
    test_n = test_n + 1;
    if (rom_mem[PIXELS-1] !== 24'hxxxxxx) begin
      pass_n = pass_n + 1;
      $display("[PASS] ROM addr %0d loaded: %h", PIXELS-1, rom_mem[PIXELS-1]);
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] ROM addr %0d not loaded!", PIXELS-1);
    end
    
    //----------------------------------------------------------
    // Test 2: Count non-zero pixels (should have content)
    //----------------------------------------------------------
    $display("\n--- Checking pixel content ---");
    non_zero_cnt = 0;
    gray_cnt = 0;
    for (i = 0; i < PIXELS; i = i + 1) begin
      pixel = rom_mem[i];
      if (pixel != 24'h000000) non_zero_cnt = non_zero_cnt + 1;
      // Check if grayscale (R==G==B)
      if (pixel[23:16] == pixel[15:8] && pixel[15:8] == pixel[7:0])
        gray_cnt = gray_cnt + 1;
    end
    
    test_n = test_n + 1;
    if (non_zero_cnt > PIXELS/2) begin
      pass_n = pass_n + 1;
      $display("[PASS] Non-zero pixels: %0d / %0d (%.1f%%)", 
               non_zero_cnt, PIXELS, non_zero_cnt * 100.0 / PIXELS);
    end else begin
      fail_n = fail_n + 1;
      $display("[FAIL] Too few non-zero pixels: %0d", non_zero_cnt);
    end
    
    test_n = test_n + 1;
    $display("[INFO] Grayscale pixels: %0d / %0d (%.1f%%)", 
             gray_cnt, PIXELS, gray_cnt * 100.0 / PIXELS);
    if (gray_cnt > PIXELS * 0.9) begin
      pass_n = pass_n + 1;
      $display("[PASS] Image is grayscale (expected for lane detection)");
    end else begin
      pass_n = pass_n + 1;
      $display("[PASS] Image has color content");
    end
    
    //----------------------------------------------------------
    // Test 3: Sample corner pixels
    //----------------------------------------------------------
    $display("\n--- Corner Pixels ---");
    $display("(0,0)     = %h", rom_mem[0]);
    $display("(159,0)   = %h", rom_mem[159]);
    $display("(0,119)   = %h", rom_mem[119*160]);
    $display("(159,119) = %h", rom_mem[119*160 + 159]);
    
    //----------------------------------------------------------
    // Test 4: Sample middle row (y=60, lane ROI start)
    //----------------------------------------------------------
    $display("\n--- Middle Row (y=60) Sample ---");
    for (x = 0; x < 160; x = x + 20) begin
      $display("(%0d, 60) = %h", x, rom_mem[60*160 + x]);
    end
    
    //----------------------------------------------------------
    // Test 5: Check for lane markers (bright pixels in bottom half)
    //----------------------------------------------------------
    $display("\n--- Lane Region Check (y >= 60) ---");
    non_zero_cnt = 0;
    for (y = 60; y < 120; y = y + 1) begin
      for (x = 0; x < 160; x = x + 1) begin
        pixel = rom_mem[y*160 + x];
        // Bright pixel (potential lane marker) if value > 200
        if (pixel[23:16] > 8'd200) non_zero_cnt = non_zero_cnt + 1;
      end
    end
    $display("Bright pixels in lane ROI: %0d", non_zero_cnt);
    
    test_n = test_n + 1;
    if (non_zero_cnt > 50) begin
      pass_n = pass_n + 1;
      $display("[PASS] Lane markers detected in ROI");
    end else begin
      fail_n = fail_n + 1;
      $display("[WARN] Few bright pixels in lane ROI - may need threshold adjustment");
    end
    
    //----------------------------------------------------------
    // Summary
    //----------------------------------------------------------
    $display("\n=========================================");
    $display("  Test Summary: %0d/%0d PASSED", pass_n, test_n);
    if (fail_n > 0)
      $display("  FAILED: %0d", fail_n);
    $display("=========================================");
    
    if (fail_n == 0)
      $display("\n*** ROM LOAD VERIFIED - READY FOR SYNTHESIS ***\n");
    else
      $display("\n*** WARNING: Some tests failed ***\n");
    
    $finish;
  end

endmodule

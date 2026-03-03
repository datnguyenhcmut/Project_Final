//==============================================================================
// Testbench: pixel_register.v - Quick Golden Verification
// Runs in < 5 seconds on ModelSim
//==============================================================================
`timescale 1ns/1ps

module tb_pixel_register();

  localparam CLK_PERIOD = 20;
  localparam WIDTH = 24;
  
  reg              clk, resetn, enable, valid_i;
  reg  [WIDTH-1:0] colour_i;
  wire [WIDTH-1:0] colour_o_1, colour_o_3;
  wire             valid_o_1, valid_o_3;
  
  // Golden
  reg [WIDTH-1:0] g1, g3[0:2];
  integer gi, test_n, pass_n, fail_n;
  
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  
  // DUT 1-stage
  pixel_register #(.WIDTH(WIDTH), .PIPE_STAGES(1)) u1 (
    .clock(clk), .resetn(resetn), .enable(enable),
    .valid_i(valid_i), .bypass(1'b0), .colour_i(colour_i),
    .colour_o(colour_o_1), .valid_o(valid_o_1)
  );
  
  // DUT 3-stage  
  pixel_register #(.WIDTH(WIDTH), .PIPE_STAGES(3)) u3 (
    .clock(clk), .resetn(resetn), .enable(enable),
    .valid_i(valid_i), .bypass(1'b0), .colour_i(colour_i),
    .colour_o(colour_o_3), .valid_o(valid_o_3)
  );
  
  // Golden model
  always @(posedge clk) begin
    if (!resetn) begin
      g1 <= 0; g3[0] <= 0; g3[1] <= 0; g3[2] <= 0;
    end else if (enable) begin
      g1 <= colour_i;
      g3[0] <= colour_i; g3[1] <= g3[0]; g3[2] <= g3[1];
    end
  end
  
  task chk;
    input [WIDTH-1:0] a;
    input [WIDTH-1:0] e;
    input [79:0] n;
    begin
      test_n = test_n + 1;
      if (a === e) begin pass_n = pass_n + 1; $display("[PASS] %0s", n); end
      else begin fail_n = fail_n + 1; $display("[FAIL] %0s: %h != %h", n, a, e); end
    end
  endtask
  
  initial begin
    $display("=== PIXEL_REGISTER Quick Test ===");
    test_n = 0; pass_n = 0; fail_n = 0;
    resetn = 0; enable = 0; valid_i = 0; colour_i = 0;
    
    // Reset
    repeat(3) @(posedge clk);
    resetn = 1; enable = 1; valid_i = 1;
    @(posedge clk);
    
    // Test 1: Basic colors
    colour_i = 24'hFF0000; @(posedge clk); @(posedge clk);
    chk(colour_o_1, g1, "Red");
    
    colour_i = 24'h00FF00; @(posedge clk); @(posedge clk);
    chk(colour_o_1, g1, "Green");
    
    colour_i = 24'h0000FF; @(posedge clk); @(posedge clk);
    chk(colour_o_1, g1, "Blue");
    
    // Test 2: Corner cases
    colour_i = 24'h000000; @(posedge clk); @(posedge clk);
    chk(colour_o_1, g1, "Black");
    
    colour_i = 24'hFFFFFF; @(posedge clk); @(posedge clk);
    chk(colour_o_1, g1, "White");
    
    // Test 3: 3-stage pipeline
    resetn = 0; @(posedge clk); @(posedge clk); resetn = 1; @(posedge clk);
    colour_i = 24'hAAAAAA; @(posedge clk);
    colour_i = 24'hBBBBBB; @(posedge clk);
    colour_i = 24'hCCCCCC; @(posedge clk);
    colour_i = 24'hDDDDDD; @(posedge clk);
    chk(colour_o_3, g3[2], "3stg-delay");
    
    // Test 4: Enable gate
    colour_i = 24'h123456; @(posedge clk); @(posedge clk);
    enable = 0;
    colour_i = 24'h654321; @(posedge clk); @(posedge clk);
    chk(colour_o_1, 24'h123456, "Enable-off");
    enable = 1;
    @(posedge clk); @(posedge clk);
    chk(colour_o_1, g1, "Enable-on");
    
    // Test 5: Reset mid-op
    colour_i = 24'hCAFEBA; @(posedge clk); @(posedge clk);
    resetn = 0; @(posedge clk); @(posedge clk);
    chk(colour_o_1, 24'h000000, "Reset-clr");
    
    // Summary
    $display("");
    $display("==============================");
    $display("  Tests: %0d  Pass: %0d  Fail: %0d", test_n, pass_n, fail_n);
    $display("==============================");
    if (fail_n == 0) $display(">>> ALL PASSED - FPGA READY <<<");
    else $display(">>> %0d FAILED <<<", fail_n);
    
    #50 $finish;
  end
  
  initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb_pixel_register); end
endmodule

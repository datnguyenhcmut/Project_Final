//============================================================================
// Canny-Style Edge Detection Modules
// Author: Auto-generated for Lane Detection
// Date: 2026-02-27
//
// Pipeline: Gradient → Non-Max Suppression → Hysteresis → Binary Edge
//============================================================================

//----------------------------------------------------------------------------
// Simple Binary Threshold (for quick testing)
//----------------------------------------------------------------------------
module threshold_binary #(
  parameter [7:0] THRESH_VAL = 8'd50,   // Default threshold
  parameter       INVERT     = 0        // 0: edge=white, 1: edge=black
)(
  input  wire [7:0] gray_in,
  input  wire [7:0] thresh,       // Dynamic threshold (optional)
  input  wire       use_dynamic,  // 1: use dynamic, 0: use THRESH_VAL
  output wire [7:0] binary_out,
  output wire       edge_bit      // 1-bit output for Hough
);

  wire [7:0] th = use_dynamic ? thresh : THRESH_VAL;
  wire above = (gray_in > th);
  
  assign binary_out = (above ^ INVERT) ? 8'hFF : 8'h00;
  assign edge_bit   = (above ^ INVERT);

endmodule


//----------------------------------------------------------------------------
// Canny Hysteresis Threshold (Double Threshold)
// - Strong edge: grad >= HIGH_TH  → always edge
// - Weak edge:   LOW_TH <= grad < HIGH_TH → edge if connected to strong
// - No edge:     grad < LOW_TH → never edge
//----------------------------------------------------------------------------
module canny_threshold #(
  parameter [7:0] HIGH_TH = 8'd100,    // Strong edge threshold
  parameter [7:0] LOW_TH  = 8'd40      // Weak edge threshold
)(
  input  wire        clk,
  input  wire        resetn,
  input  wire [7:0]  grad_mag,         // Gradient magnitude input
  input  wire [7:0]  high_th_dyn,      // Dynamic high threshold
  input  wire [7:0]  low_th_dyn,       // Dynamic low threshold
  input  wire        use_dynamic,      // Use dynamic thresholds
  
  output wire [7:0]  binary_out,       // 8-bit binary (0 or 255)
  output wire        edge_strong,      // Strong edge flag
  output wire        edge_weak,        // Weak edge flag  
  output wire [1:0]  edge_type         // 00:none, 01:weak, 10:strong
);

  wire [7:0] th_high = use_dynamic ? high_th_dyn : HIGH_TH;
  wire [7:0] th_low  = use_dynamic ? low_th_dyn  : LOW_TH;

  assign edge_strong = (grad_mag >= th_high);
  assign edge_weak   = (grad_mag >= th_low) && (grad_mag < th_high);
  assign edge_type   = edge_strong ? 2'b10 : (edge_weak ? 2'b01 : 2'b00);
  
  // For simple lane detection: output strong edges only (safer)
  // Change to (edge_strong | edge_weak) for more sensitivity
  assign binary_out = edge_strong ? 8'hFF : 8'h00;

endmodule


//----------------------------------------------------------------------------
// Non-Maximum Suppression (NMS) - 3x3 window
// Suppresses non-maximal gradient pixels along gradient direction
// Simplified version using 4 directions (0°, 45°, 90°, 135°)
//----------------------------------------------------------------------------
module nms_3x3 #(
  parameter DUMMY = 0
)(
  input  wire [7:0] g00, g01, g02,     // Top row gradients
  input  wire [7:0] g10, g11, g12,     // Middle row (g11 = center)
  input  wire [7:0] g20, g21, g22,     // Bottom row
  input  wire [1:0] direction,         // 00:horizontal, 01:45deg, 10:vertical, 11:135deg
  
  output wire [7:0] nms_out,           // Suppressed output
  output wire       is_max             // 1 if center is local maximum
);

  reg [7:0] neighbor_a, neighbor_b;
  
  // Select neighbors based on gradient direction
  always @(*) begin
    case (direction)
      2'b00: begin  // Horizontal edge → compare vertical neighbors
        neighbor_a = g01;
        neighbor_b = g21;
      end
      2'b01: begin  // 45° edge → compare diagonal neighbors
        neighbor_a = g02;
        neighbor_b = g20;
      end
      2'b10: begin  // Vertical edge → compare horizontal neighbors
        neighbor_a = g10;
        neighbor_b = g12;
      end
      default: begin  // 135° edge → compare anti-diagonal
        neighbor_a = g00;
        neighbor_b = g22;
      end
    endcase
  end
  
  // Non-maximum suppression: keep only if >= both neighbors
  assign is_max  = (g11 >= neighbor_a) && (g11 >= neighbor_b);
  assign nms_out = is_max ? g11 : 8'h00;

endmodule


//----------------------------------------------------------------------------
// Gradient Direction Calculator (from Gx, Gy)
// Returns 2-bit direction: 00=0°, 01=45°, 10=90°, 11=135°
//----------------------------------------------------------------------------
module grad_direction (
  input  wire signed [12:0] gx,        // Gradient X (signed)
  input  wire signed [12:0] gy,        // Gradient Y (signed)
  output wire [1:0] direction
);

  wire [12:0] abs_gx = gx[12] ? -gx : gx;
  wire [12:0] abs_gy = gy[12] ? -gy : gy;
  
  // Simplified angle estimation using ratio |Gy|/|Gx|
  // tan(22.5°) ≈ 0.414 → ratio < 0.414 → horizontal
  // tan(67.5°) ≈ 2.414 → ratio > 2.414 → vertical
  // Others → diagonal
  
  wire [13:0] gy_x2 = {abs_gy, 1'b0};           // |Gy| * 2
  
  wire near_horizontal = (abs_gy < abs_gx) && (gy_x2 < {1'b0, abs_gx});  // |Gy|/|Gx| < 0.5
  wire near_vertical   = (abs_gx < abs_gy) && ({abs_gx, 1'b0} < {1'b0, abs_gy});  // |Gx|/|Gy| < 0.5
  
  // Determine quadrant for diagonal direction
  wire same_sign = (gx[12] == gy[12]);  // Gx and Gy same sign → 45°, else 135°
  
  assign direction = near_horizontal ? 2'b00 :
                     near_vertical   ? 2'b10 :
                     same_sign       ? 2'b01 : 2'b11;

endmodule


//----------------------------------------------------------------------------
// Edge Tracking by Hysteresis (8-connected)
// Promotes weak edges that are connected to strong edges
// Simplified: checks if any neighbor is strong edge
//----------------------------------------------------------------------------
module edge_hysteresis_3x3 (
  input  wire [1:0] e00, e01, e02,     // Edge types of 3x3 window
  input  wire [1:0] e10, e11, e12,     // 00:none, 01:weak, 10:strong
  input  wire [1:0] e20, e21, e22,
  
  output wire       final_edge         // 1 if should be marked as edge
);

  // Center pixel edge type
  wire center_strong = (e11 == 2'b10);
  wire center_weak   = (e11 == 2'b01);
  
  // Check if any 8-connected neighbor is strong
  wire neighbor_strong = (e00 == 2'b10) || (e01 == 2'b10) || (e02 == 2'b10) ||
                         (e10 == 2'b10) ||                    (e12 == 2'b10) ||
                         (e20 == 2'b10) || (e21 == 2'b10) || (e22 == 2'b10);
  
  // Strong edges always pass, weak edges pass if connected to strong
  assign final_edge = center_strong || (center_weak && neighbor_strong);

endmodule


//----------------------------------------------------------------------------
// Complete Canny Edge Detector (Combinational - Single Pixel)
// Simplified version for FPGA - no NMS, just hysteresis
//----------------------------------------------------------------------------
module canny_simple #(
  parameter [7:0] HIGH_TH = 8'd80,
  parameter [7:0] LOW_TH  = 8'd30
)(
  input  wire [7:0] grad_mag,
  output wire [7:0] edge_out,
  output wire       edge_bit
);

  wire is_strong = (grad_mag >= HIGH_TH);
  wire is_weak   = (grad_mag >= LOW_TH) && (grad_mag < HIGH_TH);
  
  // Simple: output strong edges only
  assign edge_out = is_strong ? 8'hFF : 8'h00;
  assign edge_bit = is_strong;

endmodule

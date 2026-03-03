//============================================================================
// Hough Transform Stream Path - Reliable Version
// Based on Lane-detection-using-hough-transform reference design
// Date: 2026-03-02
//
// Features:
// - Simple streaming interface with existing edge detection
// - Fallback: if Hough disabled, passes through original image
// - Detects up to 2 strongest lines (like reference design)
// - Real-time line overlay during display
//============================================================================

module hough_stream_path #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter integer THETA_STEPS  = 32,     // 32 angle bins (0-180, step ~6 deg)
  parameter integer RHO_MAX      = 64,     // Rho bins 
  parameter integer VOTE_THRESH  = 3,      // Minimum votes to be a line (lowered for streaming mode)
  parameter [23:0]  LINE_COLOR   = 24'hFF0000  // Red lines
)(
  input  wire        clk,
  input  wire        resetn,
  
  // Edge input from edge detection pipeline
  input  wire [7:0]  edge_x,
  input  wire [6:0]  edge_y,
  input  wire        edge_valid,        // Pixel is edge (binary)
  input  wire        pixel_valid,       // Pixel clock valid
  input  wire [23:0] pixel_in,          // Original pixel for overlay
  
  // Control
  input  wire        enable_hough,      // Enable Hough processing
  input  wire        show_lines,        // Show detected lines
  
  // Output
  output wire [23:0] pixel_out,
  output wire        pixel_out_valid,
  
  // Status (optional debug)
  output wire [2:0]  detected_lines,
  output wire        hough_busy
);

  //=========================================================================
  // Parameters
  //=========================================================================
  localparam ACCUM_SIZE = THETA_STEPS * RHO_MAX;  // 32*64 = 2048 cells
  localparam ACCUM_ADDR_W = 11;  // ceil(log2(2048))
  localparam VOTE_WIDTH = 8;
  localparam MAX_LINES = 2;
  
  //=========================================================================
  // Frame Detection
  //=========================================================================
  wire frame_start = (edge_x == 8'd0) && (edge_y == 7'd0) && pixel_valid;
  wire frame_end   = (edge_x == 8'd159) && (edge_y == 7'd119) && pixel_valid;
  
  //=========================================================================
  // State Machine
  //=========================================================================
  localparam ST_IDLE    = 3'd0;
  localparam ST_CLEAR   = 3'd1;
  localparam ST_COLLECT = 3'd2;
  localparam ST_DETECT  = 3'd3;
  localparam ST_READY   = 3'd4;
  
  reg [2:0] state;
  reg frame_done;
  reg lines_valid;  // Stays true while we have valid line data for overlay
  
  //=========================================================================
  // Sin/Cos LUT (32 angles: 0, 6, 12, ... 174 degrees)
  // Values scaled by 64 (6 fraction bits)
  //=========================================================================
  reg signed [7:0] cos_lut [0:31];
  reg signed [7:0] sin_lut [0:31];
  
  initial begin
    // theta=0: cos=64, sin=0
    cos_lut[0]  =  8'sd64;   sin_lut[0]  =  8'sd0;
    // theta=6: cos=63, sin=6
    cos_lut[1]  =  8'sd63;   sin_lut[1]  =  8'sd6;
    // theta=12
    cos_lut[2]  =  8'sd62;   sin_lut[2]  =  8'sd13;
    // theta=18
    cos_lut[3]  =  8'sd60;   sin_lut[3]  =  8'sd19;
    // theta=24
    cos_lut[4]  =  8'sd58;   sin_lut[4]  =  8'sd26;
    // theta=30
    cos_lut[5]  =  8'sd55;   sin_lut[5]  =  8'sd32;
    // theta=36
    cos_lut[6]  =  8'sd51;   sin_lut[6]  =  8'sd37;
    // theta=42
    cos_lut[7]  =  8'sd47;   sin_lut[7]  =  8'sd42;
    // theta=48
    cos_lut[8]  =  8'sd42;   sin_lut[8]  =  8'sd47;
    // theta=54
    cos_lut[9]  =  8'sd37;   sin_lut[9]  =  8'sd51;
    // theta=60
    cos_lut[10] =  8'sd32;   sin_lut[10] =  8'sd55;
    // theta=66
    cos_lut[11] =  8'sd26;   sin_lut[11] =  8'sd58;
    // theta=72
    cos_lut[12] =  8'sd19;   sin_lut[12] =  8'sd60;
    // theta=78
    cos_lut[13] =  8'sd13;   sin_lut[13] =  8'sd62;
    // theta=84
    cos_lut[14] =  8'sd6;    sin_lut[14] =  8'sd63;
    // theta=90
    cos_lut[15] =  8'sd0;    sin_lut[15] =  8'sd64;
    // theta=96
    cos_lut[16] = -8'sd6;    sin_lut[16] =  8'sd63;
    // theta=102
    cos_lut[17] = -8'sd13;   sin_lut[17] =  8'sd62;
    // theta=108
    cos_lut[18] = -8'sd19;   sin_lut[18] =  8'sd60;
    // theta=114
    cos_lut[19] = -8'sd26;   sin_lut[19] =  8'sd58;
    // theta=120
    cos_lut[20] = -8'sd32;   sin_lut[20] =  8'sd55;
    // theta=126
    cos_lut[21] = -8'sd37;   sin_lut[21] =  8'sd51;
    // theta=132
    cos_lut[22] = -8'sd42;   sin_lut[22] =  8'sd47;
    // theta=138
    cos_lut[23] = -8'sd47;   sin_lut[23] =  8'sd42;
    // theta=144
    cos_lut[24] = -8'sd51;   sin_lut[24] =  8'sd37;
    // theta=150
    cos_lut[25] = -8'sd55;   sin_lut[25] =  8'sd32;
    // theta=156
    cos_lut[26] = -8'sd58;   sin_lut[26] =  8'sd26;
    // theta=162
    cos_lut[27] = -8'sd60;   sin_lut[27] =  8'sd19;
    // theta=168
    cos_lut[28] = -8'sd62;   sin_lut[28] =  8'sd13;
    // theta=174
    cos_lut[29] = -8'sd63;   sin_lut[29] =  8'sd6;
    // theta=180 (same as 0)
    cos_lut[30] = -8'sd64;   sin_lut[30] =  8'sd0;
    cos_lut[31] = -8'sd63;   sin_lut[31] = -8'sd6;
  end
  
  //=========================================================================
  // Accumulator Memory (2048 bytes)
  //=========================================================================
  reg [VOTE_WIDTH-1:0] accum [0:ACCUM_SIZE-1];
  reg [ACCUM_ADDR_W-1:0] accum_addr;
  reg [VOTE_WIDTH-1:0] accum_wdata;
  reg accum_we;
  wire [VOTE_WIDTH-1:0] accum_rdata = accum[accum_addr];
  
  always @(posedge clk) begin
    if (accum_we)
      accum[accum_addr] <= accum_wdata;
  end
  
  //=========================================================================
  // Detected Line Storage (rho, theta for 2 lines)
  //=========================================================================
  reg [5:0] line1_rho, line2_rho;
  reg [4:0] line1_theta, line2_theta;
  reg [VOTE_WIDTH-1:0] line1_votes, line2_votes;
  reg [1:0] num_lines;
  
  //=========================================================================
  // Processing Counters
  //=========================================================================
  reg [ACCUM_ADDR_W-1:0] proc_addr;
  reg [4:0] theta_cnt;
  
  // Rho calculation: rho = x*cos + y*sin, then scale to fit RHO_MAX bins
  // For 160x120 image with cos/sin scaled by 64:
  // - max|x*cos + y*sin| = 160*64 + 120*64 = 17920
  // - Divide by 512 (>>9) to get range [-35, 35]
  // - Add offset 32 to get [0, 67], clamp to [0, 63]
  localparam signed [7:0] RHO_OFFSET = 8'sd32;  // Center offset
  
  wire signed [7:0] cur_cos = cos_lut[theta_cnt];
  wire signed [7:0] cur_sin = sin_lut[theta_cnt];
  
  // rho = (x*cos + y*sin) / 512 + offset
  wire signed [15:0] x_cos = $signed({1'b0, edge_x}) * cur_cos;
  wire signed [14:0] y_sin = $signed({1'b0, edge_y}) * cur_sin;
  wire signed [16:0] rho_sum = x_cos + y_sin;
  wire signed [10:0] rho_div = rho_sum >>> 9;  // Divide by 512 (arithmetic right shift)
  wire signed [10:0] rho_shifted = rho_div + RHO_OFFSET;
  
  // Clamp rho to valid range
  wire [5:0] rho_idx = (rho_shifted < 0) ? 6'd0 :
                       (rho_shifted >= RHO_MAX) ? (RHO_MAX - 1) :
                       rho_shifted[5:0];
  
  //=========================================================================
  // Main State Machine
  //=========================================================================
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state <= ST_IDLE;
      proc_addr <= 0;
      theta_cnt <= 0;
      frame_done <= 0;
      lines_valid <= 0;
      accum_we <= 0;
      num_lines <= 0;
      line1_rho <= 0; line1_theta <= 0; line1_votes <= 0;
      line2_rho <= 0; line2_theta <= 0; line2_votes <= 0;
    end else begin
      accum_we <= 0;
      
      // Reset lines_valid when hough is disabled
      if (!enable_hough)
        lines_valid <= 0;
      
      case (state)
        //-----------------------------------------------------------
        ST_IDLE: begin
          if (enable_hough && frame_start) begin
            state <= ST_CLEAR;
            proc_addr <= 0;
          end
        end
        
        //-----------------------------------------------------------
        ST_CLEAR: begin
          // Clear accumulator
          accum_addr <= proc_addr;
          accum_wdata <= 0;
          accum_we <= 1;
          
          if (proc_addr == ACCUM_SIZE - 1) begin
            state <= ST_COLLECT;
            proc_addr <= 0;
            theta_cnt <= 0;
            // lines_valid stays as-is (previous detection results still valid for overlay)
          end else begin
            proc_addr <= proc_addr + 1;
          end
        end
        
        //-----------------------------------------------------------
        ST_COLLECT: begin
          // Vote for each edge pixel across all theta values
          if (pixel_valid && edge_valid) begin
            // Calculate accumulator address
            accum_addr <= theta_cnt * RHO_MAX + rho_idx;
            accum_wdata <= (accum_rdata < 8'hFF) ? accum_rdata + 1 : accum_rdata;
            accum_we <= 1;
            
            // Cycle through all theta values for this pixel
            if (theta_cnt == THETA_STEPS - 1) begin
              theta_cnt <= 0;
            end else begin
              theta_cnt <= theta_cnt + 1;
            end
          end
          
          // Move to detection when frame ends
          if (frame_end) begin
            state <= ST_DETECT;
            proc_addr <= 0;
            line1_votes <= 0;
            line2_votes <= 0;
            num_lines <= 0;
          end
        end
        
        //-----------------------------------------------------------
        ST_DETECT: begin
          // Scan accumulator to find peaks
          accum_addr <= proc_addr;
          
          // Check if current cell exceeds threshold and is a peak
          if (accum_rdata >= VOTE_THRESH) begin
            if (accum_rdata > line1_votes) begin
              // New best line - shift old best to second
              line2_rho <= line1_rho;
              line2_theta <= line1_theta;
              line2_votes <= line1_votes;
              // Save new best
              line1_rho <= proc_addr[5:0];  // % RHO_MAX
              line1_theta <= proc_addr[10:6]; // / RHO_MAX
              line1_votes <= accum_rdata;
              if (num_lines < 2) num_lines <= num_lines + 1;
            end else if (accum_rdata > line2_votes) begin
              // New second best line
              line2_rho <= proc_addr[5:0];
              line2_theta <= proc_addr[10:6];
              line2_votes <= accum_rdata;
              if (num_lines < 2) num_lines <= 2'd2;
            end
          end
          
          if (proc_addr == ACCUM_SIZE - 1) begin
            state <= ST_READY;
            frame_done <= 1;
            lines_valid <= 1;  // Now have valid line data for overlay
          end else begin
            proc_addr <= proc_addr + 1;
          end
        end
        
        //-----------------------------------------------------------
        ST_READY: begin
          // Lines detected, overlay on display
          if (enable_hough && frame_start) begin
            state <= ST_CLEAR;
            proc_addr <= 0;
            // lines_valid stays true - overlay previous results during new frame
          end else if (!enable_hough) begin
            state <= ST_IDLE;
            frame_done <= 0;
            lines_valid <= 0;
          end
        end
      endcase
    end
  end
  
  //=========================================================================
  // Line Drawing - Check if current pixel is on detected line
  // Line equation: rho = x*cos(theta) + y*sin(theta)
  //=========================================================================
  
  localparam LINE_THICKNESS = 3;  // Pixels tolerance (increased for coarser rho resolution)
  
  // Line 1 check
  wire signed [7:0] ln1_cos = cos_lut[line1_theta];
  wire signed [7:0] ln1_sin = sin_lut[line1_theta];
  wire signed [15:0] ln1_x_cos = $signed({1'b0, edge_x}) * ln1_cos;
  wire signed [14:0] ln1_y_sin = $signed({1'b0, edge_y}) * ln1_sin;
  wire signed [16:0] ln1_rho_calc = ln1_x_cos + ln1_y_sin;
  wire signed [10:0] ln1_rho_pixel = (ln1_rho_calc >>> 9) + RHO_OFFSET;  // Same scaling as detection
  wire signed [10:0] ln1_diff = ln1_rho_pixel - $signed({5'b0, line1_rho});
  wire [10:0] ln1_abs = ln1_diff[10] ? -ln1_diff : ln1_diff;
  wire on_line1 = lines_valid && (line1_votes >= VOTE_THRESH) && (ln1_abs <= LINE_THICKNESS);
  
  // Line 2 check
  wire signed [7:0] ln2_cos = cos_lut[line2_theta];
  wire signed [7:0] ln2_sin = sin_lut[line2_theta];
  wire signed [15:0] ln2_x_cos = $signed({1'b0, edge_x}) * ln2_cos;
  wire signed [14:0] ln2_y_sin = $signed({1'b0, edge_y}) * ln2_sin;
  wire signed [16:0] ln2_rho_calc = ln2_x_cos + ln2_y_sin;
  wire signed [10:0] ln2_rho_pixel = (ln2_rho_calc >>> 9) + RHO_OFFSET;  // Same scaling as detection
  wire signed [10:0] ln2_diff = ln2_rho_pixel - $signed({5'b0, line2_rho});
  wire [10:0] ln2_abs = ln2_diff[10] ? -ln2_diff : ln2_diff;
  wire on_line2 = lines_valid && (line2_votes >= VOTE_THRESH) && (ln2_abs <= LINE_THICKNESS) && (num_lines >= 2);
  
  wire on_any_line = on_line1 | on_line2;
  
  //=========================================================================
  // Output - Overlay lines on image
  //=========================================================================
  
  // Fallback: if Hough disabled or not ready, just pass through
  assign pixel_out = (enable_hough && show_lines && on_any_line) ? LINE_COLOR : pixel_in;
  assign pixel_out_valid = pixel_valid;
  assign detected_lines = {1'b0, num_lines};
  assign hough_busy = (state != ST_IDLE) && (state != ST_READY);

endmodule


//============================================================================
// Simplified Lane Overlay Module (Alternative - Always works!)
// Uses fixed ROI regions instead of full Hough transform
// Use this as fallback if Hough doesn't work
//============================================================================
module simple_lane_overlay #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter [23:0] LINE_COLOR = 24'h00FF00  // Green
)(
  input  wire        clk,
  input  wire        resetn,
  input  wire [7:0]  pixel_x,
  input  wire [6:0]  pixel_y,
  input  wire        edge_valid,
  input  wire [23:0] pixel_in,
  input  wire        enable,
  output wire [23:0] pixel_out
);

  // Simple lane markers based on expected lane position
  // Left lane: diagonal from (20, 119) to (60, 60)
  // Right lane: diagonal from (140, 119) to (100, 60)
  
  wire [7:0] left_x_expected = 8'd20 + ((8'd119 - {1'b0, pixel_y}) * 8'd40) / 8'd59;
  wire [7:0] right_x_expected = 8'd140 - ((8'd119 - {1'b0, pixel_y}) * 8'd40) / 8'd59;
  
  wire in_roi = (pixel_y >= 7'd60);  // Bottom 50% of image
  
  wire near_left = in_roi && edge_valid && 
                   (pixel_x >= left_x_expected - 8'd5) && 
                   (pixel_x <= left_x_expected + 8'd5);
                   
  wire near_right = in_roi && edge_valid && 
                    (pixel_x >= right_x_expected - 8'd5) && 
                    (pixel_x <= right_x_expected + 8'd5);
  
  assign pixel_out = (enable && (near_left || near_right)) ? LINE_COLOR : pixel_in;

endmodule

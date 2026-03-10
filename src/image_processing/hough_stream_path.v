//============================================================================
// Hough Transform Stream Path - Fixed Version
// Date: 2026-03-05
//
// FIX: Buffer edge pixels and vote for all 32 theta angles per pixel
//============================================================================

module hough_stream_path #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter integer THETA_STEPS  = 32,     // 32 angle bins (0-180, step ~6 deg)
  parameter integer RHO_MAX      = 64,     // Rho bins 
  parameter integer VOTE_THRESH  = 15,     // Minimum votes to be a line (increased to filter noise)
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
  // ROI and Sampling - Only process bottom half, every 2nd pixel
  // This reduces edge pixels by ~4x (essential for real-time processing)
  //=========================================================================
  wire in_roi = (edge_y >= 7'd60);  // Bottom 50% where lanes are
  wire not_border = (edge_x >= 8'd5) && (edge_x <= 8'd154) && (edge_y >= 7'd5) && (edge_y <= 7'd114);  // Exclude border
  wire sample_pixel = (edge_x[0] == 1'b0);  // Every 2nd pixel horizontally
  wire process_this_edge = edge_valid && in_roi && sample_pixel && not_border;
  
  //=========================================================================
  // State Machine
  //=========================================================================
  localparam ST_IDLE    = 3'd0;
  localparam ST_CLEAR   = 3'd1;
  localparam ST_COLLECT = 3'd2;
  localparam ST_VOTE    = 3'd3;  // NEW: voting state for current edge pixel
  localparam ST_DETECT  = 3'd4;
  localparam ST_READY   = 3'd5;
  
  reg [2:0] state;
  reg frame_done;
  reg lines_valid;  // Stays true while we have valid line data for overlay
  
  //=========================================================================
  // Edge Pixel Buffer - stores current edge being voted
  //=========================================================================
  reg [7:0] buf_edge_x;
  reg [6:0] buf_edge_y;
  reg       edge_pending;  // An edge is waiting to be voted
  
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
  reg [ACCUM_ADDR_W-1:0] accum_addr_d1, accum_addr_d2;  // Delayed addresses for pipeline
  reg [VOTE_WIDTH-1:0] accum_wdata;
  reg accum_we;
  wire [VOTE_WIDTH-1:0] accum_rdata = accum[accum_addr_d1]; // Read from delayed address
  
  always @(posedge clk) begin
    accum_addr_d1 <= accum_addr;      // 1 cycle delay
    accum_addr_d2 <= accum_addr_d1;   // 2 cycle delay (used for write timing)
    if (accum_we)
      accum[accum_addr_d1] <= accum_wdata;  // FIX: Write to SAME address as read
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
  reg [ACCUM_ADDR_W:0] proc_addr;  // Extra bit for ACCUM_SIZE+2 during clear
  reg [5:0] theta_cnt;              // Extra bits for THETA_STEPS+1
  
  // Rho calculation: rho = x*cos + y*sin, then scale to fit RHO_MAX bins
  // For 160x120 image:
  // - Max rho = sqrt(160^2 + 120^2) = 200
  // - With cos/sin scaled by 64: max = 200*64 = 12800
  // - Divide by 384 (>>8 then >>0.5 ~= multiply by 2/3) won't work easily
  // - Better: divide by 512 (>>9) to get range [-25, 25], then add 32 = [7, 57]
  // - This gives better resolution in the active range
  localparam signed [7:0] RHO_OFFSET = 8'sd32;  // Center offset = RHO_MAX/2
  
  wire signed [7:0] cur_cos = cos_lut[theta_cnt[4:0]];  // Mask to prevent out-of-bounds
  wire signed [7:0] cur_sin = sin_lut[theta_cnt[4:0]];
  
  // rho = (x*cos + y*sin) / 512 + offset (use >>9 for better fit in 64 bins)
  // Use buffered coordinates for voting
  wire signed [16:0] x_cos = $signed({1'b0, buf_edge_x}) * cur_cos;  // 9-bit * 8-bit = 17-bit
  wire signed [15:0] y_sin = $signed({1'b0, buf_edge_y}) * cur_sin;  // 8-bit * 8-bit = 16-bit
  wire signed [17:0] rho_sum = x_cos + y_sin;
  wire signed [10:0] rho_div = rho_sum >>> 9;  // Divide by 512 for better range
  wire signed [10:0] rho_shifted = rho_div + RHO_OFFSET;
  
  // Clamp rho to valid range
  wire [5:0] rho_idx = (rho_shifted < 0) ? 6'd0 :
                       (rho_shifted >= RHO_MAX) ? (RHO_MAX - 1) :
                       rho_shifted[5:0];
  
  //=========================================================================
  // Edge FIFO/Buffer for collecting edges during frame
  // Simple approach: just sample edges, vote inline
  //=========================================================================
  reg frame_active;
  reg frame_end_pending;
  
  // NMS (Non-Maximum Suppression) signals for peak detection
  // Ensure line2 has different theta from line1 (minimum 3 steps = ~18 degrees)
  wire [4:0] detect_cur_theta = accum_addr_d1[10:6];
  wire [5:0] detect_cur_rho   = accum_addr_d1[5:0];
  wire signed [5:0] nms_theta_diff = $signed({1'b0, detect_cur_theta}) - $signed({1'b0, line1_theta});
  wire [5:0] nms_theta_abs = nms_theta_diff[5] ? -nms_theta_diff : nms_theta_diff;
  wire nms_different = (nms_theta_abs >= 5'd3) || (line1_votes == 0);

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
      buf_edge_x <= 0;
      buf_edge_y <= 0;
      edge_pending <= 0;
      frame_active <= 0;
      frame_end_pending <= 0;
    end else begin
      accum_we <= 0;
      
      // Reset lines_valid when hough is disabled
      if (!enable_hough)
        lines_valid <= 0;
      
      // Capture frame end signal
      if (frame_end && frame_active)
        frame_end_pending <= 1;
      
      case (state)
        //-----------------------------------------------------------
        ST_IDLE: begin
          if (enable_hough && frame_start) begin
            state <= ST_CLEAR;
            proc_addr <= 0;
            frame_active <= 1;
            frame_end_pending <= 0;
          end
        end
        
        //-----------------------------------------------------------
        ST_CLEAR: begin
          // Clear accumulator - with 1-cycle pipeline delay
          accum_addr <= (proc_addr < ACCUM_SIZE) ? proc_addr : (ACCUM_SIZE - 1);
          accum_wdata <= 0;
          accum_we <= (proc_addr < ACCUM_SIZE + 1);  // +1 for pipeline flush
          
          if (proc_addr >= ACCUM_SIZE) begin  // +1 for pipeline flush
            state <= ST_COLLECT;
            proc_addr <= 0;
            theta_cnt <= 0;
            edge_pending <= 0;
            accum_we <= 0;
          end else begin
            proc_addr <= proc_addr + 1;
          end
        end
        
        //-----------------------------------------------------------
        ST_COLLECT: begin
          // Wait for edge pixels and buffer them
          if (!edge_pending) begin
            // Accept new edge pixel (only in ROI and sampled)
            if (pixel_valid && process_this_edge && !frame_end_pending) begin
              buf_edge_x <= edge_x;
              buf_edge_y <= edge_y;
              edge_pending <= 1;
              theta_cnt <= 0;
              state <= ST_VOTE;
            end
            // Check if frame ended
            else if (frame_end_pending) begin
              state <= ST_DETECT;
              proc_addr <= 0;
              line1_votes <= 0;
              line2_votes <= 0;
              num_lines <= 0;
              frame_end_pending <= 0;
            end
          end
        end
        
        //-----------------------------------------------------------
        ST_VOTE: begin
          // Vote for current buffered edge pixel across all theta values
          // Pipeline: read address -> get data -> write incremented
          // theta_cnt: 0..31 for reads, then flush last write
          
          if (theta_cnt < THETA_STEPS) begin
            // Set read address for this theta
            accum_addr <= theta_cnt * RHO_MAX + rho_idx;
          end
          
          // Write incremented value (1 cycle after address set)
          // accum_addr_d1 holds the address we just read from
          if (theta_cnt >= 1 && theta_cnt <= THETA_STEPS) begin
            accum_wdata <= (accum_rdata < 8'hFE) ? accum_rdata + 1 : accum_rdata;
            accum_we <= 1;
          end
          
          if (theta_cnt == THETA_STEPS) begin
            // Done voting for this pixel
            edge_pending <= 0;
            state <= ST_COLLECT;
            theta_cnt <= 0;
          end else begin
            theta_cnt <= theta_cnt + 1;
          end
        end
        
        //-----------------------------------------------------------
        ST_DETECT: begin
          // Scan accumulator to find peaks with NMS (non-maximum suppression)
          // accum_rdata is delayed by 1 cycle (reads from accum_addr_d1)
          accum_addr <= proc_addr;
          
          // Check cell value (corresponds to proc_addr-1 due to read delay)
          if (proc_addr > 0 && accum_rdata >= VOTE_THRESH) begin
            if (accum_rdata > line1_votes) begin
              // New best line - shift old best to second only if it was different
              if (line1_votes > 0) begin
                line2_rho <= line1_rho;
                line2_theta <= line1_theta;
                line2_votes <= line1_votes;
              end
              // Save new best
              line1_rho <= detect_cur_rho;
              line1_theta <= detect_cur_theta;
              line1_votes <= accum_rdata;
              if (num_lines < 2 && line1_votes > 0) num_lines <= 2;
              else if (num_lines == 0) num_lines <= 1;
            end else if (accum_rdata > line2_votes && nms_different) begin
              // New second best line - ONLY if different theta from line1
              line2_rho <= detect_cur_rho;
              line2_theta <= detect_cur_theta;
              line2_votes <= accum_rdata;
              if (num_lines < 2) num_lines <= 2'd2;
            end
          end
          
          if (proc_addr == ACCUM_SIZE) begin  // Go 1 past to check last cell
            state <= ST_READY;
            frame_done <= 1;
            lines_valid <= 1;  // Now have valid line data for overlay
            frame_active <= 0;
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
            frame_active <= 1;
            frame_end_pending <= 0;
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
  // Line Drawing - Draw full straight lines (not just on edges)
  // Like MATLAB Hough visualization: solid lines from top to bottom of ROI
  //=========================================================================
  
  localparam LINE_THICKNESS = 2;  // Line width in pixels
  localparam [23:0] LINE_COLOR_BLUE = 24'h0000FF;  // Blue for all lines
  
  // Draw ROI: from y=40 to y=119 (most of bottom 2/3)
  wire draw_roi = (edge_y >= 7'd40) && (edge_y <= 7'd119) && 
                  (edge_x >= 8'd5) && (edge_x <= 8'd154);
  
  // Line 1: check if current pixel is on line1
  wire signed [7:0] ln1_cos = cos_lut[line1_theta];
  wire signed [7:0] ln1_sin = sin_lut[line1_theta];
  wire signed [15:0] ln1_y_sin = $signed({1'b0, edge_y}) * ln1_sin;
  wire signed [16:0] ln1_x_cos = $signed({1'b0, edge_x}) * ln1_cos;
  wire signed [17:0] ln1_calc = ln1_x_cos + ln1_y_sin;
  wire signed [10:0] ln1_rho_check = (ln1_calc >>> 9) + RHO_OFFSET;
  wire signed [10:0] ln1_diff = ln1_rho_check - $signed({5'b0, line1_rho});
  wire [10:0] ln1_abs = ln1_diff[10] ? -ln1_diff : ln1_diff;
  // Vẽ đường thẳng liền - không cần edge_valid
  wire on_line1 = draw_roi && lines_valid && (line1_votes >= VOTE_THRESH) && (ln1_abs <= LINE_THICKNESS);
  
  // Line 2: check if current pixel is on line2
  wire signed [7:0] ln2_cos = cos_lut[line2_theta];
  wire signed [7:0] ln2_sin = sin_lut[line2_theta];
  wire signed [15:0] ln2_y_sin = $signed({1'b0, edge_y}) * ln2_sin;
  wire signed [16:0] ln2_x_cos = $signed({1'b0, edge_x}) * ln2_cos;
  wire signed [17:0] ln2_calc = ln2_x_cos + ln2_y_sin;
  wire signed [10:0] ln2_rho_check = (ln2_calc >>> 9) + RHO_OFFSET;
  wire signed [10:0] ln2_diff = ln2_rho_check - $signed({5'b0, line2_rho});
  wire [10:0] ln2_abs = ln2_diff[10] ? -ln2_diff : ln2_diff;
  // Vẽ đường thẳng liền - không cần edge_valid
  wire on_line2 = draw_roi && lines_valid && (line2_votes >= VOTE_THRESH) && (ln2_abs <= LINE_THICKNESS) && (num_lines >= 2);
  
  // Both lines use blue color
  wire on_any_line = on_line1 | on_line2;
  
  //=========================================================================
  // Output - Overlay lines on image
  //=========================================================================
  
  // Fallback: if Hough disabled or not ready, just pass through
  assign pixel_out = (enable_hough && show_lines && on_any_line) ? LINE_COLOR_BLUE : pixel_in;
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

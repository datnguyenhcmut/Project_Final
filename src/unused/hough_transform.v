//============================================================================
// Hough Transform Line Detection Module
// Author: Auto-generated for Lane Detection
// Date: 2026-03-02
//
// Simplified Hough Transform for FPGA implementation
// Detects straight lines from binary edge image
//
// Algorithm: rho = x*cos(theta) + y*sin(theta)
// Uses quantized angles (0-179 degrees, step = 2 degrees => 90 bins)
// rho range: [-diagonal, +diagonal] quantized to bins
//============================================================================

module hough_transform #(
  parameter IMG_WIDTH     = 160,        // Image width
  parameter IMG_HEIGHT    = 120,        // Image height
  parameter THETA_BINS    = 90,         // Number of angle bins (180/step)
  parameter THETA_STEP    = 2,          // Angle step in degrees
  parameter RHO_BINS      = 128,        // Number of rho bins
  parameter VOTE_WIDTH    = 8,          // Bits for vote counter
  parameter PEAK_THRESH   = 20,         // Minimum votes to be considered a line
  parameter MAX_LINES     = 4           // Maximum lines to detect
)(
  input  wire        clk,
  input  wire        resetn,
  
  // Edge pixel input (streaming)
  input  wire        edge_valid,        // Edge pixel valid
  input  wire [7:0]  edge_x,            // X coordinate of edge pixel
  input  wire [6:0]  edge_y,            // Y coordinate of edge pixel
  
  // Control
  input  wire        start_voting,      // Start accumulating votes
  input  wire        start_detect,      // Start peak detection
  input  wire        clear_accum,       // Clear accumulator
  
  // Status
  output reg         voting_done,       // Voting phase complete
  output reg         detect_done,       // Peak detection complete
  output reg         busy,
  
  // Detected lines output (rho, theta pairs)
  output reg  [MAX_LINES*8-1:0] line_rho,    // Detected line rho values
  output reg  [MAX_LINES*7-1:0] line_theta,  // Detected line theta indices
  output reg  [2:0]             line_count   // Number of lines detected
);

  //=========================================================================
  // Sine/Cosine LUT for 90 angles (0-178 degrees, step=2)
  // Values scaled by 128 (7 fraction bits) and stored as signed 9-bit
  //=========================================================================
  
  reg signed [8:0] cos_lut [0:THETA_BINS-1];
  reg signed [8:0] sin_lut [0:THETA_BINS-1];
  
  // Initialize LUTs (cos/sin * 128, pre-computed)
  initial begin
    // theta = 0 degrees (cos=128, sin=0)
    cos_lut[0] = 9'sd128;  sin_lut[0] = 9'sd0;
    // theta = 2 degrees
    cos_lut[1] = 9'sd127;  sin_lut[1] = 9'sd4;
    // theta = 4 degrees
    cos_lut[2] = 9'sd127;  sin_lut[2] = 9'sd9;
    // theta = 6 degrees
    cos_lut[3] = 9'sd127;  sin_lut[3] = 9'sd13;
    // theta = 8 degrees
    cos_lut[4] = 9'sd126;  sin_lut[4] = 9'sd18;
    // theta = 10 degrees
    cos_lut[5] = 9'sd126;  sin_lut[5] = 9'sd22;
    // theta = 12 degrees
    cos_lut[6] = 9'sd125;  sin_lut[6] = 9'sd26;
    // theta = 14 degrees
    cos_lut[7] = 9'sd124;  sin_lut[7] = 9'sd31;
    // theta = 16 degrees
    cos_lut[8] = 9'sd123;  sin_lut[8] = 9'sd35;
    // theta = 18 degrees
    cos_lut[9] = 9'sd121;  sin_lut[9] = 9'sd39;
    // theta = 20 degrees
    cos_lut[10] = 9'sd120; sin_lut[10] = 9'sd43;
    // theta = 22 degrees
    cos_lut[11] = 9'sd118; sin_lut[11] = 9'sd47;
    // theta = 24 degrees
    cos_lut[12] = 9'sd116; sin_lut[12] = 9'sd51;
    // theta = 26 degrees
    cos_lut[13] = 9'sd114; sin_lut[13] = 9'sd55;
    // theta = 28 degrees
    cos_lut[14] = 9'sd112; sin_lut[14] = 9'sd59;
    // theta = 30 degrees
    cos_lut[15] = 9'sd110; sin_lut[15] = 9'sd64;
    // theta = 32 degrees
    cos_lut[16] = 9'sd108; sin_lut[16] = 9'sd67;
    // theta = 34 degrees
    cos_lut[17] = 9'sd106; sin_lut[17] = 9'sd71;
    // theta = 36 degrees
    cos_lut[18] = 9'sd103; sin_lut[18] = 9'sd75;
    // theta = 38 degrees
    cos_lut[19] = 9'sd100; sin_lut[19] = 9'sd78;
    // theta = 40 degrees
    cos_lut[20] = 9'sd98;  sin_lut[20] = 9'sd82;
    // theta = 42 degrees
    cos_lut[21] = 9'sd95;  sin_lut[21] = 9'sd85;
    // theta = 44 degrees
    cos_lut[22] = 9'sd92;  sin_lut[22] = 9'sd89;
    // theta = 46 degrees
    cos_lut[23] = 9'sd88;  sin_lut[23] = 9'sd92;
    // theta = 48 degrees
    cos_lut[24] = 9'sd85;  sin_lut[24] = 9'sd95;
    // theta = 50 degrees
    cos_lut[25] = 9'sd82;  sin_lut[25] = 9'sd98;
    // theta = 52 degrees
    cos_lut[26] = 9'sd78;  sin_lut[26] = 9'sd100;
    // theta = 54 degrees
    cos_lut[27] = 9'sd75;  sin_lut[27] = 9'sd103;
    // theta = 56 degrees
    cos_lut[28] = 9'sd71;  sin_lut[28] = 9'sd106;
    // theta = 58 degrees
    cos_lut[29] = 9'sd67;  sin_lut[29] = 9'sd108;
    // theta = 60 degrees
    cos_lut[30] = 9'sd64;  sin_lut[30] = 9'sd110;
    // theta = 62 degrees
    cos_lut[31] = 9'sd59;  sin_lut[31] = 9'sd112;
    // theta = 64 degrees
    cos_lut[32] = 9'sd55;  sin_lut[32] = 9'sd114;
    // theta = 66 degrees
    cos_lut[33] = 9'sd51;  sin_lut[33] = 9'sd116;
    // theta = 68 degrees
    cos_lut[34] = 9'sd47;  sin_lut[34] = 9'sd118;
    // theta = 70 degrees
    cos_lut[35] = 9'sd43;  sin_lut[35] = 9'sd120;
    // theta = 72 degrees
    cos_lut[36] = 9'sd39;  sin_lut[36] = 9'sd121;
    // theta = 74 degrees
    cos_lut[37] = 9'sd35;  sin_lut[37] = 9'sd123;
    // theta = 76 degrees
    cos_lut[38] = 9'sd31;  sin_lut[38] = 9'sd124;
    // theta = 78 degrees
    cos_lut[39] = 9'sd26;  sin_lut[39] = 9'sd125;
    // theta = 80 degrees
    cos_lut[40] = 9'sd22;  sin_lut[40] = 9'sd126;
    // theta = 82 degrees
    cos_lut[41] = 9'sd18;  sin_lut[41] = 9'sd126;
    // theta = 84 degrees
    cos_lut[42] = 9'sd13;  sin_lut[42] = 9'sd127;
    // theta = 86 degrees
    cos_lut[43] = 9'sd9;   sin_lut[43] = 9'sd127;
    // theta = 88 degrees
    cos_lut[44] = 9'sd4;   sin_lut[44] = 9'sd127;
    // theta = 90 degrees (cos=0, sin=128)
    cos_lut[45] = 9'sd0;   sin_lut[45] = 9'sd128;
    // theta = 92 degrees
    cos_lut[46] = -9'sd4;  sin_lut[46] = 9'sd127;
    // theta = 94 degrees
    cos_lut[47] = -9'sd9;  sin_lut[47] = 9'sd127;
    // theta = 96 degrees
    cos_lut[48] = -9'sd13; sin_lut[48] = 9'sd127;
    // theta = 98 degrees
    cos_lut[49] = -9'sd18; sin_lut[49] = 9'sd126;
    // theta = 100 degrees
    cos_lut[50] = -9'sd22; sin_lut[50] = 9'sd126;
    // theta = 102 degrees
    cos_lut[51] = -9'sd26; sin_lut[51] = 9'sd125;
    // theta = 104 degrees
    cos_lut[52] = -9'sd31; sin_lut[52] = 9'sd124;
    // theta = 106 degrees
    cos_lut[53] = -9'sd35; sin_lut[53] = 9'sd123;
    // theta = 108 degrees
    cos_lut[54] = -9'sd39; sin_lut[54] = 9'sd121;
    // theta = 110 degrees
    cos_lut[55] = -9'sd43; sin_lut[55] = 9'sd120;
    // theta = 112 degrees
    cos_lut[56] = -9'sd47; sin_lut[56] = 9'sd118;
    // theta = 114 degrees
    cos_lut[57] = -9'sd51; sin_lut[57] = 9'sd116;
    // theta = 116 degrees
    cos_lut[58] = -9'sd55; sin_lut[58] = 9'sd114;
    // theta = 118 degrees
    cos_lut[59] = -9'sd59; sin_lut[59] = 9'sd112;
    // theta = 120 degrees
    cos_lut[60] = -9'sd64; sin_lut[60] = 9'sd110;
    // theta = 122 degrees
    cos_lut[61] = -9'sd67; sin_lut[61] = 9'sd108;
    // theta = 124 degrees
    cos_lut[62] = -9'sd71; sin_lut[62] = 9'sd106;
    // theta = 126 degrees
    cos_lut[63] = -9'sd75; sin_lut[63] = 9'sd103;
    // theta = 128 degrees
    cos_lut[64] = -9'sd78; sin_lut[64] = 9'sd100;
    // theta = 130 degrees
    cos_lut[65] = -9'sd82; sin_lut[65] = 9'sd98;
    // theta = 132 degrees
    cos_lut[66] = -9'sd85; sin_lut[66] = 9'sd95;
    // theta = 134 degrees
    cos_lut[67] = -9'sd89; sin_lut[67] = 9'sd92;
    // theta = 136 degrees
    cos_lut[68] = -9'sd92; sin_lut[68] = 9'sd88;
    // theta = 138 degrees
    cos_lut[69] = -9'sd95; sin_lut[69] = 9'sd85;
    // theta = 140 degrees
    cos_lut[70] = -9'sd98; sin_lut[70] = 9'sd82;
    // theta = 142 degrees
    cos_lut[71] = -9'sd100; sin_lut[71] = 9'sd78;
    // theta = 144 degrees
    cos_lut[72] = -9'sd103; sin_lut[72] = 9'sd75;
    // theta = 146 degrees
    cos_lut[73] = -9'sd106; sin_lut[73] = 9'sd71;
    // theta = 148 degrees
    cos_lut[74] = -9'sd108; sin_lut[74] = 9'sd67;
    // theta = 150 degrees
    cos_lut[75] = -9'sd110; sin_lut[75] = 9'sd64;
    // theta = 152 degrees
    cos_lut[76] = -9'sd112; sin_lut[76] = 9'sd59;
    // theta = 154 degrees
    cos_lut[77] = -9'sd114; sin_lut[77] = 9'sd55;
    // theta = 156 degrees
    cos_lut[78] = -9'sd116; sin_lut[78] = 9'sd51;
    // theta = 158 degrees
    cos_lut[79] = -9'sd118; sin_lut[79] = 9'sd47;
    // theta = 160 degrees
    cos_lut[80] = -9'sd120; sin_lut[80] = 9'sd43;
    // theta = 162 degrees
    cos_lut[81] = -9'sd121; sin_lut[81] = 9'sd39;
    // theta = 164 degrees
    cos_lut[82] = -9'sd123; sin_lut[82] = 9'sd35;
    // theta = 166 degrees
    cos_lut[83] = -9'sd124; sin_lut[83] = 9'sd31;
    // theta = 168 degrees
    cos_lut[84] = -9'sd125; sin_lut[84] = 9'sd26;
    // theta = 170 degrees
    cos_lut[85] = -9'sd126; sin_lut[85] = 9'sd22;
    // theta = 172 degrees
    cos_lut[86] = -9'sd126; sin_lut[86] = 9'sd18;
    // theta = 174 degrees
    cos_lut[87] = -9'sd127; sin_lut[87] = 9'sd13;
    // theta = 176 degrees
    cos_lut[88] = -9'sd127; sin_lut[88] = 9'sd9;
    // theta = 178 degrees
    cos_lut[89] = -9'sd127; sin_lut[89] = 9'sd4;
  end
  
  //=========================================================================
  // Accumulator Memory (Voting Space)
  // Size: THETA_BINS x RHO_BINS = 90 x 128 = 11520 entries
  //=========================================================================
  
  localparam ACCUM_ADDR_W = $clog2(THETA_BINS * RHO_BINS);  // ~14 bits
  
  reg [VOTE_WIDTH-1:0] accum_mem [0:THETA_BINS*RHO_BINS-1];
  reg [ACCUM_ADDR_W-1:0] accum_addr;
  reg [VOTE_WIDTH-1:0] accum_wdata;
  reg accum_we;
  wire [VOTE_WIDTH-1:0] accum_rdata;
  
  // Simple RAM read
  assign accum_rdata = accum_mem[accum_addr];
  
  // RAM write
  always @(posedge clk) begin
    if (accum_we)
      accum_mem[accum_addr] <= accum_wdata;
  end
  
  //=========================================================================
  // State Machine
  //=========================================================================
  
  localparam ST_IDLE       = 3'd0;
  localparam ST_CLEAR      = 3'd1;
  localparam ST_VOTE       = 3'd2;
  localparam ST_VOTE_WRITE = 3'd3;
  localparam ST_DETECT     = 3'd4;
  localparam ST_DONE       = 3'd5;
  
  reg [2:0] state, next_state;
  
  // Voting registers
  reg [6:0] theta_cnt;
  reg [7:0] px_x;
  reg [6:0] px_y;
  reg signed [17:0] rho_raw;
  reg [6:0] rho_idx;
  
  // Clear counter
  reg [ACCUM_ADDR_W-1:0] clear_cnt;
  
  // Peak detection registers
  reg [ACCUM_ADDR_W-1:0] scan_addr;
  reg [VOTE_WIDTH-1:0] peak_votes [0:MAX_LINES-1];
  reg [6:0] peak_rho [0:MAX_LINES-1];
  reg [6:0] peak_theta [0:MAX_LINES-1];
  reg [2:0] num_peaks;
  
  // Diagonal for rho offset (sqrt(160^2 + 120^2) ≈ 200)
  localparam signed [8:0] RHO_OFFSET = 9'd100;  // Half diagonal
  
  //=========================================================================
  // Rho Calculation
  // rho = x*cos(theta) + y*sin(theta)
  // Result scaled by 128, then shifted and offset
  //=========================================================================
  
  wire signed [8:0] cos_val = cos_lut[theta_cnt];
  wire signed [8:0] sin_val = sin_lut[theta_cnt];
  
  wire signed [16:0] x_cos = $signed({1'b0, px_x}) * cos_val;
  wire signed [15:0] y_sin = $signed({1'b0, px_y}) * sin_val;
  wire signed [17:0] rho_scaled = x_cos + y_sin;  // Scaled by 128
  wire signed [10:0] rho_div = rho_scaled[17:7];  // Divide by 128
  wire signed [10:0] rho_offset = rho_div + RHO_OFFSET;  // Add offset
  
  // Clamp to valid range
  wire [6:0] rho_clamped = (rho_offset < 0) ? 7'd0 : 
                           (rho_offset >= RHO_BINS) ? RHO_BINS-1 : 
                           rho_offset[6:0];
  
  //=========================================================================
  // State Machine Logic
  //=========================================================================
  
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state <= ST_IDLE;
    end else begin
      state <= next_state;
    end
  end
  
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (clear_accum)
          next_state = ST_CLEAR;
        else if (start_voting && edge_valid)
          next_state = ST_VOTE;
        else if (start_detect)
          next_state = ST_DETECT;
      end
      
      ST_CLEAR: begin
        if (clear_cnt == THETA_BINS * RHO_BINS - 1)
          next_state = ST_IDLE;
      end
      
      ST_VOTE: begin
        next_state = ST_VOTE_WRITE;
      end
      
      ST_VOTE_WRITE: begin
        if (theta_cnt == THETA_BINS - 1)
          next_state = ST_IDLE;
        else
          next_state = ST_VOTE;
      end
      
      ST_DETECT: begin
        if (scan_addr == THETA_BINS * RHO_BINS - 1)
          next_state = ST_DONE;
      end
      
      ST_DONE: begin
        next_state = ST_IDLE;
      end
      
      default: next_state = ST_IDLE;
    endcase
  end
  
  //=========================================================================
  // Datapath
  //=========================================================================
  
  integer i;
  
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      theta_cnt <= 0;
      px_x <= 0;
      px_y <= 0;
      clear_cnt <= 0;
      scan_addr <= 0;
      num_peaks <= 0;
      voting_done <= 0;
      detect_done <= 0;
      busy <= 0;
      accum_we <= 0;
      accum_addr <= 0;
      accum_wdata <= 0;
      line_count <= 0;
      line_rho <= 0;
      line_theta <= 0;
      
      for (i = 0; i < MAX_LINES; i = i + 1) begin
        peak_votes[i] <= 0;
        peak_rho[i] <= 0;
        peak_theta[i] <= 0;
      end
      
    end else begin
      // Defaults
      accum_we <= 0;
      voting_done <= 0;
      detect_done <= 0;
      
      case (state)
        ST_IDLE: begin
          busy <= 0;
          theta_cnt <= 0;
          
          if (start_voting && edge_valid) begin
            px_x <= edge_x;
            px_y <= edge_y;
            busy <= 1;
          end else if (clear_accum) begin
            clear_cnt <= 0;
            busy <= 1;
          end else if (start_detect) begin
            scan_addr <= 0;
            num_peaks <= 0;
            busy <= 1;
            for (i = 0; i < MAX_LINES; i = i + 1) begin
              peak_votes[i] <= 0;
              peak_rho[i] <= 0;
              peak_theta[i] <= 0;
            end
          end
        end
        
        ST_CLEAR: begin
          accum_addr <= clear_cnt;
          accum_wdata <= 0;
          accum_we <= 1;
          clear_cnt <= clear_cnt + 1;
        end
        
        ST_VOTE: begin
          // Calculate address and read current vote
          accum_addr <= theta_cnt * RHO_BINS + rho_clamped;
        end
        
        ST_VOTE_WRITE: begin
          // Write incremented vote
          accum_addr <= theta_cnt * RHO_BINS + rho_clamped;
          accum_wdata <= (accum_rdata < {VOTE_WIDTH{1'b1}}) ? accum_rdata + 1 : accum_rdata;
          accum_we <= 1;
          
          if (theta_cnt == THETA_BINS - 1) begin
            voting_done <= 1;
            theta_cnt <= 0;
          end else begin
            theta_cnt <= theta_cnt + 1;
          end
        end
        
        ST_DETECT: begin
          // Scan accumulator for peaks
          accum_addr <= scan_addr;
          
          // Check if current cell exceeds threshold
          if (accum_rdata >= PEAK_THRESH) begin
            // Find minimum peak to potentially replace
            if (num_peaks < MAX_LINES) begin
              // Still have room, just add
              peak_votes[num_peaks] <= accum_rdata;
              peak_rho[num_peaks] <= scan_addr % RHO_BINS;
              peak_theta[num_peaks] <= scan_addr / RHO_BINS;
              num_peaks <= num_peaks + 1;
            end else begin
              // Find and replace minimum if current is larger
              // Simple: replace peak[0] if current > peak[0]
              if (accum_rdata > peak_votes[0]) begin
                peak_votes[0] <= accum_rdata;
                peak_rho[0] <= scan_addr % RHO_BINS;
                peak_theta[0] <= scan_addr / RHO_BINS;
              end
            end
          end
          
          scan_addr <= scan_addr + 1;
        end
        
        ST_DONE: begin
          detect_done <= 1;
          line_count <= num_peaks;
          
          // Pack results
          line_rho <= {peak_rho[3], peak_rho[2], peak_rho[1], peak_rho[0]};
          line_theta <= {peak_theta[3], peak_theta[2], peak_theta[1], peak_theta[0]};
        end
        
      endcase
    end
  end

endmodule


//============================================================================
// Hough Line Drawing Module
// Converts detected (rho, theta) pairs back to image space lines
//============================================================================
module hough_line_draw #(
  parameter IMG_WIDTH  = 160,
  parameter IMG_HEIGHT = 120,
  parameter LINE_COLOR = 24'hFF0000  // Red lines
)(
  input  wire        clk,
  input  wire        resetn,
  
  // Line parameters (from Hough transform)
  input  wire [7:0]  line_rho,        // Rho value (0-127)
  input  wire [6:0]  line_theta_idx,  // Theta index (0-89)
  input  wire        line_valid,      // Line is valid
  
  // Current pixel position (from VGA scan)
  input  wire [7:0]  pixel_x,
  input  wire [6:0]  pixel_y,
  
  // Output
  output wire        on_line,         // Current pixel is on the line
  output wire [23:0] line_pixel       // Line color output
);

  //=========================================================================
  // Sin/Cos LUT (same as main Hough module)
  //=========================================================================
  
  reg signed [8:0] cos_lut [0:89];
  reg signed [8:0] sin_lut [0:89];
  
  initial begin
    cos_lut[0] = 9'sd128;  sin_lut[0] = 9'sd0;
    cos_lut[1] = 9'sd127;  sin_lut[1] = 9'sd4;
    cos_lut[2] = 9'sd127;  sin_lut[2] = 9'sd9;
    cos_lut[3] = 9'sd127;  sin_lut[3] = 9'sd13;
    cos_lut[4] = 9'sd126;  sin_lut[4] = 9'sd18;
    cos_lut[5] = 9'sd126;  sin_lut[5] = 9'sd22;
    cos_lut[6] = 9'sd125;  sin_lut[6] = 9'sd26;
    cos_lut[7] = 9'sd124;  sin_lut[7] = 9'sd31;
    cos_lut[8] = 9'sd123;  sin_lut[8] = 9'sd35;
    cos_lut[9] = 9'sd121;  sin_lut[9] = 9'sd39;
    cos_lut[10] = 9'sd120; sin_lut[10] = 9'sd43;
    cos_lut[11] = 9'sd118; sin_lut[11] = 9'sd47;
    cos_lut[12] = 9'sd116; sin_lut[12] = 9'sd51;
    cos_lut[13] = 9'sd114; sin_lut[13] = 9'sd55;
    cos_lut[14] = 9'sd112; sin_lut[14] = 9'sd59;
    cos_lut[15] = 9'sd110; sin_lut[15] = 9'sd64;
    cos_lut[16] = 9'sd108; sin_lut[16] = 9'sd67;
    cos_lut[17] = 9'sd106; sin_lut[17] = 9'sd71;
    cos_lut[18] = 9'sd103; sin_lut[18] = 9'sd75;
    cos_lut[19] = 9'sd100; sin_lut[19] = 9'sd78;
    cos_lut[20] = 9'sd98;  sin_lut[20] = 9'sd82;
    cos_lut[21] = 9'sd95;  sin_lut[21] = 9'sd85;
    cos_lut[22] = 9'sd92;  sin_lut[22] = 9'sd89;
    cos_lut[23] = 9'sd88;  sin_lut[23] = 9'sd92;
    cos_lut[24] = 9'sd85;  sin_lut[24] = 9'sd95;
    cos_lut[25] = 9'sd82;  sin_lut[25] = 9'sd98;
    cos_lut[26] = 9'sd78;  sin_lut[26] = 9'sd100;
    cos_lut[27] = 9'sd75;  sin_lut[27] = 9'sd103;
    cos_lut[28] = 9'sd71;  sin_lut[28] = 9'sd106;
    cos_lut[29] = 9'sd67;  sin_lut[29] = 9'sd108;
    cos_lut[30] = 9'sd64;  sin_lut[30] = 9'sd110;
    cos_lut[31] = 9'sd59;  sin_lut[31] = 9'sd112;
    cos_lut[32] = 9'sd55;  sin_lut[32] = 9'sd114;
    cos_lut[33] = 9'sd51;  sin_lut[33] = 9'sd116;
    cos_lut[34] = 9'sd47;  sin_lut[34] = 9'sd118;
    cos_lut[35] = 9'sd43;  sin_lut[35] = 9'sd120;
    cos_lut[36] = 9'sd39;  sin_lut[36] = 9'sd121;
    cos_lut[37] = 9'sd35;  sin_lut[37] = 9'sd123;
    cos_lut[38] = 9'sd31;  sin_lut[38] = 9'sd124;
    cos_lut[39] = 9'sd26;  sin_lut[39] = 9'sd125;
    cos_lut[40] = 9'sd22;  sin_lut[40] = 9'sd126;
    cos_lut[41] = 9'sd18;  sin_lut[41] = 9'sd126;
    cos_lut[42] = 9'sd13;  sin_lut[42] = 9'sd127;
    cos_lut[43] = 9'sd9;   sin_lut[43] = 9'sd127;
    cos_lut[44] = 9'sd4;   sin_lut[44] = 9'sd127;
    cos_lut[45] = 9'sd0;   sin_lut[45] = 9'sd128;
    cos_lut[46] = -9'sd4;  sin_lut[46] = 9'sd127;
    cos_lut[47] = -9'sd9;  sin_lut[47] = 9'sd127;
    cos_lut[48] = -9'sd13; sin_lut[48] = 9'sd127;
    cos_lut[49] = -9'sd18; sin_lut[49] = 9'sd126;
    cos_lut[50] = -9'sd22; sin_lut[50] = 9'sd126;
    cos_lut[51] = -9'sd26; sin_lut[51] = 9'sd125;
    cos_lut[52] = -9'sd31; sin_lut[52] = 9'sd124;
    cos_lut[53] = -9'sd35; sin_lut[53] = 9'sd123;
    cos_lut[54] = -9'sd39; sin_lut[54] = 9'sd121;
    cos_lut[55] = -9'sd43; sin_lut[55] = 9'sd120;
    cos_lut[56] = -9'sd47; sin_lut[56] = 9'sd118;
    cos_lut[57] = -9'sd51; sin_lut[57] = 9'sd116;
    cos_lut[58] = -9'sd55; sin_lut[58] = 9'sd114;
    cos_lut[59] = -9'sd59; sin_lut[59] = 9'sd112;
    cos_lut[60] = -9'sd64; sin_lut[60] = 9'sd110;
    cos_lut[61] = -9'sd67; sin_lut[61] = 9'sd108;
    cos_lut[62] = -9'sd71; sin_lut[62] = 9'sd106;
    cos_lut[63] = -9'sd75; sin_lut[63] = 9'sd103;
    cos_lut[64] = -9'sd78; sin_lut[64] = 9'sd100;
    cos_lut[65] = -9'sd82; sin_lut[65] = 9'sd98;
    cos_lut[66] = -9'sd85; sin_lut[66] = 9'sd95;
    cos_lut[67] = -9'sd89; sin_lut[67] = 9'sd92;
    cos_lut[68] = -9'sd92; sin_lut[68] = 9'sd88;
    cos_lut[69] = -9'sd95; sin_lut[69] = 9'sd85;
    cos_lut[70] = -9'sd98; sin_lut[70] = 9'sd82;
    cos_lut[71] = -9'sd100; sin_lut[71] = 9'sd78;
    cos_lut[72] = -9'sd103; sin_lut[72] = 9'sd75;
    cos_lut[73] = -9'sd106; sin_lut[73] = 9'sd71;
    cos_lut[74] = -9'sd108; sin_lut[74] = 9'sd67;
    cos_lut[75] = -9'sd110; sin_lut[75] = 9'sd64;
    cos_lut[76] = -9'sd112; sin_lut[76] = 9'sd59;
    cos_lut[77] = -9'sd114; sin_lut[77] = 9'sd55;
    cos_lut[78] = -9'sd116; sin_lut[78] = 9'sd51;
    cos_lut[79] = -9'sd118; sin_lut[79] = 9'sd47;
    cos_lut[80] = -9'sd120; sin_lut[80] = 9'sd43;
    cos_lut[81] = -9'sd121; sin_lut[81] = 9'sd39;
    cos_lut[82] = -9'sd123; sin_lut[82] = 9'sd35;
    cos_lut[83] = -9'sd124; sin_lut[83] = 9'sd31;
    cos_lut[84] = -9'sd125; sin_lut[84] = 9'sd26;
    cos_lut[85] = -9'sd126; sin_lut[85] = 9'sd22;
    cos_lut[86] = -9'sd126; sin_lut[86] = 9'sd18;
    cos_lut[87] = -9'sd127; sin_lut[87] = 9'sd13;
    cos_lut[88] = -9'sd127; sin_lut[88] = 9'sd9;
    cos_lut[89] = -9'sd127; sin_lut[89] = 9'sd4;
  end
  
  //=========================================================================
  // Check if current pixel lies on the line
  // Line equation: rho = x*cos(theta) + y*sin(theta)
  // Pixel is on line if |calculated_rho - line_rho| < threshold
  //=========================================================================
  
  localparam signed [8:0] RHO_OFFSET = 9'd100;
  localparam LINE_THICKNESS = 2;  // Allow ±2 tolerance
  
  wire signed [8:0] cos_val = cos_lut[line_theta_idx];
  wire signed [8:0] sin_val = sin_lut[line_theta_idx];
  
  wire signed [16:0] x_cos = $signed({1'b0, pixel_x}) * cos_val;
  wire signed [15:0] y_sin = $signed({1'b0, pixel_y}) * sin_val;
  wire signed [17:0] rho_calc = x_cos + y_sin;
  wire signed [10:0] rho_div = rho_calc[17:7];  // Divide by 128
  wire signed [10:0] rho_pixel = rho_div + RHO_OFFSET;
  
  // Calculate difference from line rho
  wire signed [10:0] rho_diff = rho_pixel - $signed({3'b0, line_rho});
  wire [10:0] rho_abs_diff = rho_diff[10] ? -rho_diff : rho_diff;
  
  // Pixel is on line if within thickness tolerance
  assign on_line = line_valid && (rho_abs_diff <= LINE_THICKNESS);
  assign line_pixel = LINE_COLOR;

endmodule


//============================================================================
// Multi-Line Overlay Module
// Overlays multiple detected lines on the image
//============================================================================
module hough_line_overlay #(
  parameter IMG_WIDTH   = 160,
  parameter IMG_HEIGHT  = 120,
  parameter MAX_LINES   = 4,
  parameter LINE_COLOR  = 24'hFF0000
)(
  input  wire        clk,
  input  wire        resetn,
  
  // Detected lines from Hough transform
  input  wire [MAX_LINES*8-1:0] line_rhos,
  input  wire [MAX_LINES*7-1:0] line_thetas,
  input  wire [2:0]             line_count,
  
  // Current pixel 
  input  wire [7:0]  pixel_x,
  input  wire [6:0]  pixel_y,
  input  wire [23:0] pixel_in,
  
  // Output
  output wire [23:0] pixel_out
);

  wire [3:0] on_line;
  
  genvar i;
  generate
    for (i = 0; i < MAX_LINES; i = i + 1) begin : line_check
      wire [7:0] rho_i   = line_rhos[i*8 +: 8];
      wire [6:0] theta_i = line_thetas[i*7 +: 7];
      wire valid_i = (i < line_count);
      wire [23:0] dummy_color;
      
      hough_line_draw #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .LINE_COLOR (LINE_COLOR)
      ) u_draw (
        .clk           (clk),
        .resetn        (resetn),
        .line_rho      (rho_i),
        .line_theta_idx(theta_i),
        .line_valid    (valid_i),
        .pixel_x       (pixel_x),
        .pixel_y       (pixel_y),
        .on_line       (on_line[i]),
        .line_pixel    (dummy_color)
      );
    end
  endgenerate
  
  // If any line passes through this pixel, draw line color
  wire any_line = |on_line;
  assign pixel_out = any_line ? LINE_COLOR : pixel_in;

endmodule

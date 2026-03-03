//============================================================================
// Edge Detection with Hough Transform Integration
// Author: Auto-generated for Lane Detection
// Date: 2026-03-02
//
// Combines edge detection pipeline with Hough Transform line detection
// Outputs image with detected lane lines overlaid
//============================================================================

module edge_hough_stream #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter integer SOBEL_SHIFT   = 2,
  parameter integer SCHARR_SHIFT  = 3,
  parameter integer EDGE_BOOST_SH = 1,
  parameter integer GAIN_SH       = 2,
  parameter [7:0]   CANNY_HIGH_TH = 8'd80,
  parameter [7:0]   CANNY_LOW_TH  = 8'd30,
  // Hough parameters
  parameter integer PEAK_THRESH   = 8,    // Minimum votes for a line
  parameter [23:0]  LINE_COLOR    = 24'hFF0000
)(
  input  wire        clock,
  input  wire        resetn,
  input  wire [2:0]  sel_im,
  input  wire [1:0]  mode,          // 00:RGB, 01:Gray, 10:Sobel, 11:Canny
  input  wire        pre_en,
  input  wire        hough_en,      // Enable Hough line detection
  input  wire        show_lines,    // Overlay detected lines

  output wire [16:0] addr_req,
  output wire [2:0]  sel_im_req,
  input  wire [23:0] pixel_in,

  output wire [7:0]  x_s,
  output wire [6:0]  y_s,
  output wire [23:0] colour_s,
  output wire        plot_s,
  
  // Debug outputs
  output wire [2:0]  hough_lines,
  output wire        hough_busy
);

  //=========================================================================
  // Pixel Counter (X, Y coordinates)
  //=========================================================================
  
  reg [7:0] xs;
  reg [6:0] ys;

  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      xs <= 8'd0;
      ys <= 7'd0;
    end else begin
      if (xs == 8'd159) begin
        xs <= 8'd0;
        ys <= (ys == 7'd119) ? 7'd0 : (ys + 7'd1);
      end else begin
        xs <= xs + 8'd1;
      end
    end
  end

  //=========================================================================
  // Input Synchronization
  //=========================================================================
  
  wire [2:0] sel_im_sync;
  wire [1:0] mode_sync;

  sync2 #(.W(3)) u_sync_im (.clk(clock), .d(sel_im), .q(sel_im_sync));
  sync2 #(.W(2)) u_sync_md (.clk(clock), .d(mode),   .q(mode_sync));

  reg  [2:0] sel_im_r;
  reg  [1:0] mode_r;

  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      sel_im_r <= 3'd0;
      mode_r   <= 2'b00;
    end else if ((xs == 8'd0) && (ys == 7'd0)) begin
      sel_im_r <= sel_im_sync;
      mode_r   <= mode_sync;
    end
  end

  //=========================================================================
  // Address Generation
  //=========================================================================
  
  wire [16:0] ys17 = {10'd0, ys};
  wire [16:0] xs17 = { 9'd0, xs};
  wire [16:0] addr = (ys17 << 7) + (ys17 << 5) + xs17;
  assign addr_req = addr;

  reg [7:0] xs_d1;
  reg [6:0] ys_d1;
  
  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      xs_d1 <= 8'd0; ys_d1 <= 7'd0;
    end else begin
      xs_d1 <= xs;   ys_d1 <= ys;
    end
  end
  
  wire sof_in = (xs_d1 == 8'd0) && (ys_d1 == 7'd0);
  wire eol_in = (xs_d1 == 8'd159);

  //=========================================================================
  // Grayscale Conversion
  //=========================================================================
  
  wire [7:0] y_in_raw;
  rgb2gray8 u_y (.rgb(pixel_in), .y(y_in_raw));

  wire [7:0] y_preproc;
  sp_preproc_constbg_comb #(
    .HIGH_TH     (250),
    .LOW_TH      (5),
    .DETECT_HIGH (1),
    .DETECT_LOW  (0),
    .BG_LEVEL    (8'd170)
  ) u_pre (
    .in_y  (y_in_raw),
    .out_y (y_preproc)
  );

  wire [7:0] y_in = pre_en ? y_preproc : y_in_raw;

  //=========================================================================
  // Median Filter (Noise Reduction)
  //=========================================================================
  
  wire       m_valid;
  wire [7:0] m_pixel;
  wire       m_sof, m_eol;

  median3x3_stream #(
    .W           (W),
    .H           (H),
    .BORDER_MODE (0)
  ) u_med (
    .clk       (clock),
    .resetn    (resetn),
    .in_valid  (1'b1),
    .in_ready  (),
    .in_pixel  (y_in),
    .in_sof    (sof_in),
    .in_eol    (eol_in),
    .out_valid (m_valid),
    .out_ready (1'b1),
    .out_pixel (m_pixel),
    .out_sof   (m_sof),
    .out_eol   (m_eol)
  );

  //=========================================================================
  // 3x3 Window Generator
  //=========================================================================
  
  wire       w_valid;
  wire [7:0] q00, q01, q02, q10, q11, q12, q20, q21, q22;

  window3x3_stream #(
    .W           (W),
    .H           (H),
    .BORDER_ZERO (0)
  ) u_win (
    .clk       (clock),
    .resetn    (resetn),
    .in_valid  (m_valid),
    .in_pixel  (m_pixel),
    .out_valid (w_valid),
    .q00(q00), .q01(q01), .q02(q02),
    .q10(q10), .q11(q11), .q12(q12),
    .q20(q20), .q21(q21), .q22(q22)
  );

  //=========================================================================
  // Coordinate Pipeline Delay
  //=========================================================================
  
  reg [7:0] x0_d1;  reg [6:0] y0_d1;
  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      x0_d1 <= 8'd0; y0_d1 <= 7'd0;
    end else begin
      x0_d1 <= xs_d1; y0_d1 <= ys_d1;
    end
  end

  reg [7:0] x_med, x_med_d1;  reg [6:0] y_med, y_med_d1;
  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      x_med<=8'd0; y_med<=7'd0; x_med_d1<=8'd0; y_med_d1<=7'd0;
    end else begin
      if (m_valid) begin x_med <= x0_d1; y_med <= y0_d1; end
      x_med_d1 <= x_med; y_med_d1 <= y_med;
    end
  end

  reg [7:0] x_win;  reg [6:0] y_win;
  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin x_win<=8'd0; y_win<=7'd0;
    end else if (w_valid) begin x_win <= x_med_d1; y_win <= y_med_d1; end
  end

  //=========================================================================
  // Edge Detection (Sobel + Canny)
  //=========================================================================
  
  wire [7:0] grad_sobel, grad_scharr;

  sobel_3x3_gray #(.SOBEL_SHIFT(SOBEL_SHIFT)) u_sobel (
    .s0(q00),.s1(q01),.s2(q02),
    .s3(q10),.s4(q11),.s5(q12),
    .s6(q20),.s7(q21),.s8(q22),
    .grad_mag8(grad_sobel)
  );

  scharr_3x3_gray #(.SCHARR_SHIFT(SCHARR_SHIFT)) u_scharr (
    .s0(q00),.s1(q01),.s2(q02),
    .s3(q10),.s4(q11),.s5(q12),
    .s6(q20),.s7(q21),.s8(q22),
    .grad_mag8(grad_scharr)
  );

  // Canny-style binary edge detection
  wire canny_edge_bit;
  canny_simple #(
    .HIGH_TH(CANNY_HIGH_TH),
    .LOW_TH (CANNY_LOW_TH)
  ) u_canny (
    .grad_mag (grad_sobel),
    .edge_out (canny_edge_bit)
  );
  wire [7:0] binary_edge = canny_edge_bit ? 8'hFF : 8'h00;

  wire [9:0]  tmp_boost = {2'b00, grad_sobel} << EDGE_BOOST_SH;
  wire [7:0]  sobel_boost_sat = (|tmp_boost[9:8]) ? 8'hFF : tmp_boost[7:0];

  //=========================================================================
  // RGB Pipeline Delay
  //=========================================================================
  
  reg [23:0] rgb_d1, rgb_med, rgb_win;
  always @(posedge clock or negedge resetn) begin
    if (!resetn) begin
      rgb_d1<=24'd0; rgb_med<=24'd0; rgb_win<=24'd0;
    end else begin
      rgb_d1 <= pixel_in;
      if (m_valid) rgb_med <= rgb_d1;
      if (w_valid) rgb_win <= rgb_med;
    end
  end

  //=========================================================================
  // Hough Transform Line Detection
  //=========================================================================
  
  wire [23:0] hough_pixel_out;
  wire        hough_out_valid;
  wire [2:0]  hough_line_count;
  wire        hough_is_busy;
  
  // Select pixel for Hough overlay (use RGB or edge based on mode)
  wire [23:0] hough_input_pixel;
  assign hough_input_pixel = (mode_r == 2'b11) ? {binary_edge, binary_edge, binary_edge} : rgb_win;
  
  hough_stream_path #(
    .W            (W),
    .H            (H),
    .THETA_STEPS  (32),         // 32 angle bins
    .RHO_MAX      (64),         // 64 rho bins
    .VOTE_THRESH  (PEAK_THRESH),
    .LINE_COLOR   (LINE_COLOR)
  ) u_hough (
    .clk             (clock),
    .resetn          (resetn),
    .edge_x          (x_win),
    .edge_y          (y_win),
    .edge_valid      (canny_edge_bit),
    .pixel_valid     (w_valid),
    .pixel_in        (hough_input_pixel),
    .enable_hough    (hough_en),
    .show_lines      (show_lines),
    .pixel_out       (hough_pixel_out),
    .pixel_out_valid (hough_out_valid),
    .detected_lines  (hough_line_count),
    .hough_busy      (hough_is_busy)
  );

  //=========================================================================
  // Output Mode Selection
  //=========================================================================
  // mode 00: Original RGB (with optional Hough overlay)
  // mode 01: Grayscale (after median)
  // mode 10: Sobel gradient
  // mode 11: Binary edge (Canny) with Hough overlay
  
  reg [23:0] colour_sel;
  always @(*) begin
    if (hough_en && show_lines) begin
      // Use Hough output (includes line overlay)
      colour_sel = hough_pixel_out;
    end else begin
      case (mode_r)
        2'b00: colour_sel = rgb_win;
        2'b01: colour_sel = {m_pixel, m_pixel, m_pixel};
        2'b10: colour_sel = {sobel_boost_sat, sobel_boost_sat, sobel_boost_sat};
        2'b11: colour_sel = {binary_edge, binary_edge, binary_edge};
      endcase
    end
  end

  //=========================================================================
  // Output Assignment
  //=========================================================================
  
  assign x_s         = x_win;
  assign y_s         = y_win;
  assign colour_s    = colour_sel;
  assign plot_s      = w_valid;
  assign sel_im_req  = sel_im_r;
  assign hough_lines = hough_line_count;
  assign hough_busy  = hough_is_busy;

endmodule

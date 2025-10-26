module edge_stream_path #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter integer SOBEL_SHIFT   = 2,  
  parameter integer SCHARR_SHIFT  = 3, 
  parameter integer EDGE_BOOST_SH = 1, 
  parameter integer GAIN_SH       = 2  
)(
  input  wire        clock,        
  input  wire        resetn,
  input  wire [2:0]  sel_im,     
  input  wire [1:0]  mode,        
  input  wire        pre_en,    

  output wire [16:0] addr_req,    
  output wire [2:0]  sel_im_req,  
  input  wire [23:0] pixel_in,     

  output wire [7:0]  x_s,          
  output wire [6:0]  y_s,
  output wire [23:0] colour_s,     
  output wire        plot_s        
);

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

  wire [9:0]  tmp_boost = {2'b00, grad_sobel} << EDGE_BOOST_SH;
  wire [7:0]  sobel_boost_sat = (|tmp_boost[9:8]) ? 8'hFF : tmp_boost[7:0];
  wire [9:0]  g_lin_w = {2'b00, grad_scharr} << GAIN_SH;
  wire [15:0] g_sq_w  = grad_scharr * grad_scharr;
  wire [10:0] comb_w  = {1'b0, g_lin_w} + {3'b000, g_sq_w[15:8]};
  wire [7:0]  scharr_enh_sat = (|comb_w[10:8]) ? 8'hFF : comb_w[7:0];

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

  reg [23:0] colour_sel;
  always @(*) begin
    case (mode_r)
      2'b00: colour_sel = rgb_win;                                            
      2'b01: colour_sel = {m_pixel, m_pixel, m_pixel};                        
      2'b10: colour_sel = {sobel_boost_sat, sobel_boost_sat, sobel_boost_sat}; 
      2'b11: colour_sel = {scharr_enh_sat, scharr_enh_sat, scharr_enh_sat};    
    endcase
  end

  assign x_s      = x_win;
  assign y_s      = y_win;
  assign colour_s = colour_sel;
  assign plot_s   = w_valid;
  assign sel_im_req = sel_im_r;
  
endmodule
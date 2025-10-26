module image_processing_uni #(
  parameter integer MEDIAN_EN     = 0,
  parameter integer IMPULSE_T     = 56,
  parameter integer SOBEL_SHIFT   = 2,
  parameter integer SCHARR_SHIFT  = 3,
  parameter integer EDGE_BOOST_SH = 1,  
  parameter integer GAIN_SH       = 2   
)(
  input  wire [23:0] colour_i0, colour_i1, colour_i2,
  input  wire [23:0] colour_i3, colour_i4, colour_i5,
  input  wire [23:0] colour_i6, colour_i7, colour_i8,
  input  wire [1:0]  mode,     
  output reg  [23:0] colour_out
);

  wire [7:0] y0, y1, y2, y3, y4, y5, y6, y7, y8;
  
  rgb2gray8 u0(.rgb (colour_i0),.y (y0));  rgb2gray8 u1(.rgb (colour_i1),.y (y1));  rgb2gray8 u2(.rgb (colour_i2),.y (y2));
  rgb2gray8 u3(.rgb (colour_i3),.y (y3));  rgb2gray8 u4(.rgb (colour_i4),.y (y4));  rgb2gray8 u5(.rgb (colour_i5),.y (y5));
  rgb2gray8 u6(.rgb (colour_i6),.y (y6));  rgb2gray8 u7(.rgb (colour_i7),.y (y7));  rgb2gray8 u8(.rgb (colour_i8),.y (y8));

  wire [7:0] med9;
  
  median3x3 u_med(.p0 (y0),.p1 (y1),.p2 (y2),.p3 (y3),.p4 (y4),.p5 (y5),.p6 (y6),.p7 (y7),.p8 (y8),.med (med9));
  
  wire [7:0] y4_sw;
  
  impulse_switch_8 #(
    .EN (MEDIAN_EN), 
	 .T  (IMPULSE_T)
  ) u_sw(
    .yc  (y4), 
	 .med (med9), 
	 .yo  (y4_sw)
  );

  wire [7:0] sobel_mag8;
  
  sobel_3x3_gray #(
    .SOBEL_SHIFT(SOBEL_SHIFT)
  ) u_sobel(
    .s0 (y0),.s1 (y1)   ,.s2 (y2), 
	 .s3 (y3),.s4 (y4_sw),.s5 (y5), 
	 .s6 (y6),.s7 (y7)   ,.s8 (y8),
    .grad_mag8 (sobel_mag8)
  );
  wire [9:0] sobel_boost_w = {2'b00, sobel_mag8} << EDGE_BOOST_SH;
  wire [7:0] sobel_boost   = (|sobel_boost_w[9:8]) ? 8'hFF : sobel_boost_w[7:0];

  wire [7:0] scharr_mag8;
  
  scharr_3x3_gray #(
    .SCHARR_SHIFT (SCHARR_SHIFT)
  ) u_scharr(
    .s0 (y0),.s1 (y1)   ,.s2 (y2), 
	 .s3 (y3),.s4 (y4_sw),.s5 (y5), 
	 .s6 (y6),.s7 (y7)   ,.s8 (y8),
    .grad_mag8 (scharr_mag8)
  );
  
  wire [9:0 ] g_lin  = {2'b00, scharr_mag8} << GAIN_SH;
  wire [15:0] g_sq   = scharr_mag8 * scharr_mag8;
  wire [10:0] g_sum  = {1'b0,g_lin} + {3'b000, g_sq[15:8]};
  wire [7:0 ] scharr_enh = (|g_sum[10:8]) ? 8'hFF : g_sum[7:0];
  wire [7:0] gray_y = med9;

  always @(*) begin
    case (mode)
      2'b00:   colour_out = colour_i4;                                 
      2'b01:   colour_out = {gray_y, gray_y, gray_y};                  
      2'b10:   colour_out = {sobel_boost, sobel_boost, sobel_boost};   
      default: colour_out = {scharr_enh, scharr_enh, scharr_enh};      
    endcase
  end
  
endmodule
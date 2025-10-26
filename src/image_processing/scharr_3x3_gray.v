module scharr_3x3_gray #(
  parameter integer SCHARR_SHIFT = 3  
)(
  input  wire [7:0] s0, s1, s2,
  input  wire [7:0] s3, s4, s5,
  input  wire [7:0] s6, s7, s8,
  output wire [7:0] grad_mag8
);
  
  wire signed [12:0] dx0 = $signed({5'd0, s2}) - $signed({5'd0, s0});  
  wire signed [12:0] dx1 = $signed({5'd0, s5}) - $signed({5'd0, s3});
  wire signed [12:0] dx2 = $signed({5'd0, s8}) - $signed({5'd0, s6});  

  wire signed [12:0] gx =   ((dx0 << 1) + dx0)         
                          + ((dx1 << 3) + (dx1 << 1))  
                          + ((dx2 << 1) + dx2);       

  wire signed [12:0] dy0 = $signed({5'd0, s0}) - $signed({5'd0, s6});
  wire signed [12:0] dy1 = $signed({5'd0, s1}) - $signed({5'd0, s7});
  wire signed [12:0] dy2 = $signed({5'd0, s2}) - $signed({5'd0, s8});

  wire signed [12:0] gy =   ((dy0 << 1) + dy0)       
                          + ((dy1 << 3) + (dy1 << 1))  
                          + ((dy2 << 1) + dy2);     

  wire [12:0] ax = gx[12] ? - gx : gx;
  wire [12:0] ay = gy[12] ? - gy : gy;
  wire [13:0] sum = {1'b0, ax} + {1'b0, ay};
  wire [13:0] sca = sum >> SCHARR_SHIFT;

  assign grad_mag8 = |sca[13:8] ? 8'hFF : sca[7:0];
  
endmodule
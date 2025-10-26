module sobel_3x3_gray #(
  parameter integer SOBEL_SHIFT = 2  
)(
  input  wire [7:0] s0, s1, s2,
  input  wire [7:0] s3, s4, s5,
  input  wire [7:0] s6, s7, s8,
  output wire [7:0] grad_mag8
);

  wire signed [12:0] gx = - $signed({5'd0, s0}) + $signed({5'd0, s2})
                          - ($signed({5'd0, s3}) << 1) + ($signed({5'd0, s5}) << 1)
                          - $signed({5'd0, s6}) + $signed({5'd0, s8});
  wire signed [12:0] gy = - $signed({5'd0, s0}) - ($signed({5'd0, s1}) << 1) - $signed({5'd0, s2})
                          + $signed({5'd0, s6}) + ($signed({5'd0, s7}) << 1) + $signed({5'd0, s8});

  wire [12:0] ax = gx[12] ? - gx : gx;
  wire [12:0] ay = gy[12] ? - gy : gy;

  wire [13:0] mag_sum    = {1'b0, ax} + {1'b0, ay};  
  wire [13:0] mag_scaled = mag_sum >> SOBEL_SHIFT;  

  assign grad_mag8 = |mag_scaled[13:8] ? 8'hFF : mag_scaled[7:0];
  
endmodule
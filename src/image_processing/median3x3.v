module median3x3 #(
  parameter DUMMY = 0
)(
  input  wire [7:0] p0, p1, p2,
  input  wire [7:0] p3, p4, p5,
  input  wire [7:0] p6, p7, p8,
  output wire [7:0] med
);

  wire [7:0] m0, m1, m2;
  
  med3_8 r0 (.a (p0), .b (p1), .c (p2), .m (m0));
  med3_8 r1 (.a (p3), .b (p4), .c (p5), .m (m1));
  med3_8 r2 (.a (p6), .b (p7), .c (p8), .m (m2));
  
  med3_8 c0 (.a (m0), .b (m1), .c (m2), .m (med));
  
endmodule
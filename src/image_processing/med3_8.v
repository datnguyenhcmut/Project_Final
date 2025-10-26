module med3_8 #(
  parameter DUMMY = 0
)(
  input  wire [7:0] a, b, c,
  output wire [7:0] m
);

  wire [7:0] maxab = (a > b) ? a : b;
  wire [7:0] minab = (a < b) ? a : b;
  
  assign m = (c < minab) ? minab : ((c > maxab) ? maxab : c);
  
endmodule
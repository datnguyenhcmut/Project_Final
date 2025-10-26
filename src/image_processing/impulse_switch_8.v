module impulse_switch_8 #(
  parameter       EN = 1,
  parameter [7:0] T  = 8'd40
)(
  input  wire [7:0] yc,
  input  wire [7:0] med,
  output wire [7:0] yo
);

  wire [7:0] diff = (yc > med) ? (yc - med) : (med - yc);
  
  assign yo = (EN && (diff > T)) ? med : yc;
  
endmodule
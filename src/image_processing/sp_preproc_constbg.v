module sp_preproc_constbg_comb #(
  parameter integer HIGH_TH     = 250,    
  parameter integer LOW_TH      = 5,      
  parameter         DETECT_HIGH = 1,      
  parameter         DETECT_LOW  = 0,      
  parameter [7:0]   BG_LEVEL    = 8'd186 
)(
  input  wire [7:0] in_y,
  output wire [7:0] out_y
);

  wire is_high = (DETECT_HIGH != 0) && (in_y >= HIGH_TH[7:0]);
  wire is_low  = (DETECT_LOW  != 0) && (in_y <= LOW_TH[7:0]);
  wire hit     = is_high || is_low;

  assign out_y = hit ? BG_LEVEL : in_y;
  
endmodule
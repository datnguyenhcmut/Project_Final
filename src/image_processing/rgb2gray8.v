module rgb2gray8 #(
  parameter DUMMY = 0
)(
  input  wire [23:0] rgb,
  output wire [7:0 ] y
);

  wire [7:0] r = rgb[23:16];
  wire [7:0] g = rgb[15:8 ];
  wire [7:0] b = rgb[7:0  ];

  wire [15:0] r_w = (r << 6) + (r << 3) + (r << 2) + r;       
  wire [15:0] g_w = (g << 7) + (g << 4) + (g << 2) + (g << 1); 
  wire [15:0] b_w = (b << 4) + (b << 3) + (b << 2) + b;        
  wire [15:0] y16 = r_w + g_w + b_w + 16'd128;                

  assign y = y16[15:8];
  
endmodule
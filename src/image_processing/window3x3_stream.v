module window3x3_stream #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter integer BORDER_ZERO = 0   
)(
  input  wire       clk,
  input  wire       resetn,
  input  wire       in_valid,
  input  wire [7:0] in_pixel,
  output reg        out_valid,
  output wire [7:0] q00, q01, q02,
  output wire [7:0] q10, q11, q12,
  output wire [7:0] q20, q21, q22
);

  reg [7:0] lb0 [0:W - 1];  
  reg [7:0] lb1 [0:W - 1]; 
  reg [7:0] x;  
  reg [6:0] y;

  reg [7:0] r0a, r0b, r0c, r1a, r1b, r1c, r2a, r2b, r2c;
  
  wire [7:0] prev0 = (y == 7'd0) ? in_pixel : lb0[x];                           
  wire [7:0] prev1 = (y == 7'd0) ? in_pixel : ((y == 7'd1) ? lb0[x] : lb1[x]);  

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      x <= 8'd0; 
	  y <= 7'd0;
      {r0a, r0b, r0c, r1a, r1b, r1c, r2a, r2b, r2c} <= {9{8'd0}};
      out_valid <= 1'b0;
    end else begin
      out_valid <= in_valid;
      if (in_valid) begin
        r0a <= (x == 8'd0) ? prev1 : r0b;
        r0b <= (x == 8'd0) ? prev1 : r0c;
        r0c <= prev1;
        r1a <= (x == 8'd0) ? prev0 : r1b;
        r1b <= (x == 8'd0) ? prev0 : r1c;
        r1c <= prev0;
        r2a <= (x == 8'd0) ? in_pixel : r2b;
        r2b <= (x == 8'd0) ? in_pixel : r2c;
        r2c <= in_pixel;

        lb1[x] <= (y == 7'd0) ? in_pixel : lb0[x];
        lb0[x] <= in_pixel;

        if (x == 8'd159) begin
          x <= 8'd0;
          y <= (y == 7'd119) ? 7'd0 : (y + 7'd1);
        end else begin
          x <= x + 8'd1;
        end
      end
    end
  end

  wire at_left = (x < 8'd2);  
  wire at_top2 = (y < 7'd2); 

  wire [7:0] p00 = r0a, p01 = r0b, p02 = r0c;
  wire [7:0] p10 = r1a, p11 = r1b, p12 = r1c;
  wire [7:0] p20 = r2a, p21 = r2b, p22 = r2c;

  assign q00 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p00;
  assign q01 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p01;
  assign q02 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p02;
  assign q10 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p10;
  assign q11 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p11;
  assign q12 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p12;
  assign q20 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p20;
  assign q21 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p21;
  assign q22 = (BORDER_ZERO && (at_left || at_top2)) ? 8'd0 : p22;

endmodule
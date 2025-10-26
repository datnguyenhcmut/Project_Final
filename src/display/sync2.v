module sync2 #(
  parameter integer W = 1
)(
  input  wire           clk,
  input  wire [W - 1:0] d,
  output reg  [W - 1:0] q
);

  reg [W - 1:0] m;
  
  always @(posedge clk) begin
    m <= d;  
    q <= m;  
  end
  
endmodule

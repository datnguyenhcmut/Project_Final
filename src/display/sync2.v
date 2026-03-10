module sync2 #(
  parameter integer W = 1
)(
  input  wire           clk,
  input  wire           resetn,
  input  wire [W - 1:0] d,
  output reg  [W - 1:0] q
);

  reg [W - 1:0] m;
  
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      m <= {W{1'b0}};
      q <= {W{1'b0}};
    end else begin
      m <= d;  
      q <= m;  
    end
  end
  
endmodule

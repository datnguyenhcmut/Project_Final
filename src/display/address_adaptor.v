module address_adaptor (
  input  wire [7:0]  x,  
  input  wire [6:0]  y,   
  input  wire [3:0]  sel,
  output reg  [16:0] address
);
  
  wire [16:0] y_s  = {10'd0, y};
  wire [16:0] x_s  = { 9'd0, x};
  wire [16:0] base = (y_s << 7) + (y_s << 5) + x_s;  
  wire [16:0] p0   = base - 17'd161;
  wire [16:0] p1   = base - 17'd160;
  wire [16:0] p2   = base - 17'd159;
  wire [16:0] p3   = base - 17'd1;
  wire [16:0] p4   = base;
  wire [16:0] p5   = base + 17'd1;
  wire [16:0] p6   = base + 17'd159;
  wire [16:0] p7   = base + 17'd160;
  wire [16:0] p8   = base + 17'd161;

  always @(*) begin
    case (sel)
      4'd0: address = p0;
      4'd1: address = p1;
      4'd2: address = p2;
      4'd3: address = p3;
      4'd4: address = p4;
      4'd5: address = p5;
      4'd6: address = p6;
      4'd7: address = p7;
      4'd8: address = p8;
      default: address = p4;   
    endcase
  end
  
endmodule
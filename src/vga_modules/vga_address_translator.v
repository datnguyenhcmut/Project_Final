module vga_address_translator #(
  parameter RESOLUTION = "160x120"  
)(
  input wire [((RESOLUTION == "320x240") ? (8) : (7)) : 0] x,
  input wire [((RESOLUTION == "320x240") ? (7) : (6)) : 0] y,
  
  output reg  [((RESOLUTION == "320x240") ? (16) : (14)) : 0] mem_address 
);

  wire [16:0] addr_320x240 = ({1'b0, y, 8'd0}) + ({1'b0, y, 6'd0}) + {1'b0, x};  
  wire [15:0] addr_160x120 = ({1'b0, y, 7'd0}) + ({1'b0, y, 5'd0}) + {1'b0, x};   

  always @(*) begin
    if (RESOLUTION == "320x240") mem_address = addr_320x240;
    else mem_address = addr_160x120[14:0];
  end

endmodule
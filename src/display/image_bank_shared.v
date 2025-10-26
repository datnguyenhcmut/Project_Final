module image_bank_shared (
  input  wire        clock,
  input  wire [16:0] address,
  input  wire [2:0]  sel_im,   
  output reg  [23:0] pixel_q
);

  wire [23:0] q0, q1, q2;

  image_01 u_img0 (.address (address), .clock (clock), .data (24'd0), .wren (1'b0), .q (q0));
  image_02 u_img1 (.address (address), .clock (clock), .data (24'd0), .wren (1'b0), .q (q1));
  image_03 u_img2 (.address (address), .clock (clock), .data (24'd0), .wren (1'b0), .q (q2));

  always @(*) begin
    case (sel_im)
      3'b001: pixel_q = q0;
      3'b010: pixel_q = q1;
      3'b100: pixel_q = q2;
      default: pixel_q = q0;
    endcase
  end
  
endmodule
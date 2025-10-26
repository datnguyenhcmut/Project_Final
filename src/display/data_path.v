module data_path (
  input  wire       clock, 
  input  wire       resetn,
  input  wire       rowCountEn,
  input  wire       colCountEn,
  input  wire       plot_in,
  input  wire       reset_sig_x,
  input  wire       reset_sig_y,
  input  wire       ld_0, ld_1, ld_2, ld_3, ld_4, ld_5, ld_6, ld_7, ld_8,
  input  wire [2:0] sel_im,   
  input  wire [3:0] sel_address,
  input  wire [1:0] img_mode,      

  output wire [16:0] addr_req,     
  output wire [2:0]  sel_im_req,   
  input  wire [23:0] pixel_in,    

  output reg         row_done,
  output reg         col_done,
  output wire [7:0 ] x_out,      
  output wire [6:0 ] y_out,     
  output wire [23:0] colour_out,
  output wire        plot_out
);

  reg [7:0] x;
  reg [6:0] y;

  always @(posedge clock) begin
    if (!resetn) begin
      x        <= 8'd1;
      row_done <= 1'b0;
    end else if (reset_sig_x) begin
      x        <= 8'd1;
      row_done <= 1'b0;
    end else if (rowCountEn) begin
      if (x == 8'd158) begin
        x        <= 8'd1;
        row_done <= 1'b1;  
      end else begin
        x        <= x + 8'd1;
        row_done <= 1'b0;
      end
    end
  end

  always @(posedge clock) begin
    if (!resetn) begin
      y        <= 7'd1;
      col_done <= 1'b0;
    end else if (reset_sig_y) begin
      y        <= 7'd1;
      col_done <= 1'b0;
    end else if (colCountEn) begin
      if (y == 7'd118) begin
        y        <= 7'd1;
        col_done <= 1'b1;  
      end else begin
        y        <= y + 7'd1;
        col_done <= 1'b0;
      end
    end
  end

  wire [16:0] address;
  address_adaptor u_addr (
    .x       (x),
    .y       (y),
    .sel     (sel_address),
    .address (address)
  );
 
  wire [23:0] c0, c1, c2, c3, c4, c5, c6, c7, c8;
  
  pixel_register r0 (.clock (clock), .resetn (resetn), .enable (ld_0), .colour_i (pixel_in), .colour_o (c0));
  pixel_register r1 (.clock (clock), .resetn (resetn), .enable (ld_1), .colour_i (pixel_in), .colour_o (c1));
  pixel_register r2 (.clock (clock), .resetn (resetn), .enable (ld_2), .colour_i (pixel_in), .colour_o (c2));
  pixel_register r3 (.clock (clock), .resetn (resetn), .enable (ld_3), .colour_i (pixel_in), .colour_o (c3));
  pixel_register r4 (.clock (clock), .resetn (resetn), .enable (ld_4), .colour_i (pixel_in), .colour_o (c4));
  pixel_register r5 (.clock (clock), .resetn (resetn), .enable (ld_5), .colour_i (pixel_in), .colour_o (c5));
  pixel_register r6 (.clock (clock), .resetn (resetn), .enable (ld_6), .colour_i (pixel_in), .colour_o (c6));
  pixel_register r7 (.clock (clock), .resetn (resetn), .enable (ld_7), .colour_i (pixel_in), .colour_o (c7));
  pixel_register r8 (.clock (clock), .resetn (resetn), .enable (ld_8), .colour_i (pixel_in), .colour_o (c8));

  wire [23:0] proc_out;
  
  image_processing_uni #(
    .MEDIAN_EN     (0),
    .IMPULSE_T     (56),
    .SOBEL_SHIFT   (2),
    .SCHARR_SHIFT  (3),
    .EDGE_BOOST_SH (1),
    .GAIN_SH       (2)
  ) u_proc (
    .colour_i0 (c0), .colour_i1 (c1), .colour_i2 (c2),
    .colour_i3 (c3), .colour_i4 (c4), .colour_i5 (c5),
    .colour_i6 (c6), .colour_i7 (c7), .colour_i8 (c8),
    .mode       (img_mode),
    .colour_out (proc_out)
  );

  assign colour_out = proc_out;
  assign x_out      = x;
  assign y_out      = y;
  assign plot_out   = plot_in;
  assign sel_im_req = sel_im;
  assign addr_req   = address;
  
endmodule
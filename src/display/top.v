module top (
  input        CLOCK_50,         
  input  [3:0] KEY,             
  input  [9:0] SW,     
 
  output       VGA_CLK,
  output       VGA_HS,
  output       VGA_VS,
  output       VGA_BLANK_N,
  output       VGA_SYNC_N,
  output [7:0] VGA_R,
  output [7:0] VGA_G,
  output [7:0] VGA_B
);

  wire resetn = KEY[0];

  wire [1:0] mode_sel  = SW[1:0];   
  wire [1:0] img_mode  = SW[3:2];   
  wire       use_stream= SW[6];    
  wire       pre_en    = SW[5]; 
  
  wire [23:0] colour_dp;
  wire [7:0]  x_dp;
  wire [6:0]  y_dp;
  wire        plot_dp;

  wire       plot, rowCountEn, colCountEn, reset_sig_x, reset_sig_y, row_done, col_done;
  wire       ld_0, ld_1, ld_2, ld_3, ld_4, ld_5, ld_6, ld_7, ld_8;
  wire [2:0] sel_im_ctrl;
  wire [3:0] sel_address;

  wire [16:0] addr_dp;
  wire [2:0]  sel_im_dp;
  wire [23:0] pixel_dp;

  data_path u_dp (
    .clock       (CLOCK_50),
    .resetn      (resetn),
    .rowCountEn  (rowCountEn),
    .colCountEn  (colCountEn),
    .plot_in     (plot),
    .reset_sig_x (reset_sig_x),
    .reset_sig_y (reset_sig_y),
    .ld_0        (ld_0),
    .ld_1        (ld_1),
    .ld_2        (ld_2),
    .ld_3        (ld_3),
    .ld_4        (ld_4),
    .ld_5        (ld_5),
    .ld_6        (ld_6),
    .ld_7        (ld_7),
    .ld_8        (ld_8),
    .sel_address (sel_address),
    .sel_im      (sel_im_ctrl),    
    .img_mode    (img_mode),
    .addr_req    (addr_dp),
    .sel_im_req  (sel_im_dp),
    .pixel_in    (pixel_dp),

    .row_done    (row_done),
    .col_done    (col_done),
    .x_out       (x_dp),
    .y_out       (y_dp),
    .colour_out  (colour_dp),
    .plot_out    (plot_dp)
  );

  ctrl_path u_ctl (
    .clock       (CLOCK_50),
    .resetn      (resetn),
    .SW          (SW[9:0]),
    .KEY         (KEY[3:0]),
    .row_done    (row_done),
    .col_done    (col_done),
    .rowCountEn  (rowCountEn),
    .colCountEn  (colCountEn),
    .plot        (plot),
    .reset_sig_x (reset_sig_x),
    .reset_sig_y (reset_sig_y),
    .ld_0        (ld_0),
    .ld_1        (ld_1),
    .ld_2        (ld_2),
    .ld_3        (ld_3),
    .ld_4        (ld_4),
    .ld_5        (ld_5),
    .ld_6        (ld_6),
    .ld_7        (ld_7),
    .ld_8        (ld_8),
    .sel_address (sel_address),
    .sel_im      (sel_im_ctrl) 
  );

  wire [23:0] colour_stream;
  wire [7:0]  x_stream;
  wire [6:0]  y_stream;
  wire        plot_stream;
  wire [16:0] addr_st;
  wire [2:0]  sel_im_st;
  wire [23:0] pixel_st;

  edge_stream_path #(
    .W             (160),
    .H             (120),
    .SOBEL_SHIFT   (2),
    .SCHARR_SHIFT  (3),
    .EDGE_BOOST_SH (1),
    .GAIN_SH       (2)
  ) u_stream (
    .clock      (CLOCK_50),
    .resetn     (resetn),
    .sel_im     (SW[9:7]),
    .mode       (img_mode),
    .pre_en     (pre_en),       
    .addr_req   (addr_st),
    .sel_im_req (sel_im_st),
    .pixel_in   (pixel_st),
    .x_s        (x_stream),
    .y_s        (y_stream),
    .colour_s   (colour_stream),
    .plot_s     (plot_stream)
  );

  wire [16:0] addr_bank  = use_stream ? addr_st  : addr_dp;
  wire [2:0]  selim_bank = use_stream ? sel_im_st: sel_im_dp;
  wire [23:0] pixel_bank;

  image_bank_shared u_bank (
    .clock   (CLOCK_50),
    .address (addr_bank),
    .sel_im  (selim_bank),
    .pixel_q (pixel_bank)
  );

  wire [23:0] colour_mux = use_stream ? colour_stream : colour_dp;
  wire [7:0]  x_mux      = use_stream ? x_stream      : x_dp;
  wire [6:0]  y_mux      = use_stream ? y_stream      : y_dp;
  wire        plot_mux   = use_stream ? plot_stream   : plot_dp;

  vga_adapter VGA (
    .clock     (CLOCK_50),
    .resetn    (resetn),
    .plot      (plot_mux),
    .colour    (colour_mux),
    .x         (x_mux),
    .y         (y_mux),
    .mode_sel  (mode_sel),
    .VGA_R     (VGA_R),
    .VGA_G     (VGA_G),
    .VGA_B     (VGA_B),
    .VGA_HS    (VGA_HS),
    .VGA_VS    (VGA_VS),
    .VGA_BLANK (VGA_BLANK_N),
    .VGA_SYNC  (),  
    .VGA_CLK   (VGA_CLK)
  );

  assign VGA_SYNC_N = 1'b0;
  assign pixel_dp = pixel_bank;
  assign pixel_st = pixel_bank;
  
  defparam VGA.RESOLUTION              = "160x120";
  defparam VGA.MONOCHROME              = "FALSE";
  defparam VGA.BITS_PER_COLOUR_CHANNEL = 8;
  defparam VGA.BACKGROUND_IMAGE        = "../../quartus/mif_files/background.mif";
  defparam VGA.DEVICE_FAMILY           = "Cyclone V";
  
endmodule
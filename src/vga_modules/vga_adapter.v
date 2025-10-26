module vga_adapter #(
  parameter integer BITS_PER_COLOUR_CHANNEL = 8,
  parameter         MONOCHROME              = "FALSE",
  parameter         RESOLUTION              = "160x120",
  parameter         BACKGROUND_IMAGE        = "../../quartus/mif_files/background.mif",
  parameter         DEVICE_FAMILY           = "Cyclone V",
  parameter integer ADDRW                   = 15,
  parameter integer NUMWORDS                = 19200
)(
  input  wire       clock,      
  input  wire       resetn,  
  input  wire       plot,       
  input  wire [((MONOCHROME == "TRUE") ? (0) : (3 * BITS_PER_COLOUR_CHANNEL - 1)):0] colour,
  input  wire [7:0] x,           
  input  wire [6:0] y,           
  input  wire [1:0] mode_sel,   

  output wire [7:0] VGA_R,
  output wire [7:0] VGA_G,
  output wire [7:0] VGA_B,
  output wire       VGA_HS,
  output wire       VGA_VS,
  output wire       VGA_BLANK,
  output wire       VGA_SYNC,
  output wire       VGA_CLK
);

  wire vcc = 1'b1, gnd = 1'b0;
  wire clock_25;
  wire pll_locked;

  vga_pll u_pll (
    .refclk   (clock),
    .rst      (~resetn),
    .outclk_0 (clock_25),
    .locked   (pll_locked)
  );

  wire resetn_sys = resetn & pll_locked;

  wire [ADDRW - 1:0] user_to_video_memory_addr;

  vga_address_translator #(
    .RESOLUTION (RESOLUTION)
  ) u_addr_wr (
    .x           (x),
    .y           (y),
    .mem_address (user_to_video_memory_addr)
  );

  wire writeEn = plot & (({1'b0, x} < 10'd160) & ({1'b0, y} < 9'd120));
  wire [ADDRW - 1:0] controller_to_video_memory_addr;
  wire [((MONOCHROME == "TRUE") ? (0) : (3 * BITS_PER_COLOUR_CHANNEL - 1)):0] to_ctrl_colour;

  altsyncram VideoMemory (
    .clock0    (clock),
    .clocken0  (vcc),
    .wren_a    (writeEn),
    .address_a (user_to_video_memory_addr),
    .data_a    (colour),
    .clock1    (clock_25),
    .clocken1  (vcc),
    .wren_b    (gnd),
    .address_b (controller_to_video_memory_addr),
    .q_b       (to_ctrl_colour)
  );

  defparam
    VideoMemory.WIDTH_A                = ((MONOCHROME == "FALSE") ? (3 * BITS_PER_COLOUR_CHANNEL) : 1),
    VideoMemory.WIDTH_B                = ((MONOCHROME == "FALSE") ? (3 * BITS_PER_COLOUR_CHANNEL) : 1),
    VideoMemory.INTENDED_DEVICE_FAMILY = DEVICE_FAMILY,
    VideoMemory.OPERATION_MODE         = "DUAL_PORT",
    VideoMemory.WIDTHAD_A              = ADDRW,
    VideoMemory.NUMWORDS_A             = NUMWORDS,
    VideoMemory.WIDTHAD_B              = ADDRW,
    VideoMemory.NUMWORDS_B             = NUMWORDS,
    VideoMemory.OUTDATA_REG_B          = "CLOCK1",
    VideoMemory.ADDRESS_REG_B          = "CLOCK1",
    VideoMemory.CLOCK_ENABLE_INPUT_A   = "BYPASS",
    VideoMemory.CLOCK_ENABLE_INPUT_B   = "BYPASS",
    VideoMemory.CLOCK_ENABLE_OUTPUT_B  = "BYPASS",
    VideoMemory.POWER_UP_UNINITIALIZED = "FALSE",
    VideoMemory.INIT_FILE              = BACKGROUND_IMAGE,
    VideoMemory.READ_DURING_WRITE_MODE_MIXED_PORTS = "OLD_DATA";

  wire [9:0] r10, g10, b10;

  vga_controller controller (
    .vga_clock      (clock_25),
    .resetn         (resetn_sys),
    .mode_sel       (mode_sel),
    .pixel_colour   (to_ctrl_colour[23:0]), 
    .memory_address (controller_to_video_memory_addr),
    .VGA_R          (r10),
    .VGA_G          (g10),
    .VGA_B          (b10),
    .VGA_HS         (VGA_HS),
    .VGA_VS         (VGA_VS),
    .VGA_BLANK      (VGA_BLANK),
    .VGA_SYNC       (VGA_SYNC),
    .VGA_CLK        (VGA_CLK)
  );

  assign VGA_R = r10[9:2];
  assign VGA_G = g10[9:2];
  assign VGA_B = b10[9:2];

endmodule
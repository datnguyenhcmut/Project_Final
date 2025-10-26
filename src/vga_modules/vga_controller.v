module vga_controller #(
  parameter RESOLUTION = "160x120",  

  parameter [9:0] C_HORZ_NUM_PIXELS  = 10'd640,
  parameter [9:0] C_HORZ_SYNC_START  = 10'd659, 
  parameter [9:0] C_HORZ_SYNC_END    = 10'd754, 
  parameter [9:0] C_HORZ_TOTAL_COUNT = 10'd800,
  
  parameter [9:0] C_VERT_NUM_PIXELS  = 10'd480,
  parameter [9:0] C_VERT_SYNC_START  = 10'd493, 
  parameter [9:0] C_VERT_SYNC_END    = 10'd494, 
  parameter [9:0] C_VERT_TOTAL_COUNT = 10'd525
)(
  input  wire        vga_clock,
  input  wire        resetn,
  input  wire [1:0 ] mode_sel,        
  input  wire [23:0] pixel_colour,    
  output wire [14:0] memory_address,  
  output reg  [9:0]  VGA_R,
  output reg  [9:0]  VGA_G,
  output reg  [9:0]  VGA_B,
  output reg         VGA_HS,
  output reg         VGA_VS,
  output reg         VGA_BLANK,
  output wire        VGA_SYNC,
  output wire        VGA_CLK
);

  reg [9:0] xCounter, yCounter;
  wire x_wrap = (xCounter == (C_HORZ_TOTAL_COUNT - 10'd1));
  wire y_wrap = (yCounter == (C_VERT_TOTAL_COUNT - 10'd1));
  wire vis640 = (xCounter < C_HORZ_NUM_PIXELS) && (yCounter < C_VERT_NUM_PIXELS);

  always @(posedge vga_clock or negedge resetn) begin
    if (!resetn) xCounter <= 10'd0;
    else if (x_wrap) xCounter <= 10'd0;
    else xCounter <= xCounter + 10'd1;
  end

  always @(posedge vga_clock or negedge resetn) begin
    if (!resetn) yCounter <= 10'd0;
    else if (x_wrap && y_wrap) yCounter <= 10'd0;
    else if (x_wrap) yCounter <= yCounter + 10'd1;
  end

  reg VGA_HS_d, VGA_VS_d, VGA_BLANK_d;
  
  always @(posedge vga_clock or negedge resetn) begin
    if (!resetn) begin
      VGA_HS_d    <= 1'b1; 
	  VGA_VS_d    <= 1'b1; 
	  VGA_BLANK_d <= 1'b0;
      VGA_HS      <= 1'b1; 
	  VGA_VS      <= 1'b1; 
	  VGA_BLANK   <= 1'b0;
    end else begin
      VGA_HS_d <= ~((xCounter >= C_HORZ_SYNC_START) && (xCounter <= C_HORZ_SYNC_END));
      VGA_VS_d <= ~((yCounter >= C_VERT_SYNC_START) && (yCounter <= C_VERT_SYNC_END));
	
      VGA_BLANK_d <=  vis640;
	  
      VGA_HS    <= VGA_HS_d;
      VGA_VS    <= VGA_VS_d;
      VGA_BLANK <= VGA_BLANK_d;
    end
  end
 
  reg [1:0] mode_meta, mode_sel_r;
  
  always @(posedge vga_clock or negedge resetn) begin
    if (!resetn) begin
      mode_meta  <= 2'b01;
      mode_sel_r <= 2'b01;
    end else begin
      mode_meta <= mode_sel;                                    
      if (xCounter == 10'd0 && yCounter == 10'd0) mode_sel_r <= mode_meta;  
    end
  end

  reg [1:0] shift_xy;     
  reg [9:0] x_off, y_off;

  always @(*) begin
    if (mode_sel_r == 2'b01) begin
      shift_xy = 2'd0;
      x_off    = 10'd240;
      y_off    = 10'd180;
    end else begin
      shift_xy = 2'd1;
      x_off    = 10'd160;
      y_off    = 10'd120;
    end
  end

  wire [9:0] win_w = (10'd160 << shift_xy);
  wire [9:0] win_h = (10'd120 << shift_xy);

  wire in_window = vis640 && (xCounter >= x_off) && (xCounter < (x_off + win_w)) 
                          && (yCounter >= y_off) && (yCounter < (y_off + win_h));
				
  reg in_window_d1;
  
  always @(posedge vga_clock or negedge resetn) begin
    if (!resetn) in_window_d1 <= 1'b0;
    else in_window_d1 <= in_window;
  end

  wire [9:0] dx = xCounter - x_off;
  wire [9:0] dy = yCounter - y_off;

  reg  [7:0] mem_x;   
  reg  [6:0] mem_y;   

  always @(*) begin
    mem_x = 8'd0; 
    mem_y = 7'd0;
    if (in_window) begin
      if (shift_xy == 2'd1) begin
        mem_x = dx[8:1];
        mem_y = dy[7:1];
      end else begin
        mem_x = dx[7:0];
        mem_y = dy[6:0];
      end
    end
  end

  wire [15:0] addr16 = {1'b0, mem_y, 7'd0} + {1'b0, mem_y, 5'd0} + {1'b0, mem_x};

  wire [7:0] R8 = pixel_colour[23:16];
  wire [7:0] G8 = pixel_colour[15:8];
  wire [7:0] B8 = pixel_colour[7:0];
  
  wire [9:0] R10 = {R8, R8[7:6]};
  wire [9:0] G10 = {G8, G8[7:6]};
  wire [9:0] B10 = {B8, B8[7:6]};
  
  always @(posedge vga_clock or negedge resetn) begin
    if (!resetn) begin
      VGA_R <= 10'd0; 
	   VGA_G <= 10'd0; 
	   VGA_B <= 10'd0;
    end else if (VGA_BLANK && in_window_d1) begin
      VGA_R <= R10; 
	   VGA_G <= G10; 
	   VGA_B <= B10;
    end else begin
      VGA_R <= 10'd0; 
	   VGA_G <= 10'd0; 
	   VGA_B <= 10'd0;
    end
  end

  assign VGA_SYNC = 1'b1;      
  assign VGA_CLK  = vga_clock; 
  assign memory_address = addr16[14:0];
  
endmodule
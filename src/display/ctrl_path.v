module ctrl_path (
  input  wire       clock, 
  input  wire       resetn,
  input  wire [9:0] SW,
  input  wire [3:0] KEY,
  input  wire       row_done,
  input  wire       col_done,
  output reg        rowCountEn,
  output reg        colCountEn,
  output reg        plot,
  output reg        reset_sig_x,
  output reg        reset_sig_y,
  output reg        ld_0, ld_1, ld_2, ld_3, ld_4, ld_5, ld_6, ld_7, ld_8,
  output reg  [3:0] sel_address,
  output wire [2:0] sel_im
);

  reg [5:0] current_state, next_state;

  localparam
    S_IDLE        = 6'd0,
    S_WAIT_KEY    = 6'd1,
    S_LD0         = 6'd2,   
	S_WAIT_C0     = 6'd3,
    S_LD1         = 6'd4,   
	S_WAIT_C1     = 6'd5,
    S_LD2         = 6'd6,   
	S_WAIT_C2     = 6'd7,
    S_LD3         = 6'd8,   
	S_WAIT_C3     = 6'd9,
    S_LD4         = 6'd10,  
	S_WAIT_C4     = 6'd11,
    S_LD5         = 6'd12,  
	S_WAIT_C5     = 6'd13,
    S_LD6         = 6'd14,  
	S_WAIT_C6     = 6'd15,
    S_LD7         = 6'd16,  
	S_WAIT_C7     = 6'd17,
    S_LD8         = 6'd18,  
	S_WAIT_C8     = 6'd19,
    S_DISPLAY     = 6'd20,
    S_INCR_X      = 6'd21,
    S_RESET_SIG   = 6'd22,
    S_INCR_Y      = 6'd23,
    S_WAIT_STABLE = 6'd24;

  always @(*) begin
    case (current_state)
      S_IDLE:        next_state = KEY[1] ? S_IDLE : S_WAIT_KEY;
	  
      S_WAIT_KEY:    next_state = KEY[1] ? S_LD0  : S_WAIT_C0;
      S_WAIT_C0:     next_state = S_LD0;
	  
      S_LD0:         next_state = S_WAIT_C1;
      S_WAIT_C1:     next_state = S_LD1;
      
	  S_LD1:         next_state = S_WAIT_C2;
      S_WAIT_C2:     next_state = S_LD2;
	  
      S_LD2:         next_state = S_WAIT_C3;
      S_WAIT_C3:     next_state = S_LD3;
	  
      S_LD3:         next_state = S_WAIT_C4;
      S_WAIT_C4:     next_state = S_LD4;
	  
      S_LD4:         next_state = S_WAIT_C5;
      S_WAIT_C5:     next_state = S_LD5;
	  
      S_LD5:         next_state = S_WAIT_C6;
      S_WAIT_C6:     next_state = S_LD6;
	  
      S_LD6:         next_state = S_WAIT_C7;
      S_WAIT_C7:     next_state = S_LD7;
	  
      S_LD7:         next_state = S_WAIT_C8;
      S_WAIT_C8:     next_state = S_LD8;
	  
      S_LD8:         next_state = S_WAIT_STABLE;
      S_WAIT_STABLE: next_state = S_DISPLAY;
	  
      S_DISPLAY:     next_state = S_INCR_X;
	  
      S_INCR_X:      next_state = row_done ? S_INCR_Y : S_WAIT_C0;
      S_INCR_Y:      next_state = col_done ? S_IDLE   : S_RESET_SIG;
      
	  S_RESET_SIG:   next_state = S_WAIT_C0;
	  
      default:       next_state = S_IDLE; 
    endcase
  end

  always @(*) begin
    rowCountEn   = 1'b0;
    colCountEn   = 1'b0;
    plot         = 1'b0;
    reset_sig_x  = 1'b0;
    reset_sig_y  = 1'b0;
    ld_0         = 1'b0; 
    ld_1         = 1'b0; 
    ld_2         = 1'b0; 
    ld_3         = 1'b0; 
    ld_4         = 1'b0;
    ld_5         = 1'b0; 
    ld_6         = 1'b0; 
    ld_7         = 1'b0; 
    ld_8         = 1'b0;
    sel_address  = 4'd4; 

    case (current_state)
      S_IDLE: begin   
        reset_sig_x = 1'b1;
        reset_sig_y = 1'b1;
      end

      S_WAIT_C0: sel_address = 4'd0;
      S_WAIT_C1: sel_address = 4'd1;
      S_WAIT_C2: sel_address = 4'd2;
      S_WAIT_C3: sel_address = 4'd3;
      S_WAIT_C4: sel_address = 4'd4;
      S_WAIT_C5: sel_address = 4'd5;
      S_WAIT_C6: sel_address = 4'd6;
      S_WAIT_C7: sel_address = 4'd7;
      S_WAIT_C8: sel_address = 4'd8;

      S_LD0: begin 
	    ld_0 = 1'b1; 
		sel_address = 4'd0; 
	  end
	  
      S_LD1: begin 
	    ld_1 = 1'b1; 
		sel_address = 4'd1; 
	  end
	  
      S_LD2: begin 
	    ld_2 = 1'b1; 
		sel_address = 4'd2; 
	  end
	  
      S_LD3: begin 
	    ld_3 = 1'b1; 
		sel_address = 4'd3; 
	  end
	  
      S_LD4: begin 
	    ld_4 = 1'b1; 
		sel_address = 4'd4; 
	  end
	  
      S_LD5: begin 
	    ld_5 = 1'b1; 
		sel_address = 4'd5; 
	  end
	  
      S_LD6: begin 
	    ld_6 = 1'b1; 
		sel_address = 4'd6; 
	  end
	  
      S_LD7: begin 
	    ld_7 = 1'b1; 
		sel_address = 4'd7; 
	  end
	  
      S_LD8: begin 
	    ld_8 = 1'b1; 
		sel_address = 4'd8; 
	  end

      S_DISPLAY: begin
        plot = 1'b1;
      end

      S_INCR_X: begin
        rowCountEn = 1'b1;
      end

      S_RESET_SIG: begin
        reset_sig_x = 1'b1;
      end

      S_INCR_Y: begin
        colCountEn = 1'b1;
      end
	  
	  default: ;
    endcase
  end

  always @(posedge clock) begin
    if (!resetn) current_state <= S_IDLE;
    else current_state <= next_state;
  end
  
  assign sel_im = SW[9:7];

endmodule
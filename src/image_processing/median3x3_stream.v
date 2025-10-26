module median3x3_stream #(
  parameter integer W = 160,
  parameter integer H = 120,
  parameter integer BORDER_MODE = 1  
)(
  input  wire       clk,
  input  wire       resetn,

  input  wire       in_valid,
  output wire       in_ready,
  input  wire [7:0] in_pixel,
  input  wire       in_sof,
  input  wire       in_eol,
  
  output reg        out_valid,
  input  wire       out_ready,
  output reg  [7:0] out_pixel,
  output reg        out_sof,
  output reg        out_eol
);

  localparam integer BORDER_ZERO      = 0;
  localparam integer BORDER_REPLICATE = 1;

  reg       skid_full;
  reg [7:0] skid_pixel;
  reg       skid_sof, skid_eol;

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      skid_full  <= 1'b0;
      skid_pixel <= 8'd0;
      skid_sof   <= 1'b0;
      skid_eol   <= 1'b0;
    end else begin
      if (in_valid && !in_ready) begin
        skid_full  <= 1'b1;
        skid_pixel <= in_pixel;
        skid_sof   <= in_sof;
        skid_eol   <= in_eol;
      end else if (out_ready && skid_full) begin
        skid_full <= 1'b0;
      end
    end
  end

  wire [7:0] px_in  = skid_full  ? skid_pixel : in_pixel;
  wire       sof_in = skid_full  ? skid_sof   : in_sof;
  wire       eol_in = skid_full  ? skid_eol   : in_eol;
  wire       v_in   = (skid_full ? 1'b1 : in_valid) && out_ready;

  reg [7:0] lb0 [0:W - 1]; 
  reg [7:0] lb1 [0:W - 1];  

  reg [7:0] x;   
  reg [6:0] y; 

  reg [7:0] r0a, r0b, r0c;
  reg [7:0] r1a, r1b, r1c; 
  reg [7:0] r2a, r2b, r2c;

  wire [7:0] prev0 = (y == 7'd0) ? px_in : lb0[x];                           
  wire [7:0] prev1 = (y == 7'd0) ? px_in : ((y == 7'd1) ? lb0[x] : lb1[x]);   

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      x <= 8'd0; 
	  y <= 7'd0;
      r0a <= 8'd0; r0b <= 8'd0; r0c <= 8'd0;
      r1a <= 8'd0; r1b <= 8'd0; r1c <= 8'd0;
      r2a <= 8'd0; r2b <= 8'd0; r2c <= 8'd0;
    end else if (v_in) begin
      r0a <= (x == 8'd0) ? prev1 : r0b;
      r0b <= (x == 8'd0) ? prev1 : r0c;
      r0c <= prev1;
      r1a <= (x == 8'd0) ? prev0 : r1b;
      r1b <= (x == 8'd0) ? prev0 : r1c;
      r1c <= prev0;
      r2a <= (x == 8'd0) ? px_in : r2b;
      r2b <= (x == 8'd0) ? px_in : r2c;
      r2c <= px_in;

      lb1[x] <= (y == 7'd0) ? px_in : lb0[x];
      lb0[x] <= px_in;

      if (eol_in || (x == 8'd159)) begin
        x <= 8'd0;
        y <= (y == 7'd119) ? 7'd0 : (y + 7'd1);
      end else begin
        x <= x + 8'd1;
      end
    end
  end

  wire [7:0] p00=r0a, p01=r0b, p02=r0c;
  wire [7:0] p10=r1a, p11=r1b, p12=r1c;
  wire [7:0] p20=r2a, p21=r2b, p22=r2c;

  wire at_left  = (x < 8'd2);  
  wire at_top2  = (y < 7'd2); 
  wire use_zero = (BORDER_MODE == BORDER_ZERO) && (at_left || at_top2);

  wire [7:0] q00 = use_zero ? 8'd0 : p00;
  wire [7:0] q01 = use_zero ? 8'd0 : p01;
  wire [7:0] q02 = use_zero ? 8'd0 : p02;
  wire [7:0] q10 = use_zero ? 8'd0 : p10;
  wire [7:0] q11 = use_zero ? 8'd0 : p11;
  wire [7:0] q12 = use_zero ? 8'd0 : p12;
  wire [7:0] q20 = use_zero ? 8'd0 : p20;
  wire [7:0] q21 = use_zero ? 8'd0 : p21;
  wire [7:0] q22 = use_zero ? 8'd0 : p22;

  wire [7:0] median9_local;
  
  median3x3 u_median_core (
    .p0  (q00), .p1 (q01), .p2 (q02),
    .p3  (q10), .p4 (q11), .p5 (q12),
    .p6  (q20), .p7 (q21), .p8 (q22),
    .med (median9_local)
  );

  reg sof_d, eol_d;
  
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      out_valid <= 1'b0;
      out_pixel <= 8'd0;
      out_sof   <= 1'b0;
      out_eol   <= 1'b0;
      sof_d     <= 1'b0;
      eol_d     <= 1'b0;
    end else if (out_ready) begin
      sof_d     <= sof_in;
      eol_d     <= eol_in;
      out_valid <= v_in;
      out_pixel <= median9_local;
      out_sof   <= sof_d;
      out_eol   <= eol_d;
    end
  end

  assign in_ready = (!skid_full) || out_ready;

endmodule
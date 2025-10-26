module pixel_register #(
  parameter integer       WIDTH       = 24,
  parameter integer       ASYNC_RESET = 0,              
  parameter [WIDTH - 1:0] RESET_VALUE = {WIDTH{1'b0}}  
)(
  input  wire               clock,
  input  wire               resetn,       
  input  wire               enable,  
  input  wire [WIDTH - 1:0] colour_i,
  output reg  [WIDTH - 1:0] colour_o
);

  generate
    if (ASYNC_RESET != 0) begin : g_async
      always @(posedge clock or negedge resetn) begin
        if (!resetn)     colour_o <= RESET_VALUE;
        else if (enable) colour_o <= colour_i;
      end
    end else begin : g_sync
      always @(posedge clock) begin
        if (!resetn)     colour_o <= RESET_VALUE;
        else if (enable) colour_o <= colour_i;
      end
    end
  endgenerate

endmodule
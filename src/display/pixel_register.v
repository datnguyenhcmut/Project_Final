//==============================================================================
// Pixel Register Module - Enhanced for Lane Detection Pipeline
//==============================================================================
// Features:
//   - Configurable data width (default 24-bit RGB or 8-bit grayscale)
//   - Sync/Async reset selection
//   - Data valid propagation for pipeline synchronization
//   - Bypass mode for debugging
//   - Multi-stage delay option (useful for lane detection ROI alignment)
//==============================================================================

module pixel_register #(
  parameter integer       WIDTH        = 24,            // Data width (24 for RGB, 8 for grayscale)
  parameter integer       ASYNC_RESET  = 0,             // 0: Sync reset, 1: Async reset
  parameter [WIDTH - 1:0] RESET_VALUE  = {WIDTH{1'b0}}, // Reset value
  parameter integer       PIPE_STAGES  = 1,             // Pipeline delay stages (1-8)
  parameter integer       BYPASS_EN    = 0              // 1: Enable bypass mode input
)(
  input  wire               clock,
  input  wire               resetn,       
  input  wire               enable,       // Pipeline enable
  input  wire               valid_i,      // Input data valid (for lane detection sync)
  input  wire               bypass,       // Bypass register (when BYPASS_EN=1)
  input  wire [WIDTH - 1:0] colour_i,     // Input pixel data
  output wire [WIDTH - 1:0] colour_o,     // Output pixel data
  output wire               valid_o       // Output data valid (delayed)
);

  // Pipeline stage count clamped to valid range
  localparam STAGES = (PIPE_STAGES < 1) ? 1 : (PIPE_STAGES > 8) ? 8 : PIPE_STAGES;

  // Internal pipeline registers
  reg [WIDTH - 1:0] pipe_data  [0:STAGES-1];
  reg [STAGES-1:0]  pipe_valid;
  
  integer i;

  //----------------------------------------------------------------------------
  // Pipeline Implementation
  //----------------------------------------------------------------------------
  generate
    if (ASYNC_RESET != 0) begin : g_async
      //-- Asynchronous Reset --
      always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
          for (i = 0; i < STAGES; i = i + 1) begin
            pipe_data[i] <= RESET_VALUE;
          end
          pipe_valid <= {STAGES{1'b0}};
        end 
        else if (enable) begin
          // First stage
          pipe_data[0]  <= colour_i;
          pipe_valid[0] <= valid_i;
          // Shift pipeline
          for (i = 1; i < STAGES; i = i + 1) begin
            pipe_data[i]  <= pipe_data[i-1];
            pipe_valid[i] <= pipe_valid[i-1];
          end
        end
      end
    end 
    else begin : g_sync
      //-- Synchronous Reset --
      always @(posedge clock) begin
        if (!resetn) begin
          for (i = 0; i < STAGES; i = i + 1) begin
            pipe_data[i] <= RESET_VALUE;
          end
          pipe_valid <= {STAGES{1'b0}};
        end 
        else if (enable) begin
          // First stage
          pipe_data[0]  <= colour_i;
          pipe_valid[0] <= valid_i;
          // Shift pipeline
          for (i = 1; i < STAGES; i = i + 1) begin
            pipe_data[i]  <= pipe_data[i-1];
            pipe_valid[i] <= pipe_valid[i-1];
          end
        end
      end
    end
  endgenerate

  //----------------------------------------------------------------------------
  // Output Assignment (with optional bypass)
  //----------------------------------------------------------------------------
  generate
    if (BYPASS_EN != 0) begin : g_bypass
      assign colour_o = bypass ? colour_i : pipe_data[STAGES-1];
      assign valid_o  = bypass ? valid_i  : pipe_valid[STAGES-1];
    end 
    else begin : g_no_bypass
      assign colour_o = pipe_data[STAGES-1];
      assign valid_o  = pipe_valid[STAGES-1];
    end
  endgenerate

endmodule
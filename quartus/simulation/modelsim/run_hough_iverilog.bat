@echo off
echo =====================================================
echo   HOUGH TRANSFORM TESTBENCH (Icarus Verilog)
echo =====================================================
echo.

set SRC=..\..\..\src\image_processing

echo [1/3] Compiling with iverilog...
iverilog -g2012 -o tb_hough.vvp ^
  -I %SRC% ^
  %SRC%\hough_stream_path.v ^
  tb_hough_stream.v

if %errorlevel% neq 0 (
  echo [ERROR] Compilation failed!
  exit /b 1
)

echo [2/3] Running simulation...
echo.
vvp tb_hough.vvp

echo.
echo [3/3] Generating waveform (optional)...
REM Uncomment below if you want VCD waveform
REM vvp tb_hough.vvp +vcd
REM gtkwave tb_hough.vcd

echo.
echo =====================================================
echo   Simulation Complete!
echo   Check hough_output.mem for visual output
echo =====================================================

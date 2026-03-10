@echo off
setlocal

set MODELSIM_PATH=C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set SRC=..\..\..\src
set IMG_PROC=%SRC%\image_processing
set DISPLAY=%SRC%\display

echo =====================================================
echo   HOUGH TRANSFORM STREAM PATH - TESTBENCH
echo =====================================================
echo.

REM Create work library
if exist work_hough rmdir /s /q work_hough
vlib work_hough
if %errorlevel% neq 0 goto :error

echo [1/2] Compiling source files...

REM Compile Hough stream path module
vlog -work work_hough ^
  %IMG_PROC%\hough_stream_path.v

if %errorlevel% neq 0 goto :error

echo [2/2] Compiling and running testbench...

vlog -work work_hough tb_hough_stream.v
if %errorlevel% neq 0 goto :error

echo.
echo Running simulation...
echo.

vsim -c -do "run -all; quit -f" work_hough.tb_hough_stream

echo.
echo =====================================================
echo   Hough Simulation Complete!
echo   Check hough_output.mem for visual verification
echo =====================================================

goto :end

:error
echo.
echo [ERROR] Compilation or simulation failed!
exit /b 1

:end
endlocal

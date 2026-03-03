@echo off
setlocal

set MODELSIM_PATH=C:\intelFPGA\18.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set SRC=..\..\..\src
set IMG_PROC=%SRC%\image_processing
set DISPLAY=%SRC%\display
set VGA=%SRC%\vga_modules

echo =====================================================
echo   FPGA Edge Detection - ModelSim Simulation
echo =====================================================
echo.

REM Create work library
if exist work rmdir /s /q work
vlib work
if %errorlevel% neq 0 goto :error

echo [1/3] Compiling source files...

REM Compile image processing modules
vlog -work work ^
  %IMG_PROC%\rgb2gray8.v ^
  %IMG_PROC%\med3_8.v ^
  %IMG_PROC%\median3x3.v ^
  %IMG_PROC%\sobel_3x3_gray.v ^
  %IMG_PROC%\scharr_3x3_gray.v ^
  %IMG_PROC%\impulse_switch_8.v ^
  %IMG_PROC%\threshold_binary.v ^
  %IMG_PROC%\image_processing_uni.v

if %errorlevel% neq 0 goto :error

echo [2/3] Compiling testbench...

vlog -work work tb_edge_detection.v
if %errorlevel% neq 0 goto :error

echo [3/3] Running simulation...
echo.

vsim -c -do "run -all; quit -f" work.tb_edge_detection

echo.
echo =====================================================
echo   Simulation Complete!
echo =====================================================
goto :end

:error
echo.
echo [ERROR] Simulation failed!
pause
exit /b 1

:end
pause

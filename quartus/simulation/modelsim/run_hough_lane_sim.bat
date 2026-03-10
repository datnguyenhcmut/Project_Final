@echo off
setlocal

set MODELSIM_PATH=C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set SRC=..\..\..\src
set IMG_PROC=%SRC%\image_processing
set DISPLAY=%SRC%\display

echo =====================================================
echo   Hough Lane Detection - ModelSim Simulation
echo =====================================================
echo.

REM Create work library
if exist work_hough_lane rmdir /s /q work_hough_lane
vlib work_hough_lane
if %errorlevel% neq 0 goto :error

echo [1/4] Compiling image processing modules...

vlog -work work_hough_lane ^
  %IMG_PROC%\rgb2gray8.v ^
  %IMG_PROC%\med3_8.v ^
  %IMG_PROC%\median3x3.v ^
  %IMG_PROC%\median3x3_stream.v ^
  %IMG_PROC%\window3x3_stream.v ^
  %IMG_PROC%\sobel_3x3_gray.v ^
  %IMG_PROC%\scharr_3x3_gray.v ^
  %IMG_PROC%\threshold_binary.v ^
  %IMG_PROC%\sp_preproc_constbg.v ^
  %IMG_PROC%\hough_stream_path.v

if %errorlevel% neq 0 goto :error

echo [2/4] Compiling display modules...

vlog -work work_hough_lane ^
  %DISPLAY%\sync2.v ^
  %DISPLAY%\edge_stream_path.v

if %errorlevel% neq 0 goto :error

echo [3/4] Compiling testbench...

vlog -work work_hough_lane tb_hough_lane.v
if %errorlevel% neq 0 goto :error

echo.
echo [4/4] Running simulation...
echo.

vsim -c -do "run -all; quit" work_hough_lane.tb_hough_lane

if %errorlevel% neq 0 goto :error

echo.
echo =====================================================
echo   Simulation completed successfully!
echo =====================================================
goto :end

:error
echo.
echo =====================================================
echo   ERROR: Simulation failed!
echo =====================================================
pause
exit /b 1

:end
pause

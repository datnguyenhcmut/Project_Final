@echo off
setlocal

set MODELSIM_PATH=C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set SRC=..\..\..\src
set IMG_PROC=%SRC%\image_processing
set DISPLAY=%SRC%\display

echo =====================================================
echo   Edge Stream Path - ModelSim Simulation
echo =====================================================
echo.

REM Create work library
if exist work_edge_stream rmdir /s /q work_edge_stream
vlib work_edge_stream
if %errorlevel% neq 0 goto :error

echo [1/3] Compiling image processing modules...

vlog -work work_edge_stream ^
  %IMG_PROC%\rgb2gray8.v ^
  %IMG_PROC%\med3_8.v ^
  %IMG_PROC%\median3x3.v ^
  %IMG_PROC%\median3x3_stream.v ^
  %IMG_PROC%\window3x3_stream.v ^
  %IMG_PROC%\sobel_3x3_gray.v ^
  %IMG_PROC%\scharr_3x3_gray.v ^
  %IMG_PROC%\threshold_binary.v ^
  %IMG_PROC%\sp_preproc_constbg.v

if %errorlevel% neq 0 goto :error

echo [2/3] Compiling display modules...

vlog -work work_edge_stream ^
  %DISPLAY%\sync2.v ^
  %DISPLAY%\edge_stream_path.v

if %errorlevel% neq 0 goto :error

echo [3/3] Compiling testbench...

vlog -work work_edge_stream tb_edge_stream_path.v
if %errorlevel% neq 0 goto :error

echo.
echo Running simulation...
echo.

vsim -c -do "run -all; quit -f" work_edge_stream.tb_edge_stream_path

echo.
echo =====================================================
echo   Simulation Complete!
echo =====================================================
goto :end

:error
echo.
echo [ERROR] Compilation or simulation failed!
echo Check error messages above.
pause
exit /b 1

:end
pause

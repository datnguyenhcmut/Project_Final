@echo off
setlocal

set MODELSIM_PATH=C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set SRC=..\..\..\src
set IMG_PROC=%SRC%\image_processing
set DISPLAY=%SRC%\display
set VGA=%SRC%\vga_modules

echo =====================================================
echo   TOP MODULE WITH HOUGH - FULL DATAPATH TEST
echo =====================================================
echo.

REM Create work library
if exist work_top_hough rmdir /s /q work_top_hough
vlib work_top_hough
if %errorlevel% neq 0 goto :error

echo [1/4] Compiling image processing modules...

vlog -work work_top_hough ^
  %IMG_PROC%\rgb2gray8.v ^
  %IMG_PROC%\med3_8.v ^
  %IMG_PROC%\median3x3.v ^
  %IMG_PROC%\median3x3_stream.v ^
  %IMG_PROC%\window3x3_stream.v ^
  %IMG_PROC%\sobel_3x3_gray.v ^
  %IMG_PROC%\scharr_3x3_gray.v ^
  %IMG_PROC%\impulse_switch_8.v ^
  %IMG_PROC%\threshold_binary.v ^
  %IMG_PROC%\sp_preproc_constbg.v ^
  %IMG_PROC%\hough_stream_path.v

if %errorlevel% neq 0 goto :error

echo [2/4] Compiling display modules...

vlog -work work_top_hough ^
  %DISPLAY%\sync2.v ^
  %DISPLAY%\pixel_register.v ^
  %DISPLAY%\address_adaptor.v ^
  %DISPLAY%\ctrl_path.v ^
  %DISPLAY%\data_path.v ^
  %DISPLAY%\image_bank_shared.v ^
  %DISPLAY%\edge_stream_path.v ^
  %DISPLAY%\top.v

if %errorlevel% neq 0 goto :error

echo [3/4] Compiling VGA modules...

vlog -work work_top_hough ^
  %VGA%\vga_adapter.v ^
  %VGA%\vga_controller.v ^
  %VGA%\vga_address_translator.v ^
  %VGA%\vga_pll.v

if %errorlevel% neq 0 goto :error

echo [4/4] Compiling testbench...

vlog -work work_top_hough tb_top_hough.v
if %errorlevel% neq 0 goto :error

echo.
echo =====================================================
echo   Running TOP HOUGH simulation...
echo =====================================================
echo.

vsim -c -do "run -all; quit -f" work_top_hough.tb_top_hough

echo.
echo =====================================================
echo   Simulation Complete!
echo =====================================================

goto :end

:error
echo.
echo [ERROR] Compilation or simulation failed!
echo Check the error messages above.
exit /b 1

:end
endlocal

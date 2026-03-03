@echo off
setlocal

set MODELSIM_PATH=C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set SRC=..\..\..\src
set DISPLAY=%SRC%\display

echo =====================================================
echo   PIXEL_REGISTER - Golden Reference Verification
echo =====================================================
echo.

REM Create work library
if exist work_pixel rmdir /s /q work_pixel
vlib work_pixel
if %errorlevel% neq 0 goto :error

echo [1/3] Compiling pixel_register.v...

vlog -work work_pixel %DISPLAY%\pixel_register.v
if %errorlevel% neq 0 goto :error

echo [2/3] Compiling testbench...

vlog -work work_pixel tb_pixel_register.v
if %errorlevel% neq 0 goto :error

echo [3/3] Running simulation...
echo.

vsim -c -do "run -all; quit -f" work_pixel.tb_pixel_register

echo.
echo =====================================================
echo   Simulation Complete! Check tb_pixel_register.vcd
echo =====================================================

goto :end

:error
echo.
echo =====================================================
echo   ERROR: Simulation failed!
echo =====================================================
exit /b 1

:end
echo.
pause

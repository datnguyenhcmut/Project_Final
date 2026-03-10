@echo off
REM Run ROM verification testbench with iverilog
cd /d "%~dp0"

echo ==========================================
echo   ROM Load Verification Test
echo ==========================================
echo.

REM Check if iverilog exists
where iverilog >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: iverilog not found in PATH
    echo Please install Icarus Verilog or add to PATH
    pause
    exit /b 1
)

REM Compile
echo Compiling...
iverilog -o tb_rom_verify.vvp tb_rom_verify.v
if %errorlevel% neq 0 (
    echo Compilation failed!
    pause
    exit /b 1
)

REM Run simulation
echo.
echo Running simulation...
echo.
vvp tb_rom_verify.vvp

echo.
pause

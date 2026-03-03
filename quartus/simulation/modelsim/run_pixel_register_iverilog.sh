#!/bin/bash
# Script to run pixel_register testbench with Icarus Verilog

SRC="../../../src"
DISPLAY="$SRC/display"

echo "====================================================="
echo "  PIXEL_REGISTER - Golden Reference Verification"
echo "  Using Icarus Verilog"
echo "====================================================="
echo ""

# Compile
echo "[1/2] Compiling..."
iverilog -o tb_pixel_register.vvp \
    -I $DISPLAY \
    $DISPLAY/pixel_register.v \
    tb_pixel_register.v

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

# Run simulation
echo "[2/2] Running simulation..."
echo ""
vvp tb_pixel_register.vvp

echo ""
echo "====================================================="
echo "  Waveform saved to: tb_pixel_register.vcd"
echo "  View with: gtkwave tb_pixel_register.vcd"
echo "====================================================="

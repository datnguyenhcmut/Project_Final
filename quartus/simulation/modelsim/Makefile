#===============================================================================
# Makefile for FPGA Edge Detection Simulation
# ModelSim Location: C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem
#===============================================================================

# Tool paths
MODELSIM_PATH = C:/intelFPGA_lite/18.1/modelsim_ase/win32aloem
VLIB  = $(MODELSIM_PATH)/vlib
VLOG  = $(MODELSIM_PATH)/vlog
VSIM  = $(MODELSIM_PATH)/vsim

# Source directories
SRC        = ../../../src
IMG_PROC   = $(SRC)/image_processing
DISPLAY    = $(SRC)/display
VGA        = $(SRC)/vga_modules

# Work libraries
WORK_PIXEL = work_pixel
WORK_EDGE  = work_edge

#===============================================================================
# Targets
#===============================================================================

.PHONY: all clean pixel_register edge_detection help

help:
	@echo "=============================================="
	@echo "  FPGA Edge Detection - Simulation Makefile"
	@echo "=============================================="
	@echo ""
	@echo "  make pixel_register  - Run pixel_register TB"
	@echo "  make edge_detection  - Run edge_detection TB"
	@echo "  make all             - Run all testbenches"
	@echo "  make clean           - Clean work libraries"
	@echo ""

#-------------------------------------------------------------------------------
# pixel_register testbench
#-------------------------------------------------------------------------------
pixel_register: $(WORK_PIXEL)
	@echo "[Compiling] pixel_register.v"
	@$(VLOG) -work $(WORK_PIXEL) $(DISPLAY)/pixel_register.v
	@echo "[Compiling] tb_pixel_register.v"
	@$(VLOG) -work $(WORK_PIXEL) tb_pixel_register.v
	@echo ""
	@echo "=============================================="
	@echo "  Running pixel_register simulation..."
	@echo "=============================================="
	@$(VSIM) -c -do "run -all; quit -f" $(WORK_PIXEL).tb_pixel_register

$(WORK_PIXEL):
	@echo "[Creating library] $(WORK_PIXEL)"
	@$(VLIB) $(WORK_PIXEL)

#-------------------------------------------------------------------------------
# edge_detection testbench  
#-------------------------------------------------------------------------------
EDGE_SRC = \
	$(IMG_PROC)/rgb2gray8.v \
	$(IMG_PROC)/med3_8.v \
	$(IMG_PROC)/median3x3.v \
	$(IMG_PROC)/sobel_3x3_gray.v \
	$(IMG_PROC)/scharr_3x3_gray.v \
	$(IMG_PROC)/impulse_switch_8.v \
	$(IMG_PROC)/threshold_binary.v \
	$(IMG_PROC)/image_processing_uni.v

edge_detection: $(WORK_EDGE)
	@echo "[Compiling] Image processing modules..."
	@$(VLOG) -work $(WORK_EDGE) $(EDGE_SRC)
	@echo "[Compiling] tb_edge_detection.v"
	@$(VLOG) -work $(WORK_EDGE) tb_edge_detection.v
	@echo ""
	@echo "=============================================="
	@echo "  Running edge_detection simulation..."
	@echo "=============================================="
	@$(VSIM) -c -do "run -all; quit -f" $(WORK_EDGE).tb_edge_detection

$(WORK_EDGE):
	@echo "[Creating library] $(WORK_EDGE)"
	@$(VLIB) $(WORK_EDGE)

#-------------------------------------------------------------------------------
# Run all
#-------------------------------------------------------------------------------
all: pixel_register edge_detection
	@echo ""
	@echo "=============================================="
	@echo "  All simulations completed!"
	@echo "=============================================="

#-------------------------------------------------------------------------------
# Clean
#-------------------------------------------------------------------------------
clean:
	@echo "[Cleaning] Removing work libraries..."
	-@rm -rf $(WORK_PIXEL) $(WORK_EDGE) 2>/dev/null || rmdir /s /q $(WORK_PIXEL) $(WORK_EDGE) 2>nul
	-@rm -f *.vcd transcript vsim.wlf 2>/dev/null || del /q *.vcd transcript vsim.wlf 2>nul
	@echo "[Done] Clean complete"

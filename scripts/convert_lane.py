#!/usr/bin/env python3
"""
Quick Convert: Lane image to MIF for FPGA ROM
Usage: python convert_lane.py [input_image]
Output: Creates image_01.mif, image_02.mif, image_03.mif in ROM folder
"""
from PIL import Image
import os
import sys

# Settings
TARGET_W = 160
TARGET_H = 120

# Input file - can be overridden by command line
if len(sys.argv) > 1:
    INPUT_FILE = sys.argv[1]
else:
    INPUT_FILE = "image_lane_detaction/image.png"

# Output to ROM folder
OUTPUT_DIR = "../quartus/mif_files/[random]_single_image_p_04_02_01_mif"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def write_mif(pixels, out_path, w, h):
    """Write MIF file in Quartus format (ADDRESS=HEX, DATA=BIN)"""
    depth = w * h
    with open(out_path, "w") as f:
        f.write("WIDTH = 24;\n")
        f.write(f"DEPTH = {depth};\n\n")
        f.write("ADDRESS_RADIX = HEX;\n")
        f.write("DATA_RADIX = BIN;\n\n")
        f.write("CONTENT BEGIN\n")
        
        for i, (r, g, b) in enumerate(pixels):
            binary = f"{r:08b}{g:08b}{b:08b}"
            addr = f"{i:04X}"
            f.write(f"\t{addr} : {binary};\n")
        
        f.write("END;\n")
    print(f"  Created: {out_path}")

def main():
    print(f"Converting {INPUT_FILE} to MIF for ROM...")
    
    # Load and resize
    img = Image.open(INPUT_FILE).convert("RGB")
    print(f"Original size: {img.size}")
    
    img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    print(f"Resized to: {img.size}")
    
    # Get pixels
    pixels = list(img.getdata())
    depth = TARGET_W * TARGET_H
    
    # Write 3 MIF files for ROM (image_01, image_02, image_03)
    print(f"\nWriting to {OUTPUT_DIR}:")
    for i in range(1, 4):
        out_path = os.path.join(OUTPUT_DIR, f"image_{i:02d}.mif")
        write_mif(pixels, out_path, TARGET_W, TARGET_H)
    
    print(f"\nTotal pixels: {depth}")
    
    # Stats
    black_cnt = sum(1 for p in pixels if p == (0, 0, 0))
    white_cnt = sum(1 for p in pixels if p == (255, 255, 255))
    bright_cnt = sum(1 for p in pixels if p[0] > 200)
    print(f"\nPixel stats:")
    print(f"  Black (0,0,0): {black_cnt}")
    print(f"  White (255,255,255): {white_cnt}")
    print(f"  Bright (R>200): {bright_cnt}")
    print(f"  Other: {depth - black_cnt - white_cnt}")
    
    print(f"\n=== DONE! ROM files ready in {OUTPUT_DIR} ===")

if __name__ == "__main__":
    main()

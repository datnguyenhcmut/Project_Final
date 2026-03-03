#!/usr/bin/env python3
"""
Quick Convert: Lane image to MIF for FPGA simulation
"""
from PIL import Image
import os

# Settings
INPUT_FILE = "image_lan/image.png"
OUTPUT_FILE = "image_lan/lane_160x120.mif"
TARGET_W = 160
TARGET_H = 120

def main():
    print(f"Converting {INPUT_FILE} to MIF...")
    
    # Load and resize
    img = Image.open(INPUT_FILE).convert("RGB")
    print(f"Original size: {img.size}")
    
    img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    print(f"Resized to: {img.size}")
    
    # Get pixels
    pixels = list(img.getdata())
    depth = TARGET_W * TARGET_H
    
    # Write MIF
    with open(OUTPUT_FILE, "w") as f:
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
    
    print(f"Created: {OUTPUT_FILE}")
    print(f"Pixels: {depth}")
    
    # Also create binary mem file for simulation
    mem_file = OUTPUT_FILE.replace(".mif", ".mem")
    with open(mem_file, "w") as f:
        for r, g, b in pixels:
            f.write(f"{r:08b}{g:08b}{b:08b}\n")
    print(f"Created: {mem_file}")
    
    # Stats
    black_cnt = sum(1 for p in pixels if p == (0, 0, 0))
    white_cnt = sum(1 for p in pixels if p == (255, 255, 255))
    print(f"\nPixel stats:")
    print(f"  Black: {black_cnt}")
    print(f"  White: {white_cnt}")
    print(f"  Other: {depth - black_cnt - white_cnt}")

if __name__ == "__main__":
    main()

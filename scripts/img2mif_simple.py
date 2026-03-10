"""
Convert image to MIF format for FPGA ROM
Usage: python img2mif_simple.py <input_image> <output.mif> [width] [height]

Default size: 160x120
"""

from PIL import Image
import sys
import os

def convert_image_to_mif(input_path, output_path, target_w=160, target_h=120):
    # Load and resize image
    img = Image.open(input_path)
    img = img.convert('RGB')
    img = img.resize((target_w, target_h), Image.LANCZOS)
    
    depth = target_w * target_h
    
    with open(output_path, 'w') as f:
        f.write(f"-- Converted from: {os.path.basename(input_path)}\n")
        f.write(f"-- Size: {target_w}x{target_h}\n")
        f.write(f"WIDTH=24;\n")
        f.write(f"DEPTH={depth};\n\n")
        f.write(f"ADDRESS_RADIX=UNS;\n")
        f.write(f"DATA_RADIX=HEX;\n\n")
        f.write(f"CONTENT BEGIN\n")
        
        addr = 0
        for y in range(target_h):
            for x in range(target_w):
                r, g, b = img.getpixel((x, y))
                rgb24 = (r << 16) | (g << 8) | b
                f.write(f"    {addr}  :  {rgb24:06X};\n")
                addr += 1
        
        f.write("END;\n")
    
    print(f"Converted {input_path} -> {output_path}")
    print(f"Size: {target_w}x{target_h} = {depth} pixels")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python img2mif_simple.py <input_image> <output.mif> [width] [height]")
        print("Example: python img2mif_simple.py road.png road_test.mif 160 120")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 160
    height = int(sys.argv[4]) if len(sys.argv) > 4 else 120
    
    convert_image_to_mif(input_file, output_file, width, height)

"""
Generate realistic road test MIF based on attached image pattern
"""

def generate_road_mif(output_path, w=160, h=120):
    pixels = []
    
    for y in range(h):
        row = []
        for x in range(w):
            # Default: road surface (gray asphalt)
            if y < 25:
                # Top area - sky/horizon (lighter)
                r = g = b = 0x90 + (25 - y) * 2
            elif y < 35:
                # Transition zone
                r = g = b = 0x70
            else:
                # Road surface with slight texture variation
                base = 0x60
                if (x + y) % 7 == 0:
                    base = 0x58
                elif (x * y) % 11 == 0:
                    base = 0x68
                r = g = b = base
            
            # Left lane line (dashed center line)
            # Angle from (45, h-1) to (72, 25)
            if y >= 25:
                left_x = 72 - int(((h - 1 - y) * 27) / (h - 26))
                if abs(x - left_x) <= 2:
                    # Dashed pattern: 10 pixels on, 8 pixels off
                    dash_seg = (y // 10) % 2
                    if dash_seg == 0:
                        r = g = b = 0xFF if abs(x - left_x) <= 1 else 0xE0
            
            # Right lane line (solid white edge line) 
            # Almost vertical, from (152, h-1) to (148, 20)
            if y >= 20:
                right_x = 152 - int(((h - 1 - y) * 4) / (h - 21))
                if x >= right_x and x <= right_x + 4:
                    r = g = b = 0xFF if x <= right_x + 2 else 0xE0
            
            # Right side (grass/dirt area)
            if x >= 155 and y < 80:
                r, g, b = 0x70, 0x70, 0x60
            
            rgb24 = (r << 16) | (g << 8) | b
            row.append(rgb24)
        pixels.append(row)
    
    # Write MIF file (Quartus format) - Match original image format
    with open(output_path, 'w') as f:
        f.write(f"WIDTH = 24;\n")
        f.write(f"DEPTH = {w*h};\n\n")
        f.write("ADDRESS_RADIX = HEX;\n")
        f.write("DATA_RADIX = BIN;\n\n")
        f.write("CONTENT BEGIN\n")
        
        addr = 0
        for y in range(h):
            for x in range(w):
                rgb24 = pixels[y][x]
                # Convert to 24-bit binary string
                bin_str = format(rgb24, '024b')
                f.write(f"\t{addr:04X} : {bin_str};\n")
                addr += 1
        
        f.write("END;\n")
    
    print(f"Generated {output_path}: {w}x{h} = {w*h} pixels")
    
    # Also write simple hex file for $readmemh
    hex_path = output_path.replace('.mif', '.hex')
    with open(hex_path, 'w') as f:
        for y in range(h):
            for x in range(w):
                f.write(f"{pixels[y][x]:06X}\n")
    print(f"Generated {hex_path} for Verilog $readmemh")

if __name__ == "__main__":
    generate_road_mif("road_test.mif")

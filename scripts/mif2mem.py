"""
Convert MIF to MEM format for Verilog $readmemh
Usage: python mif2mem.py input.mif output.mem
"""
import sys
import re

def mif_to_mem(input_path, output_path):
    with open(input_path, 'r') as f:
        lines = f.readlines()
    
    # Parse MIF content
    in_content = False
    data = {}
    
    for line in lines:
        line = line.strip()
        if line.startswith('CONTENT BEGIN'):
            in_content = True
            continue
        if line.startswith('END'):
            break
        if in_content and ':' in line:
            # Parse "addr : data;" format
            match = re.match(r'\s*(\d+)\s*:\s*([0-9A-Fa-f]+)\s*;', line)
            if match:
                addr = int(match.group(1))
                value = match.group(2)
                data[addr] = value
    
    # Write MEM file (hex format, one value per line)
    max_addr = max(data.keys()) if data else 0
    with open(output_path, 'w') as f:
        f.write(f"// Converted from {input_path}\n")
        f.write(f"// Total: {max_addr + 1} entries\n")
        for addr in range(max_addr + 1):
            value = data.get(addr, "000000")
            f.write(f"{value}\n")
    
    print(f"Converted {input_path} -> {output_path}")
    print(f"Total entries: {max_addr + 1}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python mif2mem.py input.mif output.mem")
        sys.exit(1)
    mif_to_mem(sys.argv[1], sys.argv[2])

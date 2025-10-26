from PIL import Image
import os
import sys

try:
  import numpy as np
except ImportError:
  np = None

# **************
#  Lượng tử hóa
# **************
def truncate_and_shift(value, bits):
  if bits >= 8:
    return f"{value:08b}"
  max_val = (1 << bits) - 1
  step = 256 // (max_val + 1)
  scaled = min(value // step, max_val)
  return f"{scaled:0{bits}b}"

# ***************************************
#  RGB -> 1-bit mono (ITU-R BT.601 luma) 
# ***************************************
def rgb_to_mono_bit(r, g, b):
  y = 0.299 * r + 0.587 * g + 0.114 * b
  return '1' if y >= 128 else '0'

# ************************************************
#  Salt-and-Pepper Noise (Random-mode)
# ************************************************
def add_salt_and_pepper_random(img, p = 0.02, salt_ratio = 0.5):
  if p <= 0:
    return img
  img = img.convert("RGB")

  if np is None:
    import random
    w, h = img.size
    px = img.load()
    for y in range(h):
      for x in range(w):
        if random.random() < p:
          val = 255 if (random.random() < salt_ratio) else 0
          px[x, y] = (val, val, val)
    return img
  else:
    arr = np.array(img, dtype = np.uint8)
    H, W, _ = arr.shape
    r = np.random.rand(H, W)
    salt_mask = r < (p * salt_ratio)
    pepper_mask = (r >= (p * salt_ratio)) & (r < p)
    arr[salt_mask] = 255
    arr[pepper_mask] = 0
    return Image.fromarray(arr, mode = "RGB")

# ************************************************
#  Salt-and-Pepper Noise (Even-mode)
# ************************************************
def add_salt_and_pepper_even(img, p = 0.02, salt_ratio = 0.5, tile_w = 16, tile_h = 16):
  if p <= 0:
    return img
  img = img.convert("RGB")
  w, h = img.size
  W, H = w, h

  if np is not None:
    arr = np.array(img, dtype = np.uint8)
  else:
    px = img.load()

  tiles_x = (W + tile_w - 1) // tile_w
  tiles_y = (H + tile_h - 1) // tile_h

  total_noise_target = p * W * H
  total_noise_assigned = 0.0

  for ty in range(tiles_y):
    for tx in range(tiles_x):
      x0 = tx * tile_w
      y0 = ty * tile_h
      tw = min(tile_w, W - x0)
      th = min(tile_h, H - y0)
      area = tw * th

      expected = p * area
      remaining = total_noise_target - total_noise_assigned
      expected = min(expected, max(0.0, remaining))
      quota = int(round(expected))
      quota = min(quota, area)

      if quota <= 0:
        total_noise_assigned += 0
        continue

      if np is not None:
        flat_idx = np.random.choice(area, size = quota, replace = False)
        ys = y0 + (flat_idx // tw)
        xs = x0 + (flat_idx % tw)

        num_salt = int(round(quota * salt_ratio))
        num_pepper = quota - num_salt

        order = np.random.permutation(quota)
        xs = xs[order]
        ys = ys[order]

        if num_salt > 0:
          arr[ys[:num_salt], xs[:num_salt]] = 255
        if num_pepper > 0:
          arr[ys[num_salt:num_salt + num_pepper], xs[num_salt:num_salt + num_pepper]] = 0

      else:
        import random
        coords = [(x0 + dx, y0 + dy) for dy in range(th) for dx in range(tw)]
        random.shuffle(coords)
        chosen = coords[:quota]

        num_salt = int(round(quota * salt_ratio))
        num_pepper = quota - num_salt

        random.shuffle(chosen)
        salt_pts = chosen[:num_salt]
        pepper_pts = chosen[num_salt:num_salt + num_pepper]

        for (x, y) in salt_pts:
          px[x, y] = (255, 255, 255)
        for (x, y) in pepper_pts:
          px[x, y] = (0, 0, 0)

      total_noise_assigned += quota

  if np is not None:
    return Image.fromarray(arr)
  else:
    return img

# *********
#  Ghi MIF
# *********
def write_mif(pixels, width, height, mode = "mono", bits_per_channel = 1, out_path = "out.mif"):
  if mode not in ("mono", "colour"):
    raise ValueError("Mode phải là 'Mono' hoặc 'Colour'.")

  if mode == "colour":
    if not (1 <= bits_per_channel <= 8):
      raise ValueError("bits_per_channel phải trong 1...8.")
    total_bits = bits_per_channel * 3
  else:
    bits_per_channel = 1
    total_bits = 1

  depth = width * height
  hex_width = max(1, len(f"{depth - 1:X}"))

  with open(out_path, "w") as f:
    f.write(f"WIDTH = {total_bits};\n")
    f.write(f"DEPTH = {depth};\n\n")
    f.write("ADDRESS_RADIX = HEX;\nDATA_RADIX = BIN;\n\nCONTENT BEGIN\n")

    for i, (r, g, b) in enumerate(pixels):
      if mode == "colour":
        binary = (truncate_and_shift(r, bits_per_channel) + truncate_and_shift(g, bits_per_channel) + truncate_and_shift(b, bits_per_channel))
      else:
        binary = rgb_to_mono_bit(r, g, b)
      addr = f"{i:0{hex_width}X}"
      f.write(f"\t{addr} : {binary};\n")
    f.write("END;\n")

# ***********
#  Giao tiếp 
# ***********
def ask_yes_no(prompt, default = False):
  s = input(f"{prompt} [{'Y/n' if default else 'y/N'}]: ").strip().lower()
  if s == "" and default is not None:
    return default
  return s in ("y", "yes", "1", "true", "t")

def main():
  print(">>>>>> BMP-to-MIF Conversion Program <<<<<<")

  bmp_path = input("File Name: ").strip()
  if not os.path.exists(bmp_path):
    print(f"Không tìm thấy: {bmp_path} ")
    sys.exit(1)

  try:
    img = Image.open(bmp_path).convert("RGB")
  except Exception as e:
    print(f"Lỗi mở ảnh: {e} ")
    sys.exit(1)

  width, height = img.size
  print(f"- Ảnh: {width}×{height} (RGB)")

  do_noise = ask_yes_no("Thêm nhiễu muối tiêu?", default = False)
  noisy_img = img
  if do_noise:
    try:
      p = float(input("p (0...1): ").strip() or "0.02")
      sr = float(input("Tỉ lệ muối/tiêu (0...1): ").strip() or "0.5")
      if not (0 <= p <= 1): raise ValueError
      if not (0 <= sr <= 1): raise ValueError
    except ValueError:
      print("Giá trị không hợp lệ (dùng p = 0.02, salt_ratio = 0.5).")
      p, sr = 0.02, 0.5

    mode_dist = input("Kiểu phân bố (Random/Even): ").strip().lower() or "even"
    if mode_dist not in ("random", "even"):
      print("Kiểu không hợp lệ (dùng Even-mode).")
      mode_dist = "even"

    if mode_dist == "even":
      try:
        tw = int(input("tile_w (px): ").strip() or "16")
        th = int(input("tile_h (px): ").strip() or "16")
        if tw <= 0 or th <= 0: raise ValueError
      except ValueError:
        print("tile_w/h không hợp lệ (dùng mặc định 16×16).")
        tw, th = 16, 16
      noisy_img = add_salt_and_pepper_even(img, p = p, salt_ratio = sr, tile_w = tw, tile_h = th)
    else:
      noisy_img = add_salt_and_pepper_random(img, p = p, salt_ratio = sr)

    save_noisy_bmp = ask_yes_no("Lưu BMP sau khi thêm nhiễu?", default = True)
    if save_noisy_bmp:
      base = os.path.splitext(os.path.basename(bmp_path))[0]
      tag = f"{int(p*100):02d}" if p >= 0.01 else f"{int(p*1000):03d}"
      out_bmp = input("Tên file BMP nhiễu đầu ra: ").strip()
      if out_bmp == "":
        out_bmp = f"{base}_sp{tag}.bmp"
      if not out_bmp.lower().endswith(".bmp"):
        out_bmp += ".bmp"
      try:
        noisy_img.save(out_bmp, format = "BMP")
        print(f"Đã lưu BMP nhiễu: {out_bmp}")
      except Exception as e:
        print(f"Không thể lưu BMP: {e}")

  do_mif = ask_yes_no("Chuyển sang MIF?", default = True)
  if not do_mif:
    print("Kết thúc (không xuất MIF).")
    return

  mode = input("Chế độ (Mono/Colour): ").strip().lower() or "mono"
  if mode not in ("mono", "colour"):
    print("Chế độ không hợp lệ (dùng Mono-mode).")
    mode = "mono"

  bits_per_channel = 1
  if mode == "colour":
    try:
      bits_per_channel = int(input("Bits per channel (1...8): ").strip() or "4")
      if not (1 <= bits_per_channel <= 8):
        raise ValueError
    except ValueError:
      print("Giá trị không hợp lệ (dùng 4-bit/kênh).")
      bits_per_channel = 4

  base_name = os.path.splitext(os.path.basename(bmp_path))[0]
  default_mif = (f"{base_name}.colour{bits_per_channel}.mif" if mode == "colour" else f"{base_name}.mono1.mif")
  out_mif = input("Tên file MIF: ").strip() or default_mif
  if not out_mif.lower().endswith(".mif"):
    out_mif += ".mif"

  pixels = list((noisy_img if do_noise else img).getdata())

  try:
    write_mif(pixels, width, height, mode = mode, bits_per_channel = bits_per_channel, out_path = out_mif)
    if mode == "colour":
      print(f"MIF: WIDTH = {bits_per_channel*3}, DEPTH = {width*height}, mode = COLOUR ({bits_per_channel}-bit/kênh)")
    else:
      print(f"MIF: WIDTH = 1, DEPTH={width*height}, mode = MONO(1-bit)")
    print(f"Đã lưu: {out_mif}")
  except Exception as e:
    print(f"Lỗi ghi MIF: {e} ")

if __name__ == "__main__":
  main()
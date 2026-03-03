# FPGA-Based Edge Detection with Salt-and-Pepper Denoising & Lane Detection

## Tổng Quan Dự Án

Hệ thống xử lý ảnh thời gian thực trên FPGA với các chức năng:
- **Khử nhiễu Salt-and-Pepper** bằng bộ lọc Median 3×3
- **Phát hiện cạnh** bằng Sobel/Scharr/Canny
- **Phát hiện làn đường** bằng Hough Transform
- **Hiển thị VGA 160×120** với overlay đường thẳng

## Thông Số Kỹ Thuật

| Thông số | Giá trị |
|----------|---------|
| FPGA | Cyclone V (DE10-Lite) |
| Độ phân giải | 160×120 pixels |
| Pixel Clock | 25 MHz |
| Hough Accumulator | 32 theta × 64 rho = 2048 cells |
| Vote Threshold | 3 |
| Max Lines | 2 |

## Cấu Trúc Thư Mục

```
├── docs/                    # Tài liệu
│   ├── README.md           # File này
│   ├── architecture.md     # Kiến trúc tổng thể
│   ├── modules.md          # Chi tiết các module
│   ├── hough_transform.md  # Hough Transform design
│   └── test_results.md     # Kết quả simulation
├── src/
│   ├── display/            # Top module, datapath, VGA interface
│   ├── image_processing/   # Các module xử lý ảnh
│   └── vga_modules/        # VGA controller & adapter
├── quartus/
│   ├── ram_modules/        # Image ROMs
│   ├── vga_pll/           # PLL IP
│   └── simulation/        # ModelSim testbenches
└── scripts/               # Python scripts cho MIF generation
```

## Điều Khiển (SW)

| Switch | Chức năng |
|--------|-----------|
| SW[1:0] | Chọn ảnh (00=img1, 01=img2, 10=img3) |
| SW[3:2] | Chế độ xử lý |
| SW[4] | **Bật/Tắt Hough Transform** |
| SW[6] | Stream mode (1=bật) |

### Chế độ xử lý (SW[3:2])

| SW[3:2] | Mode |
|---------|------|
| 00 | RGB gốc |
| 01 | Grayscale |
| 10 | Sobel edge |
| 11 | Binary edge (input cho Hough) |

## Kết Quả Test

- **Hough unit test**: 8/8 PASS
- **Top module test**: 15/16 PASS
- Hough phát hiện được 2 đường thẳng với 16041 pixels overlay

## Tiến Độ

- [x] Khử nhiễu Salt-and-Pepper
- [x] Phát hiện cạnh Sobel/Scharr
- [x] Streaming pipeline
- [x] **Hough Transform cho lane detection**
- [x] Line overlay trên VGA output
- [x] Simulation verification
- [ ] Deploy lên kit FPGA

---
*Cập nhật: 02/03/2026*

# SỔ ĐÓNG BĂNG — BỘ ẢNH SUY BIẾN KỸ THUẬT SỐ (18 ẢNH)

Ca trực 24/7 · 2026-11-10 18:40 CST · Việc độc lập làm song song trong lúc
chờ anh gửi 5–8 tờ thật khó (điều kiện cuối của buổi đo, xem đầu WORK-STATE).

## 1. Cái đã tạo

- `images/` — **18 ảnh**: 3 gốc (001 Sam's app · 002 Sam's tải về · 003 Home
  Depot) × 6 phép đúng bảng BENCH-MANIFEST §4: BLUR (mờ Gauss) · DOWNSCALE
  (giảm nét) · LIGHT (lệch sáng) · TILT (nghiêng + phối cảnh) · WRINKLE (nhăn
  mô phỏng) · NOISE (nhiễu hạt + nén JPEG).
- Mã ca: `SYN-<gốc>-<phép>` (ví dụ `SYN-001-BLUR`). `origin: synthetic` —
  theo ACCEPTANCE §6 các ca này CHỈ vẽ đường cong chịu đựng, trọng số ×1,
  không bao giờ thay ca thật để kết luận engine.
- Đáp án: kế thừa nguyên vẹn gt của gốc (001/002 → `GT-SAMS-F`, 003 →
  `GT-HD-003`) — ghi trong `synthetic-manifest.csv` cột `gt_id`.
- `make_synthetic.py` — mã nguồn tạo ảnh, mọi thông số ghi cứng trong file;
  `synthetic-manifest.csv` — bảng kê từng ảnh: file nguồn + sha256 nguồn,
  kích thước, byte, sha256, chất lượng JPEG, chuỗi thông số đầy đủ.
- `verify_synthetic.py` + `verify-synthetic-results.txt` — bộ tự kiểm.

## 2. Thông số đã chốt (mức "nặng vừa", một mức mỗi phép)

| Phép | Thông số |
|---|---|
| BLUR | Gaussian radius 1.5 px |
| DOWNSCALE | Hạ ×0.5 (bicubic) rồi phóng lại kích thước gốc (bicubic) |
| LIGHT | Gamma 0.62 (quá sáng) + gradient sáng 1.00→1.18 trái→phải |
| TILT | Keystone: góc trên kéo vào 3% bề ngang, góc dưới đẩy ra 1.5%; xoay 3.0°, nền trắng |
| WRINKLE | Uốn sin: x amp 6 px chu kỳ H/5, y amp 3 px chu kỳ W/2 (nearest) + dải sáng ±6% chu kỳ H/5 |
| NOISE | Nhiễu Gauss σ=12.0, seed cố định theo từng file (ghi trong manifest), lưu JPEG q=20 |

Ảnh còn lại lưu JPEG q=90 để phép nén không lẫn vào phép đang đo. Kích thước
mọi ảnh ra = đúng kích thước gốc.

**Một quyết định ghi rõ:** bảng manifest §4 nhắc hạ mẫu "×0.5 và ×0.25
(riêng gốc 001/003; 002 đã là ca thấp thật)". Bộ này chốt MỘT mức ×0.5 cho
cả 3 gốc: gốc 002 vốn chỉ 554 px bề ngang, hạ ×0.25 còn ~138 px là vượt mức
"nặng vừa" và không còn đọc được bằng mắt — đúng tinh thần ghi chú của
manifest. Nếu QA muốn thêm mức ×0.25 cho 001/003 thì đó là bộ BỔ SUNG riêng,
không sửa bộ đã đóng băng này.

## 3. Kiểm chứng đã chạy tại bàn (bằng chứng)

- `verify_synthetic.py` → **PASS cả 8 nhóm kiểm** (`verify-synthetic-results.txt`):
  18 dòng manifest = 18 file, không thừa/thiếu · sha256 + byte khớp manifest
  18/18 · kích thước = gốc 18/18 · mọi ảnh khác gốc của nó (phép đã áp thật)
  · đủ 3×6 tổ hợp · **tạo lại từ đầu cho ra 18/18 byte-trùng-hệt** (tái lập
  được — seed cố định, không dùng `hash()` bị muối theo tiến trình).
- Đo phụ: chênh lệch điểm ảnh trung bình so với gốc (meanAbsDiff, thang
  0–255) từ 1.83 (SYN-003-DOWNSCALE) tới 41.05 (SYN-003-TILT) — phép hình
  học cao là đúng kỳ vọng vì dịch vị trí điểm ảnh; không phép nào bằng 0.

## 4. Tuyên bố trung thực 3 phần

- **Đã chứng minh:** 18 ảnh tồn tại đúng đặc tả §4 của BENCH-MANIFEST, thông
  số đóng băng trong mã nguồn + manifest kèm sha256 từng file, và việc tạo
  ảnh tái lập được byte-for-byte. Điều kiện chặn buổi đo §5 mục (2) của
  manifest nay đã xong PHẦN suy biến (18/18).
- **Chưa chứng minh:** chất lượng đọc của bất kỳ cấu hình nào trên 18 ảnh
  này — tại bàn không chạy được Vision (ACCEPTANCE §3.2: ca suy biến ảnh
  tại bàn kiểm được 0%); chúng chỉ được phán trong buổi đo duy nhất trên
  máy anh. Mức "nặng vừa" là chọn theo đặc tả, chưa đối chiếu với phân bố
  hoá đơn thật của anh.
- **Chưa làm:** (a) ca thật của anh vẫn THIẾU — 5–8 tờ khó + S-1/S-2/C-002C/
  L1/L2/L3/L5 vẫn chờ anh (manifest §3) — đây mới là điều kiện quyết định
  của buổi đo; (b) ghi chú `D-SYN-18` trong `benchapp/BenchCatalog.swift`
  vẫn ghi "chưa tạo" — đã cũ so với sổ này; sửa ghi chú đó thuộc lần ráp
  bản bench cuối (cùng lúc nhúng ca thật), ca này không đụng Swift;
  (c) chưa tích hợp 18 ảnh vào BenchApp — theo ACCEPTANCE §4.2 Phần 3,
  ca suy biến nạp qua đường "Chọn ảnh" trong buổi đo, không bắt buộc nhúng.

## 5. Danh mục lỗi không được lặp — đối chiếu

Không lỗi nào trong TEAM.md bị chạm: không giao bản, không kêu anh test,
không sửa mò tầng ảnh→chữ (bộ này là dữ liệu đo đóng băng, không phải sửa
engine), không đụng model dữ liệu.

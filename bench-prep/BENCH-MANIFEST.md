# DANH MỤC BENCH ĐÓNG BĂNG — chuẩn bị cho BUỔI ĐO DUY NHẤT

Người soạn: **QA/Supervisor** (đội Sổ Hoá Đơn) · Ngày: 2026-11-10
Nguồn: `core-redo/ENGINE-REPORT.md` §5.2 (bench 2 trục) ·
`core-redo/ACCEPTANCE.md` §2.5 (đáp án hạt giống) + §3 (mở rộng corpus) +
§3.5 (điều kiện chặn buổi đo).

> Trạng thái ghi THẬT tại ngày soạn. "SẴN SÀNG" = ảnh đã nằm trong repo +
> đáp án đã đóng băng. Ca THIẾU thuộc **buổi chuẩn bị riêng trước buổi đo**
> (ENGINE §5.2) — buổi đo không bắt đầu khi danh mục này còn ca bắt buộc
> ở trạng thái THIẾU (ACCEPTANCE §3.5/G3).

## 1. Đáp án đóng băng (sổ đáp án của bộ chấm)

| gt_id | Áp cho | Nguồn đáp án | Bộ số (xu) |
|---|---|---|---|
| `GT-SAMS-F` | N-001 · N-002 · C-002C · S-0 | `samples/sample-001-ground-truth.md` + `samples/sample-002-ground-truth.md` (§F, kiểm số học tay) | Sam's Club · 2026-10-29 17:49 · subtotal 20330 · thuế [960, 390] · total 21680 · 10 dòng món · ITEMS SOLD 15 · TC# 7977 9795 7863 7256 1022 8 · Mastercard (Debit) 2586 · dung sai sổ 0 |
| `GT-HD-003` | C-003 · S-1 | `samples/sample-003-ground-truth.md` (kiểm số học tay) | The Home Depot · 2025-03-03 12:59 · subtotal 9691 · thuế [825] · total 10516 · 3 dòng món · không in ITEMS SOLD · Visa 3830 · dung sai sổ 0 |

Ca mới (L1/L2/L3/L5, S-1/S-2…) chỉ vào danh mục khi đáp án của chúng đã
được chép tay + kiểm số học + đóng băng thành gt_id mới (luật Master Plan
§3.3), nạp vào bộ chấm qua `--answers`.

## 2. Ca đã SẴN SÀNG

| Mã | Dạng × Khó | Origin | File trong repo | gt_id | Ghi chú |
|---|---|---|---|---|---|
| N-001 | N × L0 | real | `samples/sample-001-sams-club-app-screenshot.jpg` (1320×2868) | GT-SAMS-F | Ảnh app Sam's; luồng Vision thật đã có ở `parser-prototype/sample001-raw-text.txt` |
| N-002 | N × L4 | real | `samples/sample-002-sams-downloaded-receipt.jpg` (554×1457) | GT-SAMS-F | Cùng lần mua 001 qua file tải về — ca xé cột kinh điển (Lớp B) |
| C-003 | C × L1 | real | `samples/sample-003-homedepot-paper-crop.jpg` | GT-HD-003 | **Lưu ý:** bản trong repo là bản CẮT từ screenshot (nét thấp hơn gốc). Ưu tiên thay bằng ảnh gốc trong máy anh tại buổi chuẩn bị; bản repo là dự phòng hợp lệ |
| S-0 | S × L0 | real | `samples/sample-004-sams-paper-scan.jpg` (1320×2868) | GT-SAMS-F | **CA CỔNG DANH DỰ** — chính bản scan giấy thật gây ca thực địa 16:50. pages = 1 theo ảnh đã lưu (xác nhận lại số trang ở buổi chuẩn bị). Trượt §F ở cấu hình "giải pháp" = loại cấu hình tại chỗ |

## 3. Ca còn THIẾU — thuộc điều kiện tiên quyết của buổi đo

| Mã | Dạng × Khó | Cần gì | Ai làm / khi nào | gt_id |
|---|---|---|---|---|
| S-1 | S × L1 | Quét (VNDocumentCamera) tờ Home Depot — cặp với C-003 để tách biến số DẠNG khỏi nội dung | Anh quét ở buổi chuẩn bị | GT-HD-003 |
| S-2 | S × L1 | Quét một tờ nhăn THẬT từ kho của anh — cặp với L1 tương ứng | Anh quét ở buổi chuẩn bị | gt mới (đóng băng sau khi chép tay) |
| C-002C | C × L0 | Chụp thường (camera trong app) chính tờ Sam's giấy — ca 002-C treo từ WP4 [CHƯA KIỂM CHỨNG] | Anh chụp ở buổi chuẩn bị (đường camera trong app là điểm kiểm riêng, ENGINE §5.2) | GT-SAMS-F |
| L1-01…03 | C × L1 | 3 tờ nhăn/cũ THẬT từ kho hoá đơn của anh (nhăn nhất còn đọc được bằng mắt) — lớp đại diện "hàng trăm/ngàn tờ cũ", KHÔNG thay bằng suy biến | Anh chọn + gửi ảnh gốc TRƯỚC buổi đo; đội chép tay + kiểm số học đóng băng đáp án | gt mới ×3 |
| L2-01…02 | C × L2 | ≥ 2 tờ nhiệt đã PHAI THẬT trong kho. Chỉ khi không có mới hạ xuống suy biến kỹ thuật số (mục 4) và lớp mất hiệu lực kết luận (chỉ tham khảo) | Anh chọn ở buổi chuẩn bị | gt mới ×2 |
| L3-01…02 | C × L3 | Chụp LẠI 2 tờ của L1 dưới đèn vàng tối một bên + bóng đổ chéo (dùng chung đáp án L1 để tách biến số điều kiện chụp) | Buổi chuẩn bị | Dùng chung gt của L1 tương ứng |
| L4-02 | N × L4 | File tải về THẬT khác (Sam's/Best Buy) khi anh có — N-002 là ca L4 có sẵn duy nhất hiện nay | Khi anh có file | gt mới |
| L5-01 | C × L5 | Tờ NHIỀU MÓN NHẤT trong kho thật (mục tiêu ≥ 40 dòng món). Thiếu thì ghi THIẾU — **cấm ghép ảnh giả lập** (ENGINE §5.2) | Anh chọn ở buổi chuẩn bị | gt mới |
| PDF-SAM | N × L0 | File PDF hoá đơn Sam's Club THẬT (đường PDF mới có fixture tổng hợp — ACCEPTANCE §1.3) | Khi anh tải được từ tài khoản Sam's | gt mới (= bộ số của chính tờ đó) |

## 4. Ca suy biến kỹ thuật số — TỔNG HỢP, chỉ tham khảo

Theo ACCEPTANCE §3.2: **3 gốc (001/002/003) × 6 phép = 18 ảnh**, đáp án
kế thừa nguyên vẹn gt của gốc. Trạng thái: **ĐÃ TẠO + ĐÓNG BĂNG
2026-11-10 (ca trực 18:40 CST)** — `bench-prep/synthetic/` (mã nguồn tạo
`make_synthetic.py` + `synthetic-manifest.csv` bảng kê thông số/sha256
từng phép + `SYNTHETIC-LEDGER.md` + tự kiểm tái lập byte-for-byte PASS).
Một mức mỗi phép; DOWNSCALE chốt ×0.5 cho cả 3 gốc (lý do ở sổ).

| Phép | Đặc tả (mức "nặng vừa", thông số chốt khi tạo và ghi vào bảng kê) | Công cụ |
|---|---|---|
| Mờ | Gaussian blur (PIL `ImageFilter.GaussianBlur`, radius ghi lại) | Python/PIL tại bàn |
| Giảm nét | Hạ mẫu ×0.5 và ×0.25 rồi phóng lại kích thước cũ (riêng gốc 001/003; 002 đã là ca thấp thật) | Python/PIL |
| Lệch sáng | Gamma quá sáng / quá tối + vệt sáng gradient một phía | Python/PIL (`ImageEnhance` + gradient mask) |
| Nghiêng + phối cảnh | Xoay nhỏ (2–4°) + keystone (perspective transform lệch góc) | Python/PIL |
| Nhăn mô phỏng | Sóng sáng–tối chu kỳ + uốn hình học sinusoidal nhẹ | Python/PIL/numpy |
| Nhiễu + nén | Nhiễu hạt (Gaussian noise) + lưu JPEG quality thấp (15–25) | Python/PIL/numpy |

Kỷ luật ghi nhãn: các ca này mang `origin: "synthetic"` trong file đo →
trọng số ×1 kể cả ở lớp khó, KHÔNG bao giờ thay ca thật để kết luận engine
(ACCEPTANCE §6). Suy biến CHỮ (tại bàn, ACCEPTANCE §3.3) là bộ riêng của
cổng G2, không thuộc danh mục ảnh này.

## 5. Tóm tắt điều kiện chặn

Sẵn sàng hôm nay: **4/~15 ca thật** (N-001, N-002, C-003-dự phòng, S-0)
+ **18/18 ca suy biến** (mục 4, đóng băng 2026-11-10). Buổi đo
chỉ được xin anh khi: (1) các ca THIẾU ở mục 3 đã có ảnh + đáp án đóng
băng — **VẪN CHƯA**, (2) 18 ảnh suy biến mục 4 đã tạo và đóng băng —
**ĐÃ XONG 2026-11-10**, (3) luồng OCR gốc
trên máy của tờ Sam's run #26 đã về tay đội và tái hiện được tại bàn
(ACCEPTANCE §3.5.3 — điều kiện nằm ngoài danh mục ảnh nhưng cùng chặn).

# GATE100-v2 — GIAO THỨC PHIÊN ĐÓNG BĂNG

Đóng băng ngày 2026-11-17 (America/Chicago). File này là đặc tả phiên duy nhất;
mọi thay đổi sau đóng băng = patch riêng, ghi lý do.

## 1. Danh tính gói đóng băng

- Corpus: freezeVersion `gate100-corpus-2026-11-16` (FREEZE.json — 40 ảnh web,
  sha256 từng file trong FREEZE.json; thu thập SAU khi đóng băng build nền,
  chưa từng dùng trong phát triển).
- Bảng đáp án: `gate100-gt.json`, gtVersion `gate100-gt-2026-11-17`,
  sha256 `3f671fe3f6e5925df8a4efa37f4f0489650cd9194deb8493a8e0d140b6c1886e`.
  Schema giống hệt `bench-gt.json` (tiền = cent nguyên; trường không in trên
  hoá đơn / không đọc được = null, thuế = []). Kiểm số học khi lập bảng:
  31/31 ca có đủ 3 số khớp subtotal + tax = total; 9 ca còn lại thiếu ít nhất
  một trường không in trên hoá đơn (để null theo đúng bản nháp đã kiểm).
- Build dưới kiểm: build-ipa run #125, commit v3 `586262b3` (DFIX).
- Ảnh đưa lên repo dạng text: `Gate100B64/<tên gốc>.b64` (base64, giữ nguyên
  tên gốc). 5 file vượt giới hạn 1.095.138 byte/file của connector nên được
  chia mảnh: `<tên gốc>.b64.part01`, `.part02`, … (mỗi mảnh 900.000 byte;
  gồm 21-chick-fil-a-1, 24-hy-vee-gas-1, 27-lowes-1, 29-lowes-3,
  37-cvs-pharmacy-3). Ghép các mảnh theo thứ tự tên rồi mới giải mã base64.
  Giải mã xong phải đối chiếu sha256 từng file với FREEZE.json trước khi
  chạy; lệch = dừng phiên.

## 2. Thành phần phiên — TỔNG 123 lượt đọc

- Lượt A (83 lượt): mỗi ảnh 1 lượt đọc qua đường thật của app
  (`ReceiptReader.read`), gồm:
  - 43 ảnh BenchImages — lane roigate hiện có, đáp án `bench-gt.json`
    (gtVersion `bench-gt-2026-11-15-g5`);
  - 40 ảnh corpus GATE100 — giải mã từ `Gate100B64/` ra `Gate100Images/`,
    đáp án `gate100-gt.json`.
- Lượt B (40 lượt): 40 ảnh corpus chạy lượt 2, đường ROI đầy đủ.
- TỔNG = 83 + 40 = **123 lượt** (≥ 115 theo tiêu chí GATE100-v2).

## 3. Tiêu chí qua cổng (tất cả phải đạt trên cùng một phiên)

- 0 crash.
- 0 SILENT-WRONG: sai trường tiền (subtotal / thuế / tổng) mà warnings = 0.
- M9 = 0.
- Chẩn đoán đủ 123/123 lượt.
- Ghi p95 và max thời gian đọc của phiên.

Một ca trượt = phiên trượt; sửa xong phải chạy phiên MỚI toàn bộ, không chạy
bù từng ca.

## 4. S5 holdout — niêm phong

15 file cuối của corpus (mục `s5Holdout` trong FREEZE.json:
`26-murphy-usa-1.jpg` … `40-mcdonalds-4.png`) chỉ được mở khi chạy phiên.
Cấm dùng chúng để sửa code trước phiên dưới bất kỳ hình thức nào.

## 5. Đặc tả lane workflow `gate100` (Leader bổ sung vào harness-ci.yml sau)

Input job mới `gate100` của workflow `harness-ci.yml` phải làm đúng thứ tự:

1. Với mỗi ảnh gốc: nếu có `Gate100B64/<tên>.b64` thì giải mã trực tiếp;
   nếu không, ghép `Gate100B64/<tên>.b64.part*` theo thứ tự tên rồi giải mã
   → `Gate100Images/<tên gốc>`. Đối chiếu sha256 với FREEZE.json, lệch thì
   fail ngay.
2. Chạy harness `images --dir Gate100Images` (lượt A cho corpus) và lượt 2
   cho cùng thư mục (lượt B, đường ROI đầy đủ).
3. Chạy harness `roigate --dir Gate100Images --gt gate100-gt.json`.
4. Chạy lane roigate 43 ảnh BenchImages như thường lệ (đáp án bench-gt).
5. Gom toàn bộ log + chẩn đoán vào artifact evidence của lượt chạy.

## 6. ⚠️ ĐIỂM PHẢI QUYẾT TRƯỚC KHI CHẠY PHIÊN (Leader)

Harness hiện tại (HarnessApp/main.swift, chế độ `images` dòng ~835 và
`roigate` dòng ~902) **chỉ duyệt file `*.jpg`**. Corpus gồm 32 jpg + 7 webp
(01, 03, 05, 09, 10, 17, 34) + 1 png (40). Nếu giải mã giữ nguyên đuôi file,
cả hai lane sẽ lặng lẽ bỏ qua 8/40 ảnh corpus và phiên không đủ 123 lượt.
Phải chọn một cách xử lý ở bước workflow/harness trước khi chạy phiên
(chuyển đổi webp/png → jpg ở bước giải mã, hoặc mở rộng bộ lọc của harness —
sửa code harness nằm ngoài gói đóng băng này) và ghi quyết định vào đây.

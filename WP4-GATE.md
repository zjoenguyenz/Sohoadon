# WP4 — THI ĐẤU ENGINE ĐỌC ẢNH: BƯỚC 1 CHUẨN BỊ (CHƯA tới cổng gói)
**Gói:** WP4 theo BUILD2-MASTER-PLAN §2 (WP4) + §5.1 + §5.6; đặc tả đo:
`WP4-SPEC.md`. Đặc tả code: CODE-AUDIT F2a/F2c.
**Ngày chuẩn bị:** 2026-11-09 20:40 CST (ca trực sohoadon-build2-247).
**Trạng thái:** Bước 1 của WP4 — ĐẶC TẢ ĐO + TẦNG TẠO DÒNG của ứng viên
(a) — đã chuẩn bị ở `wp4-prep/ScanView.swift` (1 file, thay 1-1 cho bản
WP3 trên main). **Chưa đẩy code ở bất kỳ nhánh nào** (đúng luật ca
trực). WP4 CHƯA tới cổng gói: còn bước 2 (tiền xử lý phái sinh + F2b
phía parser) và bước 3 (bản test engine (b) iOS 26 + chạy thi đấu trên
bộ mẫu + QA ký chọn engine). Theo LUẬT MỐC LỚN, anh không cài/test
riêng gói này; bài kiểm trên máy gộp vào mốc M1.

## Tiền đề đầu ca (đã kiểm chứng bằng file)
- WP3 code ĐÃ ĐẨY MAIN bởi Wally: commit `ec73f92` (5 file wp3-prep) —
  ghi ở đầu WORK-STATE.md, cập nhật 2026-11-09 18:52 CST. WP4 xây trên
  nền wp3-prep (= bản main hiện tại), không xây trên build1.

## Việc đã làm — đúng MỘT bước: đặc tả đo + F2a/F2c cho ứng viên (a)
- **`WP4-SPEC.md`** (mới): khoá cách đo trước khi đo — 2 ứng viên × 2
  cấu hình (ảnh gốc / ảnh phái sinh, §5.1), bộ mẫu cổng 001/002/003
  (+002-C khi có), làn lab chỉ đo độ bền, hệ quả nền tảng §5.6, chia
  3 bước. Không đặt ngưỡng % (§5.8).
- **`wp4-prep/ScanView.swift`** (diff so với wp3-prep: **+121 / −16**;
  16 dòng − là toàn bộ thân `recognizeLines` cũ được thay — mọi điểm
  gọi giữ nguyên chữ ký, mọi đường WP1–WP3 không đổi):
  - `OCRFrag`: mảnh chữ + hộp chuẩn hoá gốc-dưới-trái trong không
    gian ẢNH ĐẦY ĐỦ.
  - `mergeRows` — **F2a nguyên văn thuật toán CODE-AUDIT**: sort maxY
    giảm dần → gom mảnh chồng Y ≥ 50% chiều cao mảnh ngắn hơn vào
    hàng đang mở (neo = mảnh đầu hàng) → trong hàng sort minX, nối
    " ", độ tin cậy dòng = MIN các mảnh.
  - `collectFragments` + `ocrFragments` — **F2c**: ảnh cao/rộng > 3.0
    VÀ cao > 1600px → cắt lát dọc 1600px, chồng 200px, OCR tuần tự
    từng lát (handler.perform đồng bộ, hàng đợi nền), quy đổi hộp về
    ảnh đầy đủ trước khi ráp. Ngoài ngưỡng: 1 lượt như cũ — nhưng vẫn
    qua ráp hàng F2a (đó là điểm khác Build 1 trên MỌI đường ảnh).
  - `dedupeOverlap` — khử mảnh trùng vùng chồng lát: cùng chữ + diện
    tích giao ≥ 50% hộp nhỏ hơn → giữ confidence cao hơn (luật F2c).
  - Kiểm tĩnh phía mình: cân bằng ngoặc {112/112} (262/262) [37/37];
    grep ký hiệu: mọi hàm mới có đúng 1 định nghĩa + điểm dùng thật.

## Kiểm chứng đã chạy (bằng chứng file)
- `wp4-fixtures/verify_rowmerge.py` + `rowmerge_port.py` (port Python
  trung thực của dedupeOverlap/mergeRows) trên fixture mảnh-xé
  SYNTHETIC dựng từ đáp án chuẩn Mẫu 002 — **9/9 PASS**, kết quả đầy
  đủ ở `wp4-fixtures/verify-results.txt`:
  - A: 40 mảnh xé (nhãn/tiền tách cột, tiền lệch Y nhẹ) ráp thành đúng
    24 hàng thị giác, khớp ground truth từng hàng.
  - B: hàng ráp vào parser Sam's hiện hành → **§F đạt trọn**: subtotal
    203.30 · thuế 9.60+3.90 · total 216.80 · 10 dòng món · Σ món
    203.30 · 15 món · TC# đủ 21 số. (Khớp truy vết của Leader ở
    CODE-AUDIT Addendum: luật parser đủ đúng NẾU dòng được ráp.)
  - C: chèn 6 mảnh trùng vùng chồng (confidence thấp) → dedupe bỏ
    đúng 6, hàng ráp không đổi.
  - D: **đối chứng âm** — mảnh phát 1:1 kiểu Build 1 (không ráp) →
    parser mất subtotal/total (None), §F trượt: fixture có răng,
    phép ráp là thứ tạo ra khác biệt, không phải parser tự khỏi.
  - E: biên — chồng Y 33% < 50% KHÔNG ráp; 3 mảnh 1 hàng sắp đúng
    trái→phải; confidence dòng = min mảnh.

## Tuyên bố trung thực 3 phần
- **Đã chứng minh:** thuật toán ráp hàng F2a + khử trùng F2c (bản port
  Python) tái tạo đúng 24 hàng của 002 từ mảnh xé mô phỏng và đưa
  parser hiện hành tới §F trọn vẹn; đối chứng âm tái hiện đúng khiếm
  khuyết thực địa Build 1 (mất hết tiền). Đặc tả đo WP4 đã khoá.
- **Chưa chứng minh:** (1) biên dịch Swift [CHƯA KIỂM CHỨNG — môi
  trường ca không có compiler; build cloud là phép kiểm khi Wally
  trình đẩy]; (2) Vision thật xé mảnh ra sao trên máy + phép quy đổi
  toạ độ lát cắt CGImage đúng hướng chưa [CHƯA KIỂM CHỨNG — cần build
  chạy trên máy, gộp bước 3/M1]; (3) điểm cổng 001/002/003 của ứng
  viên (a) — chưa đo được vì chưa có OCR thật trong ca này.
- **Chưa làm (cố ý, đúng chia bước):** tiền xử lý ảnh phái sinh
  (tứ giác/perspective/tương phản) + F2b phía parser = bước 2; engine
  (b) `RecognizeDocumentsRequest` + bản test pipeline riêng + chạy
  thi đấu + QA ký chọn engine + quyết nền tảng iOS 26 (§5.6) = bước
  3; mẫu 002-C cần anh chụp camera thật — điểm chờ, gộp M1, không
  xin riêng.

## Chữ ký nội bộ — BƯỚC 1
- Design ✓ — bước này không đổi giao diện nào; đặc tả đo tôn trọng
  nguyên tắc "số tiền không bị che" (không đụng lớp hiển thị).
- Code ✓ — diff +121/−16 chỉ trong tầng OCR của ScanView; API dùng
  toàn API ≤ iOS 13 (VNRecognizeTextRequest/CGImage cropping); không
  framework lạ lúc khởi động (TEAM.md #1); kiểu/optional đã rà
  (TEAM.md #2): results ép kiểu qua topCandidates/boundingBox của
  VNRecognizedTextObservation, Double/CGFloat chuyển đổi tường minh.
- QA ✓ — đối chiếu CODE-AUDIT F2a/F2c từng điều kiện (ngưỡng 50%,
  chồng 200px, lát 1600px, tỉ lệ 3.0, confidence = min); fixture có
  đối chứng âm; kết luận fixture được ghi đúng phạm vi (thuật toán,
  không phải OCR thật) — TEAM.md #4.

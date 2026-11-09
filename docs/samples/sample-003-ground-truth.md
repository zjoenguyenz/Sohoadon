# Mẫu 003 — Home Depot, hoá đơn GIẤY THẬT (chụp tờ giấy nhàu)
Nguồn: user test Build 1, 2026-11-08 23:23 CST (ảnh cắt từ screenshot màn Kiểm Lại:
sample-003-homedepot-paper-crop.jpg — bản cắt từ screenshot, độ nét thấp hơn ảnh gốc
user đã nạp; chỉ dùng làm bằng chứng/mẫu phụ, số chuẩn lấy theo Wally đọc từ ảnh to).

## Số chuẩn (Wally đọc từ screenshot lớn, kiểm số học)
- Tiệm: **The Home Depot** — 9808 E 71ST ST, Tulsa, OK 74133
- Ngày: **03/03/2025 12:59 PM**
- Món có giá: 2 OZ GOR GLU <A> 6.98 · 128 HW CLEAN <A> 19.97 · KORKY 2X COMPLETE KIT 69.96
  (6.98 + 19.97 + 69.96 = **96.91** ✓ khớp SUBTOTAL in trên hoá đơn)
- SUBTOTAL **96.91** · SALES TAX **8.25** · TOTAL **$105.16**
- Thẻ: **VISA •• 3830** (dòng XXXXXXXXXXXX3830) — thẻ CHƯA đăng ký

## Kết quả Build 1 trên mẫu này (thực địa)
- ĐÚNG: ngày+giờ (Mar 3, 2025 12:59 PM); thẻ Visa •• 3830; gợi ý "chưa đăng ký — anh chọn giúp";
  cảnh báo thiếu tổng; lưu -> Chờ duyệt (needsReview) đúng kỷ luật.
- SAI/TỆ: tên tiệm đọc thành **"How doers"** (câu slogan "How doers get more done"
  dưới logo bị chọn làm tên tiệm — luật vendor chỉ quét 6 dòng đầu tìm "HOME DEPOT"
  rồi rơi về dòng đầu tiên); SUBTOTAL/TAX/TOTAL đều trống.
- Nhận định của user (nguyên văn): "Chất lượng scan dữ liệu rất tệ" /
  "Thua các app chính thức rất nhiều".

## Bài học cho Build 2
1. Vendor: quét TOÀN BỘ dòng tìm tiệm đã biết (+ khớp mờ), không chỉ 6 dòng đầu;
   không lấy slogan làm tên tiệm.
2. Tầng đọc là điểm yếu chính, không phải luật bóc tách: cần tiền xử lý ảnh
   (cắt viền/nắn thẳng/tăng nét) + ráp hàng theo cột + ĐÁNH GIÁ ENGINE MỚI của
   Apple trên iOS 26 (RecognizeDocumentsRequest — hiểu bố cục tài liệu) so với
   Vision cổ điển, chấm trên cùng bộ mẫu 001/002/003.
3. Hoá đơn giấy nhàu + chụp thường (không qua document camera nắn thẳng) là
   trường hợp khó thật — chuẩn nghiệm thu phải tính cả loại này.

# WP6 — VĂN BẢN CỔNG (Niềm tin dữ liệu — Master Plan §2 WP6)

## BƯỚC 1 — ĐẶC TẢ (2026-11-10 12:40 CST, ca trực sohoadon-build2-247)

Việc độc lập chuẩn bị song song (không kêu anh test thêm bất cứ
thứ gì trong bước này): test run #20 đã ĐẠT trên máy anh lúc 12:39
CST (vòng M1-FIX/REPARSE đóng — WORK-STATE 12:42), làn chính đang
chạy IMGFIX + WP-EXPORT xếp sau; WP6 thuộc mốc M2, không đụng hai
làn đó. Bước này chỉ khoá đặc tả, KHÔNG viết code, KHÔNG mở cổng
gói WP6.

Sản phẩm: `WP6-SPEC.md` — phạm vi khoá đúng 8 mã của Master Plan
(B-2 · B-5 · B-6 · B-7 · C-1 · C-2 · C-3 · C-8) + cổng hoàn chỉnh
ACCOUNTING-SPEC §2.2 thành cổng Duyệt thật + cờ trùng/duplicateOf
(trường WP2 đã có, chưa nối) + nối reviewedAt/userEnteredFieldNames
(trường WP2 đã có, chưa gán ở đâu — đo grep 0 điểm).

### Bằng chứng hiện trạng (đọc trực tiếp, không qua lời kể)
- B-2: `try? modelContext.save()` — 5 điểm stamp/ReceiptViews.swift
  (486/505/628/645/982), 4 điểm build1/CardsView.swift, 1 điểm
  wp3-prep/ContentView.swift:145.
- C-1: nút Duyệt stamp/ReceiptViews.swift ~484-490 không đọc
  receiptFlags() (hàm ở dòng 104, mới dùng để hiển thị ở dòng 425).
- B-6: hộp thoại Xoá ~502-507 xoá ảnh TRƯỚC khi delete bản ghi.
- C-3: `validate()` vẫn `private static` (stamp/Parser.swift:951).
- B-7: sheet Kiểm Lại wp4-prep/ScanView.swift:195 chỉ có 1 closure
  hoàn tất, không đường dọn ảnh khi huỷ; nhánh lines.isEmpty:252
  không xoá file.
- Model: wp3-prep/Models.swift có scheduleCLine:220,
  duplicateOfStableID:240, excludedFromTotals:241, reviewedAt:245,
  userEnteredFieldNames:246 — và KHÔNG có trường dấu "xác nhận
  kèm cờ" (điểm model duy nhất đặc tả phải quyết — WP6-SPEC mục 5:
  cộng đúng 1 Bool có default, thuần cộng thêm theo tiền lệ WP2).

### Ba chữ ký nội bộ cho BƯỚC 1 (đặc tả)
- Design ✓ — đặc tả tôn trọng các quyết đã chốt ở Master Plan
  §5.3/§5.4/§5.7 (xếp lại có báo trước + chỉ tờ chưa duyệt/chưa xếp
  tay; cổng hoàn chỉnh thắng duyệt-nhanh; trùng đánh dấu không xoá);
  phần hiển thị mới duy nhất (số chờ riêng có nhãn, dòng lý do tắt
  nút Duyệt, dấu xác nhận kèm cờ) dùng đúng ngôn ngữ/cơ chế đã có
  trong app, thiết kế chi tiết để WP9 — không tự vẽ hệ mới ở WP6.
- Code ✓ — mọi khẳng định hiện trạng đối chiếu grep/đọc trực tiếp
  trên thành phần code của run #20 (stamp/ + wp3-prep + wp4-prep +
  build1 cho 2 file chưa gói nào chạm); quyết trường cộng thêm là
  thuần cộng thêm có default, không rủi ro di trú ngoài tiền lệ WP2;
  nếu bước code cần model khác thêm → dừng báo Wally (ghi cứng ở
  đặc tả mục 5).
- QA ✓ — đặc tả phủ đủ 8/8 mã Master Plan giao WP6, tiêu chí ra
  cổng viết thành 6 câu kiểm chứng được (WP6-SPEC mục 8), mục "áp
  lên dữ liệu đã lưu" có mặt theo B2 Điều 2 kèm hệ quả phải tuyên
  bố trước (tổng Trang Chủ giảm đúng bằng tiền đang chờ khi M2 lên
  — sửa đúng, không phải mất tiền).

### Tuyên bố trung thực 3 phần
- ĐÃ CHỨNG MINH: hiện trạng 8 mã còn nguyên trên code hiện hành
  (số dòng + grep ở trên); hạ tầng trường WP2 tồn tại và chưa nối;
  thiếu trường dấu xác nhận kèm cờ là thật (grep Models).
- CHƯA CHỨNG MINH: mọi hành vi sau sửa (bước 2 chưa viết); điểm mở
  đã ghi trong đặc tả — cách kiểm điều kiện "ngày" của §2.2(2) và
  cơ chế xác nhận thẻ lạ §2.2(6) chốt ở bước 2 kèm đối chiếu save()
  thực tế, không bịa luật ở bước này.
- CHƯA LÀM: code WP6 (chờ M1 đóng theo tuần tự mốc); bài kiểm máy
  thật (gộp M2); mục liệt kê file mồ côi tích lũy — thiết kế ở
  bước 2, xoá hay giữ là quyết của anh.

**Trạng thái cổng: WP6 BƯỚC 1 XONG. Cổng GÓI WP6 chưa mở.**
Bước tiếp theo của WP6: bước 2 code — chỉ khi tới lượt WP6 trong
nhịp M2 (sau khi làn IMGFIX/WP-EXPORT của mốc hiện tại xong và
Wally trình), theo trình tự cụm (a)→(e) ở WP6-SPEC mục 7.

# WP1 — CỬA CHẨN ĐOÁN F3: VĂN BẢN CỔNG (chuẩn bị tới cổng, CHƯA đẩy code)
**Gói:** WP1 theo BUILD2-MASTER-PLAN §2 (WP1) + đặc tả CODE-AUDIT mục F3.
**Ngày chuẩn bị:** 2026-11-09 04:40 CST (ca trực sohoadon-build2-247).
**Trạng thái:** Code đã chuẩn bị xong ở `wp1-prep/ReceiptViews.swift` (bản thay
thế 1-1 cho `build1/ReceiptViews.swift` khi được duyệt đẩy). Đủ 3 chữ ký nội
bộ (Design ✓ / Code ✓ / QA ✓ — xem dưới). **Chưa đẩy code ở bất kỳ nhánh nào**
(đúng luật ca trực). Còn chờ: Wally duyệt cuối + thẻ duyệt đẩy của anh → build
cloud → anh cài + chụp màn hình Kiểm Lại (bằng chứng nghiệm thu của gói).

## Việc đã làm (đối chiếu đặc tả CODE-AUDIT F3, từng mục)
1. **ReviewView (màn Kiểm Lại)** — F3 mục 1: ngay DƯỚI section ảnh gốc, thêm
   section chứa mục "Văn bản OCR gốc" thu gọn được, chỉ hiện khi
   `draft.result.rawText` không rỗng. ✓ đúng vị trí đặc tả
   (CODE-AUDIT ghi ReceiptViews.swift:420-435 = section ảnh gốc của Review).
2. **ReceiptDetailView (màn Chi Tiết)** — F3 mục 2: ngay SAU section
   "Thông tin", thêm cùng mục xem văn bản, bind `receipt.ocrRawText`,
   ẩn hẳn khi chuỗi rỗng. ✓ đúng vị trí + đúng luật ẩn của đặc tả.
3. **Dạng hiển thị** — đúng mẫu mã của đặc tả: `DisclosureGroup` (mặc định
   thu gọn — không truyền `isExpanded`), `Text` font `.caption.monospaced()`,
   `.textSelection(.enabled)` để anh copy nguyên văn khi báo lỗi.
   Hai màn dùng CHUNG một component `RawTextDisclosure` (định nghĩa 1 chỗ)
   thay vì chép 2 bản — hành vi không thể lệch nhau giữa 2 màn.

## Ranh giới trung thực — nhãn "Văn bản trong PDF" (F3 mục 3) CHƯA làm, có lý do
- F3 mục 3 yêu cầu khi là lớp chữ PDF thì hiện nhãn "Văn bản trong PDF".
  Hiện tại app CHƯA có đường PDF nào (WP3 mới xây) và model CHƯA có trường
  nguồn nạp: `sourceType` thuộc WP2 (ACCOUNTING-SPEC §5.2; Master Plan §2
  WP2). `Receipt` chỉ lưu `ocrRawText: String` — không dữ kiện nào phân
  biệt được nguồn OCR/PDF ở màn Chi Tiết. Gắn nhãn PDF lúc này là bịa.
- Xử lý của WP1: component nhận `title` làm tham số (mặc định "Văn bản OCR
  gốc" — nhãn đúng duy nhất cho mọi đường đọc đang tồn tại). WP3 chỉ cần
  truyền nhãn PDF ở 2 điểm gọi khi đường PDF + cờ nguồn đã có thật.
- Ghi rõ: **F3 mục 3 = chuyển WP3**, không tính là WP1 đã xong mục đó.

## Tờ khai trung thực (claims / evidence / unverified)
- [ĐÃ KIỂM] Tiền đề F3 còn đúng trên code hiện tại: grep `build1/ReceiptViews.swift`
  — `rawText`/`ocrRawText` chỉ xuất hiện ở tìm kiếm danh sách (dòng 117-118)
  và lúc lưu (dòng 595); không màn nào hiển thị. (Khớp CODE-AUDIT F3.)
- [ĐÃ KIỂM] Diff `build1/ReceiptViews.swift` → `wp1-prep/ReceiptViews.swift`:
  **+39 dòng / −0 dòng / 0 dòng sửa** — chỉ 3 khối thêm: component
  `RawTextDisclosure` (+22), điểm gọi Chi Tiết (+7), điểm gọi Kiểm Lại (+10).
  Toàn bộ code cũ nguyên vẹn từng dòng.
- [ĐÃ KIỂM] Cân bằng cú pháp thô: ngoặc nhọn 169/169, ngoặc đơn 425/425
  trên bản chuẩn bị (bản gốc 162/162).
- [ĐÃ KIỂM] Kiểu dữ liệu (TEAM.md lỗi #2): cả 2 điểm gọi truyền `String`
  không-optional — `ParseResult.rawText: String` (Parser.swift) và
  `Receipt.ocrRawText: String` (Models.swift); tham số component là
  `String`. Không ép kiểu, không optional lọt vào.
- [ĐÃ KIỂM] API trong giới hạn iOS 17 (deployment target ở project.yml):
  `DisclosureGroup` (iOS 14+), `textSelection` (iOS 15+),
  `Font.monospaced()` (iOS 16+). Không import mới, không framework lạ,
  không đụng gì lúc khởi động app (TEAM.md lỗi #1: không áp dụng — code
  thuần view). `project.yml` không cần đổi: file thay 1-1 cùng tên.
- [CHƯA KIỂM CHỨNG] Biên dịch: môi trường ca trực không có swiftc/xcodebuild
  (hạn chế đã ghi trong CODE-AUDIT). Phép kiểm thật = build cloud sau khi
  anh duyệt đẩy. KHÔNG khẳng định "build được" trước bằng chứng đó.
- [CHƯA KIỂM CHỨNG] Hành vi trên máy: DisclosureGroup mở đầu ở trạng thái
  thu gọn là hành vi mặc định theo tài liệu SwiftUI; bằng chứng nghiệm thu
  của gói (Master Plan §2 WP1) là ảnh chụp màn hình trên máy anh — chưa có,
  chờ vòng cài đặt của anh. KHÔNG ghi WP1 "đã nghiệm thu".

## Ba chữ ký nội bộ (TEAM.md — cổng 3 chữ ký)
- **Design ✓** — Thu gọn mặc định nên không kéo dài luồng Kiểm Lại/Chi Tiết
  thường ngày; chữ monospaced cỡ caption đúng đặc tả chẩn đoán (đây là văn
  bản bằng chứng, không phải số tiền hiển thị — luật "số tiền trên nền đục"
  không áp dụng); ẩn khi rỗng nên không có section chết. KHÔNG gộp thiết kế
  lại §4.6/§4.7 của DESIGN-AUDIT (đó là WP8/WP9) — WP1 giữ tối thiểu đúng
  phạm vi gói.
- **Code ✓** — Rà độc lập trên bản chuẩn bị: diff chỉ-thêm như trên; kiểu/
  optional sạch; không vòng đời SwiftUI/SwiftData nào bị chạm (component
  không giữ state, không đọc modelContext); 4 lỗi cơ bản của TEAM.md đã
  đối chiếu từng mục (#1 không áp dụng, #2 đã kiểm, #3 DisclosureGroup là
  component chuẩn — hành vi thu-gọn-mặc-định vẫn chờ bằng chứng máy thật ở
  vòng nghiệm thu, đã ghi ở mục chưa kiểm chứng, #4 mọi kết luận ở văn bản
  này đều có grep/diff đi kèm).
- **QA ✓** — Đối chiếu lại từ đầu độc lập với người viết: tiền đề F3 (grep),
  vị trí 2 điểm gọi (đọc file bản chuẩn bị: Chi Tiết sau "Thông tin" —
  dòng 300-304; Kiểm Lại dưới ảnh gốc — dòng 467-471), diff +39/−0, và
  ranh giới nhãn PDF ghi đúng là chuyển WP3 chứ không nuốt vào "đã xong".
  QA ký ở mức CHUẨN BỊ TỚI CỔNG — không ký nghiệm thu (nghiệm thu cần máy
  anh, ghi rõ ở trên).

## Điểm chờ anh (không tự vượt)
1. Thẻ duyệt đẩy code WP1 lên main (hệ thống sẽ trình anh).
2. Sau build cloud: anh cài bản mới, mở 1 tờ quét thật → màn Kiểm Lại →
   mở mục "Văn bản OCR gốc" → chụp màn hình gửi đội. Đó là bằng chứng
   nghiệm thu đóng gói WP1 và mở WP2.

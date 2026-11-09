# BUILD 1 — Bản nền tảng (foundation) · Sổ Hóa Đơn

Trạng thái trung thực: **code CHƯA được biên dịch ở đây** (không có compiler trong
môi trường soạn). Đã được Wally duyệt từng dòng (2026-11-08 đêm) — các sửa khi duyệt:
(1) `Parser.findDateTime` — bản nháp truyền `Int?` vào tham số `hour/minute: Int` của
`makeDate` (lỗi biên dịch chắc chắn) + thiếu xử lý AM/PM (giờ lệch 12 tiếng): đã sửa.
(2) Hai chỗ `#Predicate` so sánh cột `String?` (ReviewView.checkDuplicate,
CardsView.applyCardChange) -> đổi sang fetch + lọc trong bộ nhớ, loại bỏ rủi ro macro.
(3) `ScanView` OCR — chuẩn hoá hướng ảnh (EXIF) trước khi đọc, tránh chữ bị xoay.
Lần build cloud đầu tiên là phép xác nhận cuối. Chuỗi build/sign/cài giữ
nguyên bản đã kiểm chứng ở IPA Test 0 rev 3 (app mở được, Face ID đạt trên máy thật).

## Có gì trong Build 1

| File | Vai trò |
|---|---|
| `SoHoaDonApp.swift` | `@main`, gắn SwiftData container cho Receipt/LineItem/CardTail |
| `Models.swift` | SwiftData models (tiền lưu bằng **cent Int** — chính xác từng cent), màu DESIGN-V2 (Cá nhân #005EB8 / Business #9A4A00), danh mục Schedule C + cá nhân, gợi ý phân loại theo đuôi thẻ, `ImageStore` (ảnh gốc vào Documents/ReceiptImages của app) |
| `ContentView.swift` | Cổng khoá Face ID **fail-open** (không có sinh trắc/mật mã → mở kèm thông báo, không crash, không khoá cứng) + khung 5 tab + nạp sẵn thẻ 2586 = Business (chỉ khi danh sách thẻ trống và chưa từng nạp) |
| `HomeView.swift` | Trang Chủ (thẻ Chờ Duyệt lên đầu, 2 ô tổng năm Cá nhân/Business, top mục, 5 tờ gần nhất) + **ReportsView** (Báo Cáo Thuế: tổng theo năm + theo mục — mới là bảng xem trước) |
| `ScanView.swift` | Camera quét tài liệu VisionKit → lưu ảnh gốc → OCR **VNRecognizeTextRequest** trên máy (vi+en, tắt sửa chính tả) → Parser → màn Review. Có đường dự phòng chọn ảnh trong thư viện (PhotosPicker) |
| `ReceiptViews.swift` | Danh sách (gom theo tháng, tìm full-text gồm cả văn OCR, lọc loại, **running total của tập đang hiện**), chi tiết (ảnh gốc, cờ kiểm lại, đổi loại/mục/mục đích, Duyệt, Xoá), màn **Review sau quét** (sửa trường, gợi ý thẻ kèm lý do + đổi tay, cảnh báo đối chiếu, chặn trùng theo dedupeKey có hộp thoại hỏi) |
| `CardsView.swift` | Đăng ký thẻ: thêm/sửa/**ngưng** (không xoá), vẽ như thẻ thật; đổi loại thẻ → hỏi "chỉ từ nay / xếp lại hoá đơn cũ"; cài đặt khoá Face ID |
| `Parser.swift` | Cổng nguyên luật prototype v0.1/v0.2: Sam's đầy đủ (mã 10 số, dòng qty `N AT 1 FOR`, INST SV tiền âm, TAX 1/TAX 2, TC# làm dedupeKey, # ITEMS SOLD) + generic cho tiệm khác. 3 luật toàn cục: đối chiếu chéo chỉ gắn cờ không sửa số; đuôi thẻ **chỉ** từ dòng có ký tự che; cắt vùng Suggested Tip trước khi trích tổng |
| `project.yml` | XcodeGen như Test 0, bundle `com.nje.sohoadon`, iOS 17.0, thêm `NSCameraUsageDescription`, version 0.1.0 build 2 |

### Kỷ luật dữ liệu đã cài vào code
- Mỗi hoá đơn lưu **snapshot phân loại riêng** (`classificationRaw` + `classificationReason`);
  sửa thẻ không tự viết lại lịch sử — chỉ đổi khi anh bấm "xếp lại hoá đơn cũ".
- Lưu từ màn Review mà còn cảnh báo / chưa rõ loại / business thiếu mục đích →
  trạng thái `needsReview` (Hộp Chờ), chưa phải chứng từ chính thức.
- Trùng dedupeKey (Sam's theo TC#) → cảnh báo trước khi lưu, anh quyết.
- Không xoá tự động bất cứ thứ gì; giữ theo chuẩn 7 năm của blueprint.

## Cố ý KHÔNG có trong Build 1 (để bản sau)
- Xuất Tax Pack PDF/CSV/ZIP (ReportsView mới có bảng tổng xem trước).
- Import PDF Sam's + Share Extension; Chụp Một Đống (Pile Mode); tách hoá đơn theo dòng (Split).
- Hoá đơn dài nhiều trang: camera quét nhiều trang nhưng Build 1 mới xử lý **trang đầu**.
- Tách từng món cho tiệm ngoài Sam's (generic chỉ lấy vendor/ngày/thẻ/subtotal/thuế/tổng).
- Lưu bản sao ra thư mục ngoài trong Files: **không dùng `.fileImporter`** — Test 0 đã
  kiểm chứng trên iOS 27.2 của anh là chọn thư mục của chính app bị huỷ im lặng.
  Ảnh nằm trong thư mục của app (Files vẫn thấy nhờ UIFileSharingEnabled). Muốn thêm
  thư mục ngoài phải dùng document picker cấp thấp + 1 bài test riêng trên máy thật.
- Đồng bộ iCloud/CloudKit: **cấm tuyệt đối** (Test 0: CloudKit ném exception chết app
  ngay lúc mở dưới cách ký của anh — có crash log).
- Giao diện Liquid Glass / API iOS 26 (RecognizeDocumentsRequest): để dành bài test
  pipeline riêng, không gộp vào bản tính năng.

## API đã chọn theo hướng bảo thủ (và điểm cần để mắt khi build đầu)
Tất cả đều là API từ iOS 17 trở xuống, tránh API mới hơn mức cần thiết:
- SwiftData `@Model/@Query/FetchDescriptor/#Predicate`, `.modelContainer(for:)` — chuẩn iOS 17.
- VisionKit `VNDocumentCameraViewController` qua `UIViewControllerRepresentable` + delegate cổ điển.
- Vision `VNRecognizeTextRequest` (KHÔNG dùng RecognizeDocumentsRequest của iOS 26).
- `PhotosPicker`/`loadTransferable` (iOS 16+), `LAContext.deviceOwnerAuthentication` (có mật mã dự phòng).
- `onChange(of:)` dạng 2 tham số (chuẩn iOS 17). Tiền xử lý bằng Int cent + NumberFormatter, không dùng Decimal lưu trữ.

### Cờ rủi ro biên dịch (flag cho người duyệt — file + vị trí + lý do)
1. `ScanView.swift` — `req.results ?? []` ép sang `[VNObservation]` rồi `compactMap` xuống
   `VNRecognizedTextObservation`: viết phòng thủ cho cả 2 cách khai báo kiểu của SDK
   (typed `[VNRecognizedTextObservation]` hoặc `[VNObservation]`). Nếu SDK trả kiểu typed
   sẵn, dòng này vẫn biên dịch (upcast hợp lệ); đây là điểm duy nhất em không chắc 100%.
2. ~~`ReceiptViews.swift` — `#Predicate` với cột `String?`~~ ĐÃ XỬ LÝ KHI DUYỆT:
   cả hai chỗ dùng predicate trên cột optional đã đổi sang fetch + lọc trong bộ nhớ.
3. `Models.swift` — `@Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)`:
   mẫu chuẩn tài liệu iOS 17; nếu XcodeGen/Xcode phàn nàn về key path, kiểm tra ở đây trước.
4. `ReceiptViews.swift` (ReceiptDetailView) — chỉnh sửa bằng `@State` cục bộ khởi tạo từ
   model trong `init` (không dùng `@Bindable`): an toàn biên dịch, nhưng nếu view bị
   SwiftUI tạo lại với hoá đơn khác mà state cũ còn giữ, số liệu hiển thị có thể cũ —
   rủi ro *hành vi*, không phải rủi ro biên dịch.
5. `ContentView.swift` — HomeView dẫn sang `ReceiptListView` (vốn có NavigationStack riêng)
   tạo **NavigationStack lồng nhau**: chạy được, có thể hơi khác về thanh tiêu đề; rủi ro thẩm mỹ.
6. Tab CHỤP là tab thường có icon to hơn một chút — chưa phải nút nổi giữa tab bar kiểu
   Cash App (cần tab bar tự vẽ; để bản polish sau khi nền tảng chạy ổn).

## Cách cài (tóm tắt — quy trình mới từ 2026-11-08: Muse nối GitHub trực tiếp)
1. Muse đẩy thẳng các file này lên repo `zjoenguyenz/Sohoadon` qua kết nối GitHub
   (thay bộ file Test 0, giữ nguyên `.github/workflows/build-ipa.yml`) — anh không nạp tay.
2. Actions tự chạy khi có push → tải artifact IPA chưa ký.
3. Ký bằng app sign của anh (chứng thư còn hạn) → cài đè lên bản Test 0
   (cùng bundle `com.nje.sohoadon` nên cài như bản cập nhật).
4. Mở app: qua cổng Face ID → Tab CHỤP → quét thử Mẫu 001 (Sam's) → màn Review phải hiện:
   10 dòng món, tổng $216.80, gợi ý "Thẻ •• 2586 — đã đăng ký Business".

# WP2 — HOÀN THIỆN MODEL DỮ LIỆU: BƯỚC 1 CHUẨN BỊ TỚI CỔNG (CHƯA đẩy code)
**Gói:** WP2 theo BUILD2-MASTER-PLAN §2 (WP2) + ACCOUNTING-SPEC §5.2.
**Ngày chuẩn bị:** 2026-11-09 12:40–13:00 CST (ca trực sohoadon-build2-247).
**Trạng thái:** Bước 1 của WP2 — model dữ liệu — đã chuẩn bị xong ở
`wp2-prep/Models.swift` (thay 1-1 cho `build1/Models.swift` khi được duyệt
đẩy) + `wp2-prep/SoHoaDonApp.swift` (đăng ký model mới vào container).
Đủ 3 chữ ký nội bộ (Design ✓ / Code ✓ / QA ✓ — xem dưới). **Chưa đẩy
code ở bất kỳ nhánh nào** (đúng luật ca trực). Còn chờ: nối dây ghi trường
mới lúc lưu (bước 2 của WP2, ca sau) → Wally duyệt cuối + thẻ duyệt đẩy
của anh → build cloud → nghiệm thu di trú trên bản sao kho Build 1.

## Việc đã làm trong ca này — đúng MỘT bước: model dữ liệu (không nối dây UI/parser)
- **Đối chiếu §5.2 từng thiếu hụt → trường chứa** (bảng dưới; tiêu chí
  cổng WP2 ở Master Plan: "QA đối chiếu từng thiếu hụt CAO/TRUNG →
  đã có trường chứa"):

| Mức | Thiếu hụt §5.2 | Trường mới trong bản chuẩn bị |
|---|---|---|
| CAO | Thuế gộp 1 số (C3) | `TaxLine` (@Model mới: label / rateText / amountCents / sortIndex) + `Receipt.taxLines: [TaxLine]` (cascade); helper `taxTotalCents` ưu tiên Σ taxLines |
| CAO | Không phân loại/mục cấp dòng (B7) | `LineItem.classificationRaw` + `LineItem.category` + `LineItem.scheduleCLine` + computed `classification` |
| CAO | Không có tip (C5) | `Receipt.tipAmountCents: Int?` + `totalPrintedCents: Int?` + helper `amountPaidCents` (= tổng in + tip) |
| CAO | Chỉ 1 ảnh gốc (F1) | `Receipt.originalImageFileNames: [String]` + helper `allOriginalImageFileNames` (gộp `imageFileName` Build 1 + danh sách, bỏ trùng) |
| CAO | `taxCents = nil` nhập nhằng (C4) | `taxTotalCents: Int?` giữ nguyên nghĩa: nil = chưa đọc được, 0 = miễn thuế thật; chỉ dùng taxLines khi có, không tự điền |
| TRUNG | Không có địa chỉ tiệm (A2) | `vendorAddress: String`, `vendorPhone: String?`, `storeNumber: String?` |
| TRUNG | Không có paymentMethod (D1) | `PaymentMethod` enum (card/cash/check/other/unknown) + `paymentMethodRaw` + computed |
| TRUNG | Category không lưu mã dòng Schedule C (E3) | `Receipt.scheduleCLine: String?` + `LineItem.scheduleCLine` + bảng gợi ý `Categories.scheduleCLine(forCategory:)` |
| TRUNG | Không có dấu vết duyệt/sửa (F5) | `reviewedAt: Date?` + `userEnteredFieldNames: [String]` (tên trường anh nhập tay) |
| TRUNG | Không có cờ vốn hoá Thiết Bị (E7) | `CapitalizationFlag` enum (undecided/deMinimisExpense/depreciableAsset) + `capitalizationFlagRaw` |
| TRUNG | Không có sourceType (F3) | `SourceType` enum (camera/photoLibrary/pdfImport/screenshot/unknown) + `sourceTypeRaw` + `sourceFileName` |
| TRUNG | Không có liên kết trùng (F6) | `stableID: String` + `duplicateOfStableID: String?` + `excludedFromTotals: Bool` |
| THẤP | Không lưu mã giao dịch riêng (A5/A6) | `transactionRef: String?` + `authCode: String?` (tách khỏi `dedupeKey` — Build 1 nhét TC# chung vào đó) |
| THẤP | Confidence chỉ ở 3 trường cấp hoá đơn (F4) | `parserVersion: String` (mức tối thiểu F4; độ tin cậy cấp dòng là việc WP4/WP6, không nhét vào model bước này) |
| THẤP | Chưa có retentionUntil (F7) | `retentionUntil: Date?` — chỉ để báo danh sách đến hạn; app không tự xoá |

- **Thêm ngoài bảng (đủ để WP2/WP6 chạy):** `mealsAttendees` (E5),
  `taxYearOverride` + helper `taxYear` (E6), `enhancedImageFileName` (F2,
  bản phái sinh lưu riêng — không bao giờ thay ảnh gốc),
  `isReturn: Bool` (V8: tổng âm chỉ hợp lệ khi là hoá đơn trả hàng).
- **Bảng Schedule C** (`Categories.scheduleCLine`): gợi ý mặc định theo
  ACCOUNTING-SPEC §3.2 — Vật Tư → line 22; Hàng Hoá → Part III line 4;
  Thiết Bị → Form 4562 / line 13; Meals → 24b; Travel → 24a; Vehicle →
  line 9; Office → line 18; Software → "line 18 or 27a (CPA unverified)"
  (ghi đúng chữ unverified của đặc tả); Utilities → line 25; Khác → 27a.
  Mã đã lưu trên từng hoá đơn là snapshot sửa được, bảng không ghi đè.
- **Ranh giới model bước này (không bịa):**
  - `stableID` để rỗng ở bản ghi cũ; bản ghi mới được cấp ở bước nối dây
    lưu (WP2 bước 2 / WP6, nơi luật trùng V9 được thực thi). Model chỉ
    tạo chỗ chứa — không tự gán liên kết trùng nào.
  - `totalPrintedCents` chỉ được ghi khi bộ đọc cung cấp rõ; không tự suy
    ra từ `totalCents`. `tipAmountCents` chưa có đường parser nào điền
    (nhà hàng là WP5/WP7) — trường đã có sẵn, chưa có số nào vào.
  - `reviewedAt` / `userEnteredFieldNames` chỉ là mức tối thiểu F5 theo
    ACCOUNTING-SPEC (bản audit trail đầy đủ sang v1.1 theo đặc tả).

## Tờ khai trung thực (claims / evidence / unverified)
- [ĐÃ KIỂM] Diff `build1/Models.swift` → `wp2-prep/Models.swift`:
  **+191 dòng / −0 dòng / 0 dòng sửa** — chỉ thêm: 3 enum mới
  (PaymentMethod / SourceType / CapitalizationFlag), bảng Schedule C,
  26 trường mới trên `Receipt`, quan hệ `taxLines`, 3 trường mới trên
  `LineItem` + computed `classification`, model `TaxLine` mới, 8 helper
  computed. Toàn bộ code cũ nguyên vẹn từng dòng.
- [ĐÃ KIỂM] `wp2-prep/SoHoaDonApp.swift`: đúng **1 dòng đổi** — thêm
  `TaxLine.self` vào `.modelContainer(for: [...])`; mọi dòng còn lại
  khớp byte với `build1/SoHoaDonApp.swift`.
- [ĐÃ KIỂM] Cân bằng cú pháp thô trên bản chuẩn bị: ngoặc nhọn 88/88,
  ngoặc đơn 156/156, ngoặc vuông 22/22 (bản gốc 59/59, 99/99).
- [ĐÃ KIỂM] Kiểu dữ liệu (TEAM.md lỗi #2): mọi trường mới có kiểu +
  mặc định khớp nhau (Int?/String/[String]/Bool/Date?/enum rawValue);
  không optional lọt vào tham số; helper computed theo đúng mẫu
  `classification`/`status` đã có sẵn trong cùng file.
- [ĐÃ KIỂM] Không trùng tên: grep toàn `build1/*.swift` — tên mới
  (`TaxLine`, `PaymentMethod`, `SourceType`, `CapitalizationFlag`,
  `scheduleCLine`, `taxTotalCents` trên `Receipt`) không xuất hiện ngoài
  `Models.swift` (chỉ `ParsedTaxLine`/`ParseResult.taxTotalCents` trong
  `Parser.swift` — kiểu khác, không xung đột). Trùng tên `label`/
  `classificationRaw`/`category`/`scheduleCLine` chỉ xảy ra giữa các
  class khác nhau (Receipt vs LineItem vs CardTail) — hợp lệ.
- [ĐÃ KIỂM] Mọi trường Build 1 mà code hiện tại dùng vẫn còn:
  `taxCents`, `imageFileName`, `classificationReason`, `dedupeKey`,
  `ocrRawText`, `vendorConfidence`… đều giữ nguyên trong bản chuẩn bị
  (grep đếm ≥ 1 lần mỗi trường). `ReceiptViews`/`HomeView`/`CardsView`
  không cần sửa để biên dịch với model này.
- [ĐÃ KIỂM] Di trú nhẹ (lightweight) theo thiết kế: mọi trường mới đều
  có mặc định hoặc optional; không trường nào bị xoá/đổi tên/đổi kiểu;
  model mới `TaxLine` có quan hệ cascade + optional `receipt`.
- [CHƯA KIỂM CHỨNG] Biên dịch: môi trường ca trực không có
  swiftc/xcodebuild (đã kiểm `which swiftc xcodebuild swift` — không
  có). Phép kiểm thật = build cloud sau khi anh duyệt đẩy. KHÔNG khẳng
  định "build được" trước bằng chứng đó.
- [CHƯA KIỂM CHỨNG] Di trú trên kho thật: chưa có bản sao kho Build 1
  trong ca này và chưa có compiler để chạy migration. Phép kiểm thật =
  sau bước 2 (nối dây), chạy migration trên bản sao kho có 2 tờ test của
  anh, đối chiếu số không đổi — đó là nửa sau của bằng chứng cổng WP2
  (Master Plan §2 WP2), chưa làm trong ca này.
- [CHƯA KIỂM CHỨNG] Hành vi trên máy: chưa có build nào chứa model này.

## Ba chữ ký nội bộ (TEAM.md — cổng 3 chữ ký)
- **Design ✓** — Bước này là model thuần, không đổi màn nào nên không
  có điểm kiểm giao diện mới; việc hiển thị 2 dòng thuế riêng / tip /
  nhiều ảnh / trường nguồn là việc của WP3/WP6/WP8 theo đúng thứ tự gói
  — không nhét UI vào model. Nhãn "Văn bản trong PDF" (F3 mục 3) vẫn
  chờ WP3 như WP1-GATE đã ghi; giờ `sourceType` đã có chỗ chứa để WP3
  nối nhãn.
- **Code ✓** — Rà độc lập trên bản chuẩn bị: diff chỉ-thêm như trên;
  kiểu/optional sạch; không vòng đời SwiftUI/SwiftData nào bị chạm
  (computed helper theo mẫu có sẵn); không import mới, không framework
  lạ, không đụng gì lúc khởi động app (TEAM.md lỗi #1: không áp dụng);
  `project.yml` không cần đổi (cùng tên file, cùng deployment target
  iOS 17 — `[String]`, enum rawValue và `@Relationship` đều dùng được
  từ SwiftData iOS 17).
- **QA ✓** — Đối chiếu lại từ đầu độc lập với người viết: bảng §5.2
  trên khớp từng dòng với ACCOUNTING-SPEC §5.2 (5 CAO + 7 TRUNG + 3
  THẤP — đủ 15 dòng, không sót); diff +191/−0; container đăng ký
  `TaxLine`; ranh giới (stableID rỗng, tip chưa có số vào, F5 tối thiểu)
  ghi đúng, không nuốt vào "đã xong". QA ký ở mức CHUẨN BỊ TỚI CỔNG
  BƯỚC 1 — không ký nghiệm thu WP2 (còn bước 2 + kiểm di trú).

## Việc còn lại của WP2 (ca sau, không làm trong ca này)
1. **Bước 2 — nối dây lúc lưu:** `ReviewView.save()` ghi `taxLines`
   từ `draft.result.taxes`, `transactionRef`/`dedupeKey`,
   `sourceType` (camera/photoLibrary theo đường vào),
   `paymentMethod` (từ cardLast4: có thẻ → card, không → unknown —
   KHÔNG đoán cash), `stableID` (UUID mới), `parserVersion`; đồng bộ
   ngược `taxCents` = Σ taxLines khi có dòng thuế riêng (giữ
   `taxCents` làm chân tương thích cho màn cũ). `ReceiptDetailView`
   hiển thị 2 dòng thuế riêng khi `taxLines` có dữ liệu.
2. **Kiểm di trú:** migration trên bản sao kho Build 1 (2 tờ test của
   anh còn nguyên, số không đổi) — bằng chứng cổng còn lại của WP2.
3. Sau 2 bước trên: Wally duyệt cuối + thẻ duyệt đẩy của anh → build
   cloud → anh cài + kiểm trên máy.

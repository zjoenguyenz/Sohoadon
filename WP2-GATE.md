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
**CẬP NHẬT 2026-11-09 14:40 CST: bước 2 ĐÃ chuẩn bị xong — xem mục
"WP2 BƯỚC 2" ở cuối văn bản này. WP2 (cả 2 bước) nay đủ điều kiện trình
cổng; mục kiểm di trú vẫn [CHƯA KIỂM CHỨNG] với lý do ghi rõ ở đó.**

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

---

## WP2 BƯỚC 2 — NỐI DÂY LÚC LƯU (bổ sung 2026-11-09 14:40 CST, ca trực sohoadon-build2-247)

**Trạng thái:** Bước 2 đã chuẩn bị xong trong `wp2-prep/` — bộ file đẩy
WP2 nay gồm đủ 4 file thay 1-1 cho bản trên main: `Models.swift` +
`SoHoaDonApp.swift` (bước 1) và `ReceiptViews.swift` + `ScanView.swift`
(bước 2 này). **Chưa đẩy code ở bất kỳ nhánh nào** (luật ca trực).

### Việc đã làm — đúng phạm vi "việc còn lại #1" của văn bản cổng bước 1
- **`ScanView.swift`** (diff so với `build1/ScanView.swift`: **+9 / −4** —
  4 dòng sửa, đều là nối nguồn nạp): `ScanDraft` thêm trường
  `sourceType: SourceType = .unknown`; `process(image:source:)` nhận
  nguồn theo đúng đường vào — quét tài liệu truyền `.camera`, chọn ảnh
  truyền `.photoLibrary` — và ghi vào draft. Không điểm dựng draft nào
  khác tồn tại trong code (đã grep toàn bộ).
- **`ReceiptViews.swift`** (diff so với bản WP1 đã trên main, md5
  `599cfc70…`: **+65 / −1**, dòng −1 duy nhất là dòng "Thuế" gộp được
  thay bằng khối hiển thị có điều kiện):
  - Hằng `currentParserVersion = "build1-parser"` — dấu F4 mức tối
    thiểu; WP4 thay engine thì đổi hằng, không sửa bản ghi cũ.
  - `ReviewView.save()` ghi thêm: `stableID` (UUID mới),
    `sourceType` (từ draft), `paymentMethod` (có đuôi thẻ → `.card`;
    không có → `.unknown` — KHÔNG đoán cash), `transactionRef` (chỉ
    tách từ `dedupeKey` dạng `SAMS-TC-<số>` / `TC-<số>`; khoá yếu
    `GEN|...` → để nil), `parserVersion`, và các `TaxLine` từ
    `draft.result.taxes` (quan hệ + insert như LineItem).
  - **Quyết định thiết kế (ghi rõ để anh/QA phán):** dòng thuế riêng
    CHỈ được lưu khi tổng thuế ở màn Kiểm Lại (số anh đã duyệt) còn
    khớp Σ dòng thuế máy đọc; khi đó `taxCents` được đồng bộ ngược =
    Σ taxLines (đúng số anh duyệt). Anh sửa tổng thuế lệch đi → giữ
    tổng gộp của anh, KHÔNG lưu chi tiết dòng cũ — tránh bịa cơ cấu
    thuế không còn đúng. Kiểm số học trên đáp án chuẩn Mẫu 002:
    960 + 390 = 1350¢ = $13.50 ✓ và 20330 + 1350 = 21680¢ = TOTAL ✓;
    trường hợp sửa lệch ($14.00 → 1400 ≠ 1350) cho persistTaxLines =
    false như thiết kế.
  - `ReceiptDetailView`: có `taxLines` → hiện từng dòng (nhãn + thuế
    suất, vd "TAX 1 (8.517%)") + dòng "Thuế (tổng)" từ helper
    `taxTotalCents`; chưa có → giữ nguyên dòng thuế gộp Build 1 (bản
    ghi cũ không đổi hành vi).
- **Cố ý KHÔNG nối ở bước này (đúng phạm vi đã chốt ở bước 1):**
  `scheduleCLine` lúc lưu (việc xếp mục/sửa mục là WP6/WP7 — C-7),
  `originalImageFileNames` (luồng Build 1 vẫn 1 ảnh, `imageFileName`
  đã chứa; danh sách nhiều ảnh thuộc WP3/WP8), `reviewedAt` /
  `userEnteredFieldNames` (cổng Duyệt là WP6). Trường đã có chỗ chứa
  từ bước 1; không nối dây vượt gói.

### Tờ khai trung thực bước 2 (claims / evidence / unverified)
- [ĐÃ KIỂM] Diff từng file như trên; đọc thẳng lại toàn bộ hàm
  `save()` sau khi sửa — cấu trúc ngoặc/vòng lặp nguyên vẹn; cân bằng
  cú pháp thô: ReceiptViews 182/182 ngoặc nhọn, 458/458 ngoặc đơn;
  ScanView 54/54, 104/104 (Models 88/88 như bước 1).
- [ĐÃ KIỂM] Mọi ký hiệu mới dùng trong 2 file đều tồn tại đúng kiểu
  trong `wp2-prep/Models.swift` (grep từng ký hiệu: TaxLine +
  label/rateText/amountCents/sortIndex, Receipt.taxLines / stableID /
  transactionRef / parserVersion / taxTotalCents, SourceType.camera /
  .photoLibrary, PaymentMethod.card / .unknown); `ParsedTaxLine`
  trong `Parser.swift` khớp từng trường được chép. Kiểu/optional rà
  theo TEAM.md lỗi #2: mẫu `cardLast4?.isEmpty == false` theo đúng
  idiom đã có trong Models.swift; `Int? == Int` ở điều kiện thuế là
  phép so optional hợp lệ.
- [ĐÃ KIỂM] Không framework lạ, không API mới ngoài UUID/String —
  TEAM.md lỗi #1/#3 không áp dụng; không đụng gì lúc khởi động app.
- [CHƯA KIỂM CHỨNG] Biên dịch: môi trường ca không có swiftc/
  xcodebuild (đã kiểm `which` — không có). Phép kiểm thật = build
  cloud sau khi anh duyệt đẩy (như WP1).
- [CHƯA KIỂM CHỨNG] **Kiểm di trú (việc còn lại #2):** trong workspace
  KHÔNG có bản sao kho Build 1 (đã tìm *.store/*.sqlite — không có)
  và không có compiler để chạy thử. Bằng chứng tĩnh đã có: mọi trường
  mới optional/có mặc định, không xoá/đổi tên/đổi kiểu trường cũ
  (diff bước 1 +191/−0) — di trú nhẹ theo thiết kế. Phép kiểm chạy
  thật chỉ làm được trên bản build chứa model mới; trình anh ở cổng:
  duyệt đẩy → build cloud → cài đè lên máy đang có 2 tờ test Build 1
  → mở app kiểm 2 tờ còn nguyên, số không đổi (đó là nghiệm thu WP2,
  thay cho "bản sao kho" vì kho thật chỉ nằm trên iPhone của anh và
  đội không có đường lấy bản sao).

### Ba chữ ký nội bộ cho bước 2
- **Design ✓** — Thay đổi hiển thị duy nhất: Chi Tiết hiện từng dòng
  thuế khi có dữ liệu, đúng nghiệm thu §F (2 dòng thuế riêng); bản
  ghi cũ giữ nguyên hiển thị. Không màn mới, không đổi luồng.
- **Code ✓** — Rà độc lập: diff chỉ trong phạm vi đã chốt; không
  đoán số (cash/transactionRef/taxLines đều có luật không-bịa ghi
  trong code); vòng đời SwiftData theo đúng mẫu LineItem có sẵn.
- **QA ✓** — Đối chiếu WP2-GATE bước 1 "việc còn lại #1" từng mục:
  taxLines ✓ / transactionRef+dedupeKey ✓ / sourceType theo đường
  vào ✓ / paymentMethod không đoán cash ✓ / stableID ✓ /
  parserVersion ✓ / đồng bộ taxCents ✓ / Chi Tiết hiện dòng thuế
  riêng ✓. QA ký CHUẨN BỊ TỚI CỔNG cho toàn WP2; nghiệm thu WP2 còn
  chờ build cloud + kiểm di trú trên máy anh như ghi ở trên.

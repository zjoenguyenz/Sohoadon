# WP3 — ĐƯỜNG PDF & NẠP FILE (F1): BƯỚC 1 CHUẨN BỊ (CHƯA tới cổng gói)
**Gói:** WP3 theo BUILD2-MASTER-PLAN §2 (WP3) + đặc tả CODE-AUDIT F1.
**Ngày chuẩn bị:** 2026-11-09 16:40 CST (ca trực sohoadon-build2-247).
**Trạng thái:** Bước 1 của WP3 — LÕI ĐƯỜNG PDF + NẠP TỪ FILES — đã chuẩn bị
xong ở `wp3-prep/` (4 file thay 1-1 cho bản trên main sau WP2:
`ScanView.swift`, `Models.swift`, `ReceiptViews.swift`, `project.yml`).
**Chưa đẩy code ở bất kỳ nhánh nào** (đúng luật ca trực). WP3 CHƯA tới
cổng gói: còn bước 2 (đón Share Sheet/`onOpenURL` + chốt cổng) — xem
"Việc còn lại của WP3" ở cuối. Theo LUẬT MỐC LỚN, anh không cài/test
riêng gói này; các bài kiểm trên máy gộp vào mốc M1.

## Chia bước của WP3 (theo đúng mẫu WP2: bước lõi → bước nối/đón)
- **Bước 1 (ca này):** nạp file từ Files (nhiều file một lúc) · trích lớp
  chữ PDF vào CÙNG `ReceiptParser` · lưu PDF gốc nguyên byte làm bằng
  chứng · PDF không lớp chữ → render trang 1 ~200 dpi → đường OCR cũ ·
  file ảnh (JPEG/PNG/HEIC) từ Files → đường OCR · nối dây lúc lưu
  (`sourceType`/`sourceFileName`/`originalImageFileNames`) · nhãn
  "Văn bản trong PDF" ở Kiểm Lại + Chi Tiết (**đóng F3 mục 3** còn treo
  từ WP1) · khai báo loại tài liệu trong `project.yml`.
- **Bước 2 (ca sau):** đón file từ Share Sheet / "Mở bằng Sổ Hóa Đơn"
  (`onOpenURL` + xử lý thư mục Inbox) để khai báo document-types ở bước 1
  có đường đi thật; rà soát hàng chờ nhiều file; chốt cổng WP3 (3 chữ ký
  cho toàn gói). **CẢNH BÁO NỘI BỘ: không được đẩy riêng phần project.yml
  của bước 1 khi chưa có bước 2** — app sẽ hiện trong menu "Mở bằng" mà
  không nạp được file (đường chết).

## Việc đã làm trong ca này — đúng MỘT bước: lõi đường PDF
- **`ScanView.swift`** (diff so với bản WP2 trên main: **+168 / −3**;
  3 dòng − là `.sheet` thêm `onDismiss`, chữ ký `process()` mở rộng có
  tham số mặc định, và điểm dựng `ScanDraft` — không dòng logic cũ nào
  bị sửa nghĩa):
  - Nút thứ ba "Nạp file (PDF / ảnh tải về)" → `fileImporter` CHỌN FILE
    (loại: PDF/JPEG/PNG/HEIC, `allowsMultipleSelection: true`). Hàng chờ
    `importQueue`: xử lý lần lượt từng file, mỗi file một màn Review;
    đóng Review (lưu hay huỷ đều qua `onDismiss`) thì nạp tiếp; nhánh lỗi
    của từng file cũng gọi nạp tiếp để một file hỏng không chặn cả lô.
  - `processImportedFile(url:)`: mở security-scoped resource và đóng
    trong CÙNG lượt gọi đồng bộ (bài học rò quyền ở CODE-AUDIT F1 mục 1);
    đường OCR bất đồng bộ phía sau chỉ dùng `UIImage` + JPEG đã lưu
    trong app, không chạm lại URL.
  - `processImportedPDF`: lưu PDF gốc TRƯỚC bằng
    `ImageStore.saveFile` (lưu hỏng → báo lỗi thật, dừng file đó);
    có lớp chữ → `ReceiptParser.parse(lines:)` với confidence 1.0 cho
    từng dòng, `imageFileName` trỏ thẳng tới file PDF đã lưu,
    `sourceType = .pdfImport`; không lớp chữ → render trang 1 → đường
    OCR cũ, PDF vẫn là bằng chứng chính qua `originalFileNames`.
  - `textLayerLines(pdfData:)`: PDFKit `PDFDocument` → `page.string` →
    tách dòng, bỏ dòng rỗng; trả `nil` khi không có dòng chữ nào (đó là
    tín hiệu rẽ nhánh, không phải lỗi). KHÔNG có parser thứ hai.
  - `renderPageImage`: `UIGraphicsImageRenderer` scale 1 (không lặp lỗi
    B-4), nền trắng, biến đổi lật trục Y theo mẫu Quartz chuẩn, ~200 dpi.
  - File ảnh từ Files → `process(image:source: .fileImport, …)` (nguồn
    nạp ghi trung thực, không mạo danh thư viện Photos).
  - `ScanDraft` thêm 2 trường có mặc định (`sourceFileName`,
    `originalFileNames`) — mọi điểm dựng draft cũ biên dịch nguyên vẹn.
- **`Models.swift`** (diff **+32 / −0**, thuần cộng thêm):
  - `ImageStore.saveFile(data:fileExtension:)` — lưu file nguyên byte
    vào `ReceiptImages`, trả tên file hoặc nil.
  - `ImageStore.load` rẽ nhánh `.pdf`: render trang 1 bằng
    `PDFPage.thumbnail(of:for:)` (rộng 1240px) — cả 3 điểm gọi hiện có
    (dòng danh sách / Chi Tiết / Kiểm Lại) đều qua hàm này và đều dùng
    `if let`, không phải sửa điểm gọi nào.
  - `SourceType.fileImport` — một case rawValue String MỚI, thuần cộng
    thêm: không trường nào đổi/xoá, bản ghi cũ đọc nguyên nghĩa → không
    thuộc diện "thay đổi model không thuần cộng thêm" phải dừng báo.
  - Sửa 1 chú thích cũ nay gây hiểu lầm (fileImporter: cấm chọn THƯ MỤC,
    được chọn FILE từ WP3) — chỉ là chú thích, không phải code.
  - `import PDFKit` chỉ chạm khi nạp file / hiển thị PDF — không đụng
    lúc khởi động app (TEAM.md lỗi #1 không áp dụng).
- **`ReceiptViews.swift`** (diff **+20 / −7**; 7 dòng − là đúng 2 điểm
  gọi `RawTextDisclosure` + chú thích đi kèm được thay):
  - F3 mục 3 ĐÓNG: cả Kiểm Lại và Chi Tiết truyền nhãn theo nguồn —
    `sourceType == .pdfImport` → "Văn bản trong PDF", còn lại "Văn bản
    OCR gốc". (Trường hợp PDF render->OCR vẫn mang nhãn PDF vì văn bản
    thô lúc đó là OCR trên ảnh render của PDF — xem mục phản biện.)
  - `ReviewView.save()` nối thêm: `sourceFileName` +
    `originalImageFileNames` từ draft (cùng chỗ với nối dây WP2).
- **`project.yml`** (+7 dòng): `CFBundleDocumentTypes` cho
  `com.adobe.pdf` + `public.image`, role Viewer, `LSHandlerRank:
  Alternate` (app nhận mở nhưng không giành làm mặc định). YAML đã kiểm
  hợp lệ bằng parser thật.

## Kiểm chứng phía mình đã chạy (bằng chứng file)
- **Fixture trích lớp chữ** (`wp3-fixtures/`, chạy thật trên máy này):
  `make_fixture_pdfs.py` dựng 2 PDF TỰ TẠO (ghi rõ SYNTHETIC — **không
  phải PDF Sam's thật của anh**, file đó chưa về tay đội): một PDF có
  lớp chữ mà 36 dòng là đúng văn bản `parser-prototype/sample001-raw-
  text.txt`, một PDF không có toán tử chữ nào.
  `verify_pdf_pipeline.py` (dùng `pdftotext` của poppler làm phép trích
  độc lập) → kết quả lưu ở `wp3-fixtures/verify-results.txt`:
  - Trích xuất: 36/36 dòng; 35 dòng khớp từng byte, 1 dòng ("sam's
    club") chỉ khác codepoint dấu nháy (pdftotext cho nháy cong U+2019)
    — parser Swift `isSams` chấp nhận cả hai biến thể nên nhánh Sam's
    vẫn bắt đúng (chứng minh gián tiếp: toàn bộ bài §F dưới đây chạy
    qua nhánh Sam's mới ra được các số đó).
  - Bài §F trên các dòng trích ra, bằng bản port Python TRUNG THỰC các
    pattern của `parseSams` trong `build1/Parser.swift`: **10/10 đạt** —
    10 dòng món · Σ món 20330 · subtotal 20330 · TAX 1 8.517% 960 ·
    TAX 2 4.017% 390 · TOTAL 21680 · # ITEMS SOLD 15 · tổng SL theo
    đúng luật `validate()` (chỉ đếm món tiền dương) = 15 · khoá
    `SAMS-TC-797797957863725610228` · thẻ ••2586 · subtotal+thuế=tổng ✓.
  - PDF không lớp chữ: trích ra **0 dòng** → đúng điều kiện rẽ sang
    render->OCR như code đã viết.
  - sha256: text-layer `670c5b25…` · no-text-layer `22e3e1d5…`
    (bản đầy đủ trong thư mục fixtures; PDF 1631 / 504 byte, 1 trang).
  - GIỚI HẠN của bằng chứng này, nói thẳng: nó chứng minh (a) văn bản
    trích từ lớp chữ GIỮ ĐƯỢC DẠNG DÒNG mà parser cần, và (b) logic rẽ
    nhánh đúng. Nó KHÔNG chứng minh PDFKit `page.string` trên iOS cho
    cùng kết quả (thứ tự dòng/khoảng trắng có thể khác poppler), và bản
    port Python không phải parser Swift đang chạy trên máy anh.
- **Kiểm tĩnh code** (mẫu như WP1/WP2): diff từng file như trên; cân
  bằng ngoặc ScanView 82/82 · Models 94/94 · ReceiptViews 182/182
  (ngoặc đơn 183/183 · 175/175 · 461/461); mọi ký hiệu mới dùng đều tồn
  tại đúng kiểu ở file đích (grep từng ký hiệu); rà kiểu/optional theo
  TEAM.md lỗi #2 (PDFPage? qua guard, thumbnail trả UIImage đưa vào
  UIImage? hợp lệ, kết quả fileImporter `[URL]` khớp
  `allowsMultipleSelection`).

## Tờ khai trung thực (claims / evidence / unverified)
- [ĐÃ KIỂM] Fixture + bài §F + rẽ nhánh fallback: như mục trên, có file
  kết quả và sha256.
- [ĐÃ KIỂM] Diff/cân bằng/ký hiệu/YAML: như mục trên.
- [CHƯA KIỂM CHỨNG] Biên dịch: môi trường ca không có swiftc/xcodebuild.
  Phép kiểm thật = build cloud sau khi anh duyệt đẩy (cả WP3, ở cổng gói).
- [CHƯA KIỂM CHỨNG] PDFKit trên máy thật: thứ tự dòng của `page.string`
  trên PDF Sam's/Best Buy thật; hướng ảnh của `renderPageImage` (đã
  dùng mẫu lật trục chuẩn nhưng chưa có mắt thật nhìn); hành vi
  `fileImporter` CHỌN FILE trên iOS của anh (TEAM.md lỗi #3 — Test 0
  mới kết án chế độ chọn thư mục). Cả ba gộp vào bài kiểm mốc M1, ghi
  sẵn ở "Việc còn lại".
- [CHƯA NGHIỆM THU — chờ file] PDF Sam's thật của anh: chưa có (WORK-
  STATE điểm chờ). §3.2 của Master Plan: nghiệm thu WP3 chạy trên PDF
  lớp chữ thật khác khi tới cổng; riêng Sam's ghi chờ, không ghi đạt thay.
- [GIỚI HẠN ĐÃ BIẾT, không giấu] (i) PDF nhiều trang có lớp chữ: trích
  đủ mọi trang vào parser, nhưng bằng chứng hiển thị/OCR-render vẫn
  trang 1 — nhiều trang đầy đủ là WP8. (ii) PDF bị mã hoá/khoá: lớp chữ
  rỗng → rơi xuống render → cũng khoá → báo lỗi, chưa có xử lý riêng.
  (iii) File đuôi .pdf nhưng ruột là ảnh: báo lỗi thay vì đọc như ảnh
  (chấp nhận được — hoá đơn tải về của Sam's/Best Buy là PDF thật).
  (iv) Xoá hoá đơn ở Chi Tiết chỉ xoá `imageFileName`: bản PDF render
  ->OCR nằm ở `originalImageFileNames` chưa được xoá theo — thuộc họ
  B-6/B-7 đã xếp WP6, không mở rộng phạm vi WP3.

## Tự phản biện trước cổng bước (State 4)
- Danh mục lỗi TEAM.md: #1 framework lạ lúc khởi động — PDFKit chỉ chạm
  sau thao tác của anh ✓ · #2 kiểu/optional — đã rà ✓ · #3 API chưa
  kiểm trên máy anh dùng cho luồng chính — fileImporter là luồng nạp
  MỚI song song (camera/Photos cũ nguyên vẹn, hỏng đường file không
  chết đường cũ), bài kiểm máy thật đã ghi vào M1 ✓ có điều kiện ·
  #4 suy đoán thay bằng chứng — tiền đề trích xuất đã đo bằng fixture,
  phần PDFKit ghi unverified rõ ràng ✓.
- Nhãn "Văn bản trong PDF" cho trường hợp render->OCR: văn bản thô lúc
  đó là OCR chứ không phải lớp chữ. Suy xét: nhãn phân biệt theo NGUỒN
  NẠP (đúng mục đích F3 là cho biết tờ này vào bằng đường nào); nhưng
  để tránh hiểu lầm "đây là chữ trong file", bước 2 sẽ cân nhắc đổi
  nhãn nhánh đó thành "Văn bản OCR gốc (từ PDF)" — quyết ở bước 2 kèm
  rà soát cổng, không tự đổi trong ca này.
- Hàng chờ nhiều file: đã rà các đường tiến — file lỗi không chặn lô,
  OCR chạy dở không bị nạp chồng (guard `!isProcessing`), đóng Review
  mới nạp tiếp. Hàng chờ là URL security-scoped: URL được giữ trong
  `@State` và CHỈ mở scope ngay trước khi đọc đồng bộ — không giữ
  scope qua lúc chờ Review (đúng vòng đời scope của iOS).
- Không bịa số: lớp chữ confidence 1.0 chỉ tắt cảnh báo "chữ mờ";
  `validate()` vẫn chạy đủ V1/V2/V4 như mọi đường (Master Plan §5.5).

## Ba chữ ký nội bộ cho BƯỚC 1 (không phải ký cổng WP3)
- **Design ✓** — Một nút mới cùng hàng với 2 nút nạp sẵn có (cùng style
  bordered/large), không màn mới, không đổi luồng cũ; nhãn F3 trung
  thực theo nguồn. Thiết kế sâu (trạng thái đang nạp lô, tiến độ file)
  là WP8/WP9 — bước này giữ tối thiểu có chủ đích.
- **Code ✓** — Rà độc lập: diff chỉ trong phạm vi đã chốt; scope bảo
  mật đóng trong cùng lượt gọi; không parser thứ hai; model chỉ cộng
  thêm 1 case enum; mọi nhánh lỗi đều có đường ra + nạp tiếp hàng chờ.
- **QA ✓** — Đối chiếu CODE-AUDIT F1 từng mục: nạp Files nhiều file ✓
  (Share Sheet → bước 2, đã ghi) · hook `processImportedFile` ✓ ·
  trích lớp chữ đúng mã mẫu F1 ✓ · confidence 1.0 ✓ · lưu PDF gốc +
  hiển thị render trang 1 ✓ · fallback không lớp chữ → render → OCR ✓.
  QA ký CHUẨN BỊ BƯỚC 1 — chưa ký cổng WP3.

---

# BƯỚC 2 — ĐÓN SHARE SHEET / onOpenURL + CHỐT CỔNG WP3 (2026-11-09 18:40 CST)

**Trạng thái sau ca này: WP3 ĐÃ TỚI CỔNG GÓI** — đủ 3 chữ ký nội bộ cho
toàn gói (mục cuối). Code ở `wp3-prep/` nay gồm **5 file** (thêm
`ContentView.swift`). **CHƯA đẩy code** — trình Wally ở chat chính để
anh duyệt thẻ đẩy lên main; bài kiểm trên máy gộp mốc M1 theo luật mốc
lớn, KHÔNG xin anh cài/test riêng gói này.

## Việc đã làm trong ca này — đúng MỘT bước: bước 2 của WP3
(Diff bước 2 đo bằng diff dòng đơn giản so với bản bước 1; số luỹ kế
so với main/WP2 ghi ở mục chốt cổng.)

- **`ContentView.swift`** (file MỚI trong wp3-prep; nền = build1 —
  WP2 không đụng file này; diff so với build1: **+18 / −2**, 2 dòng −
  là điểm dựng `TabShellView(...)` và `ScanView()` được nối thêm tham
  số binding):
  - `ContentView` giữ `@State pendingImportURLs: [URL]` và nhận file
    qua `.onOpenURL` — URL chỉ được GIỮ, không đọc tại đây. App đang
    khoá Face ID thì URL chờ; mở khoá xong mới truyền xuống (không đọc
    file trước cổng khoá, đúng tinh thần TEAM.md lỗi #1).
  - `TabShellView` nhận `@Binding pendingImportURLs`, truyền thẳng
    xuống `ScanView(externalImportURLs:)`; có file chờ → tự nhảy sang
    tab CHỤP (`.onChange`).
- **`ScanView.swift`** (bước 2: **+63 / −1**; dòng −1 duy nhất là dòng
  dựng `ScanDraft` của nhánh lớp chữ được nối thêm tham số):
  - `@Binding var externalImportURLs` + `consumeExternalImports()`:
    đổ URL ngoài vào CÙNG `importQueue` của đường Files rồi xoá danh
    sách chờ — điểm nạp duy nhất vẫn là
    `processNextImportedFile`/`processImportedFile`, **không có đường
    nạp thứ hai**. Hút ở 2 thời điểm: `.onChange` (file tới lúc màn
    Chụp đang hiện) và `.onAppear` (file chờ từ lúc app khoá/ở tab
    khác). Hàng chờ bận (đang OCR/đang mở Review) thì URL nằm lại trong
    queue, `onDismiss` của Review gọi tiếp như đường Files.
  - `sweepInbox()` ở `.onAppear`: quét `Documents/Inbox` — nơi iOS chép
    file khi mở-bằng-app mà không mở-tại-chỗ — nạp nốt file còn sót
    (onOpenURL chưa chạy / app bị giết giữa chừng).
  - `removeInboxCopyIfNeeded(_:)`: trong `processImportedFile`, ngay
    sau khi `Data(contentsOf:)` đọc xong, xoá bản sao **chỉ khi URL
    nằm trong Documents/Inbox của chính app** (so prefix đường dẫn đã
    standardized). File mở-tại-chỗ từ Files không nằm trong Inbox →
    file gốc của anh tuyệt đối không bị đụng. Xoá sau khi đọc = quét
    Inbox lần sau không nạp trùng.
  - Security-scoped: URL ngoài đi qua đúng hàm cũ — scope mở và đóng
    trong cùng lượt gọi đồng bộ, đường OCR phía sau không chạm lại URL
    (giữ nguyên kỷ luật bước 1; file Inbox nằm trong sandbox nên
    `startAccessing…` trả false, vô hại).
- **QUYẾT NHÃN OCR-TỪ-PDF (việc treo từ mục phản biện bước 1) — ĐÃ
  QUYẾT:** nhãn F3 nói đúng ĐƯỜNG sinh ra chữ theo đúng chữ CODE-AUDIT
  F3 mục 3 ("honest label about which pipeline produced it"), không
  chỉ nguồn nạp:
  - Lớp chữ PDF → **"Văn bản trong PDF"**
  - PDF render→OCR → **"Văn bản OCR gốc (từ PDF)"**
  - Mọi đường ảnh → **"Văn bản OCR gốc"**
  - Cơ chế: `ScanDraft.rawTextIsPDFTextLayer` (chỉ nhánh lớp chữ gắn
    true) → lưu vào trường mới `Receipt.rawTextFromPDFTextLayer`
    (**Models.swift bước 2: +6 / −0** — một Bool có mặc định, THUẦN
    cộng thêm, di trú nhẹ; chưa từng có bản ghi `.pdfImport` nào trên
    máy ai vì WP3 chưa đẩy, nên không bản ghi cũ nào bị nhãn sai) →
    một helper chung `rawTextTitle(sourceType:isPDFTextLayer:)` trong
    **ReceiptViews.swift (bước 2: +16 / −2**, 2 dòng − là đúng 2 điểm
    gọi nhãn cũ) dùng cho cả Kiểm Lại và Chi Tiết; `save()` nối thêm
    đúng 1 dòng chép cờ.

## Kiểm chứng phía mình đã chạy (bằng chứng)
- Diff từng file như trên; cân bằng ngoặc: ScanView 94/94 (đơn
  210/210) · Models 94/94 (178/178) · ReceiptViews 185/185 (470/470) ·
  ContentView 36/36 (64/64).
- Grep ký hiệu: mọi ký hiệu mới (`rawTextTitle`, `rawTextIsPDFTextLayer`,
  `rawTextFromPDFTextLayer`, `consumeExternalImports`, `sweepInbox`,
  `removeInboxCopyIfNeeded`, `externalImportURLs`, `pendingImportURLs`)
  tồn tại đúng chỗ định nghĩa + điểm dùng; điểm dựng `ScanView(` duy
  nhất trong bộ prep là ở ContentView mới với binding khớp; trường
  ScanDraft mới có giá trị mặc định nên mọi điểm dựng draft cũ biên
  dịch nguyên vẹn.
- Rà kiểu/optional (TEAM.md lỗi #2): `[URL]` là Equatable cho
  `onChange(of:)`; closure `onChange` 2 tham số đúng iOS 17; binding
  truyền qua 2 tầng (ContentView → TabShell → ScanView) cùng một
  `@State` gốc.
- KHÔNG chấm lại điểm cổng: bước 2 không đổi khả năng đọc (đường trích
  lớp chữ + parser giữ nguyên từng dòng) — điểm 001/002/003 không đổi;
  SCORECARD thêm 1 dòng nhật ký ghi việc này, không ghi điểm mới.

## Tự phản biện trước cổng gói (State 4)
- Danh mục lỗi TEAM.md: #1 framework lạ lúc khởi động — onOpenURL chỉ
  GIỮ URL, không chạm PDFKit/không đọc file; đọc chỉ xảy ra sau thao
  tác/thao tác mở file của anh và sau cổng Face ID ✓ · #2 kiểu/
  optional — đã rà ✓ · #3 API chưa kiểm trên máy anh — onOpenURL +
  document-types là luồng MỚI song song, luồng camera/Photos/Files cũ
  nguyên vẹn; bài kiểm máy thật đã ghi vào M1 ✓ có điều kiện · #4
  suy đoán thay bằng chứng — hành vi Inbox/onOpenURL của iOS là tài
  liệu chuẩn của Apple nhưng CHƯA đo trên máy anh → ghi unverified ở
  dưới, không khẳng định ✓.
- Trường hợp biên đã rà trong code: (i) mở 2 file một lúc từ Share
  Sheet → onOpenURL gọi từng URL, queue xử lý lần lượt ✓ (ii) mở file
  khi đang có draft Review mở → queue chờ, onDismiss nạp tiếp ✓
  (iii) mở file trùng tên ở Inbox → iOS tự đổi tên bản sao, app đọc
  theo URL được trao, không đoán theo tên ✓ (iv) file Inbox bị xoá
  giữa chừng → nhánh lỗi đọc-file sẵn có báo lỗi + nạp tiếp ✓
  (v) vòng lặp onChange: ScanView xoá `externalImportURLs` → TabShell
  onChange nhận mảng rỗng → guard không nhảy tab ✓.
- Cảnh báo bước 1 ("không đẩy riêng project.yml trước bước 2") ĐÃ
  HẾT HIỆU LỰC: đường "Mở bằng" nay có đầu nhận thật (onOpenURL +
  Inbox) — cả gói đẩy chung một lần.

## Tờ khai trung thực toàn gói WP3 (claims / evidence / unverified)
- [ĐÃ CHỨNG MINH phía mình] Trích lớp chữ giữ dạng dòng + bài §F 10/10
  trên fixture tự tạo + rẽ nhánh fallback (bằng chứng bước 1:
  `wp3-fixtures/verify-results.txt`) · diff/cân bằng/grep ký hiệu cả
  2 bước · YAML hợp lệ (bước 1).
- [CHƯA CHỨNG MINH] Biên dịch (không compiler trong môi trường ca —
  phép kiểm thật là build cloud sau khi anh duyệt đẩy) · PDFKit
  `page.string` trên iOS cho thứ tự dòng ra sao trên PDF thật · hướng
  ảnh render · hành vi fileImporter CHỌN FILE, onOpenURL, và đường
  Inbox trên iOS của anh. Tất cả gộp vào bài kiểm mốc M1: mở-bằng từ
  Files/Mail → app nhận + mở Kiểm Lại; PDF lớp chữ thật → đọc được;
  PDF scan → render đúng chiều; nạp 2–3 file → Review lần lượt; Inbox
  trống sau khi nạp.
- [CHƯA LÀM / CHƯA NGHIỆM THU] PDF Sam's thật — chờ file của anh
  (Master Plan §3.2: ghi chờ, không ghi đạt thay) · PDF nhiều trang
  đầy đủ = WP8 · PDF mã hoá/khoá: chưa có xử lý riêng (giới hạn đã
  biết ở bước 1) · quyết nền tảng iOS 26 (anh duyệt ở làn thiết kế
  17:32 CST) CHƯA áp vào `project.yml` (vẫn 17.0) — thuộc quyết định
  nền tảng gắn WP4 (§5.6), không tự đổi trong WP3; ghi để Wally xử lý
  khi trình cổng.

## Số luỹ kế toàn gói WP3 so với main (WP2) — đo bằng diff dòng đơn giản
`ScanView.swift` +230/−3 · `Models.swift` +42/−2 (2 dòng − là chú
thích cũ viết lại ở bước 1) · `ReceiptViews.swift` +34/−7 ·
`ContentView.swift` (so với build1, WP2 không đụng) +18/−2 ·
`project.yml` +7/−0. Model: chỉ cộng thêm (1 case enum + 1 Bool có
mặc định) — không thuộc diện thay đổi không-thuần-cộng-thêm phải
dừng báo.

## Ba chữ ký nội bộ — CỔNG WP3 (toàn gói, thay các ký bước)
- **Design ✓** — Không màn mới, không nút mới ở bước 2: mở file từ
  ngoài → app tự nhảy tab CHỤP → Kiểm Lại như mọi đường nạp; nhãn F3
  3 nhánh trung thực theo đường đọc. Trạng thái tiến độ lô để WP8/WP9
  như đã chốt ở bước 1.
- **Code ✓** — Một điểm nạp duy nhất cho 3 đường vào (Files / Share
  Sheet / Inbox); scope bảo mật đóng trong cùng lượt gọi; xoá Inbox
  có điều kiện prefix, không đụng file gốc mở-tại-chỗ; model thuần
  cộng thêm ở cả 2 bước.
- **QA ✓** — Đối chiếu CODE-AUDIT F1 đủ 5 mục: nạp Files + Share
  Sheet/onOpenURL + document-types ✓ · hook `processImportedFile`
  duy nhất ✓ · trích lớp chữ đúng mã mẫu, confidence 1.0, vẫn qua
  validate() ✓ · lưu PDF gốc + hiển thị render trang 1 ✓ · fallback
  không lớp chữ → render → OCR ✓ — và F3 mục 3: nhãn đúng đường đọc
  ở cả 2 màn ✓. **QA KÝ CỔNG WP3** (cổng nội bộ theo luật mốc lớn;
  nghiệm thu máy thật gộp mốc M1).

## Việc còn lại của WP3 (cũ — ĐÃ LÀM ở bước 2 phía trên)
1. **Bước 2 — đón Share Sheet:** `onOpenURL`/Inbox trong ContentView/
   App: file được hệ thống chép vào `Documents/Inbox` phải được đưa
   vào cùng hàng chờ nạp của ScanView (dùng chung `processImportedFile`,
   không viết đường thứ hai); kiểm file Inbox được dọn sau khi nạp.
2. Rà soát + quyết nhãn OCR-từ-PDF (mục phản biện trên).
3. Chốt cổng WP3: Wally duyệt cuối → anh duyệt thẻ đẩy → build cloud.
   Bài kiểm máy gộp mốc M1 (không xin anh test riêng): chọn 1 PDF lớp
   chữ thật từ Files → đọc được; PDF scan không lớp chữ → render đúng
   chiều, OCR chạy; nạp 2–3 file một lúc → Review lần lượt; Chi Tiết
   hiện render trang 1 + nhãn "Văn bản trong PDF".

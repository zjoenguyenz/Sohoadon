# WORK STATE — Build 2 (ca trực 24/7 cập nhật file này)
Cập nhật lần cuối: 2026-11-09 16:40 CST (ca trực sohoadon-build2-247;
WP3 bước 1 — lõi đường PDF + nạp từ Files — đã chuẩn bị xong, xem
WP3-GATE.md. WP2 code đã lên main 15:52 CST commit `d7497d8`.)
Đẩy tài liệu ca này: xem dòng cuối mục này sau khi thử đẩy (luật chống
treo: thử đúng 1 lần ở cuối ca).

## Vị trí hiện tại
- Master Plan đã trình anh (23:38) + anh trả lời hết câu hỏi mở (LLC 1 thành
  viên; hàng mua để dùng → Supplies).
- **WP0 ĐÃ XONG — QUA CỔNG (2026-11-09 02:41 CST):** SCORECARD.md đã tạo
  (Wally, 00:41) + **QA ✓ KÝ NHẬN thứ tự gói WP1→WP9** theo Master Plan §5.0.
  Văn bản ký nhận: `WP0-QA-SIGNOFF.md`.
- **WP1 — CODE ĐÃ CHUẨN BỊ TỚI CỔNG (2026-11-09 04:40 CST):** cửa chẩn đoán
  F3 đã viết xong theo đặc tả CODE-AUDIT F3 mục 1+2 — mục "Văn bản OCR gốc"
  (DisclosureGroup thu gọn mặc định, chữ monospaced, copy được) ở màn Kiểm
  Lại (dưới ảnh gốc) + màn Chi Tiết (sau "Thông tin", ẩn khi rỗng), dùng
  chung 1 component `RawTextDisclosure`. Bản chuẩn bị:
  `wp1-prep/ReceiptViews.swift` (thay 1-1 cho `build1/ReceiptViews.swift`;
  diff đã kiểm: **+39 dòng / −0 / 0 dòng sửa**; cân bằng ngoặc 169/169).
  Đủ 3 chữ ký nội bộ Design ✓ / Code ✓ / QA ✓ — văn bản cổng: `WP1-GATE.md`.
  **CHƯA đẩy code ở bất kỳ nhánh nào** (đúng luật ca trực); biên dịch
  [CHƯA KIỂM CHỨNG] (môi trường ca không có compiler — build cloud là phép
  kiểm sau khi anh duyệt đẩy).
- **Ranh giới ghi rõ trong WP1-GATE.md:** nhãn "Văn bản trong PDF" (F3 mục 3)
  CHƯA làm — chưa có đường PDF (WP3) và chưa có trường nguồn `sourceType`
  (WP2) để phân biệt nguồn ở màn Chi Tiết; component đã nhận `title` làm
  tham số để WP3 nối nhãn, không dựng lại viewer. Mục 3 = chuyển WP3.
- **CORPUS — MỤC 3 ĐÃ LÀM XONG PHẦN KHÔNG CẦN ANH (2026-11-09 06:40 CST):**
  làn lab đã tải + kiểm chứng xong cả 3 bộ, danh mục 7 loại hình đã lập —
  văn bản: `corpus/CORPUS.md` (+ bằng chứng nguồn ở `corpus/_sources/`).
  Số đo chính: WildReceipt toàn bộ bản MMOCR (test 472 / train 1,267 tờ
  có nhãn, 72,485 hộp; 185,323,520 byte, sha256 ở CORPUS.md) · CORD v1
  test split 100 tờ (234,201,893 byte, pyarrow đếm đúng 100 dòng;
  train/validation CHƯA tải — có chủ đích, chỉ cần khi WP4 gọi) · SROIE
  bản cộng đồng 973 tờ (train 626/test 347; KHÔNG phải bản ICDAR chính
  thức, cảnh báo giấy phép ở CORPUS.md A3). Danh mục thật của anh: đã có
  kho sỉ (001/002) + big-box (003); 5 loại còn trống, lớn dần theo hoá
  đơn thật anh gửi (không phải việc ca trực tự tạo được).
- **WP1 CODE ĐÃ ĐẨY LÊN MAIN (2026-11-09 10:44 CST):** anh duyệt trong chat
  ("Đẩy code WP1 lên build bản mới luôn") + duyệt thẻ đẩy; commit **7697276**.
  Wally duyệt cuối trước khi đẩy: tự diff lại — đúng +39/−0, thuần cộng thêm.
  Kiểm chứng độc lập của ca trực 10:40 trên GitHub: commit đầy đủ
  `769727698d` (16:44:18Z); file `ReceiptViews.swift` trên main = 28.588
  byte, md5 `599cfc70c015228acc54996ad4fd5eb7` — khớp byte-for-byte với
  `wp1-prep/ReceiptViews.swift`, có `RawTextDisclosure`; ca trực không
  đẩy lại để tránh trùng. Build cloud: [CHƯA KIỂM CHỨNG trong ca này —
  connector GitHub không có công cụ xem Actions].
  **WP1 ĐÃ ĐÓNG — NGHIỆM THU XONG (2026-11-09 10:57 CST):** anh cài bản
  7697276, mở Chi Tiết tờ Home Depot, mục "Văn bản OCR gốc" hiện đầy đủ
  (screenshot anh gửi). **WP2 MỞ** — các ca sau bắt đầu chuẩn bị WP2.
  Thu hoạch chẩn đoán (samples/sample-003-ocr-raw.txt + mục chẩn đoán
  trong sample-003-ground-truth.md): tiền nằm dòng TRƯỚC nhãn (parser
  cùng-dòng trượt sạch dù chữ đọc đúng gần hết); tên tiệm vắng mặt trong
  OCR (logo → khẩu hiệu) → WP5 phải dùng neo địa chỉ; "2@34.98" dính.
- **WP2 — BƯỚC 1 (MODEL) ĐÃ CHUẨN BỊ TỚI CỔNG (2026-11-09 12:40 CST):**
  `wp2-prep/Models.swift` (thay 1-1 cho `build1/Models.swift`; diff đã
  kiểm: **+191 dòng / −0 / 0 dòng sửa**; cân bằng ngoặc 88/88) +
  `wp2-prep/SoHoaDonApp.swift` (đúng 1 dòng đổi: đăng ký `TaxLine` vào
  modelContainer). Đủ 15 dòng thiếu hụt §5.2 (5 CAO + 7 TRUNG + 3 THẤP)
  đã có trường chứa: `taxLines[]`/`TaxLine`, tip + totalPrinted, phân
  loại cấp dòng, `originalImageFileNames[]`, paymentMethod, địa chỉ
  tiệm, transactionRef/authCode, scheduleCLine (+ bảng gợi ý §3.2),
  sourceType, duplicateOf/excludedFromTotals, reviewedAt +
  userEnteredFieldNames, retentionUntil. Mọi trường Build 1 GIỮ NGUYÊN
  (di trú nhẹ theo thiết kế). Đủ 3 chữ ký nội bộ — văn bản cổng:
  `WP2-GATE.md`. **CHƯA đẩy code ở bất kỳ nhánh nào** (đúng luật ca
  trực); biên dịch + di trú trên kho thật [CHƯA KIỂM CHỨNG] (môi trường
  ca không có compiler).
- **WP2 — BƯỚC 2 (NỐI DÂY LÚC LƯU) ĐÃ CHUẨN BỊ XONG (2026-11-09
  14:40 CST):** `wp2-prep/ReceiptViews.swift` (so với bản WP1 trên main:
  **+65 / −1** — dòng −1 duy nhất là dòng "Thuế" gộp được thay bằng
  khối hiển thị có điều kiện) + `wp2-prep/ScanView.swift` (so với
  build1: **+9 / −4**). `ReviewView.save()` nay ghi `stableID` (UUID),
  `sourceType` (camera/photoLibrary theo đúng đường vào, qua
  `ScanDraft`), `paymentMethod` (có thẻ → card, không → unknown,
  KHÔNG đoán cash), `transactionRef` (chỉ tách từ `SAMS-TC-`/`TC-`),
  `parserVersion = "build1-parser"`, và các `TaxLine` từ parser —
  nhưng CHỈ khi tổng thuế anh duyệt còn khớp Σ dòng thuế (kiểm trên
  đáp án Mẫu 002: 960+390=1350¢ ✓); `taxCents` đồng bộ ngược = Σ.
  `ReceiptDetailView` hiện từng dòng thuế riêng + tổng khi có dữ
  liệu, bản ghi cũ giữ nguyên hiển thị. Đủ 3 chữ ký nội bộ bước 2 —
  xem WP2-GATE.md mục "WP2 BƯỚC 2". **CHƯA đẩy code ở bất kỳ nhánh
  nào**; biên dịch [CHƯA KIỂM CHỨNG]. **WP2 ĐÃ TỚI CỔNG (cả 2
  bước):** còn lại kiểm di trú — chỉ làm được sau khi có build chứa
  model mới (workspace không có bản sao kho Build 1; phép kiểm tĩnh
  di trú nhẹ đã có). Nghiệm thu: anh duyệt đẩy → build cloud → cài
  đè lên máy đang có 2 tờ test Build 1 → 2 tờ còn nguyên, số không
  đổi. Cố ý chưa nối ở bước này: scheduleCLine lúc lưu (WP6/WP7),
  originalImageFileNames (WP3/WP8), reviewedAt/userEntered (WP6).
  **KẾT QUẢ SAU ĐÓ:** WP2 code ĐÃ ĐẨY MAIN 2026-11-09 15:52 CST
  (commit `d7497d8`, 4 file wp2-prep) — kiểm di trú gộp vào bài test
  mốc M1 theo luật mốc lớn, WP2 coi như qua cổng nội bộ.
- **WP3 — BƯỚC 1 (LÕI ĐƯỜNG PDF + NẠP TỪ FILES) ĐÃ CHUẨN BỊ XONG
  (2026-11-09 16:40 CST):** `wp3-prep/` 4 file trên nền WP2/main —
  `ScanView.swift` (**+168/−3**: nút Nạp file + `fileImporter` chọn
  NHIỀU file + hàng chờ lần lượt, trích lớp chữ PDFKit vào cùng
  parser confidence 1.0, PDF không lớp chữ → render trang 1 ~200dpi
  → OCR, file ảnh từ Files → OCR với `sourceType .fileImport`) +
  `Models.swift` (**+32/−0**: `ImageStore.saveFile` lưu PDF nguyên
  byte, `load` rẽ nhánh PDF render trang 1, thêm case
  `SourceType.fileImport` thuần cộng thêm) + `ReceiptViews.swift`
  (**+20/−7**: nhãn "Văn bản trong PDF" đóng F3 mục 3 ở Kiểm Lại +
  Chi Tiết; `save()` nối `sourceFileName`/`originalImageFileNames`)
  + `project.yml` (+7: CFBundleDocumentTypes PDF/ảnh, HandlerRank
  Alternate). **Kiểm chứng phía mình:** fixture PDF TỰ TẠO từ văn
  bản Mẫu 001 (`wp3-fixtures/`, SYNTHETIC — không phải PDF Sam's
  thật): trích xuất giữ 36/36 dòng, bài §F đạt **10/10** bằng bản
  port pattern Swift, PDF không lớp chữ cho 0 dòng → fallback đúng;
  kết quả ở `wp3-fixtures/verify-results.txt` + dòng mới trong
  SCORECARD.md. Đủ 3 chữ ký nội bộ BƯỚC 1 — văn bản: `WP3-GATE.md`.
  **CHƯA đẩy code**; biên dịch + PDFKit/fileImporter trên máy thật
  [CHƯA KIỂM CHỨNG] (gộp bài kiểm mốc M1). **WP3 chưa tới cổng:**
  còn bước 2 — đón Share Sheet/onOpenURL (CẢNH BÁO: không đẩy riêng
  project.yml bước 1 trước bước 2, tránh đường "Mở bằng" chết).

## Hàng việc (theo BUILD2-MASTER-PLAN, tuần tự tuyệt đối)
1. ~~**WP0** — Đóng băng bộ mẫu & bảng điểm~~ **ĐÃ XONG 2026-11-09 02:41 CST**:
   SCORECARD.md tồn tại (điểm nền Build 1 theo QA-VERDICT Phụ lục B §0.3) +
   QA ✓ ký nhận thứ tự WP1→WP9 trong `WP0-QA-SIGNOFF.md`. Không cần anh.
2. **WP1** — Cửa chẩn đoán F3 (xem văn bản OCR gốc): code ĐÃ chuẩn bị tới
   cổng 3 chữ ký nội bộ (2026-11-09 04:40, xem WP1-GATE.md + wp1-prep/);
   anh ĐÃ duyệt đẩy 10:43 CST + code ĐÃ lên main commit `769727698d`
   10:44 CST (kiểm chứng md5 ở mục Vị trí hiện tại). Còn lại: kết quả
   build cloud → anh cài + chụp màn hình (nghiệm thu trên máy — cần anh).
3. **WP2** — Hoàn thiện model dữ liệu: bước 1 (model) ĐÃ tới cổng
   2026-11-09 12:40 CST + bước 2 (nối dây lúc lưu + Chi Tiết hiện dòng
   thuế riêng) ĐÃ chuẩn bị xong 2026-11-09 14:40 CST (xem WP2-GATE.md
   cả 2 mục + wp2-prep/ đủ 4 file). **CODE ĐÃ ĐẨY MAIN 2026-11-09
   15:52 CST (commit d7497d8)** — theo luật mốc lớn, anh không cài/test
   riêng gói này; kiểm di trú gộp vào bài test Mốc M1.
4. ~~Chuẩn bị corpus: tải + kiểm chứng bộ WildReceipt/CORD/SROIE (làn lab),
   lập danh mục mẫu theo 7 loại hình (Master Plan §3.3)~~ **ĐÃ XONG phần
   không cần anh 2026-11-09 06:40 CST** (xem `corpus/CORPUS.md`): 3 bộ đã
   tải + kiểm chứng bằng byte/sha256/số dòng đo thật; danh mục 7 loại đã
   lập. Phần còn lại của corpus là gom hoá đơn THẬT của anh theo loại —
   diễn ra khi anh gửi file (PDF Sam's, Best Buy… đã ở điểm chờ), mỗi mẫu
   phải có đáp án chuẩn kiểm tay mới vào bộ.
5. **LÀN THIẾT KẾ UI — ĐÃ XONG vòng 1 (2026-11-09 16:00 CST):** thư mục
   `design/` đủ 3 sản phẩm: UI-STUDY.md (9 hệ tham chiếu, 10 nguyên tắc
   P1–P10, mọi khẳng định gắn nhãn đã-kiểm-chứng/suy-luận), DESIGN-
   SYSTEM.md (hệ "Sổ": màu dark-first, khối tổng kiểu sổ có dòng đối
   chiếu số học, nút CHỤP nổi 60pt, cảnh báo tách khỏi màu Business),
   MOCKUP-M1.html (4 màn, dữ liệu thật 001/002/003 — Wally đã kiểm:
   div 206/206, số $105.16/$216.80/TAX 1 8.517% khớp đáp án). Đầu vào
   WP9. **2 điểm chờ quyết:** (i) bỏ iOS 17, chỉ iOS 26+? — đã trình
   anh kèm đề xuất duyệt; (ii) nguyên tắc màu Personal bản sáng cho
   chữ nhỏ ở dark (đo tương phản thật ở WP9 mới khóa).
6. **WP3** — Đường PDF & nạp file (F1): **bước 1 (lõi PDF + nạp từ
   Files) ĐÃ chuẩn bị xong 2026-11-09 16:40 CST** (xem WP3-GATE.md +
   wp3-prep/ + wp3-fixtures/). **Bước tiếp theo (ca sau): WP3 bước 2**
   — đón Share Sheet/onOpenURL + xử lý Inbox dùng chung hàng chờ nạp,
   quyết nhãn OCR-từ-PDF, rà soát rồi chốt cổng WP3 (Wally duyệt +
   thẻ đẩy của anh; bài kiểm máy gộp mốc M1, KHÔNG xin anh test
   riêng). Sau WP3 mới tới WP4 (thi đấu engine) theo tuần tự.

## Điểm dừng chờ anh (ghi rõ, không tự vượt)
- ~~WP1: thẻ duyệt ĐẨY CODE lên main~~ ĐÃ XONG 2026-11-09 10:43–10:44 CST
  (anh duyệt trong chat app; commit main `769727698d`).
- ~~WP1 build cloud + nghiệm thu trên máy~~ ĐÃ XONG 2026-11-09 10:57 CST
  (anh cài + chụp màn hình Chi Tiết mở mục "Văn bản OCR gốc" — WP1 đóng).
- **WP2 CODE ĐÃ ĐẨY LÊN MAIN (2026-11-09 15:52 CST):** anh duyệt sau khi
  xem hồ sơ ("cần coi tận app mới biết ra sao") — commit **d7497d8**
  (4 file wp2-prep). Build cloud đang chạy; kết quả xanh/đỏ anh nhìn
  Actions khi tiện, KHÔNG cần cài/test ngay (luật mốc lớn bên dưới).
- **LUẬT MỐC LỚN (anh ban hành 2026-11-09 15:51 CST, chi tiết trong
  WORKFLOW-PROMPT-IOS.md mục Bổ sung):** anh chỉ test ở bước lớn —
  **M1 = WP2+WP3+WP4+WP5** (bản đọc được hoá đơn), **M2 = WP6..WP9**
  (Build 2 hoàn chỉnh). Nghiệm thu từng gói trên máy anh BỎ; cổng gói
  là nội bộ (3 chữ ký + Wally duyệt + build xanh + tự kiểm fixtures).
  Ca trực KHÔNG nhắn xin anh test từng gói nữa; chỉ nhắn khi tới mốc
  M1/M2, cần quyết định thật của anh, hoặc hỏng 2 ca liên tiếp. Sau build: anh cài đè lên máy đang
  có 2 tờ test Build 1 và mở app — 2 tờ còn nguyên, số không đổi =
  kiểm di trú đạt, WP2 đóng (chi tiết + quyết định thiết kế dòng thuế
  ở WP2-GATE.md mục "WP2 BƯỚC 2").
- Mọi lần ĐẨY CODE lên main khác (thẻ duyệt của hệ thống sẽ tới anh).
- WP3: file PDF Sam's (chưa có) — nghiệm thu trên PDF thật khác trước, ghi chờ.
- WP4: mẫu 002-C chụp camera thật + bản test engine iOS 26 cài trên máy anh.

## Luật ca trực
- **LUẬT LÀM VIỆC CHUNG (anh ban hành 2026-11-09 13:09 CST): đọc và áp dụng
  `WORKFLOW-PROMPT-IOS.md` (prompt 5 trạng thái đã lọc cho dự án này) —
  trong gói việc chạy vòng code → kiểm chứng trên bộ mẫu cố định → tự sửa
  LIỀN MẠCH không dừng chờ duyệt ở bước con; cổng chỉ ở cuối gói; lúc một
  gói chờ cổng thì chuẩn bị song song việc độc lập; trước cổng tự phản
  biện + tuyên bố trung thực 3 phần.**
- Mỗi ca làm ĐÚNG MỘT bước cụ thể, kiểm chứng, cập nhật file này, đẩy tài liệu
  lên nhánh docs/planning (commit nhỏ, thấy được trên GitHub).
- Chỉ nhắn anh khi: một gói tới cổng, cần anh test/quyết định, hoặc một việc
  hỏng 2 lần liên tiếp. Còn lại im lặng làm.
- Không hứa thời gian. Không code khi chưa tới gói của nó. Không đụng main.

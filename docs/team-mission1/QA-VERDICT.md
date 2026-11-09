# QA VERDICT — Mission 1: Audit Build 1 (đã đẩy, commit dba8693) + Chuẩn bị Build 2

Trưởng nhóm kiêm Giám sát độc lập — 2026-11-08 đêm (CST)
Tài liệu kèm: [DESIGN-AUDIT.md](DESIGN-AUDIT.md) (940 dòng) · [CODE-AUDIT.md](CODE-AUDIT.md) (1.193 dòng)

---

## TỜ KHAI TRUNG THỰC (honesty declaration)

**Cách kiểm chứng:** mọi kết luận dưới đây ghi rõ thuộc loại nào —
[ĐÃ KIỂM] = trưởng nhóm tự đọc/grep file code thật hoặc có bằng chứng máy thật của anh;
[BÁO CÁO] = chuyên viên báo cáo, trưởng nhóm chưa kiểm lại từng dòng (nêu rõ);
[SUY LUẬN] = inference, chưa chứng minh được.

**Sự thật nền (field facts, từ máy thật của anh 23:18–23:19 CST):** Build 1 build cloud
THÀNH CÔNG → cài được → quét file Sam's tải về (file số sắc nét, KHÔNG phải giấy nhiệt):
đọc đúng vendor / ngày 29/10/2026 5:49 PM / thẻ Mastercard •• 2586 / 15 món đã bán;
THẤT BẠI ở subtotal + thuế + tổng (trống) và tiền từng món. Kỷ luật parser ĐÚNG:
app gắn cờ cảnh báo, không bịa số, hoá đơn rơi vào Hộp Chờ.

---

## PHẦN 1 — ĐÃ KIỂM CHỨNG (trưởng nhóm tự kiểm với file thật)

### 1.1 Bốn sửa lỗi của Wally (bản nháp Build 1) — CODE-AUDIT §A, trưởng nhóm đồng kiểm
| # | Sửa | Kết quả kiểm |
|---|---|---|
| i | Parser `findDateTime`: Int?→Int + AM/PM | ✅ ĐÚNG — `Parser.swift:335–343`; bằng chứng máy thật: đọc đúng 5:49 PM |
| ii | `checkDuplicate`: bỏ #Predicate → fetch + lọc bộ nhớ | ✅ ĐÚNG — `ReceiptViews.swift:560–564`; grep: không còn `#Predicate` nào trong build1/ |
| iii | `applyCardChange`: cùng thay thế | ✅ ĐÚNG ở phần thay thế — `CardsView.swift:161–162` (logic xung quanh còn lỗi riêng, C-8) |
| iv | ScanView: chuẩn hoá hướng ảnh EXIF trước OCR | ⚠️ CÓ nhưng CHƯA TRỌN — `ScanView.swift:171–175`; renderer dùng scale mặc định của màn hình → có thể xin bitmap ~3× trên ảnh thư viện bị xoay (B-4) |

### 1.2 Ba phát hiện hiện trường F1–F3 (CODE-AUDIT §F) — tiền đề đã kiểm
- **F1 [ĐÃ KIỂM]:** grep toàn bộ build1/ = **0** hỗ trợ PDF (không PDFKit/PDFDocument);
  đường nạp duy nhất là PhotosPicker `matching: .images` (`ScanView.swift:121`).
  File Sam's tải về dạng PDF thì **không chọn được**; không có đường Files/Share nào.
- **F2 [ĐÃ KIỂM tiền đề]:** `ScanView.swift:181–190` ánh xạ observation→dòng theo tỉ lệ
  1:1, chỉ sắp theo maxY — không gộp hàng theo chồng lấn dọc, không sắp theo X;
  `Parser.swift` đòi nhãn+số tiền trên CÙNG một dòng (mẫu neo ^…$).
  [SUY LUẬN — chưa chứng minh] cơ chế Vision tách cột tiền trên ảnh cao/hẹp
  (hoặc hạ độ phân giải) — chưa chứng minh được vì thiếu F3.
- **F3 [ĐÃ KIỂM]:** chữ OCR gốc được LƯU (`Receipt.ocrRawText`, gán ở
  `ReceiptViews.swift:595`) và chỉ dùng để tìm kiếm (`ReceiptViews.swift:117`) —
  **không hiển thị ở bất kỳ màn nào**. Đây là lý do cơ chế F2 còn là suy luận.

### 1.3 Các MAJOR về dữ liệu/hành vi — trưởng nhóm tự đọc code, khớp từng điểm
- **B-2 [ĐÃ KIỂM]:** mọi `modelContext.save()` đều là `try?` mà UI báo "Đã lưu ✓" /
  đóng màn vô điều kiện (`ReceiptViews.swift` save() + saveChanges()) → có thể mất
  hoá đơn trong im lặng.
- **B-3 [ĐÃ KIỂM]:** mỗi dòng danh sách giải mã ảnh FULL SIZE đồng bộ trên main
  thread (`ReceiptRowView` gọi `ImageStore.load` = `UIImage(data:)` nguyên cỡ).
- **B-6 [ĐÃ KIỂM]:** xoá hoá đơn thì xoá ẢNH BẰNG CHỨNG trước, rồi mới xoá DB
  bằng `try?` — lưu DB hỏng là còn hoá đơn mà mất ảnh gốc cho sở thuế.
- **B-7 [ĐÃ KIỂM]:** quét bị huỷ / OCR rỗng để lại JPEG mồ côi vĩnh viễn
  (`ScanView.process` lưu ảnh trước; Review "Huỷ, không lưu" không xoá ảnh).
- **C-1 [ĐÃ KIỂM]:** nút "Duyệt" ở Chi Tiết nâng mọi hoá đơn lên chính thức
  vô điều kiện, không nhìn cờ kiểm tra (`receiptFlags`).
- **C-4 [ĐÃ KIỂM]:** luật toàn cục 2 vỡ ở cách dựng: đuôi thẻ và hãng thẻ gặt
  từ HAI dòng không liên quan; không đòi ngữ cảnh dòng thanh toán (bẫy số trần
  Home Depot tự nó không kích hoạt — phần đó an toàn).
- **C-6 [ĐÃ KIỂM một phần]:** tham số `save(ignoreDuplicate:)` không bao giờ
  được đọc trong thân hàm (grep + đọc thân hàm); khoá chống trùng yếu cho
  phần lớn tiệm; hộp thoại trùng luôn nói "cùng mã TC#" kể cả khi khoá là
  dạng yếu GEN|tiệm|ngày|tổng.
- **C-8 [ĐÃ KIỂM]:** đổi loại thẻ → viết lại MỌI hoá đơn của đuôi đó, kể cả
  tờ đã duyệt và tờ anh đã xếp tay khác đi, ghi đè luôn câu lý do.
- **C-10 [ĐÃ KIỂM]:** generic lấy TOTAL đầu tiên và mẫu neo ^TOTAL không bao
  giờ khớp "GRAND TOTAL" (luật Amazon bị ngược/thiếu).
- **C-12 [ĐÃ KIỂM — trưởng nhóm tự phát hiện TRƯỚC khi audit về]:** "Theo mục"
  ở Trang Chủ gộp theo tên mục, trộn tiền Cá nhân + Business dưới 1 huy hiệu.

### 1.4 Mẫu kiểm DESIGN-AUDIT (top-5, trích dẫn khớp từng dòng)
Thẻ 86×56 không bấm được (`CardsView.swift:95`) · số tiền lớn nhất bị nhuộm
màu loại trên nền mờ 0.12 (`HomeView.swift:138,141` — trái luật DESIGN-V2
"chữ chính trên nền đục") · sửa tiền trong ô 110pt (`ReceiptViews.swift:543`) ·
quét chỉ lấy trang 0 (`ScanView.swift:111`) · tab CHỤP là tabItem thường
(`ContentView.swift:99`) · onboarding: grep toàn build1/ = **0** kết quả.
Tổng 54 điểm kiểm của chuyên viên: đạt 20 / trần-thiếu 34 [BÁO CÁO — trưởng
nhóm kiểm mẫu các trích dẫn gánh nặng, không đếm lại cả 54].

---

## PHẦN 2 — CHƯA KIỂM CHỨNG (gắn nhãn, không dùng làm căn cứ cổng)
- Cơ chế Vision tách cột tiền / hạ độ phân giải trên ảnh cao-hẹp: [SUY LUẬN]
  (xem phụ lục 23:23 — bằng chứng hình học ủng hộ mạnh, vẫn là suy luận về
  cơ chế bên trong Vision; chỉ F3 mới chốt được).
- File Sam's tải về là PDF hay ảnh: **ĐÃ CHỐT ở phụ lục** (file JPG là fixture
  đường ảnh; kết luận PDF của F1 đứng độc lập vì Build 1 không có PDFKit và
  đường import PDF theo BLUEPRINT là yêu cầu đã chốt từ đầu).
- Các MINOR B-8…B-10, C-13…C-16 của CODE-AUDIT: [BÁO CÁO] — đã đọc, chưa
  đối chiếu từng dòng.
- Độ tương phản ở cỡ chữ AX5, một số mục DESIGN tự gắn UNVERIFIED: giữ nguyên
  nhãn đó.
- Hai điểm trưởng nhóm tự ghi nhận, chưa ai kiểm lại: **L-1** ReviewView lấy
  gợi ý thẻ ở `onAppear` từ `@Query` — lý thuyết có thể rỗng ở lần hiện đầu;
  **L-2** header tháng ở Danh Sách bỏ sót tổng "Chưa rõ". Cả hai MINOR.

---

## PHẦN 3 — DANH SÁCH VIỆC BUILD 2 (gộp 2 audit, xếp theo mức độ)

**TẦNG 0 — Chặn phát hành (từ §F, theo đúng thứ tự ưu tiên anh/Wally đã chốt):**
1. **F1 — Import PDF + trích lớp chữ (PDFKit)** + đường nạp Files/Share đa
   file; PDF đi thẳng vào parser, bỏ qua OCR. Kèm lưu file gốc làm bằng chứng.
2. **F2 — Ráp hàng OCR** (gộp observation theo chồng lấn dọc ≥50%, sắp theo X,
   nối 1 khoảng trắng, confidence = min) + **parser chịu được nhãn/dòng-tiền
   tách đôi** (máy trạng thái 1 dòng ân hạn, KHÔNG nới luật đối chiếu) +
   **cắt lát ảnh cao** (tỉ lệ > 3.0 → lát ~1600px, chồng 200px, khử trùng
   theo Y).
3. **F3 — Mục "Văn bản OCR gốc"** thu gọn được ở Review + Chi Tiết.
4. **Nghiệm thu §F trên fixture 002** (chi tiết ở phụ lục): 10 dòng món ·
   203.30 · 9.60 · 3.90 · 216.80 · 15 món · khoá TC# — bắt buộc đạt.

**TẦNG 1 — Niềm tin dữ liệu (MAJOR, làm cùng đợt Tier 0 nếu kịp):**
5. **B-2** lưu hỏng phải BÁO, không "Đã lưu ✓" giả; không đóng màn khi save lỗi.
6. **C-1 + C-2 + C-3** bịt 3 lỗ rò Hộp Chờ: nút Duyệt phải tôn trọng cờ;
   tổng Trang Chủ/Báo Cáo/Danh Sách tách rõ tiền "đang chờ" khỏi "chính
   thức"; chạy lại đối chiếu chéo trên SỐ ĐÃ SỬA lúc lưu.
7. **B-6** đổi thứ tự xoá (DB xong mới xoá ảnh) · **B-5** fetch lỗi không
   được giả vờ "rỗng" (kiểm trùng, xếp lại thẻ, nạp thẻ 2586) · **B-7** dọn
   JPEG mồ côi khi huỷ quét · **C-8** xếp lại theo thẻ chỉ áp cho hoá đơn
   chưa duyệt / chưa xếp tay, có báo số lượng trước khi làm.

**TẦNG 2 — Đúng luật BLUEPRINT/VENDOR-FORMATS (MAJOR):**
8. **C-4** gặt thẻ phải có ngữ cảnh dòng thanh toán · **C-5** vùng loại trừ
   phải là VÙNG thật (Suggested Tip, Return Policy, MAX REFUND) và áp cho
   ngày/thẻ nữa · **C-6** khoá chống trùng theo tiệm (Amazon Order ID,
   Lowe's SALES#+TRANS#, Love's Ticket#…), hộp thoại trùng nói đúng loại
   khoá, dùng thật tham số ignoreDuplicate, khoá dựng từ số ĐÃ SỬA ·
   **C-9** thêm trường totalPrinted/tipAmount cho nhà hàng · **C-10** GRAND
   TOTAL + luật Amazon nhiều kiện · **C-11** kỷ luật độ tin cậy áp cho cả
   tiệm/ngày (vendor rỗng không được thành "chính thức") · **C-7** đổi loại
   ở Chi Tiết phải sửa mục theo · **C-17 (mới, MINOR)** quét thêm dòng kề/
   dòng TEND tìm chữ DEBIT cho hãng thẻ.

**TẦNG 3 — Hiệu năng & thiết kế gánh nặng (từ DESIGN-AUDIT §4):**
9. **B-3** thumbnail hạ cỡ bằng ImageIO, không giải mã full-size trong dòng
   danh sách · **B-4** ghim `format.scale = 1` cho renderer EXIF.
10. **Quét không chặn người dùng** (vào sổ ngay "Đang đọc…", xử lý nền — nền
    cho Chụp Một Đống) · **thẻ bấm được** → màn hoá đơn của thẻ + tổng năm ·
    **số tiền về chữ chính trên nền đục** ở ô tổng năm + running total (kèm
    sửa C-12) · **sửa tiền bằng bàn phím hero** + hiện độ tin cậy TỪNG trường
    kèm tô vàng tại chỗ.

**TẦNG 4 — Theo spec thiết kế Build 2 (DESIGN-AUDIT §4):**
11. Tab bar tự vẽ, nút CHỤP giữa 56pt · thẻ vật lý tỉ lệ 1.586 xếp chồng ·
    onboarding 3 bước làm-thật (chào 1 câu → xác nhận thẻ 2586 → chụp tờ
    đầu) · trạng thái rỗng/đang tải/lỗi có thiết kế + câu chữ tiếng Việt
    đúng spec từng màn · sửa L-2 (header tháng có tổng Chưa rõ) và B-9
    (hiện ghi chú fail-open ở màn khoá).
MINOR còn lại: B-8…B-10, C-13…C-16, L-1 — xếp lịch sau Tier 0–2.

---

## PHẦN 4 — PHÁN QUYẾT CỔNG CHO BUILD 1 (ký)

**Build 1: NỀN TẢNG ✓ — DÙNG HẰNG NGÀY ✗.**

- Đạt, có bằng chứng máy thật: chuỗi build→ký→cài→chạy (giữ từ Test 0);
  khoá Face ID fail-open; gợi ý phân loại theo thẻ kèm lý do; kỷ luật "gắn
  cờ, không bịa số" (cả 2 lần test thực địa đều kích hoạt đúng); 4 sửa lỗi
  bản nháp đều đúng, 1 sửa (AM/PM) đã chứng minh ngay trên hoá đơn thật.
- Chưa đạt: không đọc được TIỀN từ nguồn hoá đơn chính của anh (file Sam's
  tải về); cổng Hộp Chờ rò 3 đường (C-1/C-2/C-3); một lỗi mất dữ liệu im
  lặng đang mở (B-2). Build 1 giữ vai trò **bản nền + công cụ chẩn đoán**,
  KHÔNG phải sổ hoá đơn dùng thật, cho tới khi Build 2 qua được nghiệm thu
  §F và bịt Tier 1.
- Chữ ký cổng theo TEAM.md: **Design ✗** (spec Build 2 đã sẵn) · **Code ✗
  về hành vi / ✓ về biên dịch** · **QA ✗ cho phát hành, ✓ cho nền tảng**.
  Build 2 chỉ được đẩy GitHub khi đủ 3 chữ ký theo đúng quy trình mới.
- Ghi chú quy trình (nói thẳng): Build 1 được đẩy TRƯỚC khi đội tồn tại
  (anh ra lệnh lập đội 23:13, lần đẩy là ~23:10) — không truy cứu ngược;
  cổng áp dụng từ Build 2 trở đi.

— Trưởng nhóm / Giám sát độc lập, Mission 1.

---

## PHỤ LỤC A — 23:23 CST: FIXTURE 002 ĐÃ VỀ (trưởng nhóm tự kiểm)

Fixture `samples/sample-002-sams-downloaded-receipt.jpg` (đo lại: 554×1457
px) + ground-truth. Mọi ghi chú "fixture PENDING" trong verdict này nay đọc
là ĐÃ CÓ FIXTURE.
1. Số học [tính lại]: 38.96+19.48+17.28+21.40+27.96+26.98+39.96+17.78
   −4.50−2.00 = **203.30** ✓ · +9.60+3.90 = **216.80** ✓ · Σ lượng = **15** ✓.
2. Hình học ↔ pass/fail [ĐÃ KIỂM]: mọi trường hỏng đều là "nhãn + tiền cột
   phải xa"; mọi trường đúng đều là dòng 1 cục. Suy luận Vision tách cột:
   bằng chứng ủng hộ MẠNH, vẫn là [SUY LUẬN] về cơ chế trong Vision.
3. Luật parser đủ nếu dòng được ráp [trace tay]: kể cả bẫy INST SV kèm dòng
   lượng ("INST SV 12 OZ BOWL" → "2 AT 1 FOR 2.25- 4.50-T" → −4.50 đúng qua
   đường pending+qty hiện có). Lỗi nằm ở tầng OCR, không ở luật bóc tách.
4. Brand thiếu "Debit" [sửa lại cơ chế]: findCard quét MỌI dòng, lấy dòng
   đầu tiên có tên hãng, chỉ cộng " Debit" khi chính dòng đó chứa DEBIT —
   không phải "chỉ nhìn dòng thẻ che". Lý do OCR-thật: [CHƯA KIỂM CHỨNG]
   (thiếu F3). Fix ứng viên: quét thêm dòng kề dòng thẻ che / dòng TEND —
   ghi **C-17 (MINOR)**.
5. Đường camera [CHƯA KIỂM CHỨNG]: anh test qua PhotosPicker; chụp bằng
   camera trong app chưa test thực địa.

---

## PHỤ LỤC B — FIELD TEST 2 (23:23 CST): HOÁ ĐƠN GIẤY THẬT, THỨ TỰ BUILD 2 ĐỔI

Bằng chứng: fixture `samples/sample-003-ground-truth.md` (+ ảnh crop bằng
chứng). Home Depot GIẤY nhàu, chụp thường. Số chuẩn [trưởng nhóm tính lại]:
6.98+19.97+69.96 = **96.91** ✓ · +8.25 = **105.16** ✓.
Build 1: ngày/giờ ✓ · thẻ Visa ••3830 ✓ · gợi ý thẻ lạ ✓ · cảnh báo thiếu
tổng ✓ · needsReview ✓ — NHƯNG tên tiệm thành **"How doers"** (slogan) và
subtotal/thuế/tổng trống rỗng. Nhận định của anh, nguyên văn: *"Chất lượng
scan dữ liệu rất tệ" / "Thua các app chính thức rất nhiều"* — đội ghi nhận:
anh đúng trên bằng chứng. **Chất lượng đọc là vấn đề trung tâm của Build 2,
trên mọi polish.**

**Lỗi vendor [ĐÃ KIỂM tận code]:** `Parser.swift:219` chỉ quét
`lines.prefix(6)` tìm tiệm đã biết; `:229–231` rơi về DÒNG ĐẦU TIÊN (tối đa
40 ký tự) — slogan đứng đầu hoá đơn nên thắng. Độ tin cậy của lần đoán này
có ghi (≤0.5) nhưng KHÔNG được thực thi ở đâu (C-11): không cảnh báo, không
ép needsReview vì riêng nó. Ghi **C-18 (MAJOR)**: quét TOÀN BỘ dòng + khớp
mờ cho tiệm đã biết; cấm lấy dòng đầu/slogan làm tên tiệm mà không gắn cờ
tin cậy thấp + ép Hộp Chờ.

### THỨ TỰ BUILD 2 MỚI (phụ lục này THAY thứ tự ở Phần 3)

**TẦNG 0 — CHẤT LƯỢNG ĐỌC (trung tâm, trước mọi thứ khác):**
0.1 **ĐÁNH GIÁ ENGINE — spec bắt buộc, không vá mẫu:** hai ứng viên chấm
    trên CÙNG bộ mẫu cố định (mục 0.3):
    (a) Vision cổ điển + TIỀN XỬ LÝ ẢNH (cắt theo viền hoá đơn, nắn
    perspective/thẳng hoá, tăng tương phản + phóng nét) + ráp hàng (F2);
    (b) **RecognizeDocumentsRequest của iOS 26** (OCR hiểu bố cục) — qua
    MỘT BẢN TEST PIPELINE RIÊNG kiểu Test 0 trên iOS 27 của anh, vì đổi
    SDK/deployment-target tự nó là rủi ro phải cô lập, không gộp vào bản
    tính năng. **Luật chọn: engine nào điểm cao hơn trên bộ mẫu thì thắng;
    thua thì bỏ, không lai ghép mập mờ.**
0.2 **F1 — PDF lớp chữ** (nguồn số hoàn hảo — giữ nguyên ưu tiên cao, nó là
    đường tắt qua mặt cả vấn đề OCR cho hoá đơn tải về).
0.3 **BẢNG ĐIỂM CỔNG (SCORECARD — vĩnh viễn):** mẫu 001 (số) · 002 (Sam's
    tải về) · 003 (Home Depot giấy nhàu). Mỗi mẫu chấm: tiệm / ngày / tổng /
    món. **Build 2 chỉ qua cổng khi: tổng + ngày ĐÚNG trên cả 3 mẫu, và
    không một con số sai nào được trình bày mà không gắn cờ.** Điểm Build 1
    để đối chiếu: 002 — tiệm ✓ ngày ✓ tổng ✗(có cờ) món ✗ · 003 — tiệm ✗
    (KHÔNG cờ — vi phạm tinh thần cổng) ngày ✓ tổng ✗(có cờ) món ✗.
0.4 **F3 — xem OCR gốc** (điều kiện để chấm và chẩn đoán 0.1) · **C-18**
    sửa vendor như trên.
Sau Tầng 0 này, thứ tự cũ giữ nguyên: Tầng 1 (niềm tin dữ liệu: B-2,
C-1/C-2/C-3, B-5/B-6/B-7, C-8) → Tầng 2 (đúng luật: C-4…C-11, C-17) →
Tầng 3–4 (hiệu năng + thiết kế theo DESIGN-AUDIT §4). Mọi polish lùi sau
chất lượng đọc — theo đúng phán quyết thực địa của anh.

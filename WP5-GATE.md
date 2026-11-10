# WP5 — NHẬN DIỆN TIỆM & KỶ LUẬT ĐỘ TIN CẬY: BƯỚC 1 + BƯỚC 2 CHUẨN BỊ (CHƯA tới cổng gói)
**Gói:** WP5 theo BUILD2-MASTER-PLAN §2 (WP5); đặc tả: `WP5-SPEC.md`.
**Ngày chuẩn bị:** 2026-11-10 02:40 CST (ca trực sohoadon-build2-247).
**Trạng thái:** Bước 1 của WP5 — ĐẶC TẢ + PORT KIỂM CHỨNG THUẬT TOÁN —
đã chuẩn bị. Đây là việc độc lập làm song song trong lúc WP4 chờ thi
đấu ở mốc M1 (đúng gợi ý bước tiếp theo trong WORK-STATE). **Chưa có
dòng Swift nào của WP5; chưa đẩy code ở bất kỳ nhánh nào.** WP5 CHƯA
tới cổng gói: còn bước 2 (code Swift trong Parser) và bước 3 (nối dây
save() + hiển thị gợi ý + chạy lại SCORECARD + ký cổng gói).

## Việc đã làm — đúng MỘT bước: đặc tả WP5 + port kiểm chứng
- **`WP5-SPEC.md`** (mới): khoá cách làm trước khi code — hiện trạng đo
  từ code Build 1 (prefix(6), đường rơi dòng-đầu sinh "How doers",
  validate() chỉ thực thi cho total), bất biến "tên tiệm chỉ từ bằng
  chứng", 3 nấc (khớp toàn-bộ-dòng exact-trước-mờ-sau với luật token
  chống dương tính giả · neo phụ mạnh/yếu với bảng seed CHỈ gồm neo có
  bằng chứng mẫu · món đặc trưng chỉ-gợi-ý với bảng seed RỖNG), kỷ luật
  C-11 mở rộng validate() cho tiệm + ngày theo đúng mẫu ngưỡng sẵn có,
  và chia 3 bước. Ghi rõ: WP5 không cần thay đổi model (ParseResult
  cộng thêm + trường WP2 đã có sẵn) — không có rủi ro di trú.
- **`wp5-fixtures/vendor_port.py`**: port Python trung thực của thuật
  toán trong đặc tả (chuẩn hoá, Levenshtein token, neo mạnh/yếu, nấc 3,
  hàm thực thi C-11) — là bản mẫu hành vi cho bước code Swift đối chiếu.

## Kiểm chứng đã chạy (bằng chứng file)
- `wp5-fixtures/verify_vendor.py` → **19/19 PASS**, đầy đủ ở
  `wp5-fixtures/verify-vendor-results.txt`:
  - **V1 (fixture THẬT duy nhất, không phải điểm cổng):** toàn bộ văn
    bản OCR thật của Mẫu 003 (`samples/sample-003-ocr-raw.txt`) →
    nấc 1 trượt (đúng chẩn đoán: tên tiệm vắng mặt) → nấc 2 neo địa chỉ
    ra "The Home Depot" với confidence bị cap 0.5 + đúng 1 cảnh báo.
    Đây là kết quả cổng gói yêu cầu ở dạng "ra đúng tên" — kèm cờ.
  - V2: 3 biến thể Sam's (apostrophe thẳng/cong/thiếu) → khớp-đúng.
  - V3: khớp-mờ 1 ký tự "HOME DEP0T" → ra tiệm + cờ khớp-mờ.
  - V4 (đối chứng âm, khoá lỗi Build 1): chỉ slogan "How doers" +
    không neo → tên TRỐNG + cảnh báo (Build 1 trả "How doers").
  - V5: tiệm lạ → trống, không lấy dòng đầu. V6/V6b: nấc 3 với bảng
    tiêm-kiểm chỉ gợi ý, không điền; seed rỗng → không gợi ý bịa.
  - V7: ZIP 74133 đứng một mình KHÔNG đủ neo → trống (chống neo yếu
    sinh tên sai). V8: neo điện thoại Sam's Tulsa (bằng chứng Mẫu 001)
    → Sam's Club qua nấc 2.
  - V9: "WALMART" ở dòng 9 (ngoài prefix(6)) → thấy. V10: khớp-đúng ở
    dòng muộn thắng khớp-mờ ở dòng sớm. V11: "TARGETED" không thành
    Target (luật token cho từ phổ thông).
  - V12 (4 ca): hàm C-11 — tiệm trống → cảnh báo; tiệm/ngày tin cậy
    thấp → cảnh báo THẤP; cả hai chắc → không cảnh báo.

## Tuyên bố trung thực 3 phần — BƯỚC 1
- **Đã chứng minh:** thuật toán 3 nấc + C-11 (bản port) cho kết quả
  đúng đặc tả trên 19/19 fixture, trong đó có văn bản OCR THẬT của
  Mẫu 003 ra đúng tên tiệm đích kèm cờ — đường đi tới bằng chứng ra
  cổng của gói tồn tại và đo được ở tầng thuật toán; đường rơi dòng-đầu
  (nguồn lỗi "How doers") bị loại về mặt cấu trúc trong đặc tả + port.
- **Chưa chứng minh:** (1) code Swift [CHƯA LÀM — bước 2]; (2) điểm
  cổng thật trên máy (OCR engine thắng cuộc của WP4 cấp dòng + độ tin
  cậy thật — gộp mốc M1); (3) ngưỡng 0.60/0.85 và hệ số mờ 0.8 cho
  tiệm/ngày là khởi điểm mượn từ luật total hiện hành, CHƯA hiệu chuẩn
  trên corpus của anh; (4) trích địa chỉ/điện thoại nguyên văn (mục 4
  của đặc tả) mới khoá nguyên tắc, regex + fixture thuộc bước 2.
- **Chưa làm (cố ý, đúng chia bước):** bước 2 code Swift + bước 3 nối
  dây/hiển thị/cổng gói; bảng neo chưa có tiệm nào ngoài 2 neo có bằng
  chứng mẫu; bảng món đặc trưng giữ RỖNG cho tới khi có hoá đơn thật
  của anh đã duyệt làm căn cứ.

## Chữ ký nội bộ — BƯỚC 1
- Design ✓ — bước này không đổi giao diện; đặc tả giữ nguyên tắc hiển
  thị gợi ý/cảnh báo bằng cơ chế warnings sẵn có, không che số tiền.
- Code ✓ — đặc tả thuần xử lý chuỗi trong parser, không framework mới,
  không đổi model/dữ liệu (TEAM.md #1); các đường trượt đều trả
  vendor = nil tường minh trong port (TEAM.md #2).
- QA ✓ — fixture có ca thật (V1), đối chứng âm (V4/V7/V11) và ca khoá
  hành vi seed-rỗng (V6b); kết luận ghi đúng phạm vi thuật toán, không
  tính là điểm cổng (TEAM.md #4).

---

## BƯỚC 2 — CODE SWIFT (2026-11-10 04:40 CST, ca trực sohoadon-build2-247)

**Trạng thái:** Bước 2 xong — code Swift đã viết ở `wp5-prep/Parser.swift`.
WP5 CHƯA tới cổng gói: còn bước 3 (nối dây save() + hiển thị gợi ý +
chạy lại SCORECARD + ký cổng gói). **Chưa đẩy code ở bất kỳ nhánh nào.**

### Việc đã làm — đúng MỘT bước: code Swift theo WP5-SPEC
- **`wp5-prep/Parser.swift`** (nền `wp4-prep/Parser.swift`; diff
  **+323/−50**): `identifyVendor` 3 nấc dịch trung thực
  `vendor_port.py` (chuẩn hoá, Levenshtein token, luật token chống
  dương tính giả, neo mạnh/yếu, seed neo đúng 2 tiệm có bằng chứng,
  nấc 3 seed RỖNG) chạy TRƯỚC rẽ nhánh và là nguồn tên tiệm duy nhất;
  `ParseResult` cộng thêm 6 trường (vendorAddress/vendorPhone/
  storeNumber/vendorSource/vendorSuggestion/vendorAnchorDisputed);
  `extractVendorContact` trích nguyên văn địa chỉ/điện thoại/mã cửa
  hàng (regex chốt ở bước này, kèm port riêng); `validate()` THÊM
  khối C-11 cho tiệm/ngày (cờ khớp-mờ/neo, 2 mức ngưỡng 0.60/0.85,
  tiệm trống, tranh chấp neo, ngày tin cậy thấp).
- **50 dòng xoá đã kiểm từng dòng:** đúng và CHỈ gồm `isSams` (hàm +
  điểm gọi), khối đặt tên/confidence cũ trong parseSams, và khối
  vendor cũ của parseGeneric GỒM ĐƯỜNG RƠI DÒNG-ĐẦU — đường rơi biến
  mất về mặt cấu trúc, không phải bị chặn bằng danh sách slogan.
  Phần số học của validate() và toàn bộ logic tổng/món/thẻ: diff
  không có dòng xoá/sửa nào (đúng luật đặc tả mục 2.5).
- **Đổi tên chuẩn (ghi rõ):** generic trước đây trả "Home Depot";
  nay theo port + đáp án chuẩn là **"The Home Depot"**. dedupeKey
  generic (tiệm|ngày|tổng) vì thế đổi theo trên tờ Home Depot —
  hành vi đúng ý đặc tả, ghi lại để bước 3/M1 không ngạc nhiên.

### Kiểm chứng đã chạy (bằng chứng file)
- Port nhận diện (bước 1, không đổi): **19/19 PASS** (chạy lại ca này).
- Port trích xuất MỚI `wp5-fixtures/extract_port.py` +
  `verify_extract.py` → **7/7 PASS** (`verify-extract-results.txt`):
  E1 trên văn bản OCR THẬT Mẫu 003 — địa chỉ trích nguyên văn đúng
  "9808 E 71ST ST TULSA OK 74133", KHÔNG vớ điện thoại giả từ các dãy
  số dài (903 00052 53026 / AUTH CODE), KHÔNG vớ mã cửa hàng giả;
  E2/E3 biến thể 918-252-9503 / (918) 252-9503 / STORE #4628 / ST# 567;
  E4 đối chứng âm TC#/ngày/auth-code đều trống; E5 địa chỉ AVE + phẩy.
- Hồi quy parser ở tầng port: F2b **10/10**, rowmerge **9/9** (chạy lại).
- Kiểm tĩnh Swift: cân bằng ngoặc 233/233 · 445/445 · 147/147;
  grep xác nhận `prefix(6)` và đường-rơi dòng-đầu chỉ còn trong
  comment giải thích; mọi caller ngoài (ScanView các bản prep) chỉ
  gọi `ReceiptParser.parse(lines:)` — chữ ký không đổi, parseGeneric/
  isSams là private.

### Tuyên bố trung thực 3 phần — BƯỚC 2
- **Đã chứng minh:** code Swift bám đúng port đã kiểm chứng ở cả hai
  phần (nhận diện 19/19 giữ nguyên vì port không đổi; trích xuất 7/7
  gồm ca thật Mẫu 003 + đối chứng âm); diff thuần theo đặc tả — phần
  bị xoá đúng danh sách chủ đích, không đụng số học; trên bộ mẫu,
  Mẫu 003 nay có đường ra "The Home Depot" + cờ (nấc 2) thay cho
  "How doers" không cờ, Mẫu 002 giữ Sam's qua nấc 1 (điểm cổng không
  thụt ở tầng thuật toán + trích xuất).
- **Chưa chứng minh:** (1) BIÊN DỊCH Swift [chưa kiểm chứng — môi
  trường ca không có compiler, như mọi gói trước; build cloud là
  phép kiểm khi Wally trình cổng]; (2) hành vi thật của
  NSRegularExpression với lookbehind `(?<!\d)` trong mẫu điện thoại
  trên iOS (ICU hỗ trợ lookbehind — khẳng định ở mức tài liệu, chưa
  chạy máy); (3) điểm cổng trên máy với engine thắng cuộc WP4 — gộp
  mốc M1; (4) ngưỡng 0.60/0.85 + hệ số mờ 0.8 vẫn là khởi điểm chưa
  hiệu chuẩn (hiệu chuẩn ở bài chấm M1).
- **Chưa làm (đúng chia bước):** bước 3 — save() nối vendorAddress/
  vendorPhone/storeNumber vào model WP2, Kiểm Lại hiển thị gợi ý
  nấc 3 + nguồn tiệm, chạy lại SCORECARD, ký cổng gói, trình Wally
  ở chat chính. WP5 thuộc mốc M1 — không xin anh test riêng.

### Chữ ký nội bộ — BƯỚC 2
- Design ✓ — bước này không đổi giao diện; cảnh báo đi qua cơ chế
  warnings sẵn có (bước 3 mới nối hiển thị gợi ý/nguồn).
- Code ✓ — rà kiểu/optional: trường cộng thêm đều optional tường
  minh có mặc định (TEAM.md #2); không framework mới, không chạm lúc
  khởi động (TEAM.md #1); chữ ký parse() giữ nguyên cho mọi caller.
- QA ✓ — fixture có ca thật (E1/V1), đối chứng âm (E4, V4/V7/V11) và
  kiểm từng dòng xoá của diff; kết luận ghi đúng phạm vi tầng
  port + kiểm tĩnh, không tính là điểm cổng (TEAM.md #4).

---

## BƯỚC 3 — NỐI DÂY + CHỐT CỔNG GÓI (2026-11-10 06:40 CST, ca trực sohoadon-build2-247)

**Trạng thái: WP5 ĐÃ TỚI CỔNG GÓI** (cổng nội bộ theo luật mốc lớn:
3 chữ ký + tự kiểm fixtures). Chưa đẩy code ở bất kỳ nhánh nào — chờ
Wally trình anh duyệt thẻ đẩy ở chat chính, gộp cùng nhịp mốc M1
(WP4 vẫn chờ thi đấu trên máy; WP5 không xin anh cài/test riêng).

### Việc đã làm — đúng MỘT bước: nối dây + hiển thị + SCORECARD
- **`wp5-prep/ReceiptViews.swift`** (MỚI trong wp5-prep; nền
  `wp3-prep/ReceiptViews.swift` — bản WP3 đã lên main commit ec73f92;
  diff **+68/−0, thuần cộng thêm, 0 dòng sửa/xoá**):
  1. `ReviewView.save()` nối hạ cánh WP2: `vendorAddress`
     (= ParseResult.vendorAddress ?? "" — model là String không
     optional), `vendorPhone`, `storeNumber`. Ba trường là bằng chứng
     trích nguyên văn từ giấy, KHÔNG suy từ tên tiệm anh sửa tay.
  2. Kiểm Lại (Section "Thông tin đọc được", dưới các số tiền, nhãn
     caption không che số): nhãn nguồn tiệm qua helper file-level
     `vendorSourceText` (tier1-exact/fuzzy/tier2-anchor → chữ; lạ →
     nil không hiện); gợi ý nấc 3 chỉ hiện khi vendor == nil kèm chữ
     "chưa tự điền" (cảnh báo tương ứng đã có sẵn trong warnings từ
     validate() — không thêm đường điền nào); địa chỉ/điện thoại/mã
     cửa hàng đọc được hiện dạng LabeledContent để anh đối chiếu.
  3. Chi Tiết ("Thông tin"): hiện Địa chỉ tiệm/Điện thoại tiệm/Mã cửa
     hàng ĐÃ LƯU khi có dữ liệu — bề mặt để M1 kiểm chứng việc nối dây
     trên máy; bản ghi cũ để trống → hiển thị không đổi.
- **SCORECARD.md**: thêm dòng chấm lại 2026-11-10 (bước 2+3) — ghi rõ
  tầng port/kiểm tĩnh, KHÔNG tính là điểm cổng trên máy.

### Kiểm chứng đã chạy (bằng chứng file)
- Chạy lại toàn bộ tầng port sau bước 3: nhận diện **19/19**, trích
  xuất **7/7**, hồi quy F2b **10/10**, rowmerge **9/9** (kết quả ở các
  file verify-*-results.txt tương ứng; port không đổi ở bước 3 nên
  đây là kiểm hồi quy, không phải bằng chứng mới về thuật toán).
- Diff ReceiptViews: +68/−0 đã kiểm (mọi dòng thêm đều thuộc 3 mục
  trên); cân bằng ngoặc 195/195 · 496/496 · 16/16; grep: helper
  `vendorSourceText` định nghĩa 1 lần, dùng 1 lần; 3 trường model
  khớp kiểu với wp3-prep/Models.swift (String / String? / String?).
- Bất biến cổng của gói (đối chiếu WP5-SPEC mục 6): trên bộ mẫu ở
  tầng port không còn đường tên-tiệm-sai-không-cờ — nấc 1-mờ có cờ,
  nấc 2 có cờ + cap 0.5, nấc 3 không điền (seed rỗng), còn lại trống
  + cảnh báo; Mẫu 003 đạt dạng ra cổng yêu cầu ("The Home Depot" +
  cờ), Mẫu 002 giữ tiệm ✓.

### Điểm mở trình Wally khi qua cổng (không tự quyết ở ca trực)
- `currentParserVersion` trong ReceiptViews vẫn là "build1-parser"
  trong khi Parser đã đổi ở WP4+WP5 — comment tại hằng này ghi WP4
  thắng/thua xong thì cập nhật cùng lúc thay engine. Ca trực KHÔNG tự
  đổi nhãn phiên bản ở bước 3; Wally chốt nhãn khi trình đẩy (đổi
  nhãn là thay đổi ghi vào mọi bản ghi mới, thuộc quyết cổng).

### Tuyên bố trung thực 3 phần — TOÀN GÓI WP5
- **Đã chứng minh:** ở tầng thuật toán + kiểm tĩnh: nhận diện 3 nấc
  đúng đặc tả (port 19/19 gồm ca THẬT Mẫu 003 → "The Home Depot" +
  cờ; đối chứng âm slogan/ZIP-đơn/"TARGETED" đều không sinh tên sai
  không cờ); trích xuất nguyên văn 7/7 gồm ca thật + đối chứng âm;
  code Swift dịch trung thực port (diff bước 2 đã kiểm từng dòng
  xoá; bước 3 diff +68/−0); hồi quy parser không thụt (10/10 + 9/9);
  save() đã nối đủ 3 trường hạ cánh WP2 và hiển thị gợi ý/nguồn đi
  qua cơ chế warnings sẵn có.
- **Chưa chứng minh:** (1) BIÊN DỊCH Swift của cả wp4-prep + wp5-prep
  [môi trường ca không có compiler — build cloud khi Wally trình
  cổng là phép kiểm]; (2) hành vi NSRegularExpression lookbehind
  trong mẫu điện thoại trên iOS thật; (3) điểm cổng TRÊN MÁY với
  engine thắng cuộc của WP4 (dòng OCR + confidence thật) — gộp mốc
  M1; (4) ngưỡng 0.60/0.85 và hệ số mờ 0.8 chưa hiệu chuẩn trên
  corpus của anh (hiệu chuẩn ở bài chấm M1); (5) kiểm di trú: WP5
  không đổi model nên không phát sinh rủi ro di trú mới — nhưng bản
  build M1 chứa model WP2 vẫn phải qua bài kiểm cài-đè của mốc.
- **Chưa làm (cố ý, ngoài phạm vi gói):** đẩy code lên main (chờ
  Wally trình thẻ duyệt); đổi nhãn parserVersion (điểm mở ở trên);
  thêm neo/món đặc trưng mới vào seed (chỉ khi có hoá đơn thật của
  anh đã duyệt); thi đấu engine WP4 + mẫu 002-C (thuộc mốc M1).

### Chữ ký nội bộ — CỔNG GÓI WP5
- Design ✓ — hiển thị mới toàn là nhãn caption/LabeledContent dưới
  số tiền, không che số (nguyên tắc đội thiết kế); trạng thái gợi ý
  dùng đúng màu cảnh báo sẵn có; Chi Tiết chỉ thêm dòng khi có dữ
  liệu, bản ghi cũ không đổi mặt.
- Code ✓ — diff thuần cộng thêm ở cả 2 file của gói (Parser bước 2
  +323/−50 đã kiểm từng dòng xoá; ReceiptViews bước 3 +68/−0); rà
  kiểu/optional: String↔String? ở 3 trường nối dây khớp model
  (TEAM.md #2); không framework mới, không chạm lúc khởi động
  (TEAM.md #1); chữ ký parse()/save() không đổi cho caller.
- QA ✓ — bộ mẫu đóng băng chạy lại đủ 4 bài (19/19 · 7/7 · 10/10 ·
  9/9); ca thật + đối chứng âm có đủ; kết luận ghi đúng tầng bằng
  chứng (port + kiểm tĩnh), điểm cổng máy để M1, không tính gộp
  (TEAM.md #4).

**WP5 TỚI CỔNG — trình Wally ở chat chính để duyệt đẩy cùng nhịp M1.**

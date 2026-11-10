# WP4 — THI ĐẤU ENGINE ĐỌC ẢNH: BƯỚC 1 CHUẨN BỊ (CHƯA tới cổng gói)
**Gói:** WP4 theo BUILD2-MASTER-PLAN §2 (WP4) + §5.1 + §5.6; đặc tả đo:
`WP4-SPEC.md`. Đặc tả code: CODE-AUDIT F2a/F2c.
**Ngày chuẩn bị:** 2026-11-09 20:40 CST (ca trực sohoadon-build2-247).
**Trạng thái:** Bước 1 của WP4 — ĐẶC TẢ ĐO + TẦNG TẠO DÒNG của ứng viên
(a) — đã chuẩn bị ở `wp4-prep/ScanView.swift` (1 file, thay 1-1 cho bản
WP3 trên main). **Chưa đẩy code ở bất kỳ nhánh nào** (đúng luật ca
trực). WP4 CHƯA tới cổng gói: còn bước 2 (tiền xử lý phái sinh + F2b
phía parser) và bước 3 (bản test engine (b) iOS 26 + chạy thi đấu trên
bộ mẫu + QA ký chọn engine). Theo LUẬT MỐC LỚN, anh không cài/test
riêng gói này; bài kiểm trên máy gộp vào mốc M1.

## Tiền đề đầu ca (đã kiểm chứng bằng file)
- WP3 code ĐÃ ĐẨY MAIN bởi Wally: commit `ec73f92` (5 file wp3-prep) —
  ghi ở đầu WORK-STATE.md, cập nhật 2026-11-09 18:52 CST. WP4 xây trên
  nền wp3-prep (= bản main hiện tại), không xây trên build1.

## Việc đã làm — đúng MỘT bước: đặc tả đo + F2a/F2c cho ứng viên (a)
- **`WP4-SPEC.md`** (mới): khoá cách đo trước khi đo — 2 ứng viên × 2
  cấu hình (ảnh gốc / ảnh phái sinh, §5.1), bộ mẫu cổng 001/002/003
  (+002-C khi có), làn lab chỉ đo độ bền, hệ quả nền tảng §5.6, chia
  3 bước. Không đặt ngưỡng % (§5.8).
- **`wp4-prep/ScanView.swift`** (diff so với wp3-prep: **+121 / −16**;
  16 dòng − là toàn bộ thân `recognizeLines` cũ được thay — mọi điểm
  gọi giữ nguyên chữ ký, mọi đường WP1–WP3 không đổi):
  - `OCRFrag`: mảnh chữ + hộp chuẩn hoá gốc-dưới-trái trong không
    gian ẢNH ĐẦY ĐỦ.
  - `mergeRows` — **F2a nguyên văn thuật toán CODE-AUDIT**: sort maxY
    giảm dần → gom mảnh chồng Y ≥ 50% chiều cao mảnh ngắn hơn vào
    hàng đang mở (neo = mảnh đầu hàng) → trong hàng sort minX, nối
    " ", độ tin cậy dòng = MIN các mảnh.
  - `collectFragments` + `ocrFragments` — **F2c**: ảnh cao/rộng > 3.0
    VÀ cao > 1600px → cắt lát dọc 1600px, chồng 200px, OCR tuần tự
    từng lát (handler.perform đồng bộ, hàng đợi nền), quy đổi hộp về
    ảnh đầy đủ trước khi ráp. Ngoài ngưỡng: 1 lượt như cũ — nhưng vẫn
    qua ráp hàng F2a (đó là điểm khác Build 1 trên MỌI đường ảnh).
  - `dedupeOverlap` — khử mảnh trùng vùng chồng lát: cùng chữ + diện
    tích giao ≥ 50% hộp nhỏ hơn → giữ confidence cao hơn (luật F2c).
  - Kiểm tĩnh phía mình: cân bằng ngoặc {112/112} (262/262) [37/37];
    grep ký hiệu: mọi hàm mới có đúng 1 định nghĩa + điểm dùng thật.

## Kiểm chứng đã chạy (bằng chứng file)
- `wp4-fixtures/verify_rowmerge.py` + `rowmerge_port.py` (port Python
  trung thực của dedupeOverlap/mergeRows) trên fixture mảnh-xé
  SYNTHETIC dựng từ đáp án chuẩn Mẫu 002 — **9/9 PASS**, kết quả đầy
  đủ ở `wp4-fixtures/verify-results.txt`:
  - A: 40 mảnh xé (nhãn/tiền tách cột, tiền lệch Y nhẹ) ráp thành đúng
    24 hàng thị giác, khớp ground truth từng hàng.
  - B: hàng ráp vào parser Sam's hiện hành → **§F đạt trọn**: subtotal
    203.30 · thuế 9.60+3.90 · total 216.80 · 10 dòng món · Σ món
    203.30 · 15 món · TC# đủ 21 số. (Khớp truy vết của Leader ở
    CODE-AUDIT Addendum: luật parser đủ đúng NẾU dòng được ráp.)
  - C: chèn 6 mảnh trùng vùng chồng (confidence thấp) → dedupe bỏ
    đúng 6, hàng ráp không đổi.
  - D: **đối chứng âm** — mảnh phát 1:1 kiểu Build 1 (không ráp) →
    parser mất subtotal/total (None), §F trượt: fixture có răng,
    phép ráp là thứ tạo ra khác biệt, không phải parser tự khỏi.
  - E: biên — chồng Y 33% < 50% KHÔNG ráp; 3 mảnh 1 hàng sắp đúng
    trái→phải; confidence dòng = min mảnh.

## Tuyên bố trung thực 3 phần
- **Đã chứng minh:** thuật toán ráp hàng F2a + khử trùng F2c (bản port
  Python) tái tạo đúng 24 hàng của 002 từ mảnh xé mô phỏng và đưa
  parser hiện hành tới §F trọn vẹn; đối chứng âm tái hiện đúng khiếm
  khuyết thực địa Build 1 (mất hết tiền). Đặc tả đo WP4 đã khoá.
- **Chưa chứng minh:** (1) biên dịch Swift [CHƯA KIỂM CHỨNG — môi
  trường ca không có compiler; build cloud là phép kiểm khi Wally
  trình đẩy]; (2) Vision thật xé mảnh ra sao trên máy + phép quy đổi
  toạ độ lát cắt CGImage đúng hướng chưa [CHƯA KIỂM CHỨNG — cần build
  chạy trên máy, gộp bước 3/M1]; (3) điểm cổng 001/002/003 của ứng
  viên (a) — chưa đo được vì chưa có OCR thật trong ca này.
- **Chưa làm (cố ý, đúng chia bước):** tiền xử lý ảnh phái sinh
  (tứ giác/perspective/tương phản) + F2b phía parser = bước 2; engine
  (b) `RecognizeDocumentsRequest` + bản test pipeline riêng + chạy
  thi đấu + QA ký chọn engine + quyết nền tảng iOS 26 (§5.6) = bước
  3; mẫu 002-C cần anh chụp camera thật — điểm chờ, gộp M1, không
  xin riêng.

---

# WP4 — BƯỚC 2 CHUẨN BỊ (2026-11-09 22:40 CST) — vẫn CHƯA tới cổng gói
**Việc đã làm — đúng bước 2 của WP4-SPEC §6:** tiền xử lý ảnh phái sinh
cho ứng viên (a) + F2b phía parser. Code ở `wp4-prep/` nay 2 file
(`ScanView.swift` + `Parser.swift` MỚI, nền build1 = bản main cho file
này vì WP2/WP3 không đụng Parser). **Chưa đẩy code ở bất kỳ nhánh nào.**

## Phần A — Tiền xử lý ảnh phái sinh (`wp4-prep/ScanView.swift`)
- Tổng diff so wp3-prep/main: **+182/−16** (bước 1 là +121/−16; bước 2
  thuần cộng thêm **+61/−0** trên nền bước 1) + 1 dòng `import CoreImage`.
- `derivedOCRImage`: VNDetectRectanglesRequest (minimumConfidence 0.5,
  maximumObservations 1) → CIPerspectiveCorrection (đổi toạ độ Vision
  gốc-dưới-trái chuẩn hoá × kích thước ảnh → điểm CI cùng gốc) →
  CIColorControls (saturation 0, contrast 1.1, brightness 0) → CGImage
  qua CIContext. Mọi lỗi/không-thấy-tứ-giác → nil → **fail-open về ảnh
  gốc**. Phái sinh chỉ sống trong bộ nhớ ở đường đọc: `process()` đã
  lưu JPEG GỐC trước khi OCR, không có đường nào ghi phái sinh đè gốc
  (ACCOUNTING-SPEC F2/§192).
- Cờ `useDerivedImage = true`: công tắc 2 cấu hình đo của WP4-SPEC §2
  (gốc / phái sinh) để bước 3 chấm cả hai trên cùng một bản code.
- Ngưỡng 0.5 + tương phản 1.1 ghi rõ trong code là GIÁ TRỊ KHỞI ĐIỂM
  cho bước 3 đo — không phải đã tinh chỉnh.

## Phần B — F2b chịu tách dòng (`wp4-prep/Parser.swift`, +106/−0)
Thuần cộng thêm 106 dòng, 0 dòng xoá/sửa so với build1; `validate()`
giống NGUYÊN VĂN (kiểm bằng script trích hàm + so byte: identical,
1.697 ký tự). Ba điểm nối đúng CODE-AUDIT F2b:
- Vòng tổng Sam's: máy trạng thái nhãn-chờ — dòng chỉ-có-nhãn
  (SUBTOTAL/TOTAL/TAX n [tỉ lệ %]) ghi nhớ, dòng chỉ-có-tiền ngay sau
  hoàn tất; mọi dòng khác làm nhãn hết hạn (đúng 1 dòng ân hạn). Chệch
  khỏi bản audit ở 2 điểm NHỎ, có lợi dữ liệu và ghi rõ: nhãn thuế giữ
  dạng hiển thị "TAX 1" như đường cùng-dòng (audit dùng "TAX1") và
  tỉ lệ % trên dòng nhãn được giữ vào `rateText` (audit bỏ).
- Vòng món Sam's: dòng chỉ-có-tiền (kèm cờ Y/T tuỳ chọn) hoàn tất món
  đang chờ (kể cả INST SV), đặt ở sau luật dòng-số-lượng, trước INST SV.
- Vòng tổng generic: cùng máy trạng thái theo pattern generic
  (SUBTOTAL/TOTAL DUE/AMOUNT DUE/BALANCE DUE/TAX/SALES TAX); TOTAL vẫn
  tôn trọng vùng loại trừ SUGGESTED TIP như đường cùng-dòng.

## Kiểm chứng đã chạy (bằng chứng file)
- Port Python `wp4-fixtures/f2b_port.py` + `verify_f2b.py` → **10/10
  PASS**, đầy đủ ở `wp4-fixtures/verify-f2b-results.txt`:
  S1 tổng Sam's tách dòng → §F trọn + giữ tỉ lệ thuế · S2 món Sam's
  tách dòng (gồm INST SV tiền âm) → §F trọn · S3 nhãn hết hạn sau 1
  dòng xen — tiền KHÔNG bị vớ · S4 nhãn treo → total vẫn None · S5 hồi
  quy hàng nguyên 002 → §F trọn · G1 generic tách dòng → đủ 3 số ·
  G2 TOTAL chờ bị dòng tip làm hết hạn → None · G3 generic hồi quy
  cùng-dòng → đủ 3 số · G4 = finding HAZARD dưới đây.
- Hồi quy bước 1: `verify_rowmerge.py` chạy lại — vẫn **9/9 PASS**.
- Kiểm tĩnh Swift: cân bằng ngoặc Parser {170/170} (328/328) [106/106];
  ScanView {121/121} (303/303) [41/41]; grep: mọi hàm/cờ mới có đúng 1
  định nghĩa + điểm dùng thật.

## FINDING ĐỎ (red-team, bắt buộc xử lý — không lấp)
- **F2b ghép LỆCH MỘT NHỊP trên dạng tiền-ở-dòng-TRƯỚC (Mẫu 003 thật):**
  dãy `96.91 / SUBTOTAL / 8.25 / SALES TAX / $105.16 / TOTAL` qua F2b
  cho subtotal=825 (tiền thuế), thuế=10516 (tiền tổng), total=None
  (fixture G4 khoá hành vi thật). Build 1 ở dạng này ra None cả 3 —
  F2b sửa đúng dạng nhãn-trước nhưng làm dạng tiền-trước TỆ HƠN.
  Giảm nhẹ hiện có: total None → validate() gắn cờ "Không đọc được
  TỔNG TIỀN" → tờ vào Hộp Chờ, KHÔNG sạch lặng lẽ; nhưng 2 số lệch
  không mang cờ riêng — chạm tinh thần luật cổng SCORECARD.
- **Chủ sở hữu việc sửa:** dạng tiền-trước-nhãn cho khối tổng đã được
  chẩn đoán Mẫu 003 giao cho **WP7** ("parser chịu được tiền-ở-dòng-
  trước cho khối tổng — WP7", sample-003-ground-truth.md mục Chẩn
  đoán 2). Ca này KHÔNG tự bịa cơ chế vá ngoài đặc tả CODE-AUDIT.
  Điều kiện cổng: bước 3 (QA ký chọn engine) phải ghi quyết riêng cho
  hazard này, và WP7 không được mở khi chưa có thiết kế xử lý thứ tự
  khối tổng kèm fixture G4 này trong bộ kiểm.

## Tuyên bố trung thực 3 phần — BƯỚC 2
- **Đã chứng minh:** F2b (bản port) đạt §F trên cả hai dạng tách dòng
  nhãn-trước (tổng + món Sam's, generic), giữ đúng kỷ luật hết-hạn-1-
  dòng và không đổi hành vi trên hàng nguyên (hồi quy S5/G3); Parser
  thuần cộng thêm, validate() nguyên văn; hazard ghép-lệch của chính
  F2b trên dạng 003 đã đo và khoá bằng fixture, không giấu.
- **Chưa chứng minh:** (1) biên dịch Swift cả 2 file [CHƯA KIỂM CHỨNG
  — không compiler trong ca; build cloud khi Wally trình đẩy];
  (2) tiền xử lý phái sinh: VNDetectRectanglesRequest + CIPerspective-
  Correction + phép đổi toạ độ trên máy thật [CHƯA KIỂM CHỨNG — bước
  3/M1]; ngưỡng 0.5 / tương phản 1.1 chưa có điểm đo; (3) điểm cổng
  001/002/003 của ứng viên (a) ở cả 2 cấu hình — chưa đo (cần OCR thật).
- **Chưa làm (đúng chia bước):** bước 3 — bản test pipeline engine (b)
  iOS 26 + chạy thi đấu + QA ký chọn engine + loại engine thua + chốt
  nền tảng §5.6 + quyết riêng cho finding HAZARD ở trên; mẫu 002-C chờ
  anh chụp ở M1.

## Chữ ký nội bộ — BƯỚC 2
- Design ✓ — không đổi giao diện; phái sinh vô hình với anh (chỉ tầng
  đọc), ảnh gốc anh xem ở Kiểm Lại/Chi Tiết vẫn là ảnh gốc.
- Code ✓ — diff Parser +106/−0, ScanView bước 2 +61/−0; API dùng toàn
  API ≤ iOS 13 (Vision/CoreImage cổ điển), framework lạ chỉ chạm SAU
  thao tác đọc hoá đơn, fail-open (TEAM.md #1); rà kiểu/optional:
  matchGroups đếm nhóm tường minh (m.count == 2/3), optional pending
  dọn sạch ở mọi nhánh continue (TEAM.md #2).
- QA ✓ — đối chiếu CODE-AUDIT F2b từng điều kiện (1 dòng ân hạn, hết
  hạn bởi dòng xen, validate không đụng); fixture có đối chứng âm
  (S3/S4/G2) + hồi quy (S5/G3) + fixture khoá hazard của chính thay
  đổi (G4) — TEAM.md #4: kết luận ghi đúng phạm vi thuật toán.

## Chữ ký nội bộ — BƯỚC 1
- Design ✓ — bước này không đổi giao diện nào; đặc tả đo tôn trọng
  nguyên tắc "số tiền không bị che" (không đụng lớp hiển thị).
- Code ✓ — diff +121/−16 chỉ trong tầng OCR của ScanView; API dùng
  toàn API ≤ iOS 13 (VNRecognizeTextRequest/CGImage cropping); không
  framework lạ lúc khởi động (TEAM.md #1); kiểu/optional đã rà
  (TEAM.md #2): results ép kiểu qua topCandidates/boundingBox của
  VNRecognizedTextObservation, Double/CGFloat chuyển đổi tường minh.
- QA ✓ — đối chiếu CODE-AUDIT F2a/F2c từng điều kiện (ngưỡng 50%,
  chồng 200px, lát 1600px, tỉ lệ 3.0, confidence = min); fixture có
  đối chứng âm; kết luận fixture được ghi đúng phạm vi (thuật toán,
  không phải OCR thật) — TEAM.md #4.

---

# WP4 — BƯỚC 3 PHẦN CHUẨN BỊ: BẢN TEST PIPELINE ENGINE (b) (2026-11-10 00:40 CST)
**Việc đã làm — đúng phần chuẩn bị được của bước 3 (WP4-SPEC §6):** dựng
bản test pipeline engine (b) cô lập kiểu Test 0 ở `wp4-testb/` (5 file +
workflow). Phần còn lại của bước 3 (chạy thi đấu trên máy + QA ký chọn
engine + chốt §5.6 + quyết riêng HAZARD G4) cần build cloud + máy anh —
gộp mốc M1 theo luật mốc lớn, KHÔNG xin anh cài/test riêng gói này.

## Sản phẩm `wp4-testb/`
- `project.yml` — XcodeGen riêng: target **iOS 26.0**, bundle
  `com.nje.sohoadon.testb`, chỉ 3 file nguồn. App chính KHÔNG bị đụng
  (vẫn 17.0 cho tới quyết §5.6).
- `EngineB.swift` — `RecognizeDocumentsRequest` + xuất dòng theo đoạn
  (paragraph transcript tách theo "\n") để đưa qua CÙNG parser như ứng
  viên (a); `derivedImage` chép đúng thuật toán phái sinh wp4-prep
  bước 2 (đối chiếu từng dòng với `derivedOCRImage` bản gốc) để (b)
  chấm ở cả 2 cấu hình gốc/phái sinh trên CÙNG ảnh phái sinh (§5.1).
- `ContentView.swift` + `TestBApp.swift` — chọn ảnh (PhotosPicker) →
  chạy 2 cấu hình → khối văn bản copy được (thời gian · số đoạn/bảng/
  danh sách · dòng). Không SwiftData/parser/lưu trữ.
- `.github/workflows/build-ipa.yml` — khuôn Test 0, runner `macos-26`,
  scheme/project đổi tên TestB, artifact `SoHoaDonTestB-IPA`.
- `README.md` — cách build + quy trình thi đấu ở M1 (4 ảnh: 001/002/
  003 + chụp camera lập 002-C) + giới hạn đã biết ghi trước.

## Kiểm chứng đã chạy (bằng chứng)
- **API đối chiếu 2 nguồn độc lập trước khi viết** (TEAM.md #4):
  WWDC25 "Read documents using the Vision framework" (bản ghi Apple
  qua apple-docs.everest.mt) + code chạy thật của Daniel Saidi
  (2026-01-10). Whitelist thành viên được dùng: `RecognizeDocuments-
  Request()` · `textRecognitionOptions.useLanguageCorrection` ·
  `perform(on:)` · `document` · `paragraphs[].transcript` · `tables` ·
  `lists`. Ngoài whitelist = không dùng.
- Kiểm tĩnh: cân bằng ngoặc 3 file Swift ({3/3} · {33/33} · {21/21},
  tròn/vuông khớp); grep ký hiệu: mọi hàm có định nghĩa + điểm dùng.
- Thuật toán phái sinh: đối chiếu với wp4-prep `derivedOCRImage` —
  cùng ngưỡng 0.5, cùng thứ tự filter, cùng khoá KVC, fail-open nil.

## Tuyên bố trung thực 3 phần — BƯỚC 3 (phần chuẩn bị)
- **Đã chứng minh:** bản test (b) tồn tại, cô lập hoàn toàn khỏi app
  chính (bundle/target/file riêng), chỉ dùng thành viên API có 2 nguồn
  độc lập xác nhận; quy trình thi đấu M1 đã viết thành văn bản.
- **Chưa chứng minh:** (1) biên dịch [CHƯA KIỂM CHỨNG — không compiler
  trong ca; runner macos-26/Xcode 26 cũng chưa chạy lần nào]; (2) hành
  vi RecognizeDocumentsRequest trên ảnh mẫu thật + điểm cổng của (b) ở
  2 cấu hình — chưa đo, cần build cloud + máy (M1); (3) `tables/lists`
  có đúng là mảng đếm được như đã viết — chỉ build cloud mới xác nhận.
- **Chưa làm (đúng phạm vi bước):** chạy thi đấu + QA ký chọn engine +
  loại engine thua + chốt nền tảng §5.6 + QUYẾT RIÊNG cho HAZARD G4 —
  tất cả chờ dữ liệu máy ở M1; mẫu 002-C chờ anh chụp ở M1.

## Chữ ký nội bộ — BƯỚC 3 (phần chuẩn bị)
- Design ✓ — app test tối giản theo khuôn Test 0; không phải bề mặt
  sản phẩm, không áp hệ "Sổ".
- Code ✓ — framework lạ chỉ chạm sau thao tác chọn ảnh + bấm chạy
  (TEAM.md #1); lỗi ném ra màn hình nguyên văn, không nuốt (fail-open
  thành trạng thái đọc được); rà kiểu: đường dữ liệu Data→UIImage→
  CGImage đều guard rõ (TEAM.md #2).
- QA ✓ — API có bằng chứng 2 nguồn trước khi viết (TEAM.md #4); giới
  hạn confidence-theo-dòng của (b) ghi trước trong README để văn bản
  chọn engine phải cân — không để tới lúc chấm mới phát hiện.

---

# WP4 — BƯỚC 3 PHẦN DỰNG KIT: TESTB ĐÃ SẴN SÀNG ĐẨY BUILD (2026-11-10 08:40 CST)
**Việc đã làm — đúng MỘT bước theo lệnh Wally ở đầu WORK-STATE (07:52
CST: "ca trực dựng nốt bản TestB từ wp4-testb/"):** rà soát sâu lại
toàn bộ `wp4-testb/` như một vòng build bị chặn ở phía mình, rồi đóng
gói kit giao được ngay — KHÔNG đẩy code (đúng luật ca trực: code trình
Wally ở chat chính; thẻ đẩy là của anh).

## Rà soát sâu (bằng chứng đo lại trong ca này, không chép số cũ)
- Đọc lại từng dòng 3 file Swift: `EngineB.recognize` chỉ dùng thành
  viên API trong whitelist 2 nguồn (đếm máy: recognize định nghĩa 1,
  điểm dùng 2 ở ContentView; derivedImage định nghĩa 1, điểm dùng 1);
  `derivedImage` đối chiếu TỪNG DÒNG với `derivedOCRImage` của
  wp4-prep (nay đã trên main ở commit 122ee9b): cùng ngưỡng 0.5, cùng
  thứ tự CIPerspectiveCorrection → CIColorControls (0 / 1.1 / 0), cùng
  khoá KVC, fail-open nil — khớp hoàn toàn, kể cả mẫu
  `(detect.results ?? [])` dùng chung với bản (a).
- Cân bằng ngoặc đếm lại bằng script: TestBApp {3/3} · ContentView
  {33/33} (64/64) [3/3] · EngineB {21/21} (54/54) [5/5] — khớp số ca
  00:40 đã ghi. YAML của `project.yml` + workflow: parse sạch.
- `project.yml` soi với khuôn app chính (ios/project.yml — bản ĐÃ
  build xanh nhiều vòng): cùng mẫu INFOPLIST_FILE + khối info:, chỉ
  khác tên/scheme/bundle/target 26.0. Workflow soi với workflow app
  chính: cùng khuôn từng bước, chỉ đổi runner macos-26, scheme
  SoHoaDonTestB, artifact SoHoaDonTestB-IPA.
- Kiểm từ xa trong ca: main vẫn ở `dc631b0` (WP5) — khớp ghi nhận
  07:52 của Wally; nhánh docs/planning vẫn ở `27b7970` (06:47Z) →
  lần đẩy không xác định của ca 06:40 CST **KHÔNG lên được**, không
  có bản trùng trên nhánh; ca này đẩy lại tài liệu ở cuối ca theo
  luật 1 lần.

## Sản phẩm giao được
- **`SoHoaDon-TestB-Kit.zip`** (thư mục receipt-app/, 8.619 byte,
  sha256 `421ed9b59c3a62cdfdf806cafb2224ccf815e2024c2162aa28293fe209aba694`):
  chứa đúng 6 file của wp4-testb/ dưới thư mục `testb/` (gồm cả
  `.github/workflows/build-ipa.yml`); đã giải nén đối chiếu
  `diff -r`: khớp byte-for-byte với wp4-testb/ (trừ KIT-MANIFEST.txt
  nằm ngoài zip). Hash từng file: `wp4-testb/KIT-MANIFEST.txt`.
- Cách Wally dùng: đẩy nội dung kit thành repo riêng hoặc nhánh riêng
  (file ở gốc repo) → Actions tự chạy (push lên main của repo đó hoặc
  workflow_dispatch) → artifact SoHoaDonTestB-IPA → anh ký Feather +
  cài, gộp vào buổi test M1 MỘT lần cùng bản chính dc631b0.

## Tuyên bố trung thực 3 phần — PHẦN DỰNG KIT
- **Đã chứng minh:** kit tồn tại, nguyên vẹn byte-for-byte, cấu trúc
  soi với khuôn Test 0/app chính đã build được; thuật toán phái sinh
  (b) ≡ (a) từng dòng; trạng thái 2 nhánh GitHub đã đọc trực tiếp
  trong ca (main dc631b0, docs/planning 27b7970).
- **Chưa chứng minh:** biên dịch trên runner macos-26/Xcode 26
  [CHƯA KIỂM CHỨNG — chỉ build cloud lần đầu mới trả lời, gồm cả
  `tables/lists` có đếm được như đã viết]; hành vi
  RecognizeDocumentsRequest trên ảnh mẫu thật.
- **Chưa làm (đúng phạm vi):** đẩy kit lên repo/nhánh + xem kết quả
  build cloud (trình Wally ở chat chính — thẻ đẩy của anh); thi đấu
  2 ứng viên + QA ký chọn engine + chốt §5.6 + quyết HAZARD G4 +
  mẫu 002-C — tất cả ở buổi M1 trên máy anh.

## Chữ ký nội bộ — PHẦN DỰNG KIT
- Design ✓ — không đổi gì ở app test; README trong kit đã ghi cách
  build + cách dùng ở M1.
- Code ✓ — rà từng dòng đủ 3 file + 2 file cấu hình; không sửa dòng
  code nào trong ca này (không có khiếm khuyết nào được chứng minh
  bằng bằng chứng; không sửa theo suy đoán — TEAM.md #4).
- QA ✓ — số đếm máy khớp hồ sơ cổng trước; hash kit + manifest lưu
  kèm; kết luận từ xa đọc trực tiếp từ GitHub trong ca, không suy
  từ biên nhận đẩy cũ.

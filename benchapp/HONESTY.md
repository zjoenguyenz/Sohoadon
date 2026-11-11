# BENCHAPP — tuyên bố trung thực 3 phần

## Đã chứng minh (tại bàn, có file/số kèm theo)

- Hai đầu khớp schema v1: file JSON chế theo đúng định dạng
  BenchApp xuất (từ luồng đóng băng 001) được
  `bench-prep/bench_score.py` chấm **trọn sổ + trọn §F cho 8/8
  run** (N-001 + S-0 × A0–A3), cổng cứng qua, S-0 đạt — xem
  `selftest/selftest-score-results.txt`.
- Bridge không sửa hành vi: diff `ScanView.swift` của gói so với
  `p2-fix/ScanView.swift` = **+319/−0** (chỉ cộng khối `#if BENCH`
  ở cuối file).
- 4 ảnh nhúng trùng byte với `samples/` (cmp), đúng ánh xạ
  manifest: N-001 (L0), N-002 (L4), C-003 (L1), S-0 (S, pages=1).
- Không một số đáp án nào nằm trong code/project của gói (grep = 0);
  đáp án chỉ sống ở phía bộ chấm qua `gt_id` như đặc tả đòi.
- Danh mục UI khai đủ các ca THIẾU của manifest (S-1, S-2,
  C-002C, L1-01…03, L2-01…02, L3-01…02, L4-02, L5-01, PDF-SAM)
  ở trạng thái THIẾU — không bịa ảnh cho ca nào.
- **Cập nhật BENCH-CATALOG-EXT (kiểm lại tại bàn 2026-11-10
  22:40 CST, từ bằng chứng gốc — thay câu cũ "18 ca suy biến
  còn THIẾU / chưa tạo" của gói benchapp gốc):** 18 ảnh
  synthetic ĐÃ tạo, đóng băng và nhúng: sha256 + byte-size
  khớp `synthetic-manifest.csv` **18/18** và byte-trùng bản
  gốc ở `bench-prep/synthetic/images/`; 4 ảnh thật byte-trùng
  `samples/` **4/4** (kiểm lại cùng ca). Nhất quán 3 phía:
  BenchCatalog **45 mục = 22 có file** (4 thật + D-01…D-18
  synthetic) **+ 23 THIẾU tường minh** (13 ô cũ + L-R01…L-R10);
  tập file `BenchImages/` (22) == tập `resourceName` == tập
  dòng sources trong `project.yml` (22). Ngoặc BenchCatalog
  7/7 · 85/85 · 5/5. `appBuild` = `benchapp-2`. Trọng số đã
  chốt trong `bench_score.py`: origin ≠ real → ×1 bất kể
  difficulty; real L1/L2/L5 → ×2. Chi tiết gói: `AFTER.md`
  mục BENCH-CATALOG-EXT.

## Chưa chứng minh

- **Biên dịch Swift chờ cloud build.** Môi trường tại bàn không có
  swiftc/Xcode. Các điểm rủi ro biên dịch cụ thể, ghi thẳng:
  (1) bridge chạm thành viên `private` của ScanView từ extension
  cùng file — đúng luật truy cập Swift theo tài liệu, nhưng chỉ
  bản dựng thật mới phán; (2) `RecognizeDocumentsRequest()
  .supportedRecognitionLanguages` + `VNRecognizeTextRequest
  .supportedRecognitionLanguages(for:revision:)` với hằng
  `VNRecognizeTextRequestRevision3` — đối chiếu tài liệu Apple
  2026-11-01, chưa qua trình biên dịch; (3) XcodeGen có xếp 22 file
  `.jpg` liệt kê trong `sources` vào bản sao tài nguyên của bundle
  hay không (nếu không, BenchRunner sẽ ném lỗi "không tìm thấy
  ảnh nhúng" ngay khi chạy — lỗi to, dễ thấy, không âm thầm);
  (4) cờ `SWIFT_ACTIVE_COMPILATION_CONDITIONS: BENCH` qua XcodeGen
  — nếu cờ không tới được target, BenchApp.swift sẽ không có
  `@main` và bản dựng rớt rõ ràng.
- **Bản bench cuối 22 ảnh (`benchapp-2`) CHƯA build cloud** —
  biên dịch + nạp tài nguyên của 18 ảnh synthetic mới chỉ phán
  ở build bench cuối; run #32 xanh là bản `benchapp-1` (4 ảnh).
- **Hành vi trên máy = chính buổi đo.** Mọi pass (cổ điển, (b),
  ROI) đều chưa chạy trên thiết bị trong gói này; thời gian đo,
  chất lượng dòng, và việc (b) có cho candidates/tables thật hay
  không chỉ biết khi buổi đo chạy.
- **Giới hạn đo của A3 trong schema v1 (đã ghi cả trong notes của
  final A3 khi xuất):** bộ chấm parse lại *final lines* bằng
  parser đóng băng, trong khi reconcile của p2-fix sửa ở tầng
  ParseResult — các sửa trường đó **không có kênh biểu diễn**
  trong schema v1. Hệ quả: delta đo được của A3 so với A2 chủ yếu
  phản ánh vòng ROI (dòng mới thật), không phản ánh trọn giá trị
  của lớp reconcile. Đây là giới hạn của đặc tả đo hiện hành,
  không phải BenchApp tự ý cắt.
- Candidates ở cấp dòng của A1/A2/A3 là các biến thể mà
  OCRFragmentMerger còn giữ trên dòng hợp nhất (alternates), giới
  hạn 3 — không phải topCandidates thô của từng observation
  (khái niệm đó chỉ tồn tại ở cấp mảnh). A0 giữ candidates đúng
  theo observation cho hàng một mảnh.

## Chưa làm (đúng phạm vi gói)

- Không dựng nhánh bench, không đẩy GitHub, không sửa workflow —
  Leader dựng nhánh từ bộ file này + project.yml của gói.
  (Bản bench run #32 là `benchapp-1`, 4 ảnh; bản bench cuối
  22 ảnh `benchapp-2` CHƯA đẩy/build — đúng quy trình: Wally
  trình ở chat chính.)
- 18 ảnh suy biến: ĐÃ TẠO + đóng băng + nhúng (xem mục Đã
  chứng minh ở trên) — câu cũ "không tạo" đã bị thay thế.
  Còn chưa làm: chưa thu/nhúng ca thật còn thiếu — 10 ô
  L-R01…L-R10 vẫn THIẾU, chờ anh gửi ảnh thật; khi ảnh về,
  Leader lấp ô theo quy ước 5 bước trong `AFTER.md`.
- Không đổi schema, không đụng pipeline/Parser (chỉ gọi qua
  bridge + tái lập A0 ở điều phối). `bench_score.py` chỉ được
  chốt lại luật trọng số theo origin (xem trên), không đổi
  schema/cách chấm khác.

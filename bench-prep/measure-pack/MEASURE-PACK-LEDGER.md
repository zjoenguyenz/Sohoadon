# SỔ GÓI ĐO — BẢNG CHẤM ĐÓNG BĂNG + THỨ TỰ BUỔI ĐO (2026-11-11, ca trực 04:40 CST)

Việc độc lập làm trong lúc chờ 10 ảnh thật (L-R) và luồng OCR gốc
trên máy — lấp mục còn thiếu của điều kiện chặn buổi đo
`core-redo/ACCEPTANCE.md` §3.5(2) ("tất cả kèm **bảng chấm in sẵn
(ca × chỉ số × ngưỡng)**") và §4.1 ("gói đo đóng băng: danh sách
ảnh theo mã + bảng chấm in sẵn + thứ tự nạp cố định + hướng dẫn
chụp 1 trang"). Trước ca này bốn thứ đó CHƯA TỒN TẠI thành tài
liệu ở bất cứ đâu trong repo (đã kiểm bằng tìm kiếm toàn cây).

## Đã làm — `bench-prep/measure-pack/`
- `MEASURE-PACK.md` — gói đo đóng băng: ánh xạ mã buổi đo §4.2 ↔
  mã BenchApp (Phần 1 có lệch mã thật: S-01…S-04 ↔ N-001/N-002/
  C-002C/C-003; ca cổng danh dự S-0 đứng dòng S-05-DANH-DỰ) · 9 hồ
  sơ ngưỡng chép nguyên văn §2.3 (A · B · C-SEED · S0-HONOR ·
  C-REAL · D · LAB · SAVED · PDF) phủ luật tuyệt đối M9 · thứ tự
  buổi đo cố định 7 bước (kể cả vị trí 3B của làn lab — quyết của
  gói này, ghi rõ §4.2 chưa có) · trang hướng dẫn chụp 1 trang
  (§4.3) để cắt ra gửi anh tại buổi đo · bảng trạng thái điều
  kiện chặn §3.5/§4.1 tại ngày đóng băng.
- `gen_scoresheet.py` + `scoresheet.csv` — bảng chấm **71 dòng
  ca**: 45 mục BenchCatalog (22 READY = 4 thật + 18 synthetic ·
  13 MISSING · 10 EMPTY-SLOT L-R) + 24 ca lab W + 2 ca dữ liệu đã
  lưu L-01/L-02. Mỗi dòng khoá: phần buổi đo · mã buổi đo · trạng
  thái · đáp án/tham chiếu · đường chấm (bench_score.py /
  chờ-đáp-án / tại-bảng / ngoài-bench) · hồ sơ ngưỡng · luật M9.
  Tự bắt + sửa 2 lỗi của chính bộ sinh trong ca: ghi chú C-002C/
  S-1 ban đầu gán nhầm đường nạp L-R (đúng: chụp/quét ở buổi
  chuẩn bị) và đường chấm của ca đã có đáp án đóng băng bị ghi
  "chờ đáp án" (đúng: bench_score.py khi có ảnh).
- `verify_measure_pack.py` (verifier độc lập, không dùng chung
  code với bộ sinh) + `verify-measure-pack-results.txt`:
  **PASS 10/10 nhóm** — 71 dòng + header · tập mã sheet == tập mã
  catalog 45 · đếm trạng thái khớp BENCH-MANIFEST §5 · ca READY
  mang GT có thật trong sổ đáp án của `bench_score.py` · 18
  synthetic đều hồ sơ D · 24 lab khớp `wildreceipt-subset.csv` ·
  M9 trên 71/71 dòng, 0 trùng mã · ánh xạ mã Phần 1/Phần 2 đúng ·
  sinh lại CSV **byte-trùng** · tài liệu chứa đủ số đóng băng +
  ghi rõ điều kiện còn chặn.
- Hồi quy nhẹ cùng ca: `bench_score.py` chạy lại trên
  `benchapp/selftest/selftest-app-format.json` — exit 0, kết quả
  **byte-trùng** file đã lưu → đường chấm ghi trong bảng còn chạy
  đúng tại ngày đóng băng.

## Tuyên bố trung thực 3 phần
- **Đã chứng minh:** bảng chấm + gói đo khớp cơ học với mọi nguồn
  đóng băng của chúng ở tầng file/kê khai (số đếm, tập mã, GT,
  ngưỡng chép nguyên văn §2.3, tái lập byte-trùng); phần "bảng
  chấm in sẵn" của §3.5(2) NAY ĐỦ — §3.5(2) chỉ còn thiếu 10 ca
  thật L-R và việc nhúng 24 ảnh lab ở lần ráp bản bench cuối.
- **Chưa chứng minh:** (a) hồ sơ C-REAL cho ô L-R là tạm khoá
  theo lớp chung — lớp thật chốt khi ảnh về; (b) 2 ca thi đấu
  B-04/B-05 chưa chốt tên (chờ ca thật khó nhất); (c) gói đo chưa
  từng dùng trong buổi đo thật — tính đủ của nó chỉ phán khi buổi
  đo đầu tiên điền xong mà không phải chế thêm cột giữa buổi;
  (d) ngưỡng ≥ 80% ở hồ sơ C-REAL giữ nguyên nhãn *đề xuất QA*
  (§6 ACCEPTANCE), không phải cổng.
- **Chưa làm / vẫn chặn buổi đo:** 10 ca thật L-R chờ anh gửi;
  §3.5(3)/G0 luồng OCR gốc trên máy của Sam's run #26 vẫn chưa
  về; bản bench cuối (nhúng lab + L-R, build xanh, G5) chưa ráp.
  Buổi đo CHƯA đủ điều kiện — ca này không đụng Swift/schema/
  pipeline, không kêu anh cài/test gì.

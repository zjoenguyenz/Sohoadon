# SỔ STAGING LAB — 24 ẢNH WildReceipt ĐÃ ĐÓNG GÓI SẴN CHO LẦN RÁP BENCH CUỐI (2026-11-11, ca trực 06:40 CST)

Việc độc lập làm trong lúc chờ 10 ảnh thật (L-R) và luồng OCR gốc
trên máy — chuẩn bị trước phần "nhúng 24 ảnh lab" của bước 0 buổi
chuẩn bị (`bench-prep/measure-pack/MEASURE-PACK.md` mục 4 bước 0;
điều kiện chặn buổi đo `core-redo/ACCEPTANCE.md` §3.5(2)). Trước
ca này 24 ảnh lab mới chỉ tồn tại dưới dạng *bảng kê đóng băng*
(`lab-wildreceipt/wildreceipt-subset.csv`): ảnh thật vẫn nằm rải
trong cây corpus đã giải nén với tên gốc dài (`image_files/
Image_69/5/15c0….jpeg`), chưa có bộ file mang tên ca W-01…W-24
sẵn sàng để chép vào `benchapp/BenchImages/` — lần ráp cuối sẽ
phải tự mò lại 24 đường dẫn và tự chép tay, đúng loại thao tác
dễ sai ở bước chịu áp lực nhất.

## Đã làm — `bench-prep/lab-staging/`
- `make_lab_staging.py` — bộ chép xác định: chỉ đọc bảng kê đã
  đóng băng (case_id + file_name + sha256 + bytes), kiểm sha256 +
  byte-size của từng file nguồn TRƯỚC khi chép, chép byte-nguyên
  sang `images/W-01.jpg`…`W-24.jpg` (đuôi `.jpg` vì BenchImages/
  BenchCatalog dùng `resourceExtension = "jpg"`; payload là JPEG
  — verifier kiểm magic bytes + PIL format, không giả định),
  kiểm lại bản chép, ghi `lab-staging-manifest.csv` (ca · file
  staging · file nguồn · sha256 · bytes · kích thước · tầng).
- Kết quả: **24/24 ảnh, tổng 2.092.865 byte** (lớn nhất W-24
  545.788 · W-03 553.735 byte).
- `verify_lab_staging.py` (verifier độc lập, không dùng chung
  code với bộ chép) + `verify-lab-staging-results.txt`:
  **PASS 10/10 nhóm** — manifest 24 dòng liên tục · tập ca/nguồn
  khớp bảng kê · sha256+bytes khớp bảng kê **24/24** · byte-trùng
  file nguồn corpus **24/24** · JPEG thật (magic + PIL) và kích
  thước khớp bảng kê **24/24** · manifest khớp bảng kê (kích
  thước/tầng) **24/24** · thư mục staging đúng 24 file · chạy lại
  bộ chép vào cây tạm cho **byte-trùng** cả 24 ảnh + manifest ·
  **BenchApp không bị đụng** (BenchImages vẫn 22 file, catalog
  không có mã W nào, project.yml không có tham chiếu lab) ·
  tổng byte = tổng của bảng kê. (Verifier tự bắt 1 lỗi lặp dict
  của chính nó ở lần chạy đầu — đã sửa, chạy lại xanh, đúng luật
  tự kiểm.)
- Hồi quy nhẹ cùng ca: `bench_score.py` trên selftest app-format
  — exit 0, kết quả **byte-trùng** file đã lưu.

## Hệ quả cho lần ráp bản bench cuối (bước 0 buổi chuẩn bị)
Phần "nhúng lab" nay rút còn thao tác cơ học đã có nguồn kiểm
chứng: chép `lab-staging/images/W-nn.jpg` → `benchapp/
BenchImages/W-nn.jpg` (đối chiếu lại bằng manifest này), đăng ký
24 mục trong BenchCatalog + 24 dòng sources trong project.yml,
nâng `appBuild`, build. Không còn bước mò đường dẫn/tên gốc.

## Hai điểm MỞ ca này phát hiện — KHÔNG tự quyết, để Leader chốt ở lần ráp
1. **Enum `origin` của BENCH-JSON-SPEC không có chỗ cho ca lab:**
   spec chỉ định `real` · `synthetic`. Ảnh lab là ảnh thật nhưng
   KHÔNG phải hoá đơn của anh và làn lab không phải cổng
   (ACCEPTANCE §3.1/§3.3). Nếu đăng ký `origin: "real"` kèm
   `difficulty` L1/L2/L5, `bench_score.py` (`weight_of`: ×2 chỉ
   khi origin=real và difficulty thuộc L1/L2/L5) sẽ cho chúng
   trọng số ×2 như ca thật khó — ngược vai trò làn lab. Nếu đăng
   ký `"synthetic"` thì nhãn sai bản chất. Staging KHÔNG chọn;
   hướng sạch nhất (chỉ là ghi nhận, chưa quyết): mở rộng enum
   thêm `"lab"` với trọng số ×1 ở lần ráp, sửa đồng bộ spec +
   bộ chấm + kiểm lại selftest.
2. **Ánh xạ `form`/`difficulty` cho ca W chưa đóng băng ở đâu
   cả:** 4 tầng chọn LONG/DENSE/LOWRES/TALL không ánh xạ 1-1 sang
   trục khó L0–L5 của schema (LOWRES→L4 và LONG/TALL→L5 là gần,
   DENSE chưa có mức tương đương rõ). Staging giữ nguyên cột
   `stratum` làm dữ kiện gốc; Leader chốt ánh xạ khi đăng ký
   catalog, không suy từ staging này.

## Tuyên bố trung thực 3 phần
- **Đã chứng minh:** 24 ảnh lab đã có bộ file staging mang tên
  ca, byte-trùng nguồn corpus và khớp sha256/bảng kê đóng băng
  ở mức file (verifier độc lập 10/10 + tái lập byte-trùng);
  BenchApp hiện hành không đổi một byte nào vì ca này; đường
  chấm selftest không hồi quy.
- **Chưa chứng minh:** (a) các ảnh staging CHƯA được app nạp —
  biên dịch + nạp tài nguyên chỉ phán ở build bench cuối (G5);
  (b) 2 điểm mở trên (origin + ánh xạ difficulty) chưa chốt nên
  catalog của ca lab chưa viết được trọn; (c) kích thước gói đo
  tăng thêm 2.092.865 byte tài nguyên khi nhúng (để so: IPA
  bench run #32 là 2,09 MB với 4 ảnh) — chưa có ngưỡng nào phán
  mức tăng này, chỉ ghi số thật.
- **Chưa làm / vẫn chặn buổi đo:** 24 ảnh CHƯA nhúng BenchApp
  (đúng thiết kế staging — ráp ở bản bench cuối cùng nhịp L-R);
  10 ca thật L-R chờ anh gửi; §3.5(3) luồng OCR gốc trên máy của
  Sam's run #26 vẫn chưa về; B-04/B-05 chưa chốt tên. Buổi đo
  CHƯA đủ điều kiện — ca này không đụng Swift/schema/pipeline,
  không kêu anh cài/test gì.

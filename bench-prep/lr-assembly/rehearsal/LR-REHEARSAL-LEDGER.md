# SỔ DIỄN TẬP RÁP L-R + NÂNG DẤU BẢN — PHẦN CUỐI CỦA LẦN RÁP ĐÃ CHẠY THỬ TRỌN TRÊN BẢN SAO CÁCH LY (2026-11-11, ca trực 16:40 CST)

Việc độc lập làm trong lúc chờ 10 ảnh thật L-R: sổ diễn tập lab
(ca 14:40) ghi tường minh phần CHƯA diễn tập — "diễn tập chưa gồm
L-R (chưa có ảnh) và chưa nâng appBuild; hai việc đó thuộc lần ráp
cuối". Ca này diễn tập đúng hai việc đó, trên **bản sao cách ly**
nằm trên nền của chính diễn tập lab (`lab-assembly/rehearsal/work/`
— catalog 69 mục, 46 ảnh, `benchapp-2`), là đúng trạng thái mà lần
ráp cuối sẽ đứng: lab đã ráp, L-R sắp lấp.

## Ảnh đứng thay — kỷ luật ghi nhãn

Chưa có ảnh thật nên dùng **10 ảnh hạt giống đã có** trong
`benchapp/BenchImages/` (4 thật + 6 synthetic, 10 file khác nhau)
làm ảnh đứng thay (stand-in), theo bảng đóng băng
`lr-rehearsal-input.csv` (sha256 + byte từng file). Phân loại
form/difficulty và gtID của mỗi ô **kế thừa đúng ca hạt giống
nguồn** (N-001 → N/L0/GT-SAMS-F, C-003 → C/L1/GT-HD-003, S-0 →
S/L0/GT-SAMS-F + pages 1, các SYN theo đúng mục D tương ứng) —
không bịa phân loại, không bịa đáp án mới. `sourceFile` trong bản
sao mang tiền tố `REHEARSAL-STANDIN-` và `statusNote` ghi rõ
"DIỄN TẬP — ảnh đứng thay … KHÔNG phải hoá đơn thật của anh" để
bản sao không bao giờ bị đọc nhầm thành ca thật.

## Đã làm (đúng 5 bước quy ước nạp ở `benchapp/AFTER.md` + nâng dấu)

Với mỗi ô L-R01…L-R10: (1) chép ảnh → `work/BenchImages/L-Rnn.jpg`
(sha trước/sau chép khớp bảng input); (2) điền `resourceName:
"L-Rnn"` + `sourceFile` + `pages` (L-R04 = 1, còn lại nil);
(3) thêm 1 dòng sources vào `project.yml` (sau dòng W-24);
(4) điền form/difficulty/gtID theo bảng input; (5) `statusNote`
đổi từ "THIẾU — …" sang mô tả sẵn sàng (diễn tập). Cộng thao tác
nâng dấu bản: `appBuild` `benchapp-2` → `benchapp-3` **chỉ ở bản
sao**. Kết quả: catalog **69 mục / 56 mục có file** (22 gốc + 24
lab + 10 L-R); `work/` 11 MB chỉ ở tại bàn, tái lập bằng script,
KHÔNG đẩy (tiền lệ staging + diễn tập lab).

## Kiểm chứng (verifier độc lập `verify_lr_rehearsal.py` — PASS 8/8)

- 1: 10 mục L-R khớp bảng input từng trường; statusNote không còn
  "THIẾU", có ghi DIỄN TẬP + tên ảnh đứng thay 10/10.
- 2: nhất quán ba phía 56/56/56 (file == resourceName == sources)
  + YAML parse; tổng mục catalog 69.
- 3: ảnh L-R trong work byte-trùng ảnh đứng thay thật: sha256
  10/10 khớp cả bảng input lẫn file nguồn.
- 4: ngoặc cân bằng ({} 7/7 · () 121/121); appBuild bản sao =
  `benchapp-3`; 24 mục W (lab) nguyên vẹn.
- 5: **benchapp thật + nền diễn tập lab nguyên vẹn** — hash
  catalog/project khớp dòng #ORIG, BenchImages thật vẫn 22 file,
  0 file L-R ở benchapp thật, appBuild thật vẫn `benchapp-2`,
  hash nền lab khớp #ORIG.
- 6: tái lập byte-trùng khi chạy lại maker (catalog + project +
  56 ảnh).
- 7: hồi quy bộ chấm — `bench_score.py` trên selftest app-format
  stdout byte-trùng file đã lưu.
- 8: gtID dùng trong diễn tập (GT-SAMS-F · GT-HD-003) đều có thật
  trong ANSWERS của `bench_score.py`.

Vòng chạy đầu PASS trọn 8/8 — ca này không có lỗi verifier/maker
nào phải sửa (khác 2 ca trước; ghi rõ để không ai tưởng đã lược).

## Tuyên bố trung thực 3 phần

- **Đã chứng minh:** toàn bộ phần cơ học còn lại của lần ráp cuối
  nay đã diễn tập trọn trên bản sao ở đúng trạng thái ráp thật
  (lab + L-R + nâng dấu): điền ô theo quy ước 5 bước chạy sạch
  bằng regex trên đúng cấu trúc placeholder thật, nhất quán ba
  phía 56, tái lập xác định, benchapp thật không bị đụng, bộ chấm
  không hồi quy — ở mức file/kê khai tại bàn.
- **Chưa chứng minh:** (a) catalog 69 mục / 56 ảnh CHƯA biên dịch
  — không swiftc tại bàn, chỉ phán ở build bench cuối (cloud),
  như mọi gói bench; (b) phân loại + đáp án của diễn tập là kế
  thừa hạt giống — việc chép tay + kiểm số học + đóng băng GT MỚI
  cho hoá đơn thật (và file `--answers` nạp GT mới vào bộ chấm)
  CHƯA diễn tập được vì phụ thuộc nội dung ảnh thật chưa có;
  (c) B-04/B-05 vẫn chưa chốt tên (phụ thuộc 2 ca thật khó nhất).
- **Chưa làm / vẫn chặn buổi đo:** 10 ca thật L-R vẫn chờ anh
  gửi; §3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn chưa
  về. Buổi đo CHƯA đủ điều kiện — ca này không kêu anh cài/test
  gì. Sau ca này, lần ráp cuối chỉ còn việc phụ thuộc ảnh thật:
  chép tay/kiểm số học/đóng băng GT mới + nạp `--answers`, điền ô
  theo thao tác đã diễn tập, chốt B-04/B-05, build cloud.

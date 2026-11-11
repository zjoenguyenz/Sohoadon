# SỔ DIỄN TẬP RÁP LAB — CÔNG THỨC RÁP ĐÃ CHẠY THỬ TRỌN VẸN TRÊN BẢN SAO CÁCH LY (2026-11-11, ca trực 14:40 CST)

Việc độc lập làm trong lúc chờ 10 ảnh thật L-R: công thức ráp cơ
học ở `LAB-ASSEMBLY-DECISION.md` (bước 0 buổi chuẩn bị) trước ca
này mới tồn tại ở dạng văn bản quyết — chưa từng được áp thật
lên một catalog nào. Ca này áp nó lên **bản sao cách ly** của
benchapp trong `rehearsal/work/` bằng `make_rehearsal.py` xác
định, để lần ráp cuối (cùng nhịp L-R, dưới áp lực buổi đo) không
còn là lần chạy đầu tiên của công thức.

## Đã làm (đúng 3 bước của công thức, không thêm quyết nào)

1. Chép `lab-staging/images/W-01.jpg`…`W-24.jpg` →
   `work/BenchImages/` (đối chiếu sha256 trước/sau chép).
2. Thêm 24 mục `BenchCatalog` vào bản sao: id `W-nn`, form `C`,
   difficulty theo Quyết 2 (LONG/TALL → L5 · DENSE/LOWRES → L4),
   `origin: "lab"`, `gtID: ""`, `sourceFile:` = đường dẫn corpus
   nguyên văn trong `wildreceipt-subset.csv`, `resourceName:
   "W-nn"`, `statusNote:` ghi tầng gốc + "LAB — chấm tay hồ sơ
   LAB, không GT, không cổng". Chèn ngay trước khối ô L-R.
3. Thêm 24 dòng sources `BenchImages/W-nn.jpg` vào bản sao
   `project.yml` (sau dòng SYN-003-NOISE).

Kết quả tại bàn: catalog bản sao **69 mục** (45 gốc + 24 W),
**46 mục có file** (22 gốc + 24 lab); `work/` nặng 7.8 MB —
**chỉ ở tại bàn, tái lập được bằng script, KHÔNG đẩy GitHub**
(như tiền lệ 24 ảnh staging ở ca 06:40).

## Kiểm chứng (verifier độc lập `verify_rehearsal.py` — PASS 7/7)

- 1: 24 mục W khớp Quyết 1/2 từng trường + statusNote đủ
  tầng/LAB/không-GT/không-cổng.
- 2: ba phía nhất quán — tập file BenchImages(work) ==
  resourceName == sources project.yml (46/46/46); YAML parse OK.
- 3: ảnh W trong work byte-trùng staging: sha256 24/24 khớp cả
  staging manifest lẫn subset đóng băng.
- 4: ngoặc catalog cân bằng ({} 7/7 · () 111/111); `appBuild`
  giữ nguyên `benchapp-2` — diễn tập KHÔNG tự nâng dấu bản (dấu
  bản chỉ nâng ở lần ráp cuối có L-R, theo quy ước AFTER.md).
- 5: **benchapp thật không bị đụng** — hash BenchCatalog.swift +
  project.yml khớp dòng #ORIG ghi trong rehearsal-manifest.csv
  trước khi sao chép; BenchImages thật vẫn 22 file.
- 6: tái lập xác định — chạy lại `make_rehearsal.py` cho work
  byte-trùng (catalog + project + 46 ảnh).
- 7: hồi quy bộ chấm — `bench_score.py` trên selftest app-format
  (chạy đúng cách sinh file đã lưu: cwd=gốc + đường dẫn tương
  đối) cho stdout byte-trùng file đã lưu.

Lỗi phía em trong ca (verifier tự bắt, đã sửa, chạy lại xanh):
vòng chạy đầu của verifier nhóm 7 FAIL vì verifier truyền đường
dẫn tuyệt đối — `bench_score.py` in nguyên văn đường dẫn đầu vào
ở dòng 1 nên stdout lệch file đã lưu đúng 1 dòng tiêu đề. Nguyên
nhân ở verifier, không phải bộ chấm; đã sửa cách gọi + ghi rõ
trong code, chạy lại PASS byte-trùng thật.

## Tuyên bố trung thực 3 phần

- **Đã chứng minh:** công thức ráp lab chạy được trọn vẹn ở mức
  file/kê khai trên bản sao — catalog/project/ảnh nhất quán ba
  phía, tái lập xác định, benchapp thật nguyên vẹn, bộ chấm
  không hồi quy. Lần ráp cuối nay là thao tác đã diễn tập, chỉ
  còn cộng phần L-R + nâng dấu bản + build.
- **Chưa chứng minh:** (a) catalog 69 mục CHƯA được biên dịch —
  không có swiftc/Xcode tại bàn, kiểm Swift chỉ ở mức ngoặc +
  đối chiếu kê khai (giới hạn quen thuộc của mọi gói bench);
  biên dịch + nạp tài nguyên chỉ phán ở build bench cuối (cloud).
  (b) Diễn tập chưa gồm phần L-R (chưa có ảnh) và chưa nâng
  appBuild — hai việc đó thuộc lần ráp cuối theo thiết kế.
- **Chưa làm / vẫn chặn buổi đo:** 10 ca thật L-R chờ anh gửi;
  §3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn chưa về;
  B-04/B-05 chưa chốt tên (phụ thuộc ca thật của buổi đo). Buổi
  đo CHƯA đủ điều kiện — ca này không kêu anh cài/test gì.

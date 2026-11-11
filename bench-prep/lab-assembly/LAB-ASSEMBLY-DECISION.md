# QUYẾT CHỐT LẦN RÁP LAB — 2 ĐIỂM MỞ CỦA GÓI LAB-STAGING ĐÃ ĐÓNG (2026-11-11, ca trực 12:40 CST)

Vai trò: **Leader chốt** — văn bản này đóng 2 điểm mở mà sổ
`bench-prep/lab-staging/LAB-STAGING-LEDGER.md` (ca 06:40 CST) ghi
rõ "KHÔNG tự quyết, để Leader chốt ở lần ráp": (1) enum `origin`
không có chỗ cho ca lab; (2) ánh xạ `form`/`difficulty` cho 4 tầng
LONG/DENSE/LOWRES/TALL chưa đóng băng. Việc độc lập làm trong lúc
chờ 10 ảnh thật (L-R) và luồng OCR gốc trên máy — mục tiêu: lần
ráp bản bench cuối (bước 0 buổi chuẩn bị) chỉ còn thao tác cơ học,
không còn quyết nào phải bịa ra dưới áp lực.

Bằng chứng đọc trực tiếp trong ca (không dùng lời tóm tắt):
- `bench-prep/BENCH-JSON-SPEC.md` §3 (origin chỉ có real/synthetic)
  + §6 (luật phiên bản: thuần cộng → giữ số).
- `bench-prep/bench_score.py`: `weight_of`/`is_hard_real` chỉ cho
  ×2 khi origin == "real" (mọi origin khác đã ×1); vòng chấm cũ
  đòi đáp án GT cho MỌI ảnh — ca lab không có GT dạng sổ sẽ sinh
  lỗi "không có đáp án" và lớp rỗng trong bảng điểm.
- `benchapp/BenchCatalog.swift` + `BenchModels.swift`: `origin`,
  `form`, `difficulty`, `gtID` đều là **chuỗi thuần** ở cả catalog
  lẫn DTO JSON — không enum Swift nào phải sửa.
- `benchapp/BenchRunner.swift`: mọi ảnh `availableImages` đều chạy
  × A0–A3 và vào cùng 1 file JSON — ca lab nhúng vào sẽ có mặt
  trong file đo, nên bộ chấm phải xử lý chúng tường minh.
- `bench-prep/measure-pack/scoresheet.csv`: 24 dòng W **đã dùng
  origin `lab`** từ ca 04:40 (đường chấm `tai-bang`, hồ sơ LAB,
  form/difficulty để `-`) — quy ước "lab" đã tồn tại ở gói đo;
  đặc tả JSON là phía chưa theo kịp.

## QUYẾT 1 — origin của ca lab = `lab` (mở enum, giữ schema_version 1)

- `BENCH-JSON-SPEC.md` §3: enum `origin` cộng thêm `lab` (ảnh hoá
  đơn thật của bộ dữ liệu lab — làn độ bền). Mục 6.6 mới ghi lịch
  sử + phân loại thay đổi: **thuần cộng** theo luật §6.3 — file đo
  cũ đọc/chấm y hệt; giá trị mới chỉ có ở file đo mới →
  `schema_version` **giữ nguyên 1**, không tăng số.
- Ca lab mang `gt_id = ""` (rỗng, đúng quy ước ô chưa có GT trong
  catalog hiện hành) — đáp án của chúng là **nhãn nguyên văn** ở
  `lab-wildreceipt/wildreceipt-subset.csv` phía đội, không phải
  một GT trong sổ đáp án của bộ chấm.
- **Bộ chấm đã sửa trong ca này** (`bench_score.py`, chỉ ở tầng
  bench-prep — không đụng Swift/pipeline của app): run có
  origin `lab` được **đếm + liệt kê ở mục LÀN LAB rồi bỏ qua** —
  không vào lớp (layer), không trọng số, không phán quyết §5.4,
  không sinh lỗi thiếu đáp án. Cách chấm ca lab giữ nguyên như đã
  khoá: **tay, theo hồ sơ LAB** (M1/M2 đúng-hoặc-cờ đối chiếu nhãn
  nguyên văn + E1/E2 đẳng thức nội bộ; M9 vẫn phủ: số sai không
  cờ là bằng chứng chống lại bản, ghi vào báo cáo buổi đo).
- Hệ quả đã kiểm: khi file đo không có ca lab nào, đầu ra của bộ
  chấm **byte-trùng** trước khi sửa (verifier mục dưới, nhóm 5).

## QUYẾT 2 — form/difficulty của 24 ca W (chỉ mang tính mô tả)

Trục khó L0–L5 của schema được định nghĩa cho hoá đơn của anh;
4 tầng lab là trục chọn mẫu khác hẳn, không ánh xạ 1-1 được một
cách trung thực. Vì Quyết 1 đã loại ca lab khỏi mọi cổng/trọng
số/lớp, hai trường này trong file đo của ca lab **chỉ là siêu dữ
liệu mô tả** — không con số nào của buổi đo phụ thuộc chúng.
Ánh xạ chốt theo trục đo được gần nhất, ghi kèm tầng gốc trong
`statusNote` của từng mục catalog để không ai đọc nhầm thành
tuyên bố độ khó thật:

- **form = `C` cho cả 24 ca**: ảnh WildReceipt là hoá đơn giấy
  chụp ngoài đời (đúng bản chất dạng C của C-003); BenchApp nạp
  từ bundle chỉ là đường nạp, không đổi bản chất dạng.
- **LOWRES → `L4`** (trục khớp nguyên văn: L4 = phân giải thấp;
  tầng này chọn theo bề ngang ảnh nhỏ nhất, 235–275 px).
- **LONG → `L5`** (trục độ dài: tầng này chọn theo số dòng món
  nhiều nhất, 15–20 dòng — cực trị độ dài *trong làn lab*; không
  đồng nghĩa ca L5 thật ≥40 dòng của anh).
- **TALL → `L5`** (trục độ dài: tỉ lệ cao/ngang 1.77–2.07, cực
  trị hình học dài trong làn lab).
- **DENSE → `L4`** (chữ nhỏ/dày: chiều cao hộp chữ trung vị 9 px
  ở 5/6 ca — độ phân giải hiệu dụng trên từng ký tự thấp, gần
  trục L4 nhất; tầng gốc DENSE ghi ở statusNote để giữ sự thật).

| Ca | Tầng gốc | form | difficulty | Ca | Tầng gốc | form | difficulty |
|---|---|---|---|---|---|---|---|
| W-01 | LONG | C | L5 | W-13 | LOWRES | C | L4 |
| W-02 | LONG | C | L5 | W-14 | LOWRES | C | L4 |
| W-03 | LONG | C | L5 | W-15 | LOWRES | C | L4 |
| W-04 | LONG | C | L5 | W-16 | LOWRES | C | L4 |
| W-05 | LONG | C | L5 | W-17 | LOWRES | C | L4 |
| W-06 | LONG | C | L5 | W-18 | LOWRES | C | L4 |
| W-07 | DENSE | C | L4 | W-19 | TALL | C | L5 |
| W-08 | DENSE | C | L4 | W-20 | TALL | C | L5 |
| W-09 | DENSE | C | L4 | W-21 | TALL | C | L5 |
| W-10 | DENSE | C | L4 | W-22 | TALL | C | L5 |
| W-11 | DENSE | C | L4 | W-23 | TALL | C | L5 |
| W-12 | DENSE | C | L4 | W-24 | TALL | C | L5 |

Bảng chấm đóng băng (`measure-pack/scoresheet.csv`) giữ nguyên:
cột form/difficulty của dòng W là `-` vì đường chấm `tai-bang`
không dùng hai trục đó — không mâu thuẫn với bảng trên (bảng trên
chỉ áp cho siêu dữ liệu catalog/JSON ở lần ráp).

## Công thức ráp ở bước 0 buổi chuẩn bị (thuần cơ học từ nay)

Với mỗi ca W-nn: (1) chép `lab-staging/images/W-nn.jpg` →
`benchapp/BenchImages/W-nn.jpg` (đối chiếu manifest staging);
(2) thêm 1 mục `BenchCatalog` với id `W-nn`, form/difficulty theo
bảng trên, `origin: "lab"`, `gtID: ""`, `sourceFile:` = đường dẫn
corpus nguyên văn trong `wildreceipt-subset.csv`,
`resourceName: "W-nn"`, `statusNote:` ghi tầng gốc + "LAB — chấm
tay hồ sơ LAB, không GT, không cổng"; (3) thêm 1 dòng sources
`BenchImages/W-nn.jpg` vào `project.yml`. Không sửa bộ chấm,
không sửa đặc tả, không quyết thêm gì ở bước đó.

## Kiểm chứng trong ca (verifier độc lập)

`verify_lab_assembly.py` + `verify-lab-assembly-results.txt`:
kiểm ánh xạ 24/24 khớp tầng gốc trong bảng kê đóng băng · trọng
số ca lab ×1 ở mọi difficulty + không phải lớp-khó-thật ·
file đo trộn (selftest thật + 2 ca lab mang dòng rác) chấm ra:
ca thật giữ nguyên kết quả, ca lab chỉ xuất hiện ở mục LÀN LAB,
0 lỗi thiếu đáp án, phán quyết không đổi · đặc tả đã chứa `lab`
+ giữ schema_version 1 · scoresheet 24/24 dòng W origin lab ·
hồi quy selftest byte-trùng file đã lưu.

## Tuyên bố trung thực 3 phần

- **Đã chứng minh:** 2 điểm mở đã có quyết tường minh, nhất quán
  với mọi tài liệu đã đóng băng (scoresheet vốn đã dùng `lab`);
  hành vi bộ chấm với ca lab đã được kiểm bằng file đo trộn chạy
  thật tại bàn; đầu ra với file không-lab byte-trùng trước sửa —
  ở mức file/script tại bàn.
- **Chưa chứng minh:** (a) BenchApp với 24 mục W **chưa được
  build** — biên dịch + nạp tài nguyên chỉ phán ở build bench
  cuối; ca này không đụng Swift nên không có gì mới để build;
  (b) ánh xạ difficulty ở Quyết 2 là quy ước mô tả của Leader,
  không phải đo lường độ khó — buổi đo không được trình nó như
  phân lớp độ khó thật; (c) cách chấm tay hồ sơ LAB chưa từng
  được dùng ở buổi đo thật nào.
- **Chưa làm / vẫn chặn buổi đo:** 24 ảnh lab CHƯA nhúng
  BenchApp (đúng thiết kế: ráp ở bản bench cuối cùng nhịp L-R);
  10 ca thật L-R chờ anh gửi; §3.5(3) luồng OCR gốc trên máy của
  Sam's run #26 vẫn chưa về; B-04/B-05 chưa chốt tên. Buổi đo
  CHƯA đủ điều kiện — ca này không kêu anh cài/test gì.

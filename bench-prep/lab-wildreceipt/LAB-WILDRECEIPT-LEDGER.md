# SỔ LAB — TẬP CON KHÓ WildReceipt ĐÃ CHỌN + ĐÓNG BĂNG (2026-11-11, ca trực 02:40 CST)

Việc độc lập làm trong lúc chờ 10 ảnh thật (L-R) và luồng OCR gốc
trên máy — lấp mục còn thiếu của điều kiện chặn buổi đo
`core-redo/ACCEPTANCE.md` §3.5(2): **"danh sách ca lab WildReceipt
đã chọn"** theo đúng tiêu chí §3.1. Trước ca này danh sách đó
CHƯA HỀ TỒN TẠI (chỉ có chủ trương chọn ở §3.1 và số đo toàn bộ
test 472 ở CORPUS.md).

## Đã làm
- `select_wildreceipt.py` — bộ chọn xác định (không random, mọi
  sắp xếp có khoá phụ file_name), công thức dịch nguyên văn §3.1:
  - **Cửa cứng §3.1:** có nhãn Total + Date + Subtotal; cộng cửa
    Item + Price (điều kiện để chấm được đẳng thức nội bộ E1 trên
    máy: Σ món app đọc đối chiếu subtotal app đọc).
  - **Loại trùng giao dịch** trước khi xếp hạng bằng khoá mờ
    (ngày-chỉ-số bằng nhau + tập xu subtotal giao nhau + tên tiệm
    giống ≥0.75; hoặc tên tiệm bằng + ngày + total giao nhau).
    Khoá mờ là BẮT BUỘC vì nhãn dataset có bản chụp lại cùng một
    giao dịch mà nhãn lệch nhau — bằng chứng đọc trực tiếp trong
    ca: ElBorracho total `£136.5` vs `£136.95`, `ILIO'S` vs
    `ILTO'S` cùng subtotal `Eur129,75` cùng ngày `10.07.13`.
  - **Cửa độ khó:** tổng hộp chú thích ≥35 và dòng món ≥4.
  - **4 tầng × 6 ca = 24:** LONG (nhiều dòng món nhất) · DENSE
    (chiều cao hộp trung vị nhỏ nhất — chữ nhỏ/dày) · LOWRES
    (bề ngang ảnh nhỏ nhất) · TALL (tỉ lệ cao/ngang lớn nhất);
    chọn tham lam theo thứ tự tầng cố định, không tờ nào dùng
    hai lần.
- `wildreceipt-subset.csv` — bảng kê đóng băng 24 ca W-01…W-24:
  file + sha256 + byte-size + kích thước + số hộp/món/giá/số
  lượng + chiều cao chữ trung vị + tỉ lệ khung + **đáp án nhãn
  nguyên văn** (tiệm · ngày · subtotal · thuế · tips · total,
  theo thứ tự đọc) + cột cách chấm cố định từng ca.
- `verify_wildreceipt_subset.py` (verifier độc lập, không import
  selector) + `verify-wildreceipt-results.txt`: **PASS 8/8 nhóm**
  — 24 dòng/mã liên tục · 4 tầng ×6 đúng thứ tự · sha256+byte
  khớp đĩa 24/24 · mọi ca qua cửa (đếm lại từ test.txt) · văn
  bản nhãn khớp từng ký tự · cột số khớp đếm lại · 0 cặp trùng
  giao dịch · chạy lại selector cho CSV **byte-trùng**.

## Số đo phễu lọc (selection-results.txt)
472 test → phủ nhãn Total **423** · Date **398** · Subtotal
**343** (khớp đúng từng số ACCEPTANCE §3.1/CORPUS.md công bố —
đối chiếu chéo độc lập) → giao 3 cửa **266** → +Item/Price
**255** → sau loại trùng **247** (loại 8 bản thuộc 7 nhóm) →
qua cửa độ khó **109** → chọn **24**.
Độ khó của tập đã chọn so với tập đủ điều kiện sau trùng: hộp
chú thích trung vị **60.5 vs 39**; dòng món trung vị **8.5 vs 4**.

## Cách chấm các ca này (khoá theo §3.1, ghi sẵn trong CSV)
M1/M2 dạng **đúng-hoặc-cờ** đối chiếu nhãn nguyên văn + E1/E2
dạng **đẳng thức nội bộ** (số app đọc đối chiếu lẫn nhau). Kỷ
luật M9 giữ nguyên: một ca lab ra số sai không cờ là bằng chứng
chống lại bản, phải ghi vào báo cáo buổi đo. **Không bao giờ**
trình kết quả làn này như "sổ món đạt" — nhãn WildReceipt không
cho sổ món ngoài đáng tin.

## Tuyên bố trung thực 3 phần
- **Đã chứng minh:** danh sách 24 ca khó đã chọn + đóng băng ở
  tầng file/bảng kê — thuật toán xác định tái lập byte-trùng,
  đáp án nhãn trích nguyên văn kiểm từng ký tự, ảnh khớp
  sha256 trên đĩa. Phần "danh sách ca lab" của §3.5(2) NAY ĐỦ.
- **Chưa chứng minh / ghi rõ giới hạn:** (a) độ khó chỉ khẳng
  định trên 4 trục đo được từ nhãn + hình học ảnh (dài · chữ
  nhỏ · nét thấp · tờ dài) — nhăn/mờ/phai THẬT của các ảnh này
  KHÔNG đo được từ nhãn và ca này không khẳng định; (b) nhãn
  WildReceipt có nhiễu thật đã đọc thấy: W-01 subtotal £151.95
  > total £136.5 (số học nhãn không tự khép), W-15 total
  `197.285` ba số lẻ, W-08 số tiền không phần lẻ, W-24 hai giá
  trị subtotal khác nhau — vì vậy cột `*_cents_first` trong CSV
  CHỈ là giá trị phân tích đầu tiên phục vụ khoá trùng/tham
  chiếu, KHÔNG phải đáp án tiền; đáp án có quyền là văn bản
  nhãn nguyên văn; (c) nhiều ca là hoá đơn ngoài Mỹ (tiền tệ/
  định dạng ngày khác) — đúng vai trò làn độ bền, không đại
  diện phân bố hoá đơn Mỹ của anh; (d) các ca này chỉ kiểm được
  **trên máy** (T1→T4) — tại bàn kiểm được 0, chưa ca nào chạy
  qua app.
- **Chưa làm / vẫn chặn buổi đo:** 24 ảnh lab CHƯA nhúng vào
  BenchApp/BenchCatalog (việc ráp bản bench cuối, cùng nhịp
  với L-R — ca này không đụng Swift); §3.5(2) vẫn thiếu 10 ca
  thật L-R (chờ anh gửi); §3.5(3) luồng OCR gốc trên máy của
  tờ Sam's run #26 VẪN chưa về. Buổi đo CHƯA đủ điều kiện —
  ca này không kêu anh cài/test gì.

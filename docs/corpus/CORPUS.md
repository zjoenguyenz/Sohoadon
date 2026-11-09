# CORPUS — DANH MỤC BỘ MẪU CHẤM ĐIỂM (lập 2026-11-09, ca trực sohoadon-build2-247)

Tài liệu này thực hiện mục 3 hàng việc của WORK-STATE (Master Plan §3.3):
chuẩn bị corpus = tải + kiểm chứng bộ WildReceipt/CORD/SROIE (làn lab) và
lập danh mục mẫu theo 7 loại hình cho hoá đơn thật của anh.

**Luật bất di bất dịch (Master Plan §3.1/§3.3, SCORECARD.md):** cổng phát
hành là 3 mẫu hạt giống của anh (001/002/003). Làn lab CHỈ đo độ bền, không
bao giờ là điểm cổng. Ảnh dataset không nhúng vào app; chỉ dùng nội bộ theo
giấy phép của từng bộ. Mọi con số dưới đây là SỐ ĐO THẬT trên file đã tải
trong ca 2026-11-09 06:40 CST — chỗ nào khác số công bố của tác giả thì ghi
cả hai, không làm tròn theo quảng cáo.

---

## A. LÀN LAB — 3 BỘ DỮ LIỆU CÔNG KHAI (đã tải + kiểm chứng)

### A1. WildReceipt — ĐÃ TẢI TOÀN BỘ ✓ (giống điều kiện Mẫu 003 nhất)
- Nguồn chính thức dùng để tải: máy chủ OpenMMLab (MMOCR) —
  `https://download.openmmlab.com/mmocr/data/wildreceipt.tar`
  (URL lấy từ script tải của bản Hugging Face Theivaprakasham/wildreceipt,
  lưu ở `_sources/wildreceipt-script.py` dòng 38).
- File local: `corpus/lab/wildreceipt/wildreceipt.tar` + đã giải nén ở
  `corpus/lab/wildreceipt/extracted/wildreceipt/`.
- Kiểm chứng: HTTP 200 · **185,323,520 byte** (khớp đúng Content-Length
  máy chủ công bố) · sha256
  `f47646e16033d95c85a0b3a180a39d90cc354a729e51a280211b2fe7cae532bd`.
- Số đo thật trong tar: **train.txt 1,267 dòng · test.txt 472 dòng ·
  tổng 1,739 tờ có nhãn**; tổng **72,485** hộp chú thích; `class_list.txt`
  26 mục (0=Ignore + 25 lớp: Store_name, Store_addr, Tel, Date, Time,
  Prod_item/quantity/price, Subtotal, Tax, Tips, Total…); ảnh trên đĩa
  1,769 file (1,765 jpeg + 2 png + 1 gif + 1 txt).
- Lệch so với công bố (ghi trung thực): bài báo/TOP-APPS-RESEARCH ghi
  1,740 tờ (train 1,268) và ~69K hộp — bản phân phối MMOCR đo được 1,739
  dòng nhãn (train 1,267) và 72,485 hộp. Chênh 1 tờ train; dùng số đo thật
  của bản đã tải khi chấm, không dùng số bài báo.
- Độ phủ trường trên test (472 tờ, đo từ nhãn): tên tiệm **472/472** ·
  ngày **398/472** · subtotal **343/472** · thuế **318/472** · tổng
  **423/472** → chấm được 4 ô tiệm/ngày/tổng/món trên phần lớn test split.
- Giấy phép: Apache-2.0 (thẻ dataset HF ghi license apache-2.0; MMOCR
  cũng Apache-2.0). Dùng nội bộ làn lab.

### A2. CORD (v1) — ĐÃ TẢI TEST SPLIT ✓ · train/validation CHƯA tải (có chủ đích)
- Nguồn chính thức: NAVER CLOVA — GitHub `clovaai/cord` (README gốc lưu ở
  `_sources/cord-README-raw.md`, huy hiệu CC BY 4.0 ở đầu file) + Hugging
  Face `naver-clova-ix/cord-v1` (API lưu ở `_sources/cord-v1-hf-api.json`:
  gated=false, license cc-by-4.0).
- Quy mô toàn bộ (HF datasets-server, `_sources/cord-v1-size.json`):
  **1,000 dòng = train 800 / validation 100 / test 100** — khớp đúng số
  công bố của TOP-APPS-RESEARCH §4. Tổng parquet 2,307,280,303 byte.
- File local: `corpus/lab/cord-v1/cord-v1-test.parquet` — **234,201,893
  byte** (khớp X-Linked-Size HF công bố) · sha256
  `f223e444f0e5d44a053afcaafb23bfed161cbf66e13ee1060ae797ea6061b388`.
- Kiểm chứng bằng pyarrow 26.0.1: **đúng 100 dòng**; schema
  `image{bytes,path} + ground_truth (JSON)`; ảnh dòng 0 là PNG thật
  (magic 89504e47, 338,392 byte); cỡ ảnh 89,977–17,240,894 byte/dòng.
- Độ phủ nhãn test (đo từ `gt_parse`): menu **100/100** · khối sub_total
  **66/100** · total.total_price **95/100**; 30 loại trường (menu.*, 
  sub_total.*, total.*…) → đúng vai trò stress-test bóc tách cấp dòng.
- CHƯA tải: train (1,830,986,933 byte parquet) + validation
  (242,091,477 byte) — làn lab chỉ cần test split để đo; khi WP4 cần thêm
  thì tải từ đúng nguồn trên, không tìm nguồn lạ.
- Lưu ý đã biết (TOP-APPS-RESEARCH §4): hoá đơn Indonesia; một số bản phái
  sinh che vendor/date — bản HF chính thức này giữ `gt_parse` đầy đủ như
  đo ở trên. Giấy phép: **CC BY 4.0**.

### A3. SROIE — ĐÃ TẢI BẢN CỘNG ĐỒNG ✓ (kèm cảnh báo nguồn gốc)
- Bản chính thức: ICDAR 2019 Robust Reading Challenge — kênh phát hành
  gốc của ban tổ chức (cần đăng ký/điều kiện cuộc thi; TOP-APPS-RESEARCH
  §4). Ca này KHÔNG tải từ kênh gốc.
- Bản đã tải: qua script của HF `darentang/sroie` (lưu ở
  `_sources/sroie-darentang-script.py`) trỏ tới 1 file Google Drive công
  khai; tải ngày 2026-11-09 sau trang xác nhận của Drive.
- File local: `corpus/lab/sroie/sroie-hf-darentang-drive.zip` —
  **455,664,162 byte** · sha256
  `860621031662886fb77dbb5d554fb9e37dad380decf8341d8e75363c184c1fc4`.
- Số đo thật trong zip: **973 ảnh JPG + 973 file nhãn JSON, mọi basename
  đều duy nhất — train 626 / test 347** (khớp bộ số 626/347 của SROIE như
  ghi trong tài liệu FiftyOne; tổng 973 khớp TOP-APPS-RESEARCH §4).
- Dạng nhãn: bản ĐÃ QUA XỬ LÝ NER (words + bbox + labels
  COMPANY/DATE/ADDRESS/TOTAL dạng B-/I-), không phải file khoá gốc của
  Task 3 ICDAR. Độ phủ test: cả 4 trường có mặt ở **347/347** tờ.
- ⚠️ TRUNG THỰC NGUỒN GỐC/GIẤY PHÉP: thẻ HF của `darentang/sroie` ghi
  license = (trống). Đây là bản cộng đồng truyền tay qua Drive — chỉ dùng
  nội bộ làm bài test khói 4 trường (tiệm/ngày/địa chỉ/tổng) đúng vai trò
  Master Plan giao; KHÔNG khẳng định giấy phép, KHÔNG phân phối lại. Nếu
  sau này cần trích dẫn công khai, phải lấy bản gốc từ ICDAR.
- Ghi chú phụ: GitHub API khi tra `clovaai/cord` trả 403 rate-limit (lưu ở
  `_sources/cord-github-api.json`) — đã đi đường khác bằng README qua raw + HF API,
  kết luận không dựa vào lần tra lỗi đó.

### Cách dùng làn lab (chốt cho WP4)
- WildReceipt test (472) = đo độ bền đọc ảnh chụp đời thật (vai Mẫu 003).
- CORD test (100) = stress-test parser cấp dòng (menu/subtotal/total).
- SROIE test (347) = test khói 4 trường tiệm/ngày/địa chỉ/tổng.
- Điểm làn lab KHÔNG bao giờ thay điểm cổng 001/002/003 (SCORECARD.md).

---

## B. CORPUS HOÁ ĐƠN THẬT CỦA ANH — DANH MỤC 7 LOẠI HÌNH (Master Plan §3.3)

Luật vào bộ: mỗi mẫu mới phải có đáp án chuẩn kiểm số học bằng tay TRƯỚC
khi vào bộ (như 001/002/003 đã làm). Mẫu chưa có đáp án chuẩn = chưa vào.

| # | Loại hình | Đặc điểm phải có trong bộ | Đã có | Còn thiếu |
|---|---|---|---|---|
| 1 | Nhà hàng | dòng tip + bẫy Suggested Tip | — 0 | toàn bộ (chờ hoá đơn thật của anh) |
| 2 | Chợ / siêu thị thực phẩm | nhiều dòng món, thuế theo nhóm hàng | — 0 | toàn bộ |
| 3 | Cây xăng | thuế = 0 (tính trong giá) | — 0 | toàn bộ |
| 4 | Hiệu thuốc | — | — 0 | toàn bộ |
| 5 | Big-box / đồ gia dụng | Home Depot ✓ · Lowe's · Best Buy | **003** Home Depot (giấy nhàu, TOTAL 105.16) | Lowe's; **Best Buy — chờ anh gửi khi tiện** (điểm chờ đã ghi ở WORK-STATE) |
| 6 | Kho sỉ | Sam's ✓ · Costco | **001** Sam's (ảnh app, TOTAL 216.80) + **002** Sam's (file tải về, TOTAL 216.80) | Costco |
| 7 | Hoá đơn online tải về (PDF) | PDF có lớp chữ (Amazon Order ID, Best Buy…) | — 0 PDF thật (002 là JPG render của hoá đơn tải về, không phải PDF) | **PDF Sam's — chờ file của anh** (điểm chờ WP3); PDF Amazon/Best Buy |

- Mẫu 002-C (chụp camera thật cùng tờ Sam's) KHÔNG thuộc mục này — lập ở
  WP4 theo Master Plan §3.1, vẫn chưa tồn tại.
- Hàng chờ anh (không chặn việc khác): file PDF Sam's + 1 hoá đơn Best
  Buy tải về — trùng điểm chờ đã ghi ở WORK-STATE, không phát sinh mới.

---

## C. TỜ KHAI TRUNG THỰC CỦA CA NÀY
- [ĐÃ KIỂM] Cả 3 bộ đều đã tải thật về `corpus/lab/` trong ca này; mọi số
  lượng/byte/sha256 ở trên đều đo từ file local hoặc API chính thức, có
  file bằng chứng ở `corpus/_sources/` (JSON API + README gốc + 2 script
  tải). Tổng dung lượng corpus trên đĩa: ~1.0 GB (đo bằng `du`).
- [ĐÃ KIỂM] Không bộ nào bị tính là "điểm cổng": SCORECARD.md chỉ bổ sung
  dòng nhật ký + số đo làn lab, luật qua cổng không đổi.
- [CHƯA KIỂM CHỨNG] Chưa chạy engine/parser nào trên làn lab trong ca này
  — đó là việc của WP4 (thi đấu engine), không phải của bước chuẩn bị
  corpus. Danh mục này chỉ khẳng định dữ liệu ĐÃ SẴN SÀNG và ĐÚNG NGUỒN
  như ghi ở từng mục.
- [GHI RÕ] CORD mới tải test split (100/1,000 dòng) — ghi là một phần,
  không ghi "đã tải CORD toàn bộ". SROIE là bản cộng đồng (xem cảnh báo
  A3), không ghi là bản ICDAR chính thức.

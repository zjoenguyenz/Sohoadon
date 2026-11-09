# BẢNG ĐIỂM HOÁ ĐƠN — SCORECARD (đóng băng tại WP0, 2026-11-09)
Đây là thước đo vĩnh viễn của dự án. Mọi engine/bản build đều chấm trên
đúng bộ mẫu này. Nguồn điểm nền: QA-VERDICT Phụ lục B §0.3 + Master Plan §3.1
(đáp án chuẩn đã kiểm số học độc lập 2 lần: Wally + Trưởng nhóm Mission 1).

## Luật qua cổng (không đổi)
Build chỉ qua cổng khi: **tổng + ngày ĐÚNG trên cả 3 mẫu hạt giống, và không
một con số sai nào được trình bày mà không gắn cờ.** Điểm % tổng không dùng
làm mục tiêu (Master Plan §5.8).

## Mẫu hạt giống — đáp án chuẩn & điểm nền Build 1
| Mẫu | Dạng | Đáp án chuẩn | Build 1: Tiệm | Ngày | Tổng | Món |
|---|---|---|---|---|---|---|
| 001 | Ảnh chụp màn hình app Sam's (số) | Sam's Club · 2026-10-29 17:49 · TOTAL 216.80 · 10 dòng, Σ dòng 203.30, thuế 9.60+3.90, 15 món | — chưa đo trên máy | — | — | — |
| 002 | File Sam's tải về (JPG 554×1457) | SUBTOTAL 203.30 · TAX 1: 9.60 · TAX 2: 3.90 · TOTAL 216.80 · 10 dòng · 15 món · khoá TC# | ✓ | ✓ | ✗ (có cờ ✓ kỷ luật) | ✗ (0 tiền món) |
| 003 | Home Depot giấy nhàu, chụp thường | The Home Depot · 03/03/2025 12:59 · SUBTOTAL 96.91 · TAX 8.25 · TOTAL 105.16 · Visa ••3830 | ✗ (KHÔNG cờ — vi phạm tinh thần cổng) | ✓ | ✗ (có cờ ✓) | ✗ |

Ghi chú Mẫu 001: prototype trên bản chép chữ đạt 100% (chứng minh luật đọc),
nhưng Build 1 CHƯA từng chạy mẫu này trên máy — ghi CHƯA KIỂM CHỨNG, không
được tính là đạt. Mẫu 002-C (chụp camera thật cùng tờ Sam's) sẽ lập ở WP4.

## Nghiệm thu chi tiết §F cho Mẫu 002 (ràng buộc, từ CODE-AUDIT §F)
Đọc tự động, không nhập tay: **10 dòng món · 203.30 · 9.60 · 3.90 · 216.80 ·
15 món · khoá chống trùng TC#**. Thiếu bất kỳ số nào = finding còn mở, và
phải dùng cửa chẩn đoán F3 (WP1) để chỉ rõ số mất ở tầng nào trước khi sửa.

## Làn lab (chỉ đo độ bền — KHÔNG BAO GIỜ là điểm cổng)
- **WildReceipt**: 472 tờ test — hoá đơn Mỹ chụp ngoài đời (giống Mẫu 003 nhất).
- **CORD**: stress-test bóc tách cấp dòng (CC BY 4.0).
- **SROIE**: test khói 4 trường tiệm/ngày/địa chỉ/tổng (điều kiện ICDAR).
- **Trạng thái chuẩn bị (2026-11-09, ca 06:40 CST — chi tiết: corpus/CORPUS.md):**
  WildReceipt ĐÃ TẢI toàn bộ bản MMOCR (test 472/train 1,267 tờ có nhãn,
  72,485 hộp, sha256 ghi ở CORPUS.md) · CORD v1 ĐÃ TẢI test split (100 tờ,
  kiểm bằng pyarrow; train/validation chưa tải, có chủ đích) · SROIE ĐÃ
  TẢI bản cộng đồng (973 tờ = train 626/test 347, 4 trường phủ 347/347 ở
  test; KHÔNG phải bản ICDAR chính thức — xem cảnh báo CORPUS.md A3).
  Chưa chạy chấm engine nào trên làn lab — việc đó thuộc WP4.
Lý do tách làn: điểm trên corpus lạ không giống điều kiện thật thì là điểm
dối (bằng chứng 88% → 51%, TOP-APPS-RESEARCH §2.12). Ảnh dataset không nhúng
vào app; chỉ dùng nội bộ theo giấy phép của từng bộ.

## Corpus hoá đơn thật của anh — mở rộng theo loại hình (Master Plan §3.3)
Mỗi mẫu mới phải có đáp án chuẩn kiểm số học bằng tay trước khi vào bộ:
nhà hàng (tip + bẫy Suggested Tip) · chợ/siêu thị thực phẩm · cây xăng
(thuế 0, tính trong giá) · hiệu thuốc · big-box/đồ gia dụng (Home Depot ✓,
Lowe's, Best Buy — đang chờ mẫu) · kho sỉ (Sam's ✓, Costco) · hoá đơn online
tải về (PDF Amazon/Best Buy…).

## Nhật ký chấm điểm (ca trực/bản build ghi tiếp vào đây)
| Ngày | Đối tượng chấm | 001 | 002 | 003 | Ghi chú |
|---|---|---|---|---|---|
| 2026-11-08 | Build 1 (nền) | chưa đo | tiệm✓ ngày✓ tổng✗cờ món✗ | tiệm✗không cờ ngày✓ tổng✗cờ món✗ | Điểm nền đóng băng tại WP0 |
| 2026-11-09 | WP0 — QA ký nhận thứ tự gói | — | — | — | QA ✓ ký nhận thứ tự WP1→WP9 (Master Plan §5.0); văn bản: WP0-QA-SIGNOFF.md. WP0 qua cổng, mở WP1 |
| 2026-11-09 | WP1 — code F3 chuẩn bị tới cổng | — | — | — | Không chấm điểm (WP1 không đổi khả năng đọc). Code ở wp1-prep/ (diff +39/−0), đủ Design ✓ / Code ✓ / QA ✓ nội bộ; chờ anh duyệt đẩy + cài máy chụp màn hình mới nghiệm thu. Văn bản: WP1-GATE.md |
| 2026-11-09 | Corpus — chuẩn bị làn lab (mục 3 hàng việc) | — | — | — | Không chấm điểm (chuẩn bị dữ liệu, chưa chạy engine). Đã tải + kiểm chứng WildReceipt/CORD-test/SROIE với byte/sha256/số dòng đo thật; danh mục 7 loại hình hoá đơn thật lập ở corpus/CORPUS.md (đã có: kho sỉ 001/002, big-box 003; 5 loại còn trống chờ hoá đơn thật) |

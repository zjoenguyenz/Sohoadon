# WP-EXPORT — Đặc tả gói XUẤT BẢN GỐC CHO KẾ TOÁN

Lệnh của anh: 2026-11-10 12:43 CST ("App phải có chức năng trích
toàn bộ bản gốc cho từng loại hoá đơn theo năm, hoặc theo thời
gian tự chọn. Ví dụ: toàn bộ hoá đơn gốc cho thẻ business từ
10/2025 tới 11/2026. Xuất thành file để tải về hoặc email cho
kế toán.").

Trạng thái: ĐẶC TẢ XONG 2026-11-10 12:52 CST. Code chỉ bắt đầu
sau khi IMGFIX (run #22) được anh nghiệm — nền file ReceiptViews
lấy từ imgfix/, ContentView lấy từ bản main hiện hành (wp3-prep).

## 1. Phạm vi

Màn "Xuất bản gốc cho kế toán" đặt trong tab **Báo Cáo Thuế**
(ContentView.swift). Người dùng chọn:
- **Loại:** Business · Cá nhân · Tất cả (phân loại lấy từ
  `classification` đã lưu của từng tờ; tờ `unknown` chỉ vào
  "Tất cả" và bị ghi chú "chưa phân loại" trong mục lục).
- **Thời gian:** theo **năm** (chọn năm) hoặc **khoảng tuỳ chọn**
  (từ ngày – đến ngày). Lọc theo `receipt.date` (ngày hoá đơn),
  gồm cả hai đầu khoảng.
Trước khi xuất, app hiện: **số tờ khớp · tổng tiền · số tờ thiếu
bản gốc**. Bấm xuất → tạo **một file ZIP** → ShareLink (lưu
Files / đính kèm email / AirDrop).

## 2. Nội dung ZIP

- Mỗi tờ có bản gốc nạp được: file gốc nguyên byte (JPEG/PDF từ
  ImageStore), tên trong ZIP:
  `yyyy-MM-dd_<Tiệm>_<Tổng tiền>.<ext>` — Tiệm bỏ dấu/ký tự lạ,
  Tổng dạng `105.16`; trùng tên → hậu tố `-2`, `-3`.
  Tờ có nhiều file gốc (originalImageFileNames > 1): file chính
  theo imageFileName, các file phụ thêm hậu tố `-trang2`…
- `muc-luc.csv` (UTF-8 BOM cho Excel): cột
  `Ngày,Tiệm,Loại,Mục,Tạm tính,Thuế,Tổng,Thẻ 4 số,File bản gốc,Ghi chú`
  — dòng của tờ thiếu bản gốc: cột File để trống, Ghi chú
  "THIẾU BẢN GỐC". Cuối file: dòng TỔNG cộng tiền theo đúng bộ lọc.
- Tên ZIP: `BanGoc-<Loai>-<tu>-<den>.zip`
  (vd `BanGoc-Business-2025-10-01-2026-11-30.zip`).

## 3. Luật cứng

- Chỉ ĐỌC dữ liệu đã lưu, không sửa bản ghi nào (Điều 2 B2 ở
  chiều ngược: xuất không được làm thay đổi kho).
- Tờ thiếu bản gốc: KHÔNG lặng lẽ bỏ qua — đếm trước khi xuất,
  ghi trong mục lục, và dòng tổng kết trong màn hình xuất.
- ZIP ghi kiểu store (không nén thêm; JPEG/PDF đã nén sẵn) bằng
  bộ ghi ZIP tối thiểu tự viết trong app (Foundation không có
  API zip công khai) — kèm kiểm cấu trúc bằng giải nén thử.
- Không gửi đi đâu tự động: người dùng tự bấm chia sẻ.

## 4. Tiêu chí nghiệm thu (kiểm ngoại tuyến trước cổng)

1. Logic lọc + đặt tên + CSV: bản gương Python chạy trên bộ
   fixture gồm 2 bản ghi thật của anh (Sam's Business 2586 —
   dùng metadata đã biết; Home Depot Cá nhân 3830) + các ca
   biên (unknown, thiếu gốc, trùng tên, ngoài khoảng, đầu/cuối
   khoảng) → bảng kết quả khớp kỳ vọng từng ca.
2. Bộ ghi ZIP: bản gương cùng thuật toán sinh file, `unzip -t`
   sạch + giải nén ra đúng byte các file thành viên.
3. Điểm số đóng băng 001/002/003: KHÔNG đụng Parser/Models —
   tự động không hồi quy; diff gói chỉ ở ContentView.swift
   (màn xuất) + ReceiptViews.swift nếu cần helper dùng chung.
4. Cổng nội bộ 3 chữ ký + Wally tự kiểm diff/grep chéo như mọi
   gói; giao theo checklist Điều 3 B2, 1 lần kêu test: anh xuất
   thử Business 10/2025–11/2026 → mở ZIP thấy file gốc + mục lục.

## 6. Quyết đã khoá ở BƯỚC CHUẨN BỊ BẢN GƯƠNG (2026-11-10 14:40 CST,
## ca trực — các điểm đặc tả gốc để ngỏ; Wally có thể sửa ở cổng code)

Bản gương Python `wp-export-fixtures/export_port.py` + bộ kiểm
`verify_export.py`: **37/37 PASS** (`verify-export-results.txt`),
kèm `unzip -t` sạch trên ZIP mẫu do gương sinh
(`sample-export-mini.zip`, 2 tờ thu nhỏ — chỉ để kiểm cấu trúc).
Fixture: metadata THẬT của Sam's 001 + Home Depot 003 (đáp án ở
samples/) + ca biên tổng hợp ghi nhãn SYNTHETIC; byte file gốc là
dữ liệu giả lập (kho ảnh thật ở iPhone của anh). Các quyết khoá:

1. Cột Thuế của CSV = `taxTotalCents` (Σ taxLines nếu có, không
   thì taxCents) — đúng helper sẵn có trong Models.swift.
2. Tờ thiếu tổng: ô Tổng trong CSV để trống; đoạn tổng trong tên
   file trong ZIP = `chua-doc-duoc-tong`.
3. Làm sạch tên tiệm cho tên file: bỏ dấu (NFD, Đ→D), bỏ hẳn dấu
   nháy ('/'), ký tự lạ còn lại → `-`, rỗng → `Khong-ten-tiem`.
   (Bản nháp đầu của gương biến "Sam's" thành "Sam-s-Club" — bộ
   kiểm bắt được, đã sửa + khoá luật này.)
4. "Số tờ thiếu bản gốc" (con số hiện trước khi xuất) = tờ KHÔNG
   có file gốc nào nạp được. Tờ có ≥1 file nạp được nhưng mất
   trang phụ: vẫn xuất các trang có, ghi chú CSV "thiếu N trang
   gốc", KHÔNG tính vào số thiếu.
5. Thứ tự trong ZIP/CSV: ngày tăng dần → tên tiệm → tổng tiền.
6. Dòng TỔNG của CSV cộng trên các tờ khớp (trường trống = vắng
   mặt, cộng các giá trị có mặt) + ghi chú "N tờ khớp · M tờ
   thiếu bản gốc".
7. Tên ZIP: loại ghi `Business`/`CaNhan`/`TatCa`; chế độ theo
   năm = khoảng 01-01 → 12-31 của năm đó.
8. Hậu tố `-trangN` gắn theo vị trí file trong
   allOriginalImageFileNames TRƯỚC; dedupe `-2`/`-3` áp sau trên
   toàn ZIP theo thứ tự xuất.

Tiêu chí nghiệm thu §4: mục 1 (lọc/tên/CSV) + mục 2 (ZIP store)
ĐÃ ĐẠT ở tầng gương. Mục 3 (diff Swift) + code Swift: CHƯA LÀM —
vẫn chờ anh nghiệm SCANPRO theo thứ tự bắt buộc ở đầu đặc tả.

## 5. Chưa làm trong gói này (ghi rõ để không trôi)

- Gửi email tự động trong app (dùng Share Sheet thay thế).
- Đồng bộ Google Drive (amendment riêng, vẫn chờ ký).
- Báo cáo Schedule C đầy đủ (Tax Pack Build 3).

# WP-EXPORT — VĂN BẢN CỔNG (Xuất bản gốc cho kế toán)

## BƯỚC CHUẨN BỊ — BẢN GƯƠNG LOGIC + BỘ KIỂM NGOẠI TUYẾN
## (2026-11-10 14:40 CST, ca trực sohoadon-build2-247)

Việc độc lập chuẩn bị song song, đúng luật làm việc chung: làn
chính (chat chính) đã giao SCANPRO run #24 lúc 13:09 CST và đang
chờ anh nghiệm; đặc tả WP-EXPORT ghi cứng "code chỉ bắt đầu sau
khi anh nghiệm SCANPRO" — bước này KHÔNG viết Swift, KHÔNG đụng
ReceiptViews/ContentView, chỉ làm trước tiêu chí nghiệm thu §4
mục 1+2 của chính đặc tả (phần không cần chờ nghiệm).

### Sản phẩm
- `wp-export-fixtures/export_port.py` — bản gương Python của logic
  xuất: lọc loại × khoảng ngày (gồm cả 2 đầu), đặt tên file trong
  ZIP (làm sạch tên tiệm, `-trangN`, dedupe `-2/-3`), sinh
  `muc-luc.csv` (UTF-8 BOM, dòng TỔNG), ghi ZIP kiểu STORE.
  Ánh xạ trường ghi ở đầu file, đối chiếu wp3-prep/Models.swift
  (classification/category/subtotalCents/taxTotalCents/totalCents/
  cardLast4/allOriginalImageFileNames).
- `wp-export-fixtures/verify_export.py` — 37 phép kiểm: đơn vị
  (tiền, làm sạch tên) + 4 kịch bản lọc (Business theo khoảng =
  đúng ví dụ của anh 10/2025–11/2026 · theo năm 2025 · Cá nhân
  đúng 1 ngày · Tất cả gồm unknown) + ZIP (testzip, STORE, byte
  thành viên khớp, tái lập byte-identical).
- `wp-export-fixtures/verify-export-results.txt` — **37/37 PASS**.
- `wp-export-fixtures/sample-export-mini.zip` — ZIP thu nhỏ 2 tờ
  do gương sinh; `unzip -t` của hệ thống: "No errors detected".
- `WP-EXPORT-SPEC.md` mục 6 mới — 8 quyết khoá tại các điểm đặc
  tả gốc để ngỏ (thuế = taxTotalCents · thiếu tổng · làm sạch tên
  · định nghĩa "thiếu bản gốc" vs "thiếu trang" · thứ tự xuất ·
  dòng TỔNG · tên ZIP theo năm · thứ tự -trangN trước dedupe).

### Fixture — thật tới đâu, giả tới đâu (khai rõ)
- Metadata THẬT từ đáp án đã đóng băng: Sam's Club 001 (Business ·
  2586 · 2026-10-29 · 203.30 / thuế 13.50 = TAX1 9.60 + TAX2 3.90 /
  216.80 · Mục Vật Tư — samples/sample-001-ground-truth.md) và
  Home Depot 003 (Cá nhân do anh đổi tay · 3830 · 2025-03-03 ·
  96.91 / 8.25 / 105.16 — samples/sample-003-ground-truth.md; ảnh
  gốc để "có file" theo trạng thái sau IMGFIX đã nghiệm 12:53).
- Ca biên SYNTHETIC (ghi nhãn trong code): unknown có dấu tiếng
  Việt, trùng tên ZIP, đa trang mất trang 2, ngoài khoảng, đúng
  biên đầu/cuối, thiếu tổng, có tên file nhưng file không nạp
  được (đúng ca L-2026-11-10-5).
- Byte của file gốc trong fixture là DỮ LIỆU GIẢ LẬP — kho ảnh
  thật nằm trên iPhone của anh, ca trực không có; phép kiểm này
  là về logic xuất, không phải về ảnh thật.

### Lỗi phía em trong bước này (bắt được trước cổng, đã sửa)
- Nháp đầu của hàm làm sạch tên biến "Sam's Club" thành
  "Sam-s-Club" (dấu nháy thành gạch). Bộ kiểm U4/S1 bắt được;
  đã sửa (bỏ hẳn dấu nháy) + khoá thành quyết §6.3 trong đặc tả.
  Đây là đúng giá trị của bản gương: lỗi chết ở tầng Python, rẻ
  hơn chết ở bản build kêu anh cài.

### Ba chữ ký nội bộ cho BƯỚC CHUẨN BỊ
- Design ✓ — phạm vi + 8 quyết khoá tôn trọng đặc tả gốc và lệnh
  của anh (loại × thời gian, ZIP + mục lục, thiếu gốc không lặng
  lẽ bỏ qua); không thêm tính năng ngoài đặc tả.
- Code ✓ — gương thuần logic, không đụng Parser/Models/Swift nào;
  mọi ánh xạ trường đối chiếu trực tiếp Models.swift hiện hành;
  ZIP store + CSV BOM kiểm bằng 2 đường độc lập (zipfile của
  Python + `unzip -t` của hệ thống).
- QA ✓ — 37/37 PASS có file kết quả; kịch bản S1 dùng đúng ví dụ
  của anh (Business 2025-10-01..2026-11-30): 6 tờ khớp · tổng
  $521.30 · 1 tờ thiếu gốc — khớp kỳ vọng tính tay trong code
  kiểm; ca biên phủ đủ các ca đặc tả §4.1 liệt kê.

### Tuyên bố trung thực 3 phần
- ĐÃ CHỨNG MINH: logic lọc/đặt tên/CSV/ZIP-store của WP-EXPORT
  chạy đúng 37/37 trên fixture (2 bản ghi metadata thật + biên)
  ở tầng gương; cấu trúc ZIP sạch qua `unzip -t` độc lập.
- CHƯA CHỨNG MINH: bản dịch Swift của gương này (chưa viết — chờ
  nghiệm SCANPRO); bộ ghi ZIP tối thiểu trong app (gương dùng
  zipfile của Python, Swift phải tự viết theo đặc tả §3 — rủi ro
  riêng của bước code, sẽ phải kiểm lại bằng chính bộ này);
  ShareLink trên máy thật.
- CHƯA LÀM: code WP-EXPORT (ContentView/ReceiptViews Swift);
  tiêu chí §4.3 (diff gói); cổng GÓI WP-EXPORT.

**Trạng thái cổng: BƯỚC CHUẨN BỊ WP-EXPORT XONG. Cổng GÓI chưa mở.**
Bước tiếp theo của WP-EXPORT: khi anh nghiệm SCANPRO đạt → viết
Swift dịch trung thực export_port.py (màn ở tab Báo Cáo Thuế) →
chạy lại đúng bộ kiểm này ở tầng Swift/gương đối chiếu → cổng gói
3 chữ ký → trình Wally. Không kêu anh test gì ở bước này.

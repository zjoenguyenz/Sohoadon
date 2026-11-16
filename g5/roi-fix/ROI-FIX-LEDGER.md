# GÓI SỬA G5-ROIFIX — BAND DỰ PHÒNG CHO HINT KHÔNG HÌNH HỌC
Ca trực 20:40 CST 2026-11-15. Đúng MỘT bước tiếp theo của ca 18:40:
dựng gói sửa ROI theo mục 6 của sổ mổ `g5/checks/ca-1840-roigate-dissection.txt`,
tới cổng nội bộ, trình Leader/chat chính — ca KHÔNG đẩy code lên main,
KHÔNG dispatch CI, KHÔNG build, KHÔNG giao bản cho anh.

## 1) Thay đổi (1 file, +34/−1)
- File: `g5/roi-fix/ReadPipeline.swift` — bản sao cách ly của
  `g5/app/ReadPipeline.swift` (md5 gốc c511322f…, byte-trùng
  v3-phase4/app; file gốc tại bàn KHÔNG bị đụng).
- Điểm gọi duy nhất: `arbiterRegionHints.appendHint` —
  `band: arbiterBand(...) ?? arbiterFallbackBand(block: block)`.
  Band dự phòng CHỈ sinh khi band thật là nil; mọi ca có range/hộp
  thật giữ nguyên band cũ theo cấu trúc (không hồi quy theo thiết kế).
- Hàm mới `arbiterFallbackBand` (kèm comment ghi số đo ngay trong code):
  - `.items` → toàn khung (0,0,1,1).
  - `.totals` → dải đáy khung tới y=0,9 (0,0,1,0,9).

## 2) Lệch so với kiến nghị §6(b) của sổ mổ — có bằng chứng, ghi rõ
Sổ mổ đề xuất: khối món → vùng thân trên khối tổng; khối tổng → dải
dưới khung. Gói này KHÔNG làm đúng chữ đó, vì số đo trong ca này:
- Vùng thân suy từ khoảng khối tổng bị Ô NHIỄM: dòng tiêu đề cột
  "DESCRIPTION CTY PRICE TOTAL" (WR-dollartree-1, dòng 5 trong
  evidence-37) chứa chữ TOTAL nên khoảng tổng thành 5…15, "thân"
  suy ra (trên y=0,575) nằm SAI phía so với khối món thật
  (y 0,428–0,532). Thân không xác định tin cậy được → toàn khung
  là band duy nhất chắc chắn chứa khối món mất.
- Dải tổng hẹp hụt ca thật: trên 41 luồng đóng băng run31, ymax của
  khối tổng cao nhất 0,822 (WR-walgreens-1), 0,712 (WR-target-1) —
  dải 0,6 hay 0,75 đều hụt. 0,9 chứa trọn 41/41.

## 3) Kiểm chứng tại bàn — verify_roi_fix.py: 16/16 PASS
(chi tiết: verify-roi-fix-results.txt)
- Tĩnh: file gốc nguyên vẹn; ngoặc cân bằng 274/274; diff chỉ nằm
  trong 2 vùng cho phép; đúng 1 định nghĩa + 1 điểm gọi.
- Tái hiện lỗi: gương logic trên 4 ca evidence-37 — logic hiện hành
  cho band nil ở cả 4 (khớp roiRounds=0 của #37); logic đã vá cho
  band dự phòng hợp lệ ở cả 4.
- Chứa trọn: dải [0, 0,9] chứa 41/41 khối tổng run31; riêng L-R09,
  khối tổng run31 của chính tờ (y 0,375–0,472) nằm trong dải.
- Không hồi quy theo cấu trúc: 41/41 ca có range thật không dùng
  band dự phòng.

## 4) Rủi ro còn mở (khai trước, không lấp)
- ROI sẽ chạy ở MỌI ca thâm hụt thiếu hình học (không chỉ 4 ca) —
  bị chặn bởi trần sẵn có: ≤2 vòng, ≤2 vùng/vòng, trần mềm 4 giây;
  kết quả vẫn qua thang chấp nhận arbiterIsBetter.
- Hint không lineRange => defaultMerge NỐI dòng đọc lại vào cuối;
  trùng dòng là khả thể, trọng tài là lớp quyết nhận/từ chối —
  hồi quy thật chỉ phán được ở lượt mốc G5 chạy lại (cổng images
  ×10 + roigate), thuộc Leader.
- roiBreakReason (đề xuất phụ §6(c) của sổ mổ): KHÔNG đưa vào gói
  này để giữ bề mặt sửa tối thiểu; để Leader quyết riêng.
- Tuyến dollartree (token tiền có khoảng trắng "$5. 00"): KHÔNG
  đụng, đúng sổ mổ — Leader quyết riêng ở tầng parse.

## TUYÊN BỐ TRUNG THỰC
- Đã chứng minh: patch tối thiểu đúng 1 file +34/−1 trên bản sao
  cách ly; cơ chế band nil tái hiện và hết ở cả 4 ca bằng gương
  logic trên bằng chứng #37 đã kiểm sha; hình học dự phòng chứa
  trọn 41/41 khối tổng đã đo; tính không-hồi-quy theo cấu trúc
  (fallback chỉ khi band nil).
- Chưa chứng minh: bản vá CHƯA biên dịch (không có swiftc tại bàn)
  và CHƯA chạy đường ảnh thật — roiRounds thật ≥1, f2Rescued,
  regressions chỉ có ở lượt mốc G5 chạy lại trên CI do Leader kích.
  G5 VẪN CHƯA ĐÓNG.
- Chưa làm: không sửa code trong repo/g5/app/v3-phase4, không đẩy
  code, không dispatch, không build, không giao gì cho anh;
  GATE100-v2 vẫn là bước chốt sau, cần phiên với anh.

# Test B — bản test pipeline engine (b) iOS 26 (WP4 bước 3, phần chuẩn bị)

**Đây là app test cô lập kiểu Test 0, KHÔNG phải app chính.** Không
SwiftData, không parser, không đụng kho dữ liệu, bundle riêng
`com.nje.sohoadon.testb`, deployment target **iOS 26.0** (app chính vẫn
17.0 cho tới quyết nền tảng §5.6 ở cổng WP4). Cô lập là có chủ đích:
rủi ro đổi SDK/target cháy ở đây thì app chính không hề hấn gì
(WP4-SPEC §1, Master Plan §5.6).

## App làm gì
1. Anh chọn 1 ảnh hoá đơn mẫu từ thư viện ảnh.
2. Bấm "Chạy engine (b) — 2 cấu hình": `RecognizeDocumentsRequest`
   (Vision iOS 26) chạy trên **ảnh gốc** và trên **ảnh phái sinh**
   (cùng thuật toán tứ giác/perspective/tương phản của ứng viên (a),
   chép ở `EngineB.derivedImage` — để 2 ứng viên chấm trên cùng 1 ảnh
   phái sinh, WP4-SPEC §2).
3. Mỗi cấu hình hiện 1 khối văn bản copy được: thời gian đọc · số đoạn
   (paragraph) · số bảng · số danh sách · các dòng văn bản (đoạn tách
   theo ký tự xuống dòng trong transcript).

## Cách build (giống Test 0)
Đẩy thư mục này thành repo riêng (hoặc nhánh riêng) → Actions →
**Build unsigned IPA (Test B)** → tải artifact `SoHoaDonTestB-IPA` →
ký bằng chứng thư của anh (Feather) → cài. Runner `macos-26` +
Xcode 26 [CHƯA KIỂM CHỨNG — bước đầu workflow in bản Xcode thật].

## Cách dùng cho trận thi đấu (ở mốc M1, không xin riêng)
Anh chạy app trên 4 ảnh: Mẫu 001, Mẫu 002, Mẫu 003 và **1 lần chụp
camera tờ Sam's của Mẫu 002 (= lập mẫu 002-C)**; copy 2 khối kết quả
mỗi ảnh về. Đội đưa các dòng qua CÙNG parser (bản wp4-prep) rồi chấm
4 ô tiệm/ngày/tổng/món + bài §F vào SCORECARD — đối đầu trực tiếp với
điểm ứng viên (a) đo trên máy ở cùng mốc. QA ký chọn engine bằng văn
bản ở WP4-GATE; engine thua bị loại khỏi mã nguồn Build 2 (§5.1).

## Giới hạn đã biết (ghi trước, không lấp)
- Độ tin cậy (confidence) từng dòng: `DocumentObservation` không xuất
  confidence theo dòng như `VNRecognizedTextObservation` trong các
  nguồn đã đối chiếu — bản test không bịa số này; hệ quả cho kỷ luật
  gắn cờ (C-11) phải được QA cân ở văn bản chọn engine.
- Biên dịch + hành vi thật của RecognizeDocumentsRequest trên máy:
  [CHƯA KIỂM CHỨNG] cho tới build cloud + lần chạy M1.

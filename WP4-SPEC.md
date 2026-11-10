# WP4 — ĐẶC TẢ ĐO THI ĐẤU ENGINE (Master Plan §2 WP4 + §5.1 + §5.6)

Viết 2026-11-09 20:40 CST (ca trực sohoadon-build2-247, WP4 bước 1).
Tài liệu này khoá CÁCH ĐO trước khi đo — không khoá kết quả, không đặt
ngưỡng hứa trước (Master Plan: "Điểm quyết định là điểm trên mẫu của
anh — không có ngưỡng hứa trước"; §5.8 cấm mục tiêu %).

## 1. Hai ứng viên
- **(a) Vision cổ điển nâng cấp:** `VNRecognizeTextRequest` như Build 1
  + ráp hàng F2a + chịu tách dòng F2b + cắt lát ảnh cao F2c (CODE-AUDIT
  F2) + tiền xử lý ảnh phái sinh (phát hiện tứ giác → nắn perspective →
  tăng tương phản; TOP-APPS-RESEARCH ý #3). Ảnh GỐC luôn giữ nguyên —
  tiền xử lý chỉ tạo bản phái sinh trong bộ nhớ để đọc.
- **(b) Engine iOS 26:** `RecognizeDocumentsRequest` trong **bản test
  pipeline RIÊNG kiểu Test 0** (cô lập thay đổi SDK/deployment target
  khỏi app chính). Không bao giờ đưa thẳng vào main trước khi có điểm.

## 2. Cấu hình đo — "hai lượt" là cấu hình của TỪNG ứng viên (§5.1)
Mỗi ứng viên chấm ở 2 cấu hình: **đọc trên ảnh gốc** và **đọc trên ảnh
phái sinh** (tiền xử lý). Đây không phải lai hai engine — QA-VERDICT
§0.1 cấm lai ghép mập mờ; sau khi chọn thắng/thua, engine thua bị LOẠI
HẲN khỏi mã nguồn Build 2. Lớp trọng tài số học (Ý 4 — gắn cờ, đưa ứng
viên cho anh chọn, không bao giờ tự điền số) chạy bên trên engine thắng
duy nhất.

## 3. Bộ mẫu & cách chấm
- **Điểm cổng (quyết định thắng/thua):** bộ mẫu đóng băng SCORECARD —
  001 / 002 / 003, cộng **002-C** khi có (xem mục 4). Mỗi mẫu chấm 4 ô
  **tiệm / ngày / tổng / món**; Mẫu 002 chấm thêm bài §F ràng buộc
  (10 dòng món · 203.30 · 9.60 · 3.90 · 216.80 · 15 món · khoá TC#).
- **Luật cổng không đổi:** tổng + ngày ĐÚNG trên cả 3 mẫu hạt giống VÀ
  không một con số sai nào trình bày mà không gắn cờ.
- **Làn lab** (WildReceipt/CORD/SROIE — corpus/CORPUS.md): chỉ đo độ
  bền, KHÔNG BAO GIỜ là điểm quyết định (bằng chứng 88%→51% khi đổi
  điều kiện, TOP-APPS-RESEARCH §2.12).
- Mỗi lần chấm ghi 1 dòng vào Nhật ký chấm điểm của SCORECARD.md: ứng
  viên + cấu hình + bộ 4 ô từng mẫu + §F đạt/thiếu số nào, kèm đường
  dẫn bằng chứng (văn bản thô qua cửa F3).

## 4. Mẫu 002-C — chụp camera thật (điểm chờ anh)
- Nội dung: chụp bằng camera TRONG APP cùng tờ Sam's của Mẫu 002; đáp
  án chuẩn = đáp án 002 (§F). Đường camera tới nay [CHƯA KIỂM CHỨNG]
  (anh mới test qua Photos — CODE-AUDIT Leader Addendum).
- Việc của anh khi tới lúc: 1 lần chụp ở bài test mốc M1 — KHÔNG xin
  anh chụp riêng cho từng bước (luật mốc lớn). Thiếu 002-C thì bảng
  điểm vẫn lập được trên 001/002/003 nhưng mục camera ghi rõ CHƯA
  KIỂM CHỨNG trong văn bản chọn engine; quyết thắng/thua không được
  tuyên bố là đã gồm đường camera.

## 5. Hệ quả nền tảng (§5.6 — quyết theo điểm, không theo sở thích)
- (b) thắng → app chuyển đích **iOS 26** (máy anh đang chạy iOS 27.x);
  lúc đó đặc tả Liquid Glass DESIGN-AUDIT §4.9 mới kích hoạt, chỉ ở
  lớp điều khiển. Điểm mở đang treo: `project.yml` vẫn để iOS 17.0
  trong khi làn thiết kế đã chốt chỉ iOS 26 (anh duyệt 2026-11-09
  17:32 CST) — ca trực KHÔNG tự đổi; Wally xử lý khi trình cổng WP4
  kèm bảng điểm.
- (a) thắng → giữ iOS 17, tab bar tự vẽ §4.3 là bản chính, Glass hoãn.

## 6. Chia bước WP4
- **Bước 1 (ĐÃ LÀM, ca 2026-11-09 20:40):** đặc tả này + tầng tạo dòng
  của ứng viên (a): F2a ráp hàng + F2c cắt lát/khử trùng trong
  `wp4-prep/ScanView.swift`; kiểm chứng thuật toán bằng port Python
  trên fixture mảnh-xé dựng từ đáp án 002 (`wp4-fixtures/`, 9/9).
- **Bước 2:** tiền xử lý ảnh phái sinh cho (a) (tứ giác/perspective/
  tương phản) + **F2b** chịu tách dòng phía parser (máy trạng thái
  nhãn chờ 1 dòng — đúng đặc tả CODE-AUDIT F2b, `validate()` không đụng).
- **Bước 3:** bản test pipeline (b) + chạy thi đấu trên bộ mẫu (cần
  build cloud + máy anh ở mốc M1 cho đường camera/002-C) + QA ký văn
  bản chọn engine thắng + loại engine thua + chốt quyết nền tảng §5.6.

## 7. Đối chiếu danh mục lỗi không được lặp (TEAM.md)
- #1 framework lạ lúc khởi động: (b) chỉ chạm trong bản test riêng,
  sau thao tác người dùng — không vào app chính ở bước 1–2.
- #3 API chưa kiểm chứng trên máy anh: phép quy đổi toạ độ lát cắt
  (CGImage cropping + Vision) ghi [CHƯA KIỂM CHỨNG] trong code và
  WP4-GATE — bài kiểm máy ở bước 3/M1 mới được kết luận.
- #4 suy đoán thay bằng chứng: fixture mảnh-xé là MÔ PHỎNG khiếm
  khuyết đã có bằng chứng thực địa (002 mất toàn bộ tiền, ground
  truth ghi rõ cơ chế xé cột) — kết luận của fixture chỉ là "thuật
  toán ráp đúng đặc tả", không phải "OCR thật đã khỏi".

# ĐỘI NGŨ SỔ HOÁ ĐƠN — cơ cấu & cổng chất lượng
Lệnh của anh (2026-11-08 23:13 CST): "Tuyển đội ngũ chuyên thiết kế app và cả
coding cho thật tốt. Đừng lặp lại lỗi nhỏ nhặt cơ bản như lúc đầu nữa."

## Đổi hướng chiến lược (lệnh của anh, 2026-11-08 23:25 CST)
Không đuổi theo từng định dạng hoá đơn một — nhà hàng/market nào cũng khác nhau,
học không hết. Hướng đúng: (1) chuyên gia kế toán định nghĩa BỘ TRƯỜNG DỮ LIỆU
CHUẨN mà mọi hoá đơn phải lấy được (cần gì, lưu gì, vì sao — theo yêu cầu thuế);
(2) engine đọc tổng quát trích đúng các trường đó từ MỌI bố cục; (3) mẫu riêng
chỉ là tăng tốc cho vài tiệm anh hay mua nhất; (4) hoá đơn nhiều loại được thu
thập làm BỘ MẪU CHẤM ĐIỂM (corpus), không phải làm khuôn mẫu.

## Vai trò
- **Chuyên gia Kế toán (Accounting)** — phân tích theo chuẩn thuế Mỹ (IRS):
  hoá đơn cần lấy dữ liệu gì, lưu trường gì, kiểm chứng chéo ra sao, giữ bao lâu;
  ra tài liệu đặc tả dữ liệu chuẩn để cả đội code theo. Không viết code.
- **Trưởng nhóm (Leader)** — nhận brief, chia việc, KIỂM CHÉO mọi kết quả của
  chuyên viên với bằng chứng gốc (file code thật), nộp tờ khai trung thực
  (claims / evidence / unverified) trước khi bất cứ thứ gì tới tay Wally/anh.
- **Chuyên viên Thiết kế (Design)** — audit giao diện theo DESIGN-V2.md và
  chuẩn app lớn (Copilot Money, Apple Wallet, Things 3, Scanner Pro…):
  màu/icon/chữ/badge đủ 4 tín hiệu, số tiền luôn rõ trên nền đục, vùng chạm ≥44pt,
  trạng thái rỗng/lỗi/chờ đều có thiết kế — không để giao diện mặc định trần trụi.
- **Chuyên viên Code (Senior iOS)** — rà code như reviewer độc lập: cú pháp,
  kiểu dữ liệu/optional, vòng đời SwiftUI/SwiftData, API đúng đời iOS 17,
  KHÔNG đụng framework lạ lúc khởi động.
- **Giám sát độc lập (QA/Supervisor)** — không viết code, chỉ kiểm: đối chiếu
  từng kết luận của Design/Code với file thật, giữ danh mục lỗi cơ bản (dưới đây),
  và GIỮ CỔNG: chưa đủ 3 chữ ký (Design ✓ / Code ✓ / QA ✓) thì KHÔNG đẩy GitHub.

## Danh mục lỗi cơ bản — KHÔNG ĐƯỢC LẶP LẠI (mỗi lỗi từng tốn 1 vòng build/cài của anh)
1. Đụng framework có điều kiện quyền (CloudKit…) ngay lúc app khởi động mà chưa
   có bài test trên máy thật — Test 0: CKContainer tạo ở thân view làm app chết
   ngay khi mở, 2 vòng cài oan. Luật: framework lạ chỉ được chạm SAU thao tác
   người dùng, và phải có đường fail-open.
2. Truyền sai kiểu (Int? vào tham số Int…) — lỗi biên dịch sơ đẳng mà bản nháp
   Build 1 vẫn dính, chỉ thoát nhờ duyệt tay. Luật: rà kiểu/optional là mục bắt
   buộc trong checklist duyệt code, không trông vào may rủi.
3. Dùng component theo tài liệu mà không kiểm hành vi thật trên iOS của anh
   (fileImporter chọn thư mục: huỷ im lặng). Luật: API/UI nào chưa kiểm chứng
   trên máy anh thì hoặc có bài test riêng trước, hoặc không dùng cho luồng chính.
4. Suy đoán thay bằng chứng (đoán "iOS giết app vì giấy phép" khi chưa đọc log).
   Luật: lỗi phát sinh thì lấy log/bằng chứng gốc trước, kết luận sau; suy đoán
   phải gắn nhãn là suy đoán.

## Nhịp độ (lệnh của anh, 2026-11-08 23:31 CST)
"Build từ từ thật chắc chứ ko build vội vàng" — làm chậm mà chắc, không chạy
tiến độ. Mỗi gói việc phải có bằng chứng nghiệm thu trên mẫu thật mới mở gói
tiếp theo; không hứa hẹn thời gian hoàn thành; cổng 3 chữ ký là sàn, không
phải trần. Một chuyên gia Tổng hợp & Sản phẩm chịu trách nhiệm gộp mọi đầu
vào thành MỘT bản kế hoạch Build 2 duy nhất (BUILD2-MASTER-PLAN.md) trước
khi bất kỳ dòng code Build 2 nào được viết.

## Quy trình từ nay (mỗi bản build)
Nháp (coder) → Design audit → Code audit độc lập → QA đối chiếu + ký cổng →
Wally duyệt lần cuối → đẩy GitHub → build → anh ký/cài → kiểm trên máy thật
theo tiêu chí nghiệm thu viết sẵn. Báo cáo về anh: kết quả trước, bằng chứng sau,
chưa kiểm chứng thì nói chưa kiểm chứng.

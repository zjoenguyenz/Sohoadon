# AMENDMENT 002 — Đồng bộ Google Drive (THAY cơ chế của Amendment 001)
Nguồn: quyết định của anh, 2026-11-09 00:08 CST (nguyên văn): "Vậy sync luôn
google drive sẽ tiện hơn. Vì không phải lúc nào cũng nhớ backup. Và tuỳ lúc
backup thì file backup sẽ không đều vì thời gian backup khác nhau."
=> Anh chọn SYNC TỰ ĐỘNG qua Google Drive thay cho backup thủ công.
Amendment 001 giữ vai trò lịch sử (ý tưởng cloud cứu hộ); cơ chế thi hành
từ nay là amendment này.

## Lớp thư mục anh chọn (bổ sung theo lời anh, 2026-11-09 00:13 CST)
Nguyên văn: "Sẽ cho chọn lựa lưu trên máy hoặc icloud tuỳ do mình lựa chọn
thư mục. Còn google drive thì tất nhiên luôn sync."
=> Ngoài lớp Drive luôn-sync ở dưới, app có thêm **lớp thư mục do anh chọn**:
bản sao file (ảnh gốc + PDF + dữ kiện) nằm trong thư mục anh chỉ định trong
Files — chọn thư mục ở **Trên iPhone** thì là bản trong máy, chọn thư mục ở
**iCloud Drive** thì Apple tự đưa lên iCloud của anh ở cấp file (KHÔNG phải
CloudKit — không cần entitlement, chạy với cách ký hiện tại).
- Bài học Test 0 áp dụng thẳng: bộ chọn thư mục phải dùng document picker
  cấp thấp + có bài test riêng trên máy anh TRƯỚC khi thành tính năng
  (fileImporter của SwiftUI đã từng huỷ im lặng khi chọn thư mục của chính
  app — TEAM.md lỗi cơ bản #3). Thư mục mặc định vẫn là thư mục riêng của
  app trong Files; anh đổi lúc nào cũng được, đổi là app chuyển bản sao sang.

## Thiết kế đồng bộ (chốt hướng, chi tiết để Chuyên gia Tổng hợp + QA ký)
1. **Mỗi hoá đơn là file riêng trên Drive** (dữ kiện 1 file + ảnh/PDF gốc là
   file riêng của chính tờ đó) trong thư mục riêng của app. KHÔNG dùng 1 file
   database duy nhất ghi đè — tránh tuyệt đối cảnh máy này đè mất hoá đơn
   máy kia vừa thêm. Xung đột (nếu có) chỉ xảy ra trong phạm vi 1 tờ.
2. **Tự động hoàn toàn**: đồng bộ khi mở app + ngay sau mỗi thay đổi (thêm/
   sửa/duyệt 1 tờ) + quét bù khi có mạng trở lại. Anh không phải nhớ bấm gì.
3. **Offline-first giữ nguyên**: không mạng vẫn chụp/lưu bình thường (trong
   kho Sam's sóng yếu là chuyện thường) — hàng đợi đồng bộ tự chảy khi có mạng.
4. **Trung thực về giới hạn**: iOS không cho app nền chạy tuỳ ý — "sync luôn"
   nghĩa là tự động ở mọi thời điểm app được chạy/mở và ngay sau mỗi thay đổi,
   KHÔNG hứa realtime từng giây khi app đã đóng hẳn nhiều giờ. Với 1 người
   dùng, độ trễ thực tế gần như bằng 0.
5. **Nguyên tắc dữ liệu không đổi**: ảnh gốc bất khả xâm phạm, không xoá lặng
   lẽ, trùng thì đánh dấu (ACCOUNTING-SPEC §4 áp dụng cho cả bản trên Drive —
   xoá trên Drive cũng phải theo dấu vết, không tự dọn).
6. **Bảo mật**: file nằm trong Drive của chính anh, dưới tài khoản Google của
   anh; app chỉ đụng thư mục của nó. Mã hoá thêm bằng mật khẩu (ý ở Amendment
   001) lùi thành tuỳ chọn xem xét sau — nó làm đồng bộ và khôi phục phức tạp
   hơn, không mặc định.
7. **Đăng nhập Google trong app** (OAuth) không cần entitlement đặc biệt —
   chạy được với cách ký hiện tại của anh. Vẫn phải có **bài test cô lập
   kiểu Test 0** (đăng nhập + ghi/đọc 1 file thử trên máy anh) trước khi
   viết tính năng thật — luật đội, không ngoại lệ.

## Vị trí trong Master Plan (đề xuất, chưa chốt)
- Phụ thuộc WP2 (định dạng file theo model dữ liệu mới) → gói riêng SAU WP2,
  đề xuất sau WP6 hoặc cùng đợt Build 3. WP0–WP4 giữ nguyên thứ tự.
- Có hiệu lực khi được ký vào Master Plan qua quy trình sửa đổi (luật 6,
  mục 4 của Master Plan).

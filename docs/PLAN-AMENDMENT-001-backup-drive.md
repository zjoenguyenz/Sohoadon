# AMENDMENT 001 — Tuỳ chọn sao lưu lên Google Drive / drive khác
Nguồn: ý tưởng của anh, 2026-11-09 00:01 CST (nguyên văn ý): thêm lựa chọn sao lưu
trên Google Drive hoặc các drive khác, dễ lấy lại dữ liệu nếu iPhone không truy
xuất được; kết hợp lưu tại bộ nhớ iPhone + cloud storage.

## Phân biệt rạch ròi (để không lẫn với các quyết định đã chốt)
- Đây là **SAO LƯU (backup)** — một bản sao để khôi phục khi mất máy — KHÔNG phải
  đồng bộ sống (sync). CloudKit vẫn bị LOẠI HẲN (bằng chứng Test 0: chạm vào là
  app chết khi mở trên máy anh). App vẫn local-first 100%, không có drive vẫn
  chạy đầy đủ, offline hoàn toàn.
- Sao lưu = 1 file lưu trữ (toàn bộ dữ liệu + ảnh gốc + PDF gốc) ghi ra drive;
  khôi phục = nạp file đó vào app trên máy mới. Chuẩn cũ của Giám sát vẫn đứng:
  backup–restore phải đạt 100% mới tính là xong (BLUEPRINT, supervisor bar).

## Thiết kế dự kiến (chờ Chuyên gia Tổng hợp + QA ký vào bản kế hoạch)
1. **Đường chung qua Files trước**: xuất 1 file backup (.zip) qua Files/Share —
   chạm được MỌI drive có mặt trong Files (Google Drive, iCloud Drive, Dropbox,
   OneDrive) mà không cần tích hợp riêng từng hãng. Rẻ, chắc, test được sớm.
2. **Tích hợp thẳng Google Drive** (đăng nhập Google của anh, Drive API) là bước
   sau nếu anh muốn sao lưu tự động không cần bấm xuất tay.
3. **Mã hoá file backup bằng mật khẩu anh đặt** — tuỳ chọn nên có: file chứa dữ
   liệu thuế/tài chính, nằm ngoài iPhone thì không nên để trần. (Đánh đổi phải
   nói rõ: quên mật khẩu = không khôi phục được — app phải cảnh báo khi bật.)
4. Sao lưu **tự nhắc** theo chu kỳ anh chọn (vd sau mỗi X tờ mới / mỗi tuần) —
   chỉ nhắc và xuất khi anh duyệt, không tự gửi lặng lẽ (giữ luật minh bạch).

## Vị trí trong BUILD2-MASTER-PLAN (đề xuất, chưa chốt)
- Định dạng backup đi theo model dữ liệu → chỉ làm được SAU WP2.
- Đề xuất: 1 gói riêng sau WP6 (niềm tin dữ liệu) hoặc cùng đợt Build 3 với
  Tax Pack (cùng họ "xuất file"). WP0–WP4 (chất lượng đọc) KHÔNG đổi thứ tự.
- Amendment này chỉ có hiệu lực khi được ghi vào Master Plan qua quy trình
  sửa đổi có ký nhận (Master Plan mục 4, luật 6) — không tự chen ngang.

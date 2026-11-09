# Sổ Hóa Đơn — IPA Test Số 0: cách build trên cloud và cài thử

Bộ này là **app test rỗng**, chỉ để kiểm chứng 3 việc trên iPhone thật của anh:
app ký bằng chứng thư của anh có cài/mở được không · Face ID có dùng được không ·
iCloud có chạy với cách ký này không (chạy được thì tốt, không được cũng không sao —
dữ liệu chính lưu thẳng trên máy, file hoá đơn rất nhẹ).

## Bước 1 — Tạo kho chứa code (GitHub, miễn phí)

1. Vào github.com, đăng nhập (chưa có tài khoản thì tạo, miễn phí).
2. Tạo repository mới: đặt tên `sohoadon`, chọn **Private**, bấm Create.
3. Nạp toàn bộ file trong thư mục này lên repo (giữ nguyên cấu trúc, gồm cả thư mục ẩn `.github`):
   cách dễ nhất là dùng trang web GitHub — "uploading an existing file" — hoặc GitHub Desktop.

## Bước 2 — Chạy build

1. Trong repo, mở tab **Actions**.
2. Chọn workflow **Build unsigned IPA** → **Run workflow**.
3. Đợi build xong (vài phút), mở lần chạy đó, tải artifact **SoHoaDon-IPA** về — trong đó là file `SoHoaDon-unsigned.ipa`.

## Bước 3 — Ký và cài bằng app sign của anh

1. Mở app sign (Feather) → Import file IPA vừa tải.
2. Sign bằng chứng thư của anh (còn 345 ngày) → Install.
3. Mở app **Sổ Hóa Đơn — Test 0** ngoài màn hình chính.

## Bước 4 — Chạy kiểm tra và gửi kết quả

1. Bấm **Kiểm tra Face ID** → xác nhận mở khoá.
2. Bấm **Kiểm tra iCloud** → đợi hiện kết quả ghi thử.
3. Bấm **Chọn thư mục & ghi thử** → chọn một thư mục bất kỳ trong app Files (iCloud Drive hay Trên iPhone đều được) → đợi hiện kết quả.
4. **Chụp màn hình app** và gửi lại cho Wally. Mọi dòng chữ lỗi (nếu có) đều là thông tin quý — cứ gửi nguyên.

Xong bài test này, Wally mới xây app thật theo đúng đường đã kiểm chứng.

# Mẫu 002 — Sam's Club, file gốc tải về (ảnh render hoá đơn quầy)
Nguồn: user gửi trong chat 2026-11-08 23:21 CST. File: sample-002-sams-downloaded-receipt.jpg (554×1457 px — độ phân giải THẤP cho 1 hoá đơn dài).
Đây là file user nạp vào Build 1 qua "Chọn ảnh có sẵn" — kết quả thực địa: đọc đúng
tiệm/ngày/thẻ/15 món; trượt toàn bộ tiền + số món có tiền (xem MEMORY/field result).

## Bố cục quan trọng (nguyên nhân gốc)
Hoá đơn 3 cột, CỘT TIỀN TÁCH HẲN BÊN PHẢI qua khoảng trống lớn. Vision xé mỗi
hàng thị giác thành 2 mảnh (nhãn/món một mảnh, tiền một mảnh) -> parser nhận
mảnh vụn. Mọi dòng "1 cục" (ngày giờ, dòng thẻ che, # ITEMS SOLD) đều đọc đúng —
khớp hoàn toàn với kết quả thực địa. Hàng thị giác sau khi RÁP phải thành:

0980012382 35PKDIETCOK            (chờ dòng số lượng)
2 AT 1 FOR 19.48            38.96 Y
0980012387 SPRITECANS       19.48 Y
0000806965 DR PEP CANS      17.28 Y
0000561914 MM WATER               (chờ)
5 AT 1 FOR 4.28             21.40 Y
0000309203 12 OZ BOWL             (chờ)
2 AT 1 FOR 13.98            27.96 T
0000662368 POM TISSUE       26.98 T
0980143709 13G TRSH LA            (chờ)
2 AT 1 FOR 19.98            39.96 T
0990354068 GREN MM TWE      17.78 T
INST SV 12 OZ BOWL                (chờ — INST SV cũng có dòng số lượng!)
2 AT 1 FOR 2.25-             4.50-T
INST SV POM TISSUE           2.00-T
SUBTOTAL                    203.30
TAX 1 8.517 %                 9.60
TAX 2 4.017 %                 3.90
TOTAL                       216.80
MASTERCARD DEBIT TEND       216.80
MASTERCARD **** **** **** 2586
CHANGE DUE                    0.00
# ITEMS SOLD 15
TC# 7977 9795 7863 7256 1022 8

## Kiểm chứng số học (Wally đọc từ ảnh, tính tay)
38.96+19.48+17.28+21.40+27.96+26.98+39.96+17.78−4.50−2.00 = 203.30 ✓
203.30 + 9.60 + 3.90 = 216.80 ✓ · Σ số lượng = 2+1+1+5+2+1+2+1 = 15 ✓
=> Luật parser hiện tại ĐỦ ĐÚNG trên mẫu này NẾU dòng vào được ráp theo hàng.
Lỗi nằm ở tầng OCR (phân mảnh), không nằm ở luật bóc tách.
Lưu ý phụ: brand đọc ra "Mastercard" (thiếu "Debit") vì chữ DEBIT nằm ở dòng
TEND phía trên dòng thẻ che — findCard chỉ nhìn cùng dòng. Không nghiêm trọng.

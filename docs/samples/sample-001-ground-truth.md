# Sample 001 — Sam's Club (ảnh chụp màn hình app Sam's Club, "Receipt details")

File: sample-001-sams-club-app-screenshot.jpg (1320×2868, chụp 2026-11-08 21:48 CST)
Nguồn: user gửi — đây là hoá đơn điện tử xem lại trong app Sam's Club, KHÔNG phải giấy nhiệt.
Ground truth do Wally đọc trực tiếp từ ảnh + kiểm tra số học bằng máy tính (2026-11-08).

## Trường trích xuất (đáp án chuẩn)

- Vendor: Sam's Club — Tulsa, OK (Club Manager Justin, 918-252-9503)
- Ngày giờ mua: 10/29/26 17:49 → 2026-10-29 17:49
- Thanh toán: MASTERCARD DEBIT, đuôi **2586**, Pin Verified, APPR# 208448, REF# UOZU27248238
- TC# (khoá chống trùng): 7977 9795 7863 7256 1022 8
- Số món: 15

## Line items

| Mã hàng | Tên (nguyên văn) | SL | Đơn giá | Thành tiền | Cờ |
|---|---|---|---|---|---|
| 0980012382 | 35PKDIETCOK (Diet Coke 35 lon) | 2 | 19.48 | 38.96 | Y |
| 0980012387 | SPRITECANS | 1 | 19.48 | 19.48 | Y |
| 0000806965 | DR PEP CANS | 1 | 17.28 | 17.28 | Y |
| 0000561914 | MM WATER | 5 | 4.28 | 21.40 | Y |
| 0000309203 | 12 OZ BOWL | 2 | 13.98 | 27.96 | T |
| 0000662368 | POM TISSUE | 1 | 26.98 | 26.98 | T |
| 0980143709 | 13G TRSH LA (túi rác 13 gal) | 2 | 19.98 | 39.96 | T |
| 0990354068 | GREN MM TWE | 1 | 17.78 | 17.78 | T |
| — | INST SV 12 OZ BOWL (giảm giá) | 2 | −2.25 | −4.50 | T |
| — | INST SV POM TISSUE (giảm giá) | — | — | −2.00 | T |

## Tổng — ĐÃ KIỂM TRA SỐ HỌC

- Σ line items = **203.30** = SUBTOTAL trên hoá đơn ✓
- SUBTOTAL 203.30 + TAX 1 9.60 + TAX 2 3.90 = **216.80** = TOTAL ✓
- Σ số lượng = **15** = "# ITEMS SOLD 15" ✓

## Phát hiện quan trọng cho bộ đọc (parser)

1. **Hai mức thuế**: nhóm cờ Y (đồ uống/thực phẩm, $97.12) chịu TAX 2 = 4.017% → $3.90 ✓. Nhóm cờ T ($112.68 trước giảm giá) chịu TAX 1 = 8.517% → $9.60 ✓.
2. **Thuế tính trên giá TRƯỚC Instant Savings**: nhóm T sau giảm giá là $106.18 → thuế sẽ là $9.04, KHÔNG khớp $9.60. Parser không được lấy (subtotal sau giảm × thuế suất) để kiểm thuế — chỉ kiểm được: Σ items = subtotal và subtotal + tax = total.
3. Dòng giảm giá viết dạng `4.50-` (dấu trừ phía SAU số) — regex số tiền phải xử lý trailing minus của Sam's/Walmart.
4. Dòng số lượng viết dạng `2 AT 1 FOR 19.48` — mẫu riêng của Sam's, parser phải có rule riêng.
5. Tên món là mã viết tắt (35PKDIETCOK, GREN MM TWE) — app giữ nguyên văn + cho phép đặt tên dễ hiểu sau; không đoán dịch bừa.
6. Ảnh chụp màn hình có thanh tiêu đề xanh của app + nút share + sticker che 1 phần barcode ở góc — bước nhập ảnh phải tự cắt phần đầu app, và đây là hoá đơn rõ nét nhất (bản điện tử), KHÔNG đại diện cho độ khó của hoá đơn giấy phai.
7. **TC# là khoá chống trùng lý tưởng** cho hoá đơn Sam's: cùng TC# = cùng 1 lần mua, dù nạp bằng ảnh chụp màn hình, PDF hay chụp giấy.

## Phân loại — ĐÃ XÁC NHẬN

- Thẻ Mastercard Debit đuôi **2586 = BUSINESS** (user xác nhận 2026-11-08 21:51 CST).
- → Hoá đơn Sample 001 xếp vào **Business**. Đây là thẻ đầu tiên trong sổ đăng ký thẻ của app.

## Mục đích business (anh xác nhận 2026-11-08 23:44 CST)
- Anh nói nguyên văn: "Mua nước cho khách và nhân viên uống" — hoá đơn này là nước uống phục vụ khách + nhân viên tại business.
- Phân loại: Business · Mục gợi ý: Vật Tư (Supplies — Schedule C line 22). Ghi chú mục đích E4: "Nước uống cho khách và nhân viên".

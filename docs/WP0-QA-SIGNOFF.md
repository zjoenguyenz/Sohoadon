# WP0 — QA KÝ NHẬN THỨ TỰ GÓI WP1→WP9
**Vai trò ký:** Giám sát độc lập (QA/Supervisor) theo TEAM.md — không viết code,
chỉ kiểm và giữ cổng.
**Ngày ký:** 2026-11-09 02:41 CST (ca trực sohoadon-build2-247).
**Kết quả: QA ✓ — KÝ NHẬN** thứ tự gói WP1→WP9 của BUILD2-MASTER-PLAN,
theo đúng điều kiện ở Master Plan §5.0. WP0 qua cổng; gói tiếp theo được mở
là **WP1** (cửa chẩn đoán F3), chưa mở WP2 trở đi.

## Tờ khai trung thực (claims / evidence / unverified)
- [ĐÃ KIỂM] = ca này tự đọc/grep file thật, ghi rõ file + dòng/mục.
- [CHƯA KIỂM CHỨNG] = giữ nguyên nhãn, không dùng làm căn cứ ký.

## Căn cứ đã đối chiếu (bằng chứng file)
1. **Luật tầng KHÔNG đổi — điều kiện tiên quyết của §5.0.** QA-VERDICT Phụ lục B
   xếp: Tầng 0 chất lượng đọc (0.1 engine · 0.2 F1-PDF · 0.3 bảng điểm ·
   0.4 F3 + C-18) → Tầng 1 niềm tin dữ liệu → Tầng 2 đúng luật → Tầng 3–4.
   Master Plan WP6 = Tầng 1, WP7 = Tầng 2, WP8/WP9 = Tầng 3–4, và mọi gói
   thuộc Tầng 0 (WP1 F3, WP3 PDF, WP4 engine, WP5 C-18/C-11) đều nằm TRƯỚC
   WP6. Thứ tự tầng và cổng phát hành §3.1 giữ nguyên — chỉ thứ tự gói
   TRONG Tầng 0 được sắp lại. ✓
2. **WP1 (F3) đi đầu là đúng theo chính QA-VERDICT.** Phụ lục B §0.4 ghi F3 là
   "(điều kiện để chấm và chẩn đoán 0.1)" — không có cửa xem văn bản OCR gốc
   thì cơ chế hỏng của Vision vẫn là suy luận (QA-VERDICT §1.2 F2/F3;
   CODE-AUDIT mục F3: `ocrRawText` được lưu nhưng không hiển thị ở màn nào).
   Đặt dụng cụ đo trước mọi gói đọc là phụ thuộc kỹ thuật thật, không phải
   sở thích. ✓
3. **WP2 (model) trước WP3 (PDF) là đúng phụ thuộc.** ACCOUNTING-SPEC §5.2
   (dòng 220–238): thuế bị gộp 1 số (`taxCents` duy nhất) trong khi chuẩn đòi
   `taxLines[]`; thiếu `sourceType` (chuẩn F3, dòng 98) và `originalImages[]`
   dạng danh sách (chuẩn F1, dòng 96–97). Nghiệm thu §F đòi 2 dòng thuế riêng
   (9.60 / 3.90) và WP3 phải lưu file PDF gốc làm bằng chứng — cả hai đều cần
   ô chứa của model mới trước. Làm PDF trên model cũ = làm hai lần, nghiệm
   thu hai lần. ✓
4. **WP4 (thi đấu engine) sau WP2/WP3 không vi phạm luật "thua là bỏ".**
   Hai ứng viên vẫn chấm trên CÙNG bảng điểm WP0 (SCORECARD.md đã đóng băng,
   điểm nền Build 1 đã ghi), cộng mẫu 002-C; engine thua vẫn bị loại hẳn.
   "Hai lượt đọc" chỉ là cấu hình đo của từng ứng viên (Master Plan §5.1),
   không phải lai ghép. Thứ tự này chỉ dời thời điểm thi đấu trong Tầng 0,
   không dời nó sang sau Tầng 1. ✓
5. **WP5 (C-18/C-11) vẫn thuộc Tầng 0 và trước WP6.** Khớp Phụ lục B §0.4
   (C-18 nằm trong Tầng 0) và Phần 3 Tầng 2 của QA-VERDICT (C-11 ở tầng đúng
   luật được WP7 rà lại ở phía parser) — không mâu thuẫn: WP5 xử lý kỷ luật
   độ tin cậy cho tiệm/ngày, WP7 xử lý các luật bóc tách còn lại. ✓
6. **Bảng điểm WP0 đã đủ điều kiện cổng.** SCORECARD.md tồn tại: đáp án chuẩn
   001/002/003 + điểm nền Build 1 (002: tiệm✓ ngày✓ tổng✗-có cờ món✗;
   003: tiệm✗-KHÔNG cờ ngày✓ tổng✗-có cờ món✗) khớp QA-VERDICT Phụ lục B
   §0.3 và Master Plan §3.1; luật qua cổng ghi nguyên văn; làn lab tách riêng,
   không tính điểm cổng. ✓

## Điều kiện kèm theo chữ ký (bắt buộc, ghi để các ca sau không trôi)
- Nếu bất kỳ gói Tầng 0 nào (WP1/WP3/WP4/WP5) chưa có bằng chứng nghiệm thu
  mà WP6 đã mở, chữ ký này tự hết hiệu lực — quay về thứ tự Phụ lục B và
  trình lại QA (Master Plan §4.1, §5.0).
- Chữ ký này chỉ ký NHẬN THỨ TỰ GÓI. Nó không phải chữ ký cổng cho bất kỳ
  bản build/code nào; mỗi gói vẫn phải qua đủ Design ✓ / Code ✓ / QA ✓ +
  Wally duyệt cuối trước khi đẩy code (TEAM.md), và code không được đẩy
  trong ca trực — chỉ chuẩn bị tới cổng chờ thẻ duyệt của anh.
- Mẫu 001 trên máy thật và đường camera (002-C) vẫn [CHƯA KIỂM CHỨNG];
  không khẳng định nào trong văn bản này dựa vào chúng.

— Giám sát độc lập (QA/Supervisor), ca trực 2026-11-09 02:41 CST.

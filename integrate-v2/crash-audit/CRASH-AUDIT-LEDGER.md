# CRASH-AUDIT — Sổ rà soát tĩnh nguy cơ crash của bản core-v2-1 (run #34)

Ca trực 2026-11-11 20:40 CST — đúng MỘT bước theo hàng việc sau sự cố
anh báo 20:37 CST (TEAM.md L-2026-11-11-8): quét tờ 2 thì app tự tắt.
Phạm vi: 3 file staging của gói INTEGRATE-V2 (`Parser.swift` 2647 dòng ·
`ScanView.swift` 722 dòng · `ReceiptViews.swift` 1250 dòng) — theo
`integrate-v2/AFTER.md` đây là nguồn của run #34; đối chiếu phụ trên
binary IPA run #34 đã tải tại bàn (`downloads/SoHoaDon-CORE-V2-run34-
2026-11-11.ipa`): binary CÓ ký hiệu `parseGenericItemsV2`,
`extractSamelineItems`, `yieldScore` (khớp staging); chuỗi tem
`core-v2-1` không soi được bằng strings (small-string ≤15 ký tự —
đúng kỳ vọng kỹ thuật đã ghi ở TEAM L-2026-11-10-4, không kết luận gì
từ đó). KHÔNG đụng Swift, KHÔNG sửa code ở ca này.

## 1. Đường sống (reachable) của một lượt quét — đã truy bằng grep

`ScanView.process` (ScanView.swift:238) → `recognizeLines` (:422,
2 ứng viên gốc/phái sinh, hàng đợi nền) → `ReceiptParser.parse`
(điểm gọi duy nhất: ScanView:258 + :331 đường PDF; ReceiptViews:802
qua `reparse` → cũng vào `parse`) → ReviewView.save (ReceiptViews:1148).

**Khối Reconcile là MÃ CHẾT trong bản này:** `parseAndReconcile`
(Parser.swift:1987) và `ReconcileSession` (:2582) KHÔNG có điểm gọi
nào trong ScanView/ReceiptViews (grep toàn 3 file: chỉ tự tham chiếu
bên trong chính khối). Mọi điểm nghi trong khối đó (xem mục 3) vì vậy
KHÔNG thể là nguyên nhân crash khi quét.

## 2. Các điểm nghi ở ĐƯỜNG SỐNG — đã đọc trực tiếp, đều có chặn

| Điểm | Vị trí | Kết luận |
|---|---|---|
| `lines[index+1]` (tiền-trước-nhãn) | Parser:448 | Chặn `index + 1 < lines.count` cùng điều kiện — AN TOÀN |
| `lines[index+1]` (ITEM COUNT) | Parser:862 | Chặn `index + 1 < lines.count` — AN TOÀN |
| `0...(lineTokens.count − needleTokens.count)` | Parser:1363 | Bọc trong `if lineTokens.count >= needleTokens.count` — AN TOÀN |
| `1...aChars.count` (Levenshtein) | Parser:1396 | Trả sớm khi rỗng (:1393-1394); caller đòi token dài ≥5 — AN TOÀN |
| `out[lp]/out[hp]/out[pos]` (cùng-dòng) | Parser:893-1031 | Vị trí chỉ sinh từ `out.count-1` khi append; `out` không bị xoá phần tử trong hàm — AN TOÀN theo cấu trúc |
| `zoneStart..<lines.count` (anchorTotals) | Parser:1083/1107 | `guard zoneStart < lines.count` tại :1080 — AN TOÀN |
| Chia số nguyên `amount/unit`, `amount/qty` | Parser:2342/2390/2397 | Đều chặn `!= 0` trước; lại nằm trong khối Reconcile chết — AN TOÀN + không chạm tới được |
| Vòng lát `while top < h` | ScanView:595 | `step = 1400` hằng số > 0 + `break` tường minh khi lát cuối — KHÔNG treo được |
| `rows[rows.count − 1]` | ScanView:673 | Chỉ chạy khi `rows.last` tồn tại — AN TOÀN |
| Vision `handler.perform` | ScanView:542/620 | `do/catch` trả nil/[] — fail-open |
| Ảnh phái sinh (CI) | ScanView:536-582 | Mọi bước lỗi đều trả nil → bỏ ứng viên 2 — fail-open |
| Lưu SwiftData (đường giữa tờ 1 → tờ 2) | ReceiptViews:609-1247 | Mọi `save()` là `try?`; `dropFirst` ở :1178/1180 có `hasPrefix` chặn trước — KHÔNG thấy vector crash |
| `dedupeOverlap` O(n²) | ScanView:641 | Không phải trap; chạy trên hàng đợi nền (main thread rảnh → không khớp mẫu watchdog) |

## 3. Điểm nghi trong khối Reconcile (mã chết — ghi để khỏi truy lại)

- `r.subtotalCents!` (Parser:2094): có bình luận khẳng định + nhánh
  trước trả sớm khi (subtotal nil ∧ total có) — nhưng nhánh
  (subtotal nil ∧ total nil) rơi xuống điểm này theo đọc tĩnh là
  CHƯA KHẮC được hoàn toàn bằng mắt; dù sao KHÔNG chạm tới được
  trong bản này (mục 1). Nếu sau này nối Reconcile vào đường sống,
  phải xử điểm này TRƯỚC.
- `best[$0]!` (Parser:2570): khoá sinh từ chính `order` — an toàn
  theo cấu trúc. DFS `dfs` (:1947): đệ quy có `nodeCap = 100_000`
  chặn + độ sâu bị giới hạn bởi số món × maxEdits — có ngân sách.

## 4. Kiểm thực nghiệm tầng logic (bản gương Python của chính Parser này)

`run_crash_stress.py` (cùng thư mục; kết quả:
`crash-stress-results.txt`): **800 ca, 0 ngoại lệ** — 132 file
dòng-cuối buổi đo × {nguyên văn, xáo trộn, cắt nửa, nhân ba, đảo
ngược, chèn token tiền rác} + ca biên (rỗng, 1 dòng, tiền khổng lồ,
qty 0, dòng 5000 ký tự, 5000 dòng lặp). Thời gian: ca thật chậm nhất
0,032s; ca tổng hợp 5000 dòng 0,77s (tốc độ Python; Swift native kỳ
vọng nhanh hơn — đây là bằng chứng CHỐNG rủi ro watchdog ở tầng
parser, không phải số đo trên máy).

## 5. Nguy cơ lý thuyết còn lại (GHI NHÃN: chưa chứng minh, không phải nguyên nhân đã kết luận)

1. **Tràn Int trong `moneyToCents`** (Parser:1660): phần đô-la của
   mẫu tiền không giới hạn số chữ số; token dạng `<≥17 chữ số>.dd`
   mà vẫn qua được `Int(...)` (≤ 9,2×10¹⁸) thì phép `dollars * 100`
   có thể tràn → Swift trap. Cần OCR nhả đúng dạng token này —
   khả năng thấp, gương Python không tái hiện được (số nguyên không
   giới hạn). Vá rẻ khi mở băng: giới hạn độ dài phần đô-la /
   phép nhân có báo tràn.
2. **Jetsam (hết bộ nhớ) ở lượt quét 2**: 2 lượt OCR ứng viên trên
   ảnh full-res + cắt lát + `CIContext` tạo mới mỗi lần phái sinh —
   đỉnh bộ nhớ CHƯA ĐO. Jetsam làm app "tự tắt" giống hệt crash
   dưới mắt người dùng nhưng để lại log JetsamEvent, không phải
   .ips. Không khẳng định cũng không loại được từ mã nguồn.
3. **Ngoài phạm vi staging**: `ImageStore` / model / `ContentView`
   không nằm trong 3 file của gói INTEGRATE-V2 (không đổi theo
   AFTER.md) — ca này không rà; trạng thái riêng của lượt quét 2
   ở các file đó chưa được kiểm.

## 6. Tuyên bố trung thực 3 phần

- **Đã chứng minh:** đường sống của lượt quét đã truy hết bằng
  grep + đọc trực tiếp từng điểm nghi (mục 1-2); khối Reconcile
  không chạm tới được từ luồng quét; bản gương chạy 800 ca 0
  ngoại lệ với thời gian nhỏ (mục 4); binary run #34 chứa đúng
  các ký hiệu của parser v2 + yieldScore.
- **Chưa chứng minh:** NGUYÊN NHÂN GỐC của lần tự tắt 20:37 —
  rà tĩnh KHÔNG tìm thấy smoking gun trong 3 file. Bằng chứng
  quyết định còn thiếu: **log sự cố trên máy anh** (Cài đặt →
  Quyền riêng tư & Bảo mật → Phân tích & Cải tiến → Dữ liệu Phân
  tích: file `SoHoaDon-*.ips` = trap thật, `JetsamEvent-*.ips`
  = hết bộ nhớ, tại mốc ~20:37 2026-11-11). Có log đó mới phân
  xử được trap/jetsam/watchdog — đúng điều kiện mở băng (a) của
  L-2026-11-11-8 đòi "bằng chứng", không đoán thay.
- **Chưa làm:** không sửa code nào ở ca này (kể cả vá lý thuyết
  mục 5.1 — để Leader quyết cùng nhịp mở băng); chưa rà
  ImageStore/model; độ lệch đọc SỐNG của tờ T-Johnnys (Σ 47.87 vs
  bench) là tuyến riêng (dòng ScanView sống ≠ dòng bench đóng
  băng), ca này không đụng.

**Bước tiếp theo:** chat chính/Wally xin anh log phân tích trên máy
(hoặc kết nối Xcode lấy crash log) tại mốc 20:37 → phân loại
trap/jetsam/watchdog rồi mới định gói sửa; song song, điều kiện mở
băng (c) vẫn giữ nguyên: quét trong app tờ T-Johnnys từ ẢNH GỐC +
2 tờ liên tiếp không tắt — chấm trên file bench một mình không tính.

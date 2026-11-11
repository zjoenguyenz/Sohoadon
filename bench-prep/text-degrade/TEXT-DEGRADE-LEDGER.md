# SỔ G2 — BỘ SUY BIẾN CHỮ (xây + chạy 2026-11-11, ca trực 00:40 CST)

Việc độc lập làm trong lúc chờ 10 ảnh thật (L-R) và luồng OCR gốc
trên máy — lấp khoảng trống cổng **G2** của `core-redo/ACCEPTANCE.md`
§3.3/§5: trước ca này bộ suy biến chữ CHƯA HỀ TỒN TẠI trong repo
(chỉ có suy biến ẢNH 18 ca); §3.5 điều kiện (1) của buổi đo vì vậy
chưa bao giờ đạt.

## Đã làm
- `run_text_degrade.py`: sinh 24 luồng suy biến ĐÓNG BĂNG vào
  `flows/T01…T24.txt` từ 3 luồng gốc (001 THẬT · 003 THẬT · 002
  TÁI DỰNG — chỉ 1 ca T05, ghi nhãn rõ), đủ 6 họ bệnh §3.3:
  SPLIT ×4 · DROP ×6 · NOISE ×5 · BEFORE ×2 (+T02 đối chứng chứa
  dạng BEFORE nguyên bản của 003) · DUP ×3 · GARB ×2 · CTRL ×2.
- Bộ máy bị chấm: `m1fix/port.py parse(fixed=True)` +
  `core-redo/reconcile.py` — cặp mirror đã đối chiếu Swift ở
  P2-3 crosscheck 13/13. Phán quyết từng ca theo Lớp D §2.3:
  CORRECT / CORRECT-REPAIRED / FLAGGED / SILENT-WRONG, bao phủ cờ
  tính theo validate (V1/V2/V4/thiếu-tổng) + trạng thái reconcile.
- `verify_text_degrade.py` (verifier độc lập, đọc từ đĩa):
  verdict khớp bảng **24/24** · flows tái lập byte-trùng **24/24**
  khi chạy lại runner · đủ 6 họ + CTRL · mọi flow suy biến khác
  gốc, 2 ca đối chứng trùng gốc.

## Kết quả (text-degrade-results.txt)
**24 ca = 10 CORRECT/CORRECT-REPAIRED + 14 FLAGGED + 0 SILENT-WRONG
→ G2 GATE: PASS** (ở tầng T3+T4).
- 2 ca được reconcile sửa có-cờ về đúng tuyệt đối: T03 (xé dòng
  SPRITE — kênh ORPHAN/TOKEN, fixes=1), T13 (token 17.7B — fixes=1).
- 3 ca FLAGGED không có cờ validate tương ứng (T10/T14/T18 — mất
  subtotal) được bao phủ ở TẦNG RECONCILE bằng trạng thái
  TOTAL_ONLY + regionHints đọc-lại vùng tổng; bảng kết quả ghi rõ
  điều này ở chân bảng, không giấu.
- T24 (rác "TOTAL 999.99" chèn trước khối tổng thật của 003):
  parser lấy total giả 99999, nhưng V2 + ANCHOR_CONFLICT bắt —
  FLAGGED, không im lặng.

## Chạy lại toàn bộ cổng chữ cũ trong cùng ca (điều kiện §3.5(1) vế sau)
ledger_check PASS · m1fix port **13/13** · reparse **11/11** ·
rowmerge **9/9** (phải chạy trong `wp4-fixtures/` — quirk import
có từ trước, không phải hồi quy) · F2b **10/10** · vendor **19/19** ·
extract **7/7** · reconcile cases **13/13** · P2-3 crosscheck
**13/13** · synthetic verify **PASS**.

## Tuyên bố trung thực 3 phần
- **Đã chứng minh:** cổng G2 đạt ở tầng chữ T3+T4 trên bộ máy
  mirror hiện hành — mọi ca suy biến hoặc ra đúng 3 đẳng thức +
  đáp án đóng băng, hoặc có cờ đúng tầng; 0 số-sai-không-cờ.
  Điều kiện §3.5(1) (nửa offline) NAY ĐỦ.
- **Chưa chứng minh:** (a) Swift thật của P2 trên máy có hành vi
  bằng mirror hay không — chỉ buổi đo phán; (b) bao phủ cờ của 3 ca
  TOTAL_ONLY ở tầng giao diện app (mirror có trạng thái + hint,
  app hiển thị ra sao chưa đo); (c) T1/T2 (engine ảnh, ráp mảnh
  thật) — bộ này không chạm, đúng phạm vi §3.3.
- **Chưa làm / vẫn chặn buổi đo:** §3.5(2) còn thiếu danh sách ca
  lab WildReceipt đã chọn (việc độc lập, ca sau làm được) và 10 ca
  thật L-R (chờ anh gửi); §3.5(3) luồng OCR gốc trên máy của tờ
  Sam's run #26 VẪN chưa về tay đội. Buổi đo CHƯA đủ điều kiện —
  ca này không kêu anh cài/test gì.

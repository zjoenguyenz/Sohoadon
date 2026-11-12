# Harness tự chạy — cổng thi hành LUẬT 100 LƯỢT (2026-11-12)

Anh ban luật: *"Tự chạy liên tục ít nhất 100 lần thành công
liên tục mới đưa test. Chỉ đưa test bản patch lớn."* VM của
đội **không có toolchain Swift** (đã kiểm: không `swiftc` ở
mọi vị trí chuẩn) nên lượt chạy thật phải diễn ra trên CI
macOS của GitHub Actions — cùng runner vốn đã biên dịch các
bản build. Gói này là staging hoàn chỉnh để Leader đẩy MỘT
patch lớn: harness + workflow + fixture + bẫy đột biến.

## Trong gói

| File | Vai trò |
|---|---|
| `HarnessApp/main.swift` | Driver CLI: probe / images / fixture / fuzz |
| `HarnessApp/HarnessShims.swift` | Shim 1 biểu tượng (ReceiptReader.stageBreadcrumb) để OCREngine nguyên văn biên dịch được ngoài ReadPipeline |
| `project-harness.yml` | XcodeGen: target tool macOS, nạp 9 file nguồn app nguyên văn |
| `workflow/harness-ci.yml` | NHÁP workflow — phải cài vào `.github/workflows/` qua đường trình duyệt (connector không đẩy được workflow) |
| `fixtures/L-R01-raw-a-original.json` | Luồng đã ghi của L-R01 (53 dòng + hộp, engine cũ, phiên 2026-11-11) — ca control |

## Ba cổng trong workflow

1. **Control:** parse luồng đã ghi bằng Swift thật → phải
   `SURVIVED` (đối chứng kết luận audit bằng gương Python).
2. **Luật 100 lượt:** 33 ảnh × 100 set liên tiếp qua Vision
   macOS → ráp dòng → parse → chấm, cấu hình mặc định của
   BenchShell run #46 (`--lang old --topk 1`). Một crash ở
   bất kỳ lượt nào trong 3.300 lượt đọc = job đỏ. Kèm ma trận
   phụ: 3 set cho mỗi tổ hợp cấu hình còn lại.
3. **Fuzz:** ~37 đột biến trên luồng ghi, mỗi đột biến một
   process riêng; process chết vì signal = **tái hiện được**
   = job đỏ, id đột biến ghi trong `fuzz-results.txt`.

## Đọc kết quả để khoá cơ chế crash L-R01

- Ảnh nào / set nào chết ở cổng 2 + mốc `[stage]` cuối trong
  log → biết chết trong engine hay sau engine.
- Cột `frag[boxes=… nonFinite=N]` / `asm[…]` của L-R01: N > 0
  = hộp không-hữu-hạn tồn tại trong luồng Vision thật → ủng
  hộ ứng viên A (Parser.swift:1999, xem HARNESS-REPRO.md).
- `streams/L-R01.stream.json` = luồng thật (bản macOS) của
  L-R01 — đối chiếu trực tiếp với fixture đã ghi để thấy
  token/hộp nào chỉ có ở luồng thật.
- Fuzz id nào DIED → cơ chế tương ứng đã tái hiện tại bàn;
  bản sửa tối thiểu bám đúng id đó.

## Giới hạn phải nói thẳng

- Vision macOS ≠ Vision iOS 27.2 beta: cùng họ engine, cùng
  API, nhưng KHÔNG phải cùng một bản dựng. Harness chạy xanh
  100/100 là điều kiện CẦN theo luật của anh, không phải bảo
  đảm tuyệt đối trên máy anh; harness ĐỎ thì là bằng chứng
  cứng để sửa trước khi giao.
- Chuỗi ứng viên đầy đủ (CoreImage, ROI, finalize) nằm ở
  ReadPipeline (UIKit) — ngoài harness. Phạm vi harness =
  đúng thân runCandidate, là nơi breadcrumb run #46 đã khoá
  điểm chết (bên trong parse).
- Driver chấm E1/E2/score bằng CandidateScorer nguyên văn;
  công thức `integrity` là bản driver (ghi rõ trong code) —
  cổng luật là SỐNG + khép sổ, không phải khớp điểm tuyệt đối.

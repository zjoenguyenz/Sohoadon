# ĐẶC TẢ JSON KẾT QUẢ ĐO — BenchApp → bộ chấm offline

Người soạn: **QA/Supervisor** (đội Sổ Hoá Đơn) · Ngày: 2026-11-10
Nguồn luật: `core-redo/ENGINE-REPORT.md` §5.1 (dụng cụ đo) + §5.3/§5.4
(ngưỡng + công thức quyết) · `core-redo/ACCEPTANCE.md` §2 (chỉ số M1–M11,
đẳng thức E1/E2/E3) · `core-redo/CORE-REDO-PROPOSAL.md` (buổi đo duy nhất).

> **Mục đích:** BenchApp chạy MỌI cấu hình trên MỌI ảnh bench ngay trên máy,
> xuất **ĐÚNG MỘT file JSON**. File đó phải chứa đủ dữ kiện để bộ chấm
> offline (`bench_score.py`, parser đóng băng `m1fix/port.py`) tái lập
> toàn bộ việc chấm — **không được cần hỏi lại máy bất cứ điều gì**: thiếu
> một trường là buổi đo mất giá trị ở ca đó, vì không có buổi đo lại.

---

## 1. Cấu trúc tổng

```jsonc
{
  "schema": "sohoadon-bench",        // hằng số nhận diện, BẮT BUỘC
  "schema_version": 1,               // số nguyên, xem mục 6
  "generated_at": "2026-..T..:..:..+07:00",   // ISO-8601 có múi giờ
  "app": {
    "name": "BenchApp",
    "build": "string",               // bản BenchApp đã chạy
    "parser_version": "string"       // currentParserVersion tại thời điểm đo
  },
  "device": { "model": "string", "ios": "string" },        // tuỳ chọn
  "supported_languages": {           // tuỳ chọn nhưng NÊN có: phân xử CKBC
    "vision_classic": ["vi-VN", "en-US"],                  // ngôn ngữ (a) khai
    "recognize_documents": ["en-US"]                       // ngôn ngữ (b) THẬT
  },
  "configs": [ /* mục 2 */ ],
  "images":  [ /* mục 3 */ ],
  "runs":    [ /* mục 4 */ ]
}
```

## 2. `configs[]` — mỗi cấu hình thi đấu là một mục

| Trường | Kiểu | Bắt buộc | Nghĩa |
|---|---|---|---|
| `id` | string | ✓ | Mã duy nhất, ổn định: `A0-current` (đối chứng (a) hiện tại), `A1`, `A1A2`, `B1`, `B2`, `CORE2`… Đối chứng mặc định của bộ chấm là `A0-current` |
| `name` | string | ✓ | Tên người đọc được |
| `engine` | enum | ✓ | `vision-classic` · `recognize-documents` · `merged-core` (kiến trúc hợp nhất đa lượt) |
| `variant` | string | ✓ | Biến thể ảnh/đường đọc: `original` · `derived` · `upscale` · `sliced` · `full-v2`… (chuỗi tự do, ghi ổn định) |
| `baseline` | bool | | `true` cho đúng một cấu hình đối chứng |

## 3. `images[]` — mỗi ảnh bench là một mục

| Trường | Kiểu | Bắt buộc | Nghĩa |
|---|---|---|---|
| `id` | string | ✓ | Mã ca theo ACCEPTANCE/ENGINE: `N-001` · `N-002` · `C-003` · `C-002C` · `S-0` · `S-1` · `S-2` · `L1-01`… |
| `form` | enum | ✓ | Trục DẠNG (hạng nhất): `N` nạp sẵn · `C` chụp thường · `S` quét tài liệu |
| `difficulty` | enum | ✓ | Trục KHÓ: `L0` sạch · `L1` nhăn/cũ thật · `L2` phai nhiệt · `L3` lệch sáng · `L4` phân giải thấp · `L5` dài cực trị |
| `origin` | enum | ✓ | `real` (tờ/ảnh thật) · `synthetic` (suy biến kỹ thuật số — chỉ tham khảo, trọng số ×1 kể cả ở lớp khó) · `lab` (ảnh hoá đơn thật của bộ dữ liệu lab WildReceipt — làn độ bền, trọng số ×1, KHÔNG chấm bằng sổ GT; cộng thêm 2026-11-11, xem mục 6.6) |
| `gt_id` | string | ✓ | Khoá đáp án đóng băng trong sổ đáp án của bộ chấm (`GT-SAMS-F` · `GT-HD-003` · …). Đáp án KHÔNG nhúng trong file đo — đáp án sống ở phía đội, đóng băng trước buổi đo, chống hậu kiểm |
| `source_file` | string | | Tên file ảnh gốc trong `samples/`/corpus |
| `pages` | int\|null | | Riêng dạng `S`: số trang scan (hoá đơn dài có vừa 1 trang không — dữ kiện CKBC của ENGINE §5.2). Không biết → `null` |
| `width_px`, `height_px` | int | | Kích thước ảnh thật đã nạp vào engine |

## 4. `runs[]` — kết quả từng (ảnh × cấu hình)

Mỗi mục = một ảnh chạy dưới một cấu hình:

```jsonc
{
  "image_id": "N-001",
  "config_id": "A1",
  "passes": [ /* mục 5 — ÍT NHẤT một pass role "final" */ ]
}
```

## 5. `passes[]` — từng lượt đọc trong một lần chạy

| Trường | Kiểu | Bắt buộc | Nghĩa |
|---|---|---|---|
| `pass_id` | string | ✓ | Mã lượt: `final` · `raw-a` · `raw-b` · `roi-1`… |
| `role` | enum | ✓ | `final` = bộ dòng SAU hợp nhất, chính là bộ sẽ nạp parser (mỗi run đúng **một** pass `final`; bộ chấm chỉ chấm pass này) · `raw` = lượt đọc thô của một engine (chẩn đoán tầng T1/T2) · `roi` = lượt đọc lại theo vùng (chẩn đoán) |
| `engine` | enum | ✓ | Như `configs.engine` |
| `variant` | string | ✓ | Biến thể ảnh của riêng lượt này |
| `duration_ms` | number | ✓ | Thời gian lượt đọc (điểm phụ §5.3 ENGINE) |
| `lines` | array | ✓ | Xem 5.1 |
| `tables` | array | | CHỈ engine (b) nếu xuất được — xem 5.2. Không xuất được → để mảng rỗng + ghi `tables_note` |
| `detected_data` | array | | CHỈ engine (b) nếu xuất được — xem 5.3 |
| `notes` | string | | Ghi chú tự do (lỗi lượt, fallback đã xảy ra…) |

### 5.1 `lines[]` — trái tim của file đo

| Trường | Kiểu | Bắt buộc | Nghĩa |
|---|---|---|---|
| `text` | string | ✓ | Chuỗi của ứng viên đứng đầu (top-1) |
| `confidence` | number 0–1 | ✓ | Độ tin cậy của top-1. Thiếu nó, parser đóng băng không tái lập được các cờ tin cậy → ca đó coi như không đo được |
| `box` | object\|null | ✓ | `{x, y, w, h}` — toạ độ **chuẩn hoá 0–1, gốc DƯỚI–TRÁI** (quy ước Vision). Bắt buộc có để phân định tầng T2 (ráp mảnh) khi chấm; ảnh/PDF không có hộp → `null` và ghi lý do ở `notes` của pass |
| `candidates` | array | | `topCandidates(3)`: `[{text, confidence}, …]` gồm cả top-1. Engine (b): lấy từ `RecognizedTextObservation.topCandidates` nếu SDK chạy thật có |

Thứ tự `lines` = thứ tự đọc trên→dưới như app sẽ nạp cho parser. Bộ chấm
KHÔNG tự sắp xếp lại — sắp xếp là một phần của đường ống bị đo.

### 5.2 `tables[]` (engine (b), nếu xuất được)

```jsonc
{ "box": {x,y,w,h},
  "rows": [ [ {"text": "…", "box": {…}|null}, … ], … ] }   // ô theo hàng × cột
```

### 5.3 `detected_data[]` (engine (b), nếu xuất được)

```jsonc
{ "kind": "money|date|payment|other", "text": "…", "value": "…"|null }
```

`tables`/`detected_data` là dữ kiện CẤU TRÚC phụ: bộ chấm v1 chưa chấm
chúng vào điểm (điểm chỉ từ `lines` qua parser đóng băng — một thước đo
duy nhất cho mọi engine), nhưng chúng là bằng chứng để QA phán vai trò
của (b) theo ENGINE §5.4.5. Thiếu chúng không làm rớt ca; thiếu
`lines`/`confidence`/`box` thì có.

## 6. Quy tắc phiên bản schema

1. `schema_version` là **số nguyên tăng dần**. Phiên bản hiện tại: **1**.
2. Thay đổi **phá vỡ** (đổi nghĩa trường, bỏ trường bắt buộc, đổi quy ước
   toạ độ) → **tăng số nguyên** và ghi mục thay đổi vào đầu file này.
   Bộ chấm từ chối schema lạ với thông báo rõ, không chấm đoán.
3. Thay đổi **thuần cộng** (thêm trường tuỳ chọn mới) → giữ nguyên số;
   bộ chấm **bỏ qua trường lạ** ở mọi cấp.
4. BenchApp phải luôn xuất `schema` + `schema_version`; thiếu một trong
   hai → file không hợp lệ, buổi đo mất ca.
5. Đáp án (`gt_id` → bộ số) sống trong **sổ đáp án của bộ chấm**
   (`bench_score.py`, mở rộng qua `--answers answers.json`), KHÔNG trong
   file đo — để đáp án không bao giờ bị "chỉnh cho khớp" sau buổi đo.
6. **Lịch sử thay đổi:** 2026-11-11 (Leader chốt, ca trực 12:40 CST) —
   enum `origin` cộng thêm giá trị `lab` cho 24 ca WildReceipt
   (`bench-prep/lab-assembly/LAB-ASSEMBLY-DECISION.md`). Phân loại
   theo luật trên: đây là thay đổi **thuần cộng** — file đo cũ
   (real/synthetic) đọc và chấm y hệt trước; giá trị mới chỉ xuất
   hiện ở file đo mới; bộ chấm vốn đã cho mọi origin ≠ real trọng
   số ×1 và nay bỏ qua ca lab khỏi vòng chấm GT một cách tường
   minh. `schema_version` **giữ nguyên 1**; BenchApp không phải
   đổi mã kiểu dữ liệu (origin là chuỗi ở cả hai phía). Ca lab
   mang `gt_id` rỗng `""` — đáp án của chúng là nhãn nguyên văn ở
   bảng kê đóng băng phía đội, chấm tay theo hồ sơ LAB.

## 7. Ví dụ rút gọn (1 ảnh × 1 cấu hình × 1 pass)

```json
{
  "schema": "sohoadon-bench", "schema_version": 1,
  "generated_at": "2026-11-10T20:00:00-06:00",
  "app": {"name": "BenchApp", "build": "bench-1", "parser_version": "core2-1"},
  "configs": [{"id": "A0-current", "name": "(a) hiện tại", "engine": "vision-classic", "variant": "original", "baseline": true}],
  "images": [{"id": "N-001", "form": "N", "difficulty": "L0", "origin": "real",
              "gt_id": "GT-SAMS-F", "source_file": "sample-001-sams-club-app-screenshot.jpg",
              "pages": null, "width_px": 1320, "height_px": 2868}],
  "runs": [{"image_id": "N-001", "config_id": "A0-current",
    "passes": [{"pass_id": "final", "role": "final", "engine": "vision-classic",
      "variant": "original", "duration_ms": 812,
      "lines": [{"text": "sam's club", "confidence": 0.9,
                 "box": {"x": 0.31, "y": 0.97, "w": 0.38, "h": 0.012},
                 "candidates": [{"text": "sam's club", "confidence": 0.9}]}]}]}]
}
```

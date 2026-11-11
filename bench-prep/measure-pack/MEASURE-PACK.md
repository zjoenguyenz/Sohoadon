# GÓI ĐO ĐÓNG BĂNG — BẢNG CHẤM IN SẴN + THỨ TỰ BUỔI ĐO DUY NHẤT

Người soạn: ca trực 24/7 (đội Sổ Hoá Đơn) · Đóng băng: 2026-11-11
04:40 CST — việc độc lập làm trong lúc chờ 10 ảnh thật + luồng OCR
gốc trên máy, lấp mục còn thiếu của `core-redo/ACCEPTANCE.md`
§3.5(2) ("tất cả kèm **bảng chấm in sẵn (ca × chỉ số × ngưỡng)**")
và §4.1 ("Gói đo đóng băng: danh sách ảnh theo mã + bảng chấm in
sẵn + thứ tự nạp cố định + hướng dẫn chụp 1 trang"). Trước ca này
cả bốn thứ đó **chưa tồn tại thành tài liệu** — chỉ có chủ trương
rải trong ACCEPTANCE/BENCH-MANIFEST.

Nguồn luật (không tự chế ngưỡng nào): ACCEPTANCE §2.1 (chỉ số
M1–M11, đẳng thức E1/E2/E3) · §2.3 (ngưỡng theo lớp) · §2.4 (luật
tuyệt đối) · §2.5 (đáp án hạt giống) · §4.2 (gói đo 5 phần) ·
§4.3 (giao thức chụp) · §4.4 (phán quyết) · BENCH-MANIFEST §1–§5 ·
sổ lab `lab-wildreceipt/LAB-WILDRECEIPT-LEDGER.md` · BenchCatalog
thật trong `benchapp/BenchCatalog.swift` (45 mục, appBuild
`benchapp-2`, 4 cấu hình A0–A3).

> **Trạng thái gói: ĐÃ ĐÓNG BĂNG Ở TẦNG TÀI LIỆU, buổi đo CHƯA đủ
> điều kiện.** Bảng chấm này khoá *cách chấm*; nó không mở buổi đo.
> Điều kiện chặn còn mở ghi ở mục 7 — thiếu một mục là không xin
> buổi đo (ACCEPTANCE §3.5, cổng G3).

---

## 1. Bảng chấm — `scoresheet.csv` (71 dòng ca)

Sinh xác định bởi `gen_scoresheet.py` từ BenchCatalog thật +
`wildreceipt-subset.csv`; kiểm độc lập bởi
`verify_measure_pack.py`. Một dòng = một ca, với: phần buổi đo ·
mã buổi đo · dạng × khó · nguồn gốc · trạng thái · đáp án/tham
chiếu · **đường chấm** · **hồ sơ ngưỡng** (mục 3) · luật M9.

Tổng kê (đếm lại từ file, khớp BENCH-MANIFEST §5):

| Nhóm | Số ca | Trạng thái |
|---|---|---|
| Catalog BenchApp | 45 | 22 có file (4 thật + 18 synthetic) · 13 THIẾU · 10 ô trống L-R |
| Làn lab WildReceipt W-01…W-24 | 24 | Đã chọn + đóng băng đáp án nhãn; **chưa nhúng BenchApp** |
| Kiểm dữ liệu đã lưu L-01/L-02 | 2 | Ca buổi đo trong app chính (không thuộc BenchApp) |
| **Tổng** | **71** | |

Đường chấm có 4 loại, ghi tường minh từng dòng — không ca nào
được chấm bằng đường khác vào ngày đo:
- `bench_score.py` — ca có đáp án đóng băng dạng GT (22 ca sẵn
  sàng + C-002C/S-1 khi có ảnh, đáp án của chúng đã đóng băng).
- `cho-dap-an` — ca thật chưa có GT: chỉ chấm sau khi Leader chép
  tay + kiểm số học + đóng băng GT và nạp qua `--answers`.
- `tai-bang` — ca lab W (đáp án là nhãn nguyên văn, cách chấm đã
  khoá ở sổ lab) và ca buổi đo chấm bằng ảnh chụp (L-01/L-02).
- `ngoai-bench` — PDF-SAM: đường WP3, BenchApp bản này chỉ đo ảnh.

## 2. Ánh xạ mã buổi đo (§4.2) ↔ mã BenchApp

Hai hệ mã cùng tồn tại và KHÁC nhau ở Phần 1; bảng này là bản dịch
chính thức, buổi đo dùng mã buổi đo, file JSON dùng mã BenchApp:

| Mã buổi đo (§4.2) | Mã BenchApp | Nội dung |
|---|---|---|
| S-01 | N-001 | Mẫu 001 — ảnh app Sam's 1320×2868 |
| S-02 | N-002 | Mẫu 002 — file tải về 554×1457 |
| S-03 | C-002C | Chụp camera thật tờ Sam's giấy — **THIẾU** |
| S-04 | C-003 | Mẫu 003 — Home Depot (bản crop repo là dự phòng; ưu tiên ảnh gốc trong máy anh) |
| S-05-DANH-DỰ | S-0 | Bản scan giấy Sam's — ca cổng danh dự của BENCH-MANIFEST §2. §4.2 Phần 1 chỉ liệt kê 4 dòng nên ca này đứng dòng 5; trượt trọn bộ §F ở cấu hình "giải pháp" = loại cấu hình tại chỗ |
| C-01…C-10 | L-R01…L-R10 | 10 ca thật của anh theo thứ tự ảnh về (Phần 2) |
| D-01…D-18 | D-01…D-18 | 18 ca suy biến ảnh (trùng mã hai phía) |
| B-01…B-05 | (TestB) | Thi đấu engine (b): chạy trên S-01 · S-02 · S-04 + 2 ca khó nhất của Phần 2 — **2 ca này phải chốt tên TRƯỚC buổi đo** ở lần ráp bản bench cuối, không chọn giữa buổi |
| L-01 · L-02 | (app chính) | Kiểm dữ liệu đã lưu (Phần 5) |

Các ô THIẾU cũ của BENCH-MANIFEST §3 (L1-01…03 · L2-01…02 ·
L3-01…02 · L4-02 · L5-01 · S-1 · S-2) giữ nguyên mã trong bảng
chấm ở Phần 2: chúng là *danh sách mong muốn*, đường nạp thực tế
là L-R01…L-R10 (§3.1) — một tờ thật về có thể đồng thời lấp một ô
L-R và một ca mong muốn khi Leader đối chiếu. Làn lab W-01…W-24
đứng ở phần **3B** (giữa Phần 3 và Phần 4 khi đọc kết quả): §4.2
soạn trước khi tập lab được chọn nên không có phần lab; vị trí
này là quyết của gói này, ghi rõ để không ai tưởng §4.2 đã có.

## 3. Hồ sơ ngưỡng (nguyên văn ACCEPTANCE §2.3 — buổi đo không tự chọn)

| Hồ sơ | Áp cho | Ngưỡng |
|---|---|---|
| **A** | Lớp A in rõ/số sạch (N-001, C-002C) | M1·M2·M3·M8 đúng tuyệt đối 100% · E1/E2 lệch **0 xu** · E3 bằng đúng · M7 khớp từng dòng thuế · M10 = 0 · M9 = 0 |
| **B** | Lớp B tải về nét thấp (N-002) | Trọn bộ §F không thiếu số nào (10 dòng · 203.30 · 9.60 · 3.90 · 216.80 · 15 món · khoá TC#) · E1/E2/E3 như lớp A · M9 = 0 |
| **C-SEED** | Mẫu đóng băng 003 + bản quét cặp S-1 | Như A/B về số: The Home Depot · 2025-03-03 12:59 · 96.91 · thuế [8.25] · 105.16 · 3 dòng (6.98/19.97/69.96, dòng 3 SL 2) · Visa 3830. Trượt 1 số = rớt |
| **S0-HONOR** | S-0 | Trọn bộ §F như lớp B (cổng danh dự trong `bench_score.py`: `sectionF`) · trượt = loại cấu hình |
| **C-REAL** | Ca thật mở rộng (L-R sau phân loại, L1/L2/L3/L5, S-2) | M1+M2 **đúng-hoặc-cờ = 100%** · tỉ lệ đúng tuyệt đối **báo cáo số thật** (mục tiêu làm việc ≥ 80% là *đề xuất QA* §6 ACCEPTANCE — không phải cổng) · E1/E2: lệch ≤ 2 xu **hoặc** cờ đỏ V1/V2 + tờ ở lại Hộp Chờ · M3: đúng hoặc gợi ý có cờ · M9 = 0. Hồ sơ của ô L-R đang **tạm khoá** — Leader chốt lại theo lớp thật (L1/L2/L3/L5…) lúc phân loại ảnh về |
| **D** | Suy biến ảnh D-01…D-18 | M1 đúng-hoặc-cờ = 100% · E1/E2 đúng (≤ 2 xu) hoặc cờ đỏ = 100% · M9 = 0 · tỉ lệ đúng tuyệt đối báo cáo **theo từng phép biến đổi** — không đặt % đậu cứng cho lớp D |
| **LAB** | W-01…W-24 | M1/M2 đúng-hoặc-cờ đối chiếu **nhãn nguyên văn** + E1/E2 dạng **đẳng thức nội bộ** (số app đọc đối chiếu lẫn nhau) · M9: ca lab ra số sai không cờ vẫn là bằng chứng chống lại bản, ghi vào báo cáo buổi đo · **không bao giờ** trình như sổ món ngoài (nhãn WildReceipt không cho sổ món đáng tin) |
| **SAVED** | L-01 · L-02 | L-01: mở tờ Home Depot đã lưu → Đọc lại → đủ 3 thành phần Điều 1(b): số đúng · tên/địa chỉ đúng · ảnh gốc hiển thị được. L-02: đóng/mở lại app sau cài đè — 2 tờ cũ còn nguyên, số không đổi (Điều 1(a)) |
| **PDF** | PDF-SAM | Ngoài buổi đo BenchApp: nghiệm thu đường PDF theo Master Plan §3.2 trên chính file đó khi anh có file |

**Luật tuyệt đối phủ lên mọi hồ sơ (§2.4):** M9 > 0 ở bất kỳ ca
nào ⇒ **RỚT TOÀN BỘ BẢN**; điểm % chỉ là số báo cáo, không bao giờ
là điều kiện qua cổng; số app tự suy không được trình thay số in.

## 4. Thứ tự buổi đo cố định (không thêm/bớt ca giữa buổi — §4.1)

BenchApp tự chạy mọi ảnh đã nhúng × 4 cấu hình A0–A3 trong một lần
bấm và xuất 1 file JSON — thứ tự dưới đây là thứ tự của các *đoạn
thủ công* và của việc *đọc kết quả*, khoá theo §4.2:

0. **Buổi chuẩn bị (trước, riêng):** Leader lấp L-R (5 bước ở
   `benchapp/AFTER.md`) + nhúng 24 ảnh lab + chốt tên 2 ca B-04/
   B-05 + ráp bản bench cuối + build xanh có artifact (cổng G5).
1. **Phần 1 — Hạt giống:** S-01 · S-02 · S-04 · S-05-DANH-DỰ qua
   BenchApp (JSON); S-03 chụp bằng camera trong app chính (điểm
   kiểm đường camera riêng).
2. **Phần 2 — Ca thật:** C-01…C-10 (mọi ô L-R đã đóng băng GT).
3. **Phần 3 — Suy biến ảnh:** D-01…D-18. Chỉ rút còn 9 ca (mỗi
   gốc giữ mờ · nghiêng · nhăn) khi thời lượng buổi vượt dự kiến
   — tiêu chí rút đã ghi trước ở §4.2, không rút tuỳ hứng.
4. **Phần 3B — Làn lab:** W-01…W-24 (nếu đã nhúng ở bước 0).
5. **Phần 4 — Thi đấu engine:** B-01…B-05 trong app TestB.
6. **Phần 5 — Dữ liệu đã lưu:** L-01 · L-02 trong app chính.
7. **Điền bảng chấm tại chỗ** theo mục 6 → phán quyết công bố
   ngay cuối buổi (§4.4): ĐẠT / RỚT, không có "gần đạt".

## 5. TRANG HƯỚNG DẪN CHỤP — cắt ra gửi anh khi tới buổi đo (§4.3)

*(Trang này chỉ dùng tại buổi đo đã hẹn; không phải yêu cầu anh
làm gì bây giờ.)*

Với **mỗi tờ** ở Phần 1–3, gửi đúng 3 thứ theo thứ tự:
1. Ảnh **màn Kiểm Lại** của tờ (thấy tiệm/ngày/tổng + mọi cờ).
2. Mục **"Văn bản OCR gốc"** → Sao chép toàn bộ → **dán vào chat**
   (đây là bằng chứng phân định lỗi nằm ở tầng engine / ráp dòng /
   bóc tách).
3. Nếu tờ có **cờ đỏ**: thêm 1 ảnh **màn Chi Tiết** của tờ đó.

Phần 4 (TestB): mỗi ca 1 ảnh màn kết quả + dán văn bản nó đọc
được (nếu TestB không có chỗ sao chép thì ảnh màn là đủ, ghi rõ).
Cuối buổi: 1 ảnh màn Chi Tiết bất kỳ hiện dòng **"Bản bộ đọc của
app: …"** — ảnh tự khai bản đang chạy. File JSON của BenchApp:
bấm **Chạy đo** → nút chia sẻ → gửi **đúng 1 file JSON** về chat.

## 6. Cách điền + phán quyết (§4.4)

- Mỗi ca điền theo từng chỉ số: **đạt / sai-có-cờ / sai-không-cờ**
  (cột điền tay nằm ở bản in của `scoresheet.csv` khi xuất buổi
  đo; file đóng băng này chỉ khoá ca + ngưỡng, không điền sẵn kết
  quả nào).
- Phân định engine: (a) vs (b) trên cùng 5 ca Phần 4 — engine nào
  M1/M2 đúng tuyệt đối nhiều hơn **và** M9 = 0 thì thắng lớp đó;
  hoà thì giữ engine có luồng thô sạch hơn (ít mảnh rác hơn).
- Phân định đường ống: luồng thô đủ dòng mà số sai → lỗi T3/T4
  (sửa tại bàn được); luồng thô thiếu/mảnh rác → lỗi T1/T2.
- **ĐẠT** ⇔ mọi ngưỡng mục 3 đạt trên các phần đã chạy + M9 = 0
  toàn buổi + L-01/L-02 đạt. **RỚT** ⇔ bất kỳ số-sai-không-cờ
  nào, hoặc lớp A/B trượt 1 chỉ số cứng, hoặc L-01/L-02 trượt —
  quay về 4 tuyến với bằng chứng tầng đã thu, ghi nguyên nhân gốc
  + biện pháp chặn vào TEAM.md (Điều 4 B2) trước lần thử tiếp.

## 7. Điều kiện chặn buổi đo — trạng thái thật tại ngày đóng băng

| Điều kiện (§3.5 / §4.1) | Trạng thái |
|---|---|
| (1) Nửa offline đạt: suy biến chữ G2 + cổng chữ cũ xanh | **ĐỦ** — G2 PASS 2026-11-11 00:40 (10 đúng/sửa + 14 cờ + 0 sai-im-lặng); cổng chữ cũ chạy lại xanh cùng ca |
| (2) Nửa trên-máy đóng băng: 18 suy biến + danh sách lab + ca thật kèm bảng chấm | **THIẾU 1 PHẦN** — 18/18 suy biến ✓ · lab 24/24 đã chọn ✓ · **bảng chấm = tài liệu này ✓** · **10 ca thật L-R: CHƯA CÓ (chờ anh gửi)** · 24 ảnh lab chưa nhúng BenchApp (ráp ở bước 0) |
| (3) Luồng OCR gốc trên máy của tờ Sam's run #26 về tay đội + tái hiện được tại bàn | **CHƯA CÓ** — vẫn chờ anh copy từ mục "Văn bản OCR gốc" (cổng G0) |
| Build bản bench cuối xanh + artifact + tên duy nhất + dấu bản (G5) | **CHƯA** — chỉ ráp sau khi L-R về (bản hiện hành `benchapp-2` run #32 là `benchapp-1`, 4 ảnh) |
| TestB sẵn sàng cài song song | **CÓ** — kit `SoHoaDon-TestB-Kit.zip` đã dựng (chưa từng chạy trên máy) |

## 8. Tuyên bố trung thực 3 phần

- **Đã chứng minh:** bảng chấm 71 dòng khớp cơ học với các nguồn
  đóng băng của nó — verifier độc lập kiểm: tập mã ca của bảng ==
  tập mã BenchCatalog (45) + tập W của `wildreceipt-subset.csv`
  (24) + L-01/L-02; mọi ca READY đều mang GT có thật trong sổ đáp
  án của `bench_score.py`; mọi ca synthetic đều hồ sơ D + origin
  synthetic; luật M9 có trên 71/71 dòng; sinh lại CSV byte-trùng.
- **Chưa chứng minh:** (a) ngưỡng C-REAL cho từng ô L-R mới là tạm
  khoá theo lớp chung — lớp thật chỉ biết khi ảnh về; (b) 2 ca
  B-04/B-05 chưa chốt tên (phụ thuộc ca thật khó nhất — chưa có);
  (c) bảng này chưa từng được dùng trong một buổi đo thật — tính
  đủ của nó chỉ phán khi buổi đo đầu tiên điền xong mà không phải
  chế thêm cột nào giữa buổi.
- **Chưa làm:** chưa nhúng 24 ảnh lab, chưa lấp ô L-R nào, chưa
  build bản bench cuối — tất cả thuộc bước 0 của buổi chuẩn bị và
  đều đang chờ đầu vào của anh (10 ảnh thật + luồng OCR gốc).
  Ca này không đụng Swift/schema/pipeline, không kêu anh cài/test
  gì.

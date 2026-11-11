# WORK STATE — Build 2 (ca trực 24/7 cập nhật file này)
Cập nhật lần cuối: 2026-11-10 22:40 CST (ca trực: **SỬA CÂU CŨ
TRONG benchapp/HONESTY.md — việc độc lập ghi sẵn ở ca 20:40,
làm trong lúc chờ ảnh thật**: ca tự kiểm lại từ bằng chứng gốc
trước khi sửa (không dùng lời AFTER.md): 18 ảnh synthetic khớp
sha256 + byte-size với `synthetic-manifest.csv` **18/18** và
byte-trùng `bench-prep/synthetic/images/`; 4 ảnh thật byte-trùng
`samples/` **4/4**; BenchImages 22 file == 22 dòng sources trong
`project.yml`; ngoặc BenchCatalog 7/7 · 85/85 · 5/5;
`appBuild` = `benchapp-2`; luật trọng số trong `bench_score.py`
đọc trực tiếp: origin≠real → ×1, real L1/L2/L5 → ×2. Trên cơ sở
đó, HONESTY.md đã sửa 4 chỗ lỗi thời: (1) bỏ "18 ca suy biến ở
trạng thái THIẾU" khỏi mục Đã chứng minh + cộng khối cập nhật
BENCH-CATALOG-EXT (45 mục = 22 có file + 23 THIẾU: 13 cũ +
L-R01…L-R10); (2) điểm rủi ro XcodeGen sửa "4 file .jpg" →
"22 file .jpg"; (3) mục Chưa chứng minh cộng rõ bản bench cuối
22 ảnh `benchapp-2` CHƯA build cloud (run #32 xanh là
`benchapp-1`, 4 ảnh); (4) mục Chưa làm sửa "Không tạo 18 ảnh
suy biến" → ĐÃ TẠO + đóng băng + nhúng, phần chưa làm chỉ còn
10 ô L-R chờ ảnh thật. Không đụng Swift/schema/pipeline nào.
Tuyên bố trung thực — đã chứng minh: HONESTY.md nay khớp trạng
thái file tại bàn ở các điểm trên (grep câu cũ dạng khẳng định:
0); chưa chứng minh: bản bench 22 ảnh CHƯA build cloud; chưa
làm: chưa nhúng ca thật nào (L-R vẫn trống). **Bước tiếp theo
giữ nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô L-R theo
quy ước 5 bước trong benchapp/AFTER.md → ráp bản bench cuối +
build → buổi đo duy nhất. Điều kiện chặn (1) ca thật + (3)
luồng OCR gốc trên máy VẪN mở; ca này không kêu anh cài/test gì.)
Cập nhật trước đó: 2026-11-10 20:40 CST (ca trực: **KIỂM CHỨNG
ĐỘC LẬP GÓI BENCH-CATALOG-EXT + CHỐT TRỌNG SỐ BỘ CHẤM — ĐẠT
HẾT, ca tự chạy lại từ bằng chứng gốc, không dùng lời AFTER.md**:
gói mở rộng catalog (làm 19:20–19:22 CST, chưa có dòng sổ nào)
nay đã có kiểm chứng Leader: (1) 18 ảnh synthetic trong
`benchapp/BenchImages/` khớp sha256 + byte-size với
`synthetic-manifest.csv` **18/18** và byte-trùng bản gốc ở
`bench-prep/synthetic/images/`; (2) 4 ảnh thật byte-trùng
`samples/` **4/4**; (3) nhất quán 3 phía: BenchCatalog **45 mục
= 22 có file** (4 thật + D-01…D-18 synthetic) **+ 23 THIẾU
tường minh** (13 ô cũ + L-R01…L-R10) — tập file BenchImages
(22) == tập resourceName == tập dòng sources trong project.yml
(22), không thừa không thiếu; ánh xạ D-01=SYN-001-BLUR …
D-18=SYN-003-NOISE đúng thứ tự manifest; ngoặc 7/7 · 85/85 ·
5/5; **0 số đáp án** rò vào catalog/project; appBuild của
benchapp = `benchapp-2` (bench-push/run #32 vẫn `benchapp-1`
— bản bench cuối CHƯA đẩy/build, đúng quy trình: Wally trình
ở chat chính). (4) **Cờ mở trong AFTER.md (trọng số synthetic)
ĐÃ ĐÓNG**: `bench_score.py` `weight_of` nay origin≠real → ×1
bất kể difficulty, real L1/L2/L5 → ×2 — ca kiểm đơn vị
**10/10 tổ hợp** (hơn 4 ca sổ manifest ghi); chạy lại bộ chấm
trên selftest app-format: exit 0, kết quả **byte-trùng** file
đã lưu (8/8 run trọn sổ + §F). Tuyên bố trung thực — đã chứng
minh: toàn vẹn byte + nhất quán kê khai + luật trọng số ở mức
file/script tại bàn; chưa chứng minh: bản bench 22 ảnh CHƯA
build cloud (biên dịch + nạp tài nguyên chỉ phán ở build bench
cuối); chưa làm: chưa nhúng ca thật nào (L-R vẫn trống). **Bước
tiếp theo giữ nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô
L-R theo quy ước 5 bước trong benchapp/AFTER.md (chép tay +
kiểm số học + đóng băng gt) → ráp bản bench cuối + build →
buổi đo duy nhất. Điều kiện chặn (1) ca thật + (3) luồng OCR
gốc trên máy VẪN mở; ca này không kêu anh cài/test gì. Ghi chú
nhỏ cho lần ráp cuối: `benchapp/HONESTY.md` còn câu cũ "không
tạo 18 ảnh suy biến" (thuộc gói benchapp gốc) — AFTER.md mục
BENCH-CATALOG-EXT là bản hiện hành, sửa câu đó khi ráp.)
Cập nhật trước đó: 2026-11-10 18:40 CST (ca trực: **18 ẢNH SUY
BIẾN ĐÃ TẠO + ĐÓNG BĂNG** — việc độc lập làm song song trong lúc
chờ anh gửi 5–8 tờ thật khó, đúng mục còn ghi CHƯA TẠO ở
BENCH-MANIFEST §4 / điều kiện chặn buổi đo §5 mục (2):
`bench-prep/synthetic/` đủ 3 gốc (001/002/003) × 6 phép (BLUR ·
DOWNSCALE ×0.5 · LIGHT · TILT · WRINKLE · NOISE) = 18 ảnh mã
SYN-<gốc>-<phép>, origin synthetic, đáp án kế thừa gt gốc; thông
số chốt trong `make_synthetic.py` + `synthetic-manifest.csv`
(sha256 từng file). Tự kiểm `verify_synthetic.py` **PASS 8/8
nhóm** (`verify-synthetic-results.txt`): đủ 18/18, hash+byte
khớp, kích thước = gốc, mọi ảnh khác gốc, **tạo lại byte-trùng-
hệt 18/18**. Sổ: `synthetic/SYNTHETIC-LEDGER.md` (kèm tuyên bố
trung thực 3 phần + 1 quyết ghi rõ: DOWNSCALE chốt ×0.5 cả 3 gốc
vì 002 vốn 554px, ×0.25 vượt "nặng vừa"). BENCH-MANIFEST §4/§5
đã cập nhật: điều kiện (2) XONG; điều kiện (1) ca thật **VẪN
chờ anh** và (3) luồng OCR gốc trên máy vẫn mở — buổi đo CHƯA
đủ điều kiện, ca này không kêu anh cài/test gì. Ghi chú
D-SYN-18 trong BenchCatalog.swift vẫn ghi "chưa tạo" — để sửa
ở lần ráp bản bench cuối cùng lúc nhúng ca thật, ca này không
đụng Swift.)
Cập nhật trước đó: 2026-11-10 18:17 CST (chat chính: **APP ĐO ĐÃ
SẴN — run #32 XANH + Wally tự soi file**: nhánh bench, artifact
SoHoaDon-BENCH-run32-2026-11-10 (2.09 MB, sha256 e2ea0711…);
soi ruột IPA: đủ 4 ảnh bench trong bundle (N-001/N-002/C-003/
S-0) + nhãn giao diện đo. Một lỗi biên dịch nhỏ (Locale.Language)
đã sửa trên nhánh. ĐIỀU KIỆN CUỐI trước buổi đo duy nhất: anh
chụp gửi 5–8 tờ hoá đơn thật loại khó (cũ/nhăn/phai/lệch sáng)
để Wally đọc tay + kiểm số học + ĐÓNG BĂNG đáp án + nhúng vào
app đo + build lại bản bench cuối; buổi đo = anh cài bản bench
cuối → bấm Chạy đo → gửi 1 file JSON. Chưa gọi anh cài run32.)
Cập nhật trước đó: 2026-11-10 17:54 CST (chat chính: **CỔNG BIÊN
DỊCH P2 ĐÃ XANH — run #30**: P2-2 qua cổng code; lần build đầu
(run #28) ĐỎ 14 lỗi, truy ra 2 gốc: (1) P2-3 ghép nhầm nền
wp4-prep thay vì nền reparse thật của main → P2-FIX ghép lại
+934/−0, harness xanh hết (crosscheck 13/13 · ledger PASS ·
13/13 · 11/11); (2) workflow main biên dịch bằng SDK iOS 18 do
image macos-15 mặc định Xcode 16.4 — ép chọn Xcode_26.3.0 tường
minh (commit c41f9c8) thì XANH, artifact SoHoaDon-P2-CORE-run30
654 KB. Đây là cổng biên dịch NỘI BỘ, không phải bản giao.
**BENCHAPP đang xây**: app đo biến thể (4 cấu hình A0–A3 × ảnh
bench nhúng sẵn, xuất 1 JSON theo schema bench-prep) cho buổi đo
duy nhất; manifest còn thiếu các ca thật của anh (điều kiện tiên
quyết buổi đo, chưa cần ngay).)
Cập nhật trước đó: 2026-11-10 17:12 CST (chat chính: **ĐANG XÂY
THEO PHƯƠNG ÁN ĐÃ DUYỆT** — anh duyệt 16:59. P2-1 (hình học bóng +
OCRLine2 + chẩn đoán ghi rõ pass nào thắng/điểm bao nhiêu — đúng
mẩu bằng chứng thiếu trong sự cố 001; không đổi model, không đổi
hành vi đọc) + P2-3 (port trọng tài số học, Parser thuần cộng 0
dòng xoá) + BENCH-PREP (schema JSON v1 + bộ chấm tự kiểm TRÁI
NGƯỢC ĐÚNG KỲ VỌNG: bộ hỏng chế tay chấm ra Σ 16884 / 13 món —
khớp từng số ca thực địa run #26) đều QUA CỔNG LEADER tự chạy lại:
ledger PASS, crosscheck P2-3 **13/13**, ngoặc P2-1 256/256. **P2-2
đang chạy** (kích hoạt: đa pass + engine (b) + hợp nhất mờ + chọn
bộ thắng bằng số học + vòng đọc lại theo vùng; dấu bản p2-core-1).
Sau P2-2: BenchApp + buổi đo duy nhất.)
Cập nhật trước đó: 2026-11-10 16:47 CST (chat chính: **HUY ĐỘNG
TOÀN ĐỘI LÀM LẠI CỐT LÕI OCR** theo lệnh anh 16:44 — bản OCRFIX
đọc đúng phần đầu trên Mẫu 001 nhưng sổ món vẫn mất 2 đơn vị /
$34.46 trên máy (anh báo 16:40) → anh lệnh: giải pháp tuyệt đối,
KHÔNG bản test nhỏ nữa. 4 tuyến song song đã mở trong core-redo/:
ENGINE (thi đấu dứt điểm (a) Vision cổ điển vs (b) iOS 26
RecognizeDocumentsRequest + kiến trúc đa lượt), PIPELINE (kiểm
toán ráp mảnh/lát cắt theo bằng chứng lỗi), RECONCILE (lớp đối
chiếu số học + sửa có mục tiêu + đọc lại theo vùng), QA (bench
nghiệm thu "tuyệt đối" + gói đo MỘT buổi duy nhất). ĐÓNG BĂNG
mọi giao bản; bản tiếp theo = giải pháp trọn gói qua cổng QA.
Đầu vào bằng chứng số 1 còn thiếu: luồng OCR gốc trên máy của
tờ Sam's vừa nạp (anh copy từ mục Văn bản OCR gốc). WP-EXPORT
tiếp tục đóng băng.)
Cập nhật trước đó: 2026-11-10 16:40 CST (ca trực: **KIỂM CHỨNG
TỪ XA LẦN ĐẨY MƠ HỒ 14:40 — KHÔNG LÊN ĐƯỢC CHÚT NÀO, KHÔNG
TRÙNG**: đúng việc ca 14:40 dặn ca sau. Đọc trực tiếp GitHub
(zjoenguyenz/Sohoadon) trong ca này: nhánh docs/planning vẫn ở
đầu `cdd83e013e16` (commit 2026-11-10T18:46:55Z = 12:46 CST,
"WP6 bước 1 đặc tả") — không có commit nào sau đó. Kiểm từng
file trong danh sách đẩy 14:40 trên nhánh: WP-EXPORT-SPEC.md,
WP-EXPORT-GATE.md, wp-export-fixtures/export_port.py,
verify_export.py, verify-export-results.txt đều **KHÔNG TỒN
TẠI** trên docs/planning; WORK-STATE.md trên nhánh vẫn là bản
12:45 CST (blob `16b70966…`). Kết luận: lần đẩy bị gián đoạn
14:40 KHÔNG lên được phần nào — đẩy lại 6 file đó không tạo
trùng. **Bước tiếp theo giữ nguyên: anh test OCRFIX run #26
trên Mẫu 001** (Sam's Club · 203.30 · 9.60+3.90 · 216.80);
WP-EXPORT vẫn đóng băng theo L-2026-11-10-6 cho tới khi mốc
đó qua trên máy anh. Ca này không viết Swift, không kêu anh
test thêm gì.)
Cập nhật trước đó: 2026-11-10 16:33 CST (chat chính: **OCRFIX ĐÃ
GIAO THEO B2 — run #26**: sự cố Mẫu 001 (ảnh rõ → OCR 3 mảnh rác)
được anh báo 16:19; đọc code tại chỗ tìm ra tầng phái sinh chưa
kiểm chứng thay mù ảnh gốc (L-2026-11-10-6, đóng băng đã áp).
OCRFIX qua cổng Wally: ScanView +106/−24 đúng 5 vùng, ứng viên
gốc-trước + yieldScore (gương hiệu chuẩn: rác 32đ vs Sam's thật
271đ), lát cắt khi cao >2000px, harness chữ 13/13 + 11/11 tự
chạy lại đạt; ReceiptViews chỉ đổi dấu → **ocrfix-1**. Code
734f676 + workflow a35ef93 → run #26 XANH, artifact
**SoHoaDon-OCRFIX-run26-2026-11-10** 447 KB sha256 `4aa574db…`;
soi binary file giao: yieldScore ✓ + đủ nhãn cũ. Đã giao anh, 1
lần test quyết định: nạp lại CHÍNH ảnh Sam's Mẫu 001 → chuẩn đạt
Sam's Club · 203.30 · 9.60+3.90 · 216.80; kèm tuỳ chọn 1 phút nạp
cùng ảnh vào TestB (đã cài sẵn) để chốt thi đấu engine. WP-EXPORT
vẫn đóng băng chờ mốc này.)
Cập nhật trước đó: 2026-11-10 16:17 CST (chat chính: **SCANPRO
ĐƯỢC ANH NGHIỆM 15:54** — bản scan phẳng đã thay ảnh chụp thường
làm ẢNH GỐC trong chi tiết Home Depot, nút Chụp lại + chú thích
đúng vị trí, số giữ nguyên. Anh ghi nhận quét tự động chưa hoàn
hảo, phải chỉnh crop tay trong trình quét — giới hạn của chính
máy quét hệ thống. **Anh lệnh 16:16: tiếp tục các bước tiếp
theo** → gói **WP-EXPORT code ĐANG LÀM** (export/, nền
wp3-prep/ContentView + scanpro/ReceiptViews; oracle = bản gương
37/37 + 8 quyết §6; dấu bản dự kiến m1fix-reparse-5).)
Cập nhật trước đó: 2026-11-10 14:40 CST (ca trực: **WP-EXPORT
BƯỚC CHUẨN BỊ — BẢN GƯƠNG LOGIC XONG**, việc song song độc lập
trong lúc SCANPRO run #24 chờ anh nghiệm; KHÔNG viết Swift —
đặc tả ghi cứng code chỉ bắt đầu sau khi anh nghiệm SCANPRO:
`wp-export-fixtures/export_port.py` (lọc loại × khoảng ngày gồm
cả 2 đầu · đặt tên file ZIP: làm sạch tên tiệm/`-trangN`/dedupe
`-2` · muc-luc.csv UTF-8 BOM + dòng TỔNG · ZIP kiểu STORE) +
`verify_export.py` **37/37 PASS** (verify-export-results.txt) +
`unzip -t` hệ thống sạch trên ZIP mẫu thu nhỏ. Fixture: metadata
THẬT Sam's 001 (Business 2586 · 216.80) + Home Depot 003 (Cá
nhân 3830 · 105.16) + biên SYNTHETIC (unknown có dấu · trùng tên
· đa trang mất trang 2 · biên đầu/cuối · thiếu tổng · file không
nạp được); byte file gốc là giả lập (kho ảnh thật ở iPhone anh).
8 quyết khoá tại điểm đặc tả để ngỏ → WP-EXPORT-SPEC.md mục 6;
văn bản cổng bước: WP-EXPORT-GATE.md. Lỗi phía em bắt được ở
gương: "Sam's" → "Sam-s-Club", đã sửa + khoá luật bỏ dấu nháy.
**Bước tiếp theo giữ nguyên: anh nghiệm SCANPRO → mới viết code
WP-EXPORT (Swift dịch trung thực gương này).** Không kêu anh
test gì ở bước này.)
CHỜ DUYỆT ĐẨY (ca 14:40): đã thử đẩy docs/planning ĐÚNG 1 LẦN
(6 file: WORK-STATE.md, WP-EXPORT-SPEC.md, WP-EXPORT-GATE.md,
wp-export-fixtures/export_port.py, wp-export-fixtures/
verify_export.py, wp-export-fixtures/verify-export-results.txt)
— lần đẩy bị gián đoạn giữa chừng do dịch vụ khởi động lại,
kết quả KHÔNG XÁC ĐỊNH (có thể đã lên một phần hoặc chưa);
ca sau kiểm từ xa trạng thái nhánh docs/planning trước khi đẩy
lại, không đẩy mù trùng lặp. **[ĐÃ GIẢI QUYẾT 16:40 CST: ca
trực kiểm từ xa — lần đẩy đó KHÔNG lên được phần nào, xem mục
mới nhất ở đầu file; ca 16:40 đẩy lại 6 file này đúng 1 lần ở
cuối ca.]**
Cập nhật trước đó: 2026-11-10 13:09 CST (chat chính: **SCANPRO
ĐÃ GIAO THEO B2 — run #24**: gói qua cổng Wally — diff +117/−1,
1 dòng thay là mã bản; wrapper DocumentCameraView của ScanView
là struct cấp tệp nên ReceiptViews dùng lại nguyên trạng, chỉ
cộng import VisionKit. Code 9222298 + workflow 6942892 → run #24
XANH, artifact **SoHoaDon-CHUP-LAI-run24-2026-11-10** 445 KB
sha256 `9464b01c…`; Wally soi binary file giao: đủ nhãn Chụp lại
bản gốc / Gắn lại / Đọc lại / Bản bộ đọc. Dấu bản:
**m1fix-reparse-4**. Đã giao anh, 1 lần test: mở Home Depot →
Chụp lại bản gốc → quét tờ giấy → bản scan phẳng thành ảnh gốc
mới, ảnh cũ giữ ở file phụ. Chưa kiểm được đã khai: máy quét tài
liệu chỉ chạy trên máy thật. WP-EXPORT code bắt đầu sau khi anh
nghiệm SCANPRO.)
Cập nhật trước đó: 2026-11-10 13:02 CST (chat chính: **IMGFIX
ĐƯỢC ANH NGHIỆM ĐẠT 12:53** — ảnh chi tiết Home Depot đã hiện mục
ẢNH GỐC (BẰNG CHỨNG) + ảnh tờ hoá đơn + số đúng toàn bộ; vòng ảnh
gốc đóng. **LỆNH MỚI 13:00: nút CHỤP LẠI BẢN GỐC kiểu máy scan**
(Microsoft Lens) trong chi tiết — bản scan phẳng, chữ rõ, lưu làm
bản gốc. Đã kiểm grep: tab CHỤP vốn đã dùng
VNDocumentCameraViewController từ Build 1 (wp4-prep/ScanView còn
đủ) — thiếu duy nhất ở màn Chi tiết. Gói **SCANPRO đang làm**
(scanpro/, nền imgfix/ReceiptViews): nút "Chụp lại bản gốc (quét
như máy scan)" ở cả nhánh có ảnh lẫn nhánh thiếu ảnh; trang quét
1 → imageFileName mới (JPEG q0.9), file cũ GIỮ vào
originalImageFileNames (không xoá bằng chứng), trang thêm nối
tiếp; KHÔNG tự đọc lại số. Dấu bản dự kiến m1fix-reparse-4.
WP-EXPORT nối sau SCANPRO.)
Cập nhật trước đó: 2026-11-10 12:51 CST (chat chính: **IMGFIX ĐÃ
GIAO THEO B2 — run #22**: gói qua cổng Wally — diff +144/−1, đúng
1 dòng thay là mã bản; rà 3 ngõ vào đều ĐÃ lưu gốc trước phân
tích, lỗ hổng chỉ ở bản ghi đã lưu không đối soát. Code ad14b27 +
workflow 079e9af → run #22 XANH, artifact
**SoHoaDon-ANH-GOC-run22-2026-11-10** 438 KB sha256 `b3fa8ca7…`;
Wally tải chính file giao về soi binary đủ 4 nhãn: Thiếu ảnh gốc /
Gắn lại ảnh gốc / Đọc lại / Bản bộ đọc. Dấu bản: **m1fix-reparse-3**.
Đã giao anh, 1 lần test: mở Home Depot → cờ Thiếu ảnh gốc + Gắn
lại → chọn ảnh → ảnh hiện trong chi tiết. Chưa kiểm được đã khai
trong tin giao: cài đè giữ dữ liệu + picker trên máy anh.)
Cập nhật trước đó: 2026-11-10 12:45 CST (ca trực: **WP6 BƯỚC 1
— ĐẶC TẢ XONG**, việc song song độc lập, không đụng làn IMGFIX /
WP-EXPORT của chat chính và không kêu anh test gì thêm:
**WP6-SPEC.md** khoá phạm vi WP6 (mốc M2) bằng bằng chứng đọc
trực tiếp code hiện hành của run #20 — cả 8 mã Master Plan giao
đều CÒN NGUYÊN: B-2 (10 điểm `try? save`: stamp/ReceiptViews
486/505/628/645/982 + CardsView 4 + ContentView 1) · C-1 (nút
Duyệt ~484-490 không đọc receiptFlags) · B-6 (xoá ảnh trước bản
ghi ~502-507) · C-3 (validate() vẫn private, stamp/Parser:951) ·
B-7 (sheet Kiểm Lại wp4-prep/ScanView:195 không đường dọn ảnh
khi huỷ) · C-2/C-8 (HomeView/CardsView chưa gói nào chạm). Hạ
tầng WP2 có mà chưa nối: reviewedAt gán 0 điểm, duplicateOf/
excludedFromTotals dùng 0 điểm (grep). Quyết model duy nhất:
cộng đúng 1 Bool `confirmedWithFlag` có default cho cơ chế
"xác nhận kèm cờ" §2.2(3) — thuần cộng thêm tiền lệ WP2; cần
khác thêm thì dừng báo Wally. Có đủ mục B2 Điều 2 (áp lên dữ
liệu đã lưu; hệ quả phải tuyên bố ở tin giao M2: tổng Trang Chủ
sẽ giảm đúng bằng tiền đang chờ — sửa đúng, không phải mất
tiền). 3 chữ ký nội bộ bước 1 ở WP6-GATE.md. **Cổng gói WP6
CHƯA mở** — code bước 2 chờ tới lượt trong nhịp M2.)
Cập nhật trước đó: 2026-11-10 12:44 CST (**LỆNH MỚI CỦA ANH:
XUẤT BẢN GỐC CHO KẾ TOÁN — gói WP-EXPORT xếp ngay sau IMGFIX**):
anh yêu cầu app trích xuất TOÀN BỘ BẢN GỐC theo LOẠI hoá đơn
(Business/Cá nhân) × THỜI GIAN (theo năm hoặc khoảng từ–đến tự
chọn; ví dụ của anh: bản gốc thẻ Business từ 10/2025 tới 11/2026)
→ xuất thành file tải về hoặc email cho kế toán. Spec gói
WP-EXPORT: màn ở tab Báo Cáo Thuế — chọn loại + khoảng ngày (lọc
theo ngày hoá đơn) → hiện số tờ khớp + tổng tiền → tạo **1 file
ZIP** chứa các file gốc (đặt tên file theo ngày-tiệm-tổng) +
**mục lục CSV** (ngày · tiệm · loại · mục · tạm tính · thuế ·
tổng · thẻ) để kế toán đối chiếu; tờ thiếu ảnh gốc bị ghi rõ
trong mục lục + báo số lượng trước khi xuất (không lặng lẽ bỏ
qua) → nút chia sẻ chuẩn iOS (lưu Files / đính kèm email). Thứ
tự bắt buộc: IMGFIX xong trước (đảm bảo + gắn lại ảnh gốc),
WP-EXPORT nối sau trên cùng nền file. Tax Pack còn lại giữ
Build 3. Cả hai gói qua checklist B2, mỗi gói một lần kêu test.)
Cập nhật trước đó: 2026-11-10 12:42 CST (**MỐC SỬA BỘ ĐỌC ĐẠT
trên máy anh + LỖI MỚI: THIẾU ẢNH GỐC**): ảnh anh chụp 12:39 CST —
tờ Home Depot sau Đọc lại: **The Home Depot · 9808 E 71ST ST TULSA
OK 74133 · Subtotal $96.91 · TAX $8.25 · TỔNG $105.16 · Visa 3830 ·
mã chống trùng GEN|The Home Depot|2025-03-03|10516 · dấu app
m1fix-reparse-2** — khớp toàn bộ chuẩn đã hứa; phân loại CÁ NHÂN do
anh đổi tay, được giữ. Vòng M1-FIX/REPARSE ĐÓNG. **Anh phát hiện
tiếp (12:40):** màn chi tiết KHÔNG hiện mục "Ảnh gốc (bằng chứng)"
→ file ảnh gốc của tờ này không nạp được trong app, app im lặng
không cảnh báo. Anh lệnh: mọi hoá đơn sau phân tích PHẢI lưu kèm
file ảnh gốc để trình accountant. Đã ghi lỗi L-2026-11-10-5 vào
TEAM.md (kiểm Điều 1(b) của em thiếu thành phần ảnh gốc). Gói
**IMGFIX đang làm** (imgfix/): rà 3 ngõ vào (camera/Photos/Files —
mọi đường phải lưu gốc trước phân tích, chặn khi ghi lỗi) + cờ
"Thiếu ảnh gốc" thay im lặng + nút "Gắn lại ảnh gốc" cho tờ đã lưu
(Điều 2 B2) + nâng dấu bản thành m1fix-reparse-3. Vì sao riêng tờ
này thiếu ảnh: CHƯA KIỂM CHỨNG, không đoán. Giao theo checklist B2,
một lần kêu test riêng cho thay đổi này.)
Cập nhật trước đó: 2026-11-10 12:36 CST (**GIAO LẠI THEO B2 —
run #20**: B2 ban hành 12:26 (WORKFLOW-PROMPT-IOS + TEAM.md đã ghi
6 điểm thắng + 4 lỗi L-2026-11-10-1..4 kèm đính chính 12:28). Anh
sửa: anh xoá từng app sau mỗi test — cơ chế "cài nhầm chồng file"
em nêu 12:19 là SUY DIỄN, đã rút + đính chính TEAM.md. **Soi ruột
file #17 (bằng chứng trực tiếp):** binary chứa nhãn nút "Đọc lại
bằng bộ đọc hiện tại" + reparse → file #17 có thật tính năng; vì
sao ảnh 12:18 không hiện mục Bộ đọc: CHƯA KIỂM CHỨNG, không gán
phía anh. Bản giao lại: **run #20** (code commit 7855ccf + workflow
286f8dc) XANH, artifact **SoHoaDon-NUT-DOC-LAI-run20-2026-11-10**
426 KB sha256 `59ff646d…`; Wally tải chính file đó về soi binary:
nhãn nút Đọc lại ✓ + nhãn dấu "Bản bộ đọc của app" ✓ (app in mã
**m1fix-reparse-2** trong màn Chi tiết — đối chiếu mã↔commit↔run
nằm ở đây + tin giao). Điều 1(b): port 11/11 trên luồng chữ đã lưu
003/001, Parser của bản này y hệt file đã port (không đổi). Điều
1(a) cài đè giữ dữ liệu: CHƯA KIỂM ĐƯỢC từ phía em — đã khai đúng
mục 3 trong tin giao. Đang chờ MỘT lần test của anh theo Điều 4.)
Cập nhật trước đó: 2026-11-10 12:10 CST (**REPARSE: BUILD XANH
CÓ FILE THẬT — ĐÃ GIAO ANH 1 CHẠM**: run **#17** (main, commit
98fc6ef) SUCCESS 30s, artifact **SoHoaDon-IPA 425 KB** sha256
`e61b0d46…` đã xác nhận trên trang run. Wally đã nhắn anh: tải bản
run #17 → mở ĐÚNG tờ Home Depot trong ảnh anh gửi → mục "Bộ đọc"
mới có nút "Đọc lại bằng bộ đọc hiện tại" → kỳ vọng ngay trên màn
đó: The Home Depot · 96.91 · 8.25 · 105.16, tờ về Hộp Chờ theo
thiết kế (số đã thay phải có người duyệt lại). Chưa chứng minh duy
nhất: hành vi trên máy thật (nút hiện trên bản ghi Build 1,
SwiftData cập nhật tại chỗ, màn vẽ lại) — đúng 1 chạm của anh đo.)
Cập nhật trước đó: 2026-11-10 12:09 CST (GÓI REPARSE ĐÃ ĐẨY —
chờ build phán): anh cài cả 2 bản (ảnh Library + Test B chạy được)
rồi mở tờ Home Depot — vẫn rác cũ, vì hoá đơn ĐÃ LƯU không bao giờ
được đọc lại: engine mới chỉ áp cho quét mới. Anh ban thêm luật
"kiểm đúng trải nghiệm cuối" (đã ghi WORKFLOW-PROMPT-IOS). Gói
REPARSE làm ngay: nút "Đọc lại bằng bộ đọc hiện tại" trong chi tiết
hoá đơn (hiện khi ocrRawText ≠ rỗng và parserVersion lệch hiện hành
hoặc tờ đang needsReview) → ReceiptParser.reparse() chạy đúng
parse() trên ocrRawText đã lưu → hạ cánh tại chỗ theo ánh xạ save(),
GIỮ: phân loại anh đã chọn tay + businessPurpose + stableID/ảnh/
transactionRef; confidence dòng khôi phục = 0.5 (mọi tờ đọc lại về
Hộp Chờ — có chủ đích); currentParserVersion nâng "build1-parser"
→ "m1fix-reparse-1". WALLY TỰ KIỂM ĐỘC LẬP: port **11/11 PASS**
(đường chữ == đường quét từng trường trên 003 + 001), Parser
+42/−0, ReceiptViews +165/−1 (đúng 1 dòng thay = hằng version),
validate() byte-identical. **ĐÃ ĐẨY main commit `98fc6ef`** (anh
duyệt thẻ); trình duyệt đang kiểm run tới trạng thái cuối +
artifact. Chuẩn giao đã hứa với anh: mở đúng tờ Home Depot đó →
Đọc lại → hiện The Home Depot · 96.91 · 8.25 · 105.16 ngay trên
màn đó.)
Cập nhật trước đó: 2026-11-10 11:52 CST (**CẢ HAI BUILD XANH —
ĐÃ KIỂM CHỨNG TRÊN TRANG RUN**: main **run #16** (commit 235716c,
M1-FIX) SUCCESS 36s, artifact **SoHoaDon-IPA 416 KB** sha256
`c5397538…` — biên dịch Swift ĐÃ ĐƯỢC PHÁN: đạt. **TestB run #15**
(commit 268735a, workflow macos-15 + tự chọn Xcode) SUCCESS 29s,
artifact **SoHoaDonTestB-IPA 40.9 KB** sha256 `896f88d2…`; log
bước chọn Xcode chứng minh máy có Xcode 26.0–26.3 và đã chọn
**26.3** — đường vòng qua macos-15 ĐÃ CHỨNG MINH, hết phụ thuộc
runner macos-26. Wally đã giao anh buổi test M1 trọn gói trong chat
(tải run #16 + quét lại 003/002 + cài TestB chạy cùng 2 ảnh). Còn
chưa chứng minh duy nhất: Vision trên máy thật với ảnh quét mới —
đúng phần buổi test này đo.)
Cập nhật trước đó: 2026-11-10 11:40 CST (M1-FIX: SỬA XONG + WALLY
TỰ KIỂM + ĐÃ ĐẨY): gói m1fix/ hoàn thành và WALLY ĐÃ KIỂM LẠI ĐỘC
LẬP (không dùng lời đội): tự chạy port **13/13 PASS** — 003 trên
luồng thô thật đạt trọn đóng băng (subtotal 9691 · thuế [825] ·
total 10516 · 3 món 698/1997/6996, món 3 SL 2 @ 3498; cảnh báo số
học biến mất), 001/002 giống hệt trước từng trường (0 hồi quy);
diff Swift +180/−3 đúng 3 điểm phẫu thuật; **validate() so byte
IDENTICAL 3.876 byte** (Wally tự cmp); ngoặc 263/263. Cộng neo
`phrase` "HOW DOERS GET MORE DONE" cho Home Depot (dự phòng khi mất
dòng địa chỉ; luồng đầy đủ vẫn thắng bằng neo đường như hiện hành).
**ĐÃ ĐẨY main commit `235716c`** (anh duyệt thẻ) — trình duyệt đang
kiểm run mới tới trạng thái cuối + artifact. CHƯA CHỨNG MINH (giữ
nguyên nhãn): biên dịch Swift chờ build cloud phán; Vision trên
máy thật chờ anh quét lại 1 lần SAU khi build xanh được xác nhận.
Phát hiện phụ đã chứng minh bằng port: identifyVendor hiện hành VỐN
đã nhận đúng The Home Depot cho 003 qua neo địa chỉ — "How doers"
trong ảnh anh là bản ghi lưu từ Build 1 (không nhắc lại với anh;
kết quả quét lại sẽ tự nói).
Cập nhật trước đó: 2026-11-10 11:31 CST (ANH PHẢN HỒI M1 — WALLY
NHẬN LỖI GIAO SỚM): anh cài bản M1, mở tờ Home Depot và chụp gửi:
đó là **bản ghi CŨ lưu từ Build 1** (tiệm "How doers", tổng trống)
— bản mới không tự đọc lại hoá đơn đã lưu nên màn hình không đổi;
anh kết luận "không có gì mới so với tối qua" và ban **luật "không
đưa kết quả chưa thử qua kiểm định"** (đã ghi vào
WORKFLOW-PROMPT-IOS). Lỗi của Wally: fixture G4 (Sample 003 đọc sai
tổng vì tiền-ở-dòng-trước-nhãn) ĐÃ BIẾT từ cổng WP4 mà vẫn gọi bản
M1 là sẵn sàng. **Gói sửa M1-FIX đã khởi động ngay**: port trung
thực parser hiện hành → tái hiện G4 trên luồng OCR thật đã lưu của
003 → sửa gán nhãn-tiền hai chiều + giá món hai chiều + "2@34.98"
→ cổng: 003 đạt 96.91/8.25/105.16 + 3 món khớp số học VÀ 001/002
0 hồi quy → mới build lại, Wally tự kiểm chứng xanh, mới gọi anh
quét lại đúng 1 lần. Nửa TestB (macos-15 + Xcode 26) vẫn đang chạy
song song qua trình duyệt.)
Cập nhật trước đó: 2026-11-10 11:22 CST (Wally chat chính: **APP
CHÍNH ĐÃ CÓ IPA THẬT — RUN #14 XANH** (main, commit `d2550cc` =
workflow hợp nhất + runs-on macos-15): trang run xác nhận artifact
**SoHoaDon-IPA 413 KB**, sha256 `488fb8d9…` — ĐẠT chuẩn luật kiểm
chứng 10:13, Wally đã gọi anh vào tải bản chính cho buổi M1.
**TestB vẫn chưa có IPA**: Re-run #13 lần 2 lại chết vì macos-26
không cấp máy. Đường vòng ĐANG CHẠY: theo manifest runner-images
(2 nguồn độc lập trích dẫn), image macos-15 CÓ SẴN Xcode
26.0.1–26.3 (mặc định 16.4) → workflow testb đổi sang macos-15 +
bước tự chọn Xcode_26 mới nhất (file workflows-unified/
build-ipa-testb-macos15.yml, YAML đã kiểm) — trình duyệt đang đẩy
lên testb + theo dõi run; kết quả build là phép thử quyết định.
M1 vì vậy tách hai nửa: bản chính test được ngay (di trú + quét lại
002/003), nửa thi đấu engine chờ IPA TestB.)
Cập nhật trước đó: 2026-11-10 10:40 CST (ca trực: **KIỂM CHỨNG RUN
#12 + #13 — CẢ HAI VẪN QUEUED, CHƯA CÓ KẾT QUẢ BUILD** — đúng bước
tiếp theo sau mục 10:37: ca giao trình duyệt đọc trực tiếp trang
Actions của repo zjoenguyenz13/Sohoadon lúc 10:41–10:43 CST (giờ đo
của hệ thống). Run #12: nhánh main, commit `5652aaf`, kích hoạt
10:35 CST — trạng thái **Queued**, job build queued, thời lượng "–",
artifact "–" (chưa có). Run #13: nhánh testb, commit `7e92a04`,
kích hoạt 10:36 CST — trạng thái **Queued**, job build queued,
artifact "–" (chưa có). Kiểm lại sau 60 giây (~10:43) cả hai VẪN
Queued — chưa bắt đầu chạy, nên chưa xanh/đỏ, chưa artifact IPA,
chưa dòng lỗi nào để sửa. **Bước tiếp theo: ca sau (hoặc Wally ở
chat chính) kiểm lại 2 run này tới trạng thái cuối; XANH + artifact
tồn tại mới tính tiếp buổi M1 theo luật kiểm chứng 10:13; ĐỎ thì
mang dòng lỗi về tự sửa theo luật 10:18.** Tuyên bố trung thực:
đã chứng minh = 2 run đúng nhánh/commit và còn Queued ở 10:43;
chưa chứng minh = kết quả biên dịch của workflow hợp nhất trên cả
2 nhánh; chưa làm = chưa có IPA nào được kêu anh tải/cài.)
Cập nhật trước đó: 2026-11-10 10:37 CST (WALLY TỰ SỬA WORKFLOW
BẰNG TRÌNH DUYỆT — theo luật tự làm của anh 10:18): anh đã lưu đăng
nhập GitHub vào kho bảo mật + cho mã xác thực một lần; trình duyệt
của Wally đăng nhập được (tài khoản thật là **zjoenguyenz13** — địa
chỉ zjoenguyenz/Sohoadon tự chuyển hướng về zjoenguyenz13/Sohoadon)
và **đã thay file workflow hợp nhất trên CẢ HAI nhánh**: main commit
`5652aaf`, testb commit `7e92a04` (SỬA LẠI 10:53: anh đã đổi tên
tài khoản GitHub NGƯỢC VỀ `zjoenguyenz` trong sáng nay sau vụ
Lovable báo lệch tài khoản — tên chuẩn để ghi là zjoenguyenz;
zjoenguyenz13 chỉ là tên tạm vài chục phút. Mật khẩu GitHub anh
cũng đã đổi sáng nay; bản lưu trong kho bảo mật đã đăng nhập thành
công lúc 10:34 nên dùng được. Kiểm lại trên web: 63 dòng, tên
"Build unsigned IPA", macos-26, tự nhận diện project/scheme, chạy
khi đẩy lên main hoặc testb). Hệ quả phụ: từ nay Wally TỰ ĐỌC ĐƯỢC
Actions qua trình duyệt — hết cảnh mù build. Run mới: **#12 (main
5652aaf) và #13 (testb 7e92a04)** — lúc 10:36 còn Queued; Wally đã
giao trình duyệt theo dõi tới trạng thái cuối + xác nhận artifact
tồn tại; ĐỎ thì mang dòng lỗi về tự sửa. Run #11 (đẩy Parser
779ab85 chạy dưới workflow TestB cũ) đỏ như dự đoán — bỏ qua.
Trước đó cùng buổi: lỗi đỏ run #9 (WP5) đã tìm ra gốc = gói đẩy
thiếu Parser.swift → đã đẩy bổ sung `779ab85`; luật đầy đủ gói đẩy
đã ghi vào WORKFLOW-PROMPT-IOS. Gmail của anh CHƯA nối với Muse
(status not_connected) — mã xác thực qua email phải nhờ anh đọc
giúp khi cần.)
Cập nhật trước đó: 2026-11-10 08:40 CST (ca trực: **TESTB ĐÃ DỰNG
NỐT — SẴN SÀNG CHO BUỔI M1** — đúng lệnh Wally 07:52: rà soát sâu
lại wp4-testb/ (từng dòng 3 file Swift, phái sinh khớp từng dòng với
wp4-prep trên main, ngoặc đếm lại {3/3}·{33/33}·{21/21}, YAML sạch,
khuôn project/workflow soi với app chính đã build xanh) + đóng gói
**`SoHoaDon-TestB-Kit.zip`** 8.619 byte, sha256 `421ed9b5…a694`,
giải nén đối chiếu khớp byte-for-byte; hash từng file ở
wp4-testb/KIT-MANIFEST.txt; xem WP4-GATE.md mục BƯỚC 3 PHẦN DỰNG
KIT. Kiểm từ xa trong ca: main vẫn `dc631b0` ✓; docs/planning vẫn
`27b7970` → lần đẩy mơ hồ của ca 06:40 **KHÔNG lên được** (không
trùng). **Bước tiếp theo: Wally trình anh thẻ đẩy kit TestB** (repo
riêng/nhánh riêng, file ở gốc) → build cloud macos-26 lần đầu =
phép kiểm biên dịch engine (b); XONG mới gọi anh cài MỘT lần (bản
chính dc631b0 + TestB) + test lớn M1. Ca trực không tự đẩy code.)
Cập nhật trước đó: 2026-11-10 07:52 CST (Wally: **CODE M1 ĐÃ ĐỦ TRÊN
MAIN** — WP4 ứng viên (a) commit `122ee9b` + WP5 commit `dc631b0`, anh
duyệt cả 2 thẻ đẩy; Wally tự diff khớp số ca báo: ScanView +182/−16,
Parser +106/−0, ReceiptViews +68/−0. Còn thiếu cho buổi test M1: bản
TestB engine (b) — ca trực dựng nốt từ wp4-testb/, XONG mới gọi anh
cài MỘT lần + test lớn. Build cloud của dc631b0 Wally không xem được
Actions — kiểm ở buổi M1.)
Cập nhật trước đó: 2026-11-10 06:40 CST (ca trực: **WP5 BƯỚC 3 —
NỐI DÂY + CHỐT CỔNG GÓI: WP5 ĐÃ TỚI CỔNG** — đúng bước tiếp theo
hàng việc đã ghi: `wp5-prep/ReceiptViews.swift` MỚI (nền wp3-prep
đã lên main, diff **+68/−0 thuần cộng thêm**): save() ghi
vendorAddress/vendorPhone/storeNumber vào model WP2 (bằng chứng
trích nguyên văn, không suy từ tên sửa tay); Kiểm Lại hiện nhãn
nguồn tiệm (helper vendorSourceText) + gợi ý nấc 3 "chưa tự điền"
+ liên hệ đọc được; Chi Tiết hiện liên hệ đã lưu khi có dữ liệu.
SCORECARD đã chấm lại (dòng 2026-11-10 bước 2+3): 003 tiệm
✓-có-cờ ở tầng port, 002 giữ ✓. Kiểm chứng: port **19/19 + 7/7** +
hồi quy **10/10 + 9/9** chạy lại; ngoặc 195/195 · 496/496 · 16/16.
Đủ 3 chữ ký CỔNG GÓI — WP5-GATE.md mục BƯỚC 3 + CỔNG GÓI. Điểm mở
trình Wally: currentParserVersion vẫn "build1-parser" (chốt nhãn
khi trình đẩy, ca không tự đổi). **Chưa đẩy code** — chờ Wally
trình anh duyệt thẻ đẩy ở chat chính, cùng nhịp M1. — TRƯỚC ĐÓ:
**WP5 BƯỚC 2 — CODE SWIFT XONG** 04:40 CST (wp5-prep/Parser.swift
+323/−50; identifyVendor 3 nấc + C-11 + trích xuất; 19/19 + 7/7 +
10/10 + 9/9 — xem WP5-GATE.md mục BƯỚC 2). — TRƯỚC ĐÓ NỮA:
**WP5 BƯỚC 1 — ĐẶC TẢ XONG** 02:40 CST (WP5-SPEC.md + port 19/19,
xem WP5-GATE.md mục BƯỚC 1). — TRƯỚC ĐÓ NỮA: **WP4 BƯỚC 3 — PHẦN
CHUẨN BỊ XONG** 00:40 CST (bản test engine (b) iOS 26 cô lập ở
wp4-testb/; thi đấu thật + QA chọn engine + chốt §5.6 + quyết
HAZARD G4 chờ build cloud + máy ở mốc M1; xem WP4-GATE.md mục
BƯỚC 3). — TRƯỚC ĐÓ NỮA: **WP4 BƯỚC 2 XONG** 22:40 CST 2026-11-09
(tiền xử lý phái sinh + F2b parser, port 10/10 + hồi quy 9/9,
FINDING ĐỎ G4 đã khoá fixture — chủ sửa WP7; xem WP4-GATE.md).
Đẩy tài liệu: ca 06:40 thử đẩy 1 lần, kết quả không xác định —
ca 08:40 ĐÃ KIỂM CHỨNG từ xa: nhánh docs/planning vẫn ở `27b7970`
(06:47Z), lần đẩy đó KHÔNG lên được, không có bản trùng. Ca 08:40
thử đẩy lại ĐÚNG 1 LẦN ở cuối ca (WORK-STATE.md, WP4-GATE.md,
WP5-GATE.md, SCORECARD.md); nếu không hoàn tất thì ghi CHỜ DUYỆT
ĐẨY ở ca sau, không thử lại trong ca.
## Vị trí hiện tại
- Master Plan đã trình anh (23:38) + anh trả lời hết câu hỏi mở (LLC 1 thành
  viên; hàng mua để dùng → Supplies).
- **WP0 ĐÃ XONG — QUA CỔNG (2026-11-09 02:41 CST):** SCORECARD.md đã tạo
  (Wally, 00:41) + **QA ✓ KÝ NHẬN thứ tự gói WP1→WP9** theo Master Plan §5.0.
  Văn bản ký nhận: `WP0-QA-SIGNOFF.md`.
- **WP1 — CODE ĐÃ CHUẨN BỊ TỚI CỔNG (2026-11-09 04:40 CST):** cửa chẩn đoán
  F3 đã viết xong theo đặc tả CODE-AUDIT F3 mục 1+2 — mục "Văn bản OCR gốc"
  (DisclosureGroup thu gọn mặc định, chữ monospaced, copy được) ở màn Kiểm
  Lại (dưới ảnh gốc) + màn Chi Tiết (sau "Thông tin", ẩn khi rỗng), dùng
  chung 1 component `RawTextDisclosure`. Bản chuẩn bị:
  `wp1-prep/ReceiptViews.swift` (thay 1-1 cho `build1/ReceiptViews.swift`;
  diff đã kiểm: **+39 dòng / −0 / 0 dòng sửa**; cân bằng ngoặc 169/169).
  Đủ 3 chữ ký nội bộ Design ✓ / Code ✓ / QA ✓ — văn bản cổng: `WP1-GATE.md`.
  **CHƯA đẩy code ở bất kỳ nhánh nào** (đúng luật ca trực); biên dịch
  [CHƯA KIỂM CHỨNG] (môi trường ca không có compiler — build cloud là phép
  kiểm sau khi anh duyệt đẩy).
- **Ranh giới ghi rõ trong WP1-GATE.md:** nhãn "Văn bản trong PDF" (F3 mục 3)
  CHƯA làm — chưa có đường PDF (WP3) và chưa có trường nguồn `sourceType`
  (WP2) để phân biệt nguồn ở màn Chi Tiết; component đã nhận `title` làm
  tham số để WP3 nối nhãn, không dựng lại viewer. Mục 3 = chuyển WP3.
- **CORPUS — MỤC 3 ĐÃ LÀM XONG PHẦN KHÔNG CẦN ANH (2026-11-09 06:40 CST):**
  làn lab đã tải + kiểm chứng xong cả 3 bộ, danh mục 7 loại hình đã lập —
  văn bản: `corpus/CORPUS.md` (+ bằng chứng nguồn ở `corpus/_sources/`).
  Số đo chính: WildReceipt toàn bộ bản MMOCR (test 472 / train 1,267 tờ
  có nhãn, 72,485 hộp; 185,323,520 byte, sha256 ở CORPUS.md) · CORD v1
  test split 100 tờ (234,201,893 byte, pyarrow đếm đúng 100 dòng;
  train/validation CHƯA tải — có chủ đích, chỉ cần khi WP4 gọi) · SROIE
  bản cộng đồng 973 tờ (train 626/test 347; KHÔNG phải bản ICDAR chính
  thức, cảnh báo giấy phép ở CORPUS.md A3). Danh mục thật của anh: đã có
  kho sỉ (001/002) + big-box (003); 5 loại còn trống, lớn dần theo hoá
  đơn thật anh gửi (không phải việc ca trực tự tạo được).
- **WP1 CODE ĐÃ ĐẨY LÊN MAIN (2026-11-09 10:44 CST):** anh duyệt trong chat
  ("Đẩy code WP1 lên build bản mới luôn") + duyệt thẻ đẩy; commit **7697276**.
  Wally duyệt cuối trước khi đẩy: tự diff lại — đúng +39/−0, thuần cộng thêm.
  Kiểm chứng độc lập của ca trực 10:40 trên GitHub: commit đầy đủ
  `769727698d` (16:44:18Z); file `ReceiptViews.swift` trên main = 28.588
  byte, md5 `599cfc70c015228acc54996ad4fd5eb7` — khớp byte-for-byte với
  `wp1-prep/ReceiptViews.swift`, có `RawTextDisclosure`; ca trực không
  đẩy lại để tránh trùng. Build cloud: [CHƯA KIỂM CHỨNG trong ca này —
  connector GitHub không có công cụ xem Actions].
  **WP1 ĐÃ ĐÓNG — NGHIỆM THU XONG (2026-11-09 10:57 CST):** anh cài bản
  7697276, mở Chi Tiết tờ Home Depot, mục "Văn bản OCR gốc" hiện đầy đủ
  (screenshot anh gửi). **WP2 MỞ** — các ca sau bắt đầu chuẩn bị WP2.
  Thu hoạch chẩn đoán (samples/sample-003-ocr-raw.txt + mục chẩn đoán
  trong sample-003-ground-truth.md): tiền nằm dòng TRƯỚC nhãn (parser
  cùng-dòng trượt sạch dù chữ đọc đúng gần hết); tên tiệm vắng mặt trong
  OCR (logo → khẩu hiệu) → WP5 phải dùng neo địa chỉ; "2@34.98" dính.
- **WP2 — BƯỚC 1 (MODEL) ĐÃ CHUẨN BỊ TỚI CỔNG (2026-11-09 12:40 CST):**
  `wp2-prep/Models.swift` (thay 1-1 cho `build1/Models.swift`; diff đã
  kiểm: **+191 dòng / −0 / 0 dòng sửa**; cân bằng ngoặc 88/88) +
  `wp2-prep/SoHoaDonApp.swift` (đúng 1 dòng đổi: đăng ký `TaxLine` vào
  modelContainer). Đủ 15 dòng thiếu hụt §5.2 (5 CAO + 7 TRUNG + 3 THẤP)
  đã có trường chứa: `taxLines[]`/`TaxLine`, tip + totalPrinted, phân
  loại cấp dòng, `originalImageFileNames[]`, paymentMethod, địa chỉ
  tiệm, transactionRef/authCode, scheduleCLine (+ bảng gợi ý §3.2),
  sourceType, duplicateOf/excludedFromTotals, reviewedAt +
  userEnteredFieldNames, retentionUntil. Mọi trường Build 1 GIỮ NGUYÊN
  (di trú nhẹ theo thiết kế). Đủ 3 chữ ký nội bộ — văn bản cổng:
  `WP2-GATE.md`. **CHƯA đẩy code ở bất kỳ nhánh nào** (đúng luật ca
  trực); biên dịch + di trú trên kho thật [CHƯA KIỂM CHỨNG] (môi trường
  ca không có compiler).
- **WP2 — BƯỚC 2 (NỐI DÂY LÚC LƯU) ĐÃ CHUẨN BỊ XONG (2026-11-09
  14:40 CST):** `wp2-prep/ReceiptViews.swift` (so với bản WP1 trên main:
  **+65 / −1** — dòng −1 duy nhất là dòng "Thuế" gộp được thay bằng
  khối hiển thị có điều kiện) + `wp2-prep/ScanView.swift` (so với
  build1: **+9 / −4**). `ReviewView.save()` nay ghi `stableID` (UUID),
  `sourceType` (camera/photoLibrary theo đúng đường vào, qua
  `ScanDraft`), `paymentMethod` (có thẻ → card, không → unknown,
  KHÔNG đoán cash), `transactionRef` (chỉ tách từ `SAMS-TC-`/`TC-`),
  `parserVersion = "build1-parser"`, và các `TaxLine` từ parser —
  nhưng CHỈ khi tổng thuế anh duyệt còn khớp Σ dòng thuế (kiểm trên
  đáp án Mẫu 002: 960+390=1350¢ ✓); `taxCents` đồng bộ ngược = Σ.
  `ReceiptDetailView` hiện từng dòng thuế riêng + tổng khi có dữ
  liệu, bản ghi cũ giữ nguyên hiển thị. Đủ 3 chữ ký nội bộ bước 2 —
  xem WP2-GATE.md mục "WP2 BƯỚC 2". **CHƯA đẩy code ở bất kỳ nhánh
  nào**; biên dịch [CHƯA KIỂM CHỨNG]. **WP2 ĐÃ TỚI CỔNG (cả 2
  bước):** còn lại kiểm di trú — chỉ làm được sau khi có build chứa
  model mới (workspace không có bản sao kho Build 1; phép kiểm tĩnh
  di trú nhẹ đã có). Nghiệm thu: anh duyệt đẩy → build cloud → cài
  đè lên máy đang có 2 tờ test Build 1 → 2 tờ còn nguyên, số không
  đổi. Cố ý chưa nối ở bước này: scheduleCLine lúc lưu (WP6/WP7),
  originalImageFileNames (WP3/WP8), reviewedAt/userEntered (WP6).
  **KẾT QUẢ SAU ĐÓ:** WP2 code ĐÃ ĐẨY MAIN 2026-11-09 15:52 CST
  (commit `d7497d8`, 4 file wp2-prep) — kiểm di trú gộp vào bài test
  mốc M1 theo luật mốc lớn, WP2 coi như qua cổng nội bộ.
- **WP3 — BƯỚC 1 (LÕI ĐƯỜNG PDF + NẠP TỪ FILES) ĐÃ CHUẨN BỊ XONG
  (2026-11-09 16:40 CST):** `wp3-prep/` 4 file trên nền WP2/main —
  `ScanView.swift` (**+168/−3**: nút Nạp file + `fileImporter` chọn
  NHIỀU file + hàng chờ lần lượt, trích lớp chữ PDFKit vào cùng
  parser confidence 1.0, PDF không lớp chữ → render trang 1 ~200dpi
  → OCR, file ảnh từ Files → OCR với `sourceType .fileImport`) +
  `Models.swift` (**+32/−0**: `ImageStore.saveFile` lưu PDF nguyên
  byte, `load` rẽ nhánh PDF render trang 1, thêm case
  `SourceType.fileImport` thuần cộng thêm) + `ReceiptViews.swift`
  (**+20/−7**: nhãn "Văn bản trong PDF" đóng F3 mục 3 ở Kiểm Lại +
  Chi Tiết; `save()` nối `sourceFileName`/`originalImageFileNames`)
  + `project.yml` (+7: CFBundleDocumentTypes PDF/ảnh, HandlerRank
  Alternate). **Kiểm chứng phía mình:** fixture PDF TỰ TẠO từ văn
  bản Mẫu 001 (`wp3-fixtures/`, SYNTHETIC — không phải PDF Sam's
  thật): trích xuất giữ 36/36 dòng, bài §F đạt **10/10** bằng bản
  port pattern Swift, PDF không lớp chữ cho 0 dòng → fallback đúng;
  kết quả ở `wp3-fixtures/verify-results.txt` + dòng mới trong
  SCORECARD.md. Đủ 3 chữ ký nội bộ BƯỚC 1 — văn bản: `WP3-GATE.md`.
  **CHƯA đẩy code**; biên dịch + PDFKit/fileImporter trên máy thật
  [CHƯA KIỂM CHỨNG] (gộp bài kiểm mốc M1). **WP3 chưa tới cổng:**
  còn bước 2 — đón Share Sheet/onOpenURL (CẢNH BÁO: không đẩy riêng
  project.yml bước 1 trước bước 2, tránh đường "Mở bằng" chết).
- **WP3 — BƯỚC 2 (ĐÓN SHARE SHEET + CHỐT CỔNG) ĐÃ XONG (2026-11-09
  18:40 CST) — WP3 ĐÃ TỚI CỔNG GÓI:** `wp3-prep/` nay 5 file (thêm
  `ContentView.swift` nền build1 **+18/−2**): ContentView giữ URL qua
  `.onOpenURL` (khoá Face ID thì chờ, không đọc trước cổng khoá) →
  TabShell nhảy tab CHỤP + truyền binding → ScanView (**bước 2
  +63/−1**) hút vào CÙNG `importQueue` của đường Files (không đường
  nạp thứ hai), quét `Documents/Inbox` khi hiện, xoá bản sao Inbox
  ngay sau khi đọc xong dữ liệu (chỉ xoá trong Inbox — file mở-tại-
  chỗ của anh không bị đụng). **Quyết nhãn F3 ĐÃ CHỐT:** nhãn theo
  ĐƯỜNG sinh chữ — lớp chữ "Văn bản trong PDF" / render→OCR "Văn bản
  OCR gốc (từ PDF)" / ảnh "Văn bản OCR gốc" — qua helper chung
  `rawTextTitle` (ReceiptViews bước 2 **+16/−2**) + trường Bool
  thuần cộng thêm `rawTextFromPDFTextLayer` (Models bước 2 **+6/−0**).
  Kiểm chứng: diff từng file + cân bằng ngoặc 4 file (94/94 · 94/94 ·
  185/185 · 36/36) + grep ký hiệu đủ định nghĩa/điểm dùng; không chấm
  lại điểm (khả năng đọc không đổi). Đủ 3 chữ ký CỔNG WP3 — văn bản:
  WP3-GATE.md mục BƯỚC 2 + tờ khai trung thực toàn gói. **CHƯA đẩy
  code.** Điểm mở ghi trong cổng: quyết iOS 26 (anh duyệt 17:32 ở làn
  thiết kế) CHƯA áp vào project.yml (vẫn 17.0) — gắn WP4 §5.6, để
  Wally xử lý khi trình cổng, ca trực không tự đổi.

- **WP4 — BƯỚC 1 (ĐẶC TẢ ĐO + TẦNG TẠO DÒNG ỨNG VIÊN (a)) ĐÃ XONG
  (2026-11-09 20:40 CST):** `WP4-SPEC.md` khoá cách đo (2 ứng viên × 2
  cấu hình gốc/phái sinh theo §5.1; bộ mẫu cổng 001/002/003 + 002-C khi
  có; làn lab chỉ đo độ bền; hệ quả nền tảng §5.6; chia 3 bước).
  `wp4-prep/ScanView.swift` (nền wp3-prep/main, **+121/−16** — thay
  toàn bộ thân recognizeLines cũ, giữ nguyên chữ ký + mọi đường
  WP1–WP3): `mergeRows` F2a nguyên văn CODE-AUDIT (chồng Y ≥50% mảnh
  ngắn hơn, nối theo minX, confidence = min mảnh) áp cho MỌI đường
  ảnh; `collectFragments`/`ocrFragments` F2c (ảnh cao/rộng >3.0 và
  cao >1600px → lát 1600px chồng 200px, quy đổi hộp về ảnh đầy đủ);
  `dedupeOverlap` (cùng chữ + giao hộp ≥50% hộp nhỏ → giữ confidence
  cao). **Kiểm chứng:** port Python (`wp4-fixtures/rowmerge_port.py`)
  trên fixture mảnh-xé SYNTHETIC từ đáp án 002: **9/9 PASS** — ráp 40
  mảnh → 24 hàng khớp ground truth; parser hiện hành ra **§F trọn**
  (203.30 · 9.60+3.90 · 216.80 · 10 dòng · Σ 203.30 · 15 món · TC# 21
  số); đối chứng âm không ráp → subtotal/total None (đúng khiếm
  khuyết thực địa); biên 33% không ráp, dedupe bỏ đúng 6/6 mảnh
  trùng. Bằng chứng: `wp4-fixtures/verify-results.txt` + WP4-GATE.md
  (đủ 3 chữ ký nội bộ bước 1). **CHƯA đẩy code**; biên dịch + Vision
  thật + phép quy đổi toạ độ lát [CHƯA KIỂM CHỨNG] (bước 3/M1).
- **WP4 — BƯỚC 2 (TIỀN XỬ LÝ PHÁI SINH + F2b PARSER) ĐÃ XONG
  (2026-11-09 22:40 CST):** `wp4-prep/ScanView.swift`: `derivedOCRImage`
  — VNDetectRectanglesRequest (tin cậy ≥0.5) → CIPerspectiveCorrection
  → CIColorControls (bỏ màu, tương phản 1.1) — chỉ trong bộ nhớ,
  fail-open về ảnh gốc, ảnh gốc đã lưu trước khi đọc không bao giờ bị
  đụng; cờ `useDerivedImage` là công tắc 2 cấu hình đo của WP4-SPEC §2.
  `wp4-prep/Parser.swift` (nền build1, **+106/−0**): F2b máy trạng thái
  nhãn-chờ-1-dòng cho vòng tổng Sam's + generic và dòng-chỉ-có-tiền
  hoàn tất món Sam's; `validate()` nguyên văn (so byte identical).
  Kiểm chứng: port Python `wp4-fixtures/f2b_port.py` + `verify_f2b.py`
  **10/10 PASS** (`verify-f2b-results.txt`): §F trọn khi tổng/món tách
  dòng, generic tách dòng đủ 3 số, hết-hạn-1-dòng có răng (S3/G2),
  hồi quy hàng nguyên (S5/G3). **FINDING ĐỎ (fixture G4):** dạng
  tiền-ở-dòng-TRƯỚC của Mẫu 003 bị F2b ghép lệch 1 nhịp (subtotal
  nhận 8.25, thuế nhận 105.16, total trống → validate gắn cờ thiếu
  tổng, tờ vào Hộp Chờ; 2 số lệch không có cờ riêng). Chủ sửa: WP7
  (khối tổng tiền-trước-nhãn) + quyết riêng ở cổng bước 3 — ca này
  không tự vá ngoài đặc tả. Đủ 3 chữ ký nội bộ bước 2 — WP4-GATE.md
  mục BƯỚC 2. **CHƯA đẩy code**; biên dịch + Vision/CoreImage thật
  [CHƯA KIỂM CHỨNG] (bước 3/M1).
- **WP5 — BƯỚC 1 (ĐẶC TẢ) ĐÃ XONG (2026-11-10 02:40 CST):** việc độc
  lập làm song song lúc WP4 chờ M1. `WP5-SPEC.md` khoá: nấc 1 khớp
  tên toàn-bộ-dòng (chuẩn hoá + exact-trước-mờ-sau, luật token chống
  dương tính giả), nấc 2 neo phụ mạnh/yếu (seed chỉ 2 neo có bằng
  chứng: street/ZIP Home Depot từ Mẫu 003, phone Sam's Tulsa từ Mẫu
  001; ZIP đơn độc không đủ), nấc 3 món đặc trưng CHỈ gợi ý (seed
  RỖNG — chưa mẫu nào khoá được), C-11 mở rộng validate() cho
  tiệm/ngày theo mẫu ngưỡng total sẵn có; đường rơi dòng-đầu bị bỏ
  về cấu trúc. Ghi rõ WP5 không đổi model (không rủi ro di trú).
  Port Python `wp5-fixtures/vendor_port.py` + `verify_vendor.py`:
  **19/19 PASS** (`verify-vendor-results.txt`) — ca thật: văn bản OCR
  Mẫu 003 → nấc 2 ra "The Home Depot" + cờ (cap 0.5); đối chứng âm
  slogan-không-neo → trống + cờ. Đủ 3 chữ ký nội bộ bước 1 —
  WP5-GATE.md. **CHƯA viết Swift** (bước 2); điểm cổng thật [CHƯA
  KIỂM CHỨNG] (bước 2 + M1).
- **WP5 — BƯỚC 2 (CODE SWIFT) ĐÃ XONG (2026-11-10 04:40 CST):**
  `wp5-prep/Parser.swift` (nền wp4-prep, diff **+323/−50** — 50 dòng
  xoá đã kiểm từng dòng: isSams + khối vendor cũ + đường rơi
  dòng-đầu): `identifyVendor` 3 nấc dịch trung thực port (chạy trước
  rẽ nhánh, nguồn tên tiệm duy nhất), `ParseResult` +6 trường hạ
  cánh WP2, `validate()` thêm khối C-11 tiệm/ngày (phần số học
  nguyên văn), `extractVendorContact` trích nguyên văn địa chỉ/điện
  thoại/mã cửa hàng. Kiểm chứng: port nhận diện **19/19** (không đổi)
  + port trích xuất mới `wp5-fixtures/extract_port.py` **7/7** (E1
  thật Mẫu 003: địa chỉ nguyên văn "9808 E 71ST ST TULSA OK 74133",
  không vớ phone/store giả) + hồi quy F2b **10/10** + rowmerge
  **9/9**; kiểm tĩnh ngoặc cân bằng 3 loại, caller ngoài chỉ dùng
  `parse(lines:)` không đổi chữ ký. Tên chuẩn đổi "Home Depot" →
  "The Home Depot" (theo port/đáp án; dedupeKey generic đổi theo —
  ghi ở WP5-GATE.md mục BƯỚC 2). Đủ 3 chữ ký nội bộ bước 2.
  **CHƯA đẩy code**; biên dịch + lookbehind regex trên iOS [CHƯA
  KIỂM CHỨNG] (build cloud khi trình cổng / M1).
- **WP5 — BƯỚC 3 (NỐI DÂY + CHỐT CỔNG) ĐÃ XONG (2026-11-10
  06:40 CST) — WP5 ĐÃ TỚI CỔNG GÓI:** `wp5-prep/ReceiptViews.swift`
  (nền wp3-prep/main, **+68/−0**): save() ghi 3 trường liên hệ tiệm
  vào model WP2; Kiểm Lại hiện nguồn tiệm + gợi ý nấc 3 + liên hệ
  đọc được; Chi Tiết hiện liên hệ đã lưu. SCORECARD chấm lại: 003
  tiệm ✓-có-cờ (tầng port), 002 giữ ✓; port 19/19 + 7/7, hồi quy
  10/10 + 9/9. Đủ 3 chữ ký cổng gói — WP5-GATE.md mục BƯỚC 3.
  **CHƯA đẩy code**; chờ Wally trình anh duyệt thẻ đẩy ở chat chính
  cùng nhịp M1 (WP4 còn chờ thi đấu trên máy). Điểm mở: nhãn
  currentParserVersion — Wally chốt khi trình đẩy.

## Hàng việc (theo BUILD2-MASTER-PLAN, tuần tự tuyệt đối)
1. ~~**WP0** — Đóng băng bộ mẫu & bảng điểm~~ **ĐÃ XONG 2026-11-09 02:41 CST**:
   SCORECARD.md tồn tại (điểm nền Build 1 theo QA-VERDICT Phụ lục B §0.3) +
   QA ✓ ký nhận thứ tự WP1→WP9 trong `WP0-QA-SIGNOFF.md`. Không cần anh.
2. **WP1** — Cửa chẩn đoán F3 (xem văn bản OCR gốc): code ĐÃ chuẩn bị tới
   cổng 3 chữ ký nội bộ (2026-11-09 04:40, xem WP1-GATE.md + wp1-prep/);
   anh ĐÃ duyệt đẩy 10:43 CST + code ĐÃ lên main commit `769727698d`
   10:44 CST (kiểm chứng md5 ở mục Vị trí hiện tại). Còn lại: kết quả
   build cloud → anh cài + chụp màn hình (nghiệm thu trên máy — cần anh).
3. **WP2** — Hoàn thiện model dữ liệu: bước 1 (model) ĐÃ tới cổng
   2026-11-09 12:40 CST + bước 2 (nối dây lúc lưu + Chi Tiết hiện dòng
   thuế riêng) ĐÃ chuẩn bị xong 2026-11-09 14:40 CST (xem WP2-GATE.md
   cả 2 mục + wp2-prep/ đủ 4 file). **CODE ĐÃ ĐẨY MAIN 2026-11-09
   15:52 CST (commit d7497d8)** — theo luật mốc lớn, anh không cài/test
   riêng gói này; kiểm di trú gộp vào bài test Mốc M1.
4. ~~Chuẩn bị corpus: tải + kiểm chứng bộ WildReceipt/CORD/SROIE (làn lab),
   lập danh mục mẫu theo 7 loại hình (Master Plan §3.3)~~ **ĐÃ XONG phần
   không cần anh 2026-11-09 06:40 CST** (xem `corpus/CORPUS.md`): 3 bộ đã
   tải + kiểm chứng bằng byte/sha256/số dòng đo thật; danh mục 7 loại đã
   lập. Phần còn lại của corpus là gom hoá đơn THẬT của anh theo loại —
   diễn ra khi anh gửi file (PDF Sam's, Best Buy… đã ở điểm chờ), mỗi mẫu
   phải có đáp án chuẩn kiểm tay mới vào bộ.
5. **LÀN THIẾT KẾ UI — ĐÃ XONG vòng 1 (2026-11-09 16:00 CST):** thư mục
   `design/` đủ 3 sản phẩm: UI-STUDY.md (9 hệ tham chiếu, 10 nguyên tắc
   P1–P10, mọi khẳng định gắn nhãn đã-kiểm-chứng/suy-luận), DESIGN-
   SYSTEM.md (hệ "Sổ": màu dark-first, khối tổng kiểu sổ có dòng đối
   chiếu số học, nút CHỤP nổi 60pt, cảnh báo tách khỏi màu Business),
   MOCKUP-M1.html (4 màn, dữ liệu thật 001/002/003 — Wally đã kiểm:
   div 206/206, số $105.16/$216.80/TAX 1 8.517% khớp đáp án). Đầu vào
   WP9. **Quyết đã chốt:** (i) **chỉ iOS 26+, bỏ hẳn iOS 17** — anh
   duyệt 2026-11-09 17:32 CST (ghi vào DESIGN-SYSTEM.md, Sổ quyết
   định); (ii) còn mở: nguyên tắc màu Personal bản sáng cho chữ nhỏ
   ở dark (đo tương phản thật ở WP9 mới khóa).
6. **WP3** — Đường PDF & nạp file (F1): **ĐÃ ĐÓNG** — code đã đẩy
   main bởi Wally 2026-11-09 18:52 CST, commit `ec73f92` (5 file).
7. **WP4** — Thi đấu engine: **bước 1 ĐÃ xong 20:40 CST + bước 2 ĐÃ
   xong 22:40 CST 2026-11-09** (bước 2: tiền xử lý phái sinh +
   F2b parser ở wp4-prep/, kiểm chứng 10/10 + hồi quy 9/9 — xem mục
   WP4 bước 2 ở Vị trí hiện tại + WP4-GATE.md mục BƯỚC 2).
   **Bước 3 — PHẦN CHUẨN BỊ ĐÃ XONG 2026-11-10 00:40 CST** (bản test
   engine (b) cô lập ở wp4-testb/ — xem mục BƯỚC 3 trong WP4-GATE.md).
   **Phần dựng kit ĐÃ XONG 2026-11-10 08:40 CST** (SoHoaDon-TestB-
   Kit.zip sẵn sàng — xem mục ở đầu file + WP4-GATE mục DỰNG KIT).
   **Bước tiếp theo:** bước 3 phần chạy — Wally trình anh thẻ đẩy kit
   TestB lên repo test/nhánh riêng + build cloud → ở M1: chạy thi đấu 2 ứng
   viên × 2 cấu hình trên bộ mẫu + lập 002-C + QA ký chọn engine +
   loại engine thua + quyết nền tảng §5.6 (project.yml vẫn 17.0 —
   Wally xử lý khi trình cổng) + QUYẾT RIÊNG cho finding HAZARD G4
   (F2b ghép lệch trên dạng tiền-trước-nhãn của Mẫu 003; chủ sửa dài
   hạn là WP7 — WP7 không mở khi chưa có thiết kế thứ tự khối tổng
   kèm fixture G4). Trong lúc chờ M1, ca sau có thể chuẩn bị song
   song việc độc lập: đặc tả WP5 (nhận diện tiệm) theo Master Plan.
8. **WP5** — Nhận diện tiệm & kỷ luật độ tin cậy (C-18, C-11):
   **ĐÃ TỚI CỔNG GÓI 2026-11-10 06:40 CST** — bước 1 đặc tả +
   bước 2 code Swift (Parser +323/−50) + bước 3 nối dây/hiển thị/
   SCORECARD (ReceiptViews +68/−0) đều xong, đủ 3 chữ ký cổng gói
   (WP5-GATE.md mục BƯỚC 3). **Bước tiếp theo:** Wally trình anh
   duyệt THẺ ĐẨY CODE WP5 (2 file wp5-prep) ở chat chính, cùng nhịp
   mốc M1 — kèm quyết nhãn currentParserVersion. Sau WP5, phần còn
   lại của M1 là WP4 bước 3 phần chạy (thi đấu engine trên máy +
   002-C + quyết §5.6 + quyết HAZARD G4) — việc đó cần máy/build
   cloud, không phải việc ca trực tự chạy được. WP5 thuộc mốc M1 —
   không xin anh test riêng gói này.

## Điểm dừng chờ anh (ghi rõ, không tự vượt)
- ~~WP1: thẻ duyệt ĐẨY CODE lên main~~ ĐÃ XONG 2026-11-09 10:43–10:44 CST
  (anh duyệt trong chat app; commit main `769727698d`).
- ~~WP1 build cloud + nghiệm thu trên máy~~ ĐÃ XONG 2026-11-09 10:57 CST
  (anh cài + chụp màn hình Chi Tiết mở mục "Văn bản OCR gốc" — WP1 đóng).
- **WP2 CODE ĐÃ ĐẨY LÊN MAIN (2026-11-09 15:52 CST):** anh duyệt sau khi
  xem hồ sơ ("cần coi tận app mới biết ra sao") — commit **d7497d8**
  (4 file wp2-prep). Build cloud đang chạy; kết quả xanh/đỏ anh nhìn
  Actions khi tiện, KHÔNG cần cài/test ngay (luật mốc lớn bên dưới).
- **LUẬT MỐC LỚN (anh ban hành 2026-11-09 15:51 CST, chi tiết trong
  WORKFLOW-PROMPT-IOS.md mục Bổ sung):** anh chỉ test ở bước lớn —
  **M1 = WP2+WP3+WP4+WP5** (bản đọc được hoá đơn), **M2 = WP6..WP9**
  (Build 2 hoàn chỉnh). Nghiệm thu từng gói trên máy anh BỎ; cổng gói
  là nội bộ (3 chữ ký + Wally duyệt + build xanh + tự kiểm fixtures).
  Ca trực KHÔNG nhắn xin anh test từng gói nữa; chỉ nhắn khi tới mốc
  M1/M2, cần quyết định thật của anh, hoặc hỏng 2 ca liên tiếp. Sau build: anh cài đè lên máy đang
  có 2 tờ test Build 1 và mở app — 2 tờ còn nguyên, số không đổi =
  kiểm di trú đạt, WP2 đóng (chi tiết + quyết định thiết kế dòng thuế
  ở WP2-GATE.md mục "WP2 BƯỚC 2").
- **WP3 ĐÃ TỚI CỔNG NỘI BỘ (2026-11-09 18:40 CST):** chờ Wally trình
  anh duyệt THẺ ĐẨY CODE WP3 lên main ở chat chính (5 file wp3-prep).
  Theo luật mốc lớn KHÔNG kèm yêu cầu cài/test; build cloud xanh +
  code lên main là WP3 đóng, mở WP4. Kèm điểm mở để Wally xử lý khi
  trình: project.yml vẫn iOS 17.0 trong khi làn thiết kế đã chốt chỉ
  iOS 26 (17:32 CST) — quyết nền tảng gắn WP4 (§5.6).
- **WP5 ĐÃ TỚI CỔNG NỘI BỘ (2026-11-10 06:40 CST):** chờ Wally trình
  anh duyệt THẺ ĐẨY CODE WP5 lên main ở chat chính (2 file wp5-prep:
  Parser.swift + ReceiptViews.swift). Theo luật mốc lớn KHÔNG kèm yêu
  cầu cài/test; kèm điểm mở: nhãn currentParserVersion vẫn
  "build1-parser" — Wally chốt khi trình.
- Mọi lần ĐẨY CODE lên main khác (thẻ duyệt của hệ thống sẽ tới anh).
- WP3: file PDF Sam's (chưa có) — nghiệm thu trên PDF thật khác trước, ghi chờ.
- WP4: mẫu 002-C chụp camera thật + bản test engine iOS 26 cài trên máy anh.

## Luật ca trực
- **LUẬT LÀM VIỆC CHUNG (anh ban hành 2026-11-09 13:09 CST; TÁI XÁC NHẬN
  chính thức 2026-11-09 23:53 CST dưới tên TEMPLATE B tại
  ~/workspace/prompt-craft/TEMPLATES.md mục B — hai bản khớp nhau): đọc
  và áp dụng `WORKFLOW-PROMPT-IOS.md` (prompt 5 trạng thái đã lọc) —
  trong gói việc chạy vòng code → kiểm chứng trên bộ mẫu cố định → tự sửa
  LIỀN MẠCH không dừng chờ duyệt ở bước con; cổng chỉ ở cuối gói; lúc một
  gói chờ cổng thì chuẩn bị song song việc độc lập; trước cổng tự phản
  biện + tuyên bố trung thực 3 phần.**
- Mỗi ca làm ĐÚNG MỘT bước cụ thể, kiểm chứng, cập nhật file này, đẩy tài liệu
  lên nhánh docs/planning (commit nhỏ, thấy được trên GitHub).
- Chỉ nhắn anh khi: một gói tới cổng, cần anh test/quyết định, hoặc một việc
  hỏng 2 lần liên tiếp. Còn lại im lặng làm.
- Không hứa thời gian. Không code khi chưa tới gói của nó. Không đụng main.

# WORK STATE — Build 2 (ca trực 24/7 cập nhật file này)
Cập nhật lần cuối: 2026-11-11 20:40 CST (ca trực: **RÀ TĨNH NGUY
CƠ CRASH CỦA core-v2-1 XONG — KHÔNG THẤY SMOKING GUN TRONG 3 FILE;
NGUYÊN NHÂN CRASH 20:37 VẪN CHƯA XÁC ĐỊNH, CHỜ LOG TRÊN MÁY** —
việc đầu tiên thuộc điều kiện mở băng (a) của L-2026-11-11-8
(anh báo 20:37: tờ T-Johnnys đọc sống yếu + quét tờ 2 app tự tắt;
TEAM.md đã đóng băng giao bản): rà toàn bộ 3 file staging
integrate-v2 (Parser 2647 · ScanView 722 · ReceiptViews 1250
dòng) + đối chiếu binary IPA run #34 (có ký hiệu
parseGenericItemsV2/extractSamelineItems/yieldScore). Kết quả
(sổ đầy đủ: `integrate-v2/crash-audit/CRASH-AUDIT-LEDGER.md`):
(1) đường sống của lượt quét chỉ gọi `ReceiptParser.parse`
(ScanView:258/331, ReceiptViews:802) — **khối Reconcile là mã
chết** trong bản này (parseAndReconcile/ReconcileSession 0 điểm
gọi từ UI) nên mọi điểm nghi trong đó không thể gây crash khi
quét; (2) mọi điểm ép kiểu/chỉ số/vòng lặp/chia ở đường sống đã
đọc trực tiếp — ĐỀU CÓ CHẶN (lines[index+1] ×2 · khoảng
0...chênh token · Levenshtein · vòng lát while step 1400 ·
rows[count−1] · save() toàn try?); (3) thực nghiệm: bản gương
chạy **800 ca** (132 file buổi đo × 5 đột biến + ca biên)
**0 ngoại lệ**, ca thật chậm nhất 0,032s — chống rủi ro
watchdog ở tầng parser. Còn mở, ghi nhãn lý thuyết: tràn Int ở
moneyToCents cần token tiền ≥17 chữ số (khả năng thấp) · jetsam
ở lượt quét 2 (đỉnh bộ nhớ chưa đo) · ImageStore/model ngoài
phạm vi staging chưa rà. Tuyên bố trung thực — đã chứng minh:
các điểm trên bằng grep + đọc code + chạy stress thật; chưa
chứng minh: NGUYÊN NHÂN GỐC lần tự tắt — bằng chứng quyết định
là **log Phân tích trên máy anh** tại ~20:37 (SoHoaDon-*.ips =
trap · JetsamEvent = hết bộ nhớ), ca này không có và không
đoán thay; chưa làm: không sửa code nào, độ lệch đọc sống
T-Johnnys là tuyến riêng chưa đụng. **Bước tiếp theo: chat
chính/Wally lấy log sự cố trên máy anh → phân loại
trap/jetsam/watchdog → mới định gói sửa**; điều kiện mở băng
(c) giữ nguyên (quét trong app tờ T-Johnnys từ ảnh gốc + 2 tờ
liên tiếp không tắt). Ca này không kêu anh cài/test gì.)
ĐẨY CUỐI CA 20:40: **THÀNH CÔNG** — đúng 1 lần, 4 file
(WORK-STATE.md · integrate-v2/crash-audit/
CRASH-AUDIT-LEDGER.md · run_crash_stress.py ·
crash-stress-results.txt), commit mới trên docs/planning:
`84cd24ab0622638a3579107cbed0243a23554664`. (Dòng này chỉ có
tại bàn, sẽ đi theo lần đẩy của ca sau.)
Cập nhật trước đó: 2026-11-11 18:40 CST (ca trực: **KIỂM CHỨNG
TỪ XA LẦN ĐẨY MƠ HỒ 16:40 — KHÔNG LÊN ĐƯỢC CHÚT NÀO, KHÔNG
TRÙNG; ĐẨY BÙ AN TOÀN** — đúng việc ca 16:40 dặn ca sau, làm
trước mọi việc khác của ca này: đọc trực tiếp GitHub
(zjoenguyenz/Sohoadon) ở ref docs/planning trong ca này:
WORK-STATE.md trên nhánh vẫn là bản 14:40 CST (blob
`19ebcb15…`) · BENCH-MANIFEST.md trên nhánh vẫn là bản 14:40
(blob `bb124d0d…` — chứa mục cập nhật 14:40, KHÔNG có mục
16:40) · cả 6 file `bench-prep/lr-assembly/rehearsal/`
(LR-REHEARSAL-LEDGER.md · make_lr_rehearsal.py ·
verify_lr_rehearsal.py · lr-rehearsal-input.csv ·
lr-rehearsal-manifest.csv · verify-lr-rehearsal-results.txt)
đều **KHÔNG TỒN TẠI** trên nhánh. Kết luận: lần đẩy bị gián
đoạn 16:40 KHÔNG lên được phần nào — đẩy bù các file đó
không tạo trùng và không ghi đè bản mới hơn nào (bản từ xa
đều cũ hơn bản tại bàn). PHÁT HIỆN SONG SONG (không phải
việc của ca này, ca không đụng vào): tại bàn đã có gói
**LR-FREEZE** hoàn thành ~18:12–18:18 CST (việc của chat
chính/đội khác, ngay trước ca này): anh đã gửi **11 ảnh
thật**, L-R01…L-R11 đã nhúng benchapp THẬT + đáp án đóng
băng khép 0 xu từng ca + `appBuild` nâng thành `benchapp-3`,
verifier PASS 8/8 theo sổ riêng `bench-prep/lr-freeze/
LR-FREEZE-LEDGER.md` (ca này chỉ đọc sổ + kiểm sự tồn tại
của file/ảnh/catalog tại bàn — KHÔNG tự chạy lại verifier,
không nhận công, không khẳng định thay số GT). Hệ quả:
tiền đề "chờ anh gửi 10 ảnh thật" của mọi ca trước ĐÃ HẾT.
Tuyên bố trung thực — đã chứng minh: trạng thái từ xa của
docs/planning tại thời điểm kiểm (blob 2 file + vắng mặt
6/6 file diễn tập) bằng đọc trực tiếp GitHub, và sự tồn tại
tại bàn của gói LR-FREEZE; chưa chứng minh: catalog 46 mục /
33 ảnh của LR-FREEZE CHƯA biên dịch (chỉ phán ở build bench
cuối), GT của LR-FREEZE ca này chưa tự kiểm lại; chưa làm:
ráp 24 ca lab vào catalog (công thức đã diễn tập, chờ lần
ráp cuối) + đối chiếu lấp ca §3 + chốt B-04/B-05 + build
cloud bản bench cuối + §3.5(3) luồng OCR gốc trên máy của
Sam's run #26 vẫn chưa về. **Bước tiếp theo: ráp bản bench
cuối** (nhúng 24 ca lab + chốt B-04/B-05) → build cloud →
buổi đo duy nhất — việc đang ở nhịp chat chính/Wally theo
gói LR-FREEZE, ca trực không làm trùng, không kêu anh
cài/test gì.)
ĐẨY CUỐI CA 18:40: **THÀNH CÔNG** — đúng 1 lần, 7 file
(WORK-STATE.md + 6 file `bench-prep/lr-assembly/rehearsal/`
liệt kê ở mục trên; `rehearsal/work/` KHÔNG đẩy — tái lập
được bằng script), commit mới trên docs/planning:
`31b2461f2e121f16335171aab5863a125a3a082d`; đọc lại từ xa
xác nhận LR-REHEARSAL-LEDGER.md đã có trên nhánh. Cố ý
KHÔNG đẩy BENCH-MANIFEST.md ở ca này: bản tại bàn vừa được
gói LR-FREEZE (việc song song) sửa lúc 18:18 CST — để chủ
việc đó/chát chính đẩy cùng nhịp của nó, tránh đẩy trạng
thái dở dang của việc người khác. (Dòng này + mọi sửa sau
thời điểm đẩy chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)
Cập nhật trước đó: 2026-11-11 16:40 CST (ca trực: **DIỄN TẬP
RÁP L-R + NÂNG DẤU BẢN ĐÃ CHẠY TRỌN TRÊN BẢN SAO CÁCH LY —
PASS 8/8** — việc độc lập làm trong lúc chờ ảnh thật, đúng phần
ca 14:40 ghi "diễn tập chưa gồm L-R + nâng dấu bản". Nay
`bench-prep/lr-assembly/rehearsal/` đứng trên nền diễn tập lab
(catalog 69 mục, 46 ảnh, `benchapp-2`): 10 ảnh hạt giống làm ảnh
đứng thay theo bảng input đóng băng kèm sha256 (phân loại +
gtID **kế thừa đúng ca hạt giống nguồn** — không bịa phân loại/
đáp án; `sourceFile` mang tiền tố `REHEARSAL-STANDIN-`,
statusNote ghi rõ DIỄN TẬP/không phải hoá đơn thật), áp đúng
quy ước nạp 5 bước của `benchapp/AFTER.md` cho L-R01…L-R10 +
nâng `appBuild` → `benchapp-3` CHỈ ở bản sao → catalog **69
mục / 56 có file**. Verifier độc lập **PASS 8/8** (L-R khớp
input từng trường 10/10 · nhất quán ba phía 56/56/56 + YAML
parse · sha ảnh 10/10 khớp input lẫn nguồn · ngoặc 7/7+121/121
+ 24 mục W nguyên vẹn · **benchapp thật + nền lab nguyên vẹn**:
hash khớp #ORIG, BenchImages thật vẫn 22, 0 file L-R thật,
appBuild thật vẫn `benchapp-2` · tái lập byte-trùng · hồi quy
bộ chấm byte-trùng · gtID diễn tập có thật trong ANSWERS).
Vòng đầu PASS trọn — không lỗi maker/verifier nào phải sửa.
`work/` 11 MB chỉ tại bàn, tái lập bằng script, KHÔNG đẩy.
Tuyên bố trung thực — đã chứng minh: MỌI thao tác cơ học của
lần ráp cuối nay đã diễn tập (lab ca trước + L-R + nâng dấu ca
này) ở mức file/kê khai trên bản sao đúng trạng thái ráp thật;
chưa chứng minh: catalog 69/56 CHƯA biên dịch (chỉ phán ở build
bench cuối), chép tay + kiểm số học + đóng băng GT MỚI cho ảnh
thật (+ nạp `--answers`) chưa diễn tập được vì phụ thuộc nội
dung ảnh; chưa làm: 10 ca thật L-R vẫn chờ anh, §3.5(3) luồng
OCR gốc trên máy của Sam's run #26 vẫn chưa về, B-04/B-05 chưa
chốt tên (phụ thuộc ca thật khó nhất). **Bước tiếp theo giữ
nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô L-R theo quy
ước 5 bước (thao tác ĐÃ DIỄN TẬP ở lr-assembly/rehearsal) +
đóng băng GT mới → ráp bản bench cuối (lab theo công thức đã
diễn tập + chốt B-04/B-05) + build → buổi đo duy nhất. Ca này
không kêu anh cài/test gì.)
ĐẨY CUỐI CA 16:40: **KHÔNG XÁC ĐỊNH** — đã thử đẩy
docs/planning ĐÚNG 1 LẦN (8 file: WORK-STATE.md ·
bench-prep/BENCH-MANIFEST.md · bench-prep/lr-assembly/
rehearsal/LR-REHEARSAL-LEDGER.md · make_lr_rehearsal.py ·
verify_lr_rehearsal.py · lr-rehearsal-input.csv ·
lr-rehearsal-manifest.csv · verify-lr-rehearsal-results.txt;
`rehearsal/work/` 56 ảnh KHÔNG đẩy — tái lập được bằng script)
— lần đẩy bị gián đoạn giữa chừng do dịch vụ khởi động lại,
kết quả KHÔNG XÁC ĐỊNH (có thể đã lên một phần hoặc chưa);
ca sau kiểm từ xa trạng thái nhánh docs/planning trước khi
đẩy lại, không đẩy mù trùng lặp. (Dòng này + mọi sửa sau thời
điểm đẩy chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)
Cập nhật trước đó: 2026-11-11 14:40 CST (ca trực: **DIỄN TẬP
RÁP LAB ĐÃ CHẠY TRỌN TRÊN BẢN SAO CÁCH LY — PASS 7/7** — việc
độc lập làm trong lúc chờ ảnh thật: công thức ráp cơ học của
`LAB-ASSEMBLY-DECISION.md` trước ca này mới là văn bản quyết,
chưa từng áp thật lên catalog nào. Nay
`bench-prep/lab-assembly/rehearsal/make_rehearsal.py` áp đúng
3 bước lên bản sao cách ly trong `rehearsal/work/`: chép 24 ảnh
staging → BenchImages · +24 mục catalog W (form C · LONG/TALL
L5, DENSE/LOWRES L4 · origin `lab` · gtID rỗng · sourceFile =
đường corpus nguyên văn · statusNote ghi tầng + LAB/không GT/
không cổng) · +24 dòng sources project.yml → catalog **69 mục
/ 46 có file**. Verifier độc lập **PASS 7/7** (mục W khớp Quyết
1/2 từng trường · nhất quán ba phía 46/46/46 + YAML parse ·
sha ảnh W 24/24 khớp staging manifest lẫn subset · ngoặc
7/7+111/111, appBuild giữ `benchapp-2` — diễn tập không tự
nâng dấu bản · **benchapp thật nguyên vẹn**: hash catalog/
project khớp dòng #ORIG tiền-sao-chép, BenchImages vẫn 22 ·
tái lập byte-trùng khi chạy lại · hồi quy bộ chấm byte-trùng
file đã lưu). Verifier vòng đầu tự bắt lỗi của chính nó ở nhóm
7 (truyền đường dẫn tuyệt đối làm lệch dòng tiêu đề bộ chấm —
lỗi verifier, không phải bộ chấm), đã sửa cách gọi, chạy lại
xanh — ghi ở `rehearsal/REHEARSAL-LEDGER.md`. `work/` 7.8 MB
chỉ ở tại bàn, tái lập bằng script, KHÔNG đẩy (tiền lệ staging).
Tuyên bố trung thực — đã chứng minh: công thức ráp chạy trọn ở
mức file/kê khai trên bản sao, lần ráp cuối nay là thao tác đã
diễn tập; chưa chứng minh: catalog 69 mục CHƯA biên dịch
(không swiftc tại bàn — chỉ phán ở build bench cuối), diễn tập
chưa gồm L-R + nâng dấu bản; chưa làm: 10 ca thật L-R vẫn chờ
anh, §3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn chưa
về, B-04/B-05 chưa chốt tên (phụ thuộc ca thật). **Bước tiếp
theo giữ nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô L-R
theo quy ước 5 bước trong benchapp/AFTER.md → ráp bản bench
cuối (nhúng 24 ca lab theo công thức ĐÃ DIỄN TẬP ở
lab-assembly/rehearsal + chốt B-04/B-05) + build → buổi đo duy
nhất. Ca này không kêu anh cài/test gì.)
ĐẨY CUỐI CA 14:40: **THÀNH CÔNG** — đúng 1 lần, 7 file
(WORK-STATE.md · bench-prep/BENCH-MANIFEST.md ·
bench-prep/lab-assembly/rehearsal/REHEARSAL-LEDGER.md ·
bench-prep/lab-assembly/rehearsal/make_rehearsal.py ·
bench-prep/lab-assembly/rehearsal/verify_rehearsal.py ·
bench-prep/lab-assembly/rehearsal/rehearsal-manifest.csv ·
bench-prep/lab-assembly/rehearsal/verify-rehearsal-results.txt;
`rehearsal/work/` 46 ảnh KHÔNG đẩy — tái lập được bằng script),
commit mới trên docs/planning:
`a5a3f7288cc0aab74879820bfe4b0494f3ab40ef`. (Dòng này + mọi sửa
sau thời điểm đẩy chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)
Cập nhật trước đó: 2026-11-11 12:40 CST (ca trực: **2 ĐIỂM MỞ
CỦA LAB-STAGING ĐÃ CHỐT + BỘ CHẤM ĐÃ XỬ LÝ CA LAB TƯỜNG MINH**
— việc độc lập làm trong lúc chờ ảnh thật, đóng đúng 2 điểm mở
ca 06:40 ghi "để Leader chốt ở lần ráp": (1) **origin ca lab =
`lab`** — BENCH-JSON-SPEC §3 cộng enum + mục 6.6 phân loại
thuần cộng, `schema_version` **giữ nguyên 1** (bằng chứng đọc
trực tiếp trong ca: origin là chuỗi thuần ở cả BenchCatalog/
BenchModels — không enum Swift phải sửa; scoresheet đóng băng
vốn đã dùng origin `lab` 24/24); `bench_score.py` sửa tối thiểu
ở tầng bench-prep: run origin `lab` được đếm + liệt kê ở mục
LÀN LAB rồi bỏ qua — không lớp/trọng số/phán quyết/lỗi thiếu
đáp án (trước sửa, ca lab nhúng vào sẽ sinh lỗi "không có đáp
án" vì nhãn WildReceipt không thành GT dạng sổ được — đúng
khoá ACCEPTANCE §3.1: chấm tay hồ sơ LAB). (2) **Ánh xạ
form/difficulty 24 ca W đóng băng** ở văn bản quyết: form `C`
cả 24 · LOWRES/DENSE → L4 · LONG/TALL → L5 — ghi rõ chỉ là
siêu dữ liệu mô tả, không hiệu lực cổng (Quyết 1 đã loại lab
khỏi mọi cổng). Văn bản: `bench-prep/lab-assembly/
LAB-ASSEMBLY-DECISION.md` (kèm công thức ráp cơ học ở bước 0:
chép staging → catalog với các giá trị đã chốt → project.yml,
không còn quyết nào dưới áp lực). Verifier độc lập **PASS
6/6** (ánh xạ khớp tầng gốc 24/24 · trọng số lab ×1 mọi
difficulty + không lớp-khó-thật · file đo trộn selftest + 2 ca
lab dòng rác: 8 run lab chỉ hiện ở mục LÀN LAB, 0 lỗi, phần
không-lab byte-trùng file gốc · hồi quy selftest byte-trùng
file đã lưu · nhất quán spec/scoresheet); verifier tự bắt 2
lỗi của chính nó ở vòng chạy đầu (regex bảng 2-ca/dòng + dòng
thừa) — đã sửa, chạy lại xanh. Tuyên bố trung thực — đã chứng
minh: 2 điểm mở đã đóng nhất quán ở mức file/script tại bàn,
hành vi bộ chấm với ca lab kiểm bằng file đo trộn chạy thật;
chưa chứng minh: BenchApp chứa ca W CHƯA build (ca này không
đụng Swift), ánh xạ difficulty là quy ước mô tả không phải đo
độ khó; chưa làm: 10 ca thật L-R vẫn chờ anh, §3.5(3) luồng
OCR gốc trên máy của Sam's run #26 vẫn chưa về, B-04/B-05
chưa chốt tên (phụ thuộc ca thật). **Bước tiếp theo giữ
nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô L-R theo quy
ước 5 bước trong benchapp/AFTER.md → ráp bản bench cuối (nhúng
24 ca lab theo công thức đã chốt ở lab-assembly + chốt
B-04/B-05) + build → buổi đo duy nhất. Ca này không kêu anh
cài/test gì.)
ĐẨY CUỐI CA 12:40: **THÀNH CÔNG** — đúng 1 lần, 7 file
(WORK-STATE.md · bench-prep/bench_score.py ·
bench-prep/BENCH-JSON-SPEC.md · bench-prep/BENCH-MANIFEST.md ·
bench-prep/lab-assembly/LAB-ASSEMBLY-DECISION.md ·
bench-prep/lab-assembly/verify_lab_assembly.py ·
bench-prep/lab-assembly/verify-lab-assembly-results.txt),
commit mới trên docs/planning:
`1ea2123e94e55a6bf8c903aa56d8a6d2d7d6bd6f`. (Dòng này + mọi sửa
sau thời điểm đẩy chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)
Cập nhật trước đó: 2026-11-11 10:40 CST (ca trực: **KIỂM
CHỨNG TỪ XA BACKLOG 00:40–04:40 — CẢ 40 FILE ĐỀU VẮNG TRÊN
docs/planning; LIỆT KÊ TƯỜNG MINH ĐỂ ĐẨY BÙ** — đúng việc ca
08:40 dặn ca sau, làm trong lúc chờ ảnh thật: đọc trực tiếp
GitHub (zjoenguyenz/Sohoadon) trong ca này: đầu nhánh
docs/planning vẫn là `2fb3d37b8caeccba828c1ac81ca64751cce8a0f5`
(commit ca 08:40, 2026-11-11T15:25:24Z) — khớp sổ sync tại
bàn. Kiểm TỪNG file backlog bằng get_file_contents ở ref
docs/planning: cả **40/40 file** đều trả "path does not point
to a file or directory, or the file does not exist" — tức
KHÔNG TỒN TẠI trên nhánh, đẩy bù không trùng, không ghi đè.
Danh sách tường minh 40 file: text-degrade 28 file
(TEXT-DEGRADE-LEDGER.md · run_text_degrade.py ·
verify_text_degrade.py · text-degrade-results.txt ·
flows/T01.txt…T24.txt) · lab-wildreceipt 6 file
(LAB-WILDRECEIPT-LEDGER.md · select_wildreceipt.py ·
verify_wildreceipt_subset.py · wildreceipt-subset.csv ·
selection-results.txt · verify-wildreceipt-results.txt) ·
measure-pack 6 file (MEASURE-PACK.md · MEASURE-PACK-LEDGER.md
· gen_scoresheet.py · verify_measure_pack.py · scoresheet.csv
· verify-measure-pack-results.txt). Kiểm lại tại bàn trong
ca này: verifier text-degrade PASS (verdict khớp 24/24, tái
lập flows byte-trùng) · verifier WildReceipt PASS 8/8 ·
verifier measure-pack PASS 10/10. Tuyên bố trung thực — đã
chứng minh: trạng thái vắng mặt 40/40 trên docs/planning +
đầu nhánh, và 3 gói backlog vẫn PASS verifier tại bàn; chưa
chứng minh: không có gì về build/app — ca này không đụng
Swift/schema/pipeline; chưa làm: 10 ca thật L-R vẫn chờ anh,
§3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn chưa về.
**Bước tiếp theo giữ nguyên: chờ anh gửi 10 ảnh thật** →
Leader lấp ô L-R theo quy ước 5 bước trong benchapp/AFTER.md
→ ráp bản bench cuối (kèm nhúng 24 ca lab từ staging + chốt
B-04/B-05 + chốt 2 điểm mở origin/difficulty của ca 06:40) +
build → buổi đo duy nhất. Ca này không kêu anh cài/test gì.)
ĐẨY CUỐI CA 10:40: **THÀNH CÔNG** — đúng 1 lần, 41 file
(WORK-STATE.md + 40 file backlog liệt kê ở mục trên), commit
mới trên docs/planning: `f7bef45c56d8ead9d71df0949ce0397560b1fb9d`;
sổ sync snapshot đã ghi nhận commit này. Backlog tài liệu
00:40–04:40 nay ĐÃ HẾT — không còn file bench-prep nào của các
ca đó chỉ nằm tại bàn. (Dòng này + mọi sửa sau thời điểm đẩy
chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)
Cập nhật trước đó: 2026-11-11 08:40 CST (ca trực: **KIỂM CHỨNG
TỪ XA LẦN ĐẨY MƠ HỒ 06:40 — KHÔNG LÊN ĐƯỢC CHÚT NÀO, KHÔNG
TRÙNG; ĐẨY LẠI AN TOÀN** — đúng việc ca 06:40 dặn ca sau, làm
trong lúc chờ ảnh thật: đọc trực tiếp GitHub
(zjoenguyenz/Sohoadon) trong ca này: nhánh docs/planning vẫn ở
đầu `6e68d02d45d8` (commit 2026-11-11T04:42:53Z = 22:40 CST
2026-11-10, "WORK-STATE 22:40 + benchapp HONESTY") — không có
commit nào sau đó. Kiểm từng file của danh sách đẩy 06:40 trên
nhánh: WORK-STATE.md vẫn là bản cũ (blob `78fa5712…`, khác blob
bản tại bàn `73a26699…`) · BENCH-MANIFEST.md vẫn là bản cũ
(blob `86ca17ba…`, khác bản tại bàn `fa119d3e…`) · cả 5 file
`bench-prep/lab-staging/` (LAB-STAGING-LEDGER.md,
make_lab_staging.py, verify_lab_staging.py,
lab-staging-manifest.csv, verify-lab-staging-results.txt)
**KHÔNG TỒN TẠI** trên docs/planning. Kết luận: lần đẩy bị
gián đoạn 06:40 KHÔNG lên được phần nào — đẩy lại 7 file đó
không tạo trùng. Phát hiện phụ cùng lần kiểm (ghi nhận, chưa
xử lý ở ca này): sổ của 3 ca 00:40/02:40/04:40
(text-degrade/TEXT-DEGRADE-LEDGER.md,
lab-wildreceipt/LAB-WILDRECEIPT-LEDGER.md,
measure-pack/MEASURE-PACK.md) cũng **KHÔNG TỒN TẠI** trên
nhánh — backlog tài liệu đó vẫn chỉ có tại bàn, ca sau nếu đẩy
bù phải liệt kê tường minh từng file, không gộp mù vào lần đẩy
này. Tuyên bố trung thực — đã chứng minh: trạng thái từ xa của
docs/planning ở thời điểm kiểm (đầu nhánh + tồn tại/vắng mặt
từng file + blob 2 file cũ) bằng đọc trực tiếp GitHub; chưa
chứng minh: không có gì về build/app — ca này không đụng
Swift/schema/pipeline; chưa làm: 10 ca thật L-R vẫn chờ anh,
§3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn chưa về.
**Bước tiếp theo giữ nguyên: chờ anh gửi 10 ảnh thật** →
Leader lấp ô L-R theo quy ước 5 bước trong benchapp/AFTER.md
→ ráp bản bench cuối (kèm nhúng 24 ca lab từ staging + chốt
B-04/B-05 + chốt 2 điểm mở origin/difficulty của ca 06:40) +
build → buổi đo duy nhất. Ca này không kêu anh cài/test gì.)
ĐẨY CUỐI CA 08:40: **THÀNH CÔNG** — đúng 1 lần, 7 file của
danh sách 06:40, commit mới trên docs/planning:
`2fb3d37b8caeccba828c1ac81ca64751cce8a0f5`; sổ sync snapshot
đã ghi nhận commit này. (Dòng này + mọi sửa sau thời điểm đẩy
chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau. Backlog tài
liệu 00:40–04:40 nêu ở mục trên vẫn CHƯA đẩy bù.)
Cập nhật trước đó: 2026-11-11 06:40 CST (ca trực: **STAGING
24 ẢNH LAB ĐÃ ĐÓNG GÓI + KIỂM ĐẠT** — việc độc lập làm trong lúc
chờ ảnh thật: phần "nhúng 24 ảnh lab" của bước 0 buổi chuẩn bị
trước ca này mới có bảng kê đóng băng, ảnh thật vẫn nằm rải
trong cây corpus với tên gốc dài, lần ráp cuối sẽ phải mò lại
24 đường dẫn + chép tay. Nay `bench-prep/lab-staging/` có bộ
file staging mang tên ca `images/W-01.jpg`…`W-24.jpg` chép
byte-trùng nguồn corpus bởi `make_lab_staging.py` (kiểm sha256
trước/sau chép) + `lab-staging-manifest.csv`; tổng **2.092.865
byte**. Verifier độc lập **PASS 10/10** (sha+bytes khớp bảng kê
24/24 · byte-trùng nguồn 24/24 · JPEG thật + kích thước khớp
24/24 · tái lập byte-trùng · **BenchApp không bị đụng**:
BenchImages vẫn 22, catalog 0 mã W) + `bench_score.py` selftest
byte-trùng file đã lưu. Sổ: `lab-staging/LAB-STAGING-LEDGER.md`
(tuyên bố trung thực 3 phần; ghi rõ 2 điểm MỞ ca này phát hiện
mà KHÔNG tự quyết: (1) enum `origin` của BENCH-JSON-SPEC chỉ có
real/synthetic — ca lab đăng ký real+L1/L2/L5 sẽ bị trọng số ×2
như ca thật, đăng ký synthetic thì sai nhãn, hướng ghi nhận là
mở enum "lab" ×1 ở lần ráp; (2) ánh xạ difficulty cho tầng
LONG/DENSE/LOWRES/TALL chưa đóng băng ở đâu). Hệ quả: phần
nhúng lab ở lần ráp cuối nay chỉ còn thao tác cơ học có nguồn
kiểm chứng (chép staging → BenchImages + đăng ký + build).
**Bước tiếp theo giữ nguyên: chờ anh gửi 10 ảnh thật** → Leader
lấp ô L-R theo quy ước 5 bước trong benchapp/AFTER.md → ráp bản
bench cuối (kèm nhúng 24 ca lab từ staging này + chốt B-04/
B-05 + chốt 2 điểm mở trên) + build → buổi đo duy nhất;
§3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn chưa về.
Ca này không đụng Swift/schema/pipeline, không kêu anh
cài/test gì.)
CHỜ DUYỆT ĐẨY (ca 06:40): đã thử đẩy docs/planning ĐÚNG 1 LẦN
(7 file: WORK-STATE.md, bench-prep/BENCH-MANIFEST.md,
bench-prep/lab-staging/LAB-STAGING-LEDGER.md,
bench-prep/lab-staging/make_lab_staging.py,
bench-prep/lab-staging/verify_lab_staging.py,
bench-prep/lab-staging/lab-staging-manifest.csv,
bench-prep/lab-staging/verify-lab-staging-results.txt;
24 ảnh staging KHÔNG đẩy — tái lập được bằng script từ corpus)
— lần đẩy bị gián đoạn giữa chừng do dịch vụ khởi động lại,
kết quả KHÔNG XÁC ĐỊNH (có thể đã lên một phần hoặc chưa);
ca sau kiểm từ xa trạng thái nhánh docs/planning trước khi
đẩy lại, không đẩy mù trùng lặp. **[ĐÃ GIẢI QUYẾT 08:40 CST:
ca trực kiểm từ xa — lần đẩy đó KHÔNG lên được phần nào, xem
mục mới nhất ở đầu file; ca 08:40 đẩy lại 7 file này đúng 1 lần
ở cuối ca.]**
Cập nhật trước đó: 2026-11-11 04:40 CST (ca trực: **GÓI ĐO
ĐÓNG BĂNG — BẢNG CHẤM IN SẴN ĐÃ XÂY + KIỂM ĐẠT** — việc độc lập
lấp mục cuối còn tự làm được của điều kiện chặn buổi đo
§3.5(2), làm trong lúc chờ ảnh thật: trước ca này "bảng chấm in
sẵn (ca × chỉ số × ngưỡng)" + thứ tự nạp cố định + hướng dẫn
chụp 1 trang của §4.1 CHƯA TỒN TẠI thành tài liệu ở đâu cả.
Nay `bench-prep/measure-pack/` có: `MEASURE-PACK.md` (ánh xạ mã
buổi đo §4.2 ↔ mã BenchApp — Phần 1 lệch mã thật S-01…S-04 ↔
N-001/N-002/C-002C/C-003, ca danh dự S-0 đứng dòng S-05-DANH-DỰ ·
9 hồ sơ ngưỡng nguyên văn §2.3 phủ luật M9 · thứ tự buổi đo cố
định 7 bước, làn lab ở phần 3B ghi rõ là quyết của gói này ·
trang hướng dẫn chụp §4.3 cắt ra gửi anh tại buổi đo · bảng
trạng thái điều kiện chặn) + `scoresheet.csv` **71 dòng ca**
(45 catalog = 22 READY + 13 MISSING + 10 ô L-R · 24 lab W ·
L-01/L-02) sinh xác định bởi `gen_scoresheet.py` — ca tự bắt +
sửa 2 lỗi của bộ sinh (ghi chú C-002C/S-1 gán nhầm đường nạp
L-R; đường chấm ca đã có đáp án bị ghi chờ-đáp-án). Verifier
độc lập **PASS 10/10** (tập mã khớp catalog 45 · GT của ca READY
có thật trong sổ `bench_score.py` · 18 synthetic đều hồ sơ D ·
24 lab khớp subset · M9 71/71 · tái lập CSV byte-trùng) +
`bench_score.py` chạy lại trên selftest cho kết quả byte-trùng
file đã lưu. Sổ: `measure-pack/MEASURE-PACK-LEDGER.md` (tuyên
bố trung thực 3 phần; ghi rõ hồ sơ C-REAL của L-R chỉ tạm khoá,
2 ca B-04/B-05 chưa chốt tên, gói chưa từng dùng ở buổi đo
thật). Hệ quả: **§3.5(2) nay chỉ còn thiếu 10 ca thật L-R chờ
anh + nhúng 24 ảnh lab ở lần ráp cuối**; §3.5(3) luồng OCR gốc
trên máy của Sam's run #26 vẫn chưa về. **Bước tiếp theo giữ
nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô L-R theo quy
ước 5 bước trong benchapp/AFTER.md → ráp bản bench cuối (kèm
nhúng 24 ca lab + chốt B-04/B-05) + build → buổi đo duy nhất.
Ca này không đụng Swift/schema/pipeline, không kêu anh cài/test gì.)
Cập nhật trước đó: 2026-11-11 02:40 CST (ca trực: **TẬP CON KHÓ
WildReceipt ĐÃ CHỌN + ĐÓNG BĂNG** — việc độc lập xếp hàng ở ca
00:40, làm trong lúc chờ ảnh thật: phần "danh sách ca lab" của
điều kiện chặn buổi đo §3.5(2) trước ca này CHƯA HỀ TỒN TẠI.
Nay `bench-prep/lab-wildreceipt/` có bộ chọn xác định theo
ACCEPTANCE §3.1 (cửa Total+Date+Subtotal + Item/Price · loại
trùng giao dịch bằng khoá mờ — bắt được các cặp nhãn lệch như
ElBorracho total 136.5/136.95, ILIO'S/ILTO'S · cửa độ khó hộp
≥35 + món ≥4 · 4 tầng LONG/DENSE/LOWRES/TALL × 6): phễu **472 →
266 → 255 → 247 → 109 → 24 ca W-01…W-24**; số phủ nhãn đếm lại
khớp đúng §3.1 (Total 423 · Date 398 · Subtotal 343); độ khó
trung vị của tập chọn vs tập đủ điều kiện: hộp **60.5 vs 39**,
món **8.5 vs 4**. Bảng kê `wildreceipt-subset.csv` đóng băng
sha256 + đáp án nhãn NGUYÊN VĂN từng ca (cột xu chỉ tham chiếu
— nhãn có nhiễu thật đã ghi ở sổ: W-01 subtotal > total, W-15
total 3 số lẻ, W-24 hai subtotal). Verifier độc lập **PASS 8/8**
(sha256 24/24 · nhãn khớp từng ký tự · 0 cặp trùng · tái lập
CSV byte-trùng). Sổ: `lab-wildreceipt/LAB-WILDRECEIPT-LEDGER.md`
(tuyên bố trung thực 3 phần; ghi rõ độ khó chỉ trên 4 trục đo
được từ nhãn/hình học — không khẳng định nhăn/mờ/phai; cách
chấm khoá: M1/M2 đúng-hoặc-cờ + E1/E2 đẳng thức nội bộ, không
bao giờ trình như sổ món). Hệ quả: **§3.5(2) nay chỉ còn thiếu
10 ca thật L-R chờ anh**; 24 ảnh lab chưa nhúng BenchApp (ráp
ở bản bench cuối cùng nhịp L-R, ca này không đụng Swift).
**Bước tiếp theo giữ nguyên: chờ anh gửi 10 ảnh thật** → Leader
lấp ô L-R theo quy ước 5 bước trong benchapp/AFTER.md → ráp
bản bench cuối (kèm nhúng 24 ca lab) + build → buổi đo duy
nhất; §3.5(3) luồng OCR gốc trên máy của Sam's run #26 vẫn
chưa về. Ca này không kêu anh cài/test gì.)
Cập nhật trước đó: 2026-11-11 00:40 CST (ca trực: **CỔNG G2 —
BỘ SUY BIẾN CHỮ ĐÃ XÂY + CHẠY ĐẠT** — việc độc lập lấp khoảng
trống còn lại của điều kiện chặn buổi đo §3.5(1), làm trong lúc
chờ ảnh thật: trước ca này bộ suy biến chữ theo ACCEPTANCE §3.3
CHƯA HỀ TỒN TẠI trong repo (chỉ có suy biến ảnh). Nay
`bench-prep/text-degrade/` có 24 luồng đóng băng (001 THẬT ·
003 THẬT · 002 tái dựng chỉ 1 ca, ghi nhãn) đủ 6 họ bệnh §3.3
(SPLIT 4 · DROP 6 · NOISE 5 · BEFORE 2 · DUP 3 · GARB 2 · CTRL 2),
chấm trên cặp mirror port(fixed=True)+reconcile (đã crosscheck
Swift 13/13): **10 CORRECT/CORRECT-REPAIRED + 14 FLAGGED + 0
SILENT-WRONG → G2 PASS ở tầng T3+T4** (`text-degrade-results.txt`).
Verifier độc lập đọc từ đĩa: verdict khớp **24/24**, flows tái
lập byte-trùng **24/24**, đủ họ. Chạy lại toàn bộ cổng chữ cũ
trong cùng ca đều xanh: ledger PASS · m1fix 13/13 · reparse
11/11 · rowmerge 9/9 (chạy trong wp4-fixtures/) · F2b 10/10 ·
vendor 19/19 · extract 7/7 · reconcile 13/13 · crosscheck
13/13 · synthetic PASS. Sổ: `text-degrade/TEXT-DEGRADE-LEDGER.md`
(tuyên bố trung thực 3 phần; ghi rõ 3 ca TOTAL_ONLY được bao phủ
cờ ở tầng reconcile, chưa đo ở tầng giao diện app). Hệ quả:
**§3.5(1) nửa offline NAY ĐỦ**; buổi đo VẪN bị chặn bởi §3.5(2)
(danh sách ca lab WildReceipt chưa chọn — việc độc lập ca sau
làm được — và 10 ca thật L-R chờ anh) + §3.5(3) (luồng OCR gốc
trên máy của Sam's run #26 chưa về). **Bước tiếp theo giữ
nguyên: chờ anh gửi 10 ảnh thật** → Leader lấp ô L-R theo quy
ước 5 bước trong benchapp/AFTER.md → ráp bản bench cuối + build
→ buổi đo duy nhất; việc độc lập xếp hàng cho ca sau: chọn tập
con khó WildReceipt theo ACCEPTANCE §3.1 (kèm bảng kê đóng băng).
Ca này không đụng Swift/schema/pipeline, không kêu anh cài/test gì.)
Cập nhật trước đó: 2026-11-10 22:40 CST (ca trực: **SỬA CÂU CŨ
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

## BUỔI ĐO — BẢN BENCH CUỐI ĐÃ SẴN SÀNG (2026-11-11 18:5x CST)
- 11 ảnh thật anh gửi đã đóng băng (LR-FREEZE, khép 11/11 0 xu) + 18
  synthetic + 4 ca gốc = 33 ảnh trong app đo, catalog benchapp-3.
- Run #33 (nhánh bench, commit dd7029c) SUCCESS; artifact
  SoHoaDon-BENCH-run33-2026-11-10 (13.1 MB). Wally tự tải + giải nén:
  33/33 ảnh nằm trong .app, sha256 mẫu kiểm (L-R01, L-R11,
  SYN-003-LIGHT, S-0) khớp byte bản đóng băng cục bộ.
- ĐÃ GỌI ANH CHẠY BUỔI ĐO DUY NHẤT: cài bản bench (app riêng, không
  đụng dữ liệu Sổ Hóa Đơn), mở app, bấm "Chạy đo", gửi lại file JSON.
  Nhận JSON → chấm bench_score.py theo lớp → tuyên bố kết cục A/B/C.

## BUỔI ĐO ĐÃ CHẠY — ĐANG KIỂM TOÀN VẸN PHÉP ĐO (2026-11-11 19:3x CST)
- Anh chạy xong buổi đo và gửi JSON (19:29): đủ 132 runs = 33 ảnh ×
  4 cấu hình, app tự khai build benchapp-3 / parser p2-core-1, máy
  iPhone iOS 27.2. SAU KHI CHẠY XONG APP ĐO BỊ FREEZE (anh báo
  19:31) — lỗi của bản bench, đã ghi nhận; app chính + dữ liệu của
  anh không liên quan. JSON vẫn nguyên vẹn.
- Chấm lượt đầu bằng bench_score.py: MỌI cấu hình 0 sổ trọn, điểm 0
  — NHƯNG kiểm tra chéo file gốc cho thấy dấu hiệu phép đo hỏng ở
  phía BỘ CHẤM, chưa phải kết luận về engine: các pass OCR trong
  JSON có đủ dòng thật (vd L-R06 A0 = 28 dòng, đọc đúng tên tiệm)
  trong khi bộ chấm báo 0 dòng món cho ca đó; chính bench_score.py
  cũng crash TypeError ở đoạn phán quyết khi nạp --answers.
  => CHƯA tuyên bố kết cục A/B/C. Việc tiếp theo (phía em): rà soát
  bộ chấm đối chiếu tay từng ca trên JSON gốc, sửa đường chấm,
  chấm lại, rồi mới tuyên bố theo §5.5 kèm số liệu.
- FREEZE — trình tự anh báo nguyên văn (19:31): chạy đo xong → bấm
  share file → nó chạy → anh cancel, không share nữa → app đứng yên
  từ đó tới giờ. Suy luận (gắn nhãn): điểm khoá nằm ở tầng giao diện
  của BenchView quanh việc trình bày/huỷ sheet chia sẻ (trạng thái
  tiến trình không được dỡ sau khi huỷ share), KHÔNG nằm ở đường OCR
  — JSON đã xuất trọn trước điểm freeze. Truy nguyên nhân khi tích
  hợp; app đo là đồ đo dùng một lần, anh xoá không hệ quả gì.

## PHÂN TÍCH BUỔI ĐO — KẾT LUẬN KIỂM TOÀN VẸN (2026-11-11 19:4x CST)
- Lượt chấm 0-điểm KHÔNG phải hỏng phép đo: port chấm là bản sao
  TRUNG THỰC của parser Swift hiện tại (đối chiếu mã nguồn hai bên:
  parseGenericItems chỉ hiểu bố cục khối UPC kiểu Home Depot —
  dòng mã >=9 số + dòng tiền trần + dòng mô tả). Hệ quả: mọi hoá
  đơn dạng "tên ... tiền CÙNG DÒNG" (Pan-Asia, Walmart, Costco,
  T-Johnnys) cho 0 món ở MỌI cấu hình — trong app thật cũng vậy.
  Đây là PHÁT HIỆN CỐT LÕI của buổi đo: thiếu hẳn chương trích xuất
  món cùng-dòng trong parser; KHÔNG phải lỗi engine OCR (các pass
  có đủ 28–44 dòng, số tiền nằm trong văn bản).
- Mặt trước (OCR/hợp nhất): A0 (đọc đơn + chọn theo sản lượng)
  KHÔNG thua A1/A2/A3; hợp nhất hiện tại làm TRÙNG dòng và phá
  chọn neo ở vài ca (vd L-R06 A1: dòng đầu bị nhân đôi, parser vớ
  thuế $0.22 làm subtotal; N-001 A1–A3 sai total trong khi A0
  đúng). Engine (b) không cho thắng lợi bù lại. Lỗi ngày M2 lặp ở
  L-R02/L-R03/L-R08 mọi cấu hình (định dạng ngày chữ + chọn ngày).
- bench_score.py crash TypeError ở đoạn phán quyết khi nạp
  --answers (bảng theo lớp in trước crash đã đối chiếu tay với
  file gốc ở các ca then chốt: L-R06/L-R11/N-001/S-0).
- XẾP LOẠI: không phải A (không cấu hình nào qua), KHÔNG phải C
  như đã định nghĩa (engine không phải nút thắt — văn bản đã về,
  parser của đội vứt bỏ). Gần nhất với B (một phần) + nút thắt xác
  định chính xác thuộc phía đội. KHÔNG cần buổi đo mới: JSON đã ghi
  đủ dòng cuối của mọi cấu hình — sửa parser + bộ chấm rồi chấm
  lại trên CHÍNH file này.
- Việc tiếp: gói SCORER-FIX + PARSER-GAP (sửa crash bộ chấm; xây
  trích xuất món cùng-dòng ở port Python trước, kiểm chứng trên
  corpus đóng băng + 11 ca L-R; chấm lại; khuyến nghị mặt trước).
  Swift theo sau ở gói tích hợp khi hướng đã chứng minh.

## CHẤM LẠI XONG — PARSER-GAP ĐÃ VÁ Ở PORT, CHỐT MẶT TRƯỚC A0 (2026-11-11 19:5x CST)
- bench_score crash đã sửa (layer_of nhận dict thay vì id — chỉ nổ
  khi có ca thật độ khó cao; selftest không có nên ngủ qua các vòng).
- port_v2 (bản nháp cho Swift): thêm trích xuất món cùng-dòng.
  Chấm lại CHÍNH JSON buổi đo, ca thật ở A0: trọn sổ 0/15 → 3/15;
  Σ món khép 8/11 ca L-R (trước 0/11). Leader tự chạy lại kiểm:
  L-R07 17 món/8283 ✓, L-R02 2/16448 ✓, L-R10 3/9691 ✓, L-R03
  10/6760 ✓, hồi quy 001 (10 dòng/20330/qty 15) ✓.
- 3 ca chưa khép (L-R05/L-R08/L-R09): ký tự tiền đã nát ngay trong
  dòng OCR cuối (vd '$6.29' thành '$0.29'; '3.€8') — cần đọc lại
  vùng ảnh (ROI) ở tầng tích hợp, không nặn số.
- Tồn đọng tầng totals/ngày: L-R01 nhãn total bị OCR vỡ ('34.86ł'),
  L-R02/L-R08 dòng thuế không bắt đầu bằng TAX + ngày tháng chữ,
  L-R03 subtotal OCR 67.50 (đúng 67.60) — việc của gói tích hợp.
- MẶT TRƯỚC CHỐT: đọc đơn kiểu A0. A1/A2/A3 trọn 0/15 và phá ca
  đúng của A0 (C-003 A1 Σ phình 128.038.684¢; L-R10 A1 thừa 6996
  do KORKY nhân đôi). Thuật toán gộp chỉ được quay lại khi tự chứng
  minh trên corpus này. Engine (b): cắt theo luật ablation.
- TIẾP: gói tích hợp Swift (trích xuất cùng-dòng + vá tầng totals/
  ngày + mặt trước A0) → MỘT bản lớn qua G0–G7 + tem bản mới.

## INTEGRATE-V2 ĐÃ ĐẨY + BUILD XANH — BẢN CORE-V2-1 (2026-11-11 20:0x CST)
- Đẩy main commit 7c52ddc8 (anh duyệt thẻ): ScanView = OCRFIX
  nguyên byte (mặt trước A0), Parser = p2-fix + trích món cùng-dòng
  + vá totals/ngày (anchorTotals/matchTaxRateLine/parseGenericItemsV2),
  ReceiptViews chỉ đổi tem p2-core-1 → core-v2-1.
- Run #34 THÀNH CÔNG (40s). Wally tự mở file IPA thật kiểm nhị
  phân: có đủ parseGenericItemsV2/matchTaxRateLine/anchorTotals/
  yieldScore + nhãn nút Đọc lại/Ảnh gốc/Chụp lại. File giao:
  downloads/SoHoaDon-CORE-V2-run34-2026-11-11.ipa, sha256 82d06a2a…
  (artifact GitHub vẫn mang tên cũ SoHoaDon-P2-CORE-run34-2026-11-10
  do workflow chưa đổi tên — cùng một file).
- Số kiểm trên dòng-đọc-thật của buổi đo (bản gương Swift): trọn
  sổ 5/11 ca L-R (trước làm lại: 0/11), Σ khép 8/11; hồi quy
  001/002/003 nguyên vẹn. 3 ca tiền bị OCR phá (L-R05/08/09) vẫn mở
  — chờ tầng đọc-lại-ROI; L-R03 số subtotal sai ngay trong chữ OCR
  (67.50 vs 67.60) được cổng sổ gắn cờ, không sửa thầm.
- Chờ anh test mốc lớn trên máy (quét mới + nút Đọc lại trên hồ sơ
  đã lưu) — phán quyết Điều 1 thuộc mốc này.

## TRUY LỖI FREEZE APP ĐO (đọc tĩnh, 2026-11-11 20:1x CST)
- Đọc BenchView.swift: đường share là ShareLink(item:) thuần của
  SwiftUI — không trạng thái trình bày tự chế, không handler huỷ;
  isRunning đã về false trước khi nút Xuất hiện. KHÔNG tìm thấy cơ
  chế app-side nào khoá UI khi huỷ share. Khả năng nhất quán nhất:
  treo ở tầng share-sheet hệ thống trên iOS 27.2 (bản beta anh
  chạy) — NHÃN: suy luận, không chứng minh được từ đây (không có
  crash log). App đo là đồ bỏ, không sửa; app chính không dùng
  đường share này. ĐÓNG mục truy lỗi.

## CORE-V2 RỚT TEST TRÊN MÁY ANH (2026-11-11 20:37 CST) — ĐÓNG BĂNG
- Anh báo: "Không được và quét thử tờ 2 thì app crash tự tắt" +
  ảnh màn Kiểm Lại tờ T-Johnnys (L-R08): ngày ✓, subtotal ✓
  155.64, total ✓ 170.20; Σ món 47.87 ✗, thuế 2.56 ✗, vendor ✗.
  Cờ lệch sổ bung đúng cả hai. Tờ 2 crash — chưa rõ tờ nào.
- Đã ghi L-2026-11-11-8 vào TEAM.md + đóng băng giao bản (Điều 4).
  Cần từ anh: ảnh tờ 2 + văn bản OCR gốc của tờ 1 (mục "Văn bản OCR
  gốc" trong màn Kiểm Lại) để tái hiện đúng luồng dòng trên máy.
- Điều kiện mở băng đã chốt (chat chính 20:38): nguyên nhân gốc có
  bằng chứng cho cả cụm lỗi + chặn tái diễn trong TEAM.md + kiểm
  chứng đầu-cuối: quét trong app tờ L-R08 từ ảnh gốc (đúng món +
  thuế 2 tầng 1.33/13.23 + vendor) và 2 tờ liên tiếp không crash.
  Gói truy crash (crashfix/) đang chạy, đã nhận bổ sung dữ kiện này.

## LỆNH 20:40 CST 2026-11-11 — LÀM LẠI TOÀN BỘ CỐT LÕI, NGHIÊN CỨU SÂU TRƯỚC
- Bỏ truy tờ 2. Tập trung: vì sao ngay tờ 1 (L-R08) cũng không qua
  được cốt lõi khi quét sống trong app chính.
- Mở chương trình NGHIÊN CỨU SÂU toàn đội (chưa giải pháp, chưa
  bản giao): giải phẫu vấn đề từ bằng chứng đóng băng + đối chiếu
  từng dòng cấu hình giữa đường OCR app đo và đường OCR app chính
  + nghiên cứu engine/capture từ tài liệu gốc. Báo cáo nghiên cứu
  trình anh trước khi thiết kế lại.

## AUDIT + ĐỐI CHIẾU XONG — LỆCH NẰM Ở ẢNH ĐẦU VÀO (2026-11-11 20:46 CST)
- Cấu hình OCR app-đo ≡ app-chính từng dòng. Lệch là PIXEL: bench
  đọc JPG 1320×1760 một lượt (cắt lát không kích hoạt); app chính
  đọc ảnh VisionKit đã xử lý, ảnh quét cao 2868px → cắt lát kích
  hoạt + lỗi xé ở đường nối. Ứng viên phái sinh: bench thua 8/8 khi
  xuất hiện, sống lại gần như luôn có mặt + yieldScore không đo cột
  tiền. integrate-v2 đã bỏ OCRDiagnostics → mất luồng dòng sống.
- CRASH: chứng minh bằng mô phỏng Int64 hai điểm TRAP tràn số
  trong code mới (moneyToCents token 17–19 số; anchorTotals
  implied×100) + họ hàng ở validate/lastCommaMoney/qty — gương
  Python mù với lớp này. Đã loại: chỉ số mảng, regex, state 2 lần
  quét, đệ quy Reconcile (không nối). Bản vá sàn an toàn 5 điểm ở
  crashfix/ (parse ≡ trên 20 bộ đầu vào) — KHÔNG phải bản sửa
  chất lượng. Kịch bản kiểm chứng mở băng: crashfix/
  VERIFICATION-SCRIPT.md (Phần A phía đội + Phần B một phiên máy).
- L-R08 phân rã: vendor = khoảng trống từ điển (9 hãng chuỗi;
  T-Johnnys/Pan-Asia vắng — mọi đường đọc đều trống); thuế mất ký
  tự "3" ở tầng ảnh→chữ sống; Σ sống 47.87 ≠ bench 23.97.
- Toàn bộ đã chuyển làm đầu vào cho chương trình nghiên cứu sâu.

## NGHIÊN CỨU SÂU HOÀN TẤT 4/4 TUYẾN (2026-11-11 20:49 CST) — CHỜ CỔNG ANH
- Báo cáo hợp nhất: deep-study/DEEP-STUDY-REPORT.md (+ T1–T4).
  Leader kiểm số đầu: 159 giá trị tiền sống sót khớp artifact T1.
- Kết luận chính: mong manh theo PHÉP NHÂN (159/172 giá trị tiền
  về nguyên vẹn trong dòng OCR nhưng trọn sổ chỉ 5/15) — vá từng
  chỗ là thua toán học này. Xếp hạng kẻ giết: F2 engine mất 1 chữ
  số trên in nhiệt mờ → F3 ráp dòng trên ảnh cắt lát (3/3 ca lát
  đều rớt; cặp C-003/L-R10 cùng tờ: cắt→rớt, không cắt→qua) → F4
  từ điển vendor 9 chuỗi (mất tên tiệm 5/15 dù header đọc hoàn hảo)
  → F5 tầng trọng tài/đọc-lại VẮNG MẶT trong bản đã giao (Reconcile
  không nối vào parse()) biến vết thương thành mất mát vĩnh viễn.
  F6 cờ/hiển thị khoẻ nhất: 0 số sai không cờ.
- §5.5 kiểm lại: điều kiện cloud CHƯA từng kích hoạt hợp lệ — họ cổ
  điển bị bác bỏ là nút thắt bằng số (92,4% chữ đã về); họ tài liệu
  CHƯA TỪNG ĐƯỢC ĐO CÔ LẬP (chỉ xuất hiện trong bản gộp phá hoại).
  Nghiên cứu KHÔNG trình ngoại lệ cloud; T3 có thiết kế phép đo cô
  lập engine. Đính chính T2: enhancedImageOfPage KHÔNG tồn tại
  trong API công khai — chỉ imageOfPage; tăng cường phải tự sinh.
- T3: 7 nguyên tắc bất biến + kiến trúc 6 tầng + máy kiểm chứng
  khép kín (chẩn đoán bắt buộc trong app chính; corpus sinh từ
  chính đường app chính; một module đọc duy nhất dùng chung).
- Bước tiếp theo theo L-9: anh duyệt hướng ở cổng nghiên cứu →
  thiết kế chi tiết → xây. Chưa duyệt = chưa thiết kế.

## ANH DUYỆT HƯỚNG NGHIÊN CỨU (2026-11-11 21:02 CST)
- Sau khi em trình bày thêm theo yêu cầu của anh (21:01 "Chưa duyệt
  — em cần trình bày thêm"), anh bấm duyệt: "Duyệt hướng — đi tiếp
  thiết kế chi tiết cốt lõi mới".
- Bước hiện tại: THIẾT KẾ CHI TIẾT cốt lõi mới (theo T3) — trình
  anh qua cổng thiết kế trước khi xây bất cứ thứ gì. Đóng băng
  giao bản vẫn nguyên hiệu lực.

## LỆNH 21:05 CST 2026-11-11 — MỔ XẺ APP KHÁC + CỔNG CỐT LÕI 100/100
- Mở nghiên cứu mổ xẻ phương pháp của các app/sản phẩm quét hoá
  đơn & tài liệu khác (kỹ thuật, không phải bảng tính năng) làm
  đầu vào bắt buộc trước khi phác lại sơ đồ; gói thiết kế chi tiết
  đang chạy được lệnh chờ tích hợp, không chốt thiết kế trước
  nghiên cứu này.
- Chuẩn cốt lõi mới: 100% trên 100 lần thử thành công mới tính
  giai đoạn 2 (L-2026-11-11-10). Định nghĩa lần thử/thành công sẽ
  đặc tả trong thiết kế, qua cổng của anh.

## BẢN THẢO THIẾT KẾ CHI TIẾT XONG — PARK CHỜ DISSECTION (2026-11-11 21:09 CST)
- core-v3-design/DESIGN-DETAIL.md (994 dòng, 10 chương). Đúng kỷ
  luật L-10: miền không phụ thuộc đã đặc tả đầy đủ (module đọc duy
  nhất liên kết cùng nguồn cho app chính + BenchShell +
  ReplayHarness; KHÔNG đổi model SwiftData; chẩn đoán schema v2
  lưu toàn bộ mảnh; SafeMoney), miền tầng đọc để MỞ theo mã OPEN-*
  chờ DISSECTION.
- Đặc tả ĐỀ XUẤT cổng 100/100 (GATE100-v1, chưa chốt): một lần thử
  = một lần đọc trọn vẹn hoá đơn thật qua đường production trên
  thiết bị; thành công = trọn sổ + vendor + ngày + thuế từng dòng
  + thẻ + M9=0 + không crash + chẩn đoán đủ, chấm trên kết quả máy
  trước sửa tay; cấu thành S1 15 + S2 10 + S3 50 + S4 20 + S5 5
  (cổng danh dự S-0 + L-R08 — rớt 1 rớt cả phiên); luật qua cổng:
  100/100 cho nguyên phiên, một lần thua = chạy lại trọn phiên mới.
- Chờ DISSECTION về → tích hợp OPEN-* → bản chốt trình anh ở cổng
  thiết kế lần hai. Không mở pha xây nào trước điểm tích hợp
  (ngoại lệ tối đa Pha 0–1 phần không phụ thuộc — Leader giữ chưa
  mở, chờ cổng thiết kế).

## MỔ XẺ APP KHÁC HOÀN TẤT (2026-11-11 21:17 CST) — ĐANG TÍCH HỢP VÀO THIẾT KẾ
- deep-study/DISSECTION-REPORT.md + 4 phụ lục (~1.300 dòng nguồn
  đọc trực tiếp). 4 phát hiện bao trùm: (1) ngành ĐI VÒNG QUA F2 —
  không ai cứu chữ số phai ở mức engine; thắng lợi nằm ở chụp tốt
  (F1) + hậu kiểm số học (F5); (2) ranh giới on-device của cả
  ngành nằm GIỮA pipeline — trích xuất trường ngữ nghĩa tổng quát
  không hãng nào công bố chạy on-device; F4 của ta chỉ có nguyên
  lý để học, không có sản phẩm để bắt chước; (3) mọi số 95–99%
  bên ngoài đều kèm điều kiện đầu vào đã chuẩn hoá (cùng model:
  98,5% với chữ vàng → 38,5% với OCR thật) — phép nhân tầng là cơ
  chế phổ quát; (4) đội thắng SROIE Task 3 KHÔNG dùng deep-KIE —
  thắng bằng lexicon tự sửa + regex theo trường + ràng buộc.
- Ghi chú bắt buộc giữ nhãn: Veryfi công khai SUY subtotal =
  Total − Tax − Tip — luật không-nặn-số của dự án là ngược ngành
  CÓ CHỦ ĐÍCH (chứng cứ kế toán), phải ghi lý do vào thiết kế.
  OCR voting không phải mẫu hình của sản phẩm hoá đơn nào; đọc-
  lại-ROI là sáng tác tổng hợp của dự án — không mượn uy tín hãng.
  15 ca hiện tại = IN-SAMPLE; ca mới phải holdout trước khi dùng
  chỉnh parser.
- Đang chạy gói tích hợp DISSECTION → DESIGN-FINAL (giải quyết
  từng OPEN-*, sửa đặc tả GATE100 theo kỷ luật holdout). Xong sẽ
  trình anh ở cổng thiết kế.

## THIẾT KẾ CHỐT XONG (2026-11-11 21:21 CST) — TRÌNH CỔNG THIẾT KẾ
- core-v3-design/DESIGN-FINAL.md (773 dòng). Mọi OPEN-* đã giải
  quyết có truy vết (chốt / đo-ở-pha + căn cứ mổ xẻ).
- Tích hợp lớn: trọng tâm cứu chữ số dời F2 → F1+F5 (cổng chất
  lượng 3 quyết định + QualityMap có vị trí làm đích ROI); hoá đơn
  dài = chế độ nạp nhiều trang + ghép tầng chữ (hết bệnh cắt lát);
  nắn cong là bước riêng, xoá bóng giữ màu trước nhị phân; cấm
  phục hồi sinh-tạo trong đường đọc; DomainCorrection (chỉ sửa
  CHỮ, không chạm token số) thành tầng hạng nhất; hiến chương
  không-nặn-số ghi kèm phản ví dụ Veryfi.
- GATE100-v2 (luật 100/100 không đổi, cấu thành sửa theo kỷ luật
  in-sample): 15 ca hạt giống rời khỏi con số 100 → tiền-cổng hồi
  quy bắt buộc 15/15; 100 lần đếm = S1 quét hạt giống 10 + S2 ca
  MỚI NIÊM PHONG 50 + S3 lặp chụp 20 + S4 cổng danh dự 5 + S5
  HOLDOUT THUẦN 15 (chọn sau khi build đóng băng). Một phiên = 115
  lần đọc; rớt 1 lần đếm = rớt cả phiên, chạy lại trọn phiên.
- 7 quyết định trình cổng (D1–D7) — D6 cần anh cam kết nguồn cung
  hoá đơn niêm phong (≥25 tờ trước đóng băng + ≥15 tờ sau).

## ANH DUYỆT THIẾT KẾ CHỐT + CẢ 7 QUYẾT ĐỊNH (2026-11-11 21:44 CST)
- Cổng thiết kế ĐÃ QUA: DESIGN-FINAL thành đặc tả thi hành;
  D1–D7 chốt theo khuyến nghị (gồm GATE100-v2; D6 = anh cam kết
  nguồn hoá đơn niêm phong ≥25 tờ trước đóng băng + ≥15 tờ sau;
  D5 hiến chương không-nặn-số + DomainCorrection chỉ sửa chữ;
  D7 luật §5.5 giữ nguyên).
- Bắt đầu XÂY PHA 0: máy kiểm chứng + sàn an toàn trước mọi tầng
  đọc (SafeMoney, chẩn đoán schema v2, ReplayHarness, cổng ngữ
  nghĩa nền tảng). Các pha sau theo §7 của thiết kế; phiên cổng
  100/100 là điểm cuối của lộ trình cốt lõi.

## PHA 0 XONG Ở STAGING (2026-11-11 21:55 CST) — LEADER TỰ CHẠY LẠI XANH TOÀN BỘ
- v3-phase0/: Money.swift (gương 15/15; ≡ crashfix trên 28 token
  thật), ReadDiagnostics.swift v2 (gương 5/5 gồm mô phỏng lỗi ghi
  — fail-closed chạy đúng), ReplayHarness (48/48 trên 3 bản ghi;
  bản ghi chuyển đổi từ luồng 001 tái lập đúng mọi số đóng băng),
  platform_gate 17/17. Leader tự chạy lại cả 4 bộ: PASS toàn bộ.
- Cổng tự bắt được 1 lỗi thật: luật extent thuần của sàn crashfix
  CHO QUA tứ giác nơ-bướm tự cắt (ảnh nắn bị gấp mà extent vẫn hữu
  hạn) — luật đầy đủ (tứ giác đơn + extent) đã đặc tả, Pha 2 kế
  thừa bắt buộc.
- Điều kiện treo (đã có cách khép, không chặn Pha 1 ngoại tuyến):
  C1 in ngôn ngữ trên thiết bị (probe đã sẵn); C2 biên dịch Swift
  thật trên CI (khép ở lần đẩy v3 đầu tiên); C3 nối chẩn đoán vào
  app chính (Pha 4); C4 replay toàn baseline (cần F4 thật — Pha 1).
- PHA 1 bắt đầu: tầng phân tích F4 trên luồng chữ theo DESIGN-FINAL.

## PHA 1 XONG Ở MỨC GƯƠNG + KIỂM TĨNH (2026-11-11 22:25 CST)
- F4 v3 (v3-phase1/): trọn sổ IN-SAMPLE 5/15 → 7/15 (L-R 5/11 →
  6/11; +L-R04 nhờ luật in Walmart E3 thành dữ liệu, +N-002);
  0 ca thụt lùi; phủ vendor 15/15 (nền 10/15); M9=0; Domain
  Correction 4/4 đúng 0 oan; 8 lỗi F4 tự bắt + sửa trong pha, mỗi
  lỗi có fixture. Leader tự chạy lại test_f4.py: exit 0, cổng A–G
  PASS; kiểm tĩnh Swift ALL PASS.
- Ca còn rớt đều phân tầng có bằng chứng: F2 chữ chết (L-R05/08/09
  + subtotal-in-sai L-R03 + token đếm mất L-R06) chờ F5 ở Pha 3;
  F3 ráp dòng (S-0/N-001/C-003) chờ Pha 2. Hình học nhãn–tiền đã
  xây, kiểm không-hại 15/15, chưa có ca nào để trọng tài kích hoạt
  — không tuyên bố quá mức.
- SỰ KIỆN ĐIỀU KIỆN DỪNG §7: replay L-R10 rớt → cổng replay đạt
  6/7. Truy tới số: khung ráp F3 của Pha 0 gộp hàng với dung sai
  0.0179 trong khi hộp thật của L-R10 cách 0.0135–0.0176 → 25 dòng
  bị gộp thành 18, giết cả hai neo tổng. Lệch 100% ở tham số F3
  skeleton, không ở F4 (cô lập: hộp không chồng → 25/25, parse
  trọn). Xử lý đúng luật: KHÔNG sửa Pha 0, KHÔNG chạy lại bằng hộp
  thay thế để nhận "qua" — bàn giao Pha 2 kèm file chẩn đoán +
  yêu cầu đo luật hàng §3.3 trên chính các hộp chồng này (C4 đóng
  6/7, L-R10 mang sang Pha 2).
- Treo cũ: Swift chưa biên dịch thật (C2 — lần đẩy v3 đầu tiên);
  1 phép nhân thô còn trong khối Reconcile giữ-nguyên-văn (gia cố
  khi tách module ở Pha 3); validate chưa có cơ chế cờ cho giá trị
  thẻ bất thường (L-R09 "2580" đi qua không cờ — xét Pha 3/4).
- PHA 2 bắt đầu: F1 capture/hình học + F2 adapter engine + F3 ráp
  dòng với luật hàng đo trên hộp chồng L-R10.

## PHA 2 XONG Ở MỨC GƯƠNG (2026-11-11 22:42 CST) — C4 ĐÃ ĐÓNG 7/7
- F3 ráp dòng mới: replay toàn baseline 7/7 qua khung mới (L-R10
  trọn 9691/[825]/10516). Hiệu chuẩn trên hộp chồng thật của
  L-R10: khung xương Pha 0 ra 18/25 dòng → luật bắt đầu của thiết
  kế 21/25 → luật đầy đủ Pha 2 (cộng tương thích ngang: hai mảnh
  chồng theo cột là hai dòng in xếp chồng) 25/25. Leader tự chạy
  lại test_f3 + replay_f3 + test_capture_engine: QUA toàn bộ.
- Gộp xuyên-lượt bị kết tội bằng số ngay trong F3: cho ăn mảnh của
  nhiều lượt đọc, số dòng phình 104→66 so với thật 38 (N-001) —
  F3 chỉ ráp mảnh của MỘT lượt, bất biến chống nhân đôi = 0 ngay
  cả khi cho ăn sai phạm vi.
- Thi đấu chính sách lát: KHÔNG đo được ngoại tuyến (JSON buổi đo
  không ghi hình học lát — lỗ hổng chẩn đoán v2 lấp bằng tileMap)
  → dời nguyên vẹn vào giao thức đo thiết bị M-4. Ghép trang mô
  phỏng trên mảnh thật L-R07: khôi phục tỉ lệ 0.621 (thật 0.620),
  48/48 dòng, 0 token nhân đôi; không vùng chồng → cờ fail-closed.
- F1/F2 ở mức hàm: cổng tứ giác đầy đủ; cổng chất lượng 3 quyết
  định (chặn mặc định TẮT, fail-safe sau 3 lần từ chối); hàm chọn
  ứng viên mới qua ca rác 16:19 (ứng viên "nhiều chữ vỡ tiền" thua
  bản đọc khép sổ); F2 ghim Rev3 + giữ top-3 biến thể. Phần đo
  thiết bị (M-1 in ngôn ngữ → M-7 đóng gói phiên) đã có giao thức
  sẵn sàng: v3-phase2/MEASUREMENT-PROTOCOL.md.
- Treo: C2 biên dịch Swift thật (lần đẩy v3 đầu tiên); ngưỡng cổng
  chất lượng đang là mặc định giữ chỗ, hiệu chuẩn ở M-5.
- PHA 3 bắt đầu: nối trọng tài F5 vào parse + ROI + kênh CANDIDATE
  (oracle@3 đo ngoại tuyến từ JSON buổi đo) + gia cố phép nhân thô
  cuối cùng trong khối Reconcile.

## CA TRỰC 22:40 CST 2026-11-11 — KIỂM CHÉO ĐỘC LẬP PHA 2
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC — WORK-STATE ghi
  rõ anh duyệt hướng 21:02 + duyệt thiết kế chốt D1–D7 21:44.
  Ca không thiết kế/code mới, không làm trùng Pha 3 đang ở nhịp
  chat chính/đội xây.
- Leader ca trực tự chạy lại CẢ 4 bộ kiểm Pha 2 tại bàn
  (test_f3.py · test_capture_engine.py · replay_f3.py ·
  swift_static_check_p2.py): exit 0 cả 4; kết quả BYTE-TRÙNG
  từng file output đã lưu trong v3-phase2/ (test-f3-output.txt ·
  test-capture-engine-output.txt · replay-output.txt ·
  swift-static-output.txt); kiểm tĩnh đúng 83 mục PASS như
  AFTER.md tuyên bố; C4 7/7 tái lập. Số liệu Pha 2 trong mục
  22:42 ở trên vì vậy đã qua kiểm chéo độc lập của ca trực.
- Bước tiếp theo giữ nguyên: PHA 3 (nhịp chat chính). Treo cũ
  không đổi: C1 in ngôn ngữ + C2 biên dịch Swift thật.

## PHA 3 XONG Ở MỨC GƯƠNG (2026-11-11 23:03 CST)
- Reconcile tách module + gia cố SafeMoney toàn bộ: 13/13 ca tổng
  hợp PASS lại, vi sai 3 chiều trùng cả số nút DFS; bẫy Int64 cũ
  bẫy thật, đường mới từ chối sạch. ReadPipeline nối F3→F4→
  Reconcile→ROI. Cờ thẻ đóng (L-R09 "2580" → cờ mạnh; 2 ca cờ oan
  đã đăng ký là chi phí đã biết).
- KÊNH CANDIDATE: oracle@3 = 0/7 token — file buổi đo chỉ ghi ĐÚNG
  1 candidate cho mọi dòng tranh chấp, biến thể đúng không tồn
  tại trong dữ liệu đã ghi. Kênh giữ tầng gợi ý; chỉ xét lại bằng
  đo thiết bị với topCandidates(3) bảo đảm. (Bài học dữ liệu: bản
  ghi bench mỏng hơn thiết kế giả định.)
- F5 TRÊN 15 CA THẬT: can thiệp áp = 0, can thiệp SAI = 0 → cổng
  cứng §7 QUA (không lùi chỉ-gợi-ý). Đọc đúng nghĩa: trọng tài TỪ
  CHỐI áp trên các ca thật gãy (ANCHOR_CONFLICT/NO_SOLUTION/
  TOTAL_ONLY) vì không có nghiệm duy nhất kèm bằng chứng tại chỗ —
  năng lực sửa đúng mới chứng minh trên ca tổng hợp. Hệ quả cho
  GATE100: các ca chữ-số-chết KHÔNG được F5 cứu trên luồng kiểu
  này; đường cứu nằm ở ROI trên ảnh thật (thiết bị) + capture.
- Leader đã tự chạy lại test_f5_corpus + test_reconcile13: khớp.
- AMD-001 (Leader chốt): nới vùng ROI thống nhất ±50% mỗi phía
  theo RECONCILE §6 (thay ×1.5 của DESIGN-FINAL) — ghi tại
  core-v3-design/AMENDMENTS.md; Pha 4 thi hành + fixture.
- PHA 4 bắt đầu: lắp ráp toàn bộ module vào hình hài app chính +
  BenchShell dùng chung nguồn + chuẩn bị đẩy nhánh v3 lên CI
  (đóng C2 biên dịch Swift thật).
- ĐẨY CUỐI CA 22:40: THÀNH CÔNG — đúng 1 lần, 1 file (WORK-STATE.md), commit docs/planning: `304c1c90443ba4f55283c7169284454be80c293d`. (Dòng này chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## PHA 4 LẮP RÁP XONG (2026-11-11 23:22 CST) — CHỜ TRÌNH ĐẨY NHÁNH v3
- v3-phase4/: bộ nguồn app v3 hoàn chỉnh (19 Swift + vendors/
  lexicon JSON + project.yml 2 target + 33 ảnh bench). Models
  .swift trùng byte với main. Toàn bộ bộ kiểm Pha 0–3 chạy lại
  trên nguồn đã lắp: KẾT QUẢ ≡ từng pha (trọn sổ 7/15, vendor
  15/15, C4 7/7, reconcile 13/13, F5 0 can thiệp, oracle 0/7).
  Kiểm tĩnh Pha 4 PASS toàn bộ (ReadPipeline là đường đọc duy
  nhất từ UI; không phép tính tiền trần ngoài SafeMoney).
- AMD-001 đã thi hành (RegionReReader hệ số 2.0, fixture PASS).
- Lắp ráp tự bắt 2 lỗi loại biên-dịch-thật mà gương/lexer mọi pha
  đều mù: P4-D1 (gán Int vào Double — CI chắc chắn rớt) và P4-D4
  (Parser lén phụ thuộc formatMoney của tầng app — BenchShell chỉ
  -module sẽ gãy). Bằng chứng sống cho giá trị của bước CI.
- PUSH-MANIFEST sẵn sàng: 16 file chữ qua connector + 34 file qua
  trình duyệt (workflow + 33 JPG) lên nhánh `v3` MỚI (không đụng
  main, không đụng app đang chạy của anh). Run CI đầu tiên đóng
  C2 (biên dịch Swift thật); lỗi sót (nếu còn) sửa theo log trên
  nhánh v3. Đang trình anh duyệt đẩy.

## NHÁNH v3 ĐÃ ĐẨY + CI RUN ĐẦU (2026-11-11 23:25–23:32 CST)
- Đẩy đủ theo PUSH-MANIFEST (anh duyệt 23:23): nguồn be4e9073
  (17 file, connector) + workflow 165f035 + ảnh 87c8871/001d47b/
  0d2639a (33/33) qua trình duyệt. Main không bị đụng.
- Run #35–#38 đều rớt; run #38 (HEAD 0d2639a) đọc log tận nơi:
  bước "Build main app" rớt bởi ĐÚNG MỘT lỗi — Parser.swift:2128
  chứa byte điều khiển 0x08 (backspace thật) ngay trong regex cân
  nặng, ở chỗ gương Python có `\b` in được. Quét toàn bộ nguồn
  lắp ráp: đó là byte điều khiển DUY NHẤT. Đã sửa ở cả bản lắp
  ráp Pha 4 lẫn nguồn Pha 1 (thay bằng `\b` hai ký tự) và đẩy lên
  v3: commit 0ac6406 (thẻ duyệt của anh). Đang chờ run kế tiếp
  phán quyết — C2 chưa đóng cho tới khi có run XANH.

## CI RUN #39 (2026-11-11 23:50 CST) — LỚP LỖI ĐƯỜNG NỐI
- Run #39 (0ac6406): lỗi 0x08 ĐÃ HẾT; compiler đi tiếp và phơi
  13 lỗi thuộc họ đường-nối-giữa-các-pha ở bước Build main app:
  2 khai báo trùng TRONG cùng file Parser (hasAlphaToken,
  samelineExcludeContains — kiểm tĩnh cũ chỉ soi trùng XUYÊN
  file), 3 điểm gọi thừa đối số 'confidence' (lệch chữ ký findCard
  của việc cờ thẻ), các lời gọi Vision lệch nhãn cgImage:/thiếu
  try (vùng CONFIRM-AT-COMPILE), 1 thứ tự đối số, 1 gán Double→Int
  thứ hai cùng họ P4-D1, 1 nhãn 'lines:' thừa ở ReadPipeline.
- Gói CI-FIX-1 đang sửa trong staging v3-phase4/app: luật cứng —
  helper trùng phải đối chiếu thân hàm + gương trước khi xoá
  (khác nhau thì chọn theo hành vi đã kiểm chứng, cấm hợp nhất
  bừa); chạy lại toàn bộ bộ kiểm sau sửa phải ≡; bổ sung 2 kiểm
  tĩnh mới (trùng trong-file + quét byte điều khiển) và phải chứng
  minh bắt được lỗi cũ. Leader đẩy bản sửa khi gói xong.

## CI RUN #40 + CI-FIX-2 (2026-11-12 00:30 CST)
- Run #40 (e853f12): còn ĐÚNG MỘT lỗi biên dịch — OCREngine.swift
  :198: adapter họ documents bắc cầu RecognizeDocumentsRequest
  (Swift-native, async perform(on:) theo T2 §2) qua
  VNImageRequestHandler.perform([VNRequest]) — không hợp lệ theo
  kiểu. Đây là khung đo Pha 2 để trống ĐIỂM CHUYỂN ĐỔI có chủ
  đích; lỗi nằm ở câu bắc cầu, không phải ý đồ.
- CI-FIX-2 (Leader tự sửa, điểm duy nhất): adapter fail-closed
  bằng lỗi tường minh OCREngineError.documentsAdapterNotWired
  (BenchView đã bọc do/catch và in trung thực trạng thái khung);
  sửa đồng bộ vào nguồn gốc Pha 2; kiểm tĩnh P4+P5 PASS, byte
  điều khiển = 0. Đẩy v3 commit 399f67a. Đang chờ run phán quyết.

## CA TRỰC 00:40 CST 2026-11-12 — PHÁN QUYẾT RUN #41: APP CHÍNH ĐÃ BIÊN DỊCH XANH, BENCH CÒN ĐÚNG 2 LỖI
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (như ca 22:40 đã
  ghi) — file này ghi rõ anh duyệt hướng 21:02 + duyệt thiết
  kế chốt D1–D7 21:44. Ca làm đúng MỘT bước trong hàng việc:
  lấy phán quyết run cho commit 399f67a đang chờ ở mục trên.
  Ca không sửa code, không đẩy code v3, không làm trùng gói
  CI-FIX tiếp theo đang ở nhịp chat chính/Leader.
- Kiểm từ xa trước khi đọc Actions (connector GitHub, trong
  ca này): đầu nhánh v3 = đúng commit
  `399f67a0cd373118585c05ea80b80089e931a7c9` (2026-11-12T06:30:56Z
  = 00:30:56 CST, thông điệp CI-FIX-2) — không có commit nào
  sau nó.
- Run #41 (đọc trực tiếp GitHub Actions qua trình duyệt có
  phiên của anh, 00:41–00:45 CST; run: https://github.com/
  zjoenguyenz/Sohoadon/actions/runs/43168679392): completed /
  failure, chạy 1m 5s trên macos-26, Xcode 26.3, SDK
  iphoneos26.2, build đúng commit 399f67a. Các bước setup /
  XcodeGen / chọn Xcode ĐỀU QUA. **Build main app (scheme
  SoHoaDon) QUA — lần đầu tiên app chính biên dịch xanh trên
  CI; 0 lỗi biên dịch ở bước này.** C2 vì vậy ĐÃ ĐÓNG ở phía
  app chính.
- Build bench app (scheme SoHoaDonBench) RỚT, exit 65, đúng
  **2 lỗi biên dịch**, cả hai ở BenchView.swift — chính là 2
  lời gọi giữ nhãn CONFIRM-AT-COMPILE mà CI-FIX-1/HONESTY đã
  khai chờ compiler phán: (1) dòng 208:38 — `instance member
  'supportedRecognitionLanguages' cannot be used on type
  'RecognizeDocumentsRequest'`; (2) dòng 210:39 — lỗi y hệt
  trên `RecognizeTextRequest`. Compiler đã phán: thuộc tính
  này là instance member, KHÔNG phải type member — cách gọi
  `.supportedRecognitionLanguages` trên chính kiểu là sai.
  Tìm `error:` toàn log chỉ có 2 lỗi này (+1 dòng liệt kê
  destination không phải lỗi). Các warning deprecated
  (VNRecognizeTextRequestRevision1/2, supportedRecognition
  Languages(for:revision:) ở BenchView 191/198 + OCREngine
  111/188) KHÔNG phải nguyên nhân rớt.
- Đối chiếu tại bàn (ca tự đọc trực tiếp): v3-phase4/app/
  BenchView.swift dòng 208–211 khớp từng ký tự 2 điểm lỗi
  (docLangs ở 208–209, textLangs ở 210–211, trong
  printLanguages(), khối #available(iOS 26.0, *)).
- Hệ quả run: Package + Upload 2 artifact đều SKIPPED —
  **run #41 KHÔNG có artifact/IPA nào**; không có gì để kêu
  anh tải/cài (đúng luật: chưa xanh trọn = chưa giao).
- Tuyên bố trung thực — đã chứng minh: trạng thái đầu nhánh
  v3 + phán quyết run #41 từng bước/lỗi bằng đọc trực tiếp
  (connector + Actions) và khớp code tại bàn 208–211; chưa
  chứng minh: bản sửa cho 2 điểm này CHƯA tồn tại — compiler
  mới chỉ phán cách gọi hiện tại sai, hướng sửa (tạo instance
  trước khi đọc thuộc tính, hoặc in fail-closed trung thực
  như tiền lệ CI-FIX-2 cho phần probe) phải qua kiểm tĩnh +
  chạy lại bộ kiểm Pha 0–4 ≡ trước khi đẩy, ca này chưa làm;
  C2 phía BenchShell CHƯA đóng (chỉ đóng khi một run xanh
  trọn cả 2 scheme); chưa làm: chưa đụng Swift nào, chưa
  chuẩn bị bản giao nào — đóng băng giao bản vẫn nguyên.
- **Bước tiếp theo: CI-FIX-3 ở nhịp chat chính/Leader** — sửa
  đúng 2 lời gọi probe ở BenchView.swift:208/210 (điểm duy
  nhất), chạy lại toàn bộ bộ kiểm + kiểm tĩnh P4/P5 phải ≡,
  đẩy v3, chờ run kế tiếp phán quyết. Rớt 1 scheme là C2
  chưa đóng; không kêu anh cài/test gì.
- ĐẨY CUỐI CA 00:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `ce6f6dccfc902a1f3df301a94dc639fcaf047a55`. (Dòng này chỉ
  có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## CA TRỰC 02:40 CST 2026-11-12 — KIỂM CHÉO ĐỘC LẬP CI-FIX-3 TẠI BÀN: ĐÚNG PHẠM VI, KIỂM TĨNH XANH, CHƯA ĐẨY
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (như ca 22:40 +
  00:40 đã ghi). Ca làm đúng MỘT bước: kiểm chéo độc lập bản
  sửa CI-FIX-3 đã xuất hiện tại bàn lúc 00:49 CST (sau mục
  00:40) trước khi Leader đẩy — ca không sửa code, không đẩy
  code v3, không làm trùng nhịp chat chính.
- Trạng thái từ xa (connector GitHub, trong ca này): đầu
  nhánh v3 VẪN là `399f67a0cd373118585c05ea80b80089e931a7c9`
  (CI-FIX-2) — CI-FIX-3 CHƯA đẩy, chưa có run mới. (Lưu ý kỹ
  thuật: list_commits phải truyền nhánh qua tham số `sha`;
  truyền `branch` bị bỏ qua và trả nhánh mặc định.)
- Diff phạm vi (bằng chứng sơ cấp): tải BenchView.swift trên
  v3 qua connector — blob SHA tự tính từ nội dung tải về
  `882d8af87f2ea8349260bc335ee75fd38390902b` KHỚP SHA
  connector báo. Diff với bản tại bàn: CHỈ đúng điểm
  CI-FIX-3 — dòng 208 `RecognizeDocumentsRequest` →
  `RecognizeDocumentsRequest()` và dòng 210
  `RecognizeTextRequest` → `RecognizeTextRequest()` (đọc
  thuộc tính trên INSTANCE thay vì trên kiểu, đúng phán
  quyết compiler run #41) + 3 dòng chú thích; toàn file
  không khác chỗ nào nữa.
- Tiền lệ biên dịch được: benchapp/BenchRunner.swift:60-61
  (đã build xanh ở các run bench #32/#33) dùng đúng mẫu
  `RecognizeDocumentsRequest().supportedRecognitionLanguages`
  cho họ documents. Họ TextRequest chưa có tiền lệ instance
  riêng tại bàn — compiler run #41 tự chỉ hướng instance,
  phán quyết cuối vẫn là run CI xanh trọn.
- Bộ kiểm ca tự chạy lại trên bộ nguồn đã lắp (app/):
  static_check_p4 PASS TOÀN BỘ (exit 0) · static_check_p5:
  S8 PASS 19 file Swift (0 trùng trong-type), S9 byte điều
  khiển = 0 trên 22 file nguồn, PASS · fixture AMD-001 PASS
  8 nhóm. Hồi quy Pha 0–3: Pha 0 cả 5 bộ exit 0 BYTE-TRÙNG
  file đã lưu · Pha 1 test_f4 exit 0 toàn PASS (chênh byte
  duy nhất ở dòng 157 = thứ tự in của tập hợp Python, nội
  dung 4 sửa y hệt) + kiểm tĩnh P1 ALL PASS byte-trùng ·
  Pha 2 test_f3/test_capture_engine/replay_f3 (C4 7/7) đều
  exit 0 byte-trùng · Pha 3 reconcile 13/13 + F5 corpus +
  hardening + tĩnh P3 đều PASS exit 0. replay_f4 (Pha 1)
  exit 1 nhưng BYTE-TRÙNG file đã lưu — đó là sổ §7 cũ
  (L-R10 6/7 thời Pha 1, đã được replay_f3 Pha 2 đóng 7/7),
  không phải thụt lùi mới.
- PHÁT HIỆN LỆCH CŨ (không thuộc CI-FIX-3, ca không tự sửa):
  swift_static_check_p2 nay FAIL đúng 1/84 mục —
  "OCREngine.swift có 'TODO(PHA-3)'": CI-FIX-2 đã thay thân
  adapter bằng throw `documentsAdapterNotWired` và đồng bộ
  về nguồn Pha 2, xoá luôn chuỗi TODO(PHA-3) mà kiểm tĩnh
  Pha 2 còn kỳ vọng tồn tại; diff đầu ra so với file đã lưu
  chỉ khác đúng 2 dòng (mục đó + dòng kết luận). Hệ quả:
  câu "toàn bộ bộ kiểm ≡" cho lần đẩy CI-FIX-3 phải ghi
  ngoại lệ này, hoặc Leader cập nhật kỳ vọng kiểm tĩnh P2
  (TODO(PHA-3) → documentsAdapterNotWired) ở nhịp chat
  chính trước khi tuyên bố ≡ toàn bộ.
- Tuyên bố trung thực — đã chứng minh: phạm vi diff
  CI-FIX-3 + trạng thái từ xa + kết quả mọi bộ kiểm kể trên
  bằng chạy thật/đọc trực tiếp trong ca; chưa chứng minh:
  CI-FIX-3 CHƯA biên dịch thật ở đâu cả (không swiftc tại
  bàn) — C2 phía BenchShell chỉ đóng khi một run CI xanh
  trọn cả 2 scheme; chưa làm: chưa đẩy v3, chưa chuẩn bị
  bản giao nào — đóng băng giao bản vẫn nguyên.
- **Bước tiếp theo giữ nguyên: CI-FIX-3 ở nhịp chat
  chính/Leader** — đẩy BenchView.swift đã kiểm chéo này lên
  v3 (kèm quyết về kỳ vọng kiểm tĩnh P2 ở mục phát hiện
  trên), chờ run kế tiếp phán quyết. Không kêu anh cài/test
  gì.

## CA TRỰC 04:40 CST 2026-11-12 — KIỂM CHỨNG LẠI LỆCH KIỂM TĨNH P2 + XÁC NHẬN CI-FIX-3 VẪN CHƯA ĐẨY
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (file này ghi
  rõ anh duyệt hướng 21:02 + duyệt thiết kế chốt D1–D7
  21:44 ngày 2026-11-11) — thân lệnh ca này ghi điều kiện
  cổng tự hết khi WORK-STATE đã ghi duyệt, nên ca quay lại
  luật chung, làm đúng MỘT bước độc lập trong lúc chờ nhịp
  chat chính: kiểm chứng lại bằng bằng chứng sơ cấp điểm
  lệch kiểm tĩnh P2 mà ca 02:40 đã phát hiện. Ca không sửa
  code, không sửa script kiểm, không đẩy code v3.
- Trạng thái từ xa (connector GitHub, trong ca này): đầu
  nhánh v3 VẪN là `399f67a0cd373118585c05ea80b80089e931a7c9`
  (CI-FIX-2, 2026-11-12T06:30:56Z) — CI-FIX-3 CHƯA đẩy,
  chưa có run CI mới. Tại bàn, BenchView.swift vẫn giữ
  đúng sửa CI-FIX-3: `RecognizeDocumentsRequest()` (1 hit)
  + `RecognizeTextRequest()` (1 hit) ở dòng 211–214.
- Kiểm tĩnh P2 chạy lại tại bàn (v3-phase2/
  swift_static_check_p2.py): exit 1 — đếm theo dòng bắt
  đầu [PASS]/[FAIL] trong đầu ra: **81 PASS / 1 FAIL /
  82 mục** (ca 02:40 ghi "1/84" — số đếm của ca này theo
  đầu ra thật là 82 mục; nội dung lệch không đổi). FAIL
  duy nhất: "OCREngine.swift có 'TODO(PHA-3)'". Diff đầu
  ra so với swift-static-output.txt đã lưu: ĐÚNG 2 dòng
  (dòng 58 PASS→FAIL của mục đó + dòng kết luận ALL PASS
  → FAIL).
- Nguyên nhân đã đọc trực tiếp: script dòng 193 còn kỳ
  vọng chuỗi `TODO(PHA-3)` trong OCREngine.swift, trong
  khi OCREngine.swift Pha 2 dòng 195 nay là
  `throw OCREngineError.documentsAdapterNotWired` kèm
  chú thích CI-FIX-2 (dòng 191–194) — kỳ vọng kiểm tĩnh
  đã CŨ so với sửa fail-closed đã duyệt/đã đẩy ở CI-FIX-2,
  không phải thụt lùi code mới và không thuộc CI-FIX-3.
- Tuyên bố trung thực — đã chứng minh: trạng thái đầu
  nhánh v3 + nội dung BenchView tại bàn + kết quả/diff
  kiểm tĩnh P2 kể trên, bằng đọc trực tiếp + chạy thật
  trong ca; chưa chứng minh: CI-FIX-3 vẫn CHƯA biên dịch
  thật — C2 phía BenchShell chỉ đóng khi một run CI xanh
  trọn cả 2 scheme; chưa làm: chưa cập nhật kỳ vọng kiểm
  tĩnh P2 (quyết thuộc Leader ở nhịp chat chính: đổi kỳ
  vọng TODO(PHA-3) → documentsAdapterNotWired, hoặc ghi
  ngoại lệ tường minh khi tuyên bố ≡), chưa đẩy v3,
  chưa chuẩn bị bản giao nào — đóng băng giao bản vẫn
  nguyên.
- **Bước tiếp theo giữ nguyên: CI-FIX-3 ở nhịp chat
  chính/Leader** — quyết kỳ vọng kiểm tĩnh P2 theo mục
  trên, đẩy BenchView.swift đã kiểm chéo lên v3, chờ run
  kế tiếp phán quyết. Không kêu anh cài/test gì.

## CA TRỰC 06:40 CST 2026-11-12 — XÁC NHẬN CI-FIX-3 VẪN CHƯA ĐẨY, TRẠNG THÁI CHỜ KHÔNG ĐỔI
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (file này ghi
  rõ anh duyệt hướng 21:02 + duyệt thiết kế chốt D1–D7
  21:44 ngày 2026-11-11) — thân lệnh ca này ghi điều kiện
  cổng tự hết khi WORK-STATE đã ghi duyệt, nên ca quay lại
  luật chung, làm đúng MỘT bước: kiểm tra trạng thái từ xa
  của bước tiếp theo đang chờ (CI-FIX-3). Ca không sửa code,
  không đẩy code v3, không làm trùng nhịp chat chính/Leader.
- Trạng thái từ xa (connector GitHub, trong ca này): đầu
  nhánh v3 VẪN là `399f67a0cd373118585c05ea80b80089e931a7c9`
  (CI-FIX-2, 2026-11-12T06:30:56Z) — giống hệt ca 02:40 và
  04:40. CI-FIX-3 CHƯA đẩy, chưa có run CI mới, chưa có
  phán quyết nào mới cho 2 lỗi BenchView của run #41.
- Tại bàn: BenchView.swift vẫn giữ đúng sửa CI-FIX-3 —
  `RecognizeDocumentsRequest()` ở dòng 211 và
  `RecognizeTextRequest()` ở dòng 213 (grep trực tiếp
  trong ca này).
- Tuyên bố trung thực — đã chứng minh: trạng thái đầu
  nhánh v3 + nội dung BenchView tại bàn kể trên, bằng đọc
  trực tiếp GitHub + grep trong ca; chưa chứng minh:
  CI-FIX-3 vẫn CHƯA biên dịch thật — C2 phía BenchShell
  chỉ đóng khi một run CI xanh trọn cả 2 scheme; chưa
  làm: chưa quyết kỳ vọng kiểm tĩnh P2 (TODO(PHA-3) →
  documentsAdapterNotWired — quyết thuộc Leader), chưa
  đẩy v3, chưa chuẩn bị bản giao nào — đóng băng giao
  bản vẫn nguyên.
- **Bước tiếp theo giữ nguyên: CI-FIX-3 ở nhịp chat
  chính/Leader** — quyết kỳ vọng kiểm tĩnh P2, đẩy
  BenchView.swift đã kiểm chéo lên v3, chờ run kế tiếp
  phán quyết. Không kêu anh cài/test gì. Đây là ca thứ 3
  liên tiếp cùng một điểm chờ (02:40 / 04:40 / 06:40) —
  ghi nhận để chat chính xử lý, ca trực không tự đẩy
  code v3 theo luật ca.
- ĐẨY CUỐI CA 06:40: **KHÔNG XÁC ĐỊNH / CHƯA LÊN** — đã thử
  đẩy docs/planning ĐÚNG 1 LẦN (1 file: WORK-STATE.md) —
  lần đẩy bị gián đoạn do dịch vụ khởi động lại giữa chừng.
  Kiểm từ xa ngay sau đó trong cùng ca (chỉ đọc): đầu nhánh
  docs/planning VẪN là `ce6f6dccfc902a1f3df301a94dc639fcaf047a55`
  (commit ca 00:40) — lần đẩy 06:40 chưa lên tại thời điểm
  kiểm. Theo luật chống treo: KHÔNG thử lại trong cùng ca;
  ca sau kiểm từ xa lại trước khi đẩy bù, không đẩy mù.
  CHỜ DUYỆT ĐẨY: WORK-STATE.md (gồm các mục 02:40, 04:40,
  06:40 chưa lên nhánh).

## CA TRỰC 08:40 CST 2026-11-12 — XÁC NHẬN LẦN 4: CI-FIX-3 VẪN CHƯA ĐẨY; LẦN ĐẨY 06:40 XÁC NHẬN CHƯA LÊN
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (file này ghi
  rõ anh duyệt hướng 21:02 + duyệt thiết kế chốt D1–D7
  21:44 ngày 2026-11-11) — ca quay lại luật chung, làm đúng
  MỘT bước: kiểm chứng từ xa hai điểm chờ đang mở (CI-FIX-3
  + lần đẩy mơ hồ 06:40). Ca không sửa code, không đẩy code
  v3, không làm trùng nhịp chat chính/Leader.
- Trạng thái từ xa (connector GitHub, trong ca này):
  (1) đầu nhánh v3 VẪN là `399f67a0cd373118585c05ea80b80089e931a7c9`
  (CI-FIX-2, 2026-11-12T06:30:56Z) — CI-FIX-3 CHƯA đẩy, chưa
  có run CI mới, chưa có phán quyết cho 2 lỗi BenchView của
  run #41. (2) đầu nhánh docs/planning VẪN là
  `ce6f6dccfc902a1f3df301a94dc639fcaf047a55` (commit ca
  00:40) — lần đẩy 06:40 XÁC NHẬN CHƯA LÊN; các mục 02:40,
  04:40, 06:40 (và mục này) vẫn chỉ có tại bàn cho tới khi
  lần đẩy cuối ca này / ca sau lên được.
- Tại bàn: BenchView.swift vẫn giữ đúng sửa CI-FIX-3 —
  `RecognizeDocumentsRequest()` ở dòng 211 và
  `RecognizeTextRequest()` ở dòng 213 (grep trực tiếp
  trong ca này).
- Tuyên bố trung thực — đã chứng minh: trạng thái đầu
  nhánh v3 + docs/planning và nội dung BenchView tại bàn
  kể trên, bằng đọc trực tiếp GitHub + grep trong ca; chưa
  chứng minh: CI-FIX-3 vẫn CHƯA biên dịch thật — C2 phía
  BenchShell chỉ đóng khi một run CI xanh trọn cả 2
  scheme; chưa làm: chưa quyết kỳ vọng kiểm tĩnh P2
  (TODO(PHA-3) → documentsAdapterNotWired — quyết thuộc
  Leader), chưa đẩy v3, chưa chuẩn bị bản giao nào — đóng
  băng giao bản vẫn nguyên.
- **Bước tiếp theo giữ nguyên: CI-FIX-3 ở nhịp chat
  chính/Leader** — quyết kỳ vọng kiểm tĩnh P2, đẩy
  BenchView.swift đã kiểm chéo lên v3, chờ run kế tiếp
  phán quyết. Không kêu anh cài/test gì. Đây là ca thứ 4
  liên tiếp cùng một điểm chờ (02:40 / 04:40 / 06:40 /
  08:40) — theo luật báo cáo mục (c), điểm chờ này cần
  chat chính xử lý; ca trực không tự đẩy code v3 theo
  luật ca.
- ĐẨY CUỐI CA 08:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `0466434067d6e0c03162800296a0c535948d4099`; đọc lại từ xa
  xác nhận đầu nhánh = commit này. Nhờ đó các mục 02:40,
  04:40, 06:40 bị kẹt từ ca 06:40 NAY ĐÃ LÊN nhánh.
  (Dòng này chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## RUN #42 XANH TRỌN — C2 ĐÃ ĐÓNG HOÀN TOÀN (2026-11-12 09:22 CST)
- Run #42 (45244ff, CI-FIX-3): 14/14 bước thành công — Build main
  app 29s + Build bench app 22s + đóng gói + tải lên. Hai
  artifact: SoHoaDon-V3-run42-2026-11-12 (814,341 B) và
  SoHoaDon-BENCH-V3-run42-2026-11-12 (13,633,361 B). Tổng hành
  trình C2: run #38 (byte 0x08) → #39 (13 lỗi nối) → #40 (cầu
  documents) → #41 (app chính xanh; bench rớt 2 lỗi probe) → #42
  XANH TRỌN. Điều kiện treo C2 từ Pha 0 chính thức đóng; C1 (in
  ngôn ngữ trên máy) sẽ đóng trong phiên đo M-1.
- Đang tải 2 artifact về máy để kiểm đếm tài nguyên trong .app
  bench (33 ảnh + vendors.json + lexicon.json — bài học run #33:
  đếm file trong .app trước khi tin) rồi mới chuẩn bị gói phiên
  đo thiết bị M-1..M-7 trình anh.

## KIỂM ĐẾM ARTIFACT RUN #42 (2026-11-12 09:27 CST) — ĐẠT
- Tải cả 2 artifact về, mở gói kiểm tận nơi: .app bench chứa
  ĐÚ 33/33 ảnh JPG + vendors.json + lexicon.json; .app chính có
  đủ 2 JSON; ký hiệu documentsAdapterNotWired có mặt trong cả 2
  binary (bản sửa CI-FIX-2 thật sự ở trong bản biên dịch).
  IPA lưu tại downloads/: SoHoaDon-BENCH-V3-run42-2026-11-12.ipa
  (sha256 56342258…) + SoHoaDon-V3-run42-2026-11-12.ipa
  (sha256 d0d95032…). Đây là BẢN BIÊN DỊCH KIỂM CHỨNG + BẢN ĐO —
  không phải bản giao (luật GATE100).
- BƯỚC TIẾP: phiên đo thiết bị bằng BenchShell (gói IPA bench ở
  trên, bundle riêng com.nje.sohoadon.bench — cài song song,
  không đụng app chính/dữ liệu của anh): in ngôn ngữ (đóng C1) +
  chạy pipeline trên 33 ảnh bundle + dò họ documents + xuất
  chẩn đoán gửi lại. Trình anh xếp lịch phiên đo.

## C1 ĐÃ ĐÓNG + CI-FIX-5 (2026-11-12 10:20 CST)
- Anh chạy BenchShell run #42 và gửi toàn văn LanguageProbe:
  máy đích (iPhone, iOS 27.2) classic Rev3/accurate có 33 ngôn
  ngữ GỒM tiếng Việt — viết là "vi-VT"; họ documents cũng có vi.
  Hồ sơ: deep-study/LANGUAGE-PROBE-2026-11-12.md. C1 ĐÓNG.
- Bẫy phát hiện từ chính bản in: LanguagePolicy cũ khớp chuỗi
  nguyên văn "vi-VN" → sẽ đánh rớt tiếng Việt và ghi manifest
  SAI. CI-FIX-5: khớp theo mã ngôn ngữ + dùng nguyên văn cách
  viết của runtime; gương + fixture ENG-LANG-VT PASS; tĩnh P4/P5
  PASS. (Kèm L-2026-11-12-11 cho lỗi BenchView 0 ảnh — CI-FIX-4
  đang biên dịch ở run kế tiếp; bản bench giao tiếp theo sẽ gồm
  cả CI-FIX-4 + CI-FIX-5.)

## BENCH RUN #44 XANH + ĐÃ KIỂM GÓI (2026-11-12 10:25 CST)
- Run #43 (CI-FIX-4) và #44 (CI-FIX-5, HEAD 4678dce) đều xanh.
  Gói bench run #44 đã tải về và kiểm theo kỷ luật L-11 mới:
  33/33 JPG + vendors.json + lexicon.json trong .app; chuỗi ghi
  chú ngôn ngữ mới của CI-FIX-5 có mặt trong binary;
  documentsAdapterNotWired có mặt. IPA: downloads/
  SoHoaDon-BENCH-V3-run44-2026-11-12.ipa (sha256 da06bd00…).
- Đã gửi anh bản này: cài đè bản đo cũ → "Chạy tất cả qua
  ReceiptReader" (33 ảnh) → dò documents → xuất chẩn đoán gửi
  lại. File chẩn đoán về = nguyên liệu phân tích M-2..M-7 +
  Phần A.

## CA TRỰC 10:40 CST 2026-11-12 — KIỂM CHÉO ĐỘC LẬP L-2026-11-12-12 + GÓI CI-FIX-6 TẠI BÀN
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế D1–D7 21:44 ngày 2026-11-11). Sau mục
  10:25, TEAM.md đã có L-2026-11-12-12 (anh báo 10:27: BenchShell
  run #44 crash ở file đầu tiên; QuadGate lệch hệ toạ độ ĐÃ
  CHỨNG MINH tĩnh; giả thuyết crash H1 CHƯA chứng minh, chờ .ips
  hoặc bản đo breadcrumb). Ca làm đúng MỘT bước độc lập: kiểm
  chéo bằng chứng sơ cấp tại bàn, không sửa code, không đẩy v3.
- (1) IPA run #44 tại bàn: downloads/SoHoaDon-BENCH-V3-run44-
  2026-11-12.ipa sha256 = da06bd00aba67d790383ff70629bfa2cb9549
  b37c1ddcaae9a42c5c382957e3a — khớp dòng 10:25 (da06bd00…).
- (2) QuadGate: hợp đồng cổng ở CaptureIntake.swift:112-135
  tính theo ĐIỂM ẢNH (diện tích ≥ 55% × imageWidth×imageHeight)
  — khớp khẳng định L-12. Caller tại bàn (ReadPipeline.swift:
  838-853) NAY ĐÃ đổi điểm chuẩn hoá 0..1 → pixelQuad TRƯỚC khi
  gọi QuadGate.evaluate, kèm chú thích ghi rõ đây là lỗi riêng
  fail-closed, KHÔNG trình bày là bản sửa crash — đúng kỷ luật
  L-12.
- (3) Cả 3 biện pháp chặn của L-12 đã có trong nguồn tại bàn
  (gói CI-FIX-6, nhịp chat chính): stageBreadcrumb khai báo ở
  ReadPipeline.swift:363 + 8 điểm gọi (candidate/ocr/perspective/
  civariant/scoring/finalize); CIDocumentEnhancer cách ly sau
  cờ mặc định TẮT (dòng 365 + cờ "document-enhancer-off" dòng
  604, filter ở 915); đổi hệ toạ độ QuadGate ở mục (2) trên.
- Tuyên bố trung thực — đã chứng minh: hash IPA + hợp đồng
  QuadGate + sự hiện diện của 3 biện pháp CI-FIX-6 trong nguồn
  tại bàn, bằng đọc trực tiếp + grep trong ca; chưa chứng minh:
  cơ chế crash run #44 (H1 vẫn chờ .ips/bản đo breadcrumb —
  ca không đoán thay), CI-FIX-6 CHƯA biên dịch/chưa chạy thiết
  bị ở ca này; chưa làm: chưa đẩy v3, chưa chuẩn bị bản giao —
  đóng băng giao bản vẫn nguyên.
- **Bước tiếp theo giữ nguyên: nhịp chat chính/Leader** — đẩy
  CI-FIX-6 lên v3 → run CI → bản bench chẩn đoán cho anh chạy
  để lấy breadcrumb/.ips khoá cơ chế crash. Không kêu anh
  cài/test thêm gì ngoài phiên chẩn đoán đó.
- ĐẨY CUỐI CA 10:40: **THÀNH CÔNG** — đúng 1 lần hoàn tất, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `d12fa0a47738d46a229728709a8458f97b1abfac`. (Dòng này chỉ có
  tại bàn, sẽ đi theo lần đẩy của ca sau.)

## BENCH CHẨN ĐOÁN RUN #45 (CI-FIX-6) XANH + ĐÃ KIỂM GÓI (2026-11-12 10:59 CST)
- Commit 4ab4920 (breadcrumb giai đoạn + cách ly CIDocumentEnhancer
  mặc định TẮT + sửa QuadGate đổi hệ toạ độ); run #45 xanh 1m10s.
  Gói bench đã kiểm: 33/33 JPG + 2 JSON; mọi dấu CI-FIX-6 có mặt
  trong binary (cờ document-enhancer-off, bench-stage-log.txt,
  stageBreadcrumb, documentEnhancerEnabled, nhãn công tắc).
  IPA: downloads/SoHoaDon-BENCH-V3-run45-2026-11-12.ipa
  (sha256 33e36a56…).
- Đã gửi anh kèm phép đo A/B: (1) enhancer TẮT → chạy hết 33 →
  xuất chẩn đoán; (2) tuỳ chọn khi (1) trọn: BẬT enhancer → chạy
  lại; nếu chết, nhật ký giai đoạn trong mục "Chẩn đoán crash"
  chỉ đích danh tầng chết → khoá/không khoá H1.

## BENCH CHẨN ĐOÁN RUN #45 CRASH SAU FILE ĐẦU TIÊN (anh báo qua voice 11:18 CST 2026-11-12)
- Anh chạy bản bench chẩn đoán run #45: app vẫn crash sau khi
  đọc file đầu tiên (giống triệu chứng run #44). Chưa rõ lúc
  crash công tắc enhancer đang TẮT hay BẬT — nhật ký giai đoạn
  (breadcrumb) ghi trên đĩa sẽ trả lời cả hai: dòng stage cuối
  cùng = tầng chết; có dòng civariant-enhancedDocument hay
  không = enhancer có chạy hay không.
- Đã hướng dẫn anh (voice): mở lại app đo → mục "Chẩn đoán
  crash (CI-FIX-6)" → nhật ký tự nạp (hoặc bấm "Đọc lại nhật
  ký giai đoạn") → "Chia sẻ nhật ký giai đoạn" gửi về đây.
- Chờ file nhật ký để khoá/không khoá H1. Nếu dòng cuối là
  civariant-enhancedDocument → H1 khoá ở bộ lọc đó. Nếu chết
  vẫn với enhancer TẮT và dòng cuối là civariant-shadowRemoved
  hoặc enhancedContrast → nghi phạm dời sang CIContext GPU
  dùng chung / biến thể CI còn lại (H1 dạng rộng). Nếu dòng
  cuối là ocr-* hoặc candidate-* thuần → quay lại họ H4.

## NÚT "ĐỌC LẠI NHẬT KÝ GIAI ĐOẠN" KHÔNG CÓ TÁC DỤNG (anh báo voice 11:21 CST 2026-11-12)
- Anh báo nguyên văn: "Còn phần đọc lại nhật ký giai đoạn không
  có tác dụng." Chưa rõ nghĩa chính xác: bấm mà không hiện chữ
  nào (file nhật ký rỗng/không tồn tại trên máy) hay mục không
  hiện — cần ảnh chụp mục "Chẩn đoán crash" để phân định, đã
  xin anh đúng 1 tấm ảnh đó (chốt 3 câu hỏi cùng lúc: đúng bản
  run #45 chưa / mục có hiện không / nhật ký có chữ nào không).
- Khả năng phía em đã tự nhận diện (NHÃN: chưa chứng minh):
  (1) bộ ghi nhật ký nuốt mọi lỗi bằng try? — ghi hỏng là im
  lặng tuyệt đối, chính nó mù với lỗi của nó (lỗi thiết kế của
  Leader khi làm CI-FIX-6); (2) breadcrumb đầu tiên chỉ được
  gắn SAU loadCGImage trong runOne — nếu crash nằm ở khâu nạp
  ảnh thì không dòng nào kịp ghi; (3) anh có thể đang mở bản
  run #44 (không có mục chẩn đoán) — chỉ ảnh chụp mới phân
  định được, không suy đoán về phía anh.
- Bài học ghi trước: dụng cụ chẩn đoán phải TỰ HIỆN TRẠNG THÁI
  của chính nó (số dòng đã ghi / lỗi ghi cuối) ngay trong giao
  diện — bản sửa kế tiếp của bộ ghi phải fail-visible.

## NHẬT KÝ BREADCRUMB RUN #45 ĐÃ VỀ (2026-11-12 11:17 CST)
- C-003 chạy trọn toàn chuỗi; L-R01 chết bên trong
  runCandidate(original). H1 (CIDocumentEnhancer/CoreImage)
  BỊ BÁC — xem phụ lục L-2026-11-12-12 trong TEAM.md.
- Đang audit tại bàn cửa sổ runCandidate trên dữ liệu L-R01;
  không còn thao tác nào cần từ anh cho tới khi có cơ chế +
  bản sửa kiểm chứng tại bàn.

## BENCH CHIA ĐÔI CI-FIX-7 RUN #46 XANH + ĐÃ KIỂM GÓI (2026-11-12 12:41 CST)
- Commit 54d68a1; run #46 xanh 1m22s. Gói bench kiểm: 33/33 JPG
  + 2 JSON; đủ dấu CI-FIX-7 trong binary (breadcrumb mịn
  engine-perform-begin / engine-convert-done /
  candidate-recognize-done / candidate-parse-done; chuỗi
  direct-override của bisect; symbol directLanguagesOverride).
  IPA: downloads/SoHoaDon-BENCH-V3-run46-2026-11-12.ipa.
- Phiên đo kèm theo: mặc định = cấu hình đã chứng minh (ngôn
  ngữ "Bản cũ: vi-VN + en-US", topCandidates TẮT) → chạy hết
  33 → xuất chẩn đoán. Tuỳ chọn cô lập: đổi Picker sang
  "Hiện tại: vi-VT + en-US" chạy riêng L-R01; rồi bật
  topCandidates(3) chạy riêng L-R01. Bảng đọc kết quả ở
  v3-phase4/CI-FIX-7.md.

## RUN #46 VẪN CRASH (anh báo 2026-11-12 12:42 CST: "Tiếp tục crash")
- Anh báo bản bench CI-FIX-7 (mặc định = cấu hình đã chứng
  minh: ngôn ngữ kiểu cũ + top-1) vẫn crash. Nếu điểm chết
  trùng lần trước thì tiền đề chia đôi (hai điểm mới của cấu
  hình engine) SỤP — thủ phạm nằm sâu hơn hai delta đó.
- Chưa kết luận gì thêm khi chưa có nhật ký giai đoạn của
  lượt này: bản này có mốc mịn quanh lượt gọi engine
  (engine-perform-begin/-done, engine-convert-done) — dòng
  cuối quyết định hướng. Đã xin anh đúng một thứ: file nhật
  ký đó. Không xin thao tác nào khác.

## CA TRỰC 12:40 CST 2026-11-12 — KIỂM CHÉO ĐỘC LẬP GÓI BENCH RUN #46 (CI-FIX-7)
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (file này ghi
  rõ anh duyệt hướng 21:02 + duyệt thiết kế chốt D1–D7
  21:44 ngày 2026-11-11) — ca quay lại luật chung. Nhịp
  crash L-R01 đang ở chat chính/Leader (audit
  CRASH-WINDOW-LR01 + CI-FIX-7 + run #46 xanh, mục 12:41 ở
  trên) — ca không làm trùng, chỉ làm đúng MỘT bước độc
  lập: kiểm gói IPA bench run #46 tại bàn theo kỷ luật
  L-11, bằng mở gói + strings trực tiếp trong ca này.
- (1) IPA downloads/SoHoaDon-BENCH-V3-run46-2026-11-12.ipa:
  13.649.159 byte, sha256 tự tính trong ca =
  dbe6f541ce4d98f81d98c5de52ed8c2d5fc3dbe7083b0a7dad91541f0d57a441
  (mục 12:41 chưa ghi hash — ca này bổ sung con số đầy đủ).
- (2) Ruột Payload/SoHoaDonBench.app: 33/33 JPG nằm ở gốc
  .app (layout phẳng đã biết) + vendors.json +
  lexicon.json — khớp mục 12:41.
- (3) Dấu CI-FIX-7 trong binary: đủ 11/11 chuỗi, mỗi chuỗi
  có hit bằng strings — engine-perform-begin,
  engine-perform-done, engine-convert-done,
  candidate-recognize-done, candidate-assemble-done,
  candidate-parse-done, candidate-evaluation-done,
  direct-override, directLanguagesOverride,
  document-enhancer-off, bench-stage-log.txt.
- Tuyên bố trung thực — đã chứng minh: toàn vẹn gói +
  sự hiện diện của dấu CI-FIX-7 trong file bench run #46
  tại bàn, bằng chứng sơ cấp của chính ca này; chưa chứng
  minh: cơ chế crash L-R01 — bằng chứng quyết định là
  phiên chia đôi run #46 trên máy anh (chưa chạy), ca này
  không kết luận thay; chưa làm: không sửa code, không
  đẩy v3, không chuẩn bị bản giao — đóng băng giao bản
  vẫn nguyên.
- **Bước tiếp theo giữ nguyên: phiên đo run #46 ở nhịp
  chat chính** (mặc định Bản cũ + topCandidates TẮT chạy
  hết 33 → xuất chẩn đoán; tuỳ chọn cô lập trên L-R01) →
  Leader đọc kết quả theo bảng v3-phase4/CI-FIX-7.md.
  Không kêu anh cài/test gì thêm ngoài phiên đó.

## LUẬT MỚI CỦA ANH 12:44 CST 2026-11-12 — DỪNG GIAO BẢN CRASH
- Anh ra lệnh: ngừng đưa bản crash bắt anh test; rà toàn bộ
  project, sửa lỗi tại bàn; tự chạy ≥100 lần thành công liên
  tục mới giao; chỉ giao patch lớn. Đã ghi TEAM.md.
- Hai tuyến mở ngay: (A) rà soát toàn project + vi sai
  cũ-vs-mới; (B) dựng harness tự chạy trên CI macOS (đường
  đọc Swift thật × 33 ảnh × 100 lượt). Yêu cầu nhật ký
  run #46: RÚT.
- ĐẨY CUỐI CA 12:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `b5bd50d8b24d9ca4de505a661c9954272fa74255`. (Dòng này chỉ
  có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## ĐIỂM CHẾT ĐÃ KHOÁ: TRONG PARSER, TRÊN LUỒNG THẬT CỦA L-R01
- Nhật ký mịn run #46 (mục trên trong TEAM.md): chết trong
  ReceiptParser.parse. Hai tuyến theo luật mới của anh:
  (A) harness tự chạy + tái hiện tại bàn (Swift parser trên
  luồng ghi + đột biến token, và/hoặc CI macOS với Vision
  thật); (B) rà soát toàn project. Không bản nào tới tay anh
  cho tới khi: tái hiện được tại bàn → sửa → tự chạy 100
  lượt liên tiếp sạch trên đủ 33 ảnh → mới giao patch lớn.

## HAI TUYẾN RÀ SOÁT XONG (2026-11-12 ~12:55 CST) + HARNESS ĐÃ ĐẨY
- HARNESS-REPRO: VM không có Swift → gói CI-macOS dựng xong;
  Leader đã đẩy harness/ lên v3 (commit de2c617) và đang cài
  workflow qua trình duyệt để kích lượt chạy đầu. Hai ứng
  viên cơ chế crash (đọc tĩnh toàn văn parse, Leader tự đọc
  lại cả hai dòng): A = Parser.swift:1999 Int((maxX/0.01)…)
  — hộp tiền NaN/inf/khổng lồ là trap, KHÔNG cổng hữu hạn
  nào trên đường đi; B = Parser.swift:1223 dòng cân (đã được
  FULL-REVIEW xác nhận là điểm trap CHẮC CHẮN duy nhất trong
  lõi đọc). Lượt CI đầu phân định bằng census hộp + fuzz id.
- FULL-PROJECT-REVIEW (69 phát hiện, 11 lệch thiết kế, 14
  khẳng định vượt bằng chứng — v3-phase4/FULL-PROJECT-REVIEW.md):
  nặng nhất: (1) Models.swift:414-439 hàm tiền tầng app phá
  số âm (−216.80 đọc lại thành −21520; −0.50 thành +50) +
  crash khi dán số 18–19 chữ số — lọt mọi cổng vì kiểm tĩnh
  chỉ quét file module, không quét tầng app; (2) 18 điểm lưu
  SwiftData nuốt lỗi bằng try? mà vẫn báo "Đã lưu ✓" (màn
  Kiểm Lại đóng dù lưu hỏng); (3) ReadPipeline giữ CGImage
  toàn phân giải của MỌI ứng viên tới finalize (đỉnh vài
  trăm MB — bề mặt jetsam không trần) + đường
  diagnosticsDirectory=nil né cổng ghi mà cờ vẫn false (phá
  luật §1.5); (4) QualityMap không hề nuôi hàm chọn ứng
  viên như thiết kế (code chết) và cổng chất lượng lệch vị
  trí thiết kế; (5) vi sai cũ↔mới chưa từng vào ma trận đo:
  họ documents biến mất, bỏ cắt lát + ~3× lượt perform,
  CIContext tĩnh ép GPU dùng chung.
- Hàng sửa (Leader xếp, thi hành SAU khi harness khoá cơ
  chế crash): trap A/B + họ cùng nhà → toàn vẹn dữ liệu
  (tiền số âm, lưu nuốt lỗi, né cổng ghi) → trần bộ nhớ ứng
  viên → lệch thiết kế ảnh hưởng đúng-sai. Sau sửa: chạy
  luật 100 lượt trên CẤU HÌNH SẼ GIAO (current + top-3),
  không chỉ cấu hình bench cũ.

## HARNESS RUN #1 HUỶ SAU 3 GIÂY — RUNNER (2026-11-12 12:59 CST)
- Workflow đã cài: v3 ad1c675 + main e6bb6f2 (bản sao y hệt
  để Actions thấy workflow — dispatch chỉ chạy với workflow
  có trên nhánh mặc định). Run #1 kích thành công trên v3
  nhưng bị huỷ ngay: cấu hình runner "macos-14-arm64-us-xl"
  không được hỗ trợ cho repo này. Sửa: runs-on macos-14 →
  macos-15 (nhãn build-ipa vẫn chạy xanh) trên cả hai bản +
  bản nháp staging, rồi kích lại.

## HARNESS RUNS #2/#3 — HAI LẦN CHẾT Ở BƯỚC BUILD CỦA HARNESS (2026-11-12)
- Run #2 (e4f5921): build hỏng dưới Xcode 16.4 mặc định —
  bản nháp thiếu bước Select Xcode 26 + giấu lỗi sau tail -5.
  Đã sửa bản nháp (chọn Xcode 26 như build-ipa, tee build.log
  vào artifact); workflow trên v3 394a10d + main (đồng bộ).
- Run #3 (394a10d): build tiến tới Xcode 26.3, chết vì lỗi
  biên dịch trong CHÍNH mã harness: main.swift:385,388
  "ambiguous use of 'nan'" (mã fuzz dựng hộp NaN). Đã sửa
  CGFloat.nan tường minh (376/385/388), đẩy v3 3be5737.
  Run #4 tự kích theo push — đang chờ kết quả cổng thật.
- Bài học ghi sổ: harness cũng là mã — phải qua cùng kỷ luật
  kiểm tĩnh biên dịch trước khi kích lượt dài.

## HARNESS RUN #4 (2026-11-12 13:36 CST) — BUILD XANH, CỔNG 1 CHƯA CHẠY ĐƯỢC
- Build SUCCEEDED (sửa NaN đúng), nhưng biến BIN của
  workflow trỏ nhầm vào file DWARF trong .dSYM (find lấy
  kết quả đầu) → "Permission denied" ở Cổng 1; cổng luật
  chưa chạy. Probe "PASS" là PASS GIẢ: bước probe không có
  pipefail, tee nuốt mã lỗi — control.log/probe.log rỗng.
  Đã sửa bản nháp: find giới hạn Build/Products + loại
  .dSYM; probe thêm pipefail. Chờ cài lên repo + chạy lại.

## CA TRỰC 14:40 CST 2026-11-12 — PHÁN QUYẾT HARNESS RUN #5: BIN + PROBE ĐÃ KHÉP, CỔNG 1 RỚT CÂM; BẢN 2>&1 CHƯA CÓ LƯỢT CHẠY
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế chốt D1–D7 21:44 ngày 2026-11-11) —
  ca quay lại luật chung, làm đúng MỘT bước: lấy phán quyết
  lượt harness sau mục RUN #4 (13:36), là bước tiếp theo đang
  chờ ở mục đó ("cài lên repo + chạy lại"). Ca không sửa code,
  không đẩy code v3, không kích lượt chạy nào.
- Cài lên repo ĐÃ XẢY RA ở nhịp chat chính sau mục 13:36:
  commit `43dd986` trên v3 (2026-11-12 13:40 CST, "Update
  harness-ci.yml") đưa đúng 2 sửa của bản nháp — BIN find giới
  hạn `harness/dd/Build/Products` + loại `.dSYM`, và Probe
  cộng `set -o pipefail` (đối chiếu trang commit: 2 cộng /
  1 xoá so với `3be5737`; bản nháp tại bàn
  harness/workflow/harness-ci.yml dòng 51 + 56 khớp).
- RUN #5 (đọc trực tiếp GitHub Actions trong ca này, run id
  43292958946, job law-and-control macos-15, kích tay, bắt đầu
  13:42 CST, 44s, completed/failure): build ĐÚNG commit
  `43dd986` — KHÔNG phải đầu v3 hiện tại. Từng bước: Build
  harness (Release) **PASS** — log kết "** BUILD SUCCEEDED **",
  `BIN: harness/dd/Build/Products/Release/SoHoaDonHarness`
  (đúng binary Release thật, hết bệnh .dSYM của run #4) ·
  Probe **PASS THẬT** — log có danh sách ngôn ngữ rev3/accurate
  (gồm `vi-VT`), `vendors dataVersion = vendors-2026-11-11-p1`,
  `lexicon version = lexicon-2026-11-11-p1`, `SURVIVED probe`
  (hết PASS giả của run #4) · **Cổng 1 — control RỚT** (1s,
  exit 1): log bước chỉ 7 dòng — lệnh chạy + `grep -q
  "SURVIVED fixture" control.log` + dòng lỗi exit 1; binary
  KHÔNG để lại stdout nào bị bắt, không dòng "Permission
  denied", không chữ lỗi nào khác. Cổng 2 (luật 100 lượt) ·
  ma trận phụ · Cổng 3 fuzz đều SKIPPED. Artifact
  `harness-evidence-5` ĐÃ tải lên (6.03 KB, 3 file, sha256
  3593ffe2… theo trang run).
- ĐẦU v3 HIỆN TẠI ĐÃ ĐI TIẾP: `6716f22` (14:29 CST) cộng
  `2>&1` vào lệnh Cổng 1 + Cổng 2 + ma trận (3 cộng / 3 xoá,
  1 file) — bản nháp tại bàn đã khớp dạng này (grep `2>&1` ở
  các lệnh fixture/images trong ca này); main có commit đồng
  bộ `0884d10` (14:31 CST, cùng thông điệp — ca chỉ xác nhận
  tồn tại qua connector, chưa đối chiếu nội dung trên main).
  **Chưa có run #6**: lượt chạy trên `6716f22` CHƯA TỒN TẠI ở
  thời điểm kiểm (14:45 CST) — sửa 2>&1 chưa được phán quyết.
- Tuyên bố trung thực — đã chứng minh: trạng thái run #5
  từng bước + nội dung workflow trên v3 + thứ tự 2 commit,
  bằng đọc trực tiếp Actions/trang commit/file trên nhánh
  trong ca; chưa chứng minh: VÌ SAO binary fixture ở Cổng 1
  không ra chữ nào — log run #5 không chứa bằng chứng (lệnh
  ở `43dd986` chưa có `2>&1` nên stderr nếu có đã không vào
  control.log; đây là tính chất của lệnh, không phải kết
  luận cơ chế: chết-trong-parse / thoát-sớm / crash đều chưa
  phân định được); chưa làm: chưa chạy lượt trên `6716f22`,
  chưa đụng hàng sửa crash A/B (vẫn chờ harness khoá cơ chế
  theo mục ~12:55), chưa chuẩn bị bản giao nào — đóng băng
  giao bản + luật 100 lượt vẫn nguyên.
- **Bước tiếp theo: một lượt harness trên đầu v3 `6716f22`**
  (nhịp chat chính/Leader kích — workflow đã có sẵn nút
  dispatch; push lên v3 cũng tự kích theo paths) → đọc Cổng 1
  với stderr đã bắt: nếu binary chết có chữ lỗi thì đối chiếu
  census/fuzz để khoá A/B; nếu Cổng 1 qua thì Cổng 2 (100
  lượt) mới là phán quyết luật của anh. Không kêu anh
  cài/test gì.

## HARNESS RUN #5 (2026-11-12 13:42 CST) — PROBE THẬT, CONTROL CHẾT LẶNG
- BIN đã đúng file chạy; probe PASS thật (macOS Vision rev3
  cũng ghi "vi-VT" như iPhone). Cổng 1 (control, parse luồng
  đã ghi L-R01) chết với control.log = 0 byte, KHÔNG một
  dòng stdout/stderr: giả thuyết làm việc = Swift print qua
  pipe bị đệm theo khối, process trap trong parse thì mất
  toàn bộ log (chưa chứng minh — cũng có thể log UI thiếu).
- Đã vá dụng cụ: driver setvbuf(stdout,_IONBF) + mốc
  [fixture] từng chặng (19b40a6); workflow gộp stderr vào
  log cổng (6716f22). Run #6 đang được theo dõi — lượt này
  hoặc control SURVIVED, hoặc log chỉ đúng chặng chết.
- ĐẨY CUỐI CA 14:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `f0a8222d9d159f9bcb8ae7015fb9bb8665be25f9`; đọc lại từ xa
  xác nhận đầu nhánh = commit này. (Dòng này chỉ có tại bàn,
  sẽ đi theo lần đẩy của ca sau.)

## *** TÁI HIỆN ĐƯỢC CRASH BẰNG SWIFT THẬT (run #6, 2026-11-12 14:50 CST) ***
- Cổng control: mốc [fixture] start → data-loaded →
  lines=53 boxes=yes → [fixture] parsing → PROCESS CHẾT,
  không có [fixture] parsed. ReceiptParser.parse TRAP trên
  chính LUỒNG ĐÃ GHI của L-R01 (53 mảnh, hộp hữu hạn) khi
  chạy bằng Swift thật trên macOS.
- Hệ quả: kết luận "parser sạch trên luồng đã ghi" của
  CRASH-WINDOW-LR01 (kết luận qua gương Python + đọc tĩnh)
  BỊ THU HỒI — gương mù với ngữ nghĩa trap của Swift, đúng
  họ lỗi L-2026-11-11-9 (kiểm trên cái không phải thứ thật).
- Bước tiếp: chế độ bisect trong harness — parse từng tiền
  tố + thu nhỏ tập dòng trong process con riêng, khoanh
  dòng/nội dung gây chết tối thiểu ngay trong một lượt CI.

## CƠ CHẾ CHẾT ĐÃ CÓ NGĂN XẾP (run #16, 2026-11-12 16:32 CST)
- Bẫy tín hiệu tự chẩn đoán hoạt động: HARNESS-SIGNAL sig=5
  (SIGTRAP — bẫy runtime của Swift), mã thoát 133.
  Ngăn xếp: parse -> parseGeneric -> parseGenericItemsV2 ->
  extractSamelineItems (+4312) -> TRAP. Điểm chết nằm TRONG
  nhánh trích món cùng-dòng, trên dòng tối thiểu
  "3006152 BOUNCE 400 11.49 A".
- matchGroups đã đọc lại: an toàn (xử NSNotFound tường
  minh). Vòng desk truy tay dòng này qua extractSamelineItems
  chưa thấy điểm trap — cần chẻ biến thể để chỉ đặc điểm
  kích hoạt. Harness đã thêm chế độ variants (10 biến thể,
  process con riêng) + bước CI tương ứng; đang đẩy chạy.

## CA TRỰC 16:40 CST 2026-11-12 — PHÁN QUYẾT RUN #17: VARIANTS ĐÃ ĐẨY XONG NHƯNG BƯỚC VARIANTS CHƯA TỪNG CHẠY; CỔNG 1 RỚT Y HỆT RUN #16
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế chốt D1–D7 21:44 ngày 2026-11-11) —
  ca quay lại luật chung, làm đúng MỘT bước: lấy phán quyết
  lượt harness sau mục 16:32 ("variants … đang đẩy chạy"),
  là bước tiếp theo đang chờ ở mục đó. Ca không sửa code,
  không đẩy code v3, không kích lượt chạy nào.
- ĐẨY VARIANTS ĐÃ XONG Ở NHỊP CHAT CHÍNH (ca kiểm từ xa):
  (1) mã variants — commit `dc13cf64` trên v3 (16:42 CST,
  "HARNESS-VARIANTS: parseonly --text + chế độ variants");
  blob `main.swift` tại bàn `50110b92…` (30.755 byte) KHỚP
  blob trên nhánh v3 tại thời điểm kiểm — bản tại bàn và
  bản trên repo là một. (2) bước CI variants — commit
  `86d8e934` trên v3 (16:48 CST, "Add variants step after
  bisect and upload variants.log") = đầu v3 tại thời điểm
  kiểm của ca.
- RUN #17 (cho `dc13cf64`, run id 43322329122, đọc trực tiếp
  Actions trong ca; 44s, completed/FAILED): Build harness
  PASS · Probe PASS · **Cổng 1 control RỚT** (exit 133) —
  log: [fixture] start → data-loaded → lines=53 boxes=yes →
  parsing → **HARNESS-SIGNAL sig=5**, ngăn xếp y hệt run #16:
  parse → parseGeneric → parseGenericItemsV2 →
  extractSameLineItems **+4312** → TRAP (ký hiệu trong log
  run #17 ghi "extractSameLineItems"). Bước bisect PASS và
  xác nhận lại độc lập: tiền tố k=9 DIED, thu nhỏ còn đúng
  **idx=8, 1 dòng duy nhất "3006152 BOUNCE 400 11.49 A"**
  (BISECT-DONE fatalPrefix=9 minimalCount=1). Cổng 2 (luật
  100 lượt) · ma trận · Cổng 3 SKIPPED.
- **BƯỚC VARIANTS CHƯA TỪNG CHẠY**: run #17 chạy theo
  workflow của `dc13cf64` — lúc đó CHƯA có bước variants
  (bước chỉ vào ở `86d8e934`). Và tính tới 16:54 CST (kiểm
  2 lần trên danh sách Actions lọc branch v3): **CHƯA CÓ
  LƯỢT CHẠY NÀO cho `86d8e934`** — không run #18, không
  lượt đang chạy. Giải thích ghi nhãn SUY LUẬN (chưa chứng
  minh — ca chưa đọc danh sách file của commit `86d8e934`):
  workflow chỉ tự kích khi push chạm `*.swift` hoặc
  `harness/**` (đọc từ bản nháp tại bàn, dòng on.push.paths);
  một commit chỉ sửa `.github/workflows/harness-ci.yml`
  không khớp cả hai mẫu đó nên không tự sinh lượt — khớp
  với việc `dc13cf64` (chạm harness/**) sinh run #17 ngay.
  Dù nguyên nhân nào, hệ quả thực tế như nhau: phán quyết
  V1–V10 chưa tồn tại.
- Tuyên bố trung thực — đã chứng minh: trạng thái đẩy 2
  commit + phán quyết run #17 từng bước + vắng mặt lượt
  chạy của `86d8e934` tới 16:54 CST, bằng đọc trực tiếp
  GitHub/Actions trong ca; chưa chứng minh: ĐẶC ĐIỂM nào
  của dòng chết kích hoạt trap (đúng việc variants sinh ra
  để trả lời — chưa có dữ kiện), và nguyên nhân vắng lượt
  của `86d8e934` mới ở mức suy luận trên; chưa làm: chưa
  sửa code, chưa đụng hàng sửa trap A/B, chưa chuẩn bị
  bản giao nào — đóng băng giao bản + luật 100 lượt vẫn
  nguyên, không kêu anh cài/test gì.
- **Bước tiếp theo: Leader kích tay (workflow_dispatch)
  một lượt harness trên đầu v3 `86d8e934`** → đọc mục
  variants trong artifact/log: biến thể V1–V10 nào
  ok/DIED sẽ chỉ đặc điểm kích hoạt của dòng chết → mới
  định điểm trap cụ thể trong extractSameLineItems.
- ĐẨY CUỐI CA 16:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `d5a9ab9cc999e985fce951e688fc9848719fd9d3`. (Dòng này chỉ
  có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## ★ CƠ CHẾ CRASH ĐÃ KHOÁ + ĐÃ SỬA (2026-11-12 17:0x CST)
- Run #18 (2a927fa) — chẻ biến thể: CHẾT = V1,V3,V4,V8,V10;
  SỐNG = V2,V5,V6,V7,V9. Mẫu số chung của nhóm chết: dòng có
  MÃ >= 7 CHỮ SỐ đứng độc + TIỀN SẠCH -> tạo được món.
  "400" và cờ đuôi không liên quan.
- CƠ CHẾ (đọc code đối chiếu, khớp mọi bằng chứng):
  Parser.swift:1320 — matchGroups CHỈ trả các nhóm bắt
  (capture groups), không gồm toàn khớp. Pattern trích
  itemCode "(?<!\d)\d{7,}(?!\d)" KHÔNG có nhóm bắt nào ->
  khớp thành công trả MẢNG RỖNG [] (không phải nil) ->
  `if let cm` qua -> `cm[0]` subscript mảng rỗng -> SIGTRAP.
  Dòng Costco điển hình (mã 7 số + tiền) luôn kích hoạt.
- Điều tra diện (census): site 1320 là DUY NHẤT trong toàn
  code mắc lớp lỗi này — mọi site subscript khác đều có
  pattern có nhóm + chốt count (1161-64, 1178-81, 1252,
  470, 1131-37, im/sm). 21 chỗ dùng != nil dạng boolean an
  toàn. Quét [0]/[1] ngoài matchGroups: đều mảng cố định/
  API hệ thống, an toàn theo cấu trúc.
- Vì sao gương Python mù: port dùng tuple rỗng = FALSY nên
  nhánh tương đương bị bỏ qua lặng lẽ; Swift mảng rỗng
  KHÁC nil. Đây là cơ chế mù gương thứ ba, đã vào TEAM.md
  L-2026-11-12-13.
- SỬA (đẩy v3 43cf53d6, patch nhỏ theo Luật 2): pattern thêm
  nhóm bắt "(\d{7,})" + chốt cm.count == 1 + comment ghi cơ
  chế. Hành vi giữ nguyên (itemCode = dãy số dài trong tên).
- Đang chờ: lượt harness tự kích hoạt trên 43cf53d6 —
  control phải SURVIVED, sau đó Cổng 2 (33 ảnh x 100 set),
  ma trận, Cổng 3 fuzz.

## CONTROL XANH TRÊN CODE ĐÃ SỬA (run #19, 2026-11-12 17:04 CST)
- Lượt tự kích hoạt trên 43cf53d6: Cổng 1 control PASS —
  "[fixture] parsing -> [fixture] parsed -> SURVIVED
  fixture", không còn HARNESS-SIGNAL. Luồng L-R01 từng giết
  mọi bản trước nay parse trọn vẹn bằng Swift thật.
- Cổng 2 (33 ảnh x 100 set) đang chạy tại thời điểm ghi;
  kết quả toàn lượt (kèm ma trận + fuzz) sẽ đọc từ artifact
  harness-evidence-19 khi lượt kết thúc.

## GÓI SỬA LỚN — PHẦN FULL-REVIEW ĐÃ THI HÀNH Ở STAGING (2026-11-12 chiều)
Vị trí: v3-phase4/app/ (chưa đẩy — chờ census run #19 xong
rồi đẩy một lần, lượt CI trên code cuối là cổng Luật 3).
- T1 Parser: weightLine chặn lb (finite, <=1e6) + điểm
  Int(Double) ở :1223 qua kiểm miền [0, 2^63).
- Khoá bin NaN (3 site): Parser.columnModel + CaptureIntake
  moneyColumnRange chỉ nạp cạnh hữu hạn; LineAssembly loại
  phiếu dy không hữu hạn tại nguồn.
- T2+N1 Models.dollarsTextToCents viết lại: dấu trừ áp toàn
  giá trị (-216.80 -> -21680; -0.50 -> -50), phần đô-la
  chặn 12 chữ số (hết trap dán chuỗi dài); giữ nguyên các
  ngữ nghĩa cũ còn lại (cắt xu ở chữ số 3, frac 1 chữ số
  đệm 0...).
- N2 toàn diện: helper saveContextOrFalse (ReceiptViews);
  ReviewView.save hỏng -> rollback + alert + Ở LẠI màn
  (hết đóng màn giả); saveChanges/Duyệt/gắn ảnh/quét lại/
  đọc lại ở Chi Tiết đều báo lỗi đỏ thật; CardsView 4 điểm
  (hoàn tác + alert); ContentView seed 2586 (fetch lỗi
  không nạp trùng, chỉ đặt cờ sau khi lưu chắc).
- C8: ReviewView — ngày tạm (bộ đọc trượt ngày) hiện cảnh
  báo cam ngay tại ô ngày; lưu mà không sửa -> ép chờ
  duyệt (dateIsUntouchedDefault vào stillNeedsReview).
- C9: xoá tờ — chụp tên file trước, xoá bản ghi + lưu
  TRƯỚC, thành công mới xoá file (kèm mọi ảnh gốc phụ);
  hỏng -> rollback, mọi thứ còn nguyên.
- N4 ReadPipeline: diagnosticsDirectory == nil -> ép
  diagnosticsWriteFailed = true (hết né cổng §1.5).
- N3 ReadPipeline: sau pickWinner, ảnh toàn phân giải của
  ứng viên thua bị thay bằng ảnh 1x1 (metadata/fragments
  giữ cho hồ sơ); hết giữ ~6 CGImage 12-24MP tới cuối đọc.
- N5 BenchView: mặc định = cấu hình app giao (top3On=true,
  langMode=0 = chính sách runtime vi-VT).
- S10 (checks/static_check_s10.py, MỚI): cổng tĩnh lớp
  matchGroups/subscript — PASS trên code đã sửa, FAIL
  đúng điểm cũ khi kiểm ngược. P4 + P5 vẫn PASS toàn bộ
  trên nguồn đã sửa.
- NGOÀI phạm vi gói này (đã khai): C13 cụm phép toán trần
  còn lại (tiềm ẩn, bị chặn thượng nguồn), L1/L2 QualityMap
  (lệch thiết kế — cần quyết định sửa code hay sửa đặc tả),
  C1/C2 hiệu năng regex/O(n^2).

## GÓI SỬA LỚN ĐÃ ĐẨY v3 6781e582 (2026-11-12 ~17:24 CST)
- 9 file Swift (Parser, CaptureIntake, LineAssembly,
  Models, ReceiptViews, CardsView, ContentView,
  ReadPipeline, BenchView) — diff đối chiếu repo trước khi
  đẩy: đúng và chỉ đúng các hunk đã định (Leader tự kiểm).
- Hai lượt CI tự kích hoạt trên 6781e582 cần đọc kết quả:
  (1) build-ipa — biên dịch THẬT cả hai app, là cổng biên
  dịch đầu tiên cho các sửa tầng UI (harness không biên
  dịch tầng UI); (2) harness — cổng Luật 3 trên code cuối:
  control -> 33x100 -> ma trận -> fuzz.
- Run #19 (chỉ crash-fix 43cf53d6) vẫn đang ở Cổng 2 tại
  17:10 CST — census độc lập, kết quả đọc từ artifact sau.

## BUILD XANH + CONTROL ĐÓNG SỔ TRÊN CODE CUỐI (2026-11-12 17:25 CST)
- build-ipa run #80 (6781e582): SUCCESS — cả hai app biên
  dịch sạch với toàn bộ gói sửa (kể cả tầng UI ReceiptViews/
  CardsView/ContentView/ReadPipeline mà harness không biên
  dịch). 2 artifact IPA đã sinh.
- Harness run #20 (6781e582): control PASS — SURVIVED
  fixture kèm tóm tắt parse: vendor=Costco subtotal=12548
  tax=938 total=13486 items=20 sumItems=12548 sold=12
  card=2586 warnings=1. Tức luồng L-R01 đóng sổ TUYỆT ĐỐI
  bằng Swift thật (Σ món = subtotal; subtotal + thuế =
  total; 20 món gồm 8 dòng INST SV âm; đúng 12 món bán).
- Nhịp Cổng 2 đo từ run #19: ~35 set / 22 phút (~38s/set)
  -> 100 set ~64 phút. Run #19 dự kiến xong ~18:20 CST,
  run #20 (code cuối) ~18:45 CST (cộng ma trận + fuzz).

## CA TRỰC 18:40 CST 2026-11-12 — PHÁN QUYẾT HARNESS RUN #19 + #20: CỔNG 2 (LUẬT 100 LƯỢT) QUA TRÊN CẢ HAI, CỔNG 3 FUZZ CÒN ĐÚNG 1 CA CHẾT TRÊN CODE CUỐI
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế chốt D1–D7 21:44 ngày 2026-11-11) —
  ca quay lại luật chung, làm đúng MỘT bước: lấy phán quyết
  2 lượt harness đang chờ ở mục 17:25 (run #19 chỉ crash-fix
  43cf53d6 + run #20 code cuối 6781e582). Ca không sửa code,
  không đẩy code v3, không kích lượt chạy nào (đọc Actions
  qua trình duyệt, chỉ đọc).
- RUN #19 (43cf53d, run id 43325453133, 17:03–18:16 CST,
  completed/failure): Cổng 1 control PASS · **Cổng 2 LUẬT
  100 LƯỢT PASS** (1h05m28s; log "SET 100 DONE 33/33" +
  "SURVIVED images x100") · ma trận phụ PASS (7m20s) ·
  **Cổng 3 fuzz RỚT**: 40 ca — 32 PASS, **8 DIED (exit 133)**:
  weight-huge-mid · weight-huge-start · weight-barcode-lb-mid ·
  weight-inf-mid · box-nan-maxx-moneyline ·
  box-inf-maxx-moneyline · box-huge-maxx-moneyline ·
  box-nan-everywhere. Artifact harness-evidence-19 (174 KB).
- RUN #20 — CODE CUỐI (6781e582, run id 43328593696,
  17:24–18:39 CST, completed/failure): Cổng 1 control PASS ·
  **Cổng 2 LUẬT 100 LƯỢT PASS** (1h06m14s; "SET 100 DONE
  33/33" + "SURVIVED images x100") · ma trận phụ PASS
  (7m38s) · **Cổng 3 fuzz RỚT đúng 1 ca**: 40 ca — **39 PASS,
  1 DIED (exit 133): box-huge-maxx-moneyline**. Gói sửa lớn
  vì vậy đã diệt 7/8 ca fuzz chết của run #19 (toàn bộ họ
  weight-huge/inf + box-nan/inf/everywhere nay PASS); ca
  sống sót duy nhất là hộp có maxX KHỔNG LỒ trên dòng tiền —
  cùng họ trap A đã ghi ở mục ~12:55 (Int(Double) từ toạ độ
  hộp không qua cổng hữu hạn/biên trên đường dòng tiền),
  nhưng ca này KHÔNG tự kết luận điểm code — Leader khoanh
  bằng census/bisect của harness trước khi sửa.
- Tuyên bố trung thực — đã chứng minh: phán quyết từng
  cổng của run #19 + #20 kể trên, bằng đọc trực tiếp
  GitHub Actions (từng bước + log Cổng 2/Cổng 3) trong ca;
  chưa chứng minh: điểm trap cụ thể của box-huge-maxx-
  moneyline trong code cuối (chưa bisect, chưa đọc stack
  của ca này); chưa làm: chưa sửa trap còn lại, chưa có
  lượt harness XANH TRỌN nào — luật của anh (≥100 lượt sạch
  MỚI giao) đã đạt ở Cổng 2 trên ảnh thật nhưng Cổng 3 chưa
  qua nên CHƯA có bản giao, đóng băng giao bản vẫn nguyên,
  không kêu anh cài/test gì.
- **Bước tiếp theo: Leader (nhịp chat chính) sửa đúng ca
  fuzz box-huge-maxx-moneyline** (khoanh điểm trap bằng
  harness trước, sửa ở staging, kiểm tĩnh S10/P4/P5 ≡) →
  đẩy v3 → lượt harness kế tiếp phải XANH TRỌN cả 4 cổng
  (control + 100 lượt + ma trận + fuzz 40/40) mới tính
  chuẩn bị patch lớn giao anh.
- ĐẨY CUỐI CA 18:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `c85c9d22d9204d0f8a33c7f5cceaad11955a4bd2`. (Dòng này chỉ
  có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## CA TRỰC 20:40 CST 2026-11-12 — KHOANH BÀN GIẤY ĐIỂM TRAP CỦA box-huge-maxx-moneyline: Parser.swift:2025 (columnModel) — HỌ A, DẠNG HỮU-HẠN-KHỔNG-LỒ
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế chốt D1–D7 21:44 ngày 2026-11-11) —
  ca quay lại luật chung, làm đúng MỘT bước: khoanh điểm trap
  của ca fuzz chết duy nhất trên code cuối (mục 18:40 giao:
  "Leader khoanh bằng census/bisect của harness trước khi
  sửa") — ca này làm nửa bàn giấy của việc khoanh (census code
  + số học, đọc trực tiếp); bisect/stack trên harness vẫn là
  bằng chứng quyết định thuộc Leader. Ca không sửa code,
  không đẩy code v3, không kích lượt chạy nào.
- TRẠNG THÁI TỪ XA (đọc trực tiếp trong ca): đầu v3 VẪN là
  `6781e582` (gói sửa lớn) · đầu docs/planning VẪN là
  `c85c9d22` (commit ca 18:40) — chưa có sửa/run nào mới cho
  ca fuzz này kể từ mục 18:40.
- CHUỖI BẰNG CHỨNG KHOANH (mọi mắt xích đọc trực tiếp trong ca):
  (1) Định nghĩa ca fuzz — harness/HarnessApp/main.swift:
  401-403: `boxes[28] = CGRect(x: 0, y: 0.47, width: 1e17,
  height: 0.013)` → maxX = 1e17, HỮU HẠN. Fixture kiểm tận
  nơi: dòng 28 (0-based) của L-R01-raw-a-original.json đúng
  là "125.48" (tiền trần, y gốc 0.469 ≈ 0.47 của đột biến) —
  khớp chú thích tại main.swift:393-394.
  (2) Cổng vào fuzz — main.swift:642: chỉ gọi
  `ReceiptParser.parse(lines:boxes:)`, KHÔNG qua ráp dòng /
  bộ chấm. Trong Parser.swift, `boxes` chỉ được tiêu thụ ở
  đúng 1 chỗ: dòng 839-840 → geometricItems:2057 →
  columnModel:2010. Hai site bin Int((e/0.01)) còn lại KHÔNG
  tới được từ cổng fuzz này: CaptureIntake.moneyColumnBand
  (chỉ qua CandidateScorer ở chế độ images) và bin dy của
  LineAssembly stitch (chỉ ráp đa trang; bề rộng hộp không
  đụng centerY).
  (3) Chốt chặn hiện tại — Parser.swift:2015-2019: chỉ loại
  cạnh KHÔNG hữu hạn (`guard e.isFinite`). 1e17 hữu hạn →
  QUA chốt. Dòng 2025: `Int((e / 0.01).rounded())` =
  Int(1e19) > Int64.max 9.223e18 → Swift TRAP (khớp exit 133
  của ca chết). Số học kiểm bằng Python/IEEE-double trong
  ca: 1e17/0.01 = 1e19; ngưỡng trap: maxX ≳ 9.22e16.
  (4) Giải thích trọn vẹn mẫu run #20: hai ca anh em
  box-nan/box-inf bị chốt isFinite diệt → PASS; box-huge là
  ca HỮU-HẠN-tràn DUY NHẤT còn lại → DIED duy nhất. Khớp ứng
  viên A của HARNESS-REPRO §4 (columnModel, số dòng cũ
  :1999): gói sửa lớn đã diệt dạng không-hữu-hạn của A,
  chừa lại dạng hữu-hạn-khổng-lồ.
  (5) Site tiềm ẩn song sinh (ghi cho gói sửa, KHÔNG phải
  điểm chết của ca fuzz này): CaptureIntake.swift:524
  `bins[Int((e / 0.01)…)]` với chốt hữu-hạn tương tự ở
  :516-520 — tới được qua đường app/images (CandidateScorer),
  cùng họ lỗi; Leader quyết sửa chặn độ lớn ở CẢ hai site
  (và rà bin dy ở LineAssembly:430 cho trọn họ) hay chỉ site
  đã chết — ca này chỉ ghi nhận, không tự quyết thay.
- Tuyên bố trung thực — đã chứng minh: trạng thái từ xa +
  định nghĩa fuzz + nội dung fixture dòng 28 + chuỗi gọi
  parse→geometricItems→columnModel + văn bản chốt chặn +
  số học tràn Int, toàn bộ bằng đọc trực tiếp/chạy tính
  trong ca; chưa chứng minh: CHƯA có stack/bisect của riêng
  ca box-huge này được đọc — khoanh ở đây là mức bàn giấy
  (code + số học, mọi mắt xích đều sơ cấp) chứ không phải
  ngăn xếp CI; phán quyết cuối vẫn là lượt harness sau sửa
  XANH TRỌN 4 cổng. Chưa làm: chưa sửa dòng code nào, chưa
  chuẩn bị bản giao — đóng băng giao bản + luật 100 lượt
  vẫn nguyên, không kêu anh cài/test gì.
- **Bước tiếp theo (đã thu hẹp): Leader sửa chặn độ lớn tại
  Parser.swift:2025** (kèm quyết về site song sinh
  CaptureIntake:524) ở staging → kiểm tĩnh S10/P4/P5 ≡ →
  đẩy v3 → lượt harness kế tiếp phải XANH TRỌN cả 4 cổng
  (control + 100 lượt + ma trận + fuzz 40/40) mới tính
  chuẩn bị patch lớn giao anh.
- ĐẨY CUỐI CA 20:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `08527ad5135a7babd9ffacb429ce0bdabf712fb6`; đọc lại từ xa
  xác nhận đầu nhánh = commit này. (Dòng này chỉ có tại
  bàn, sẽ đi theo lần đẩy của ca sau.)

## TRAP-FIX HỌ A DẠNG HỮU-HẠN-KHỔNG-LỒ ĐÃ ĐẨY v3 30795b1c (2026-11-12 20:5x CST)
- Leader thi hành bước ca 20:40 khoanh: kiểm miền khoá bin
  |khoá| < 2^63 TRƯỚC Int() ở cả 3 site binning:
  Parser.columnModel (điểm chết của box-huge-maxx-moneyline),
  CaptureIntake.moneyColumnBand (thêm nil khi rỗng bin —
  chống ép mở max trên tập rỗng), LineAssembly stitch
  (lọc phiếu ngoài miền; rỗng hết -> neo mặc định như
  nhánh votes.isEmpty).
- Kiểm tĩnh trên nguồn đã sửa: P4 PASS toàn bộ, P5 PASS,
  S10 PASS.
- Lượt harness tự kích hoạt trên 30795b1c = ứng viên cổng
  Luật 3 trên code cuối thật: phải XANH TRỌN 4 cổng
  (control + 100 lượt + ma trận + fuzz 40/40) mới trình
  anh patch lớn. Thời lượng kỳ vọng ~1h20m theo nhịp run
  #20. Site tiềm ẩn cùng họ đã ghi nhận nhưng NGOÀI gói
  này: CaptureIntake:348/364 Int(CGFloat) kẹp sau đổi
  (đầu vào bị chặn bởi producer — FULL-REVIEW mức tiềm ẩn).

## CA TRỰC 22:40 CST 2026-11-12 — PHÁN QUYẾT RUN #21 TRÊN 30795b1c: XANH TRỌN CẢ 4 CỔNG — ĐIỀU KIỆN CHUẨN BỊ PATCH LỚN ĐÃ ĐẠT
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế chốt D1–D7 21:44 ngày 2026-11-11) —
  ca quay lại luật chung, làm đúng MỘT bước: đọc phán quyết
  lượt harness trên commit trap-fix 30795b1c (mục cuối file
  giao: "lượt harness kế tiếp phải XANH TRỌN cả 4 cổng mới
  tính chuẩn bị patch lớn giao anh"). Ca không sửa code,
  không đẩy code, không kích lượt chạy nào.
- KẾT QUẢ (đọc trực tiếp GitHub Actions trong ca, qua trình
  duyệt đã đăng nhập — MCP GitHub không có công cụ Actions):
  run #21 "Harness — cổng tự chạy 100 lượt" trên 30795b1c
  (đẩy 03:02:01Z = 21:02 CST), SUCCESS, tổng 1h15m45s, kết
  thúc 22:17 CST; commit page: "Status checks: success, 2/2";
  artifact bằng chứng harness-evidence-21 (171 KB,
  sha256 b4e5ed2b…).
  · Control: PASS — "SURVIVED fixture" (costco · subtotal
    12548 · tax 938 · total 13486 · 20 món · sumItems 12548
    · warnings 1).
  · 100 lượt: PASS — "SET 100 DONE 33/33" + "SURVIVED
    images x100" (100/100 bộ × 33 ảnh = 3.300 lượt ảnh).
  · Ma trận phụ: PASS — 4/4 cấu hình (current topk=1 ·
    current topk=3 · old vi-VN topk=3 · en-US topk=1) đều
    "SET 3 DONE 33/33" + "SURVIVED images x3".
  · Fuzz: PASS 40/40 — ca chết duy nhất của run #20,
    box-huge-maxx-moneyline, nay PASS. (Ghi chú nhãn: trong
    workflow, bước fuzz mang nhãn "Cổng 3 — bẫy đột biến",
    bước ma trận không mang số cổng; bốn phần trên khớp
    đúng danh sách 4 cổng của mục 18:40.)
- Hệ quả theo luật đã chốt: điều kiện "harness XANH TRỌN
  trên code cuối thật" của Luật 3 NAY ĐÃ ĐẠT trên commit
  30795b1c. Đóng băng giao bản vẫn nguyên cho tới khi patch
  lớn được chuẩn bị + trình anh ở chat chính — ca trực
  không tự chuẩn bị bản giao, không kêu anh cài/test gì
  trong ca này.
- Tuyên bố trung thực — đã chứng minh: phán quyết run #21
  từng cổng bằng log job đọc trực tiếp trên GitHub Actions
  (job 131658680956, run 43356189848); chưa chứng minh:
  chất lượng ĐỌC (đúng số/món) trên máy thật của anh — cổng
  harness chỉ phán sống/chết + đối soát control, việc đọc
  đúng ở thiết bị vẫn thuộc lần test patch lớn của anh;
  chưa làm: chưa chuẩn bị patch lớn (thuộc Leader/chat
  chính), chưa hợp v3 vào bản giao.
- **Bước tiếp theo: Leader (nhịp chat chính) chuẩn bị PATCH
  LỚN trên nền 30795b1c** (đây là loại patch phải trình anh
  duyệt theo luật GitHub 2026-11-12) → anh duyệt mới build
  bản giao cài đặt; trước lúc đó không giao bản nào.
- ĐẨY CUỐI CA 22:40: **THÀNH CÔNG** — đúng 1 lần, 1 file
  (WORK-STATE.md), commit mới trên docs/planning:
  `5668bc8bce734ffc7b21e197e917e0ed4d23e169`; đọc lại từ xa
  (list_commits) xác nhận đầu nhánh = commit này. (Dòng này
  chỉ có tại bàn, sẽ đi theo lần đẩy của ca sau.)

## ★ HARNESS RUN #21 XANH TRỌN 4 CỔNG (30795b1c) + ĐÃ NÂNG TEM core-v3-2 CHO BẢN GIAO (2026-11-12 22:4x-23:1x CST)
- Ca 22:40 đọc trực tiếp Actions: run #21 (43356189848,
  21:02-22:17 CST) XANH TRỌN: control PASS (sổ đóng tuyệt
  đối) · Cổng 2 100 lượt PASS (SET 100 DONE 33/33) · ma
  trận PASS 4/4 · fuzz PASS 40/40 (box-huge đã qua).
  => Điều kiện Luật 3 "harness xanh trọn trên code cuối
  thật" ĐÃ ĐẠT trên 30795b1c.
- Leader chốt bản giao: nâng tem bộ đọc core-v3-1 ->
  core-v3-2 (ReadPipeline.swift, chỉ đổi hằng tem + chú
  thích) để bản giao tự khai trên máy anh (B2 Điều 3);
  đẩy v3 = 3d530b5f. Lượt harness XÁC NHẬN trên đúng
  commit giao + build-ipa của commit này là điều kiện
  cuối trước khi trình anh patch lớn kèm IPA đã kiểm
  gói tại bàn (kỳ vọng verdict ~00:35 CST).
- Chưa kiểm được (ghi vào tin giao bản): chất lượng đọc
  trên máy thật của anh + hành vi cài-đè/dữ liệu đã lưu —
  thuộc lần test patch lớn của anh; phiên GATE100-v2
  (115 lượt, hoá đơn niêm phong) vẫn ở phía trước.

## LUẬT HẠN MỨC BUILD GITHUB (anh ban hành 2026-11-12 23:16 CST)
- Anh: "Hạn chế build ipa khi không cần thiết... Chỉ build
  khi thật sự cần thiết" (đã ghi MEMORY.md). Hạn mức
  Actions của tài khoản đã cạn vì các đợt build dồn dập
  (kho riêng tư -> phút macOS trừ quota miễn phí).
- Áp dụng ngay cho bản giao core-v3-2: lượt harness xác
  nhận trên 3d530b5f là THỪA (run #21 đã xanh trọn trên
  logic byte-identical; delta duy nhất là hằng tem) —
  Leader đã giao trình duyệt HUỶ lượt đó nếu còn queued/
  running; build-ipa của commit giao thì giữ (đó là lượt
  tạo IPA giao bản — thật sự cần). Kết quả huỷ + trạng
  thái build-ipa (cả 30795b1c lẫn 3d530b5f) chờ báo cáo
  trình duyệt xác nhận, sẽ ghi tiếp tại đây.
- Kỷ luật từ nay: gom thay đổi, build ở mốc; không
  dispatch vì thay đổi trang trí.

## ★★ BẢN GIAO PATCH LỚN core-v3-1 ĐÃ TRÌNH ANH (2026-11-12 23:2x CST)
- Hai lượt của commit tem 3d530b5f (harness #22 + build
  #82) CHẾT 3-4s tại cổng thanh toán tài khoản GitHub
  ("recent account payments have failed or your spending
  limit needs to be increased") — hạn mức đã cạn hẳn theo
  luật anh vừa ban hành 23:16; không build riêng tư nào
  khởi động được tới khi anh xử lý Billing & plans.
- BẢN GIAO = IPA của build-ipa run #81 trên commit
  30795b1c — ĐÚNG commit harness run #21 xanh trọn 4
  cổng (bằng chứng tải về đọc tại bàn: control SURVIVED
  đóng sổ; images SET 100 DONE + SURVIVED x100; matrix
  4/4 SURVIVED; fuzz 40 PASS / 0 DIED).
- IPA đã kiểm gói tại bàn: sha256 3003acc733d18502f9…;
  bundle có vendors.json + lexicon.json, KHÔNG có ảnh
  bench; binary có "Bản bộ đọc của app" + "Lưu không
  thành công" (chuỗi của gói sửa). Tem trong app =
  core-v3-1 (bản nâng tem v3-2 không build được vì cổng
  thanh toán — đã khai rõ trong tin giao).
- File giao: downloads/SoHoaDon-V3-run81-2026-11-13.ipa
  đính kèm trong chat. Chờ anh ký/cài/test theo nhịp của
  anh (patch lớn — Luật 2/3). GATE100-v2 vẫn ở phía trước.

## HARNESS CHUYỂN CHỈ-CHẠY-THỦ-CÔNG (lệnh anh qua chat chính 2026-11-12 23:48 CST)
- Số liệu anh cung cấp: Actions tháng này đã cạn $18
  miễn phí gói Pro; riêng Sohoadon tốn $17.57 — phần lớn
  do harness tự chạy theo mỗi lần đẩy code. Anh đã nâng
  budget tài khoản lên $40 (có trần dừng) và ra lệnh
  Sohoadon không được xài hết budget.
- ĐÃ SỬA trigger của .github/workflows/harness-ci.yml
  trên CẢ main (d41e149) + v3 (6b03857) qua web editor:
  bỏ hẳn khối push (branches v3 + paths), chỉ còn
  workflow_dispatch. Leader tự đọc lại từ xa cả hai
  nhánh xác nhận: không còn "push:" trong file.
- Build unsigned IPA: GIỮ nguyên trigger theo push
  (~1 phút/lượt, rẻ) theo đúng chỉ thị.
- Luật vận hành từ nay: trước khi bấm chạy tay harness
  toàn phần phải cân chi phí (macOS $0.08/phút, một
  lượt ≈ 76 phút ≈ $6) — chỉ chạy ở cổng quyết định
  trước patch lớn. Luật 100 lượt giữ nguyên 100%.
- Bản nháp tại harness/workflow/harness-ci.yml đã khớp
  (trigger + ghi chú chi phí ở đầu file).

## ★★★ ANH TEST TRÊN MÁY THẬT: L-R01 ĐỌC ĐÚNG TUYỆT ĐỐI (2026-11-13 00:04 CST)
- Anh cài bản run81 (core-v3-1), nhập lại ảnh L-R01
  (Costco — tờ từng làm chết app) và gửi 4 ảnh chụp màn
  Kiểm Lại. Leader đối chiếu từng dòng với chân lý đã
  đóng băng:
  * 20/20 dòng món ĐÚNG TỪNG XU: 12 dòng dương cộng
    154.98; 8 dòng INST SV trừ đúng 29.50; hiệu =
    125.48 = tiểu tổng in trên hoá đơn. Dòng chết cũ
    "3006152 BOUNCE 400 $11.49" nay là món đầu tiên,
    đọc đúng nguyên vẹn.
  * Tiểu tổng 125.48 ✓ · thuế 9.38 ✓ (app tự ghi: khôi
    phục nhờ đọc lại vùng ảnh vòng 1 — cơ chế ROI chạy
    thật trên máy anh) · TỔNG 134.86 ✓ · độ tin cậy
    tổng 100%.
  * Tiệm Costco ✓ · ngày Sep 14, 2026 2:17 PM ✓ ·
    địa chỉ 10220 S. Memorial Drive ✓ · thẻ 2586 ✓ ·
    gợi ý phân loại BUSINESS theo thẻ đã đăng ký ✓.
  * KHÔNG crash — toàn bộ luồng nhập ảnh -> đọc ->
    Kiểm Lại chạy trọn trên iPhone của anh.
- Ý nghĩa: bằng chứng Điều 1 trên máy thật cho bản giao
  — cơ chế crash đã chết trên thiết bị thật, không chỉ
  trên harness. Giới hạn trung thực: L-R01 là ca trong
  bộ mẫu đã đóng băng (hồi quy), chưa phải hoá đơn niêm
  phong; chất lượng trên hoá đơn CHƯA TỪNG THẤY vẫn chờ
  phiên GATE100-v2 phán quyết.

## LỆNH ĐÊM 2026-11-13 (anh, 00:09 CST) — KIỂM TOÀN APP+LÕI, HOÁ ĐƠN MẠNG, UI MỚI
- Anh duyệt hướng: tiếp tục rà soát toàn app + lõi, thấy
  lỗi thì sửa; tìm file hoá đơn TRÊN MẠNG làm mẫu thử
  lạ (ngoài bộ đóng băng); THIẾT KẾ LẠI UI đẹp + chuyên
  nghiệp như các app top cùng dịch vụ trên App Store.
- GIAO SÁNG MAI: (1) bản IPA UI mới, (2) báo cáo việc
  làm trong đêm.
- RÀO CHI PHÍ (luật budget anh vừa ban hành): tối đa MỘT
  lượt harness toàn phần trong đêm (chỉ khi có sửa lõi
  cần cổng, hoặc chạy cổng kèm bộ hoá đơn lạ); build-ipa
  chỉ cho commit giao sáng (1-2 lượt rẻ). Mọi chi phí CI
  phải kê khai trong báo cáo sáng.
- Hàng việc đêm (Leader điều phối + ca trực hỗ trợ):
  Q1 Rà soát vòng 2 toàn app+lõi (gồm các điểm hoãn của
     FULL-REVIEW: C13, CaptureIntake:348/364, L1/L2,
     C1/C2) -> sửa những gì sửa an toàn tại bàn.
  Q2 Săn hoá đơn mạng: 10-15 tờ Mỹ ngoài bộ mẫu (nhiều
     ngành: siêu thị, nhà hàng, xăng, dược, điện máy —
     ưu tiên có Best Buy), tải về + ghi nguồn + Leader
     đọc tay lập chân lý từng tờ.
  Q3 Thiết kế lại UI (CHỈ lớp hiển thị — cấm đổi logic;
     diff rà soát từng hunk): hệ thống khoảng cách/màu/
     chữ thống nhất, danh sách + chi tiết + kiểm lại +
     thẻ theo chuẩn app top (Expensify/Veryfi/QuickBooks).
  Q4 Đóng gói sáng: build-ipa 1 lượt trên commit cuối ->
     kiểm gói -> trình anh kèm báo cáo đêm.

## TIẾN ĐỘ ĐÊM 2026-11-13 (Leader, ~00:30 CST)
- Đã cử 2 tuyến song song: (A) rà soát vòng 2 toàn app+lõi
  (chỉ đọc+báo cáo), (B) săn 10-15 hoá đơn Mỹ trên mạng
  ngoài bộ mẫu + lập chân lý đọc tay (web-receipts/).
- UI PASS 1 ĐÃ LÀM Ở STAGING (chỉ lớp hiển thị):
  DesignSystem.swift MỚI (token màu/khoảng cách/bo góc +
  DSCard/StatusChip/VendorMonogram/PrimaryButtonStyle/
  MoneyAmount) + project.yml nạp file mới vào target
  chính; Theme nâng sáng cho nền tối (Cá nhân #0A84FF,
  Business #FF9F0A); Home dựng lại (hero tổng năm + thanh
  tỉ lệ + banner chờ duyệt dạng thẻ + thẻ Theo mục/Gần
  đây); ReceiptRowView (thumbnail bo 10 + monogram +
  chip CHỜ DUYỆT); Chi tiết thêm thẻ hero (monogram +
  tổng lớn + chip trạng thái); Kiểm Lại (tổng nhuộm màu
  thương hiệu, nút Lưu PrimaryButtonStyle, món semibold);
  Thẻ (gradient + bóng + chip loại); Chụp (biểu tượng
  thương hiệu + nút Quét chính); màn Khoá + tint tab.
  Kiểm tĩnh sau sửa: P4 PASS toàn bộ (đã cập nhật S5b
  tem core-v3-2 + tập file kỳ vọng thêm DesignSystem),
  P5 PASS, S10 PASS, cân bằng ngoặc 7/7 file = 0.
- CHƯA đẩy code: chờ báo cáo rà soát (sửa an toàn gộp
  một lần) + rà soát diff UI từng hunk (cấm đổi logic)
  rồi mới đẩy 1 commit + build-ipa 1 lượt cho bản sáng.

### Đêm 2026-11-13 — tiến triển ~00:45 CST (bổ sung)
- RÀ SOÁT VÒNG 2 XONG (audit2/AUDIT2-REPORT.md): 14 nhóm.
  Điểm cân bằng: MỌI điểm chết đợt 1 kiểm lại ĐÃ ĐÓNG;
  không crash mới nào tới được bằng dữ liệu OCR thật.
  ĐÃ SỬA trong staging: A2-01 (CaptureIntake
  LuminanceGrid: clampedCoord [-1,2] TRƯỚC khi đổi Int ở
  cả 2 hàm + guard samples.count — đúng họ trap box-huge
  còn sót 2 site), A2-06 (ScanView renderPageImage: trần
  cạnh dài 4096px cho PDF), A2-08 (DiagParseSnapshot thêm
  vendorDataVersion + finalize nạp từ parsedBeforeReconcile
  — cộng trường Optional, tương thích ngược), A2-13-nhãn
  (tilePolicyID "full-frame-v3-p4" -> "full-frame-v3").
  TRÌ HOÃN có ghi lý do: A2-02 cache regex + A2-03 O(n^2)
  (hiệu năng — gói lõi kế tiếp, không mổ Parser đêm trước
  bản giao), A2-09 kỷ luật số học C13 (bị chặn thượng
  nguồn, không tới được), A2-07/A2-10/A2-11/A2-12 (ghi
  nhận), A2-04/A2-05 = L1/L2 CHỜ QUYẾT ĐỊNH sửa-code-hay-
  sửa-đặc-tả của anh (báo cáo sáng nêu lại).
- HOÁ ĐƠN WEB: tuyến săn trả 10 tờ; LEADER ĐÃ TỰ MỞ ĐỌC
  LẠI TỪNG ẢNH và khoá chân lý ở web-receipts/FREEZE-WR.md
  (Best Buy 397.94/27.86/425.80; Trader Joe's 75 món
  173.95/12.11/186.06 VISA 1694 — ảnh XOAY 90°; Starbucks
  40.80/2.27/43.07 + SBUX x3862; McDonald's 3.17/0.24/3.41;
  Wendy's 9.58/0.84/10.42; Walgreens tổng 28.99 VISA Debit
  9765; CVS 0.51*/0.29*/0.80* in-cent-mơ-hồ; Target gift
  0.39/0.02/0.41 ảnh 100MP; Shell tổng 20.00; Dollar Tree
  5.00/0.25/5.25 ba cột). Đã nạp vào staging BenchImages
  (33 -> 43) + project.yml + cổng P4 S6c = 43; kiểm tĩnh
  P4/P5/S10 PASS sau mọi sửa.
- ĐẨY: ảnh WR đang tải lên repo qua trình duyệt (connector
  không đẩy được binary); xong sẽ đẩy 1 commit connector
  (11 file chữ: UI + DesignSystem + 3 file lõi sửa + 
  project.yml) rồi KÍCH HARNESS TAY 1 LƯỢT trên corpus 43
  (cổng Luật 3 cho lõi đã đổi; ~1h50m, ~$9 — kê khai sáng).
- ĐÃ ĐẨY (00:2x CST): ảnh WR lên repo qua trình duyệt —
  commit d8199d0 (BenchImages đủ 43, trình duyệt mở lại
  thư mục xác nhận). Commit chữ qua connector: v3 HEAD =
  1a0ff281 "Ban dem 2026-11-13: UI moi (DesignSystem) +
  sua A2-01/A2-06/A2-08 + project.yml corpus 43 anh"
  (11 file). Đang chờ: build-ipa tự chạy cho 1a0ff281 +
  kích harness tay (qua trình duyệt) — verdict là cổng
  giao bản sáng.
- CI ĐÃ KÍCH (00:27 CST): build-ipa run #86 (id
  43378815819, commit 1a0ff281) đang chạy; harness run
  #23 (id 43378874694) đã kích TAY trên v3 @1a0ff281 —
  cổng Luật 3 trên corpus 43 ảnh, dự ~1h50m (~02:30 CST
  xong; chi phí dự ~$9-11 gồm cả build-ipa — kê khai
  chính xác trong báo cáo sáng kèm số phút thật).
  SÁNG: đọc verdict harness #23 + tải/kiểm gói IPA #86
  -> trình anh bản UI mới + báo cáo đêm đầy đủ.
- TÊN + ICON (lệnh anh 00:32 CST): app mang tên
  GL-Keeper. Icon mẫu A (hoá đơn + tích + khiên hổ phách,
  nền xanh ngọc) đã xử lý 1024x1024 tràn viền, kiểm đọc ở
  60px rõ; mẫu B monogram GL giữ ở icon-work/ làm phương
  án thay thế. Đã đẩy: commit 023be82d (project.yml:
  CFBundleDisplayName GL-Keeper + ASSETCATALOG AppIcon +
  sources Assets.xcassets; 2 Contents.json; tiêu đề
  HomeView/ContentView đổi GL-Keeper). Kiểm tĩnh P4 đã
  cập nhật kỳ vọng S6a (+Assets.xcassets) PASS toàn bộ.
  Đang tải icon-1024.png qua trình duyệt vào
  Assets.xcassets/AppIcon.appiconset/ — bản build-ipa
  trên commit CUỐI (đủ icon) mới là bản giao sáng; lượt
  trung gian (thiếu PNG) đỏ là dự kiến, bỏ qua.
  LƯU Ý PHẠM VI CỔNG: harness #23 kiểm commit 1a0ff281;
  các commit sau (023be82d + icon) CHỈ chạm tên/icon/tiêu
  đề hiển thị — không file lõi nào đổi — verdict #23 áp
  cho lõi của bản giao, khai rõ trong báo cáo sáng.

## CA TRỰC 00:40 CST 2026-11-13 — KIỂM CHỨNG TỪ XA ICON ĐÃ LÊN v3: COMMIT CUỐI 8ddf280f, BYTE-TRÙNG BẢN TẠI BÀN
- Cổng đóng băng nghiên cứu: ĐÃ HẾT HIỆU LỰC (anh duyệt hướng
  21:02 + duyệt thiết kế chốt D1–D7 21:44 ngày 2026-11-11) —
  ca quay lại luật chung, làm đúng MỘT bước: kiểm chứng việc
  "đang tải icon-1024.png" mà mục cuối trước ca này còn ghi dở.
  Ca không sửa code, không đẩy code v3, không kích lượt CI nào.
- KẾT QUẢ (đọc trực tiếp GitHub trong ca): đầu nhánh v3 =
  `8ddf280f3e58bc70073247a60795f2dc14699009` "GL-Keeper: icon
  1024" (06:35:21Z = 00:35 CST), ngay sau 023be82d. Thư mục
  `Assets.xcassets/AppIcon.appiconset/` trên HEAD này đủ 2 file:
  Contents.json (213 byte, blob `27a4f381…`) + icon-1024.png
  (214.478 byte, blob `c936d63d167811cf67c14e3757a1959bc5465732`).
- ĐỐI CHIẾU TẠI BÀN: `git hash-object` trên
  v3-phase4/app/Assets.xcassets/AppIcon.appiconset/ cho ĐÚNG 2
  blob trên; icon tại bàn sha256 `9d5a8dac…`, 1024×1024 RGB —
  icon trên repo byte-trùng bản đã kiểm ở staging. Việc tải
  icon của Leader vì vậy ĐÃ XONG; commit cuối đủ icon đúng như
  mục trước dự kiến.
- Tuyên bố trung thực — đã chứng minh: icon đã lên repo ở
  commit cuối, đúng đường + byte-trùng, bằng đọc trực tiếp
  GitHub + hash tại bàn; chưa chứng minh: build-ipa trên
  commit cuối 8ddf280f đã xanh / IPA có icon trong gói — ca
  này không đọc Actions (harness #23 trên 1a0ff281 còn chạy
  theo kế hoạch, verdict dự ~02:30 CST thuộc nhịp sáng của
  Leader); chưa làm: chưa kiểm gói IPA nào của đêm nay.
- **Bước tiếp theo giữ nguyên: Leader (nhịp sáng) đọc verdict
  harness #23 + build-ipa của commit cuối 8ddf280f → kiểm gói
  IPA → trình anh bản UI mới + báo cáo đêm.** Ca này không kêu
  anh cài/test gì.

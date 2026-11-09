# BUILD 2 — KẾ HOẠCH TỔNG (MASTER PLAN)

**Người soạn:** Chuyên gia Tổng hợp & Sản phẩm — theo lệnh của anh (2026-11-08
23:31 CST): *"Đưa 1 chuyên gia để tổng kết và lên ý tưởng rõ ràng"* và *"Build
từ từ thật chắc chứ ko build vội vàng"*.
**Vai trò của tài liệu này:** ĐÂY là bản kế hoạch duy nhất cả đội code theo cho
Build 2 (TEAM.md, mục Nhịp độ). Mọi tài liệu khác là đầu vào; khi có mâu thuẫn,
mục 5 của bản này là nơi đã xử lý và ghi lý do.

**Đầu vào đã tổng hợp (đọc đủ, trích dẫn theo tên file ở từng mục):**
1. `team-mission1/QA-VERDICT.md` — phán quyết Mission 1: **Build 1 = NỀN TẢNG ✓ /
   DÙNG HẰNG NGÀY ✗**; thứ tự tầng Build 2 ở **Phụ lục B** là bản có hiệu lực
   (Tầng 0 chất lượng đọc → Tầng 1 niềm tin dữ liệu → Tầng 2 đúng luật →
   Tầng 3–4 hiệu năng/thiết kế).
2. `team-mission1/CODE-AUDIT.md` — đặc tả sửa lỗi F1/F2/F3 kèm mã mẫu và bài
   nghiệm thu §F; các lỗi B-2…B-10, C-1…C-18.
3. `team-mission1/DESIGN-AUDIT.md` — 54 điểm kiểm (đạt 20), đặc tả thiết kế
   Build 2 ở §4 (viết sẵn tới mức code được ngay), và Leader Note 23:24 CST.
4. `team-mission1/ACCOUNTING-SPEC.md` — bộ trường chuẩn (~30 trường, 6 nhóm),
   luật kiểm chứng V1–V10, định nghĩa "hoàn chỉnh" (§2.2), 10 điều cấm (§4),
   và bảng chấm model Build 1 (§5).
5. `team-mission1/TOP-APPS-RESEARCH.md` — nghiên cứu app top đợt 2: pipeline
   đọc của Expensify/Dext/SparkReceipt/QuickBooks/Veryfi/Shoeboxed/Scanner
   Pro/Genius Scan/Apple; UX sửa lỗi; bảng ý tưởng xếp hạng §3.1; dataset
   công khai §4. **Đã về kịp — không còn mục nào chờ đầu vào này.**

Quy ước: khẳng định nào cũng ghi nguồn file. Chỗ nào là suy luận của chuyên
gia tổng hợp thì ghi **[TỔNG HỢP]**; chỗ chưa kiểm chứng ghi **[CHƯA KIỂM CHỨNG]**.

---

## 1. Ý TƯỞNG CHỦ ĐẠO — 8 ý tưởng làm nên Build 2

### Ý 1 — Một bộ trường chuẩn cho MỌI hoá đơn, không khuôn theo tiệm
App không học "hoá đơn Sam's trông thế nào, hoá đơn Home Depot trông thế nào"
nữa. Chuyên gia Kế toán đã định nghĩa **bộ trường chuẩn** mà tờ hoá đơn nào
cũng phải lấy được: tên tiệm + địa chỉ, ngày giờ, từng món, các dòng thuế để
riêng thành danh sách, tổng tiền, tip để riêng (nhà hàng), cách trả tiền +
đuôi thẻ chỉ từ dòng bị che, mục chi kèm mã dòng Schedule C, ghi chú mục đích
business, ảnh gốc đầy đủ mọi trang (ACCOUNTING-SPEC §0–§1).
- **Vì sao:** lệnh đổi hướng của anh 23:25 CST (TEAM.md) — mỗi nhà hàng/market
  in một kiểu, học từng khuôn là không hết. Nghiên cứu app top xác nhận đây
  là hướng của cả ngành: Veryfi nói thẳng mô hình của họ hiểu mọi bố cục,
  **không cần template** (TOP-APPS-RESEARCH §0.3, §1.7b).
- **Anh được gì:** hoá đơn của bất kỳ tiệm nào — kể cả tiệm app chưa từng gặp —
  vẫn được đọc theo cùng một chuẩn; phần nào thiếu thì vào Hộp Chờ, app không
  đoán bừa.

### Ý 2 — File PDF là "sự thật tuyệt đối": đọc thẳng lớp chữ, không qua OCR
Hoá đơn anh tải từ Sam's/Best Buy là file số do máy tính của tiệm tạo ra —
chữ nằm sẵn trong file, chính xác 100%. Build 2 mở đường nạp **Files + Chia sẻ,
nhiều file một lúc**; gặp PDF thì trích lớp chữ đưa thẳng vào bộ bóc tách,
chỉ khi PDF không có lớp chữ (scan thành ảnh) mới chuyển sang đường đọc ảnh
(CODE-AUDIT F1; QA-VERDICT Phụ lục B, mục 0.2).
- **Vì sao:** Build 1 không có nổi đường nạp PDF (grep = 0 PDFKit) — nguồn
  hoá đơn chính của anh bị ép đi qua đường đọc yếu nhất, hoặc không nạp được
  (CODE-AUDIT F1). Bản prototype ngày đầu đã chứng minh: cùng tờ Sam's, đưa
  bản chép chữ đúng thì bóc tách đạt 100% (BLUEPRINT / parser-prototype).
- **Anh được gì:** toàn bộ hoá đơn tải về — phần lớn đống hồ sơ của anh — hết
  lỗi đọc số. Đây là đường tắt qua mặt cả vấn đề OCR.

### Ý 3 — Hai engine đọc thi đấu, BẢNG ĐIỂM quyết định, thua là bỏ
Hai ứng viên đọc ảnh: **(a)** Vision cổ điển + tiền xử lý ảnh (cắt theo viền
hoá đơn, nắn thẳng, tăng tương phản) + ráp hàng theo cột; **(b)** engine hiểu
cấu trúc tài liệu của iOS 26 (`RecognizeDocumentsRequest` — trả về đoạn/bảng/
danh sách, tự bắt ngày và tiền) chạy trong **một bản test pipeline riêng**,
cô lập rủi ro đổi SDK (QA-VERDICT Phụ lục B, mục 0.1; CODE-AUDIT Leader
Addendum #2). Cả hai chấm trên CÙNG bộ mẫu cố định; ai điểm cao hơn thì
thắng, engine thua bị loại hẳn — không lai ghép mập mờ.
- **Vì sao:** đây là điểm yếu đã chứng minh bằng 2 lần test thật (tổng tiền
  trượt 0/2). Nghiên cứu xác nhận (b) là "bước nhảy on-device thật sự duy
  nhất hiện có" (TOP-APPS-RESEARCH §0.6), nhưng Apple **không công bố** độ
  chính xác của nó trên hoá đơn (§5) — nên phải đo trên hoá đơn của chính
  anh, không tin quảng cáo của ai.
- **Anh được gì:** quyết định engine bằng số đo trên hoá đơn thật của anh,
  không bằng cảm tính của đội.

### Ý 4 — Hai lượt đọc + số học làm trọng tài
Khi đọc một tờ hoá đơn, app đọc **hai lượt độc lập** (ảnh gốc và ảnh đã tăng
nét; hoặc hai cấu hình của engine thắng cuộc — xem cách xử lý xung đột ở
mục 5.1). Hai kết quả **khớp nhau và qua được các phép kiểm số học** (cộng
dòng = subtotal, subtotal + thuế = tổng…) thì độ tin cậy cao; **lệch nhau
thì gắn cờ và đưa cả hai ứng viên cho anh chọn** — app không tự quyết số nào
đúng (TOP-APPS-RESEARCH ý #4, §2.12).
- **Vì sao:** một thí nghiệm độc lập công khai cho thấy model đọc hoá đơn
  xịn rơi từ 88% → ~51% khi gặp hoá đơn đời thật chưa từng thấy, nhưng khi
  cộng kiểm chứng số học làm trọng tài thì hệ thống *biết được tờ nào đáng
  tin* (93% số tờ được "tick xanh" là đúng thật) (TOP-APPS-RESEARCH §2.12).
  Với hồ sơ thuế, "đọc sai mà im lặng" là lỗi nguy hiểm nhất — ý này biến
  "không chắc" thành tín hiệu đo được.
- **Anh được gì:** app thà báo "tờ này em chưa chắc" còn hơn đưa số sai vào
  sổ một cách lặng lẽ.

### Ý 5 — Kho dữ liệu phải đủ chỗ chứa sự thật TRƯỚC khi đọc tốt hơn
Model dữ liệu Build 1 đang **làm mất dữ kiện ngay từ tầng lưu**: thuế bị gộp
1 số (mất cơ cấu TAX 1/TAX 2), không có trường tip, không phân loại theo
từng dòng món, chỉ chứa được 1 ảnh gốc, không có hình thức thanh toán…
(ACCOUNTING-SPEC §5.2 — 5 thiếu hụt mức CAO, 7 mức TRUNG). Build 2 hoàn
thiện model theo đúng thứ tự chuyên gia Kế toán đã xếp: **các dòng thuế →
tip → phân loại cấp dòng → nhiều ảnh gốc → hình thức thanh toán + địa chỉ
tiệm → mã dòng Schedule C + dấu vết duyệt/sửa** (ACCOUNTING-SPEC §5.2, đoạn
kết).
- **Vì sao:** engine đọc có tốt đến đâu mà kho không có chỗ chứa thì dữ kiện
  vẫn mất. Và đường PDF (Ý 2) cần chỗ lưu file gốc + nguồn nạp; bài nghiệm
  thu §F đòi hiển thị 2 dòng thuế riêng — tất cả đều cần model mới trước.
- **Anh được gì:** tờ hoá đơn được lưu *đúng như nó in* — sau này IRS hay
  người làm thuế hỏi tới đâu, dữ kiện còn tới đó.

### Ý 6 — Không bịa số: kiểm chứng V1–V10 và luật "hoàn chỉnh" là cổng dữ liệu
Mọi hoá đơn đều qua 10 phép kiểm của kế toán (ACCOUNTING-SPEC §2.1): cộng
dòng khớp subtotal (lệch ≤ 2 cent), subtotal + thuế khớp tổng, số lượng ×
đơn giá khớp thành tiền, tổng số món khớp dòng "# ITEMS SOLD", chống trùng
2 lớp, đuôi thẻ chỉ nhận từ dòng bị che… Lệch là **gắn cờ, ở lại Hộp Chờ** —
tuyệt đối không tự sửa số cho khớp (ACCOUNTING-SPEC §4, điều cấm 1). Một tờ
chỉ thành "chính thức" khi đủ 6 điều kiện hoàn chỉnh (ACCOUNTING-SPEC §2.2):
có ảnh gốc, có tiệm/ngày/tổng, số học đạt *hoặc* anh đã nhìn ảnh và xác
nhận kèm cờ, phân loại đã quyết kèm lý do, business thì có mục + dòng
Schedule C + ghi chú mục đích, thẻ khớp sổ đăng ký hoặc anh xác nhận thẻ lạ.
- **Vì sao:** Build 1 có 3 lỗ rò ở cổng này (nút Duyệt cho qua vô điều kiện;
  tổng ở Trang Chủ/Báo Cáo tính cả tờ chưa duyệt như chính thức; sửa số xong
  không chạy lại kiểm chứng) — QA-VERDICT §1.3 (C-1/C-2/C-3). Cộng thêm lỗi
  B-2: lưu hỏng mà vẫn báo "Đã lưu ✓" — mất hoá đơn trong im lặng.
- **Anh được gì:** con số nào đã vào tổng năm là con số đứng được khi kiểm
  tra; con số nào chưa chắc chắn thì luôn đeo cờ, không trà trộn.

### Ý 7 — Máy đọc nháp, anh duyệt NHANH: biến Hộp Chờ thành thao tác vài giây
Sự thật ngành phải nói thẳng: mọi app đọc giỏi nhất đều là **cloud + mô hình
huấn luyện trên hàng trăm triệu hoá đơn + có người kiểm** (Expensify, Dext,
Veryfi, Shoeboxed — TOP-APPS-RESEARCH §0.1, §1.8). Mình **không có và không
dùng server** — nên mình copy *kiến trúc* của họ: máy làm bản nháp nhanh,
còn "người kiểm" chính là anh, và việc của Build 2 là làm vòng duyệt đó rẻ
nhất có thể, học từ UX sửa lỗi của họ:
- **Chạm vào 1 trường → app highlight đúng vùng chữ đó trên ảnh gốc** để đối
  chiếu 1 giây (học Rossum/Veryfi — TOP-APPS-RESEARCH ý #8).
- **Nút "trường tiếp theo cần xem"**: chỉ nhảy qua các trường bị cờ, không
  bắt cuộn cả form (ý #9).
- Mở màn Kiểm Lại bằng **câu hỏi về trường lõi còn thiếu** ("Chưa đọc được
  TỔNG — anh nhìn giấy điền giúp, hoặc chụp lại") thay vì danh sách cảnh báo
  dài (ý #9; Expensify thiếu merchant/date/total là hỏi thẳng — §1.1).
- **Sửa tiền bằng bàn phím hero** với dòng kiểm chéo sống ngay dưới số
  ("Subtotal + Thuế = $X — khớp ✓") (DESIGN-AUDIT §4.7).
- Trường tin cậy thấp **tô vàng ngay tại chỗ**, có câu hướng dẫn riêng từng
  trường (DESIGN-AUDIT §4.7).
- **Xem văn bản đọc thô** (F3) ngay trong Kiểm Lại/Chi Tiết — công cụ chẩn
  đoán để từ nay lỗi đọc nào cũng có bằng chứng, hết đoán mò (CODE-AUDIT F3).
- **Anh được gì:** duyệt 1 tờ chỉ còn vài giây và vài chạm; "đã qua mắt
  người" được trình bày như điểm mạnh của chứng từ (bài học Shoeboxed —
  TOP-APPS-RESEARCH §2.11), không phải việc anh phải làm vì app dở.

### Ý 8 — Ảnh gốc là chứng từ bất khả xâm phạm
Ảnh gốc (mọi trang) + file PDF gốc là *bằng chứng*; dữ liệu đọc ra chỉ là
bản trích. Luật cứng: **không ghi đè ảnh gốc** (ảnh tăng nét là bản phái
sinh lưu riêng, đeo nhãn); xoá hoá đơn thì **xoá bản ghi trước, ảnh sau**
(Build 1 đang làm ngược — B-6); quét huỷ không để lại file rác (B-7); không
tự xoá theo tuổi — hết hạn giữ 7 năm app chỉ *báo danh sách*, xoá hay không
là anh quyết (ACCOUNTING-SPEC nhóm F, §4 điều cấm 2–4).
- **Vì sao:** Rev. Proc. 97-22 chỉ chấp nhận bản điện tử *đầy đủ, rõ, lấy
  lại được, có kiểm soát toàn vẹn* (ACCOUNTING-SPEC §0). Mất ảnh gốc là mất
  chứng từ — dữ liệu đọc đúng cũng không cứu được.
- **Anh được gì:** kho hoá đơn của anh đứng vững ở tầng bằng chứng, không
  chỉ tầng con số.

---

## 2. PHẠM VI BUILD 2 — CHỐT CỨNG THÀNH GÓI VIỆC (WP)

Nguyên tắc xếp thứ tự: **Phụ lục B của QA-VERDICT là luật về THỨ TỰ TẦNG**
(chất lượng đọc trước mọi thứ). Trong Tầng 0, thứ tự gói dưới đây là quyết
định phụ thuộc kỹ thuật của bản tổng hợp này — lý do ghi ngay ở từng gói,
và QA phải ký nhận cách xếp này ở cổng WP0 (xem thêm mục 5.0). Các gói chạy
**tuần tự**: gói sau chỉ mở khi gói trước có bằng chứng nghiệm thu (mục 4).
Mỗi lần đẩy GitHub chứa đúng **một** gói.

### WP0 — Đóng băng bộ mẫu & bảng điểm (không viết code app)
- Việc: chốt 3 mẫu hạt giống 001/002/003 (ground truth đã kiểm số học —
  `samples/`), lập **tờ bảng điểm** ghi điểm nền của Build 1 (QA-VERDICT
  Phụ lục B §0.3: Mẫu 002 — tiệm ✓ ngày ✓ tổng ✗-có-cờ món ✗; Mẫu 003 —
  tiệm ✗-KHÔNG-cờ ngày ✓ tổng ✗-có-cờ món ✗; Mẫu 001 — bản prototype trên
  bản chép chữ đạt 100%, **[CHƯA KIỂM CHỨNG]** trên máy thật bằng Build 1),
  và định nghĩa làn đo phụ trong phòng lab (mục 3.3).
- **Bằng chứng ra cổng:** tờ bảng điểm tồn tại, có điểm nền; QA ký nhận thứ
  tự gói WP1→WP9 của bản kế hoạch này.

### WP1 — Cửa chẩn đoán: xem văn bản đọc thô (F3)
- Việc: mục "Văn bản OCR gốc" thu gọn được trong màn Kiểm Lại + Chi Tiết,
  có nhãn trung thực về đường đọc ("Văn bản trong PDF" khi là lớp chữ —
  CODE-AUDIT F3, đặc tả mã sẵn).
- Vì sao trước: đây là *dụng cụ đo* cho mọi gói đọc phía sau. Thiếu nó, cơ
  chế hỏng của Vision mãi là suy luận (QA-VERDICT §1.2 F2/F3).
- **Bằng chứng ra cổng:** trên máy anh, mở được văn bản thô của 1 tờ quét
  thật; chụp màn hình lưu kèm báo cáo gói.

### WP2 — Hoàn thiện model dữ liệu (theo ACCOUNTING-SPEC §5.2)
- Việc, theo đúng thứ tự ưu tiên của chuyên gia Kế toán: danh sách dòng
  thuế `taxLines[]` + phân biệt rạch ròi thuế = 0 (miễn thuế) vs chưa đọc
  được; `totalPrinted`/`tipAmount` cho nhà hàng; phân loại + mục **ở cấp
  dòng món**; danh sách ảnh gốc `originalImages[]` + ô chứa ảnh phái sinh;
  `paymentMethod`; địa chỉ tiệm; mã giao dịch + mã xác thực thành trường
  riêng; mục chi lưu kèm **mã dòng Schedule C**; `sourceType` (chụp/chọn
  ảnh/import PDF); liên kết trùng `duplicateOf`/`excludedFromTotals`; dấu
  vết tối thiểu: `reviewedAt` + cờ "anh nhập tay" theo trường; `retentionUntil`.
  Kèm: chuyển đổi dữ liệu (migration) từ kho Build 1 — phải thử trên bản
  sao kho trước, không thử trên dữ liệu thật của anh.
- Vì sao ở đây: PDF (WP3) cần chỗ lưu file gốc + nguồn nạp; nghiệm thu §F
  cần 2 dòng thuế riêng; engine (WP4) cần chỗ hạ cánh cho mọi trường nó đọc
  được. Làm WP2 sau khi đã có WP1 để mọi lỗi chuyển đổi đều nhìn thấy được.
- **Bằng chứng ra cổng:** QA đối chiếu từng thiếu hụt CAO/TRUNG ở bảng
  ACCOUNTING-SPEC §5.2 → đã có trường chứa; migration chạy sạch trên bản
  sao kho Build 1 (2 tờ test của anh còn nguyên, số không đổi).

### WP3 — Đường PDF & nạp file (F1)
- Việc: nạp từ Files + Chia sẻ, **nhiều file một lúc** (loại: PDF/JPEG/PNG/
  HEIC); PDF có lớp chữ → trích thẳng vào cùng bộ bóc tách (độ tin cậy lớp
  chữ = 1.0 theo CODE-AUDIT F1, nhưng vẫn qua đủ phép kiểm V1–V10 — xem
  mục 5.5); lưu **file PDF gốc** làm bằng chứng (dùng ô chứa của WP2); PDF
  không lớp chữ → render thành ảnh → đi đường đọc ảnh. Bộ chọn file phải có
  **bài test riêng trên máy anh trước** (bài học Test 0: chọn thư mục của
  chính app bị huỷ im lặng — TEAM.md lỗi cơ bản #3; CODE-AUDIT F1 bước 1).
- **Bằng chứng ra cổng:** nghiệm thu §F trên một PDF lớp chữ thật (mục 3.2).
  **[LƯU Ý TRUNG THỰC]** file PDF Sam's của anh chưa về tay đội (mới có bản
  JPG — Mẫu 002): nếu tới WP3 mà chưa có, nghiệm thu chạy trên PDF lớp chữ
  thật khác (vd hoá đơn Best Buy/Amazon tải về) và mục "PDF Sam's" ghi
  **CHƯA NGHIỆM THU — chờ file**, không ghi đạt.

### WP4 — Thi đấu engine đọc ảnh (trung tâm của Tầng 0)
- Việc: (a) Vision cổ điển + tiền xử lý (phát hiện tứ giác → nắn
  perspective → tăng tương phản thành ảnh phái sinh; ảnh gốc giữ nguyên —
  TOP-APPS-RESEARCH ý #3) + ráp hàng F2a + chịu tách dòng F2b + cắt lát ảnh
  cao F2c (đặc tả mã sẵn ở CODE-AUDIT F2); (b) `RecognizeDocumentsRequest`
  trong bản test pipeline riêng kiểu Test 0. Cả hai chấm trên bảng điểm
  WP0, **cộng thêm 1 lần chụp camera thật** tờ Sam's (đường camera tới nay
  **[CHƯA KIỂM CHỨNG]** — CODE-AUDIT Leader Addendum) thành mẫu 002-C.
  Biến thể "hai lượt đọc + trọng tài số học" (Ý 4) được đo như một cấu hình
  của mỗi ứng viên (đọc trên ảnh gốc vs ảnh phái sinh) — cách xử lý với
  luật "thua là bỏ" ghi ở mục 5.1.
- **Bằng chứng ra cổng:** bảng điểm đầy đủ của cả hai ứng viên trên
  001/002/003/002-C; QA ký chọn engine thắng bằng văn bản; engine thua bị
  loại khỏi mã nguồn Build 2. **Điểm quyết định là điểm trên mẫu của anh —
  không có ngưỡng hứa trước.**

### WP5 — Nhận diện tiệm & kỷ luật độ tin cậy (C-18, C-11)
- Việc: tìm tiệm trên **toàn bộ dòng** + khớp mờ; chuỗi fallback 3 nấc học
  từ Veryfi (TOP-APPS-RESEARCH ý #6): (i) khớp mờ tên → (ii) neo phụ: địa
  chỉ/mã cửa hàng/số điện thoại khớp tiệm đã biết → (iii) *gợi ý* từ món
  đặc trưng (chỉ gợi ý, không tự điền); cả 3 trượt → để trống + ép Hộp Chờ.
  **Cấm** lấy dòng đầu/slogan làm tên tiệm khi không có cờ tin cậy thấp
  (QA-VERDICT Phụ lục B, C-18). Độ tin cậy được **thực thi** cho cả tiệm và
  ngày, không chỉ tổng tiền (C-11).
- **Bằng chứng ra cổng:** Mẫu 003 cho ra "The Home Depot" hoặc "chưa rõ —
  có cờ"; khẳng định kiểm được: không còn đường nào để tên tiệm sai mà
  không cờ trên bộ mẫu.

### WP6 — Niềm tin dữ liệu (Tầng 1 của QA-VERDICT)
- Việc: B-2 (lưu hỏng phải báo lỗi thật, không đóng màn, không "Đã lưu ✓"
  giả) · C-1/C-2/C-3 (nút Duyệt tôn trọng cờ; tổng Trang Chủ/Báo Cáo/Danh
  Sách tách rõ tiền *đang chờ* khỏi *chính thức*; chạy lại kiểm chứng trên
  số anh đã sửa ngay lúc lưu) · B-5 (nạp dữ liệu lỗi thì báo lỗi, không giả
  vờ rỗng) · B-6 (xoá bản ghi xong mới xoá ảnh) · B-7 (dọn file ảnh mồ côi
  khi huỷ quét) · C-8 (xếp lại theo thẻ chỉ áp tờ chưa duyệt/chưa xếp tay,
  báo số lượng trước khi làm — khớp điều cấm 5 của kế toán, xem mục 5.3).
  Cộng phần của kế toán: **luật "hoàn chỉnh" §2.2 trở thành cổng Duyệt thật
  trong app**, gồm cơ chế "xác nhận kèm cờ" (anh xác nhận bất chấp chênh
  lệch thì cờ vẫn hiển thị, không bị nuốt); cờ trùng hiện ở **cả hai bản**
  và nối liên kết `duplicateOf` (TOP-APPS-RESEARCH ý #11); lưu độ tin cậy
  từng trường + phiên bản bộ đọc (ACCOUNTING-SPEC F4; ý #7 của nghiên cứu).
- **Bằng chứng ra cổng:** QA rà lại từng mã lỗi với bằng chứng file + thao
  tác thật trên bản build: tổng các màn không còn tính tờ chưa duyệt; thử
  lưu trong điều kiện lỗi phải hiện lỗi.

### WP7 — Đúng luật bóc tách (Tầng 2 của QA-VERDICT)
- Việc: C-4 (gặt thẻ phải có ngữ cảnh dòng thanh toán — luật V10 của kế
  toán) · C-5 (vùng loại trừ là *vùng* thật: Suggested Tip, Return Policy,
  MAX REFUND — áp cho cả ngày/thẻ) · C-6 (khoá chống trùng theo tiệm:
  Amazon Order ID, Lowe's SALES#+TRANS#, Love's Ticket#…; hộp thoại nói
  đúng loại khoá; dùng thật tham số bỏ qua trùng; khoá dựng từ số đã sửa)
  · C-7 (đổi loại ở Chi Tiết phải sửa mục theo) · C-9 phía parser (tổng in
  + tip của nhà hàng, vùng Suggested Tip) · C-10 (GRAND TOTAL + Amazon
  nhiều kiện) · C-17 (quét dòng kề tìm DEBIT) · các MINOR C-13/C-14/C-15/C-16.
- **Bằng chứng ra cổng:** chạy lại bộ prototype + cả 3 mẫu: mọi luật trong
  VENDOR-FORMATS có dòng đối chiếu đạt/trượt rõ ràng.

### WP8 — Trải nghiệm quét & sửa (phần gánh nặng của Tầng 3)
- Việc: quét **không chặn** — chụp xong tờ hoá đơn vào sổ ngay với trạng
  thái "Đang đọc…", đọc chạy nền, đếm tiến độ "Đang đọc 3/12 tờ", hỗ trợ
  nhiều trang, nút Chụp Một Đống (DESIGN-AUDIT §4.8) · hướng dẫn chụp ngay
  trong luồng camera: 2 câu "vuốt phẳng hoá đơn — đủ 4 góc trong khung"
  (TOP-APPS-RESEARCH ý #12) · sửa lỗi rẻ (Ý 7): tô vàng trường tin cậy
  thấp tại chỗ, bàn phím hero sửa tiền + kiểm chéo sống, nút nhảy trường
  bị cờ, chạm-trường-highlight-vùng-ảnh · so sánh trùng 2 ảnh cạnh nhau
  (DESIGN-AUDIT §4.7) · thẻ **bấm được**: thẻ vật lý tỉ lệ 1.586 → màn hoá
  đơn của thẻ + tổng năm (§4.10) · số tiền về **chữ chính trên nền đục** ở
  mọi ô tổng + sửa C-12 (tổng theo mục phải tách Cá nhân/Business) · B-3
  (thumbnail hạ cỡ, không giải mã ảnh full-size trong danh sách) · B-4
  (ghim scale = 1 cho bước chuẩn hoá hướng ảnh).
- **Bằng chứng ra cổng:** Design rà lại các điểm kiểm §4.7/§4.8/§4.10 trên
  bản cài thật; anh chụp thử 1 đống nhỏ và duyệt thử 3 tờ — thời gian duyệt
  được ghi lại làm số đo (không đặt mục tiêu hứa trước).

### WP9 — Hoàn thiện theo đặc tả thiết kế (Tầng 4)
- Việc: tab bar tự vẽ + nút CHỤP giữa 56pt (§4.3) · onboarding 3 bước
  làm-thật (§4.10) · bộ trạng thái dùng chung: thẻ lỗi/thông tin/toast
  thành công (§4.11) · Báo Cáo: thẻ "Năm thuế nhìn lại" + cảnh báo sẵn
  sàng khi còn tờ chưa duyệt (chỉ cảnh báo — xuất hồ sơ Tax Pack KHÔNG
  thuộc Build 2, xem mục 2.1) (§4.13) · màn khoá Face ID có thiết kế +
  ghi chú fail-open hiện rõ (B-9) (§4.14) · sửa L-1/L-2, B-8/B-10 ·
  Liquid Glass: **chỉ khi** WP4 chọn engine iOS 26 thì mới áp theo §4.9
  (chỉ ở lớp điều khiển, không bao giờ trên số tiền) — xem mục 5.6.
- **Bằng chứng ra cổng:** Design đếm lại 54 điểm kiểm trên bản cuối; QA ký
  cổng Build 2 (mục 4).

### 2.1 NGOÀI PHẠM VI BUILD 2 (hoãn, có lý do)
- **Xuất hồ sơ Tax Pack (PDF/CSV/ZIP)** → Build 3. Lý do: xuất hồ sơ chỉ có
  nghĩa khi model đã đủ trường (WP2) và cổng hoàn chỉnh đã chạy thật (WP6);
  làm sớm là xuất "hồ sơ sạch giả tạo" — điều cấm 9 của kế toán. Màn Báo
  Cáo ở WP9 chỉ hiện thẻ sẵn sàng + cảnh báo, **không nút chết** (DESIGN-
  AUDIT §4.13).
- **Giao diện tách hoá đơn theo dòng (split UI)** → sau Build 2. Model có
  khả năng ở WP2 (trường cấp dòng); phần tương tác tách cần một vòng thiết
  kế riêng sau khi chất lượng đọc đã ổn. (Prototype đã chứng minh phép
  toán tách trên Mẫu 001 — chứng minh toán, chưa phải tính năng.)
- **Đồng bộ đám mây / server dưới mọi hình thức** → loại hẳn, không phải
  hoãn (bằng chứng Test 0: chạm CloudKit làm app chết ngay khi mở; triết
  lý dự án: ảnh hoá đơn không rời iPhone).
- **Nối ngân hàng / tự đối chiếu sao kê** → loại (FEATURES đã loại). Biến
  thể "anh tự nạp file sao kê để đối chiếu" chỉ **ghi nhận** cho v1.x xem
  xét, chưa đề xuất làm (TOP-APPS-RESEARCH ý #14).
- **Học luật bằng ngôn ngữ tự do kiểu LLM** (SparkReceipt) → không copy
  được on-device; thay bằng gợi ý luật dạng mẫu cố định ("Home Depot →
  Vật tư? [Lưu luật]") — và gợi ý bằng Foundation Models vẫn giữ lịch
  v1.2 như FEATURES đã xếp, không kéo vào Build 2.
- **Khuôn mẫu (template) riêng cho tiệm mới** → chỉ thêm khi bộ mẫu chấm
  điểm cho thấy một tiệm anh hay mua bị đọc kém — template là tăng tốc phụ,
  không phải chiến lược (Ý 1).
- **Xem toàn bộ nhật ký sửa đổi (audit trail UI)** → dữ liệu được *ghi* từ
  WP2; màn xem để sau. Tương tự: camera tuỳ biến sâu hơn VisionKit (cổng
  tin cậy phát hiện 5 mức kiểu Genius Scan, TOP-APPS-RESEARCH ý #13) —
  ghi nhớ, chưa làm.

---

## 3. NGHIỆM THU — ba lớp cổng, thiếu một cũng không qua

### 3.1 Bảng điểm hoá đơn (cổng phát hành — vĩnh viễn)
Mỗi mẫu chấm 4 ô: **tiệm / ngày / tổng / món**. Luật qua cổng (nguyên văn
tinh thần QA-VERDICT Phụ lục B §0.3): **Build 2 chỉ qua cổng khi tổng +
ngày ĐÚNG trên cả 3 mẫu hạt giống, và không một con số sai nào được trình
bày mà không gắn cờ.**

| Mẫu | Dạng | Đáp án chuẩn (đã kiểm số học) | Điểm Build 1 (đối chiếu) |
|---|---|---|---|
| 001 | Ảnh chụp màn hình app Sam's (số) | Sam's Club · 2026-10-29 17:49 · TOTAL **216.80** · 10 dòng, Σ = 203.30, 15 món | Prototype trên bản chép chữ: 100%. Trên máy thật: **[CHƯA KIỂM CHỨNG]** |
| 002 | File Sam's tải về (ảnh JPG 554×1457) | SUBTOTAL **203.30** · TAX 1 **9.60** · TAX 2 **3.90** · TOTAL **216.80** · 10 dòng món · 15 món · khoá TC# | Tiệm ✓ · Ngày ✓ · Tổng ✗ (có cờ) · Món ✗ |
| 002-C | **Chụp camera thật** cùng tờ Sam's (mẫu mới, lập ở WP4) | Như 002 | Chưa tồn tại — đường camera **[CHƯA KIỂM CHỨNG]** |
| 003 | Home Depot giấy nhàu, chụp thường | The Home Depot · 03/03/2025 12:59 · SUBTOTAL 96.91 · TAX 8.25 · TOTAL **105.16** · Visa ••3830 | Tiệm ✗ (**không cờ** — vi phạm tinh thần cổng) · Ngày ✓ · Tổng ✗ (có cờ) · Món ✗ |

Nghiệm thu chi tiết §F cho Mẫu 002 (CODE-AUDIT §F, ràng buộc): đọc tự động,
không nhập tay — **10 dòng món · 203.30 · 9.60 · 3.90 · 216.80 · 15 món ·
khoá TC#**. Thiếu bất kỳ số nào là finding F2/F1 còn mở, và phải dùng cửa
chẩn đoán F3 (WP1) để nói rõ số mất ở tầng nào trước khi sửa tiếp.

### 3.2 Nghiệm thu đường PDF (cho WP3)
Trên PDF lớp chữ thật: các trường đọc ra phải khớp đáp án chuẩn của chính
file đó (với Sam's: cùng bộ số §F như trên, qua lớp chữ thay vì OCR). File
PDF Sam's chưa về tay đội — trạng thái nghiệm thu mục này ghi ở WP3: đạt
trên PDF thật nào thì ghi tên file đó; riêng Sam's ghi chờ file, không
ghi đạt thay.

### 3.3 Bộ mẫu lớn dần (corpus) — đo độ bền, không thay cổng 3.1
Cổng phát hành là hoá đơn thật của anh (3.1). Corpus mở rộng để *phát hiện
điểm yếu trước khi anh phải test tay*:
- **Theo loại hình** (mỗi loại gom dần từ hoá đơn thật của anh; mỗi mẫu mới
  phải có đáp án chuẩn kiểm số học bằng tay trước khi vào bộ): nhà hàng
  (có dòng tip + bẫy Suggested Tip) · chợ/siêu thị thực phẩm · cây xăng
  (thuế = 0, tính trong giá) · hiệu thuốc · đồ gia dụng/big-box (Home
  Depot, Lowe's, Best Buy — **mẫu Best Buy đang chờ anh gửi khi tiện**) ·
  kho sỉ (Sam's/Costco) · hoá đơn online tải về (PDF Amazon có Order ID,
  Best Buy…).
- **Làn lab từ dataset công khai** (TOP-APPS-RESEARCH §4 — chỉ làm làn đo
  phụ, **không bao giờ là điểm cổng**, ảnh không nhúng vào app, dùng nội bộ
  theo giấy phép CC BY 4.0 / Apache-2.0 / điều kiện ICDAR): **WildReceipt**
  (472 tờ test — hoá đơn Mỹ chụp ngoài đời, giống điều kiện Mẫu 003 nhất)
  để đo độ bền ngoài bộ mẫu nhà; **CORD** để stress-test bóc tách cấp dòng;
  **SROIE** làm bài test khói cho 4 trường tiệm/ngày/địa chỉ/tổng. Lý do
  phải tách làn: điểm trên corpus lạ không giống điều kiện thật thì là
  điểm dối (bằng chứng 88% → 51% ở TOP-APPS-RESEARCH §2.12).
- **Hiệu chuẩn ngưỡng:** mốc tin cậy 85%/60% hiện tại chỉ là điểm khởi đầu;
  sau mỗi vòng bảng điểm, ngưỡng được chỉnh theo lỗi thật trên corpus của
  anh — không mượn ngưỡng của hãng nào (TOP-APPS-RESEARCH §2.1, nguyên tắc
  của Nutrient).

### 3.4 Cổng dữ liệu (của kế toán — chạy trên mọi tờ, mọi gói)
- 10 phép kiểm V1–V10 (ACCOUNTING-SPEC §2.1) phải chạy ở tầng bóc tách và
  **chạy lại trên số đã sửa khi lưu** (sửa C-3 ở WP6).
- Định nghĩa "hoàn chỉnh" 6 điều kiện (ACCOUNTING-SPEC §2.2) là điều kiện
  duy nhất để một tờ thành chính thức và được tính vào tổng.
- Danh sách cờ đỏ (ACCOUNTING-SPEC §2.3) phải nổi lên đầu Hộp Chờ: thiếu
  tổng · lệch số học > 2 cent · trùng khoá cứng · đuôi thẻ lạ · business
  trống mục đích · ngày lệch năm · ảnh gốc mờ/cắt mất phần tổng.

---

## 4. NHỊP ĐỘ — "CHẬM MÀ CHẮC", VIẾT THÀNH LUẬT

1. **Tuần tự tuyệt đối:** WP sau chỉ bắt đầu khi WP trước có *bằng chứng*
   nghiệm thu (không phải "làm xong cảm giác"). Bằng chứng = tờ bảng điểm
   đã điền, ảnh chụp màn hình máy thật, hoặc biên bản rà lỗi có trích file —
   tuỳ loại ghi ở từng WP.
2. **Mỗi lần đẩy = một gói.** Không gộp gói để "tiện một lần build" — bài
   học Build 1: phạm vi gộp làm lỗi nấp trong nhau (QA-VERDICT Phần 4).
3. **Cổng 3 chữ ký + 1 duyệt cuối** (TEAM.md): nháp → Design audit → Code
   audit độc lập → QA đối chiếu & ký → Wally duyệt cuối → mới đẩy GitHub.
   Chưa đủ chữ ký thì bản build đó không tồn tại, dù code đã viết xong.
4. **Không hứa thời gian.** Không có ngày hoàn thành cho bất kỳ gói nào
   trong tài liệu này, và đội không được phép hứa thay. Anh nhận báo cáo
   theo *kết quả + bằng chứng*, không theo lịch.
5. **Vòng test thật với anh:** các gói đụng tới đọc (WP1/WP3/WP4/WP5/WP8)
   đều kết thúc bằng một vòng anh cài và test trên hoá đơn thật của anh;
   nhận định của anh được **trích nguyên văn** vào báo cáo gói (như cách
   Mission 1 đã ghi nhận xét về chất lượng scan), không diễn giải lại.
6. **Dừng là quyền mặc định:** bất kỳ ai trong đội thấy bằng chứng mâu
   thuẫn với kế hoạch này thì dừng gói, ghi lại, trình lên — không tự ý
   đổi hướng. Đổi hướng chỉ đến từ anh (như lần đổi 23:25 CST) hoặc qua
   sửa đổi có ký nhận của bản kế hoạch này.

---

## 5. XUNG ĐỘT GIỮA CÁC NGUỒN — VÀ CÁCH BẢN KẾ HOẠCH NÀY XỬ LÝ

**5.0 Thứ tự trong Tầng 0: QA-VERDICT vs bản tổng hợp này.**
Phụ lục B xếp F1 (PDF) lên đầu danh sách Tầng 0; bản này đặt WP2 (model)
trước WP3 (PDF) và WP1 (cửa chẩn đoán) trước cả hai. *Xử lý:* Phụ lục B
vẫn là luật về **thứ tự tầng và cổng phát hành** — không đổi. Thứ tự gói
trong tầng là phụ thuộc kỹ thuật: PDF cần ô chứa file gốc/nguồn nạp của
model mới, nghiệm thu §F cần 2 dòng thuế riêng của model mới; làm PDF
trên model cũ sẽ phải làm hai lần và nghiệm thu hai lần. WP1 đi trước vì
nó là dụng cụ đo cho mọi chẩn đoán sau (chính CODE-AUDIT F3 lập luận vậy).
QA ký nhận cách xếp này tại cổng WP0; nếu QA không ký, thứ tự quay về
đúng Phụ lục B.

**5.1 "Engine thua là bỏ, không lai ghép" (QA) vs "hai lượt đọc" (nghiên cứu).**
QA-VERDICT §0.1 cấm lai ghép mập mờ giữa hai engine; TOP-APPS-RESEARCH ý #4
đề xuất đọc hai lượt làm trọng tài. *Xử lý:* hai lượt đọc **không phải**
lai hai engine. Trong WP4, "hai lượt" là một *cấu hình đo* của từng ứng
viên (ảnh gốc vs ảnh phái sinh — cùng một engine). Sau khi chọn thắng/thua
theo luật QA, engine thua vẫn bị loại hẳn; lớp trọng tài số học (Ý 4) chạy
bên trên engine thắng cuộc duy nhất. Trọng tài chỉ được **gắn cờ và đưa
ứng viên cho anh chọn** — không bao giờ tự điền số (điều cấm 1 của kế toán
giới hạn nó).

**5.2 Veryfi tự tính số thiếu (subtotal = total − tax − tip) vs điều cấm của kế toán.**
Veryfi coi số tự tính là tính năng (TOP-APPS-RESEARCH §1.7d); ACCOUNTING-
SPEC §1-C1/C2 và điều cấm 1/6 cấm điền số tính ra vào trường chính thức.
*Xử lý:* học Veryfi ở **cơ chế đeo nhãn** "số suy ra — không in trên giấy",
**không** học hành vi tự điền. Số suy ra chỉ hiện dưới dạng gợi ý đối chiếu;
anh xác nhận thì nó thành số *anh nhập* (có dấu vết), không thành số máy đọc.

**5.3 Đổi loại thẻ xếp lại toàn bộ hoá đơn cũ (tiện) vs không viết lại lịch sử (kế toán).**
Nhu cầu gốc của anh: đổi loại thẻ phải hỏi "từ nay, hay xếp lại cả hoá đơn
cũ?". CODE-AUDIT C-8 bắt lỗi cách Build 1 làm (xếp lại cả tờ đã duyệt, ghi
đè lý do); ACCOUNTING-SPEC điều cấm 5 cấm viết lại lịch sử phân loại.
*Xử lý:* giữ nguyên nhu cầu của anh ở dạng **chọn rõ ràng**: mặc định chỉ
áp tờ chưa duyệt/chưa xếp tay, báo số lượng trước; muốn xếp lại cả tờ cũ
thì anh bấm chọn riêng và việc xếp lại đó **vào dấu vết sửa đổi** (WP2/WP6).
Không ai được xếp lại lặng lẽ.

**5.4 Duyệt hàng loạt cho nhanh (FEATURES) vs cổng hoàn chỉnh 6 điều kiện (kế toán).**
*Xử lý:* cổng hoàn chỉnh thắng. "Duyệt tất cả tờ đã rõ" (DESIGN-AUDIT
§4.4) chỉ áp cho nhóm tờ **đã đủ 6 điều kiện** — nút đó là duyệt-nhanh-nhiều-tờ-đã-rõ,
không phải đường tắt qua cổng. Tờ thiếu điều kiện vẫn ở Hộp Chờ, tờ nào
anh muốn cho qua bất chấp thì dùng "xác nhận kèm cờ" — cờ đi theo tờ đó
vĩnh viễn, kể cả khi xuất hồ sơ sau này.

**5.5 Lớp chữ PDF gắn độ tin cậy 1.0 (CODE-AUDIT F1) vs "độ tin cậy không phải bằng chứng" (kế toán, điều cấm 10).**
*Xử lý:* 1.0 ở đây nghĩa là "đây không phải chữ đoán" — nó tắt đúng các
cảnh báo *về độ mờ của chữ*, nhưng **không** tắt kiểm chứng: V1/V2/V4 vẫn
chạy đủ trên hoá đơn PDF, và luật hoàn chỉnh §2.2 vẫn là cổng duy nhất để
thành chính thức. Độ tin cậy, kể cả 1.0, không tự nó duyệt được tờ nào.

**5.6 Nếu engine iOS 26 thắng (WP4) thì sao với bản iOS 17 và Liquid Glass?**
Thắng/thua kéo theo quyết định nền tảng: engine (b) thắng → app chuyển
đích iOS 26 (đúng máy anh đang chạy iOS 27.2), rủi ro đổi SDK đã được cô
lập ở bản test riêng từ WP4; lúc đó đặc tả Liquid Glass (DESIGN-AUDIT
§4.9) mới kích hoạt — và chỉ ở lớp điều khiển. Engine (a) thắng → giữ
iOS 17, tab bar tự vẽ §4.3 là bản chính, Glass hoãn vô điều kiện. *Xử lý:*
quyết định thuộc về bảng điểm, không thuộc sở thích của đội; cả hai
đường đều đã có đặc tả sẵn nên không đường nào làm chậm gói sau.

**5.7 Xoá hoá đơn trong menu Chi Tiết (thiết kế) vs không xoá trùng lặng lẽ (kế toán).**
DESIGN-AUDIT §4.6 để "Xoá hoá đơn này" trong menu •••; ACCOUNTING-SPEC
điều cấm 3 cấm xoá bản trùng lặng lẽ. *Xử lý:* hai việc khác nhau và giữ
cả hai đúng chỗ của nó: **trùng** thì đánh dấu + liên kết + loại khỏi tổng,
không xoá (WP6); **xoá một tờ** là hành động riêng, có chủ đích của anh,
đi qua thứ tự an toàn của B-6 và để lại dấu vết. Menu thiết kế giữ nguyên
— nó không phải nút xử lý trùng.

**5.8 Độ chính xác của app top (98–99,9% theo hãng) vs trần on-device của mình.**
Các con số đó là marketing chưa kiểm chứng độc lập; test độc lập hiếm hoi
đo được 85–94% cho OCR thuần app (TOP-APPS-RESEARCH, quy ước bằng chứng).
*Xử lý:* bản kế hoạch này **không đặt mục tiêu % nào** cho Build 2. Thước
duy nhất là bảng điểm trên hoá đơn của anh (mục 3.1) cộng kỷ luật "sai thì
có cờ" — đó là thứ hồ sơ thuế cần, không phải con số quảng cáo.

---

## 6. CÂU HỎI MỞ CHO ANH (chỉ gồm việc thật sự chặn — còn lại đội tự lo)

1. **Loại hình business của anh là gì** — cá nhân kinh doanh (sole
   proprietor) / LLC 1 thành viên / LLC nhiều thành viên / S-corp / khác?
   (ACCOUNTING-SPEC §3.1 — câu hỏi lớn nhất còn mở.) Bảng ánh xạ Schedule C
   trong đặc tả kế toán đúng nếu là sole proprietor hoặc LLC 1 thành viên;
   khác đi là phải làm lại bảng. *Mức chặn:* chỉ chặn việc **khoá cứng mã
   dòng** ở WP2/WP7 — và đội có sẵn đường né: lưu mã dòng dưới dạng dữ
   liệu sửa được, nên WP0/WP1 và toàn bộ việc đọc **không phải chờ** câu
   trả lời này. Hai điểm phụ thuộc CPA của anh (không phải hỏi anh): áp
   dụng ngưỡng de minimis cho thiết bị, và dòng khai cho mục Phần Mềm —
   chuyên gia Kế toán đã ghi unverified, cần CPA xác nhận trước khi khoá.
2. **Hàng mua ở Sam's chủ yếu để BÁN LẠI hay để DÙNG cho business?**
   (ACCOUNTING-SPEC §3.1, câu phụ.) Quyết định gợi ý mặc định giữa Hàng
   Hoá/Giá Vốn (COGS) và Vật Tư (Supplies). *Mức chặn:* chỉ ảnh hưởng gợi
   ý mặc định theo tiệm — từng tờ vẫn quyết bằng ghi chú mục đích của anh.
3. **Hai file mẫu khi anh tiện** (không phải quyết định, không chặn bắt đầu
   việc): **file PDF Sam's** (để nghiệm thu WP3 đúng trên nguồn chính của
   anh) và **một hoá đơn Best Buy tải về** (vào corpus big-box). Có lúc nào
   gửi lúc đó — đội làm các gói khác trước, không đứng chờ.

---

## PHỤ LỤC — NGUỒN & RANH GIỚI TRUNG THỰC

- Mọi khẳng định kỹ thuật/kế toán trong tài liệu này truy về 5 file đầu vào
  ghi ở đầu trang; đáp án chuẩn của 3 mẫu truy về `samples/*-ground-truth.md`
  (đã kiểm số học độc lập ít nhất 2 lần: Wally + Trưởng nhóm Mission 1).
- Các điểm **[CHƯA KIỂM CHỨNG]** còn đứng sau bản kế hoạch này: cơ chế bên
  trong Vision khiến cột tiền bị xé (suy luận có bằng chứng hình học ủng hộ
  mạnh — QA-VERDICT Phụ lục A); độ chính xác của `RecognizeDocumentsRequest`
  trên hoá đơn (chưa ai công bố — WP4 sẽ đo); đường chụp camera trong app
  (chưa test thật — thành mẫu 002-C ở WP4); điểm Mẫu 001 trên máy thật.
- Tài liệu này là **kế hoạch**, không phải code và không phải tư vấn thuế.
  Các điểm ACCOUNTING-SPEC ghi unverified (loại hình business, de minimis,
  dòng cho Software) vẫn unverified cho tới khi anh/CPA của anh xác nhận.

*— Chuyên gia Tổng hợp & Sản phẩm, 2026-11-08 đêm.*

# WP6 — ĐẶC TẢ NIỀM TIN DỮ LIỆU (Master Plan §2 WP6 — Tầng 1 QA-VERDICT)

Viết 2026-11-10 12:40 CST (ca trực sohoadon-build2-247 — việc độc lập
chuẩn bị song song, đúng luật làm việc chung: một làn chờ/đang chạy
thì chuẩn bị song song việc độc lập không đụng làn đó. Bối cảnh lúc
viết: làn chính đang chạy gói IMGFIX (lỗi thiếu ảnh gốc
L-2026-11-10-5) và WP-EXPORT đã xếp hàng sau IMGFIX theo lệnh anh
12:44 — cả hai không thuộc WP6 và đặc tả này không đụng vào chúng).
Tài liệu này khoá CÁCH LÀM trước khi viết code — chưa có dòng Swift
nào của WP6 được viết trong bước này. WP6 thuộc mốc M2 (WP6..WP9)
— đặc tả này KHÔNG mở cổng code WP6; code chỉ viết khi tới lượt
WP6 trong nhịp M2 và Wally trình theo nhịp mốc.

## 0. Nguồn luật (mọi khẳng định truy về file)
- Master Plan §2 WP6: B-2 · C-1/C-2/C-3 · B-5 · B-6 · B-7 · C-8 ·
  luật "hoàn chỉnh" §2.2 thành cổng Duyệt thật (gồm cơ chế "xác nhận
  kèm cờ", cờ không bị nuốt) · cờ trùng hiện ở CẢ HAI bản + nối liên
  kết `duplicateOf` · lưu độ tin cậy từng trường + phiên bản bộ đọc
  (ACCOUNTING-SPEC F4).
- Bằng chứng ra cổng của gói (Master Plan): "QA rà lại từng mã lỗi
  với bằng chứng file + thao tác thật trên bản build: tổng các màn
  không còn tính tờ chưa duyệt; thử lưu trong điều kiện lỗi phải
  hiện lỗi."
- ACCOUNTING-SPEC §2.2 — "hoàn chỉnh" đủ 6 điều kiện mới được rời
  Hộp Chờ: (1) có ảnh gốc; (2) có tiệm + ngày + tổng; (3) V1+V2 đạt
  HOẶC anh xác nhận bất chấp chênh lệch — bản ghi mang dấu "đã xác
  nhận kèm cờ" và cờ VẪN hiển thị ở Chi Tiết + khi xuất, không bị
  nuốt; (4) phân loại đã quyết kèm lý do; (5) Business: mục + dòng
  Schedule C + ghi chú mục đích (Meals/Travel thêm E5, Equipment
  thêm E7); (6) thẻ khớp sổ đăng ký hoặc anh xác nhận thẻ lạ, tiền
  mặt thì D1 = cash rõ ràng. Điều cấm 10: độ tin cậy không phải
  bằng chứng — "đã duyệt" chỉ đến từ anh xác nhận hoặc kiểm chéo
  đạt + luật hoàn chỉnh.
- Master Plan §5.3 + §5.4 (đã xử lý xung đột): xếp lại theo thẻ chỉ
  áp tờ CHƯA duyệt / chưa xếp tay, báo số lượng TRƯỚC khi làm, việc
  xếp lại vào dấu vết; "duyệt tất cả tờ đã rõ" chỉ áp nhóm đã đủ 6
  điều kiện — cổng hoàn chỉnh THẮNG tốc độ.
- Master Plan §5.7: trùng thì đánh dấu + liên kết + loại khỏi tổng,
  KHÔNG xoá; xoá một tờ là hành động riêng của anh qua thứ tự B-6.

## 1. Hiện trạng đo được từ code hiện hành (bản stamp/ = thành phần
## của run #20 trên main; CardsView/HomeView chưa từng bị gói nào
## chạm — đối chiếu: không thư mục prep nào chứa hai file này)
- **B-2 CÒN NGUYÊN:** `try? modelContext.save()` tại 5 điểm trong
  stamp/ReceiptViews.swift (dòng 486 Duyệt · 505 Xoá · 628 · 645 ·
  982 lưu ở Kiểm Lại — kèm `onDone()` chạy vô điều kiện), 4 điểm ở
  build1/CardsView.swift (132/144/152/168), 1 điểm ở
  wp3-prep/ContentView.swift:145 (seed thẻ). UI báo "Đã lưu ✓" /
  đóng màn bất kể save có ném lỗi hay không.
- **C-1 CÒN NGUYÊN:** nút Duyệt (stamp/ReceiptViews.swift ~484-490)
  chỉ gán `status = .reviewed` + `try? save` — không đọc
  `receiptFlags()` (hàm đã có sẵn, dòng 104, tính 5 loại cờ: lệch
  Σ món↔subtotal >2¢ · lệch subtotal+thuế↔tổng >2¢ · thiếu tổng ·
  Business thiếu mục đích · chưa phân loại; đang chỉ được HIỂN THỊ
  ở Chi Tiết, dòng 425). Tờ thiếu tổng + chưa phân loại vẫn thành
  "chính thức" trong 1 chạm.
- **C-2 CÒN NGUYÊN:** build1/HomeView.swift — tổng năm lọc theo
  phân loại + năm, KHÔNG lọc status (chỉ ĐẾM số tờ needsReview ở
  dòng 15/219 để hiện chữ, tiền vẫn cộng cả tờ chờ). Cùng bệnh ở
  ReportsView.sum và tổng chạy của Danh Sách (CODE-AUDIT C-2).
- **C-3 CÒN NGUYÊN:** `validate()` vẫn `private static`
  (stamp/Parser.swift:951); ReviewView.save() vẫn quyết status từ
  warnings của LẦN ĐỌC GỐC, không chạy lại trên số anh đã sửa —
  hai chiều đều sai (sửa thành số lệch vẫn "chính thức"; sửa đúng
  hết vẫn kẹt Hộp Chờ — CODE-AUDIT C-3 nguyên văn).
- **B-5 CÒN NGUYÊN:** 3 điểm fetch fail-open theo CODE-AUDIT B-5
  (checkDuplicate ở ReceiptViews · applyCardChange ở CardsView ·
  seed thẻ ở ContentView — flag `didSeedStarterCard2586` set true
  kể cả khi seed lưu hỏng, không bao giờ thử lại được).
- **B-6 CÒN NGUYÊN:** hộp thoại Xoá (stamp/ReceiptViews.swift
  ~502-507): `ImageStore.delete` TRƯỚC, rồi mới delete bản ghi +
  `try? save` + dismiss vô điều kiện — save hỏng là còn bản ghi mà
  mất ảnh gốc (chứng từ IRS).
- **B-7 CÒN NGUYÊN:** sheet Kiểm Lại (wp4-prep/ScanView.swift:195 —
  thành phần ScanView hiện hành) chỉ có MỘT closure hoàn tất
  `{ draft = nil }`, không có đường onCancel dọn ảnh; nhánh
  `lines.isEmpty` (dòng 252) cũng không xoá file. Ảnh của lần quét
  huỷ/không đọc được nằm lại vĩnh viễn trong Documents/ReceiptImages.
- **C-8 CÒN NGUYÊN:** build1/CardsView.swift applyCardChange quét
  MỌI tờ trùng đuôi thẻ — kể cả tờ đã duyệt và tờ anh xếp tay —
  ghi đè cả classificationReason (xoá dấu vết vì sao từng tờ được
  xếp), không sửa mục/trạng thái kèm theo.
- **Hạ tầng WP2 ĐÃ CÓ SẴN, CHƯA NỐI:** model hiện hành
  (wp3-prep/Models.swift) đã có `scheduleCLine` (220),
  `duplicateOfStableID` (240), `excludedFromTotals` (241),
  `reviewedAt` (245), `userEnteredFieldNames` (246). Đo thực tế:
  `reviewedAt` KHÔNG được gán ở bất kỳ đâu trong thành phần hiện
  hành (grep 0 điểm gán); `duplicateOfStableID`/`excludedFromTotals`
  KHÔNG được đọc/ghi ở ReceiptViews nào (grep 0). Độ tin cậy từng
  trường + parserVersion ĐÃ lưu từ WP2/reparse (F4 coi như đã hạ
  cánh — WP6 chỉ kiểm lại, không làm lại).
- **THIẾU TRƯỜNG CHO §2.2(3):** model KHÔNG có trường nào chứa dấu
  "xác nhận kèm cờ" (grep flag/confirm trong Models: chỉ có
  CapitalizationFlag của E7, không liên quan). Đây là điểm model
  duy nhất WP6 cần quyết — xem mục 5.

## 2. Nguyên tắc bất biến của WP6
1. Lỗi lưu là SỰ KIỆN HIỂN THỊ, không phải im lặng: mọi save hỏng
   phải hiện lỗi + giữ nguyên màn hình/dữ liệu đang sửa. Không còn
   `try?` ở bất kỳ điểm save nào trong phạm vi gói.
2. Cổng Duyệt = luật hoàn chỉnh §2.2, không hơn không kém: thiếu
   điều kiện thì nút Duyệt TẮT kèm dòng chữ nói rõ thiếu gì (dùng
   chính danh sách cờ của `receiptFlags()` mở rộng — mục 3).
3. "Xác nhận kèm cờ" là đường DUY NHẤT qua cổng khi số học lệch:
   anh bấm xác nhận riêng (hộp thoại liệt kê từng cờ) → tờ thành
   chính thức NHƯNG mang dấu vĩnh viễn và cờ vẫn hiện. Không có
   đường nào nuốt cờ.
4. Tổng "chính thức" chỉ cộng tờ `.reviewed` và không
   `excludedFromTotals`; tiền đang chờ hiện THÀNH SỐ RIÊNG có nhãn,
   không cộng ngầm, không giấu.
5. Fetch hỏng ≠ rỗng: lỗi đọc dữ liệu phải chặn thao tác + báo,
   không bao giờ diễn giải thành "0 tờ / không trùng / chưa có thẻ".
6. Thứ tự xoá bất biến: bản ghi trước — lưu thành công — ảnh sau.
   Ảnh gốc chỉ mất khi bản ghi đã chắc chắn mất.
7. Không viết lại lịch sử phân loại: xếp lại theo thẻ chỉ chạm tờ
   còn mang snapshot của thẻ; quyết định tay của anh là bất khả xâm
   phạm ở mọi đường quét hàng loạt.

## 3. Cổng hoàn chỉnh §2.2 → ánh xạ kiểm được trong code
`receiptFlags()` hiện tính được: lệch V1 (Σ món↔subtotal), lệch V2
(subtotal+thuế↔tổng), thiếu tổng, Business thiếu mục đích, chưa
phân loại. WP6 mở rộng hàm này (hoặc hàm cổng riêng dùng chung cho
nút Duyệt + save ở Kiểm Lại) để phủ đủ 6 điều kiện:
- (1) ảnh gốc: `imageFileName` rỗng → cờ "thiếu ảnh gốc".
- (2) tiệm/ngày: vendor rỗng → cờ; ngày — hiện receiptFlags CHƯA
  kiểm ngày (ngày luôn có giá trị Date do đường lưu gán mặc định —
  bước code phải quyết: kiểm qua cờ "ngày do anh/bộ đọc xác nhận"
  hay giữ nguyên trạng; ghi là ĐIỂM MỞ ở bước 2, không tự bịa luật).
- (5) Business thiếu `scheduleCLine` → cờ (trường đã có, save hiện
  hành chưa chắc đã ghi — bước 2 đối chiếu save() rồi mới kết luận).
- (6) đuôi thẻ không khớp thẻ nào trong sổ + paymentMethod chưa rõ
  → cờ "thẻ lạ chưa xác nhận" (xác nhận thẻ lạ dùng CÙNG cơ chế dấu
  ở mục 5 hoặc cờ riêng — chốt ở bước 2 kèm fixture).
Nút Duyệt: `.disabled` khi còn cờ KHÔNG thuộc nhóm được xác-nhận-
kèm-cờ (chỉ lệch V1/V2 mới được xác nhận bất chấp theo §2.2(3);
thiếu tổng/thiếu phân loại/thiếu mục đích Business thì KHÔNG —
đó là thiếu dữ kiện, không phải chênh lệch đã nhìn thấy).

## 4. C-3 — chạy lại kiểm chứng trên số đã sửa (chốt cơ chế)
- Mở `validate()` từ `private` thành `internal` (đúng phác thảo
  CODE-AUDIT C-3) — thay đổi khả kiến, không đổi thân hàm ở gói này
  ngoài những gì WP5 đã mở rộng.
- ReviewView.save(): dựng ParseResult từ GIÁ TRỊ ĐÃ SỬA (tiệm/ngày/
  subtotal/thuế/tổng/món) → validate() mới → status quyết bởi kết
  quả MỚI + cổng mục 3. Trường anh sửa tay = anh đã xác nhận: ghi
  tên trường vào `userEnteredFieldNames` + đặt `reviewedAt` khi tờ
  thành chính thức (nối hai trường WP2 đang bỏ không — mục 1).
- Đường Đọc lại (reparse, run #20) cũng là một "lần lưu": bước 2
  phải đối chiếu reparseReceipt() với luật này (hiện nó tự tính
  status theo công thức save() cũ) — không để hai đường lưu hai luật.
- Hệ quả phải tuyên bố trước: tờ anh sửa đúng hết nay rời Hộp Chờ
  ngay tại Kiểm Lại (hết cảnh "cứu qua Chi Tiết"); tờ sửa lệch bị
  giữ lại kèm cờ MỚI tính trên số đã sửa.

## 5. Điểm model duy nhất — dấu "xác nhận kèm cờ" (QUYẾT Ở ĐẶC TẢ)
- Đề xuất: cộng thêm ĐÚNG 1 trường `confirmedWithFlag: Bool = false`
  vào Receipt. Thuần cộng thêm + có giá trị mặc định → di trú nhẹ
  đúng tiền lệ WP2 (+191/−0, mọi trường có default) — KHÔNG thuộc
  ngoại lệ "di trú không thuần cộng thêm" của luật mốc lớn.
- Cờ hiển thị KHÔNG lưu riêng: cờ được tính lại trực tiếp từ số đã
  lưu bằng receiptFlags() mỗi lần hiển thị, nên chừng nào số còn
  lệch thì cờ còn hiện — cấu trúc này làm cờ "không bị nuốt" theo
  đúng nghĩa §2.2(3), Bool chỉ ghi sự kiện anh đã xác nhận bất chấp.
- Nếu bước code phát hiện cần thay đổi model nào KHÁC ngoài trường
  này: DỪNG, báo Wally trước (luật cứng của ca trực) — không tự làm.

## 6. Áp lên dữ liệu ĐÃ LƯU (mục bắt buộc theo B2 Điều 2)
WP6 đổi HÀNH VI trên kho hiện có, không đổi cách đọc — đường áp là
tự thân các thay đổi sau, áp dụng ngay cho mọi bản ghi đã lưu khi
anh mở bản M2, không cần thao tác chuyển đổi nào từ anh:
- Tổng các màn (C-2): số "chính thức/đang chờ" đổi NGAY trên kho
  cũ vì tổng là phép tính lúc hiển thị, không phải số đã lưu.
  Hệ quả phải nói trước trong tin giao M2: tổng Trang Chủ sẽ GIẢM
  đúng bằng tiền các tờ đang chờ — đó là sửa đúng, không phải mất
  tiền; tin giao phải kèm số trước→sau trên kho thật của anh nếu
  đo được phía mình, đo không được thì ghi rõ chưa đo.
- Cổng Duyệt (C-1): áp cho mọi tờ needsReview đã lưu — kể cả tờ
  Home Depot vừa đọc lại ở M1 nếu còn chờ.
- C-8: chỉ chạy khi anh đổi loại thẻ (thao tác của anh), phạm vi
  mới (chưa duyệt + snapshot thẻ) áp cho kho cũ tại thời điểm đó,
  kèm báo số lượng TRƯỚC khi làm.
- B-6/B-7: thứ tự xoá + dọn mồ côi áp cho thao tác TỪ BẢN M2 VỀ
  SAU. Ảnh mồ côi ĐÃ tích lũy từ Build 1/M1: bước 2 thiết kế mục
  "file không thuộc hoá đơn nào" chỉ LIỆT KÊ + đếm trong màn nào
  đó phù hợp — XOÁ hay giữ là quyết của anh (chứng từ nhạy cảm:
  kể cả ảnh anh từng huỷ quét cũng là ảnh hoá đơn của anh; đội
  không tự xoá ngược).
- B-2/B-5: thuần hành vi lỗi — không dữ liệu nào cần áp lại.

## 7. Chia bước WP6 (đề xuất — bước 1 là bước này)
- **Bước 1 (ĐÃ LÀM, ca 2026-11-10 12:40):** đặc tả này — khoá phạm
  vi 8 mã + cổng §2.2 + quyết trường cộng thêm duy nhất + mục dữ
  liệu đã lưu. Không fixture chạy được ở bước đặc tả (WP6 là tầng
  hành vi SwiftData/UI, không có thuật toán thuần để port như
  WP4/WP5); phép kiểm của gói dồn vào bước 2/3 theo mục 8.
- **Bước 2 (code Swift, sau khi M1 đóng):** theo thứ tự an toàn —
  (a) B-2 + B-5 + B-6 + B-7 (nhóm "không mất dữ kiện", ít giao nhau
  nhất); (b) C-3 + nối reviewedAt/userEnteredFieldNames; (c) C-1 +
  cổng §2.2 + dấu xác nhận kèm cờ; (d) C-2 tách tổng; (e) C-8 phạm
  vi xếp lại. Mỗi cụm diff riêng, đối chiếu từng điểm save/fetch
  bằng grep trước-sau (số điểm `try? save` trong phạm vi phải về 0).
- **Bước 3 (chốt cổng gói):** bảng rà từng mã (mục 8) + 3 chữ ký +
  trình Wally. Bài kiểm trên máy gộp MỐC M2 — không xin anh test
  riêng gói (luật mốc lớn + B2 Điều 4).

## 8. Tiêu chí ra cổng gói (viết thành câu kiểm chứng được)
1. grep sau đẩy: 0 điểm `try? modelContext.save()` trong các file
   thuộc phạm vi WP6; mọi catch đều gán văn bản lỗi hiển thị và
   KHÔNG chạy onDone/dismiss trong nhánh lỗi.
2. Thao tác thật trên bản build (gộp buổi M2): ép lưu lỗi (khoá máy
   giữa chừng không tái hiện được thì dùng đường QA đã ghi ở cổng —
   tối thiểu: rà code từng điểm + 1 lần xoá thật cho thấy ảnh chỉ
   mất sau khi bản ghi mất — B-6).
3. Tổng Trang Chủ/Báo Cáo/Danh Sách: chụp cùng một kho, số chính
   thức chỉ gồm tờ reviewed; số chờ hiện riêng có nhãn; đối chiếu
   tay tổng reviewed khớp.
4. Một tờ lệch số học: nút Duyệt tắt + chữ nói rõ cờ; xác nhận kèm
   cờ qua hộp thoại → tờ vào sổ, mở Chi Tiết cờ VẪN hiện + dấu
   "đã xác nhận kèm cờ" hiện.
5. Sửa số tại Kiểm Lại: sửa lệch → ở lại Hộp Chờ với cờ mới; sửa
   đúng hết → rời Hộp Chờ ngay tại Kiểm Lại (C-3 hai chiều).
6. Đổi loại thẻ: hộp thoại báo số tờ SẼ đổi trước khi làm; tờ đã
   duyệt + tờ xếp tay không đổi; classificationReason của các tờ
   không bị quét giữ nguyên văn.

## 9. Đối chiếu danh mục lỗi không được lặp (TEAM.md + B2)
- #1 framework lạ lúc khởi động: WP6 không framework mới; seed thẻ
  (B-5) vẫn ở đường khởi động hiện hữu — sửa của nó chỉ đổi xử lý
  lỗi, không thêm chạm framework.
- #2 sai kiểu/optional: bước 2 rà mọi điểm save/fetch đổi chữ ký.
- #3 API chưa kiểm chứng trên máy: không API/UI mới; hộp thoại xác
  nhận kèm cờ dùng confirmationDialog sẵn có (đã chạy ở nút Xoá).
- #4 suy đoán thay bằng chứng: mọi khẳng định mục 1 đều là grep/
  đọc trực tiếp trên thành phần code của run #20, ghi kèm số dòng.
- L-2026-11-10-2 (sửa không áp dữ liệu đã lưu): mục 6 là mục bắt
  buộc của đặc tả này — WP6 áp lên kho đã lưu bằng chính thiết kế.
- B2 Điều 1: bài kiểm cổng (mục 8) chạy trên đúng luồng anh làm
  (mở app → nhìn tổng → duyệt một tờ → xoá một tờ), không chỉ linh
  kiện rời — phần máy thật đo ở buổi M2, khai rõ là chưa đo cho
  tới lúc đó.

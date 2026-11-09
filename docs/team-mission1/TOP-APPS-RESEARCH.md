# NGHIÊN CỨU APP TOP APP STORE — ĐỢT 2: HỌ ĐỌC TỐT NHỜ ĐÂU, VÀ MÌNH HỌC ĐƯỢC GÌ CHO BUILD 2

Chuyên gia Nghiên cứu Thị trường/Sản phẩm — 2026-11-08 (đêm CST)
Lệnh của anh: *"Tìm hiểu kỹ các app top của appstore mà nghiên cứu để có ý tưởng mà build."*

**Phạm vi đợt này (không lặp đợt 1):** DESIGN-V2.md đã lo UI/teardown giao diện, FEATURES.md đã lo danh mục tính năng. Đợt 2 chỉ trả lời 4 câu đợt 1 chưa trả lời: (1) pipeline đọc thật của các app top — on-device hay cloud, có gì công khai; (2) UX sửa lỗi khi đọc sai; (3) ý tưởng xếp hạng cho đúng các tầng Build 2 theo QA-VERDICT Phụ lục B; (4) dataset hoá đơn công khai nào dùng được cho bộ mẫu chấm điểm.

**Quy ước bằng chứng:** [FACT — nguồn] = có nguồn công khai nêu tên ngay tại chỗ · [INFERENCE] = suy luận của chuyên gia, ghi rõ · Số % chính xác do hãng tự công bố đều ghi "theo hãng" — **không có bên thứ ba nào kiểm chứng độc lập các con số 98–99,9% này**; một bài test độc lập hiếm hoi (DataConvertPro, 50 hoá đơn/app gồm giấy nhiệt, nhàu, phai mực) đo OCR thuần app ở khoảng **85–94%** tuỳ app, và chỉ khi cộng người kiểm mới lên 98%+ [FACT — dataconvertpro.com].

---

## 0. KẾT LUẬN NHANH (đọc phần này là đủ để ra quyết định)

1. **Mọi app trích-xuất-trường giỏi nhất đều là CLOUD ML huấn luyện trên hàng trăm triệu hoá đơn + có người đỡ khi máy bí.** Expensify, Dext, SparkReceipt, Veryfi, QuickBooks — không ngoại lệ. [FACT — mục 1]
2. **App on-device thuần (Scanner Pro, Genius Scan) chỉ làm OCR-ra-chữ và làm rất tốt phần CHỤP + XỬ LÝ ẢNH; họ KHÔNG trích trường hoá đơn.** Tức là "đọc tốt" của họ = ảnh sạch + chữ đúng, không phải "hiểu hoá đơn". [FACT — mục 1.2, 1.3]
3. **Không ai trong số họ dùng khuôn mẫu theo tiệm (template) ở tầng lõi.** Veryfi nói thẳng: mô hình nền tảng huấn luyện trên hàng trăm triệu hoá đơn, hiểu mọi bố cục, không cần template. Điều này xác nhận hướng anh đã chốt (trích theo bộ trường chuẩn — ACCOUNTING-SPEC §0) là đúng hướng ngành đang đi; template chỉ là tăng tốc phụ. [FACT — veryfi.com/receipt-ocr-api]
4. **Vũ khí bí mật thứ hai của họ là KIỂM CHỨNG SỐ HỌC + ĐỘ TIN CẬY TỪNG TRƯỜNG**, không phải OCR mạnh hơn: Veryfi trả `score` từng trường + `ocr_score` cả trang + bounding box theo yêu cầu; giá trị "suy ra" (enrich/compute) bị gắn cờ riêng để phân biệt với giá trị đọc được. Đây là thứ **copy được hoàn toàn trên máy** — và ACCOUNTING-SPEC §2 (V1–V10) của mình đã ở đúng đường này. [FACT — docs.veryfi.com, faq.veryfi.com]
5. **Chất lượng ảnh lúc chụp là đòn bẩy rẻ nhất**: coaching thời gian thực (khung xanh của QuickBooks, cảnh báo mờ + độ-tin-cậy-phát-hiện-tài-liệu của Genius Scan, kiểm tra mờ/lệch + tự bật đèn theo ánh sáng <30ms của Veryfi Lens) ngăn lỗi trước khi OCR chạy. [FACT — mục 1]
6. **Phần mình KHÔNG copy được** (cloud ML trăm triệu mẫu, LLM ngữ nghĩa kiểu SparkReceipt/ChatGPT, đội người kiểm của Shoeboxed, CNN nhận logo của Veryfi) — và tương đương on-device gần nhất cho từng món — liệt kê ở mục 3.2. Tin tốt: iOS 26 `RecognizeDocumentsRequest` (hiểu cấu trúc: đoạn/bảng/danh sách + DataDetection bắt ngày/tiền tệ ngay trong engine) là bước nhảy on-device thật sự duy nhất hiện có, và QA-VERDICT 0.1(b) đã xếp nó vào bài test pipeline riêng — nghiên cứu này xác nhận đó là lựa chọn đúng. [FACT — WWDC25 session 272, tài liệu Apple]

---

## 1. PIPELINE ĐỌC CỦA TỪNG APP — CÔNG KHAI ĐẾN ĐÂU

### 1.1 Expensify SmartScan — cloud, nhiều lớp, có người đỡ

- **Kiến trúc (theo chính Expensify giải thích, bản 2014 còn lưu qua easycloudsolutions.com):** SmartScan là hệ nhiều lớp: (1) OCR trích chữ từ ảnh; (2) phân tích chữ để gán merchant / amount / date; (3) đối chiếu danh sách chi tiêu sẵn có để bắt trùng; (4) **khi cần, gắn cờ cho "secure technicians" — người thật của Expensify — kiểm lại.** [FACT — easycloudsolutions.com, trích giải thích của Expensify]
- **3 trường bắt buộc:** merchant, purchase date, total amount — thiếu 1 trong 3 thì hoá đơn bị coi là "không truy vết được" và Concierge chủ động nhắn hỏi người dùng. [FACT — tài liệu cộng đồng Expensify, qua nghiên cứu benchmark javajack/reimbursement trên GitHub]
- **Bất đồng bộ tuyệt đối:** theo FAQ cộng đồng của chính Expensify, SmartScan historically mất **"vài phút tới vài giờ"**, "tối ưu cho chính xác thay vì tốc độ", người dùng được bảo cứ đóng app. [FACT — community.expensify.com FAQ, qua benchmark GitHub nêu trên]
- **Số hãng công bố:** 98,6% chính xác — do bên thứ ba (mastersccg.com) dẫn lại marketing của Expensify, **chưa kiểm chứng độc lập**. [FACT về việc con số tồn tại; độ tin cậy của con số: UNVERIFIED]
- **Không công khai:** engine OCR nào, model gì, có template không — **not public**. [FACT về tính không công khai]

### 1.2 Scanner Pro (Readdle) — on-device 100%, và CHỈ OCR chữ

- **Text Vision OCR chạy hoàn toàn trên máy** bằng mô hình neural on-device, 30+ ngôn ngữ, không tải gì lên server, hoạt động offline; sản phẩm là **lớp chữ tìm-được/chọn-được** trên PDF — không có trích trường merchant/total nào cả. [FACT — readdle.com blog "What is OCR?", support.readdle.com]
- Phần chụp: tự phát hiện cạnh, nắn perspective, xoá bóng — đầu ra là ảnh sạch để OCR. [FACT — readdle.com]
- **Bài học:** chuẩn "đọc tốt" của Scanner Pro = pipeline ảnh + OCR chữ tốt. Nó chứng minh on-device làm được nửa đầu của vấn đề; nửa "hiểu trường" nó không hề làm.

### 1.3 Genius Scan (The Grizzly Labs) — on-device 100% kể cả OCR, kỹ thuật chụp công khai chi tiết nhất

- Toàn bộ xử lý gồm OCR **chạy offline trên máy**; SDK của họ (cùng lõi với app) công khai: phát hiện tài liệu thời gian thực, nắn méo gồm **perspective VÀ curvature (cong trang)**, tự xoay đúng hướng bằng AI, **phát hiện mờ và cảnh báo**, xoá bóng/vết bẩn. [FACT — geniusscansdk.com/features, Play Store listing]
- Chi tiết đáng giá nhất (changelog SDK chính thức): họ gắn **mức tin cậy 5 bậc cho việc phát hiện tài liệu** (Lowest→Highest) và dùng nó để quyết định **có bắt người dùng xác nhận viền tài liệu trước khi tự cắt hay không** — tin cậy cao thì tự làm, thấp thì hỏi. [FACT — geniusscansdk.com/docs/changelog, v6.2.0 PR #1669]
- Changelog cũng cho thấy lõi phát hiện tài liệu là **neural network inference on-device** (migrate sang LiteRT V2). [FACT — cùng nguồn]
- **Không trích trường hoá đơn** — sản phẩm là PDF + lớp chữ. Giống Scanner Pro: thắng ở khâu ảnh.

### 1.4 Dext (ex-Receipt Bank) — cloud AI+OCR, quy mô lớn, có tầng "data health"

- Cloud hoàn toàn: chụp/email/upload → AI+OCR trích supplier, date, total, line items, tax → phân loại → đồng bộ phần mềm kế toán. Theo Dext: xử lý **>320 triệu tài liệu/năm**, chính xác **99,9%** (số của hãng, trên tài liệu sạch theo các bài review dẫn lại; tài liệu hư nặng vẫn cần người duyệt). [FACT về công bố — dext.com, softwareadvice.ie, aitrendytools.com]
- Blog chính thức của Dext mô tả pipeline gồm **tiền xử lý ảnh (normalisation, noise reduction)** trước OCR, rồi "validation rules and pattern recognition" ở tầng trích xuất, và **học từ lần sửa của người dùng** để cải thiện phân loại. [FACT — dext.com/uk/blog "the most accurate receipt OCR software"]
- **Dext Precision**: lớp kiểm sức khoẻ dữ liệu (data health checks / error analysis) sau trích xuất — tức họ cũng không tin OCR tuyệt đối, họ kiểm chéo sau. [FACT — fahimai.com review, dext.com]
- **Không công khai:** engine/model cụ thể — not public.

### 1.5 SparkReceipt — cloud OCR + LLM (ChatGPT) hiểu ngữ nghĩa

- Theo review độc lập: SparkReceipt dùng **OCR + ChatGPT AI** để hiểu nội dung hoá đơn (không chỉ đọc chữ): trích merchant, date, total, taxes, phân loại; xử lý được cả hoá đơn nhàu/phai trong test của reviewer. [FACT — trombonegeek.com review 2026]
- Theo trang chính thức: trích vendor, total, subtotal, tax, date, currency, payment method, line items trong **2–3 giây/tờ**; 190 tiền tệ; **mọi trường đều sửa được, sửa 1 chạm và AI học vendor của bạn theo thời gian**; trả lời 1 câu bằng tiếng Anh thường ("Amazon order này là thiết bị") thì hệ thống biến thành **luật** áp cho các tờ sau. [FACT — sparkreceipt.com]
- Hãng tự công bố 99,9% (qua receiptflow.agency, kênh marketing) — UNVERIFIED độc lập.
- **Không công khai:** OCR engine nền là gì — not public. Phần "hiểu" là LLM cloud — **đây là món không copy được on-device nguyên dạng** (xem 3.2).

### 1.6 QuickBooks Receipt Capture (Intuit) — cloud, trích ÍT trường, thắng ở coaching + đối chiếu sao kê

- Chụp trong app → OCR cloud trích **payment date, total amount, merchant name, payment method** — bài test độc lập ghi nhận trung bình chỉ khoảng **4 trường/tờ**; OCR **không lộ ra API**, chỉ sống trong app/web của Intuit. [FACT — certumsolutions.com, henssler.com, sayfocus.me]
- Camera có **khung chuyển xanh khi phát hiện hoá đơn đặt đúng vị trí** (coaching lúc chụp) + hướng dẫn cụ thể: vuốt phẳng hoá đơn, đủ 4 góc trong khung, 1 tờ/1 ảnh. [FACT — certumsolutions.com]
- Sau đọc: hoá đơn vào tab **"For Review"**; hệ thống **tự đối chiếu với bank feed** (vendor+date+amount) và gợi ý Match. Reviewer cũng ghi nhận nó vật lộn với chữ tay, giấy nhiệt phai, đa tiền tệ. [FACT — certumsolutions.com, tapsayve.com]
- **Bài học:** ngay cả Intuit cũng chỉ trích vài trường lõi + dựa vào duyệt tay và đối chiếu sao kê. "Top app" không đồng nghĩa "đọc hết mọi trường".

### 1.7 Veryfi — công khai sâu nhất; chuẩn để mình soi vào

Veryfi là vendor duy nhất **công bố kiến trúc theo tầng** và danh sách trường gần như đầy đủ. Đây là nguồn tham chiếu chính cho Build 2.

**a) Lens (SDK chụp, on-device):** [FACT — veryfi.com/receipt-ocr-api, veryfi.com/lens]
- "Document AI detection" — phát hiện tài liệu bằng AI (không chỉ tìm cạnh; xử lý được cả hoá đơn trắng trên bàn trắng — theo nghiên cứu benchmark GitHub tổng hợp từ trang Lens), kiểm tra **mờ / cong vênh (warp) / giả mạo** theo thời gian thực.
- Phân tích ánh sáng môi trường **<30 ms** để tự bật đèn pin.
- **Ghép (stitch) hoá đơn dài** kiểu panorama; chụp tới **4 tài liệu trong 1 khung**; chụp offline, đồng bộ sau; có "on-device extraction" theo trang sản phẩm Lens (mức độ extraction on-device đầy đủ đến đâu: hãng không mô tả chi tiết — ghi nhận thận trọng).
- Burst mode cho chụp số lượng lớn.

**b) Cloud API (phần trích trường thật):** [FACT — veryfi.com/receipt-ocr-api]
- "Proprietary foundational models trained on **hundreds of millions of receipts**", hiểu dữ liệu "irrespective of receipt structure, geography or language" — **không template**.
- Pipeline 6 stage công bố: (1) Image Intelligence — blur detection, image quality, document/non-document classification, **auto de-skew, smart cropping, linearization**; (2) Content Detection — **logo detection/classification**, barcode/QR; (3) Advanced Text Processing — multi-language OCR, handwriting, **text confidence scoring**, character enhancement; (4) Document Intelligence — data extraction engine, document classification, **line item analysis, tax calculation**, currency detection; (5) Fraud & QA — duplicate detection, LCD/screenshot/tampering detection; (6) output.

**c) Trường trích ra (150+; đối chiếu với bộ trường chuẩn của ACCOUNTING-SPEC §1):** [FACT — faq.veryfi.com "Data Extraction Fields Explained", veryfi.com/lens field list]
- Vendor: name + **raw_name** (bản chưa chuẩn hoá — giữ song song!), address + raw_address, store number, phone, **logo**.
- Tiền: subtotal, **discount, cashback, shipping, tax, tip, total, rounding**, currency + exchange rate.
- **Tax lines breakdown**: từng dòng thuế (name, rate %, amount, base) — khớp đúng yêu cầu C3 của ACCOUNTING-SPEC (taxLines[] dạng danh sách).
- Payment: **card type + card number (last 4)** — khớp D2 của mình.
- Line items ở mức SKU: description, SKU/UPC/HSN, quantity, unit of measure, price, tax, tax rate, discount, total, **type** (food/product/alcohol/tax/discount/payment/refund… — taxonomy loại dòng công bố ở faq.veryfi.com Data Enrichment), weight, section.
- **Cách Veryfi nhận diện vendor khi thiếu chữ:** nhận diện **từ logo alone**; nếu không có tên lẫn logo thì **suy từ line items** (sản phẩm đặc trưng → vendor). [FACT — faq.veryfi.com Data Enrichment] Đây là chuỗi fallback đáng học cho lỗi C-18 "How doers" (xem mục 3, ý T0-8).

**d) Kiểm chứng & độ tin cậy — phần đáng copy nhất:** [FACT — docs.veryfi.com, nutrient.io comparison, faq.veryfi.com]
- Mỗi trường có **`score`** (độ tin cậy giá trị thuộc về trường đó) và cả trang có **`ocr_score`** 0–1; **bounding boxes trả kèm khi yêu cầu**.
- **Enrichment bị lộ diện:** trường do hệ thống "làm giàu" (suy ra) thì **thiếu score và bounding box**, và có cờ `"enriched"` — tức người dùng API **phân biệt được số-đọc-được với số-bị-suy-ra**. [FACT — faq.veryfi.com]
- **Cảnh báo cho mình (khác biệt triết lý):** một số trường của Veryfi là **"Computable"** — vd **không tìm thấy subtotal thì TỰ TÍNH** subtotal = total − tax − tip; due_date tự tính từ payment terms. [FACT — faq.veryfi.com] → **ACCOUNTING-SPEC của mình cấm đúng việc này ở tầng lưu trữ** (chỉ được tính để *đối chiếu*, C1; số suy ra phải ghi rõ derived, C2). Học Veryfi ở khoản *gắn cờ derived*, **không** học khoản *lặng lẽ điền số tính ra vào trường chính thức*.
- Trùng lặp: `meta.duplicates` chứa id + score của bản trùng; phương pháp bắt trùng gồm text_similarity / field_matching. [FACT — veryfi.com/receipt-ocr-api, docs.veryfi.com]
- Vendor thứ ba (Nutrient) đúc kết quy tắc chọn ngưỡng duyệt: **"Pick review thresholds from errors observed on your own labeled set"** — ngưỡng tin cậy phải hiệu chuẩn trên bộ mẫu gán nhãn của chính mình, không mượn số của hãng. [FACT — nutrient.io/blog/best-invoice-data-extraction-apis] → củng cố trực tiếp cho cơ chế scorecard corpus của mình.

### 1.8 Shoeboxed — OCR + NGƯỜI kiểm mọi tờ (cực trị của human-in-the-loop)

- Khác biệt cốt lõi: **mọi dữ liệu trích ra đều được data-entry specialists kiểm lại bằng mắt**; có cả dịch vụ gửi phong bì giấy (Magic Envelope) tới trung tâm quét. Thời gian xử lý ~24 giờ cho khâu kiểm. [FACT — shoeboxed.com/features, shoeboxed.com/security]
- Hãng và các bài test độc lập đều xếp: app-only ~90–94%, **có người kiểm mới lên ~95–99%**. [FACT — dataconvertpro.com test 50 tờ/app; shoeboxed.com]
- **Bài học trung thực nhất của đợt nghiên cứu:** ở đẳng cấp thị trường, "chính xác gần tuyệt đối" cho hoá đơn thuế = máy đọc + **người duyệt**. Mình không có đội người — nhưng mình có **anh** + Hộp Chờ. Kết luận thiết kế: đừng cố bắt chước độ chính xác của họ bằng OCR; bắt chước **kiến trúc** của họ: máy làm nháp nhanh, vòng người-duyệt làm cho rẻ và nhanh nhất có thể (mục 2).

### 1.9 Microsoft Lens — đã khai tử; bài học còn lại là "chế độ chụp theo loại tài liệu"

- Microsoft Lens bị Microsoft cho nghỉ hưu cuối 2025 (ngừng tạo scan mới từ 15/12/2025 theo Microsoft Support; gỡ khỏi store cùng giai đoạn), chức năng scan chuyển vào Microsoft 365 Copilot/OneDrive. [FACT — thurrott.com dẫn Microsoft Support, microsoft.fandom.com]
- Di sản đáng học: **capture modes theo loại nội dung** — Document mode được mô tả là tối ưu cho "small text on flyers, forms, menus, posters, and **receipts**", Whiteboard mode xử lý loá/bóng riêng; tự cắt cạnh, nắn perspective, xoá bóng. [FACT — microsoft.fandom.com, updf.com tổng hợp]
- Ghi nhận để khỏi đề xuất nhầm: **đừng học theo Lens nữa** (đã chết), học nguyên tắc mode-hoá của nó thôi.

### 1.10 Google Drive scan / ML Kit Document Scanner — pipeline chụp on-device chuẩn của Google

- ML Kit Document Scanner API (Android; là nền của Drive scan trên Android): **toàn bộ flow chạy on-device** — tự chụp khi phát hiện tài liệu, phát hiện cạnh chính xác, tự nhận hướng xoay, cho crop tay, **bộ lọc (grayscale, auto enhancement), xoá bóng, xoá vết bẩn**, và chế độ FULL có **ML cleaning (xoá ngón tay/vết bẩn)**. [FACT — developers.google.com/ml-kit/vision/doc-scanner]
- Trên iOS không có ML Kit scanner tương đương — tương đương của mình là VisionKit (mục 1.11). Ghi để đội khỏi tìm nhầm SDK.

### 1.11 Apple Notes / Files + Vision framework — "app top" ngay trong máy anh, và engine on-device duy nhất hiểu cấu trúc

- Notes/Files dùng **document camera của hệ thống** (VisionKit `VNDocumentCameraViewController`): highlight cạnh trực tiếp, **tự chụp khi phát hiện đủ biên trang**, nắn perspective, cho chỉnh góc tay sau chụp; bản scan được OCR để tìm kiếm toàn văn. [FACT — support.apple.com "Scan text and documents in Notes"; phân tích kỹ thuật medium.com về VNDocumentCameraViewController]
- Đường tự làm khi không dùng UI hệ thống: `VNDetectRectanglesRequest` → `CIPerspectiveCorrection` — cặp API cổ điển cho phát hiện tứ giác + nắn phẳng ảnh đã chụp/import. [FACT — cùng nguồn medium, đối chiếu tài liệu Apple]
- **iOS 26 `RecognizeDocumentsRequest`** (WWDC25 session 272 "Reading documents using Vision"): trả `DocumentObservation` có cấu trúc phân cấp — **paragraphs, tables (rows/columns/cells), lists, barcodes** — và chạy **DataDetection** ngay trong engine để bắt **dates, money/currency, addresses, phone, email, URL, tracking/flight numbers**; 26 ngôn ngữ; **toàn bộ on-device** ("all of Vision's processing happens on the user's device" — Apple). [FACT — developer.apple.com sample "Recognizing tables within a document", WWDC25-272, tổng hợp wwdc-journal GitHub]
- Giới hạn phải nói thẳng: Apple **không công bố** độ chính xác của RecognizeDocumentsRequest trên hoá đơn; nó hiểu *cấu trúc tài liệu* chứ không phải model *trích trường hoá đơn* kiểu Veryfi (không có khái niệm vendor/total/tax sẵn). Tầng gán trường vẫn là parser của mình — nhưng parser sẽ ăn dữ liệu **đã có hàng/cột** thay vì mảnh chữ rời. [FACT về việc không công bố + INFERENCE về hệ quả kiến trúc]

---

## 2. UX SỬA LỖI — KHI ĐỌC SAI, APP TOP LÀM CHO VIỆC SỬA RẺ THẾ NÀO

1. **Định tuyến theo ngưỡng tin cậy (confidence-threshold routing).** Chuẩn ngành tài liệu: trường ≥ ngưỡng (Azure Document Intelligence dùng mốc tài liệu hoá **0.80**) thì đi thẳng, dưới ngưỡng thì vào hàng duyệt. Nhưng ngưỡng phải **hiệu chuẩn trên bộ mẫu gán nhãn của chính mình** (Nutrient). → Áp cho mình: mốc 85/60 trong BLUEPRINT chỉ là khởi điểm; sau mỗi vòng scorecard phải chỉnh lại theo lỗi thật trên corpus của anh. [FACT — benchmark javajack/reimbursement GitHub; nutrient.io]
2. **Trường ↔ vùng ảnh (grounding).** Rossum (chuẩn tham chiếu của mảng validation UI): hộp xanh dương = máy đọc, **chỉ chuyển xanh lá khi người đã xác nhận**; Veryfi/Nutrient: mỗi giá trị kèm bounding box + trang để "a value that reaches approval should be traceable to the page". → Trên máy mình làm được y hệt ở mức dữ liệu: Vision observation đã có bounding box — chạm vào trường trong Review thì **highlight đúng vùng chữ trên ảnh** để anh đối chiếu 1 giây. [FACT — benchmark GitHub về Rossum; docs.veryfi.com; nutrient.io]
3. **Nhảy thẳng tới trường có vấn đề.** Rossum: phím Tab nhảy qua các trường low-confidence. Bản di động của pattern này: nút **"Trường tiếp theo cần xem"** trong Review — chỉ đi qua trường bị cờ/tin cậy thấp, không bắt cuộn cả form. [FACT pattern — benchmark GitHub; INFERENCE về bản di động]
4. **Thiếu trường lõi thì HỎI, và luôn có lối thoát tự điền.** Expensify: thiếu merchant/date/total → Concierge chủ động đặt câu hỏi; đồng thời luôn có **"Fill out details myself"** để sửa mọi trường mà không chờ OCR. Học cả hai: Review của mình nên mở đầu bằng đúng câu hỏi còn thiếu ("Chưa đọc được TỔNG — anh nhìn giấy điền giúp, hoặc chụp lại"), không chôn trong danh sách cảnh báo dài. [FACT — benchmark GitHub tổng hợp tài liệu Expensify]
5. **OCR là BẢN NHÁP, không bao giờ là cổng.** Expensify để hoá đơn sống tiếp dạng draft trong lúc scan chạy nền vài phút–vài giờ; SparkReceipt: "every extracted field is editable". DESIGN-V2 của mình đã có async "Đang đọc…" — nghiên cứu này xác nhận đó là chuẩn ngành, giữ nguyên. [FACT — community.expensify.com qua benchmark; sparkreceipt.com]
6. **Số suy ra phải đeo biển "suy ra".** Veryfi lộ enrichment bằng cờ riêng + thiếu box/score. → Mọi giá trị app tự tính để gợi ý (vd subtotal-từ-tổng-dòng) phải hiển thị nhãn **"số suy ra — không in trên giấy"** và không bao giờ lưu thành số chính thức nếu anh chưa xác nhận (khớp ACCOUNTING-SPEC C1/C2 và điều cấm tự sửa số). [FACT — faq.veryfi.com; neo ACCOUNTING-SPEC §1–2]
7. **Trùng lặp: gắn cờ CẢ HAI bản, treo lại, cho chọn.** Expensify: hai expense cùng date+amount+currency → cả hai bị "Potential duplicate" đỏ, bị hold, giải quyết bằng Keep all / Keep this one. Veryfi: meta.duplicates kèm score. → Khớp F6/V9 của ACCOUNTING-SPEC (đánh dấu duplicateOf + excludedFromTotals, không xoá); DESIGN-V2 đã có so sánh 2 ảnh cạnh nhau — bổ sung: **cờ phải hiện ở cả bản cũ** chứ không chỉ bản mới. [FACT — benchmark GitHub; veryfi.com]
8. **Ngăn lỗi từ lúc chụp (rẻ hơn sửa sau).** Khung-xanh của QuickBooks; cảnh báo mờ + ngưỡng tin cậy phát hiện của Genius Scan (thấp thì bắt xác nhận viền); Lens của Veryfi kiểm mờ/vênh thời gian thực + tự bật đèn. Nguyên tắc chung của benchmark ngành: *"fixes image quality at the source, which is the single biggest OCR-accuracy lever; cheaper than any post-hoc correction UX."* [FACT — certumsolutions.com; geniusscansdk.com changelog; benchmark GitHub]
9. **Hướng dẫn chụp dành riêng cho hoá đơn nhàu:** QuickBooks hướng dẫn công khai: **vuốt phẳng hoá đơn**, đủ 4 góc, 1 tờ/ảnh. Nghe nhỏ nhưng đó là cách họ xử "crumpled paper" ở tầng hành vi thay vì tầng model. → Onboarding/man camera của mình nên có đúng 2 câu này, kèm mẹo đè nhẹ 2 đầu tờ giấy nhiệt bị cuộn. [FACT — certumsolutions.com; INFERENCE về mẹo đè giấy]
10. **Học từ lần sửa — nhưng học CÓ CẤU TRÚC.** Dext học phân loại từ corrections; SparkReceipt biến câu trả lời tiếng Anh thành luật (cloud LLM). Phần copy được on-device: **luật theo tiệm + luật theo đuôi thẻ** (FEATURES.md đã chốt) và **gợi ý luật dạng mẫu có sẵn** ("Từ nay hoá đơn Home Depot → Vật tư?") thay vì hiểu ngôn ngữ tự do. [FACT — dext.com blog, sparkreceipt.com; INFERENCE về tương đương on-device]
11. **Người kiểm là tính năng, không phải thất bại.** Shoeboxed bán "human-verified" như điểm cộng lớn nhất. → Đổi góc nhìn cho Hộp Chờ của mình: thông điệp trong app nên là "đã qua mắt người = chứng từ chắc" (khớp kỷ luật reviewed của ACCOUNTING-SPEC §2.2), không phải "app đọc dở nên anh phải sửa". [FACT — shoeboxed.com; INFERENCE về thông điệp]
12. **Thí nghiệm độc lập đáng chú ý — "hoá đơn là một checksum":** một developer chạy thử công khai (dev.to, 2026-10): model Donut fine-tune trên CORD đọc đúng **88% tờ hoàn hảo trên CORD test** nhưng sang WildReceipt (hoá đơn Mỹ chụp ngoài đời, chưa từng thấy) chỉ đúng **~51% số dòng**; khi cộng **kiểm chứng số học (Σ dòng = tổng) làm trọng tài** giữa hai bộ đọc, tỉ lệ tờ-đúng tăng vọt và hệ thống **biết tờ nào đáng tin** (93% các tờ được "tick xanh" là đúng thật). → Đây là bằng chứng độc lập cho kiến trúc: **hai lượt đọc + V-rules làm trọng tài + gắn cờ theo kết quả kiểm** — làm được 100% on-device. [FACT — dev.to/vanshajpoonia "A receipt is a checksum"]

---

## 3. Ý TƯỞNG XẾP HẠNG CHO BUILD 2

### 3.1 Bảng ý tưởng áp dụng được

Tầng theo QA-VERDICT Phụ lục B: **T0** = chất lượng đọc · **T1** = niềm tin dữ liệu · **Sau** = sau T0/T1.

| # | Ý tưởng | Học từ | Chữa đúng bệnh gì của mình | Tầng | Công / rủi ro |
|---|---|---|---|---|---|
| 1 | **Đánh giá engine `RecognizeDocumentsRequest`** trong bản test pipeline riêng (đã có ở verdict 0.1b — nghiên cứu xác nhận và bổ sung: nó trả sẵn hàng/cột của bảng + DataDetection bắt money/date, đúng thứ parser mình đang thiếu) | Apple Vision iOS 26 (WWDC25-272) | Cột tiền bị xé dòng (Mẫu 002); dòng món rời rạc (Mẫu 003) — nếu engine hiểu cấu trúc thắng, bài toán ráp hàng được giải ở tầng engine thay vì vá parser | T0 | Công trung bình (bản test riêng); rủi ro: chưa ai công bố độ chính xác trên hoá đơn → **scorecard quyết**, không tin quảng cáo |
| 2 | **Chụp bằng document camera hệ thống + coaching**: highlight cạnh trực tiếp, tự chụp khi đủ biên; sau chụp chấm nhanh độ mờ/tương phản, dở thì nhắc chụp lại NGAY tại chỗ | Apple Notes/VisionKit; QuickBooks khung xanh; Genius Scan blur detection | Hoá đơn giấy nhàu chụp thường (Mẫu 003 là ảnh chụp thường, không qua nắn thẳng) — ngăn ảnh dở vào OCR | T0 | Công thấp (VNDocumentCameraViewController có sẵn); rủi ro thấp. Lưu ý đường import ảnh cũ vẫn cần ý #3 |
| 3 | **Tiền xử lý ảnh cho ảnh IMPORT (không qua camera)**: phát hiện tứ giác (VNDetectRectanglesRequest) → nắn perspective (CIPerspectiveCorrection) → tăng tương phản thành **ảnh phái sinh**, ảnh gốc giữ nguyên | Genius Scan / Scanner Pro / ML Kit (chuỗi xử lý ảnh on-device chuẩn ngành) | Ảnh tải về/chụp sẵn bị nghiêng, méo, tương phản thấp; khớp spec F2 (enhancedImage là derivative, không thay gốc) | T0 | Công trung bình; rủi ro: nắn sai làm hỏng chữ → luôn giữ gốc + chỉ OCR trên phái sinh khi phái sinh "đẹp" hơn theo điểm chất lượng |
| 4 | **Hai lượt đọc chéo + số học làm trọng tài**: đọc ảnh gốc và ảnh phái sinh (hoặc engine A và B) độc lập; hai kết quả khớp + qua V1–V10 → tin cậy cao; lệch → gắn cờ kèm **cả hai ứng viên** cho anh chọn | Thí nghiệm "receipt is a checksum" (dev.to); Veryfi text-confidence scoring | Đọc sai lặng lẽ là lỗi nguy hiểm nhất với hồ sơ thuế; biến "không chắc" thành tín hiệu đo được thay vì đoán | T0 (khung) / T1 (hiển thị ứng viên) | Công trung bình; rủi ro: chậm gấp đôi — chấp nhận được vì đọc chạy nền async |
| 5 | **Cắt lát hoá đơn dài có chồng lấp** (đã có ở verdict F2 — giữ nguyên, bổ sung căn cứ: Veryfi Lens giải bài toán hoá đơn dài bằng stitching ở tầng chụp; mình không có stitching thì slicing ở tầng đọc là tương đương thực tế) | Veryfi Lens long-receipt stitching | Hoá đơn Sam's dài (ảnh 554×1457 bị hạ nét khi OCR nguyên tấm) | T0 | Đã spec ở verdict; rủi ro khử trùng theo Y như verdict đã ghi |
| 6 | **Chuỗi fallback nhận diện vendor 3 nấc**: (i) khớp mờ tên tiệm trên TOÀN BỘ dòng (đã spec C-18) → (ii) neo phụ: địa chỉ/mã cửa hàng/số điện thoại khớp mẫu tiệm đã biết → (iii) gợi ý từ line items đặc trưng; cả 3 đều trượt thì để trống + ép Hộp Chờ, **cấm** lấy slogan/dòng đầu | Veryfi vendor-by-logo → vendor-by-line-items (faq.veryfi.com) | Lỗi C-18 "How doers" (Mẫu 003): vendor sai mà KHÔNG cờ — vi phạm cổng scorecard | T0 (nấc i, đã spec) / T1 (nấc ii–iii) | Công thấp–trung bình; rủi ro thấp; nấc (iii) chỉ gợi ý, không tự điền |
| 7 | **Lưu độ tin cậy TỪNG TRƯỜNG + hiệu chuẩn ngưỡng trên corpus của anh** (không mượn ngưỡng của hãng) | Veryfi score/ocr_score; Nutrient "thresholds from your own labeled set" | C-11 (độ tin cậy ghi mà không thực thi); cổng scorecard cần số đo để tiến bộ qua từng bản | T1 | Công thấp (Vision đã trả confidence); rủi ro: cần kỷ luật ghi parserVersion (spec F4 đã đòi) |
| 8 | **Chạm trường → highlight vùng chữ trên ảnh** trong Review/Chi tiết (dùng bounding box Vision đã có sẵn) | Rossum validation UI; Veryfi bounding boxes; Nutrient grounding | Anh duyệt 1 tờ trong vài giây thay vì dò mắt cả hoá đơn; đặc biệt cứu trường hợp cột tiền xa nhãn (Mẫu 002) | T1 | Công trung bình (ánh xạ hệ toạ độ ảnh↔view); rủi ro thấp; giá trị UX/rủi ro thuộc loại cao nhất trong bảng |
| 9 | **Luồng duyệt "chỉ đi qua chỗ có vấn đề"**: nút nhảy trường-bị-cờ tiếp theo + đầu Review mở bằng câu hỏi thiếu trường lõi (vendor/date/total) | Rossum Tab-to-low-confidence; Expensify Concierge hỏi trường thiếu + "Fill out details myself" | Hộp Chờ là vòng người-duyệt duy nhất của mình (bài học Shoeboxed) — phải làm nó nhanh như app top làm cho nhân viên của họ | T1 | Công thấp–trung bình; thuần UX trên dữ liệu đã có |
| 10 | **Nhãn "số suy ra"** cho mọi giá trị tính ra (không in trên giấy): hiển thị khác màu + không lưu thành chính thức khi chưa xác nhận | Veryfi "enriched" flag (học cơ chế lộ diện, KHÔNG học hành vi tự điền của họ) | Giữ ranh giới ACCOUNTING-SPEC: số in trên giấy ≠ số app tính; tránh "hồ sơ sạch giả tạo" | T1 | Công thấp; rủi ro: đừng để nhãn gây rối — chỉ hiện khi thật sự có số suy ra |
| 11 | **Cờ trùng hiện ở CẢ HAI bản + màn so sánh giữ/bỏ có liên kết duplicateOf** (DESIGN-V2 đã có so sánh 2 ảnh — bổ sung cờ hai chiều và trạng thái "đã loại khỏi tổng") | Expensify duplicate violations; Veryfi meta.duplicates | V9/F6 của ACCOUNTING-SPEC; chống tính trùng khi anh vừa chụp giấy vừa import PDF cùng 1 lần mua (F3 sourceType) | T1 | Công thấp; phần lớn đã spec |
| 12 | **Hướng dẫn chụp hoá đơn trong camera** (2 câu: vuốt phẳng, đủ 4 góc; mẹo với giấy cuộn) + nhắc "1 tờ 1 lần chụp" | QuickBooks capture guidance | Giấy nhàu là ca Mẫu 003; giảm lỗi từ nguồn với chi phí gần 0 | T0 (kèm ý #2) | Công rất thấp |
| 13 | **Ngưỡng tin cậy phát hiện tài liệu → quyết định hỏi hay tự cắt** khi sau này làm camera tuỳ biến sâu hơn VisionKit | Genius Scan SDK (5-level detection confidence) | Tránh tự cắt sai lặng lẽ trên nền khó (trắng-trên-trắng) | Sau | Chỉ áp dụng nếu rời VisionKit; hiện tại VisionKit tự lo — ghi để khỏi quên khi cần |
| 14 | **Đối chiếu sao kê bằng FILE anh tự nạp** (không nối ngân hàng): gợi ý ghép hoá đơn ↔ dòng sao kê theo amount+date+vendor | SparkReceipt statement matching; QuickBooks bank-feed matching | Bắt hoá đơn thiếu/trùng ở tầng sổ sách | Sau (v1.x) | FEATURES.md đã loại bản nối-ngân hàng; bản nạp-file là biến thể on-device chấp nhận được — **chỉ ghi nhận, chưa đề xuất làm** |

### 3.2 KHÔNG copy được — và tương đương on-device gần nhất

| Của họ | Vì sao không copy được | Tương đương on-device của mình |
|---|---|---|
| Model nền tảng huấn luyện trên **hàng trăm triệu hoá đơn** (Veryfi; tương tự ở Expensify/Dext) | Không có dữ liệu, không có hạ tầng train, và app của mình cấm server | `RecognizeDocumentsRequest` (model cấu trúc của Apple, train bởi Apple) + parser theo bộ trường chuẩn + V-rules; chấp nhận trần chính xác thấp hơn và **bù bằng vòng duyệt rẻ** (ý #8, #9) |
| **LLM hiểu ngữ nghĩa** hoá đơn (SparkReceipt/ChatGPT; "trả lời tiếng Anh → thành luật") | LLM cloud; gửi ảnh hoá đơn thuế ra ngoài trái triết lý dự án | Gợi ý luật dạng mẫu cố định ("Home Depot → Vật tư? [Lưu luật]") + luật theo tiệm/đuôi thẻ đã có ở FEATURES; Foundation Models on-device (đã xếp v1.2 ở FEATURES) là đường nâng cấp sau |
| **Người kiểm mọi tờ** (Shoeboxed; technician của Expensify) | Không có đội người, không có server | Anh + Hộp Chờ: biến việc duyệt thành thao tác giây (grounding #8, nhảy trường #9, hỏi đúng trường thiếu #9) — kiến trúc giống họ, "người" là chính chủ |
| **CNN nhận diện logo** vendor (Veryfi) | Cần model + thư viện logo huấn luyện sẵn | Chuỗi fallback chữ 3 nấc (ý #6): khớp mờ toàn văn + neo địa chỉ/mã cửa hàng + gợi ý từ line items |
| **Mạng lưới chống trùng/gian lận xuyên khách hàng** (Veryfi fraud, duplicates toàn hệ thống) | Cần dữ liệu tập trung của nhiều người dùng | Chống trùng nội bộ bằng khoá giao dịch A5 + ghép mờ V9 (ACCOUNTING-SPEC) — đủ cho 1 người dùng |
| **Đối chiếu bank feed trực tiếp** (QuickBooks, Dext, SparkReceipt) | Cần kết nối ngân hàng/server; FEATURES.md đã loại | Ý #14 dạng nạp file thủ công — để sau, không phải V1 |

---

## 4. DATASET HOÁ ĐƠN CÔNG KHAI — CHỈ LIỆT KÊ CÁI ĐÃ KIỂM CHỨNG TỒN TẠI

| Dataset | Đã kiểm chứng | Nội dung thật | Hợp với mình tới đâu |
|---|---|---|---|
| **SROIE** (ICDAR 2019 Robust Reading Challenge) | ✔ — bài báo ICDAR 2019 (Huang et al.), bản tổ chức lại trên Kaggle (urbikn/sroie-datasetv2) | **973 hoá đơn** scan (626 train / 347 test), mỗi tờ có ảnh JPG + text OCR + nhãn **4 trường: company, date, address, total**. Hoá đơn tiếng Anh, phần lớn từ Malaysia, scan phẳng | Dùng làm **bài test khói (smoke test)** cho tầng trích company/date/total và so engine A/B. **Không** đại diện hoá đơn Mỹ chụp bằng điện thoại — đừng lấy điểm SROIE làm điểm cổng |
| **CORD** (NAVER CLOVA, **CC BY 4.0**) | ✔ — github.com/clovaai/cord; Hugging Face naver-clova-ix/cord-v1 (và cord-v2) | Thu thập **>11.000 hoá đơn Indonesia**; bản công khai v1: **1.000 tờ** gán nhãn (800/100/100) với **30 loại trường** gồm menu items (tên/SL/đơn giá/thành tiền), subtotal, tax, service, total — nhãn kèm bounding box, định hướng **post-OCR parsing** | Bộ tốt nhất để stress-test **parser cấp dòng** (ý #4/#5) ở quy mô lớn. Hạn chế: định dạng Indonesia, một số bản phái sinh che vendor/date — kiểm tra trường trước khi chấm |
| **WildReceipt** (Sun et al. 2021, **Apache-2.0**) | ✔ — benchmark inventory (MMOCR), bài IJDAR 2026 về conformal prediction dùng chính nó, thí nghiệm dev.to chạy thật trên nó | **1.740 ảnh hoá đơn CHỤP NGOÀI ĐỜI bằng điện thoại** (1.268 train / 472 test), **25 loại trường**, ~69K text boxes, **1.192 template khác nhau**, chủ yếu nhà hàng/shop ở **Mỹ**; ảnh có góc nghiêng, nếp gấp | **Giống điều kiện Mẫu 003 nhất** (chụp thường, nhàu, nhiều template lạ) → ứng viên số 1 làm **làn phụ của scorecard**: chạy engine trên test split 472 tờ để đo độ bền ngoài 3 fixture nhà mình. Bằng chứng dev.to: model xịn trên CORD rơi từ 88% → ~51% dòng đúng khi sang WildReceipt — corpus không giống điều kiện thật thì điểm là dối |
| **FUNSD** | ✔ tồn tại — nhưng **không phải hoá đơn** | 199 form scan nhiễu (question/answer/header), cho bài toán hiểu form | **Không dùng** cho scorecard hoá đơn; chỉ ghi để đội khỏi nhầm khi tìm kiếm |

**Cách dùng khuyến nghị (gắn vào verdict 0.3):** cổng phát hành vẫn là 3 fixture của anh (001/002/003) — đó là điều kiện thật của anh. Dataset công khai chỉ làm **làn đo phụ trong phòng lab** (đặc biệt WildReceipt test split) để phát hiện engine/parser yếu ở đâu trước khi anh phải test tay; ảnh dataset **không** nhúng vào app, và giấy phép (CC BY 4.0 / Apache-2.0 / điều kiện thi ICDAR) chỉ nên dùng cho nghiên cứu/kiểm thử nội bộ.

---

## 5. NHỮNG GÌ **KHÔNG** CÔNG KHAI (ghi nhận là kết quả nghiên cứu, không đoán)

- Engine OCR + kiến trúc model của **Expensify, Dext, SparkReceipt, QuickBooks**: không hãng nào công bố. Mọi bài viết nói "họ dùng X" ngoài trang chính thức đều là phỏng đoán của bên thứ ba.
- Độ chính xác thật (đo độc lập, trên hoá đơn Mỹ chụp điện thoại, gồm nhàu/phai) của **từng** app: **không tồn tại** nghiên cứu công khai đáng tin ở quy mô lớn; các con số 98,6–99,9% đều là marketing hoặc test nhỏ tự làm.
- Veryfi công bố nhiều nhất nhưng vẫn dừng ở mức *tên stage + tên trường*; trọng số model, dữ liệu train chi tiết, và mức "on-device extraction" đầy đủ của Lens: **not public**.
- `RecognizeDocumentsRequest` trên hoá đơn nhiệt dài/cột tiền xa: **chưa có benchmark công khai nào** — đây là lý do verdict bắt nó qua bản test pipeline riêng + scorecard của chính mình thay vì tin bất kỳ ai.

---

## NGUỒN (đã tra 2026-11-08)

- veryfi.com/receipt-ocr-api · veryfi.com/lens/mobile-document-scanner · faq.veryfi.com (Data Extraction Fields Explained; Veryfi's Data Enrichment) · docs.veryfi.com (API reference: score/ocr_score/duplicates) · veryfi.com AP-automation article
- nutrient.io/blog/best-invoice-data-extraction-apis (so sánh grounding/confidence/duplicates giữa các API)
- github.com/javajack/reimbursement — research-ocr-itemization-ux.md (benchmark UX tổng hợp: Expensify Concierge/FAQ, Rossum validation UI, Azure ngưỡng 0.80, Veryfi/Klippa capture coaching)
- easycloudsolutions.com (2014, trích giải thích SmartScan của Expensify) · engine.com Expensify review · mastersccg.com (dẫn số 98,6%)
- readdle.com/blog/what-is-ocr · support.readdle.com (Text Recognition — on-device OCR model)
- geniusscansdk.com/features · geniusscansdk.com/docs/changelog (detection confidence 5 mức; LiteRT) · Play Store listing Genius Scan
- dext.com/uk/blog (pipeline + validation rules) · softwareadvice.ie · aitrendytools.com · getapp.com (số 320M tờ/năm, 99,9% theo hãng)
- sparkreceipt.com (features/OCR pages) · trombonegeek.com SparkReceipt review (OCR + ChatGPT)
- certumsolutions.com (QuickBooks capture/review, khung xanh) · henssler.com (test ~4 trường) · sayfocus.me (OCR không có API) · tapsayve.com
- shoeboxed.com/features · shoeboxed.com/security · dataconvertpro.com (test 50 tờ/app)
- thurrott.com (Microsoft Lens retirement, dẫn Microsoft Support) · microsoft.fandom.com (Lens modes)
- developers.google.com/ml-kit/vision/doc-scanner
- support.apple.com (Scan text and documents in Notes) · developer.apple.com — WWDC25 session 272 + sample "Recognizing tables within a document" (RecognizeDocumentsRequest, DocumentObservation, DataDetection)
- Dataset: ICDAR 2019 SROIE (Huang et al.) + kaggle.com/datasets/urbikn/sroie-datasetv2 · github.com/clovaai/cord + huggingface.co/datasets/naver-clova-ix/cord-v1 · WildReceipt (Sun et al. 2021) qua MMOCR benchmark inventory + IJDAR 2026 (s10032-026-00572-y) · dev.to/vanshajpoonia "A receipt is a checksum" (thí nghiệm Donut/Florence-2 trên CORD + WildReceipt) · FUNSD (Jaume et al. 2019, arXiv 1905.13538)

*Hết báo cáo đợt 2. Mọi điểm ghi [INFERENCE] là ý kiến chuyên gia, không phải dữ kiện; mọi con số % của hãng đều là công bố chưa kiểm chứng độc lập.*

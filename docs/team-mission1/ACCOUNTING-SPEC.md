# ĐẶC TẢ DỮ LIỆU KẾ TOÁN CHUẨN — SỔ HOÁ ĐƠN (ACCOUNTING-SPEC)

Người soạn: Chuyên gia Kế toán (đội Sổ Hóa Đơn) · Ngày: 2026-11-08
Bối cảnh: người dùng ở Oklahoma, Mỹ; hoá đơn được giữ để **đứng vững khi IRS kiểm tra** (tax inspection / audit).
Tài liệu này xây tiếp trên mục 4 của BLUEPRINT.md (đã có sẵn kết luận IRS) — không lặp lại, chỉ cụ thể hoá thành trường dữ liệu.

> **Ranh giới (nói 1 lần, rõ ràng):** Tài liệu này là đặc tả dữ liệu theo thông lệ ghi sổ và yêu cầu chứng từ của IRS. Đây **không phải tư vấn thuế** và chuyên gia này **không phải CPA của anh**. Quyết định khoản nào được khấu trừ, khấu hao ra sao, loại hình doanh nghiệp khai form nào — thuộc về CPA/người làm thuế của anh. App chỉ lo: **ghi đủ, ghi đúng, giữ nguyên, tra lại được.**

## 0. Nguyên tắc chiến lược — vì sao là "bộ trường chuẩn", không phải "khuôn từng tiệm"

Lệnh của anh (23:25 CST): nhà hàng/market nào cũng in khác nhau, học từng định dạng là không hết. Đúng — và phía kế toán cũng không cần từng định dạng. IRS không hỏi "hoá đơn này của tiệm nào, in theo mẫu gì"; IRS hỏi **4 câu giống nhau cho mọi khoản chi**:

1. **Bao nhiêu tiền?** (amount)
2. **Khi nào?** (date)
3. **Trả cho ai / mua ở đâu?** (payee / place)
4. **Mua cái gì, và để làm gì cho business?** (what was bought + business purpose)

Đây là chuẩn chứng minh chi phí (substantiation) theo **IRC §162** (chi phí "thông thường và cần thiết" — ordinary and necessary) + **Reg. §1.6001-1(a),(e)** (nghĩa vụ giữ sổ sách đủ để chứng minh), và với nhóm travel/meals/gifts còn chặt hơn theo **IRC §274(d)**: phải có chứng cứ về (1) số tiền, (2) ngày, (3) nơi, (4) mục đích business và quan hệ business của người liên quan.

→ **Kết luận cho cả đội:** engine đọc phải trích đúng **bộ trường chuẩn ở mục 1** từ *bất kỳ* bố cục nào. Mẫu riêng từng tiệm (Sam's, Home Depot…) chỉ là tăng tốc và bộ mẫu chấm điểm (corpus) — không phải khuôn bắt buộc. Một hoá đơn lạ hoắc vẫn phải ra được bộ trường chuẩn ở mức "đủ chứng minh", phần thiếu thì vào Hộp Chờ, không đoán.

Nền pháp lý cho bản scan (đã có ở BLUEPRINT, nhắc lại đúng 1 dòng để neo các trường bên dưới): **Rev. Proc. 97-22** chấp nhận lưu trữ điện tử thay bản giấy nếu bản điện tử *chính xác, rõ đọc được, đầy đủ, lấy lại được, in lại rõ được*, và hệ thống có kiểm soát hợp lý về tính toàn vẹn (không bị sửa âm thầm — có dấu vết khi sửa). Companion: **Rev. Proc. 98-25** cho hồ sơ xử lý bằng máy (machine-sensible records).

---

## 1. BỘ TRƯỜNG DỮ LIỆU CHUẨN (Canonical receipt data spec)

Quy ước cột "Bắt buộc":
- **BẮT BUỘC** = thiếu trường này thì bản ghi **không được rời Hộp Chờ Phân Loại** (chưa phải chứng từ hoàn chỉnh).
- **BẮT BUỘC NẾU CÓ IN** = hoá đơn có in mà app không lấy được thì gắn cờ; hoá đơn không in thì để trống hợp lệ.
- **NÊN CÓ** = thiếu không chặn, nhưng yếu bằng chứng.

Quy ước tiền: mọi số tiền lưu bằng **cent nguyên (Int)** — Build 1 đã làm đúng, giữ nguyên. `null` (không biết) và `0` (bằng không thật) là **hai nghĩa khác nhau**, tuyệt đối không gộp (xem mục 2 và 4).

### Nhóm A — Định danh tiệm & giao dịch (Vendor & transaction identity)

| # | Trường (VI — EN) | Vì sao cần (neo IRS) | Bắt buộc | Thiếu thì sao khi kiểm tra |
|---|---|---|---|---|
| A1 | **Tên tiệm** (vendorName) — nguyên văn như in | Yếu tố "payee/place" của §162/§274(d) | BẮT BUỘC | Không chứng minh được mua ở đâu → khoản chi dễ bị bác toàn bộ |
| A2 | **Địa chỉ / chi nhánh tiệm** (vendorAddress: đường, thành phố, bang, ZIP — như in) | Phân biệt các chi nhánh cùng chuỗi (Home Depot Tulsa ≠ Home Depot khác); củng cố yếu tố "place" | BẮT BUỘC NẾU CÓ IN | Bằng chứng "nơi mua" yếu đi; vẫn sống được nếu có A1 + ngày + tổng, nhưng là điểm IRS hay soi khi nghi ngờ |
| A3 | **Số điện thoại / mã cửa hàng / số quầy** (vendorPhone, storeNumber) | Đối chiếu chéo với sao kê và hồ sơ của tiệm khi bị yêu cầu xác minh | NÊN CÓ | Mất một lớp đối chiếu; không tự nó làm mất khấu trừ |
| A4 | **Ngày + giờ mua** (purchaseDateTime — như in trên hoá đơn) | Yếu tố "date" của §162/§274(d); quyết định **năm thuế** của khoản chi | BẮT BUỘC (ngày); giờ: NÊN CÓ | Không có ngày → không gán được năm thuế, khoản chi gần như vô giá trị làm chứng từ |
| A5 | **Mã giao dịch của tiệm** (transactionRef: TC# của Sam's, số đơn online, số hoá đơn/register#) | Khoá định danh giao dịch: vừa chống trùng, vừa là thứ tiệm/IRS dùng để truy lại giao dịch gốc | BẮT BUỘC NẾU CÓ IN | Mất khoá chống trùng mạnh nhất → phải chống trùng bằng ghép mờ (tiệm+ngày+tổng), rủi ro tính trùng hoặc xoá nhầm bản xịn |
| A6 | **Mã xác thực thanh toán** (authCode / approval #) | Lớp đối chiếu phụ với sao kê thẻ | NÊN CÓ | Không sao nếu đã có đuôi thẻ + tổng + ngày |

### Nhóm B — Từng món (Line items) — "mua cái gì"

Đây là nhóm phân biệt hoá đơn **đủ chứng minh** với sao kê thẻ **không đủ** (BLUEPRINT mục 4: sao kê chỉ nói đã trả bao nhiêu, không nói mua gì).

| # | Trường | Vì sao cần | Bắt buộc | Thiếu thì sao |
|---|---|---|---|---|
| B1 | **Tên món — nguyên văn như in** (itemName, giữ đúng chữ viết tắt của tiệm: "35PKDIETCOK") | Yếu tố "what was bought"; tên viết tắt là bình thường, giữ nguyên văn, cho phép anh đặt tên dễ hiểu *bên cạnh* (alias) chứ không ghi đè | BẮT BUỘC cho từng dòng app tách được | Dòng không tên = dòng tiền không giải thích được; nếu **toàn bộ** hoá đơn không có dòng nào, bản ghi tụt xuống ngang sao kê thẻ → yếu |
| B2 | **Mã hàng / SKU** (itemCode) | Đối chiếu với catalogue của tiệm; giúp học theo tiệm | NÊN CÓ | Không chặn |
| B3 | **Số lượng** (qty) | Cần cho kiểm tra qty × đơn giá = thành tiền; cần cho hàng tồn kho (COGS) | BẮT BUỘC cho từng dòng (mặc định 1 chỉ khi anh xác nhận) | Không kiểm chứng được thành tiền; kho hàng lệch |
| B4 | **Đơn giá** (unitPrice) | Kiểm chứng chéo dòng; phân bổ khi tách dòng | BẮT BUỘC NẾU CÓ IN | Vẫn tính được nếu có thành tiền + SL, nhưng mất 1 phép kiểm chéo |
| B5 | **Thành tiền của dòng** (lineAmount) — **dòng giảm giá là dòng ÂM riêng** (Instant Savings, coupon), không được trừ ngầm vào dòng khác | Cộng các dòng phải ra subtotal; và thuế ở nhiều nơi tính trên giá **trước** giảm (bằng chứng: Mẫu 001 — thuế nhóm T tính trên giá trước Instant Savings: $112.68 × 8.517% = $9.60 ✓, còn sau giảm $106.18 × 8.517% = $9.04 ✗). Trừ ngầm sẽ phá sự thật về căn cứ tính thuế | BẮT BUỘC cho từng dòng app tách được | Σ dòng ≠ subtotal mà không rõ vì sao → gắn cờ, ở lại Hộp Chờ tới khi anh đối chiếu giấy |
| B6 | **Cờ thuế của dòng như in** (taxFlag — vd Sam's "Y"/"T", Home Depot "<A>") | Bằng chứng phân bổ thuế giữa các nhóm thuế suất; giữ **nguyên văn**, app không tự diễn giải chữ cái thành "chịu thuế/không" (mỗi tiệm một nghĩa — Home Depot `<A>` là mã chính sách đổi trả, không phải cờ thuế; xem VENDOR-FORMATS) | NÊN CÓ (lưu raw) | Mất khả năng giải thích vì sao thuế được chia như vậy |
| B7 | **Phân loại + mục của TỪNG DÒNG** (lineClassification: personal/business; lineCategory) | Nền của tính năng **tách hoá đơn theo dòng** (split): 1 tờ Sam's trả thẻ Business nhưng nước ngọt là cá nhân (prototype đã chứng minh tách được trên Mẫu 001: Personal $101.02 + Business $115.78 = $216.80). Không có trường này ở cấp dòng thì tính năng tách không tồn tại | BẮT BUỘC CÓ KHẢ NĂNG (capability); áp dụng khi anh tách | Nếu chỉ phân loại cấp hoá đơn: tờ mua lẫn sẽ bị ép chọn 1 phe → hoặc khai thiếu, hoặc khai lẫn chi cá nhân vào business (rủi ro bị bác + phạt) |

### Nhóm C — Tổng & thuế (Totals & tax)

| # | Trường | Vì sao cần | Bắt buộc | Thiếu thì sao |
|---|---|---|---|---|
| C1 | **Subtotal** (tổng trước thuế, sau giảm giá) | Điểm neo của phép kiểm: Σ dòng = subtotal | BẮT BUỘC (in mà không đọc được → cờ; tự cộng từ dòng để *đối chiếu* chứ không thay số in) | Mất phép kiểm toàn vẹn chính của hoá đơn |
| C2 | **Tổng giảm giá** (discountTotal — suy ra từ các dòng âm) | Giải thích chênh giữa Σ dòng gốc và subtotal | NÊN CÓ (lưu dạng suy ra, ghi rõ là derived) | Khó giải thích số khi người làm thuế hỏi |
| C3 | **Danh sách dòng thuế** (taxLines[]: mỗi dòng gồm nhãn như in "TAX 1" / "TAX 2" / "SALES TAX", thuế suất nếu có in, số tiền thuế của dòng) | Hoá đơn thật thường có **nhiều dòng thuế với suất khác nhau** (Mẫu 001: TAX 1 8.517% = $9.60 cho hàng hoá + TAX 2 4.017% = $3.90 cho thực phẩm). Gộp thành 1 con số duy nhất là **làm mất dữ kiện in trên giấy** — khi cần giải trình cơ cấu thuế sẽ không còn đường quay lại ngoài ảnh gốc | BẮT BUỘC dưới dạng **danh sách** (1 phần tử cũng được) | Chỉ còn tổng thuế: vẫn khai được tổng chi, nhưng mất khả năng kiểm chứng cơ cấu thuế và phân bổ thuế theo nhóm hàng |
| C4 | **Tổng thuế** (taxTotal = Σ taxLines) | Cần cho đẳng thức subtotal + thuế = total; **phân biệt `0` (miễn thuế thật) với `null` (chưa đọc được)** | BẮT BUỘC (0 là giá trị hợp lệ) | Nếu null: không kiểm được đẳng thức tổng → ở lại Hộp Chờ |
| C5 | **Tiền tip — nhà hàng** (tipAmount, lưu **riêng**) | Hoá đơn nhà hàng in **tổng TRƯỚC tip**; tip viết tay sau đó mới là số tiền thật đã trả. Số được tính chi phí là *total in trên giấy + tip*. Gộp tip vào total sẽ phá đẳng thức kiểm chứng; bỏ tip thì khai thiếu | BẮT BUỘC VỚI NHÀ HÀNG (không có tip thì để trống hợp lệ, khác với "chưa hỏi") | Khai thiếu đúng bằng tiền tip; hoặc tệ hơn, app lưu total sai bản chất |
| C6 | **TỔNG TIỀN cuối** (total — số in lớn nhất trên hoá đơn; với nhà hàng: total + tip = số đã trả thực tế, cả hai phải xem được) | Yếu tố "amount" của §162/§274(d) — **trường quan trọng nhất của cả hoá đơn** | **BẮT BUỘC TUYỆT ĐỐI** | Không có total → bản ghi chưa phải chứng từ chi phí; chỉ anh nhập tay từ giấy (và phải đánh dấu "người dùng nhập") mới cứu được |
| C7 | **Tiền thối / tiền đưa** (tendered, changeDue) | Không phải chi phí | KHÔNG LƯU (cố ý) | — |

### Nhóm D — Thanh toán (Payment)

| # | Trường | Vì sao cần | Bắt buộc | Thiếu thì sao |
|---|---|---|---|---|
| D1 | **Hình thức thanh toán** (paymentMethod: card / cash / check / other / unknown) | Phân biệt "trả tiền mặt" với "không đọc được thẻ" — hai tình trạng hoàn toàn khác nhau về bằng chứng. Tiền mặt không có sao kê đỡ lưng → ảnh gốc + ghi chú càng quan trọng | BẮT BUỘC (giá trị "unknown" hợp lệ nhưng gắn cờ) | Không rõ đường tiền → khó đối chiếu sao kê; hoá đơn tiền mặt bị nghi là của người khác cũng không có gì gỡ |
| D2 | **Hãng thẻ + 4 số cuối** (cardBrand, cardLast4 — **chỉ từ dòng bị che `****2586`**) | Đối chiếu sao kê + là tín hiệu gợi ý Cá nhân/Business theo sổ đăng ký thẻ của anh. **Chỉ 4 số cuối — không bao giờ lưu số thẻ đầy đủ** (bảo mật + PCI: app không có lý do gì giữ PAN) | BẮT BUỘC NẾU TRẢ THẺ | Mất gợi ý phân loại tự động và mất lớp đối chiếu sao kê |
| D3 | **Ảnh chụp sao kê / đối chiếu ngân hàng** | Ngoài phạm vi app (BLUEPRINT đã chốt: sao kê một mình không đủ, và app không làm nhiệm vụ ngân hàng) | KHÔNG LƯU | — |

### Nhóm E — Phân loại & ánh xạ thuế (Classification & tax mapping) — bằng chứng "tách Cá nhân / Business"

| # | Trường | Vì sao cần | Bắt buộc | Thiếu thì sao |
|---|---|---|---|---|
| E1 | **Phân loại của hoá đơn** (classification: personal / business — **snapshot tại thời điểm xếp**) | Đây là ranh giới tiền của anh vs tiền business. Snapshot = sửa thẻ sau này không viết lại lịch sử (BLUEPRINT đã chốt; Build 1 đã làm — xem mục 5) | BẮT BUỘC để hoàn chỉnh (chưa quyết = "chưa rõ" = ở Hộp Chờ) | Hoá đơn lơ lửng không vào được tổng năm nào → Tax Pack thiếu hoặc lẫn |
| E2 | **Lý do + nguồn quyết định phân loại** (classificationReason; decidedBy: theo-thẻ / anh-chọn-tay / tách-dòng; decidedAt) | Khi IRS (hoặc chính anh, 2 năm sau) hỏi "sao tờ này là business?" — phải trả lời được bằng dữ kiện, không bằng trí nhớ | BẮT BUỘC | Phân loại thành khẳng định không căn cứ; tờ bị hỏi tới là đuối lý |
| E3 | **Mục chi + dòng Schedule C** (category + **mã dòng thuế**, vd "Supplies — Sch C line 22") | Lưu **cả mã dòng** chứ không chỉ nhãn chữ: đổi tên nhãn sau này không được làm vỡ ánh xạ khi xuất hồ sơ (xem mục 3) | BẮT BUỘC VỚI BUSINESS | Người làm thuế phải xếp lại từng tờ bằng tay — app mất nửa giá trị |
| E4 | **Ghi chú mục đích business** (businessPurpose — "mua để làm gì") | Nửa sau của yếu tố §162/§274(d) mà **hoá đơn không bao giờ tự nói được**: hoá đơn Home Depot chứng minh mua keo + máy rửa sàn, không chứng minh mua *cho việc gì*. Sao kê cũng không. Chỉ anh biết — app phải có ô và phải nhắc | **BẮT BUỘC VỚI BUSINESS để hoàn chỉnh** | Đây là thiếu sót kinh điển khiến chi phí business bị bác dù hoá đơn đẹp: có giấy, không có mục đích |
| E5 | **Thông tin bổ sung cho Ăn Uống/Đi Lại** (mealsAttendees: ăn với ai, quan hệ business gì) | §274(d) đòi riêng cho travel/meals: mục đích + **quan hệ business của người cùng ăn**. (Ngưỡng $75 của Reg. §1.274-5(c)(1) chỉ miễn *chứng từ giấy* cho khoản nhỏ, không miễn việc ghi lại các yếu tố này) | BẮT BUỘC NẾU MỤC LÀ MEALS/TRAVEL (app phải hỏi) | Khoản ăn uống business là nhóm bị soi §274(d) đầu tiên; thiếu người ăn cùng + mục đích = rất dễ mất |
| E6 | **Năm thuế** (taxYear — suy ra từ ngày mua, anh sửa được) | Tax Pack gom theo năm; hoá đơn cuối tháng 12 / đầu tháng 1 hay bị gán nhầm năm | BẮT BUỘC (dạng derived, sửa được) | Gom sai năm → tổng năm sai cả cục |
| E7 | **Cờ tài sản / khấu hao cho Thiết Bị** (capitalizationFlag: mua đứt theo de minimis / tài sản khấu hao / chưa rõ) | Món "Equipment" **không phải chi phí thường kỳ mặc định**: nguyên tắc vốn hoá §263(a); chỉ được trừ ngay khi thuộc diện an toàn tối thiểu (de minimis safe harbor, Reg. §1.263(a)-1(f) — thường ≤ $2,500/món với người nộp thuế không có báo cáo tài chính kiểm toán), còn lại vào khấu hao (Form 4562, dòng 13 Schedule C) hoặc §179. *(Ngưỡng và điều kiện áp dụng thực tế cho trường hợp của anh: CPA xác nhận — ghi unverified ở mức áp dụng cá nhân.)* | BẮT BUỘC HỎI KHI MỤC LÀ EQUIPMENT | Khai thiết bị lớn thành chi phí năm → sai bản chất, bị điều chỉnh + phạt khi kiểm tra |

### Nhóm F — Bằng chứng & toàn vẹn (Evidence & integrity — phần của Rev. Proc. 97-22)

| # | Trường | Vì sao cần | Bắt buộc | Thiếu thì sao |
|---|---|---|---|---|
| F1 | **Ảnh gốc — KHÔNG sửa, đủ mọi trang** (originalImages[] — danh sách, không phải 1 ảnh) | Đây mới là chứng từ; dữ liệu OCR chỉ là bản trích. 97-22 đòi bản điện tử **đầy đủ** — hoá đơn dài 2 trang mà chỉ giữ trang 1 là bản sao thiếu | **BẮT BUỘC TUYỆT ĐỐI** (không ảnh gốc → bản ghi chỉ là ghi chú cá nhân, không phải bằng chứng) | Mất ảnh gốc = mất chứng từ, dữ liệu đọc được không cứu nổi |
| F2 | **Ảnh tăng nét / đã nắn thẳng** (enhancedImage — bản phái sinh, lưu riêng, gắn nhãn derivative) | Chỉ để đọc tốt hơn và để xem; **không bao giờ thay ảnh gốc** | NÊN CÓ (nếu tạo) | — |
| F3 | **Nguồn nạp** (sourceType: chụp camera / chọn ảnh / import PDF / ảnh chụp màn hình + tên file gốc nếu có) | Truy vết (provenance): chống trùng xuyên kênh (chụp giấy + PDF cùng 1 lần mua) và giải thích chất lượng đọc | BẮT BUỘC | Chống trùng mất 1 chân; không giải thích được vì sao 2 bản ghi giống nhau |
| F4 | **Toàn văn OCR + độ tin cậy từng trường + phiên bản bộ đọc** (ocrRawText, fieldConfidences, parserVersion) | Tái hiện được "app đã thấy gì"; khi bộ đọc nâng cấp, đọc lại được từ văn bản/ảnh đã lưu mà không cần hoá đơn giấy nữa; là cơ sở cho tìm kiếm full-text | BẮT BUỘC (raw text + version); độ tin cậy: NÊN CÓ cho cả cấp dòng món | Không truy vết được lỗi đọc; nâng cấp bộ đọc không kiểm chứng lại được trên dữ liệu cũ |
| F5 | **Dấu vết sửa đổi** (auditTrail: createdAt; reviewedAt; mỗi lần sửa: trường nào, giá trị cũ → mới, khi nào, nguồn sửa là OCR hay anh gõ tay) | 97-22 yêu cầu hệ thống lưu trữ điện tử có kiểm soát toàn vẹn — sửa phải **có dấu vết**, không sửa chìm. Đồng thời phân biệt "số máy đọc" với "số anh nhập tay" — hai loại số này giá trị chứng minh khác nhau | BẮT BUỘC CÓ KHẢ NĂNG (V1 có thể tối giản: reviewedAt + cờ userEntered theo trường; bản đầy đủ sang v1.1) | Bản ghi bị sửa mà không ai biết sửa gì/khi nào → toàn vẹn của cả kho bị đặt dấu hỏi |
| F6 | **Liên kết bản trùng** (duplicateOf + excludedFromTotals + lý do loại) | Xem mục 4: trùng được **đánh dấu và loại khỏi tổng**, không xoá | BẮT BUỘC CÓ KHẢ NĂNG | Hoặc tính trùng 2 lần, hoặc xoá mất dấu vết |
| F7 | **Hạn giữ** (retentionUntil = năm thuế + 7 năm theo chính sách giữ 7 năm của BLUEPRINT: chuẩn luật là 3 năm từ ngày nộp theo §6501(a), 6 năm nếu khai thiếu thu nhập đáng kể theo §6501(e), 7 năm cho nợ xấu/chứng khoán mất giá theo §6511(d)(1) — giữ 7 năm bao hết các mốc này) + cờ **không bao giờ tự xoá** | Giữ đủ lâu cho mọi cửa sổ kiểm tra; xoá là hành động của anh, có chủ đích | BẮT BUỘC (ở mức chính sách app; trường dữ liệu NÊN CÓ) | Xoá sớm = tự huỷ bằng chứng trong thời hạn IRS còn quyền hỏi |

---

## 2. LUẬT KIỂM CHỨNG KẾ TOÁN (Validation rules)

### 2.1 Các phép đối chiếu số học (chạy trên mọi hoá đơn, kết quả chỉ **gắn cờ** — không bao giờ tự sửa số)

| # | Phép kiểm | Ngưỡng | Khi lệch |
|---|---|---|---|
| V1 | Σ lineAmount (kể cả dòng âm) **=** subtotal | Lệch ≤ 2 cent: chấp nhận (làm tròn in ấn). Lệch > 2 cent: **cờ đỏ** | Ở lại Hộp Chờ; nghi đọc sót/sai dòng. (Mẫu 002 trượt đúng phép này vì cột tiền bị xé dòng — cờ đã cứu, không cho số sai đi qua) |
| V2 | subtotal **+** Σ taxLines **=** total (nhà hàng: **+ tip =** số đã trả) | Lệch ≤ 2 cent chấp nhận; hơn → **cờ đỏ** | Ở lại Hộp Chờ |
| V3 | qty **×** unitPrice **=** lineAmount (từng dòng, khi có đủ 3 số) | Lệch ≤ 1 cent/dòng (làm tròn đơn giá) | Cờ vàng ở dòng đó — nghi đọc sai 1 trong 3 số |
| V4 | Σ qty **=** số món in trên hoá đơn ("# ITEMS SOLD") khi có in | Phải bằng đúng | Cờ vàng: đọc sót món hoặc sót dòng số lượng |
| V5 | Σ taxLines **=** taxTotal (khi hoá đơn in cả hai) | ≤ 1 cent | Cờ vàng |
| V6 | **CẤM kiểm thuế kiểu "thuế suất × subtotal"**: thuế thường tính trên căn cứ riêng (trước giảm giá, theo nhóm hàng — bằng chứng Mẫu 001). Chỉ kiểm V2/V5, không kiểm ngược thuế từ suất | — | App nào "kiểm" kiểu này sẽ báo sai hoá đơn đúng — lỗi logic, không phải lỗi đọc |
| V7 | Ngày hợp lệ: không ở tương lai, không trước quá 7 năm giữ liệu, năm khớp taxYear gán | — | Cờ vàng (hay gặp: OCR đọc 2025 thành 2026 — Mẫu 001 là 2026 thật, phải đối chiếu ảnh) |
| V8 | total > 0; total ≥ taxTotal; subtotal ≥ 0 (trừ hoá đơn **trả hàng/refund** — phải có cờ isReturn riêng, tổng âm là hợp lệ khi đó) | — | Cờ đỏ nếu total ≤ 0 mà không phải hoá đơn trả hàng |
| V9 | Chống trùng 2 lớp: (a) **khoá cứng** — dedupeKey (A5) trùng = cùng giao dịch; (b) **ghép mờ** — cùng tiệm + cùng ngày + cùng total = nghi trùng | — | Cảnh báo đối chiếu 2 ảnh cạnh nhau cho anh quyết; xử lý theo mục 4 (đánh dấu, không xoá) |
| V10 | Thanh toán: cardLast4 chỉ chấp nhận khi lấy từ dòng có ký tự che (`****`/`XXXX`). 4 số ở chân hoá đơn, mã đơn, số điện thoại… **không phải** đuôi thẻ (bẫy đã biết: footer Home Depot) | — | Đuôi thẻ "tự chế" làm hỏng gợi ý phân loại — thà để unknown vào Hộp Chờ |

### 2.2 Định nghĩa "HOÀN CHỈNH" (complete) — điều kiện rời Hộp Chờ

Một bản ghi chỉ được chuyển trạng thái **đã duyệt (reviewed)** và được tính vào tổng/Tax Pack khi **đủ tất cả**:

1. Có **ảnh gốc** (F1) — rõ, đủ trang.
2. Có **tên tiệm** (A1), **ngày** (A4), **tổng tiền** (C6) — 3 trường xương sống.
3. Đẳng thức V1 + V2 đạt, **hoặc** anh đã nhìn ảnh gốc và **xác nhận bất chấp chênh lệch** — khi đó bản ghi mang dấu "đã xác nhận kèm cờ" (confirmed-with-flag) và cờ **vẫn hiển thị** trong chi tiết + khi xuất hồ sơ, không bị nuốt mất.
4. **Phân loại đã quyết** (E1) kèm lý do (E2). "Chưa rõ" = chưa hoàn chỉnh.
5. Nếu **Business**: có **mục + dòng Schedule C** (E3) và **ghi chú mục đích** (E4); nếu mục là Meals/Travel: thêm E5; nếu Equipment: thêm E7.
6. Nếu trả thẻ: đuôi thẻ khớp 1 thẻ trong sổ đăng ký, **hoặc** anh đã xác nhận "thẻ lạ" có chủ đích. Nếu tiền mặt: D1 = cash rõ ràng.

Thiếu bất kỳ điều nào → **needsReview**, và Tax Pack phải **cảnh báo** nếu xuất trong lúc còn bản ghi chưa hoàn chỉnh trong kỳ (xuất được, nhưng kèm danh sách thiếu — quyết định của anh, có ghi lại).

### 2.3 Cờ đỏ (red flags) — luôn nổi lên đầu Hộp Chờ

- Thiếu total, hoặc total do OCR có độ tin cậy thấp (< 60% theo thang BLUEPRINT).
- V1/V2 lệch > 2 cent (số không tự khớp — dấu hiệu đọc sai có hệ thống).
- Trùng khoá cứng (V9a) — nguy cơ tính 2 lần.
- Đuôi thẻ **không có trong sổ đăng ký** — có thể là thẻ mới (anh cần thêm) hoặc đọc sai.
- Business mà **trống mục đích** (E4) — thiếu sót bị bác nhiều nhất.
- Ngày bị OCR đọc sang năm khác (V7) — lệch năm thuế là lệch cả hồ sơ.
- Ảnh gốc mờ/cắt mất phần tổng tiền — ảnh không đạt chuẩn 97-22 (không rõ/không đầy đủ) thì dữ liệu chuẩn cũng vô ích.

---

## 3. DANH MỤC ÁNH XẠ THUẾ (Category taxonomy)

### 3.1 ⚠️ CÂU HỎI PHẢI HỎI ANH TRƯỚC KHI CHỐT DANH MỤC (chưa có đáp án — không tự giả định)

> **Loại hình business của anh là gì: sole proprietor (cá nhân kinh doanh) / LLC 1 thành viên / LLC nhiều thành viên / S-corp / khác?**
> (BLUEPRINT mục 10 câu 4 — đến nay **chưa được trả lời**.)
>
> Bảng dưới đây lập theo **Schedule C (Form 1040)** — đúng nếu anh là sole proprietor hoặc LLC 1 thành viên khai như disregarded entity (trường hợp phổ biến nhất với business nhỏ). Nếu là S-corp → Form 1120-S, partnership → Form 1065: **cấu trúc mục khác hẳn**, phải làm lại bảng. Đây là điểm **unverified** lớn nhất của đặc tả này.
>
> Câu hỏi phụ (ảnh hưởng COGS — mục 3.2 dòng đầu): **anh mua hàng ở Sam's để BÁN LẠI (tồn kho) hay để DÙNG cho business?** Mẫu 001 toàn nước ngọt số lượng lớn — nếu bán lại thì là COGS/Part III, nếu dùng thì là Supplies. Mục đích ghi ở E4 sẽ quyết từng tờ, nhưng mặc định gợi ý theo tiệm cần biết đường nào là chính.

### 3.2 Business — ánh xạ Schedule C (Form 1040), Part II trừ khi ghi khác

| Mục trong app (VI — EN) | Dòng Schedule C | Ghi chú kế toán |
|---|---|---|
| Hàng Hoá / Giá Vốn (Inventory / COGS) | **Part III → Line 4** (không nằm ở Part II) | Hàng mua để bán lại **không** trừ như chi phí thường: đi qua tồn kho (đầu kỳ + mua − cuối kỳ). Gợi ý mục này phải đi kèm câu hỏi tồn kho cuối năm |
| Quảng Cáo (Advertising) | Line 8 | Biển bảng, in ấn, quảng cáo online |
| Xe & Xăng (Vehicle / Fuel) | Line 9 (Car and truck) | Hai đường: **standard mileage rate** (cần **sổ km** — app hiện không ghi km; nếu anh đi đường này, app chỉ lưu hoá đơn xăng làm phụ chứng) hoặc **actual expenses** (cần tỉ lệ % dùng cho business). Chọn đường nào là việc của CPA — app lưu hoá đơn, gắn cờ "vehicle" để CPA xử |
| Hoa Hồng / Phí Dịch Vụ Ngoài (Commissions & Fees) | Line 10 | |
| Nhân Công Thuê Ngoài (Contract Labor) | Line 11 | Trả 1 người ≥ $600/năm → liên quan Form 1099-NEC (app chỉ cần gắn cờ nhắc, không phát hành form) |
| Bảo Hiểm Business (Insurance) | Line 15 | Không gồm bảo hiểm y tế cá nhân |
| Tư Vấn / Luật / Kế Toán (Legal & Professional) | Line 17 | Phí CPA nằm ở đây |
| Văn Phòng (Office Expenses) | Line 18 | Văn phòng phẩm, đồ dùng văn phòng nhỏ |
| Thuê Mặt Bằng / Thiết Bị (Rent or Lease) | Line 20b (20a cho xe/máy móc thuê) | |
| Sửa Chữa & Bảo Trì (Repairs & Maintenance) | Line 21 | Sửa để *duy trì* ≠ nâng cấp vốn hoá (ranh giới §263 — CPA chốt khi món lớn) |
| **Vật Tư (Supplies)** | **Line 22** | Mục mặc định cho đồ tiêu hao dùng trong business (không phải tồn kho bán lại, không phải văn phòng phẩm) |
| Thuế & Giấy Phép (Taxes & Licenses) | Line 23 | Phí license business, **không** gồm thuế thu nhập |
| Đi Lại (Travel) | Line 24a | Vé, khách sạn, xe — §274(d): cần E4 + ngày đi/về rõ; khách sạn luôn cần hoá đơn dù nhỏ |
| Ăn Uống Business (Meals) | Line 24b (Deductible meals) | **Chỉ được trừ 50%** (§274(n)); giải trí (entertainment) **không** được trừ từ sau TCJA; bắt buộc E5 (ăn với ai, quan hệ gì, mục đích gì) |
| Điện Nước / Internet / Điện Thoại (Utilities) | Line 25 | Dùng lẫn nhà ở → cần tỉ lệ phân bổ (CPA chốt tỉ lệ; app ghi tổng, không tự chia) |
| Phần Mềm / Đăng Ký Dịch Vụ (Software / Subscriptions) | Thường Line 18 hoặc Line 27a | *(Thực hành phổ biến, unverified cho trường hợp cụ thể — CPA xác nhận khi khai thật)* |
| Thiết Bị (Equipment) | **Không có dòng trừ thẳng** — Line 13 (Depreciation, qua Form 4562) hoặc trừ ngay nếu đủ de minimis/§179 (xem E7) | Mục này trong app **bắt buộc kèm cờ E7**; mặc định xếp "chưa rõ cách xử" cho CPA quyết |
| Khác (Other Expenses) | Line 27a (liệt kê ở Line 48) | Bãi đáp cuối — Tax Pack phải liệt kê rõ từng khoản trong nhóm này, không để "Khác" trống nghĩa |

### 3.3 Cá nhân (Personal) — chỉ để tổ chức, **không** phải vị thế thuế

Đi Chợ (Groceries) · Nhà Cửa (Home) · Y Tế (Medical) · Xe Cá Nhân · Ăn Uống Cá Nhân · Giải Trí · Khác.
Ghi rõ trong app (chữ nhỏ): nhóm cá nhân phục vụ quản lý chi tiêu; một vài nhóm (y tế, thuế nhà…) *có thể* liên quan Schedule A nếu anh itemize — app **không tự khẳng định**, CPA quyết. Đừng để giao diện ám chỉ "cá nhân = không liên quan thuế tuyệt đối".

---

## 4. NHỮNG VIỆC APP TUYỆT ĐỐI KHÔNG ĐƯỢC LÀM (góc nhìn kế toán)

1. **Không tự sửa số cho "khớp".** Thấy Σ dòng ≠ subtotal thì gắn cờ — không được lặng lẽ đổi subtotal/tổng/dòng nào để đẳng thức đẹp. Số trên giấy là sự thật duy nhất; app sửa chìm = bịa chứng từ.
2. **Không ghi đè ảnh gốc.** Ảnh tăng nét/nắn thẳng là bản phái sinh lưu riêng (F2). Xoá hoặc thay ảnh gốc = huỷ chứng từ theo chuẩn 97-22.
3. **Không xoá bản trùng lặng lẽ.** Phát hiện trùng → đánh dấu `duplicateOf` + loại khỏi tổng + ghi lý do (F6). Hai bản vẫn còn đó để đối chiếu. Xoá hẳn chỉ khi anh ra lệnh riêng, và lệnh đó cũng phải có dấu vết.
4. **Không tự xoá theo tuổi.** Không cron, không "dọn dẹp tự động". Hết hạn giữ 7 năm (F7) app chỉ được *báo danh sách đến hạn* — xoá hay giữ tiếp là quyết định của anh.
5. **Không viết lại lịch sử phân loại.** Đổi loại thẻ trong sổ đăng ký không được tự xếp lại hoá đơn cũ; chỉ khi anh chọn rõ "xếp lại cả hoá đơn cũ" và việc xếp lại đó phải vào audit trail (F5). (Build 1 đã giữ luật này — xem mục 5.)
6. **Không gộp các dòng thuế thành 1 số rồi vứt chi tiết** (xem C3), **không trừ ngầm giảm giá vào dòng hàng** (xem B5), **không gộp tip vào total** (xem C5). Mọi phép gộp phá huỷ khả năng kiểm chứng đều bị cấm.
7. **Không lưu số thẻ đầy đủ, không suy đuôi thẻ từ số không bị che** (xem D2, V10).
8. **Không để AI/gợi ý tự động đụng vào số tiền, ngày, tổng.** Gợi ý chỉ được chạm: tên mục, phân loại, tên món dễ hiểu (alias). Số liệu tài chính chỉ đến từ giấy + tay anh.
9. **Không xuất hồ sơ "sạch" giả tạo.** Tax Pack xuất khi còn bản ghi chưa hoàn chỉnh phải kèm cảnh báo + danh sách thiếu (mục 2.2). Xuất ZIP/PDF/CSV mà giấu phần chưa duyệt = làm sai lệch hồ sơ anh đưa cho CPA/IRS.
10. **Không coi độ tin cậy OCR là bằng chứng.** Confidence 95% vẫn là "máy đoán"; trạng thái "đã duyệt" chỉ đến từ anh xác nhận hoặc phép kiểm chéo đạt + luật hoàn chỉnh ở mục 2.2.

---

## 5. CHẤM BẢN MODEL BUILD 1 (Models.swift) THEO ĐẶC TẢ NÀY

Thang mức độ: **CAO** = mất dữ kiện chứng minh hoặc chặn tính năng đã hứa · **TRUNG** = yếu bằng chứng / sai ánh xạ / thiếu truy vết · **THẤP** = thiếu tiện ích đối chiếu, chưa nguy hiểm.

### 5.1 Điểm Build 1 đã ĐÚNG chuẩn (giữ nguyên, đừng ai "sửa" mất)

- Tiền lưu **cent nguyên (Int)** — chính xác tới cent, không lỗi số thực. ✓
- **Snapshot phân loại theo từng hoá đơn** (`classificationRaw` + `classificationReason`) và luật "đổi thẻ không viết lại lịch sử, chỉ xếp lại khi anh chọn" — đúng E1/E2 và điều cấm số 5. ✓
- Thẻ **ngưng (archive) chứ không xoá** (`CardTail.archived`) — hoá đơn cũ còn tra được. ✓
- Giữ **ảnh gốc** (`imageFileName`) + **toàn văn OCR** (`ocrRawText`) + **độ tin cậy** + **dedupeKey** + trạng thái mặc định **needsReview**. ✓
- `taxFlag` lưu nguyên văn chữ cái, comment trong code ghi rõ "không tự suy thuế" — đúng B6. ✓

### 5.2 Thiếu / lệch — theo mức độ

| Mức | Vấn đề (đối chiếu đặc tả) | Hệ quả cụ thể |
|---|---|---|
| **CAO** | **Thuế bị gộp 1 số**: `Receipt.taxCents: Int?` duy nhất, trong khi C3 đòi `taxLines[]`. Mẫu 001 có TAX 1 $9.60 (8.517%) + TAX 2 $3.90 (4.017%) — model hiện tại **không có chỗ chứa** cơ cấu này | Mất dữ kiện in trên giấy ngay từ tầng lưu; muốn xem lại phải mở ảnh đọc tay. Vi phạm điều cấm số 6 |
| **CAO** | **Không có phân loại/mục ở cấp dòng**: `LineItem` không có classification/category (B7) | Tính năng tách hoá đơn theo dòng — đã hứa và prototype đã chứng minh trên Mẫu 001 — **không thể triển khai** trên model này. Tờ mua lẫn chỉ còn nước ép 1 phe |
| **CAO** | **Không có trường tip** (C5) và không có khái niệm "số đã trả = total + tip" | Mọi hoá đơn nhà hàng sẽ lưu **thiếu đúng bằng tiền tip** — sai số có hệ thống ở đúng nhóm chi bị §274(d) soi nhất |
| **CAO** | **Chỉ 1 ảnh gốc**: `imageFileName: String` đơn (F1 đòi danh sách) | Hoá đơn dài/chụp 2 mặt/chụp bổ sung phần dưới (luồng BLUEPRINT đã hứa) không có chỗ lưu → bản sao **thiếu trang** = không đạt "đầy đủ" của 97-22 |
| **CAO** | **`taxCents = nil` nhập nhằng 2 nghĩa**: chưa đọc được **hay** miễn thuế (C4 đòi phân biệt 0 vs null và có taxLines đỡ lưng) | Hoá đơn miễn thuế thật sẽ bị đối xử như hoá đơn lỗi đọc, kẹt Hộp Chờ oan; ngược lại hoá đơn mất thuế có thể bị hiểu là miễn thuế |
| **TRUNG** | **Không có địa chỉ tiệm** (A2): `vendor` là 1 chuỗi tên duy nhất | Yếu tố "place" mỏng; thêm bằng chứng thực địa: Mẫu 003 tên tiệm bị đọc thành "How doers" (slogan) — khi chỉ có 1 trường tên, đọc sai là mất trắng định danh |
| **TRUNG** | **Không có paymentMethod** (D1): tiền mặt và "không đọc được thẻ" đều biểu diễn bằng `cardLast4 = nil` | Hai tình trạng bằng chứng khác nhau bị gộp một; luật hoàn chỉnh 2.2 mục 6 không kiểm được |
| **TRUNG** | **Category là chuỗi tự do, không lưu mã dòng Schedule C** (E3): danh sách `Categories` có nhãn gần đúng nhưng không mang line number | Đổi nhãn/typo là vỡ ánh xạ xuất hồ sơ; Tax Pack phải đoán lại mục → dòng. Cần lưu mã dòng kèm nhãn snapshot |
| **TRUNG** | **Không có dấu vết duyệt/sửa** (F5): chỉ có `statusRaw` + `createdAt`; không `reviewedAt`, không ghi trường nào do anh nhập tay | Không phân biệt được số-máy-đọc vs số-anh-nhập; sửa đổi không dấu vết — điểm trừ trực tiếp theo tinh thần 97-22 |
| **TRUNG** | **Mục "Thiết Bị (Equipment)" là mục chi thường, không có cờ vốn hoá** (E7) | Người dùng dễ trừ thẳng thiết bị lớn vào chi phí năm — sai bản chất §263(a)/khấu hao; app phải hỏi E7 khi chọn mục này |
| **TRUNG** | **Không có sourceType** (F3) | Chống trùng xuyên kênh chụp/PDF (chuẩn nghiệm thu số 3 của BLUEPRINT) thiếu dữ kiện; không giải thích được provenance |
| **TRUNG** | **Không có liên kết trùng** duplicateOf / excludedFromTotals (F6) | Khi V9 bắt được trùng, model không có cách xử lý đúng luật: chỉ còn xoá (cấm) hoặc để tính 2 lần |
| **THẤP** | **Không lưu mã giao dịch riêng** (A5/A6): TC# bị nhét chung vào `dedupeKey`, auth code/ref# không có trường (chỉ còn trong ocrRawText) | Vẫn truy được qua raw text nhưng không truy vấn/hiển thị có cấu trúc được |
| **THẤP** | **Độ tin cậy chỉ có ở 3 trường cấp hoá đơn** (vendor/date/total); dòng món không có confidence riêng (F4) | Tô vàng "dòng nào đáng ngờ" kém chính xác; chưa nguy hiểm vì đã có kiểm chéo V1–V4 đỡ |
| **THẤP** | **Chưa có retentionUntil** (F7) — hiện mới là chính sách chữ trong BLUEPRINT | Chấp nhận được ở V1 nếu app tuyệt đối không tự xoá (hiện đúng vậy); nên thêm trường khi làm Tax Pack |

### 5.3 "Giữ quá tay" (over-kept)?

Gần như **không có**. `ocrRawText` tưởng thừa nhưng là bằng chứng truy vết + nguồn tìm kiếm + nguyên liệu đọc lại khi nâng cấp bộ đọc — giữ là đúng. `cardBrand` giữ đúng mức (chỉ hãng + 4 số cuối). Kết luận của chuyên gia kế toán: **model Build 1 thiếu trường, không thừa trường** — mọi thiếu hụt đều nằm ở phía "mất dữ kiện chứng minh", đúng hướng phải sửa ở Build 2 theo thứ tự: **taxLines → tip → phân loại cấp dòng → nhiều ảnh gốc → paymentMethod + địa chỉ tiệm → mã dòng Schedule C + dấu vết duyệt**.

---

*Hết đặc tả. Các điểm ghi "unverified" (áp dụng de minimis cho trường hợp cụ thể của anh; dòng cho Software; toàn bộ bảng Schedule C nếu loại hình business không phải sole proprietor/LLC 1 thành viên) phải được xác nhận với CPA của anh trước khi khoá cứng vào code.*

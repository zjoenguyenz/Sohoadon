import Foundation

// MARK: - Kết quả đọc 1 dòng OCR

struct OCRLine {
    var text: String
    /// Độ tin cậy 0.0–1.0 của dòng này (từ Vision).
    var confidence: Double
}

// MARK: - Kết quả bóc tách 1 hoá đơn (bản nháp, chưa lưu)

struct ParsedLineItem {
    var name: String
    var qty: Int = 1
    var unitPriceCents: Int? = nil
    var amountCents: Int? = nil
    var taxFlag: String? = nil
    var itemCode: String? = nil
    // INTEGRATE-V2 (thuần cộng thêm, mặc định nil): metadata dòng cân
    // "W lb @ $U/lb" gắn kèm món bởi nhánh cùng-dòng — CHỈ là thông
    // tin phụ (kiểm chứng số học W x U ≈ tiền món khi gắn), không
    // tham gia cổng sổ của validate() và không phải trường model.
    var weightLb: Double? = nil
    var weightUnitCents: Int? = nil
}

struct ParsedTaxLine {
    var label: String
    var rateText: String? = nil
    var amountCents: Int
}

struct ParseResult {
    var vendor: String? = nil
    var vendorKey: String = "generic"   // "sams" khi nhận diện Sam's Club
    var date: Date? = nil
    var items: [ParsedLineItem] = []
    var subtotalCents: Int? = nil
    var taxes: [ParsedTaxLine] = []
    var totalCents: Int? = nil
    var cardLast4: String? = nil
    var cardBrand: String? = nil
    var dedupeKey: String? = nil
    var itemsSold: Int? = nil
    var warnings: [String] = []
    var vendorConfidence: Double = 0
    var dateConfidence: Double = 0
    var totalConfidence: Double = 0
    // WP5 (thuần cộng thêm): hạ cánh các trường model WP2 ĐÃ CÓ sẵn +
    // nguồn/gợi ý của hàm nhận diện tiệm. ParseResult là struct nháp,
    // không phải SwiftData model — không có rủi ro di trú.
    var vendorAddress: String? = nil
    var vendorPhone: String? = nil
    var storeNumber: String? = nil
    var vendorSource: String? = nil   // "tier1-exact" | "tier1-fuzzy" | "tier2-anchor"
    var vendorSuggestion: String? = nil   // nấc 3: CHỈ gợi ý, không bao giờ tự điền
    var vendorAnchorDisputed: Bool = false
    var rawText: String = ""

    var taxTotalCents: Int { taxes.reduce(0) { $0 + $1.amountCents } }
}

// MARK: - Bộ bóc tách hoá đơn
//
// Luật toàn cục (VENDOR-FORMATS.md — không được phá):
// 1. Luôn đối chiếu chéo: Σ món ≈ subtotal; subtotal + thuế ≈ total.
//    Không khớp -> gắn cờ vào Hộp Chờ, TUYỆT ĐỐI không tự sửa số.
// 2. Đuôi thẻ CHỈ lấy từ dòng thanh toán có ký tự che (****2586...).
//    Mã ở chân hoá đơn kết thúc bằng 4 số KHÔNG phải đuôi thẻ (bẫy Home Depot).
// 3. Vùng loại trừ (Suggested Tip, Return Policy, MAX REFUND VALUE...) bị cắt
//    trước khi trích tổng/món.
// Sam's Club: cổng nguyên luật đã kiểm chứng ở parser-prototype v0.1/v0.2
// (Mẫu 001: 10 dòng món, subtotal 203.30, thuế 9.60+3.90, total 216.80, thẻ 2586).
// Tiệm khác: đường generic (vendor/ngày/thẻ/tổng) — tách từng món để bản sau.
//
// WP4 bước 2 (bản wp4-prep): F2b — parser chịu được nhãn/tiền TÁCH DÒNG
// (CODE-AUDIT F2b): máy trạng thái "nhãn chờ đúng 1 dòng" ở vòng tổng của
// cả hai nhánh + dòng chỉ-có-tiền hoàn tất món đang chờ ở nhánh Sam's.
// F2b chỉ đổi NƠI tìm tiền, không đổi CÁCH phán xét: validate() NGUYÊN VĂN.
//
// WP5 bước 2 (bản wp5-prep, nền wp4-prep): nhận diện tiệm 3 nấc theo
// WP5-SPEC — hàm identifyVendor chung chạy TRƯỚC rẽ nhánh (khớp tên
// toàn-bộ-dòng exact-trước-mờ-sau · neo phụ mạnh/yếu · món đặc trưng
// chỉ-gợi ý với bảng seed RỖNG); ĐƯỜNG RƠI DÒNG-ĐẦU của parseGeneric
// ĐÃ BỎ về mặt cấu trúc; validate() MỞ RỘNG kỷ luật C-11 cho tiệm/ngày
// (phần số học của validate() giữ nguyên văn). Bản Swift này là bản
// dịch của wp5-fixtures/vendor_port.py (đã kiểm chứng 19/19 ở bước 1)
// + extract_port.py cho phần trích địa chỉ/điện thoại/mã cửa hàng.
//
// M1-FIX (bản m1fix, nền wp5-prep): sửa hazard G4 + trích món generic.
// (a) Vòng tổng generic nhận dạng TIỀN-Ở-DÒNG-TRƯỚC: dòng chỉ-có-tiền
// mà dòng ngay sau là nhãn tổng trống thì tiền thuộc về nhãn đó, nhãn
// bị bỏ qua 1 nhịp để máy nhãn-chờ F2b không gán lệch tiếp. (b) Nhánh
// generic có đường trích món riêng (khối UPC, giá kề hai chiều, dòng
// "N@X") — trước đây generic không trích món nào. (c) Neo phụ cộng
// loại cụm-chữ: slogan Home Depot (bằng chứng luồng 003 thật).
// validate() KHÔNG đổi — phần số học nguyên văn như mọi bản trước.
// Port kiểm chứng: m1fix/port.py + m1fix/run_port.py (13/13).
//
// REPARSE (bản reparse, nền m1fix): cộng điểm vào reparse(storedText:)
// — chạy lại ĐÚNG parse(lines:) hiện hành trên văn bản thô ĐÃ LƯU của
// một hoá đơn cũ (nút "Đọc lại" ở màn Chi Tiết, xem ReceiptViews).
// Trước gói này engine mới chỉ áp cho lần quét mới; hoá đơn lưu từ
// Build 1 giữ số của bộ đọc cũ mãi mãi. Không fork logic: reparse chỉ
// khôi phục [OCRLine] từ chữ đã lưu rồi gọi parse(lines:) nguyên văn.
// validate() vẫn KHÔNG đổi. Port kiểm chứng: reparse/port_check.py.
//
// INTEGRATE-V2 (bản này, nền p2-fix = reparse + khối Reconcile ở cuối
// file — khối Reconcile giữ NGUYÊN, không lời gọi mới nào từ parse()):
// đưa kết quả chấm lại buổi đo 2026-11-11 vào đường generic:
// (1) Trích món v2: đường khối UPC cũ (cộng 2 vá có điều kiện + chặn
//     dòng '<mã> / <mã>' mở khối) + NHÁNH MÓN CÙNG-DÒNG cho hoá đơn
//     kiểu "tên ... tiền cùng dòng" (Pan-Asia/Walmart/Costco/Clover)
//     + đọc nhãn số món ở đường generic. Bản thiết kế đã chứng minh
//     ở bench-prep/port_v2.py (chấm lại buổi đo: ca thật A0 trọn sổ
//     0/15 -> 3/15, Σ món khép 8/11 ca L-R) — bản Swift này chép
//     trung thực thuật toán đó; bản gương kiểm chứng là
//     integrate-v2/port_swift_mirror.py (chép từ CHÍNH bản Swift
//     này), KHÔNG chép từ port_v2.
// (2) Vá tầng totals/ngày theo bằng chứng buổi đo (mới, ngoài
//     port_v2): dòng thuế mang SUẤT mà nhãn không bắt đầu bằng TAX
//     ("Coweta sales tax 10.05% $16.53"); ngày tháng chữ kiểu Clover
//     ("20-May-2026 1:11:30P") + giờ đứng riêng dòng; neo tổng bằng
//     số học theo tinh thần Reconcile khi nhãn vỡ/mất (chỉ nhận số
//     ĐÃ IN trên bill và chỉ khi phương trình khép DUY NHẤT — không
//     nặn số, không ghi thuế suy diễn ngoài một dòng tiền đã in mà
//     vai trò của nó được phương trình chứng minh).
// Đường Sam's + validate() giữ nguyên văn như bản nền.

enum ReceiptParser {

    static func parse(lines input: [OCRLine]) -> ParseResult {
        let lines = input
            .map { OCRLine(text: $0.text.trimmingCharacters(in: .whitespaces), confidence: $0.confidence) }
            .filter { !$0.text.isEmpty }
        var result = ParseResult()
        result.rawText = lines.map { $0.text }.joined(separator: "\n")

        // WP5: nhận diện tiệm 3 nấc chạy TRƯỚC, một hàm chung cho mọi
        // đường — kết quả quyết định rẽ nhánh Sam's/generic (thay isSams
        // khớp-chuỗi cũ) và là nguồn tên tiệm DUY NHẤT của cả parser.
        let identification = identifyVendor(lines: lines)
        if identification.vendorKey == "sams" {
            result = parseSams(lines: lines)
        } else {
            result = parseGeneric(lines: lines, identifiedVendor: identification.vendor)
        }
        result.vendor = identification.vendor
        result.vendorKey = identification.vendorKey
        result.vendorConfidence = identification.confidence
        result.vendorSource = identification.source
        result.vendorSuggestion = identification.suggestion
        result.vendorAnchorDisputed = identification.anchorDisputed
        let contact = extractVendorContact(lines: lines)
        result.vendorAddress = contact.address
        result.vendorPhone = contact.phone
        result.storeNumber = contact.storeNumber
        result.rawText = lines.map { $0.text }.joined(separator: "\n")
        result.warnings = validate(result)
        return result
    }

    // MARK: - REPARSE: đọc lại hoá đơn đã lưu từ văn bản thô đã lưu
    //
    // OCRLine.confidence KHÔNG được lưu cùng hoá đơn (chỉ lưu chữ), nên
    // dòng khôi phục phải gán một độ tin cậy thay thế. Truy vết mọi nơi
    // Parser dùng confidence của dòng: nó chỉ chảy vào đúng 3 trường
    // phái sinh — totalConfidence (mọi điểm gán TỔNG ở hai nhánh),
    // vendorConfidence (nấc 1 của identifyVendor: exact = conf,
    // fuzzy = conf × 0.8; nấc 2 neo phụ tự gán 0.5, không dùng tới),
    // dateConfidence (findDateTime / findDateOnly) — và validate() đọc
    // 3 trường đó qua ngưỡng 0.60/0.85, mọi điều kiện đều kèm "> 0".
    // Hệ quả của từng lựa chọn: 1.0 -> validate() câm mọi cảnh báo độ
    // tin cậy (YẾU hơn đường quét); 0.0 -> cũng câm vì vướng điều kiện
    // "> 0" (yếu nhất); 0.5 -> nằm dưới ngưỡng 0.60 nên cả 3 trường
    // đều nhận cảnh báo MẠNH NHẤT ("độ tin cậy THẤP — bắt buộc kiểm
    // tra lại với giấy") — thà thêm cờ còn hơn mất cờ, đúng kỷ luật
    // Hộp Chờ. 0.5 cũng là mức parser tự gán cho bằng chứng nấc 2
    // ("không phải tên in trên giấy") — cùng một nghĩa: bằng chứng
    // không còn kiểm chứng trực tiếp được. Số trích ra (tiền/món/
    // tiệm/ngày/thẻ) không phụ thuộc confidence ở bất kỳ nhánh nào.

    /// Độ tin cậy gán cho dòng khôi phục từ văn bản đã lưu (xem trên).
    static let recoveredLineConfidence: Double = 0.5

    /// Đọc lại một hoá đơn ĐÃ LƯU: tách văn bản thô đã lưu theo "\n"
    /// thành [OCRLine] rồi gọi đúng parse(lines:) hiện hành — cùng
    /// một bộ đọc như lần quét mới, không fork logic. Dòng rỗng/xen
    /// khoảng trắng được parse(lines:) tự cắt/lọc như đường quét.
    static func reparse(storedText: String) -> ParseResult {
        let lines = storedText
            .split(separator: "\n")
            .map { OCRLine(text: String($0), confidence: recoveredLineConfidence) }
        return parse(lines: lines)
    }

    // MARK: - SAM'S CLUB (cổng từ prototype v0.1 đã đạt Mẫu 001)

    private static func parseSams(lines: [OCRLine]) -> ParseResult {
        var r = ParseResult()
        r.vendorKey = "sams"
        // Tên tiệm + vendorConfidence: parse() gắn từ identifyVendor
        // (WP5) sau khi hàm này trả về — ở đây KHÔNG tự đặt tên tiệm.

        // Ngày + giờ: MM/DD/YY(YY) HH:MM
        if let found = findDateTime(in: lines) {
            r.date = found.date
            r.dateConfidence = found.confidence
        }

        // --- Dòng món ---
        var pending: ParsedLineItem? = nil
        for line in lines {
            let text = line.text

            // Dòng số lượng: "2 AT 1 FOR 19.48 38.96 Y"
            if let q = matchQtyLine(text), var p = pending {
                p.qty = q.qty
                p.unitPriceCents = q.unitCents
                p.amountCents = q.amountCents
                if let flag = q.flag { p.taxFlag = flag }
                r.items.append(p)
                pending = nil
                continue
            }

            // F2b: dòng CHỈ có tiền ("19.48 Y") hoàn tất món đang chờ —
            // tiền của món rớt xuống dòng thị giác ngay sau khi hàng bị xé
            // dù đã ráp (ảnh lệch). Không có món chờ thì dòng tiền lẻ rơi
            // tiếp xuống các luật dưới (không luật nào nhận) như cũ.
            if var p = pending,
               let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?\s*([YT])?$"#), m.count == 3 {
                let cents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                p.amountCents = cents
                p.unitPriceCents = cents
                if let flag = m[2] { p.taxFlag = flag }
                r.items.append(p)
                pending = nil
                continue
            }

            // Dòng giảm giá Instant Savings: "INST SV <tên> [tiền] [cờ]"
            if let rest = matchPrefix(text, pattern: #"^INST SV\s+(.+)$"#) {
                if let tail = trailingAmount(in: rest) {
                    var item = ParsedLineItem(name: "INST SV " + tail.name)
                    item.amountCents = tail.cents
                    item.unitPriceCents = tail.cents
                    item.taxFlag = tail.flag
                    r.items.append(item)
                } else {
                    pending = ParsedLineItem(name: "INST SV " + rest)
                }
                continue
            }

            // Dòng món thường: mã 10 số + phần còn lại
            if let m = matchGroups(text, pattern: #"^(\d{10})\s+(.+)$"#), m.count == 2 {
                let code = m[0]
                let rest = m[1] ?? ""
                if let tail = trailingAmount(in: rest), !tail.name.isEmpty {
                    var item = ParsedLineItem(name: tail.name)
                    item.itemCode = code
                    item.amountCents = tail.cents
                    item.unitPriceCents = tail.cents
                    item.taxFlag = tail.flag
                    r.items.append(item)
                } else {
                    var item = ParsedLineItem(name: rest)
                    item.itemCode = code
                    pending = item
                }
                continue
            }
            // Dòng khác: bỏ qua (qty line lạc khi không có pending cũng rơi xuống đây).
        }
        if let p = pending { r.items.append(p) }

        // --- Tổng / thuế / thẻ / TC# ---
        // F2b: máy trạng thái nhãn-chờ (đúng đặc tả CODE-AUDIT F2b).
        // pendingKind: "SUBTOTAL" | "TOTAL" | "TAX"; với TAX giữ thêm
        // nhãn hiển thị ("TAX 1") + tỉ lệ đọc được trên dòng nhãn để
        // dòng thuế tách không thua thông tin so với đường cùng-dòng.
        var pendingKind: String? = nil
        var pendingTaxLabel: String? = nil
        var pendingTaxRate: String? = nil
        for line in lines {
            let text = line.text
            // Dòng chỉ-có-tiền hoàn tất nhãn đang chờ.
            if let kind = pendingKind,
               let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#), m.count == 2 {
                let cents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                switch kind {
                case "SUBTOTAL":
                    r.subtotalCents = cents
                case "TOTAL":
                    r.totalCents = cents
                    r.totalConfidence = line.confidence
                default:
                    r.taxes.append(ParsedTaxLine(label: pendingTaxLabel ?? "TAX",
                                                  rateText: pendingTaxRate,
                                                  amountCents: cents))
                }
                pendingKind = nil
                pendingTaxLabel = nil
                pendingTaxRate = nil
                continue
            }
            // Dòng chỉ-có-nhãn (TAX được kèm thứ hạng + tỉ lệ, chưa có tiền).
            if let lm = matchGroups(text, pattern: #"^(SUBTOTAL|TOTAL|TAX\s+(\d)(?:\s+([\d.]+)\s*%)?)$"#), lm.count == 3 {
                let head = lm[0] ?? ""
                if head == "SUBTOTAL" || head == "TOTAL" {
                    pendingKind = head
                    pendingTaxLabel = nil
                    pendingTaxRate = nil
                } else {
                    pendingKind = "TAX"
                    pendingTaxLabel = "TAX \(lm[1] ?? "")"
                    pendingTaxRate = lm[2]
                }
                continue
            }
            // Mọi dòng khác: nhãn chờ HẾT HẠN — đúng 1 dòng ân hạn, không
            // bao giờ vươn qua một dòng chữ để vớ số ở xa (CODE-AUDIT F2b).
            pendingKind = nil
            pendingTaxLabel = nil
            pendingTaxRate = nil
            if let m = matchGroups(text, pattern: #"^SUBTOTAL\s+\$?(\d[\d,]*\.\d{2})(-)?$"#) {
                r.subtotalCents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                continue
            }
            if let m = matchGroups(text, pattern: #"^TAX\s+(\d)\s+([\d.]+)\s*%\s+\$?(\d[\d,]*\.\d{2})(-)?$"#), m.count == 4 {
                let amount = moneyToCents(m[2] ?? "", negative: m[3] != nil)
                r.taxes.append(ParsedTaxLine(label: "TAX \(m[0] ?? "")", rateText: m[1], amountCents: amount))
                continue
            }
            if let m = matchGroups(text, pattern: #"^TOTAL\s+\$?(\d[\d,]*\.\d{2})(-)?$"#) {
                r.totalCents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                r.totalConfidence = line.confidence
                continue
            }
            if let m = matchGroups(text, pattern: #"^#\s*ITEMS SOLD\s+(\d+)$"#) {
                r.itemsSold = Int(m[0] ?? "")
                continue
            }
            if let tc = matchPrefix(text, pattern: #"^TC#\s+([\d ]+)$"#) {
                let digits = tc.replacingOccurrences(of: " ", with: "")
                if digits.count >= 16 && digits.count <= 24 {
                    r.dedupeKey = "SAMS-TC-" + digits
                }
                continue
            }
        }
        let card = findCard(lines: lines)
        r.cardLast4 = card.last4
        r.cardBrand = card.brand
        return r
    }

    // MARK: - GENERIC (mọi tiệm khác — Build 1 chỉ lấy trường cốt lõi)

    private static func parseGeneric(lines: [OCRLine], identifiedVendor: String?) -> ParseResult {
        var r = ParseResult()
        r.vendorKey = "generic"

        // Vendor: WP5 — tên tiệm CHỈ từ identifyVendor (nấc 1 khớp tên /
        // nấc 2 neo phụ). Đường rơi dòng-đầu của Build 1 (nguồn lỗi
        // "How doers" trên Mẫu 003) ĐÃ BỎ về mặt cấu trúc: không khớp
        // thì để trống, validate() gắn cảnh báo, anh nhập tay.
        r.vendor = identifiedVendor

        // Ngày — INTEGRATE-V2: findDateTime/findDateOnly đã cộng mẫu
        // tháng chữ (xem dưới). Thêm đường GHÉP GIỜ: hoá đơn thật có
        // ca ngày và giờ bị OCR tách thành hai dòng rời (ngày ở một
        // dòng, giờ đứng một mình ở dòng khác — bằng chứng buổi đo
        // L-R03) thì ngày-không-giờ được ghép với dòng giờ độc lập
        // duy nhất đọc được; không có dòng giờ thì giữ ngày 00:00
        // như cũ. Đường Sam's không đổi (vẫn findDateTime trực tiếp).
        if let found = findDateTime(in: lines) {
            r.date = found.date
            r.dateConfidence = found.confidence
        } else if let found = findDateOnly(in: lines) {
            if let t = findStandaloneTime(in: lines),
               let merged = mergingTime(into: found.date, hour: t.hour, minute: t.minute) {
                r.date = merged
                r.dateConfidence = min(found.confidence, t.confidence)
            } else {
                r.date = found.date
                r.dateConfidence = found.confidence
            }
        }

        // Tổng: cắt vùng loại trừ TRƯỚC (Suggested Tip chứa tổng giả).
        // F2b: cùng máy trạng thái nhãn-chờ như nhánh Sam's, theo pattern
        // của nhánh generic; TOTAL vẫn tôn trọng vùng loại trừ
        // (ignoreTotals) y như đường cùng-dòng.
        var ignoreTotals = false
        var pendingKind: String? = nil   // "SUBTOTAL" | "TOTAL" | "TAX"
        var skipNext = false   // M1-FIX: nhãn đã được dòng tiền ngay trước nhận
        // INTEGRATE-V2: sổ theo dõi cho tầng neo tổng (anchorTotals)
        // và luật dòng thuế mang suất.
        var claimedIndices = Set<Int>()   // dòng đã sinh giá trị tổng/thuế
        var taxLineIndices: [Int] = []    // chỉ số dòng nguồn của r.taxes (song song)
        var totalsSeen = false            // đã gặp bất kỳ neo vùng tổng nào
        var totalTaxSummary: (index: Int, cents: Int)? = nil
        for (index, line) in lines.enumerated() {
            let text = line.text
            let upper = text.uppercased()
            // M1-FIX: dòng nhãn đã có tiền từ dòng ngay trước (xem
            // khối tiền-trước-nhãn ở dưới) -> bỏ qua, không cho máy
            // nhãn-chờ F2b dựng chờ mới trên nhãn đã xong.
            if skipNext {
                skipNext = false
                pendingKind = nil
                continue
            }
            // F2b: dòng chỉ-có-tiền hoàn tất nhãn đang chờ.
            if let kind = pendingKind,
               let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#), m.count == 2 {
                let cents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                switch kind {
                case "SUBTOTAL":
                    if r.subtotalCents == nil { r.subtotalCents = cents }
                case "TOTAL":
                    if !ignoreTotals, r.totalCents == nil {
                        r.totalCents = cents
                        r.totalConfidence = line.confidence
                    }
                default:
                    r.taxes.append(ParsedTaxLine(label: "TAX", rateText: nil, amountCents: cents))
                    taxLineIndices.append(index)
                }
                claimedIndices.insert(index)
                totalsSeen = true
                pendingKind = nil
                continue
            }
            // M1-FIX (tiền-trước-nhãn): dòng CHỈ có tiền mà dòng NGAY
            // SAU là nhãn tổng trống -> tiền thuộc về nhãn đó (dạng
            // Mẫu 003 thật: "96.91 / SUBTOTAL", "$105.16 / TOTAL").
            // Chỉ nhận đúng 1 dòng kề — không vươn xa; nhãn đã nhận
            // được đánh dấu bỏ qua (skipNext) để không bị gán tiền
            // của nhãn kế tiếp, đúng gốc hazard G4. TOTAL vẫn tôn
            // trọng vùng loại trừ như đường cùng-dòng.
            if let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#), m.count == 2,
               index + 1 < lines.count {
                let cents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                let next = lines[index + 1].text
                let nextUpper = next.uppercased()
                var claimed = false
                if matchGroups(next, pattern: #"^SUBTOTAL\s*:?$"#) != nil {
                    if r.subtotalCents == nil { r.subtotalCents = cents }
                    claimed = true
                } else if (nextUpper.hasPrefix("TAX") || nextUpper.hasPrefix("SALES TAX")),
                          lastMoneyInLine(next) == nil {
                    r.taxes.append(ParsedTaxLine(label: "TAX", rateText: nil, amountCents: cents))
                    taxLineIndices.append(index)
                    claimed = true
                } else if !ignoreTotals,
                          matchGroups(next, pattern: #"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?$"#) != nil {
                    if r.totalCents == nil {
                        r.totalCents = cents
                        r.totalConfidence = line.confidence
                    }
                    claimed = true
                }
                if claimed {
                    claimedIndices.insert(index)
                    claimedIndices.insert(index + 1)
                    totalsSeen = true
                    skipNext = true
                    continue
                }
            }
            // F2b: dòng chỉ-có-nhãn -> ghi nhớ cho đúng dòng ngay sau.
            if matchGroups(text, pattern: #"^SUBTOTAL\s*:?$"#) != nil {
                pendingKind = "SUBTOTAL"
                totalsSeen = true
                continue
            }
            if !ignoreTotals,
               matchGroups(text, pattern: #"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?$"#) != nil {
                pendingKind = "TOTAL"
                totalsSeen = true
                continue
            }
            if (upper.hasPrefix("TAX") || upper.hasPrefix("SALES TAX")),
               lastMoneyInLine(text) == nil {
                pendingKind = "TAX"
                totalsSeen = true
                continue
            }
            // Mọi dòng khác (kể cả dòng bật vùng loại trừ và RETURN
            // POLICY ở dưới): nhãn chờ hết hạn sau đúng 1 dòng.
            pendingKind = nil
            if upper.contains("SUGGESTED TIP") || upper.contains("TIP GUIDE") {
                ignoreTotals = true
            }
            if upper.contains("RETURN POLICY") || upper.contains("MAX REFUND VALUE") {
                continue
            }
            if let m = matchGroups(text, pattern: #"^SUBTOTAL\s*:?\s*\$?(\d[\d,]*\.\d{2})(-)?$"#) {
                if r.subtotalCents == nil {
                    r.subtotalCents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                }
                claimedIndices.insert(index)
                totalsSeen = true
                continue
            }
            let isTaxLine = upper.hasPrefix("TAX") || upper.hasPrefix("SALES TAX")
            if isTaxLine, let cents = lastMoneyInLine(text) {
                r.taxes.append(ParsedTaxLine(label: "TAX", rateText: nil, amountCents: cents))
                taxLineIndices.append(index)
                claimedIndices.insert(index)
                totalsSeen = true
                continue
            }
            // INTEGRATE-V2: dòng TỔNG THUẾ tóm tắt ("TOTAL TAX 9.38")
            // — không cộng chồng lên các dòng thuế thành phần: chỉ
            // giữ làm ứng viên dự phòng, dùng sau vòng lặp khi không
            // có dòng thuế thành phần nào.
            if upper.contains("TOTAL TAX"), let cents = lastMoneyInLine(text) {
                if totalTaxSummary == nil {
                    totalTaxSummary = (index, cents)
                }
                claimedIndices.insert(index)
                totalsSeen = true
                continue
            }
            // INTEGRATE-V2: dòng thuế mang SUẤT mà nhãn không bắt đầu
            // bằng TAX — "Coweta sales tax 10.05% $16.53" (chữ TAX ở
            // giữa nhãn), "F 4.0107% TAXÙ 1.16" (chữ TAX ở từ đệm sau
            // suất), "Oklahoma Grocery 5.55% $1.33" (không có chữ
            // TAX: chỉ nhận khi vùng tổng đã bắt đầu — totalsSeen —
            // để không vớ phải dòng món mang suất lạ).
            if let rt = matchTaxRateLine(text) {
                if rt.taxLabeled || totalsSeen {
                    r.taxes.append(ParsedTaxLine(label: rt.label, rateText: rt.rate, amountCents: rt.cents))
                    taxLineIndices.append(index)
                    claimedIndices.insert(index)
                    totalsSeen = true
                    continue
                }
            }
            if !ignoreTotals, r.totalCents == nil,
               let m = matchGroups(text, pattern: #"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?\s*\$?(\d[\d,]*\.\d{2})(-)?$"#),
               m.count == 3 {
                r.totalCents = moneyToCents(m[1] ?? "", negative: m[2] != nil)
                r.totalConfidence = line.confidence
                claimedIndices.insert(index)
                totalsSeen = true
                continue
            }
            if r.dedupeKey == nil, let tc = matchPrefix(text, pattern: #"^TC#\s+([\d ]+)$"#) {
                let digits = tc.replacingOccurrences(of: " ", with: "")
                if digits.count >= 16 && digits.count <= 24 {
                    r.dedupeKey = "TC-" + digits
                }
                continue
            }
        }

        // INTEGRATE-V2: dòng TỔNG THUẾ tóm tắt chỉ được dùng khi
        // không có bất kỳ dòng thuế thành phần nào đọc được — trong
        // trường hợp đó nó LÀ dòng thuế duy nhất của bill, không
        // cộng chồng lên các thành phần.
        if r.taxes.isEmpty, let summary = totalTaxSummary {
            r.taxes.append(ParsedTaxLine(label: "TAX", rateText: nil, amountCents: summary.cents))
            taxLineIndices.append(summary.index)
        }

        // INTEGRATE-V2: trích món generic v2 — khối UPC + nhánh
        // cùng-dòng, xem parseGenericItemsV2 ở dưới (thay
        // parseGenericItems của M1-FIX).
        let extracted = parseGenericItemsV2(lines: lines)
        r.items = extracted.items
        if r.itemsSold == nil {
            r.itemsSold = findItemsSoldGeneric(lines: lines)
        }

        // INTEGRATE-V2: neo tổng bằng số học khi nhãn vỡ/mất (chỉ
        // điền trường còn trống, chỉ bằng số đã in, chỉ khi khép
        // duy nhất) — xem anchorTotals.
        anchorTotals(result: &r, lines: lines, claimedIndices: claimedIndices,
                     taxLineIndices: &taxLineIndices, lastItemIndex: extracted.lastItemIndex)

        let card = findCard(lines: lines)
        r.cardLast4 = card.last4
        r.cardBrand = card.brand

        // Khoá chống trùng yếu cho tiệm generic: tiệm + ngày + tổng.
        if r.dedupeKey == nil, let total = r.totalCents, let date = r.date, let vendor = r.vendor {
            let day = DateFormatter()
            day.calendar = Calendar(identifier: .gregorian)
            day.locale = Locale(identifier: "en_US_POSIX")
            day.dateFormat = "yyyy-MM-dd"
            r.dedupeKey = "GEN|\(vendor)|\(day.string(from: date))|\(total)"
        }
        return r
    }

    // MARK: - INTEGRATE-V2: món cho tiệm generic v2 (khối UPC + cùng-dòng)
    //
    // Thay parseGenericItems của M1-FIX. Thiết kế đã chứng minh ở
    // bench-prep/port_v2.py (gói PARSER-GAP, chấm lại buổi đo
    // 2026-11-11 trên dòng-cuối A0: ca thật trọn sổ 0/15 -> 3/15,
    // Σ món khép 8/11 ca L-R) — bản Swift dưới đây chép TRUNG THỰC
    // thuật toán đó, gồm: đường khối UPC cũ + 2 vá có điều kiện
    // (tiền ở cuối dòng mã / cuối dòng mô tả gán cho chính món đó
    // khi món chưa có tiền; dòng '<mã coupon> / <mã món>' KHÔNG mở
    // khối) + NHÁNH CÙNG-DÒNG cho các dòng khối chưa dùng. Món trả
    // về sắp theo vị trí dòng xuất hiện. Mọi món vẫn qua cổng sổ
    // validate() như cũ — trích ra mà tổng không khép thì giữ kết
    // quả + cờ, không sửa số. Dòng tiền bị OCR phá được trích với
    // amount = nil: TUYỆT ĐỐI không nặn số từ mảnh vỡ.

    /// Một món kèm chỉ số dòng nguồn (để sắp lại theo thứ tự in và
    /// để tầng neo tổng biết vùng món kết thúc ở đâu).
    private struct IndexedItem {
        var index: Int
        var item: ParsedLineItem
    }

    private static func parseGenericItemsV2(lines: [OCRLine]) -> (items: [ParsedLineItem], lastItemIndex: Int?) {
        var tagged: [IndexedItem] = []
        var consumed = Set<Int>()
        var open: ParsedLineItem? = nil
        var openIndex: Int? = nil
        var openHasDescription = false
        var prevLineWasBlock = false
        var lastBareMoney: (index: Int, cents: Int)? = nil
        var bareMoneyConsumed = Set<Int>()
        var stop = lines.count

        func closeOpen() {
            if let o = open, let oi = openIndex {
                tagged.append(IndexedItem(index: oi, item: o))
            }
            open = nil
            openIndex = nil
            openHasDescription = false
            prevLineWasBlock = false
        }

        // Đường khối UPC (sao trung thực vòng lặp gốc + 2 vá).
        for (index, line) in lines.enumerated() {
            let text = line.text
            let upper = text.uppercased()
            if upper.hasPrefix("SUBTOTAL") || upper.hasPrefix("TOTAL")
                || upper.hasPrefix("SALES TAX") || upper.hasPrefix("TAX")
                || upper.contains("RETURN POLICY") || upper.contains("MAX REFUND VALUE")
                || upper.contains("SUGGESTED TIP") || upper.contains("TIP GUIDE") {
                stop = index
                break
            }
            // Dòng số lượng kiểu Home Depot: "2@34.98".
            if let m = matchGroups(text, pattern: #"^(\d+)\s*@\s*(\d[\d,]*\.\d{2})$"#), m.count == 2,
               var o = open {
                o.qty = Int(m[0] ?? "") ?? o.qty
                o.unitPriceCents = moneyToCents(m[1] ?? "", negative: false)
                open = o
                consumed.insert(index)
                prevLineWasBlock = true
                continue
            }
            // Dòng chỉ-có-tiền: giá kề SAU khối cho món đang mở.
            if let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#), m.count == 2 {
                let cents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                lastBareMoney = (index, cents)
                if var o = open, o.amountCents == nil, prevLineWasBlock {
                    o.amountCents = cents
                    if o.unitPriceCents == nil { o.unitPriceCents = cents }
                    open = o
                    bareMoneyConsumed.insert(index)
                    consumed.insert(index)
                }
                prevLineWasBlock = false
                continue
            }
            // Dòng mã món: >= 9 số liền + phần tên. Dòng '<mã> / <mã>'
            // (INST SV của Costco) KHÔNG mở khối — nếu mở, khối sẽ
            // nuốt dòng món thật ngay sau làm "mô tả" và gán tiền trần
            // của vùng tổng làm giá món (đo được trên final L-R01:
            // món rác amount = subtotal 12548). Để nhánh cùng-dòng xử.
            if let m = matchGroups(text, pattern: #"^(\d{9,})\s+(.+)$"#), m.count == 2,
               !((m[1] ?? "").trimmingCharacters(in: .whitespaces).hasPrefix("/")) {
                closeOpen()
                var item = ParsedLineItem(name: "")
                item.itemCode = m[0]
                var rest = m[1] ?? ""
                if let fm = matchGroups(rest, pattern: #"^(.*?)\s*<([A-Z])>$"#),
                   let cleaned = fm[0] {
                    rest = cleaned
                    item.taxFlag = fm[1]
                }
                item.name = rest
                if let lb = lastBareMoney, lb.index == index - 1,
                   !bareMoneyConsumed.contains(lb.index) {
                    item.amountCents = lb.cents
                    item.unitPriceCents = lb.cents
                    consumed.insert(lb.index)
                }
                // VÁ (i): tiền ở cuối chính dòng mã thuộc về món này
                // (bản final trên máy thật gộp tiền vào dòng mã, khác
                // luồng thô đóng băng — luồng thô không có tiền cuối
                // dòng mã nên vá không đổi hành vi trên corpus đó).
                if item.amountCents == nil, let tail = trailingAmount(in: rest), !tail.name.isEmpty {
                    item.amountCents = tail.cents
                    if item.unitPriceCents == nil { item.unitPriceCents = tail.cents }
                }
                open = item
                openIndex = index
                openHasDescription = false
                prevLineWasBlock = true
                consumed.insert(index)
                continue
            }
            // Dòng mô tả ngay sau dòng mã — tên đầy đủ của món.
            if var o = open, !openHasDescription, prevLineWasBlock,
               text.contains(where: { $0.isLetter }),
               matchGroups(text, pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})"#) == nil {
                // VÁ (ii): tiền ở cuối dòng mô tả thuộc về món đang mở.
                if let tail = trailingAmount(in: text), o.amountCents == nil {
                    o.amountCents = tail.cents
                    if o.unitPriceCents == nil { o.unitPriceCents = tail.cents }
                    o.name = tail.name
                } else {
                    o.name = text
                }
                open = o
                openHasDescription = true
                prevLineWasBlock = true
                consumed.insert(index)
                continue
            }
            prevLineWasBlock = false
        }
        closeOpen()

        tagged += extractSamelineItems(lines: lines, consumed: consumed, stop: stop)
        tagged.sort { $0.index < $1.index }
        return (tagged.map { $0.item }, tagged.map { $0.index }.max())
    }

    // MARK: - INTEGRATE-V2: nhánh món CÙNG-DÒNG

    /// Tiền tố / cụm nhãn KHÔNG bao giờ là món cùng-dòng (thanh toán,
    /// quản trị quầy, chân bill) — lớp phòng thủ thứ hai sau điểm
    /// dừng vùng tổng trong vòng trích xuất.
    private static let samelineExcludePrefixes: [String] = [
        "ST#", "OP#", "TE#", "TR#", "TC#", "REF #", "REF#", "AID",
        "TERMINAL", "AUTH", "NETWORK", "APPR", "SEQ#", "STATION", "ORDER",
        "TRANSACTION", "CASHIER", "MEMBER", "DC MEMBER", "SALE", "DEBIT",
        "CREDIT", "EFT", "VISA", "MASTERCARD", "MASTER CARD", "AMEX",
        "DISCOVER", "FSA", "PAYMENT", "AMOUNT", "CHANGE", "CASH", "ENTRY",
        "CONTACTLESS", "RETAIN", "THANK", "GET FREE", "SCAN TO",
        "LOW PRICES", "POLICY", "CONTACT", "ITEM COUNT", "ITEMS SOLD",
        "# ITEMS",
    ]
    private static let samelineExcludeContains: [String] = [
        "CASH BACK", "CASH ", "PURCHASE", "TOTAL", "HTTP", ".COM",
        "SURVEY", "FEEDBACK", "RETURN POLICY", "STORE RETUR",
    ]

    private static func samelineExcluded(upper: String) -> Bool {
        if upper.contains("%") { return true }
        if samelineExcludePrefixes.contains(where: { upper.hasPrefix($0) }) { return true }
        if samelineExcludeContains.contains(where: { upper.contains($0) }) { return true }
        return false
    }

    private static func hasAlphaToken(_ name: String) -> Bool {
        matchGroups(name, pattern: #"[A-Za-z]{2,}"#) != nil
    }

    /// Tiền sạch ở CUỐI dòng (nhánh cùng-dòng): (tên, cents, đuôi).
    /// Đuôi = cờ/rác tối đa 3 ký tự không-phải-số sau tiền (R, FT,
    /// ł...); dấu trừ dính ngay sau tiền (kiểu '4.50-A' của dòng
    /// giảm giá Costco) cho số âm.
    private static func lastCleanMoney(_ text: String) -> (name: String, cents: Int, tail: String)? {
        guard let m = matchGroups(text, pattern: #"^(.*?)\s*\$?\s*(\d[\d,]*\.\d{2})(-)?\s*([^\d\s]{0,3})$"#),
              m.count == 4 else { return nil }
        let cents = moneyToCents(m[1] ?? "", negative: m[2] != nil)
        return ((m[0] ?? "").trimmingCharacters(in: .whitespaces), cents,
                (m[3] ?? "").trimmingCharacters(in: .whitespaces))
    }

    /// Tiền thập-phân-PHẨY sau $ ở cuối dòng (rác OCR '$2,79' thay
    /// '$2.79'): chỉ nhận khi có $ ngay trước và token không chứa
    /// dấu chấm — không lẫn với phân cách nghìn (luôn đi cùng chấm).
    private static func lastCommaMoney(_ text: String) -> (name: String, cents: Int, tail: String)? {
        guard let m = matchGroups(text, pattern: #"^(.*?)\s*\$\s*(\d+,\d{2})\s*([^\d\s]{0,3})$"#),
              m.count == 3, let money = m[1] else { return nil }
        let parts = money.split(separator: ",")
        guard parts.count == 2, let whole = Int(parts[0]), let frac = Int(parts[1]) else { return nil }
        return ((m[0] ?? "").trimmingCharacters(in: .whitespaces), whole * 100 + frac,
                (m[2] ?? "").trimmingCharacters(in: .whitespaces))
    }

    /// Dòng có tiền nhưng OCR phá mất dạng tiền ('$131 57', token
    /// '3.€8', ':,68'): trả PHẦN TÊN để trích món amount = nil — số
    /// tiền KHÔNG được nặn lại từ mảnh vỡ. nil nếu không khớp.
    private static func brokenMoneyName(_ text: String) -> String? {
        if let m = matchGroups(text, pattern: #"^(.*?)\s*\$\s*([\d\s]+)$"#), m.count == 2,
           let name = m[0], let junk = m[1] {
            if junk.filter({ $0.isNumber }).count >= 4, hasAlphaToken(name) {
                return name.trimmingCharacters(in: .whitespaces)
            }
        }
        if let m = matchGroups(text, pattern: #"^(.*?)\s+([0-9.,:€$£¥฿]{3,})\s*([^\d\s]{0,3})$"#),
           m.count == 3, let name = m[0], let tok = m[1] {
            if tok.filter({ $0.isNumber }).count >= 2,
               tok.contains(".") || tok.contains(",") || tok.contains(":"),
               hasAlphaToken(name) {
                return name.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Dòng cân 'W lb @ $U/lb' (chịu rác OCR: '1b'/'Tb', đơn giá mất
    /// $): (weightLb, unitCents?) hoặc nil. Trọng lượng KHÔNG phải
    /// qty đếm món — chỉ là metadata gắn kèm (xem extract).
    private static func weightLine(_ text: String) -> (lb: Double, unit: Int?)? {
        guard text.contains("/lb") || text.contains("/1b") else { return nil }
        guard let m = matchGroups(text, pattern: #"(\d+(?:\.\d+)?)\s*(?:lb|1b|Tb)\b"#),
              let w = Double(m[0] ?? "") else { return nil }
        var unit: Int? = nil
        if let mu = matchGroups(text, pattern: #"\$\s*\*?\s*(\d[\d,]*\.\d{2})"#) {
            unit = moneyToCents(mu[0] ?? "", negative: false)
        } else if let mu = matchGroups(text, pattern: #"(\d[\d,]*\.\d{2})\s*/l"#) {
            unit = moneyToCents(mu[0] ?? "", negative: false)
        }
        return (w, unit)
    }

    /// Như matchQtyLine của đường Sam's nhưng cờ cuối dòng nhận 1–2
    /// chữ cái bất kỳ (Walmart in cờ R/T thay Y/T của Sam's).
    private static func matchQtyLineGeneric(_ text: String) -> (qty: Int, unitCents: Int, amountCents: Int, flag: String?)? {
        guard let m = matchGroups(text, pattern: #"^(\d+)\s+AT\s+1\s+FOR\s+(\d[\d,]*\.\d{2})(-)?\s+(\d[\d,]*\.\d{2})(-)?\s*([A-Z]{1,2})?$"#),
              m.count == 6, let qty = Int(m[0] ?? "") else { return nil }
        let unit = moneyToCents(m[1] ?? "", negative: m[2] != nil)
        let amount = moneyToCents(m[3] ?? "", negative: m[4] != nil)
        return (qty, unit, amount, m[5])
    }

    /// Nhãn số món đọc TRỰC TIẾP từ bill ở đường generic (bản gốc chỉ
    /// đọc các nhãn này ở đường Sam's nên hoá đơn generic luôn mất
    /// itemsSold — cổng E3 không kiểm được). nil khi không nhãn nào
    /// đọc được; mẫu "Item Count:" đứng riêng thì nhận số nguyên
    /// trần ở dòng ngay sau (số lượng là số nguyên, subtotal luôn
    /// có phần thập phân nên không lẫn).
    private static func findItemsSoldGeneric(lines: [OCRLine]) -> Int? {
        for (index, line) in lines.enumerated() {
            let text = line.text
            if let m = matchGroups(text, pattern: #"TOTAL NUMBER OF ITEMS SOLD\s*=\s*(\d+)"#) { return Int(m[0] ?? "") }
            if let m = matchGroups(text, pattern: #"#\s*ITEMS SOLD\s+(\d+)"#) { return Int(m[0] ?? "") }
            if let m = matchGroups(text, pattern: #"^ITEMS SOLD:?\s+(\d+)$"#) { return Int(m[0] ?? "") }
            if let m = matchGroups(text, pattern: #"^ITEM COUNT:?\s+(\d+)$"#) { return Int(m[0] ?? "") }
            if matchGroups(text, pattern: #"^ITEM COUNT:?$"#) != nil,
               index + 1 < lines.count,
               matchGroups(lines[index + 1].text, pattern: #"^\d{1,3}$"#) != nil {
                return Int(lines[index + 1].text)
            }
        }
        return nil
    }

    /// Kiểm nhãn số món trên ĐÚNG một dòng (cho vòng cùng-dòng bỏ qua
    /// dòng nhãn — tương đương findItemsSoldGeneric trên danh sách
    /// 1 dòng, nơi luật dòng-kế không áp dụng được).
    private static func findItemsSoldInLine(_ text: String) -> Int? {
        if let m = matchGroups(text, pattern: #"TOTAL NUMBER OF ITEMS SOLD\s*=\s*(\d+)"#) { return Int(m[0] ?? "") }
        if let m = matchGroups(text, pattern: #"#\s*ITEMS SOLD\s+(\d+)"#) { return Int(m[0] ?? "") }
        if let m = matchGroups(text, pattern: #"^ITEMS SOLD:?\s+(\d+)$"#) { return Int(m[0] ?? "") }
        if let m = matchGroups(text, pattern: #"^ITEM COUNT:?\s+(\d+)$"#) { return Int(m[0] ?? "") }
        return nil
    }

    /// Nhánh cùng-dòng: quét các dòng trong vùng món mà đường khối
    /// chưa dùng, trích món dạng 'tên ... [mã] ... [$]tiền [cờ]'.
    /// Thứ tự mẫu mỗi dòng: ranh giới vùng -> tiền trần (= đầu vùng
    /// tổng ở họ cùng-dòng) -> dòng cân -> dòng qty đi kèm món treo
    /// -> loại trừ nhãn -> tiền sạch cuối dòng -> tiền phẩy -> tiền
    /// vỡ (amount = nil) -> món treo (tên + mã dài, amount = nil).
    private static func extractSamelineItems(lines: [OCRLine], consumed: Set<Int>, stop: Int) -> [IndexedItem] {
        var out: [IndexedItem] = []
        var pendingHangPos: Int? = nil   // vị trí trong out của món treo chờ dòng qty
        var pendingWeight: (lb: Double, unit: Int?)? = nil
        var lastItemPos: Int? = nil

        func attachWeight(_ pos: Int, _ w: (lb: Double, unit: Int?)) {
            out[pos].item.weightLb = w.lb
            if let u = w.unit { out[pos].item.weightUnitCents = u }
        }

        let upperBound = min(stop, lines.count)
        for index in 0..<upperBound {
            if consumed.contains(index) { continue }
            let text = lines[index].text
            let upper = text.uppercased()
            // Nhãn SỐ MÓN không phải ranh giới vùng: Walmart in
            // '# ITEMS SOLD' ở ĐẦU bill (trước khối món), Pan-Asia
            // in 'Item Count:' ở cuối — cả hai chỉ là dòng bỏ qua.
            if findItemsSoldInLine(text) != nil || upper.hasPrefix("ITEM COUNT") { continue }
            // Dòng ngày (số hoặc tháng chữ) không bao giờ là món —
            // mẫu tiền-vỡ từng nuốt '20-May-2026 1:11:30P' thành món.
            if matchGroups(text, pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})"#) != nil
                || matchGroups(upper, pattern: #"\d{1,2}-(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)"#) != nil { continue }
            if upper.hasPrefix("SUBTOTAL") || upper.hasPrefix("TOTAL")
                || upper.hasPrefix("SALES TAX") || upper.hasPrefix("TAX") { break }
            if matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#) != nil {
                // Tiền trần chưa được khối dùng = đầu vùng tổng ở họ
                // cùng-dòng (Costco in '125.48' / '9.38' trần liên tiếp).
                break
            }
            if let w = weightLine(text) {
                let expected = w.unit.map { Int((w.lb * Double($0)).rounded()) }
                if let exp = expected, let lp = lastItemPos,
                   let amt = out[lp].item.amountCents, abs(exp - amt) <= 2,
                   out[lp].item.weightLb == nil {
                    // Kiểm chứng số học: W x U khớp tiền món NGAY
                    // TRƯỚC (họ in cân SAU nhãn — T-Johnnys) -> gắn về trước.
                    attachWeight(lp, w)
                } else {
                    // Mặc định: họ in cân TRƯỚC nhãn (Pan-Asia) ->
                    // chờ món tiếp theo. Liên kết cân là metadata,
                    // KHÔNG tham gia cổng sổ.
                    pendingWeight = w
                }
                continue
            }
            if let q = matchQtyLineGeneric(text) {
                if let hp = pendingHangPos {
                    out[hp].item.qty = q.qty
                    out[hp].item.unitPriceCents = q.unitCents
                    out[hp].item.amountCents = q.amountCents
                    if let f = q.flag { out[hp].item.taxFlag = f }
                    pendingHangPos = nil
                }
                continue
            }
            if samelineExcluded(upper: upper) { continue }
            // Cờ trái 1 chữ cái (Costco in cờ thực phẩm ở cột trái).
            var leftFlag: String? = nil
            var body = text
            if let fm = matchGroups(text, pattern: #"^([A-Z])\s+(?=\d{6,}\s)"#), let f = fm[0] {
                leftFlag = f
                body = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }

            var item: ParsedLineItem? = nil
            var isHang = false
            if let got = lastCleanMoney(body) {
                let name = got.name
                // Tên còn chứa một số thập phân khác -> dòng thuế/tỷ
                // lệ lọt lưới, không phải món.
                if !name.isEmpty,
                   hasAlphaToken(name) || matchGroups(name, pattern: #"\d{7,}"#) != nil,
                   matchGroups(name, pattern: #"\d+\.\d{2}"#) == nil {
                    var it = ParsedLineItem(name: name)
                    it.amountCents = got.cents
                    it.unitPriceCents = got.cents
                    if !got.tail.isEmpty, matchGroups(got.tail, pattern: #"^[A-Z]{1,2}$"#) != nil {
                        it.taxFlag = got.tail
                    }
                    item = it
                }
            }
            if item == nil, let got = lastCommaMoney(body) {
                let name = got.name
                if !name.isEmpty, hasAlphaToken(name),
                   matchGroups(name, pattern: #"\d+\.\d{2}"#) == nil {
                    var it = ParsedLineItem(name: name)
                    it.amountCents = got.cents
                    it.unitPriceCents = got.cents
                    if !got.tail.isEmpty, matchGroups(got.tail, pattern: #"^[A-Z]{1,2}$"#) != nil {
                        it.taxFlag = got.tail
                    }
                    item = it
                }
            }
            if item == nil, let broken = brokenMoneyName(body), !broken.isEmpty {
                item = ParsedLineItem(name: broken)   // amount = nil: không nặn số
            }
            if item == nil,
               matchGroups(body, pattern: #"(?<!\d)\d{9,}(?!\d)"#) != nil,
               matchGroups(body, pattern: #"[A-Za-z]{3,}"#) != nil {
                // Món treo: tên + mã dài nhưng tiền không nằm trên
                // dòng (Walmart in tiền ở dòng qty ngay sau, hoặc
                // tiền bị rơi).
                item = ParsedLineItem(name: body)
                isHang = true
            }
            guard var it = item else { continue }

            // Chuẩn hoá tên: dòng giảm giá Costco '<mã coupon> /
            // <mã món> ...' -> tên INST SV + mã đối ứng (số âm đã
            // nằm trong amount); số thứ tự quầy Clover (không phải
            // qty) chỉ tách khi dòng không chứa mã dài nào; mã dài
            // trong tên -> itemCode.
            var name = it.name
            if let im = matchGroups(name, pattern: #"^(\d{7,})\s*/\s*(\d{7,})"#), im.count == 2,
               (it.amountCents ?? 0) < 0 {
                it.name = "INST SV " + (im[1] ?? "")
                name = it.name
            } else if !name.uppercased().contains("INST SV") {
                if let sm = matchGroups(name, pattern: #"^(\d{1,2})\s+([A-Za-z].*)$"#), sm.count == 2,
                   matchGroups(body, pattern: #"(?<!\d)\d{7,}(?!\d)"#) == nil,
                   let cleaned = sm[1] {
                    it.name = cleaned
                    name = cleaned
                }
                if let cm = matchGroups(name, pattern: #"(?<!\d)\d{7,}(?!\d)"#), let code = cm[0] {
                    it.itemCode = code
                }
            }
            if it.taxFlag == nil, let lf = leftFlag { it.taxFlag = lf }
            out.append(IndexedItem(index: index, item: it))
            let pos = out.count - 1
            if isHang { pendingHangPos = pos }
            if let pw = pendingWeight {
                attachWeight(pos, pw)
                pendingWeight = nil
            }
            lastItemPos = pos
        }

        if let pw = pendingWeight, let lp = lastItemPos, out[lp].item.weightLb == nil {
            out[lp].item.weightLb = pw.lb
            if let u = pw.unit { out[lp].item.weightUnitCents = u }
        }
        return out
    }

    // MARK: - INTEGRATE-V2: dòng thuế mang suất + neo tổng bằng số học

    /// Dòng thuế mang SUẤT mà nhãn không bắt đầu bằng TAX:
    /// "<nhãn> <suất>% [một từ đệm] <tiền>" — "Coweta sales tax
    /// 10.05% $16.53", "F 4.0107% TAXÙ 1.16" (từ đệm chứa TAX),
    /// "Oklahoma Grocery 5.55% $1.33", "A 8.517% 8.22". Trả nhãn +
    /// suất + tiền + cờ "có chữ TAX" (ở nhãn hoặc ở từ đệm).
    private static func matchTaxRateLine(_ text: String) -> (label: String, rate: String, cents: Int, taxLabeled: Bool)? {
        guard let m = matchGroups(text, pattern: #"^(.+?)\s+([\d.]+)\s*%\s+(?:(\S+)\s+)?\$?(\d[\d,]*\.\d{2})(-)?$"#),
              m.count == 5, let label = m[0], let rate = m[1], let amountText = m[3] else { return nil }
        let taxLabeled = label.uppercased().contains("TAX")
            || (m[2]?.uppercased().contains("TAX") ?? false)
        return (label.trimmingCharacters(in: .whitespaces), rate,
                moneyToCents(amountText, negative: m[4] != nil), taxLabeled)
    }

    /// NEO TỔNG BẰNG SỐ HỌC khi nhãn tổng/thuế vỡ hoặc mất — theo
    /// tinh thần lớp Reconcile (thiết kế RECONCILE): số neo không
    /// bao giờ bị BỊA; hàm này chỉ gán VAI TRÒ cho những số ĐÃ IN
    /// trên bill, và chỉ khi vai trò đó được phương trình chứng
    /// minh DUY NHẤT. Chỉ điền trường còn TRỐNG (không bao giờ ghi
    /// đè số đã đọc theo nhãn), chỉ xét vùng tổng (các dòng sau
    /// dòng món cuối), bỏ qua dòng đã được vòng tổng chính nhận.
    /// Ba bước, theo thứ tự phụ thuộc:
    ///  1. SUBTOTAL: đúng một số tiền trần trong vùng tổng khớp
    ///     Σ món ±2 xu (hoặc khớp total - Σ thuế khi không có món).
    ///  2. TOTAL: ứng viên là số trên dòng thanh toán (TEND /
    ///     AMOUNT: / EFT / CARD SALE / PAYMENT) hoặc trên dòng chứa
    ///     TOTAL mà nhãn đã vỡ; nhận khi subtotal + Σ thuế khớp ±2,
    ///     hoặc thuế hàm ý (total - subtotal) nằm trong dải hợp lý
    ///     0–15% như kiểm tra hợp lý §5.3 của Reconcile — và đúng
    ///     MỘT giá trị ứng viên qua được. (Bẫy "TOTAL DEBIT
    ///     PURCHASE 92.24" gồm rút tiền mặt của L-R09 bị loại bởi
    ///     chính phương trình này.)
    ///  3. THUẾ còn thiếu: phần chênh total - subtotal - Σ thuế đã
    ///     có phải bằng đúng một dòng tiền đã in chưa ai nhận trong
    ///     vùng tổng — dòng đó được ghi là dòng thuế với vai trò đã
    ///     được phương trình chứng minh (không phải thuế suy diễn:
    ///     số tiền là số in nguyên văn, chỉ vai trò là được suy).
    private static func anchorTotals(result r: inout ParseResult, lines: [OCRLine],
                                     claimedIndices: Set<Int>,
                                     taxLineIndices: inout [Int],
                                     lastItemIndex: Int?) {
        let zoneStart = (lastItemIndex ?? -1) + 1
        guard zoneStart < lines.count else { return }
        var bareZone: [(index: Int, cents: Int)] = []
        var zoneAmounts: [(index: Int, cents: Int)] = []
        for i in zoneStart..<lines.count where !claimedIndices.contains(i) {
            let text = lines[i].text
            if let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#), m.count == 2 {
                let c = moneyToCents(m[0] ?? "", negative: m[1] != nil)
                bareZone.append((i, c))
                zoneAmounts.append((i, c))
            } else if let c = lastMoneyInLine(text) {
                zoneAmounts.append((i, c))
            }
        }
        // 1) SUBTOTAL
        if r.subtotalCents == nil, !r.items.isEmpty {
            let sum = r.items.reduce(0) { $0 + ($1.amountCents ?? 0) }
            let hits = Set(bareZone.filter { abs($0.cents - sum) <= 2 }.map { $0.cents })
            if hits.count == 1, let v = hits.first { r.subtotalCents = v }
        }
        if r.subtotalCents == nil, r.items.isEmpty, let total = r.totalCents, !r.taxes.isEmpty {
            let taxSum = r.taxTotalCents
            let hits = Set(bareZone.filter { abs($0.cents + taxSum - total) <= 2 }.map { $0.cents })
            if hits.count == 1, let v = hits.first { r.subtotalCents = v }
        }
        // 2) TOTAL
        if r.totalCents == nil, let s = r.subtotalCents {
            var candidates: [(index: Int, cents: Int)] = []
            for i in zoneStart..<lines.count where !claimedIndices.contains(i) {
                let text = lines[i].text
                let upper = text.uppercased()
                let isTend = upper.contains("TEND") || upper.contains("AMOUNT:")
                    || upper.hasPrefix("EFT") || upper.contains("CARD SALE")
                    || upper.hasPrefix("PAYMENT")
                let isDamagedTotal = upper.contains("TOTAL") && !upper.contains("SUBTOTAL")
                    && !upper.contains("TAX")
                if (isTend || isDamagedTotal), let c = lastMoneyInLine(text) {
                    candidates.append((i, c))
                }
            }
            let taxSum = r.taxTotalCents
            let passing = Set(candidates.filter { cand in
                if !r.taxes.isEmpty && abs(s + taxSum - cand.cents) <= 2 { return true }
                let implied = cand.cents - s
                return s > 0 && implied >= 0 && implied * 100 <= 15 * s
            }.map { $0.cents })
            if passing.count == 1, let v = passing.first,
               let src = candidates.first(where: { $0.cents == v }) {
                r.totalCents = v
                r.totalConfidence = lines[src.index].confidence
            }
        }
        // 3) THUẾ còn thiếu
        if let s = r.subtotalCents, let total = r.totalCents {
            let missing = total - s - r.taxTotalCents
            if missing > 0 {
                let hits = zoneAmounts.filter { abs($0.cents - missing) <= 2 }
                let distinct = Set(hits.map { $0.cents })
                if distinct.count == 1, let hit = hits.first {
                    r.taxes.append(ParsedTaxLine(label: "TAX", rateText: nil, amountCents: hit.cents))
                    taxLineIndices.append(hit.index)
                    // Thuế giữ thứ tự in trên bill: sắp lại theo
                    // chỉ số dòng nguồn.
                    let paired = zip(r.taxes, taxLineIndices).sorted { $0.1 < $1.1 }
                    r.taxes = paired.map { $0.0 }
                    taxLineIndices = paired.map { $0.1 }
                }
            }
        }
    }

    // MARK: - INTEGRATE-V2: ngày tháng chữ + giờ đứng riêng dòng

    private static let monthNames: [String: Int] = [
        "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
        "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
    ]

    private static func monthNumber(_ s: String?) -> Int? {
        guard let s = s else { return nil }
        return monthNames[s.uppercased()]
    }

    /// Dòng CHỈ có giờ ("14:09:42", "3:08 PM") — dùng để ghép vào
    /// ngày-không-giờ khi OCR tách ngày và giờ thành hai dòng rời.
    private static func findStandaloneTime(in lines: [OCRLine]) -> (hour: Int, minute: Int, confidence: Double)? {
        for line in lines {
            if let m = matchGroups(line.text, pattern: #"^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)?$"#), m.count == 3 {
                var hour = Int(m[0] ?? "") ?? 0
                if let ampm = m[2]?.uppercased() {
                    if ampm == "PM" && hour < 12 { hour += 12 }
                    if ampm == "AM" && hour == 12 { hour = 0 }
                }
                return (hour, Int(m[1] ?? "") ?? 0, line.confidence)
            }
        }
        return nil
    }

    private static func mergingTime(into date: Date, hour: Int, minute: Int) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)
    }

    // MARK: - WP5: Nhận diện tiệm 3 nấc (WP5-SPEC mục 3–5)
    //
    // Bản Swift của wp5-fixtures/vendor_port.py (port đã kiểm chứng
    // 19/19 ở bước 1 — sửa hành vi thì sửa port + fixture TRƯỚC, không
    // sửa một phía). Tên tiệm chỉ đến từ bằng chứng: nấc 1 khớp tên
    // toàn-bộ-dòng (exact trước, mờ sau) hoặc nấc 2 neo phụ của tiệm
    // đã biết; nấc 3 món đặc trưng CHỈ gợi ý (bảng seed RỖNG). Ngoài
    // hai nấc đầu, tên tiệm để TRỐNG — không còn đường rơi dòng-đầu.

    struct VendorIdentification {
        var vendor: String? = nil
        var vendorKey: String = "generic"
        var confidence: Double = 0
        var source: String? = nil   // "tier1-exact" | "tier1-fuzzy" | "tier2-anchor"
        var suggestion: String? = nil
        var anchorDisputed: Bool = false
    }

    /// Danh sách tiệm đã biết — đúng seed Build 1 + Sam's, tên chuẩn
    /// theo vendor_port.py (needle đã chuẩn hoá: apostrophe -> khoảng
    /// trắng, vd "SAM S CLUB").
    private static let knownVendors: [(name: String, needles: [String], key: String)] = [
        ("Sam's Club", ["SAM S CLUB", "SAMS CLUB"], "sams"),
        ("Walmart", ["WALMART"], "generic"),
        ("Costco", ["COSTCO"], "generic"),
        ("The Home Depot", ["HOME DEPOT", "THE HOME DEPOT"], "generic"),
        ("Lowe's", ["LOWE S", "LOWES"], "generic"),
        ("Target", ["TARGET"], "generic"),
        ("QuikTrip", ["QUIKTRIP", "QUIK TRIP"], "generic"),
        ("Casey's", ["CASEY S", "CASEYS"], "generic"),
        ("Love's", ["LOVE S", "LOVES"], "generic")
    ]

    /// Token thuộc diện chỉ-khớp-đúng, cấm khớp-mờ (từ ngắn/phổ thông —
    /// chống dương tính giả kiểu "TARGETED" thành Target).
    private static let exactTokenOnly: Set<String> = ["TARGET", "LOWES", "LOWE"]

    /// Neo phụ (nấc 2) — seed CHỈ gồm neo có bằng chứng trong bộ mẫu
    /// đóng băng (WP5-SPEC mục 4): (tiệm, key, loại neo, giá trị đã
    /// chuẩn hoá). Cấm chép địa chỉ chuỗi tiệm từ internet vào đây.
    private static let vendorAnchors: [(vendor: String, key: String, kind: String, value: String)] = [
        ("The Home Depot", "generic", "street", "9808 E 71ST ST"),
        ("The Home Depot", "generic", "zip", "74133"),
        ("Sam's Club", "sams", "phone", "9182529503"),
        // M1-FIX: neo cụm chữ (phrase) — slogan in ngay dưới logo
        // Home Depot; bằng chứng trong bộ mẫu đóng băng: 2 dòng đầu
        // của luồng 003 thật. Khớp trên toàn văn đã chuẩn hoá nối
        // liền vì OCR xé slogan thành 2 dòng ("How doers" /
        // "get more done") — neo theo dòng đơn không bao giờ khớp.
        ("The Home Depot", "generic", "phrase", "HOW DOERS GET MORE DONE")
    ]

    /// Món đặc trưng (nấc 3) — bảng seed RỖNG: chưa mẫu đóng băng nào
    /// khoá được một món là đặc trưng của một tiệm (WP5-SPEC mục 5).
    private static let signatureItems: [String: String] = [:]

    private static func identifyVendor(lines: [OCRLine]) -> VendorIdentification {
        var result = VendorIdentification()

        // NẤC 1 — quét TOÀN BỘ dòng (bỏ prefix(6) của Build 1);
        // khớp-đúng ở BẤT KỲ dòng nào thắng khớp-mờ ở dòng sớm hơn;
        // cùng hạng thì dòng sớm hơn thắng.
        var best: (rank: Int, lineIndex: Int, vendor: String, key: String, confidence: Double, kind: String)? = nil
        for (index, line) in lines.enumerated() {
            let normalized = normalizeForVendorMatch(line.text)
            for kv in knownVendors {
                for needle in kv.needles {
                    guard let kind = vendorLineMatch(normalizedLine: normalized, needle: needle) else { continue }
                    let rank = kind == "exact" ? 2 : 1
                    if let b = best, rank < b.rank || (rank == b.rank && index >= b.lineIndex) { continue }
                    best = (rank, index, kv.name, kv.key, line.confidence, kind)
                }
            }
        }
        if let b = best {
            result.vendor = b.vendor
            result.vendorKey = b.key
            if b.kind == "exact" {
                result.source = "tier1-exact"
                result.confidence = b.confidence
            } else {
                result.source = "tier1-fuzzy"
                result.confidence = b.confidence * 0.8
            }
            return result
        }

        // NẤC 2 — neo phụ: ≥1 neo MẠNH (street/phone) hoặc ≥2 neo YẾU
        // khác loại của CÙNG tiệm (ZIP đơn độc là yếu — không đủ). Hai
        // tiệm khác nhau cùng khớp neo -> tranh chấp, KHÔNG điền.
        let hits = anchorHits(lines: lines)
        if hits.count == 1, let only = hits.first {
            result.vendor = only.vendor
            result.vendorKey = only.key
            result.source = "tier2-anchor"
            result.confidence = 0.5   // neo không phải tên in trên giấy: giới hạn 0.5
            return result
        }
        if hits.count > 1 {
            result.anchorDisputed = true
        }

        // NẤC 3 — món đặc trưng: CHỈ gợi ý, vendor vẫn để trống.
        if !signatureItems.isEmpty {
            let joined = lines.map { normalizeForVendorMatch($0.text) }.joined(separator: " ")
            for (token, vendor) in signatureItems where joined.contains(token) {
                result.suggestion = vendor
                break
            }
        }
        return result
    }

    /// Các tiệm đủ điều kiện neo: (tiệm, key). Điều kiện: có neo mạnh
    /// hoặc ≥2 loại neo yếu khác nhau của cùng tiệm.
    private static func anchorHits(lines: [OCRLine]) -> [(vendor: String, key: String)] {
        var kindsByVendor: [String: Set<String>] = [:]
        var keyByVendor: [String: String] = [:]
        // M1-FIX: neo cụm chữ khớp trên toàn văn nối liền (slogan bị
        // OCR xé nhiều dòng) — tính một lần trước vòng lặp.
        let joinedNormalized = lines.map { normalizeForVendorMatch($0.text) }.joined(separator: " ")
        for line in lines {
            let normalized = normalizeForVendorMatch(line.text)
            let tokens = normalized.split(separator: " ").map(String.init)
            let digits = line.text.filter { $0.isASCII && $0.isNumber }
            for anchor in vendorAnchors {
                let ok: Bool
                switch anchor.kind {
                case "street": ok = normalized.contains(anchor.value)
                case "phone": ok = digits.contains(anchor.value)
                case "zip": ok = tokens.contains(anchor.value)
                case "phrase": ok = joinedNormalized.contains(anchor.value)
                default: ok = false
                }
                if ok {
                    kindsByVendor[anchor.vendor, default: []].insert(anchor.kind)
                    keyByVendor[anchor.vendor] = anchor.key
                }
            }
        }
        let strongKinds: Set<String> = ["street", "phone", "phrase"]
        var qualifying: [(vendor: String, key: String)] = []
        for (vendor, kinds) in kindsByVendor {
            if !kinds.isDisjoint(with: strongKinds) || kinds.count >= 2 {
                qualifying.append((vendor, keyByVendor[vendor] ?? "generic"))
            }
        }
        return qualifying
    }

    /// Chuẩn hoá để khớp tiệm (bản Swift của normalize() trong port):
    /// thống nhất apostrophe cong/thẳng, bỏ dấu tiếng Việt, viết hoa,
    /// ký tự không phải A-Z/0-9 thành khoảng trắng, gọn khoảng trắng.
    private static func normalizeForVendorMatch(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\u{2019}", with: "'")
        t = t.replacingOccurrences(of: "\u{2018}", with: "'")
        t = t.replacingOccurrences(of: "\u{02BC}", with: "'")
        t = t.folding(options: [.diacriticInsensitive], locale: nil).uppercased()
        var out = ""
        for scalar in t.unicodeScalars {
            if (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 48 && scalar.value <= 57) {
                out.append(Character(scalar))
            } else {
                out.append(" ")
            }
        }
        return out.split(separator: " ").joined(separator: " ")
    }

    /// Một dòng đã chuẩn hoá khớp một needle: "exact" khi needle xuất
    /// hiện nguyên vẹn theo ranh giới token; "fuzzy" khi MỌI token của
    /// needle có một token trong dòng khớp (đúng hoặc mờ-1-ký-tự) và ít
    /// nhất một token là khớp-mờ thật; nil nếu không khớp.
    private static func vendorLineMatch(normalizedLine: String, needle: String) -> String? {
        let lineTokens = normalizedLine.split(separator: " ").map(String.init)
        let needleTokens = needle.split(separator: " ").map(String.init)
        guard !needleTokens.isEmpty, !lineTokens.isEmpty else { return nil }
        if lineTokens.count >= needleTokens.count {
            for i in 0...(lineTokens.count - needleTokens.count) {
                if Array(lineTokens[i..<(i + needleTokens.count)]) == needleTokens {
                    return "exact"
                }
            }
        }
        var usedFuzzy = false
        for nt in needleTokens {
            var hit: String? = nil
            for lt in lineTokens {
                if lt == nt { hit = "exact"; break }
                if tokenFuzzyEqual(lineToken: lt, needleToken: nt) { hit = "fuzzy" }
            }
            guard let h = hit else { return nil }
            if h == "fuzzy" { usedFuzzy = true }
        }
        return usedFuzzy ? "fuzzy" : nil
    }

    /// 1 token khớp-mờ: bằng nhau, hoặc cả hai dài ≥5 và Levenshtein ≤1.
    /// Token thuộc exactTokenOnly chỉ khớp khi bằng nhau.
    private static func tokenFuzzyEqual(lineToken: String, needleToken: String) -> Bool {
        if lineToken == needleToken { return true }
        if exactTokenOnly.contains(needleToken) { return false }
        guard lineToken.count >= 5, needleToken.count >= 5 else { return false }
        return levenshtein(lineToken, needleToken) <= 1
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a), bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }
        var prev = Array(0...bChars.count)
        for i in 1...aChars.count {
            var cur = [i]
            for j in 1...bChars.count {
                cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (aChars[i - 1] == bChars[j - 1] ? 0 : 1)))
            }
            prev = cur
        }
        return prev[bChars.count]
    }

    // MARK: - WP5: Trích địa chỉ / điện thoại / mã cửa hàng (hạ cánh WP2)
    //
    // Chỉ trích NGUYÊN VĂN dòng thấy được trên hoá đơn, không ghép/suy
    // địa chỉ từ nhiều dòng rời (WP5-SPEC mục 4). Mẫu regex chốt ở đây
    // kèm bản port kiểm chứng wp5-fixtures/extract_port.py.

    private static func extractVendorContact(lines: [OCRLine]) -> (address: String?, phone: String?, storeNumber: String?) {
        var address: String? = nil
        var phone: String? = nil
        var storeNumber: String? = nil
        for line in lines {
            let text = line.text
            // Địa chỉ: dòng bắt đầu bằng số nhà + tên đường + hậu tố
            // đường (ST/AVE/BLVD...). Lấy nguyên văn dòng đầu tiên khớp.
            if address == nil,
               matchGroups(text.uppercased(), pattern: #"^\d{1,6}\s+[A-Z0-9 .'\-]+\s+(ST|STREET|AVE|AVENUE|BLVD|RD|ROAD|DR|DRIVE|LN|LANE|HWY|HIGHWAY|CT|COURT|WAY|CIR|CIRCLE|PL|PLACE|TER|TERRACE|TRL|TRAIL)\b"#) != nil {
                address = text
            }
            // Điện thoại 10 số có định dạng (dấu - . khoảng trắng hoặc
            // ngoặc mã vùng), hai đầu không dính số khác — tránh vớ
            // phải dãy số hoá đơn/TC#.
            if phone == nil,
               let m = matchGroups(text, pattern: #"(?<!\d)(\(?\d{3}\)?[-. ]\d{3}[-. ]\d{4})(?!\d)"#),
               let found = m.first ?? nil {
                phone = found
            }
            // Mã cửa hàng: "STORE #1234" / "ST# 1234" / "CLUB #1234".
            if storeNumber == nil,
               let m = matchGroups(text, pattern: #"\b(?:STORE|ST|CLUB)\s*#\s*(\d{3,6})\b"#),
               let found = m.first ?? nil {
                storeNumber = found
            }
        }
        return (address, phone, storeNumber)
    }

    // MARK: - Thẻ: CHỈ từ dòng có ký tự che (luật toàn cục số 2)

    private static func findCard(lines: [OCRLine]) -> (last4: String?, brand: String?) {
        var last4: String? = nil
        for line in lines {
            let text = line.text
            if let m = matchGroups(text, pattern: #"\*{4}\s+\*{4}\s+\*{4}\s+(\d{4})"#) {
                last4 = m[0]
                break
            }
            if let m = matchGroups(text, pattern: #"\*{3,}\s*(\d{4})"#) {
                last4 = m[0]
                break
            }
            if let m = matchGroups(text, pattern: #"X{3,}\s*(\d{4})"#) {
                last4 = m[0]
                break
            }
        }
        guard last4 != nil else { return (nil, nil) }
        // Brand: dòng chứa tên hãng thẻ (kèm "Debit" nếu in cùng dòng).
        let brands = ["MASTERCARD", "MASTER CARD", "VISA", "AMEX", "AMERICAN EXPRESS", "DISCOVER"]
        var brand: String? = nil
        for line in lines {
            let upper = line.text.uppercased()
            for b in brands where upper.contains(b) {
                var name = b == "MASTER CARD" ? "Mastercard" : b.capitalized
                if b == "AMEX" { name = "Amex" }
                if b == "AMERICAN EXPRESS" { name = "Amex" }
                if upper.contains("DEBIT") { name += " Debit" }
                brand = name
                break
            }
            if brand != nil { break }
        }
        return (last4, brand)
    }

    // MARK: - Ngày giờ

    private static func findDateTime(in lines: [OCRLine]) -> (date: Date, confidence: Double)? {
        for line in lines {
            if let m = matchGroups(line.text, pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})\s+(\d{1,2}):(\d{2})\s*([AP]M)?"#), m.count == 6 {
                // Xử lý AM/PM: "5:49 PM" phải thành 17:49, kẻo giờ bị lệch 12 tiếng.
                var hour = Int(m[3] ?? "") ?? 0
                if let ampm = m[5]?.uppercased() {
                    if ampm == "PM" && hour < 12 { hour += 12 }
                    if ampm == "AM" && hour == 12 { hour = 0 }
                }
                if let d = makeDate(month: Int(m[0] ?? ""), day: Int(m[1] ?? ""), year: Int(m[2] ?? ""),
                                    hour: hour, minute: Int(m[4] ?? "") ?? 0) {
                    return (d, line.confidence)
                }
            }
            // INTEGRATE-V2: ngày tháng CHỮ kiểu Clover —
            // "20-May-2026 1:11:30P": hậu tố AM/PM một chữ cái dính
            // ngay sau giây (có thể có khoảng trắng + chữ M).
            if let m = matchGroups(line.text, pattern: #"(\d{1,2})-([A-Za-z]{3})-(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AP])M?"#), m.count == 7,
               let month = monthNumber(m[1]) {
                var hour = Int(m[3] ?? "") ?? 0
                let ampm = m[6]?.uppercased()
                if ampm == "P" && hour < 12 { hour += 12 }
                if ampm == "A" && hour == 12 { hour = 0 }
                if let d = makeDate(month: month, day: Int(m[0] ?? ""), year: Int(m[2] ?? ""),
                                    hour: hour, minute: Int(m[4] ?? "") ?? 0) {
                    return (d, line.confidence)
                }
            }
        }
        return nil
    }

    private static func findDateOnly(in lines: [OCRLine]) -> (date: Date, confidence: Double)? {
        for line in lines {
            if let m = matchGroups(line.text, pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})"#), m.count == 3 {
                if let d = makeDate(month: Int(m[0] ?? ""), day: Int(m[1] ?? ""), year: Int(m[2] ?? "")) {
                    return (d, line.confidence)
                }
            }
            if let m = matchGroups(line.text, pattern: #"(\d{4})-(\d{2})-(\d{2})"#), m.count == 3 {
                // yyyy-MM-dd
                var comps = DateComponents()
                comps.year = Int(m[0] ?? "")
                comps.month = Int(m[1] ?? "")
                comps.day = Int(m[2] ?? "")
                if let d = Calendar.current.date(from: comps) {
                    return (d, line.confidence)
                }
            }
            // INTEGRATE-V2: ngày tháng chữ không kèm giờ
            // ("20-May-2026" đứng một mình).
            if let m = matchGroups(line.text, pattern: #"(\d{1,2})-([A-Za-z]{3})-(\d{2,4})"#), m.count == 3,
               let month = monthNumber(m[1]) {
                if let d = makeDate(month: month, day: Int(m[0] ?? ""), year: Int(m[2] ?? "")) {
                    return (d, line.confidence)
                }
            }
        }
        return nil
    }

    private static func makeDate(month: Int?, day: Int?, year: Int?, hour: Int = 0, minute: Int = 0) -> Date? {
        guard let month = month, let day = day, var year = year else { return nil }
        if year < 100 { year += 2000 }
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)
    }

    // MARK: - Đối chiếu chéo (luật toàn cục số 1 — chỉ gắn cờ, không sửa số)

    private static func validate(_ r: ParseResult) -> [String] {
        var warnings: [String] = []
        if r.totalCents == nil {
            warnings.append("Không đọc được TỔNG TIỀN — anh nhập tay giúp.")
        }
        if r.date == nil {
            warnings.append("Không đọc được ngày — anh chọn ngày giúp.")
        }
        if !r.items.isEmpty, let subtotal = r.subtotalCents {
            let sum = r.items.reduce(0) { $0 + ($1.amountCents ?? 0) }
            if abs(sum - subtotal) > 2 {
                warnings.append("Đối chiếu: tổng các món (\(formatMoney(cents: sum))) khác subtotal (\(formatMoney(cents: subtotal))) — có thể đọc sót hoặc sai món.")
            }
        }
        if let subtotal = r.subtotalCents, let total = r.totalCents {
            if abs(subtotal + r.taxTotalCents - total) > 2 {
                warnings.append("Đối chiếu: subtotal + thuế (\(formatMoney(cents: subtotal + r.taxTotalCents))) khác tổng tiền (\(formatMoney(cents: total))).")
            }
        }
        if let sold = r.itemsSold {
            let qtySum = r.items.filter { ($0.amountCents ?? 0) > 0 }.reduce(0) { $0 + $1.qty }
            if qtySum != sold {
                warnings.append("Số lượng: đọc được \(qtySum) món, hoá đơn ghi \(sold) món.")
            }
        }
        if r.totalCents != nil {
            if r.totalConfidence > 0 && r.totalConfidence < 0.60 {
                warnings.append("Tổng tiền độ tin cậy THẤP — bắt buộc kiểm tra lại với giấy.")
            } else if r.totalConfidence >= 0.60 && r.totalConfidence < 0.85 {
                warnings.append("Tổng tiền chưa thật chắc — anh kiểm tra giúp.")
            }
        }
        // WP5 — kỷ luật C-11 mở rộng cho TIỆM và NGÀY (WP5-SPEC mục 6):
        // cùng mẫu ngưỡng 0.60/0.85 với total ở trên (ngưỡng khởi điểm,
        // chưa hiệu chuẩn trên corpus — hiệu chuẩn thuộc bài chấm M1).
        // Phần số học của validate() ở trên giữ NGUYÊN VĂN. Cảnh báo
        // mới đi qua warnings -> ReviewView.save() ép Hộp Chờ như cũ.
        if r.vendor == nil {
            if let suggestion = r.vendorSuggestion {
                warnings.append("Chưa rõ tiệm — gợi ý từ món đặc trưng: \(suggestion) (chưa tự điền).")
            } else {
                warnings.append("Không đọc được tên tiệm — anh nhập tay giúp.")
            }
        } else {
            if r.vendorSource == "tier1-fuzzy" {
                warnings.append("Tên tiệm khớp mờ — anh kiểm tra giúp.")
            }
            if r.vendorSource == "tier2-anchor" {
                warnings.append("Tên tiệm nhận qua địa chỉ/số điện thoại — anh kiểm tra giúp.")
            }
            if r.vendorConfidence > 0 && r.vendorConfidence < 0.60 {
                warnings.append("Tên tiệm độ tin cậy THẤP — bắt buộc kiểm tra lại với giấy.")
            } else if r.vendorConfidence >= 0.60 && r.vendorConfidence < 0.85 {
                warnings.append("Tên tiệm chưa thật chắc — anh kiểm tra giúp.")
            }
        }
        if r.vendorAnchorDisputed {
            warnings.append("Nhiều tiệm cùng khớp neo phụ — không tự điền tên tiệm.")
        }
        if r.date != nil {
            if r.dateConfidence > 0 && r.dateConfidence < 0.60 {
                warnings.append("Ngày độ tin cậy THẤP — bắt buộc kiểm tra lại với giấy.")
            } else if r.dateConfidence >= 0.60 && r.dateConfidence < 0.85 {
                warnings.append("Ngày chưa thật chắc — anh kiểm tra giúp.")
            }
        }
        return warnings
    }

    // MARK: - Tiện ích regex / tiền

    /// Số tiền ở CUỐI một phần chữ: "POM TISSUE 2.00-T" -> (name: "POM TISSUE", -200, flag "T")
    private static func trailingAmount(in text: String) -> (name: String, cents: Int, flag: String?)? {
        guard let ns = matchWithRange(text, pattern: #"\s(\d[\d,]*\.\d{2})(-)?\s*([YT])?$"#) else { return nil }
        let name = String(text[..<ns.nameEnd])
        let cents = moneyToCents(ns.groups[0] ?? "", negative: ns.groups[1] != nil)
        return (name.trimmingCharacters(in: .whitespaces), cents, ns.groups[2])
    }

    private static func matchQtyLine(_ text: String) -> (qty: Int, unitCents: Int, amountCents: Int, flag: String?)? {
        guard let m = matchGroups(text, pattern: #"^(\d+)\s+AT\s+1\s+FOR\s+(\d[\d,]*\.\d{2})(-)?\s+(\d[\d,]*\.\d{2})(-)?\s*([YT])?$"#),
              m.count == 6, let qty = Int(m[0] ?? "") else { return nil }
        let unit = moneyToCents(m[1] ?? "", negative: m[2] != nil)
        let amount = moneyToCents(m[3] ?? "", negative: m[4] != nil)
        return (qty, unit, amount, m[5])
    }

    /// Số tiền cuối cùng xuất hiện trong dòng (cho dòng thuế generic: "TAX 1 8.517% 9.60").
    private static func lastMoneyInLine(_ text: String) -> Int? {
        guard let re = regex(#"(\d[\d,]*\.\d{2})(-)?"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = re.matches(in: text, options: [], range: range)
        guard let last = matches.last, last.numberOfRanges >= 2,
              let r1 = Range(last.range(at: 1), in: text) else { return nil }
        let negative = last.numberOfRanges >= 3 && last.range(at: 2).location != NSNotFound
        return moneyToCents(String(text[r1]), negative: negative)
    }

    /// "203.30" -> 20330 ; "-" ở cuối (kiểu Sam's in giảm giá) -> âm.
    private static func moneyToCents(_ s: String, negative: Bool) -> Int {
        let clean = s.replacingOccurrences(of: ",", with: "")
        let parts = clean.split(separator: ".")
        guard parts.count == 2, let dollars = Int(parts[0]), let cents = Int(parts[1]) else { return 0 }
        let value = dollars * 100 + cents
        return negative ? -value : value
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// Nhóm bắt được (nil cho nhóm không tham gia). nil nếu không khớp.
    private static func matchGroups(_ text: String, pattern: String) -> [String?]? {
        guard let re = regex(pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String?] = []
        for i in 1..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location == NSNotFound {
                groups.append(nil)
            } else if let sr = Range(r, in: text) {
                groups.append(String(text[sr]))
            } else {
                groups.append(nil)
            }
        }
        return groups
    }

    /// Nhóm bắt đầu tiên — dùng khi cần tiền tố sau pattern (vd "INST SV ...").
    private static func matchPrefix(_ text: String, pattern: String) -> String? {
        guard let groups = matchGroups(text, pattern: pattern), let first = groups.first else { return nil }
        return first
    }

    /// Như matchGroups nhưng thêm vị trí kết thúc của phần TRƯỚC số tiền (để cắt tên món).
    private static func matchWithRange(_ text: String, pattern: String) -> (groups: [String?], nameEnd: String.Index)? {
        guard let re = regex(pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range),
              let whole = Range(match.range, in: text) else { return nil }
        var groups: [String?] = []
        for i in 1..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location == NSNotFound {
                groups.append(nil)
            } else if let sr = Range(r, in: text) {
                groups.append(String(text[sr]))
            } else {
                groups.append(nil)
            }
        }
        return (groups, whole.lowerBound)
    }
}

// MARK: - ════════════════════════════════════════════════════════════
// MARK: P2-3 — Lớp TRỌNG TÀI SỐ HỌC (Reconcile)
//
// Phần này CỘNG THÊM THUẦN vào cuối file: không một hàm nào ở trên bị
// sửa. parse()/validate() giữ nguyên 100% — luật toàn cục số 1 ("chỉ
// gắn cờ, TUYỆT ĐỐI không tự sửa số") vẫn là luật của parse().
//
// Lớp trọng tài là một tầng RIÊNG chạy SAU parse (điểm vào:
// ReceiptParser.reconcile / parseAndReconcile), port trung thực từ
// mirror đã kiểm chứng core-redo/reconcile.py (13/13 ca — xem
// core-redo/RECONCILE-DESIGN.md và core-redo/case-results.txt).
// Tư tưởng: hoá đơn tự mang số kiểm tra (subtotal / thuế / total /
// # ITEMS SOLD). Lớp này dùng chúng làm ĐÍCH để truy vết và sửa CÓ
// MỤC TIÊU, với ranh giới trung thực cứng (R1–R7 của thiết kế):
//   - Số neo KHÔNG BAO GIỜ bị sửa; neo mâu thuẫn -> ANCHOR_CONFLICT.
//   - Chỉ ÁP DỤNG sửa khi nghiệm khớp từng xu là DUY NHẤT ở mức sửa
//     tối thiểu VÀ mọi sửa đều có bằng chứng tại chỗ trên dòng (kênh
//     FORCE/TOKEN/ORPHAN). Nghiệm thuần số học (DIGIT/SIGN/DEFICIT)
//     chỉ thành GỢI Ý trình anh ở Review — khớp tổng là điều kiện
//     cần, không bao giờ là điều kiện đủ (ca bẫy C6).
//   - Mất hẳn dòng -> KHÔNG bịa món; chỉ báo thiếu + khoanh vùng
//     đọc lại. Mất subtotal/thuế còn total (dạng thực địa 16:50) ->
//     TOTAL_ONLY: TUYỆT ĐỐI không suy ngược số từ total.
//   - Mọi giá trị bị can thiệp đều được ghi trong ReconcileReport
//     (kênh + giá trị gốc) để tầng lưu/Hiển thị gắn cờ "suy luận" —
//     ParsedLineItem và model SwiftData KHÔNG đổi ở gói này.
//   - Mọi trạng thái khác OK đều requiresReview = true -> tầng lưu
//     giữ Receipt.status = .needsReview (Hộp Chờ Duyệt hiện có).

import CoreGraphics

// MARK: P2-3 — Kiểu dữ liệu của lớp trọng tài

/// Trạng thái kết luận của một lượt đối chiếu (khớp mirror).
enum ReconcileStatus: String {
    case ok = "OK"
    case repaired = "REPAIRED"
    case suggestionOnly = "SUGGESTION_ONLY"
    case ambiguous = "AMBIGUOUS"
    case noSolution = "NO_SOLUTION"
    case anchorConflict = "ANCHOR_CONFLICT"
    case totalOnly = "TOTAL_ONLY"
    case noAnchor = "NO_ANCHOR"
    case partial = "PARTIAL"
    case tooComplex = "TOO_COMPLEX"
}

/// Kênh sinh ứng viên sửa. Tier càng thấp bằng chứng càng "tại chỗ".
enum ReconcileChannel: String {
    case force = "FORCE"     // bộ ba qty×unit=amount của chính món tự mâu thuẫn
    case token = "TOKEN"     // token tiền đọc-bao-dung nằm trong cửa sổ dòng của món
    case orphan = "ORPHAN"   // dòng mã món có trong luồng thô nhưng parser đánh rơi
    case digit = "DIGIT"     // biến thể 1 chữ số theo cặp nhầm OCR — thuần số học
    case sign = "SIGN"       // mất dấu trừ — thuần số học
    case deficit = "DEFICIT" // gán đúng phần thiếu cho món duy nhất chưa có tiền

    var tier: Int {
        switch self {
        case .force: return 1
        case .token, .orphan: return 2
        case .digit, .sign: return 3
        case .deficit: return 4
        }
    }

    /// Kênh có bằng chứng tại chỗ trên dòng — điều kiện để được ÁP DỤNG.
    var isSiteEvidenced: Bool {
        self == .force || self == .token || self == .orphan
    }
}

/// Một sửa (đã áp dụng) hoặc một ứng viên trong tổ hợp gợi ý.
/// Với field == .insert (kênh ORPHAN): itemIndex là vị trí món chèn
/// trong mảng items của kết quả ĐÃ sửa (= số món gốc + thứ tự slot).
struct ReconcileFix {
    enum Field: String {
        case amount, qty, unit, insert
    }
    var itemIndex: Int
    var field: Field
    var oldValue: Int?
    var newValue: Int
    var delta: Int
    var channel: ReconcileChannel
    var tier: Int
    // Payload riêng cho .insert (ORPHAN) — nil ở mọi field khác.
    var insertName: String? = nil
    var insertQty: Int? = nil
    var insertUnitCents: Int? = nil
    var insertCode: String? = nil
    /// Vết bằng chứng tại chỗ, vd "line 4: 19.4B" (TOKEN/ORPHAN).
    var evidence: String? = nil
}

/// Yêu cầu khoanh vùng đọc lại có mục tiêu — phát cho tầng OCR
/// (P2-1/P2-2 thực thi qua ReOCRService). `band` là dải chuẩn hoá
/// (gốc dưới-trái như Vision) tính từ hộp dòng khi caller cấp
/// lineBoxes; chưa có hình học thì band = nil và `block` + `lineRange`
/// là neo định vị. `priority` tăng theo thứ tự phát (1 = trước nhất).
struct ReconcileRegionHint {
    enum Block: String {
        case items = "items-block"
        case totals = "totals-block"
    }
    enum Reason: String {
        case missingOrUnrepairable = "missing-or-unrepairable"
        case qtyMismatch = "qty-mismatch"
        case anchorConflict = "anchor-conflict"
        case totalOnlyAnchor = "total-only-anchor"
    }
    var block: Block
    var reason: Reason
    var priority: Int = 0
    /// Phần tiền còn thiếu (xu) — chỉ có ở .missingOrUnrepairable.
    var deltaCents: Int? = nil
    var lineRange: ClosedRange<Int>? = nil
    var band: CGRect? = nil
}

/// Báo cáo một lượt đối chiếu. `fixes` là các sửa ĐÃ ÁP DỤNG vào kết
/// quả trả kèm (mang kênh + giá trị gốc = vết kiểm toán; đây cũng là
/// nguồn gắn cờ "suy luận" cho tầng lưu — xem AFTER.md của gói P2-3).
/// `suggestions` là các tổ hợp KHÔNG áp dụng, trình anh ở Review.
struct ReconcileReport {
    var status: ReconcileStatus = .partial // sentinel — mọi đường ra đều gán lại
    var moneyDeltaCents: Int? = nil
    var qtyDelta: Int? = nil
    var fixes: [ReconcileFix] = []
    var suggestions: [[ReconcileFix]] = []
    var solutionCount: Int = 0
    var regionHints: [ReconcileRegionHint] = []
    var notes: [String] = []
    var nodesVisited: Int = 0
    var taxMissing: Bool = false
    /// Thuế hàm ý (total − subtotal) — CHỈ để kiểm tra hợp lý, không
    /// bao giờ được ghi thành dòng thuế (thiết kế §5.3).
    var impliedTaxCents: Int? = nil
    var anchorsPresent: [String] = []
    var anchorsMissing: [String] = []
    var requiresReview: Bool = false

    /// Sửa đã áp dụng cho món ở vị trí `index` trong kết quả đã sửa.
    func appliedFix(forItemAt index: Int) -> ReconcileFix? {
        fixes.first { $0.itemIndex == index }
    }
}

/// Giao diện đọc-lại-có-mục-tiêu (thiết kế §6). Gói P2-3 chỉ ĐỊNH
/// NGHĨA giao diện + phát ReconcileRegionHint; bản thực thi (ROI /
/// cắt vùng phóng to) thuộc P2-1/P2-2 và phải đo trên máy thật.
protocol ReOCRService {
    func recognizeRegion(_ hint: ReconcileRegionHint, upscale: Double) -> [OCRLine]
}

// MARK: P2-3 — Hằng số (lấy đúng giá trị của mirror)

enum ReconcileConstants {
    static let maxEdits = 3            // ngân sách sửa cho 1 lượt đối chiếu tiền
    static let maxQtyEdits = 2         // ngân sách sửa cho lượt đối chiếu số lượng
    static let nodeCap = 100_000       // ngân sách nút DFS — vượt = TOO_COMPLEX
    static let maxVariantsPerItem = 16
    static let maxAmountCents = 1_000_000  // trần sanity: 1 món < $10,000
    static let searchSolutionCap = 4   // thu tối đa 4 nghiệm thô mỗi mức
}

/// Cặp chữ số OCR kinh điển (đối xứng): 0–6, 0–8, 0–9, 1–7, 2–7,
/// 3–8, 4–9, 5–6, 5–8, 6–8, 8–9. (Mirror: CONFUSE.)
private let reconcileConfusePartners: [Int: [Int]] = {
    var map: [Int: Set<Int>] = [:]
    for (a, b) in [(0, 6), (0, 8), (0, 9), (1, 7), (2, 7), (3, 8),
                   (4, 9), (5, 6), (5, 8), (6, 8), (8, 9)] {
        map[a, default: []].insert(b)
        map[b, default: []].insert(a)
    }
    return map.mapValues { $0.sorted() }
}()

/// Chữ cái OCR hay lẫn vào token tiền -> chữ số (mirror: LETTER_DIGIT).
private let reconcileLetterDigit: [String: String] = [
    "O": "0", "Q": "0", "S": "5", "Z": "2",
    "G": "6", "B": "8", "I": "1", "L": "1"
]

// MARK: P2-3 — DFS chọn tập con có ràng buộc (port của Search trong mirror)
//
// Tìm tổ hợp ứng viên (mỗi món tối đa 1 sửa) cho tổng delta cần đạt,
// theo mức số-sửa tăng dần 1..maxEdits; dừng ở mức tối thiểu đầu tiên
// có nghiệm; thu tối đa searchSolutionCap nghiệm thô ở mức đó. Cắt
// tỉa bằng khoảng delta hậu tố còn đạt được + ngân sách nút.

private final class ReconcileSearch {
    let byItem: [[ReconcileFix]]
    let maxEdits: Int
    let nodeCap: Int
    let solCap: Int
    private(set) var nodes = 0
    private(set) var overflow = false
    private let sufMin: [Int]
    private let sufMax: [Int]

    init(candsByItem: [[ReconcileFix]], maxEdits: Int,
         nodeCap: Int = ReconcileConstants.nodeCap,
         solCap: Int = ReconcileConstants.searchSolutionCap) {
        self.byItem = candsByItem.filter { !$0.isEmpty }
        self.maxEdits = maxEdits
        self.nodeCap = nodeCap
        self.solCap = solCap
        let n = self.byItem.count
        var sMin = [Int](repeating: 0, count: n + 1)
        var sMax = [Int](repeating: 0, count: n + 1)
        if n > 0 {
            for j in stride(from: n - 1, through: 0, by: -1) {
                let ds = self.byItem[j].map { $0.delta }
                sMin[j] = sMin[j + 1] + min(0, ds.min() ?? 0)
                sMax[j] = sMax[j + 1] + max(0, ds.max() ?? 0)
            }
        }
        self.sufMin = sMin
        self.sufMax = sMax
    }

    func run(target: Int) -> (solutions: [[ReconcileFix]], overflow: Bool) {
        for level in 1...maxEdits {
            var sols: [[ReconcileFix]] = []
            var chosen: [ReconcileFix] = []
            dfs(0, target, level, &chosen, &sols)
            if overflow { return (sols, true) }
            if !sols.isEmpty { return (sols, false) }
        }
        return ([], false)
    }

    private func dfs(_ j: Int, _ remaining: Int, _ editsLeft: Int,
                     _ chosen: inout [ReconcileFix],
                     _ sols: inout [[ReconcileFix]]) {
        if sols.count >= solCap || overflow { return }
        nodes += 1
        if nodes > nodeCap {
            overflow = true
            return
        }
        if remaining == 0 && !chosen.isEmpty {
            sols.append(chosen)
            return
        }
        if j >= byItem.count || editsLeft == 0 { return }
        if remaining < sufMin[j] || remaining > sufMax[j] { return }
        // Nhánh "bỏ qua món j" chạy TRƯỚC nhánh "lấy ứng viên" — đúng
        // thứ tự duyệt của mirror (thứ tự này quyết định nghiệm nào
        // được thu khi có hơn solCap nghiệm thô).
        dfs(j + 1, remaining, editsLeft, &chosen, &sols)
        for c in byItem[j] {
            chosen.append(c)
            dfs(j + 1, remaining - c.delta, editsLeft - 1, &chosen, &sols)
            chosen.removeLast()
            if sols.count >= solCap || overflow { return }
        }
    }
}

// MARK: - P2-3 — Lớp trọng tài (extension: dùng lại được các helper
// private của ReceiptParser trong cùng file — moneyToCents,
// trailingAmount, matchQtyLine, matchGroups)

extension ReceiptParser {

    // MARK: Điểm vào

    /// parse() nguyên vẹn + một lượt trọng tài. Cảnh báo trả về =
    /// cảnh báo validate() gốc (tính trên kết quả CHƯA sửa) + ghi chú
    /// của lớp trọng tài — validate() không bị sửa, lớp này chỉ bổ
    /// sung. Quyết định trình bày cuối cùng thuộc gói tích hợp.
    static func parseAndReconcile(lines: [OCRLine], lineBoxes: [CGRect?]? = nil)
        -> (result: ParseResult, report: ReconcileReport) {
        let parsed = parse(lines: lines)
        let (report, reconciled) = reconcile(result: parsed, lines: lines,
                                             lineBoxes: lineBoxes)
        var out = reconciled
        out.warnings = reconciled.warnings + report.notes
        return (out, report)
    }

    /// Một lượt đối chiếu trên kết quả parse có sẵn. Hàm THUẦN: không
    /// chạm OCR, không sửa kết quả đầu vào (struct — làm việc trên bản
    /// sao). Trả (báo cáo, kết quả): kết quả chỉ khác đầu vào khi có
    /// sửa được ÁP DỤNG (status REPAIRED/PARTIAL); mọi đường từ chối
    /// đều trả kết quả nguyên vẹn.
    ///
    /// `lines` là cùng danh sách dòng đã đưa vào parse(); hàm tự chuẩn
    /// hoá (cắt khoảng trắng + bỏ dòng rỗng) đúng như parse() để chỉ
    /// số dòng trong báo cáo khớp result.rawText. `lineBoxes` (tuỳ
    /// chọn) song song với danh sách dòng SAU chuẩn hoá — chỉ dùng để
    /// tính band cho RegionHint, không ảnh hưởng quyết định.
    static func reconcile(result r: ParseResult, lines rawLines: [OCRLine],
                          lineBoxes: [CGRect?]? = nil)
        -> (report: ReconcileReport, result: ParseResult) {
        let lines = rawLines
            .map { OCRLine(text: $0.text.trimmingCharacters(in: .whitespaces), confidence: $0.confidence) }
            .filter { !$0.text.isEmpty }
        let texts = lines.map { $0.text }
        let items = r.items
        let lineOf = reconcileItemLineMap(items: items, texts: texts)

        var rep = ReconcileReport()
        // Trạng thái "chưa kết luận" ở giữa lượt (Pha B được đặt
        // .partial) — mirror giữ rep["status"] = None tới Pha kết
        // luận; bản Swift dùng biến cục bộ tương đương.
        var status: ReconcileStatus? = nil
        var rawHints: [(block: ReconcileRegionHint.Block,
                        reason: ReconcileRegionHint.Reason,
                        delta: Int?)] = []

        // Đóng gói hint khi ra: priority theo thứ tự phát, lineRange
        // theo khối, band khi caller cấp hộp dòng (nới 50% chiều cao
        // mỗi phía, kẹp [0,1] — thiết kế §6).
        func blockRange(_ block: ReconcileRegionHint.Block) -> ClosedRange<Int>? {
            let idx: [Int]
            switch block {
            case .items:
                idx = lineOf.compactMap { $0 }
            case .totals:
                idx = texts.indices.filter {
                    let u = texts[$0].uppercased()
                    return u.contains("SUBTOTAL") || u.contains("TOTAL") || u.contains("TAX")
                }
            }
            guard let lo = idx.min(), let hi = idx.max() else { return nil }
            return lo...hi
        }
        func band(for range: ClosedRange<Int>) -> CGRect? {
            guard let boxes = lineBoxes else { return nil }
            let ys = range.compactMap { i -> CGRect? in
                (i >= 0 && i < boxes.count) ? boxes[i] : nil
            }
            guard let lo = ys.map({ $0.minY }).min(),
                  let hi = ys.map({ $0.maxY }).max() else { return nil }
            let h = hi - lo
            let y0 = max(0.0, lo - h / 2)
            let y1 = min(1.0, hi + h / 2)
            return CGRect(x: 0, y: y0, width: 1, height: max(0, y1 - y0))
        }
        func finalizeHints() -> [ReconcileRegionHint] {
            var out: [ReconcileRegionHint] = []
            for (i, h) in rawHints.enumerated() {
                let range = blockRange(h.block)
                out.append(ReconcileRegionHint(block: h.block, reason: h.reason,
                                               priority: i + 1, deltaCents: h.delta,
                                               lineRange: range,
                                               band: range.flatMap { band(for: $0) }))
            }
            return out
        }

        // ── Pha 0: neo. Số neo KHÔNG BAO GIỜ bị lớp này sửa. ──────
        if r.subtotalCents == nil && r.totalCents == nil {
            rep.status = .noAnchor
            rep.notes.append("Không có cả subtotal lẫn total — không có đích đối chiếu; chỉ giữ cảnh báo của validate().")
            // Thiết kế §2: mọi trạng thái khác OK đều vào Hộp Chờ.
            // (Mirror trả sớm ở đây trước khi gán requiresReview.)
            rep.requiresReview = true
            return (rep, r)
        }
        if r.subtotalCents == nil, let total = r.totalCents {
            // DẠNG CA THỰC ĐỊA 16:50 (bản giấy quét): mất subtotal +
            // thuế, thường mất cả khối món, chỉ còn total (+ ITEMS
            // SOLD). Total là NEO TREO — TUYỆT ĐỐI không suy ngược
            // subtotal/thuế từ total (thiết kế §5.1: hoá đơn Sam's có
            // 2 suất thuế + món miễn thuế -> thiếu phương trình).
            rep.status = .totalOnly
            rep.anchorsPresent = ["total"] + (r.itemsSold != nil ? ["itemsSold"] : [])
            rep.anchorsMissing = ["subtotal", "taxes"]
            rep.notes.append("Chỉ còn total \(total) xu (+ ITEMS SOLD \(r.itemsSold.map { String($0) } ?? "không rõ")) — subtotal/thuế/món không suy diễn. Total được giữ làm neo treo: khi đọc lại được khối món, Σ món + thuế hàm ý sẽ được kiểm với total trong dải suất hợp lý (xem §5).")
            rawHints.append((.items, .totalOnlyAnchor, nil))
            rawHints.append((.totals, .totalOnlyAnchor, nil))
            rep.regionHints = finalizeHints()
            rep.requiresReview = true
            return (rep, r)
        }
        // Từ đây subtotal chắc chắn có mặt.
        let subtotal = r.subtotalCents!
        if let total = r.totalCents, !r.taxes.isEmpty {
            let taxSum = r.taxes.reduce(0) { $0 + $1.amountCents }
            if abs(subtotal + taxSum - total) > 2 {
                rep.status = .anchorConflict
                rep.notes.append("Chính các số neo mâu thuẫn nhau (subtotal + thuế != total) — đích không đáng tin, từ chối sửa; cần đọc lại vùng tổng hoặc anh kiểm với giấy.")
                rawHints.append((.totals, .anchorConflict, nil))
                rep.regionHints = finalizeHints()
                rep.requiresReview = true
                return (rep, r)
            }
        }
        if let total = r.totalCents, r.taxes.isEmpty {
            // Có subtotal + total nhưng mất hẳn dòng thuế: thuế hàm ý
            // CHỈ dùng kiểm tra hợp lý (suất pha trộn trong 0..15%),
            // KHÔNG ghi thành dòng thuế (thiết kế §5.3).
            let implied = total - subtotal
            if implied < 0 || (subtotal > 0 && implied * 100 > 15 * subtotal) {
                rep.status = .anchorConflict
                rep.notes.append("Thuế hàm ý từ total - subtotal = \(implied) xu nằm ngoài dải hợp lý (âm hoặc suất pha trộn > 15%) — một trong hai số neo đáng ngờ, từ chối sửa.")
                rawHints.append((.totals, .anchorConflict, nil))
                rep.regionHints = finalizeHints()
                rep.requiresReview = true
                return (rep, r)
            }
            rep.taxMissing = true
            rep.impliedTaxCents = implied
            let pct = subtotal != 0
                ? String(format: "%.2f", 100.0 * Double(implied) / Double(subtotal))
                : "0.00"
            rep.notes.append("Mất dòng thuế; thuế hàm ý \(implied) xu (suất pha trộn \(pct)%) nằm trong dải hợp lý — chỉ là kiểm tra hợp lý, KHÔNG ghi thuế suy diễn vào hoá đơn.")
        }

        let sumItems = items.reduce(0) { $0 + ($1.amountCents ?? 0) }
        let delta = subtotal - sumItems
        rep.moneyDeltaCents = delta
        if let sold = r.itemsSold {
            rep.qtyDelta = sold - reconcileQtySum(items)
        }

        var r2 = r
        var applied: [ReconcileFix] = []

        // ── Pha A: khớp tiền (E1) ─────────────────────────────────
        if delta != 0 {
            var anchorAmounts = Set<Int>()
            anchorAmounts.insert(subtotal)
            if let t = r.totalCents { anchorAmounts.insert(t) }
            for t in r.taxes { anchorAmounts.insert(t.amountCents) }
            let knownAmounts = Set(items.compactMap { $0.amountCents })
            let noneItems = items.indices.filter { items[$0].amountCents == nil }
            var cands: [[ReconcileFix]] = items.map { _ in [] }

            for k in items.indices {
                let it = items[k]
                let (full, consistent) = reconcileTriple(it)
                if let amount = it.amountCents {
                    if full && !consistent {
                        let forced = it.qty * (it.unitPriceCents ?? 0)
                        if forced != amount && abs(forced) < ReconcileConstants.maxAmountCents {
                            cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                         oldValue: amount, newValue: forced,
                                                         delta: forced - amount,
                                                         channel: .force, tier: 1))
                        }
                    }
                    // KHOÁ bộ ba chỉ khi unit là bằng chứng ĐỘC LẬP:
                    // dòng số lượng qty >= 2 (unit đọc từ "N AT 1 FOR
                    // X"). Món qty = 1 có unit bị parser sao chép từ
                    // chính amount — bộ ba "nhất quán" thoái hoá,
                    // không khoá được gì (bài học ca C6/C7 của mirror).
                    let locked = full && consistent && it.qty >= 2
                    if !locked {
                        for v in reconcileDigitVariants(amount) {
                            cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                         oldValue: amount, newValue: v,
                                                         delta: v - amount,
                                                         channel: .digit, tier: 3))
                        }
                        cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                     oldValue: amount, newValue: -amount,
                                                     delta: -2 * amount,
                                                     channel: .sign, tier: 3))
                    }
                } else {
                    // Món chưa có tiền: cửa sổ dòng của nó (dòng nhãn
                    // -> trước dòng nhãn món kế tiếp) — token tiền lạc
                    // trong cửa sổ là bằng chứng tại chỗ (dòng xé
                    // mảnh / token hỏng ký tự).
                    let start = lineOf[k] ?? 0
                    let later = lineOf.compactMap { $0 }.filter { $0 > start }
                    let end = later.min().map { $0 - 1 } ?? (texts.count - 1)
                    var seen = Set<Int>()
                    if end >= start {
                        for li in start...end {
                            for tok in reconcileTolerantTokens(texts[li]) {
                                if seen.contains(tok.cents) || anchorAmounts.contains(tok.cents) { continue }
                                if knownAmounts.contains(tok.cents) && !tok.hasLetter { continue }
                                seen.insert(tok.cents)
                                cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                             oldValue: nil, newValue: tok.cents,
                                                             delta: tok.cents,
                                                             channel: .token, tier: 2,
                                                             evidence: "line \(li): \(tok.raw)"))
                            }
                        }
                    }
                    if noneItems.count == 1 {
                        cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                     oldValue: nil, newValue: delta,
                                                     delta: delta,
                                                     channel: .deficit, tier: 4))
                    }
                }
            }

            // Kênh ORPHAN: dòng mã món CÓ trong luồng thô nhưng
            // parser đã đánh rơi (điển hình: món đang chờ bị dòng mã
            // kế tiếp ghi đè). Mã + nhãn lấy nguyên từ dòng; tiền từ
            // token trên dòng / dòng số lượng sau / mảnh xé sau. Hiện
            // chỉ có mẫu cho định dạng Sam's (mã 10 số) — định dạng
            // khác kênh này tắt (giới hạn đã ghi ở thiết kế §3).
            if r.vendorKey == "sams" {
                let parsedCodes = Set(items.compactMap { $0.itemCode })
                var slotNo = 0
                for li in texts.indices {
                    let text = texts[li]
                    guard let m = matchGroups(text, pattern: #"^(\d{10})\s+(.+)$"#),
                          m.count == 2, let code = m[0], let rest = m[1] else { continue }
                    if parsedCodes.contains(code) { continue }
                    var ocands: [(amount: Int, name: String, qty: Int, unit: Int)] = []
                    if let tail = trailingAmount(in: rest), !tail.name.isEmpty {
                        ocands.append((tail.cents, tail.name, 1, tail.cents))
                    } else {
                        for tok in reconcileTolerantTokens(rest) {
                            let nm = reconcileCollapseName(rest.replacingOccurrences(of: tok.raw, with: ""))
                            ocands.append((tok.cents, nm, 1, tok.cents))
                        }
                        if li + 1 < texts.count {
                            let ntext = texts[li + 1]
                            if let q = matchQtyLine(ntext) {
                                ocands.append((q.amountCents, rest, q.qty, q.unitCents))
                            } else {
                                for tok in reconcileTolerantTokens(ntext) {
                                    let frag = reconcileCollapseName(ntext.replacingOccurrences(of: tok.raw, with: ""))
                                    ocands.append((tok.cents,
                                                   (rest + " " + frag).trimmingCharacters(in: .whitespaces),
                                                   1, tok.cents))
                                }
                            }
                        }
                    }
                    var slot: [ReconcileFix] = []
                    var seenAmt = Set<Int>()
                    for oc in ocands {
                        if oc.amount == 0 || anchorAmounts.contains(oc.amount) || seenAmt.contains(oc.amount) { continue }
                        seenAmt.insert(oc.amount)
                        slot.append(ReconcileFix(itemIndex: items.count + slotNo, field: .insert,
                                                 oldValue: nil, newValue: oc.amount,
                                                 delta: oc.amount,
                                                 channel: .orphan, tier: 2,
                                                 insertName: oc.name, insertQty: oc.qty,
                                                 insertUnitCents: oc.unit, insertCode: code,
                                                 evidence: "line \(li): \(text)"))
                    }
                    if !slot.isEmpty {
                        cands.append(slot)
                        slotNo += 1
                    }
                }
            }

            let search = ReconcileSearch(candsByItem: cands, maxEdits: ReconcileConstants.maxEdits)
            let (rawSols, overflow) = search.run(target: delta)
            let sols = reconcileDedupe(rawSols)
            rep.nodesVisited = search.nodes
            if overflow {
                rep.status = .tooComplex
                rep.notes.append("Vượt ngân sách tìm kiếm (\(ReconcileConstants.nodeCap) nút) — từ chối sửa, giữ nguyên + cảnh báo.")
                rep.requiresReview = true
                rep.regionHints = finalizeHints()
                return (rep, r)
            }
            rep.solutionCount = sols.count
            if sols.count >= 2 {
                rep.status = .ambiguous
                rep.suggestions = sols
                rep.notes.append("Có >=2 tổ hợp cùng khớp đúng từng xu ở mức sửa tối thiểu — mơ hồ, không áp dụng tổ hợp nào; cả hai được trình anh ở Review.")
                rep.requiresReview = true
                rep.regionHints = finalizeHints()
                return (rep, r)
            }
            if sols.isEmpty {
                rep.status = .noSolution
                rep.notes.append("Lệch \(delta) xu nhưng không tổ hợp sửa nào (<= \(ReconcileConstants.maxEdits) sửa) khớp — KHÔNG bịa món. Nghi mất dòng: vùng đọc lại = khối món.")
                rawHints.append((.items, .missingOrUnrepairable, delta))
                rep.regionHints = finalizeHints()
                rep.requiresReview = true
                return (rep, r)
            }
            let sol = sols[0]
            if sol.allSatisfy({ $0.channel.isSiteEvidenced }) {
                for c in sol {
                    if c.field == .insert {
                        var ni = ParsedLineItem(name: c.insertName ?? "")
                        ni.qty = c.insertQty ?? 1
                        ni.unitPriceCents = c.insertUnitCents
                        ni.amountCents = c.newValue
                        ni.itemCode = c.insertCode
                        r2.items.append(ni)
                        applied.append(c)
                        continue
                    }
                    var it2 = r2.items[c.itemIndex]
                    it2.amountCents = c.newValue
                    // Mirror: unit bị sao chép thoái hoá (thiếu, hoặc
                    // qty = 1) thì đồng bộ theo amount mới.
                    if it2.unitPriceCents == nil || it2.qty == 1 {
                        it2.unitPriceCents = c.newValue
                    }
                    r2.items[c.itemIndex] = it2
                    applied.append(c)
                }
                rep.fixes = sol
            } else {
                rep.status = .suggestionOnly
                rep.suggestions = [sol]
                rep.notes.append("Tồn tại đúng 1 tổ hợp khớp từng xu nhưng ít nhất một sửa thuần số học (không bằng chứng tại chỗ trên dòng) — KHÔNG áp dụng; trình làm gợi ý ở Review kèm phép tính.")
                rep.requiresReview = true
                rep.regionHints = finalizeHints()
                return (rep, r)
            }
        }

        // ── Pha B: khớp số lượng (E3) — chạy trên r2, đã gồm sửa
        // tiền đã áp ở Pha A. Cùng cơ chế, ngân sách 2 sửa; nghiệm
        // thuần số học -> gợi ý, không áp dụng. ────────────────────
        if let sold = r.itemsSold {
            let qd = sold - reconcileQtySum(r2.items)
            rep.qtyDelta = qd
            if qd != 0 {
                var qcands: [[ReconcileFix]] = r2.items.map { _ in [] }
                for k in r2.items.indices {
                    let it = r2.items[k]
                    guard let amount = it.amountCents, amount > 0 else { continue }
                    let (full, consistent) = reconcileTriple(it)
                    if full && !consistent, let unit = it.unitPriceCents, unit != 0,
                       amount % unit == 0 {
                        let nq = amount / unit
                        if nq > 0 && nq != it.qty {
                            qcands[k].append(ReconcileFix(itemIndex: k, field: .qty,
                                                          oldValue: it.qty, newValue: nq,
                                                          delta: nq - it.qty,
                                                          channel: .force, tier: 1))
                        }
                    }
                    for v in reconcileDigitVariants(it.qty) where v > 0 {
                        qcands[k].append(ReconcileFix(itemIndex: k, field: .qty,
                                                      oldValue: it.qty, newValue: v,
                                                      delta: v - it.qty,
                                                      channel: .digit, tier: 3))
                    }
                }
                let qs = ReconcileSearch(candsByItem: qcands, maxEdits: ReconcileConstants.maxQtyEdits)
                let (qRaw, qOverflow) = qs.run(target: qd)
                let qsols = reconcileDedupe(qRaw)
                rep.nodesVisited += qs.nodes
                if !qOverflow && qsols.count == 1 && qsols[0].allSatisfy({ $0.channel.isSiteEvidenced }) {
                    for c in qsols[0] {
                        r2.items[c.itemIndex].qty = c.newValue
                        applied.append(c)
                    }
                    rep.fixes = applied
                } else if !qOverflow && !qsols.isEmpty {
                    rep.suggestions = rep.suggestions + [qsols[0]]
                    rep.notes.append("Số lượng còn lệch \(qd) và nghiệm khớp số lượng không đủ điều kiện áp dụng (mơ hồ hoặc thuần số học) — để gợi ý.")
                    if status == nil { status = .partial }
                } else {
                    rep.notes.append("Số lượng còn lệch \(qd), không sửa được — cần đọc lại vùng món hoặc anh kiểm với giấy.")
                    rawHints.append((.items, .qtyMismatch, nil))
                    if status == nil { status = .partial }
                }
            }
        }

        // ── Pha C: quét bộ ba khi tiền & lượng đã khớp. Suy trường
        // còn lại của bộ ba mâu thuẫn CHỈ khi phép chia hết (không
        // làm lệch lại tổng tiền vì amount không đổi). ─────────────
        for k in r2.items.indices {
            let it = r2.items[k]
            let (full, consistent) = reconcileTriple(it)
            if !full || consistent { continue }
            guard let amount = it.amountCents, let unit = it.unitPriceCents else { continue }
            var fixedField: ReconcileFix.Field? = nil
            var fixedValue = 0
            if it.qty != 0 && amount % it.qty == 0 {
                let nu = amount / it.qty
                if it.qty * nu == amount {
                    r2.items[k].unitPriceCents = nu
                    fixedField = .unit
                    fixedValue = nu
                }
            } else if unit != 0 && amount % unit == 0 {
                let nq = amount / unit
                if nq > 0 {
                    r2.items[k].qty = nq
                    fixedField = .qty
                    fixedValue = nq
                }
            }
            if let ff = fixedField {
                // Mirror ghi old = None cho sửa Pha C (giữ nguyên
                // hành vi đó; giá trị cũ vẫn truy được từ kết quả gốc).
                applied.append(ReconcileFix(itemIndex: k, field: ff,
                                            oldValue: nil, newValue: fixedValue,
                                            delta: 0, channel: .force, tier: 1))
                rep.fixes = applied
            } else {
                rep.notes.append("Món #\(k) bộ ba qty×unit!=amount và không chia hết để suy ra trường còn lại — để nguyên, gắn cờ.")
            }
        }

        // ── Kết luận ──────────────────────────────────────────────
        let sum2 = r2.items.reduce(0) { $0 + ($1.amountCents ?? 0) }
        if let s = status {
            rep.status = s
        } else if !applied.isEmpty && sum2 == subtotal {
            rep.status = .repaired
        } else if applied.isEmpty && delta == 0 {
            rep.status = .ok
        } else {
            rep.status = .partial
        }
        rep.requiresReview = !applied.isEmpty || rep.status != .ok
        rep.regionHints = finalizeHints()
        return (rep, r2)
    }

    // MARK: P2-3 — Helper của lớp trọng tài (port từ mirror)

    /// (có đủ bộ ba?, có nhất quán?) cho qty/unit/amount. qty trong
    /// ParsedLineItem luôn có (mặc định 1) như port — nên "đủ" chỉ
    /// còn phụ thuộc unit/amount.
    static func reconcileTriple(_ it: ParsedLineItem) -> (full: Bool, consistent: Bool) {
        guard let unit = it.unitPriceCents, let amount = it.amountCents else {
            return (false, false)
        }
        return (true, it.qty * unit == amount)
    }

    /// Σ số lượng các món tiền dương (đích E3).
    static func reconcileQtySum(_ its: [ParsedLineItem]) -> Int {
        its.reduce(0) { $0 + (($1.amountCents ?? 0) > 0 ? $1.qty : 0) }
    }

    /// Biến thể 1-chữ-số của |cents| theo cặp nhầm OCR; giữ dấu, giữ
    /// độ dài (không tạo số 0 ở đầu), bỏ trùng/gốc/0, sắp tăng dần,
    /// trần maxVariantsPerItem. (Mirror: digit_variants.)
    static func reconcileDigitVariants(_ cents: Int) -> [Int] {
        if cents == 0 { return [] }
        let sign = cents < 0 ? -1 : 1
        let digits = Array(String(abs(cents)))
        var out = Set<Int>()
        for i in digits.indices {
            guard let d = Int(String(digits[i])) else { continue }
            for nd in reconcileConfusePartners[d] ?? [] {
                if i == 0 && nd == 0 { continue }
                var t = digits
                t[i] = Character(String(nd))
                guard let v = Int(String(t)) else { continue }
                if v != abs(cents) && v > 0 && v < ReconcileConstants.maxAmountCents {
                    out.insert(sign * v)
                }
            }
        }
        return Array(out.sorted().prefix(ReconcileConstants.maxVariantsPerItem))
    }

    /// Mọi token dạng tiền trong 1 dòng, gồm token chứa chữ cái lẫn
    /// (vd "19.4B" -> 1948 qua B->8). Trả (cents, raw, có-chữ) — token
    /// toàn chữ số cũng được trả (có-chữ = false) để kênh ORPHAN/mảnh
    /// xé dùng lại. (Mirror: tolerant_money_tokens.)
    static func reconcileTolerantTokens(_ text: String) -> [(cents: Int, raw: String, hasLetter: Bool)] {
        guard let re = try? NSRegularExpression(
            pattern: #"(\$?)([0-9OQSZGBIL][0-9OQSZGBIL,]*\.[0-9OQSZGBIL]{2})(-)?"#,
            options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var out: [(cents: Int, raw: String, hasLetter: Bool)] = []
        for m in re.matches(in: text, options: [], range: fullRange) {
            guard m.numberOfRanges >= 4 else { continue }
            let token = ns.substring(with: m.range(at: 2))
            let hasLetter = token.contains { $0.isLetter }
            let norm = token.map { ch -> String in
                reconcileLetterDigit[ch.uppercased()] ?? String(ch)
            }.joined()
            let digitsOnly = norm.filter { $0 != "," && $0 != "." }
            if digitsOnly.isEmpty || !digitsOnly.allSatisfy({ $0.isNumber }) { continue }
            let negative = m.range(at: 3).location != NSNotFound
            let cents = moneyToCents(norm, negative: negative)
            if cents != 0 {
                out.append((cents, ns.substring(with: m.range(at: 0)), hasLetter))
            }
        }
        return out
    }

    /// Gán mỗi món về chỉ số dòng thô (theo mã món, rồi theo tiền tố
    /// tên 10 ký tự) — neo cho cửa sổ TOKEN và lineRange của hint.
    /// (Mirror: item_line_map.)
    static func reconcileItemLineMap(items: [ParsedLineItem], texts: [String]) -> [Int?] {
        var idxs: [Int?] = []
        for it in items {
            var found: Int? = nil
            if let code = it.itemCode {
                for i in texts.indices where texts[i].contains(code) {
                    found = i
                    break
                }
            }
            if found == nil {
                let key = String(it.name.trimmingCharacters(in: .whitespaces).uppercased().prefix(10))
                if !key.isEmpty {
                    for i in texts.indices where texts[i].uppercased().contains(key) {
                        found = i
                        break
                    }
                }
            }
            idxs.append(found)
        }
        return idxs
    }

    /// Thu gọn khoảng trắng + bỏ cờ Y/T ở cuối — dọn tên món mồ côi
    /// như mirror (re.sub "\\s+" -> " ", rồi bỏ "\\s+[YT]$").
    static func reconcileCollapseName(_ s: String) -> String {
        var out = s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if out.hasSuffix(" Y") || out.hasSuffix(" T") {
            out = String(out.dropLast(2))
        }
        return out
    }

    /// Gộp nghiệm trùng chữ ký (item, field, new) — hai ứng viên khác
    /// kênh cùng gán một giá trị cho một món là MỘT nghiệm vật lý; giữ
    /// bản bằng chứng mạnh hơn (ưu tiên toàn kênh tại chỗ, rồi tier
    /// thấp hơn). (Mirror: dedupe_sols — bản Swift thu nghiệm riêng
    /// biệt theo chữ ký đúng khuyến nghị ở thiết kế §4.)
    static func reconcileDedupe(_ sols: [[ReconcileFix]]) -> [[ReconcileFix]] {
        func signature(_ sol: [ReconcileFix]) -> String {
            sol.map { "\($0.itemIndex)|\($0.field.rawValue)|\($0.newValue)" }
                .sorted()
                .joined(separator: ";")
        }
        func isBetter(_ a: [ReconcileFix], than b: [ReconcileFix]) -> Bool {
            let aAll = a.allSatisfy { $0.channel.isSiteEvidenced }
            let bAll = b.allSatisfy { $0.channel.isSiteEvidenced }
            if aAll != bAll { return aAll }
            let aTier = a.map { $0.tier }.max() ?? 0
            let bTier = b.map { $0.tier }.max() ?? 0
            return aTier < bTier
        }
        var best: [String: [ReconcileFix]] = [:]
        var order: [String] = []
        for s in sols {
            let sg = signature(s)
            if let existing = best[sg] {
                if isBetter(s, than: existing) { best[sg] = s }
            } else {
                best[sg] = s
                order.append(sg)
            }
        }
        return order.map { best[$0]! }
    }
}

// MARK: - P2-3 — Phiên đối chiếu nhiều vòng (đọc-lại-có-mục-tiêu)
//
// Vòng lặp ở mức DỮ LIỆU (thiết kế §6): tầng OCR (P2-1/P2-2) đọc lại
// vùng theo pendingHints, gộp dòng mới vào tập dòng đầy đủ (khử trùng
// theo (text, hộp giao nhau) — việc của tầng OCR), parse lại toàn bộ
// rồi nộp kết quả qua submitRound. Tối đa 2 vòng, mỗi vòng tối đa 2
// vùng theo priority.

final class ReconcileSession {
    static let maxRounds = 2
    static let maxRegionsPerRound = 2

    private(set) var bestReport: ReconcileReport
    private(set) var bestResult: ParseResult
    private(set) var roundsUsed = 0
    private(set) var isFinished = false

    init(result: ParseResult, lines: [OCRLine], lineBoxes: [CGRect?]? = nil) {
        let (rep, res) = ReceiptParser.reconcile(result: result, lines: lines,
                                                 lineBoxes: lineBoxes)
        bestReport = rep
        bestResult = res
    }

    /// Vùng nên đọc lại ở vòng kế (đã cắt theo ngân sách vùng/vòng).
    var pendingHints: [ReconcileRegionHint] {
        Array(bestReport.regionHints.prefix(ReconcileSession.maxRegionsPerRound))
    }

    /// Nhận kết quả một vòng đọc lại. QUY TẮC ĐƠN ĐIỆU (chống dao
    /// động): chỉ nhận khi đối chiếu tốt hơn hẳn theo isBetter; không
    /// tốt hơn -> giữ kết quả vòng trước và KẾT THÚC phiên.
    /// Trả true khi kết quả mới được nhận làm best mới.
    @discardableResult
    func submitRound(result: ParseResult, lines: [OCRLine],
                     lineBoxes: [CGRect?]? = nil) -> Bool {
        if isFinished || roundsUsed >= ReconcileSession.maxRounds { return false }
        roundsUsed += 1
        let (rep, res) = ReceiptParser.reconcile(result: result, lines: lines,
                                                 lineBoxes: lineBoxes)
        if ReconcileSession.isBetter(newReport: rep, newResult: res,
                                     oldReport: bestReport, oldResult: bestResult) {
            bestReport = rep
            bestResult = res
            if roundsUsed >= ReconcileSession.maxRounds { isFinished = true }
            return true
        }
        isFinished = true
        return false
    }

    /// Thứ tự "tốt hơn" (thiết kế §6): |lệch tiền| giảm -> số món
    /// khôi phục tăng -> trạng thái neo cải thiện. Bằng nhau ở cả ba
    /// = KHÔNG tốt hơn. Lệch tiền nil (TOTAL_ONLY/NO_ANCHOR) tính là
    /// xấu nhất (Int.max).
    static func isBetter(newReport: ReconcileReport, newResult: ParseResult,
                         oldReport: ReconcileReport, oldResult: ParseResult) -> Bool {
        let nd = newReport.moneyDeltaCents.map { abs($0) } ?? Int.max
        let od = oldReport.moneyDeltaCents.map { abs($0) } ?? Int.max
        if nd != od { return nd < od }
        if newResult.items.count != oldResult.items.count {
            return newResult.items.count > oldResult.items.count
        }
        return anchorRank(newReport) > anchorRank(oldReport)
    }

    private static func anchorRank(_ rep: ReconcileReport) -> Int {
        switch rep.status {
        case .noAnchor, .anchorConflict: return 0
        case .totalOnly: return 1
        default: return 2
        }
    }
}

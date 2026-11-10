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

enum ReceiptParser {

    static func parse(lines input: [OCRLine]) -> ParseResult {
        let lines = input
            .map { OCRLine(text: $0.text.trimmingCharacters(in: .whitespaces), confidence: $0.confidence) }
            .filter { !$0.text.isEmpty }
        var result = ParseResult()
        result.rawText = lines.map { $0.text }.joined(separator: "\n")

        if isSams(lines: lines) {
            result = parseSams(lines: lines)
        } else {
            result = parseGeneric(lines: lines)
        }
        result.rawText = lines.map { $0.text }.joined(separator: "\n")
        result.warnings = validate(result)
        return result
    }

    // MARK: Nhận diện Sam's

    private static func isSams(lines: [OCRLine]) -> Bool {
        for line in lines {
            let lower = line.text.lowercased()
            if lower.contains("sam's club") || lower.contains("sams club") || lower.contains("sam’s club") {
                return true
            }
        }
        return false
    }

    // MARK: - SAM'S CLUB (cổng từ prototype v0.1 đã đạt Mẫu 001)

    private static func parseSams(lines: [OCRLine]) -> ParseResult {
        var r = ParseResult()
        r.vendor = "Sam's Club"
        r.vendorKey = "sams"
        for line in lines {
            let lower = line.text.lowercased()
            if lower.contains("sam's club") || lower.contains("sams club") || lower.contains("sam’s club") {
                r.vendorConfidence = line.confidence
                break
            }
        }

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

    private static func parseGeneric(lines: [OCRLine]) -> ParseResult {
        var r = ParseResult()
        r.vendorKey = "generic"

        // Vendor: nhận một số tiệm lớn, còn lại lấy dòng đầu hợp lệ.
        let knownVendors: [(needle: String, name: String)] = [
            ("WALMART", "Walmart"),
            ("COSTCO", "Costco"),
            ("HOME DEPOT", "Home Depot"),
            ("LOWE", "Lowe's"),
            ("TARGET", "Target"),
            ("QUIKTRIP", "QuikTrip"),
            ("CASEY", "Casey's"),
            ("LOVE'S", "Love's"),
            ("LOVES", "Love's")
        ]
        var vendorFound = false
        for line in lines.prefix(6) {
            let upper = line.text.uppercased()
            for kv in knownVendors where upper.contains(kv.needle) {
                r.vendor = kv.name
                r.vendorConfidence = line.confidence
                vendorFound = true
                break
            }
            if vendorFound { break }
        }
        if !vendorFound, let first = lines.first, first.text.count <= 40 {
            r.vendor = first.text
            r.vendorConfidence = min(first.confidence, 0.5) // đoán từ dòng đầu -> tin cậy thấp
        }

        // Ngày
        if let found = findDateTime(in: lines) ?? findDateOnly(in: lines) {
            r.date = found.date
            r.dateConfidence = found.confidence
        }

        // Tổng: cắt vùng loại trừ TRƯỚC (Suggested Tip chứa tổng giả).
        // F2b: cùng máy trạng thái nhãn-chờ như nhánh Sam's, theo pattern
        // của nhánh generic; TOTAL vẫn tôn trọng vùng loại trừ
        // (ignoreTotals) y như đường cùng-dòng.
        var ignoreTotals = false
        var pendingKind: String? = nil   // "SUBTOTAL" | "TOTAL" | "TAX"
        for line in lines {
            let text = line.text
            let upper = text.uppercased()
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
                }
                pendingKind = nil
                continue
            }
            // F2b: dòng chỉ-có-nhãn -> ghi nhớ cho đúng dòng ngay sau.
            if matchGroups(text, pattern: #"^SUBTOTAL\s*:?$"#) != nil {
                pendingKind = "SUBTOTAL"
                continue
            }
            if !ignoreTotals,
               matchGroups(text, pattern: #"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?$"#) != nil {
                pendingKind = "TOTAL"
                continue
            }
            if (upper.hasPrefix("TAX") || upper.hasPrefix("SALES TAX")),
               lastMoneyInLine(text) == nil {
                pendingKind = "TAX"
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
                continue
            }
            let isTaxLine = upper.hasPrefix("TAX") || upper.hasPrefix("SALES TAX")
            if isTaxLine, let cents = lastMoneyInLine(text) {
                r.taxes.append(ParsedTaxLine(label: "TAX", rateText: nil, amountCents: cents))
                continue
            }
            if !ignoreTotals, r.totalCents == nil,
               let m = matchGroups(text, pattern: #"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?\s*\$?(\d[\d,]*\.\d{2})(-)?$"#),
               m.count == 3 {
                r.totalCents = moneyToCents(m[1] ?? "", negative: m[2] != nil)
                r.totalConfidence = line.confidence
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

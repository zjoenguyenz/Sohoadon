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

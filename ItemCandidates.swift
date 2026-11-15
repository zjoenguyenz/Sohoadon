import Foundation

// =====================================================================
//  ItemCandidates.swift — CORE-V4 · GÓI V4-2 (DESIGN-V4 §4)
//
//  ỨNG VIÊN MÓN + NỐI SỐ LƯỢNG. Nguyên tắc nền (§4.1): một dòng
//  thành ứng viên món khi có TOKEN TIỀN + CHỮ; mã món chỉ là
//  THUỘC TÍNH chấm điểm — không bao giờ là cổng (nghịch đảo trực
//  tiếp của mẫu `(?<!\d)\d{10}` cũ ở Parser.swift:471, nguyên
//  nhân ca Sam's giấy 30/09 đọc 0 món: mã ở đó dài 9 và 6 số).
//
//  Thành phần:
//   - PrintSemanticsRules: bốn quy tắc §4.4 khai dạng DỮ LIỆU CÓ
//     TÊN ở một chỗ duy nhất — cấm rải rác `if` theo tên tiệm.
//   - ItemLineClassifier: quét token tiền cho tầng món (token
//     chấm cùng biên với CandidateFactory + token phẩy thập phân
//     thừa kế lastCommaMoney của v3 + token phẩy trần có ngữ
//     cảnh) và phân loại MỌI dòng thành: món / mảnh giá / món
//     treo / món tiền-gãy / dòng phụ (AT · N@ · cân) / bị họ
//     nhãn loại trừ / dòng tên / bỏ qua. KHÔNG dòng nào bị vứt
//     vì "sai hình dạng" — dòng không thành món vẫn nằm trong
//     hồ sơ phân loại cho pha trọng tài dùng (bể ngoài cửa sổ,
//     bể bị loại trừ cho các nước sửa §3.5).
//   - Biến thể hậu tố của token dính (tầng ocrVariant CỦA TẦNG
//     MÓN): token in dính mã+giá ("1280219.97") sinh thêm các
//     ứng viên là CHUỖI CON IN THẬT của nó (bỏ k chữ số đầu của
//     phần nguyên). §2.6 định tầng ocrVariant qua ứng viên OCR
//     — đường chữ không có chúng; không có cơ chế này ca C-003
//     bất khả trên luồng A0 (1997 chỉ tồn tại như hậu tố). Mọi
//     biến thể đều truy về đúng token đã in qua provenance.
//   - ItemCandidateFactory: lắp món trong cửa sổ khối món (§4.5:
//     cửa sổ là ƯU TIÊN, không phải cổng — món ngoài cửa sổ vẫn
//     vào bể dự phòng cho nước sửa (ii)) và NỐI dòng phụ trong
//     cửa sổ ±2 dòng CẢ HAI CHIỀU (§4.2): khớp tích qty × đơn
//     giá là bằng chứng mạnh nhất; token đã tiêu thụ cho một
//     món không tính hai lần, không tự đứng thành món; nối
//     không được thì token về "chưa gán" + dấu vết, KHÔNG ép
//     nối theo vị trí khi còn ≥2 ứng viên cùng không khớp tích.
// =====================================================================

/// §4.4 — quy tắc ngữ nghĩa in, DỮ LIỆU CÓ TÊN (không phải if
/// rải rác). (iii)+(iv) thi hành ở tầng khối tổng (V4-1) và được
/// khai ở đây để đủ bộ bốn quy tắc tại một chỗ tra cứu.
enum PrintSemanticsRules {
    /// (i) Dòng phụ "N @ giá" (Sam's): chỉ đóng góp E3, KHÔNG
    /// nhân tiền dòng (tờ Sam's giấy tự chứng minh bằng E1: nhân
    /// tiền sẽ phá sổ — 2 × 19.48 ≠ 38.96 của dòng COKE).
    static let qtyAtPriceContributesCountOnly = true
    /// (ii) "k AT 1 FOR u a" kèm onePerLine (Walmart): dòng AT
    /// MANG TIỀN của món treo đứng cạnh; E3 đếm theo
    /// soldContribution của dữ liệu tiệm (v3), không hard-code.
    static let atLineCarriesHangAmount = true
    /// (iii) "TOTAL DEBIT PURCHASE 92.24" là TENDER (tiền rút
    /// kèm $20 cashback), không phải tổng — V4-1: họ TENDER
    /// thắng TOTAL ở tầng nhãn (Candidates.labelFamily).
    static let totalDebitPurchaseIsTender = true
    /// (iv) Dòng tender trùng giá trị tổng là CHỨNG THỰC lặp,
    /// không phải tổng thứ hai — V4-1: bậc chứng thực lặp trong
    /// thang phân định nghiệm.
    static let duplicateTenderCorroborates = true
}

/// Một token tiền ở tầng món: giá trị qua SafeMoney + nguyên văn
/// + khoảng utf16 trong dòng (phục vụ phần dư AT/tên/cờ thuế).
struct ItemMoneyToken {
    var cents: Int
    var text: String          // nguyên văn phần số, vd "19.48" / "$2,79"
    var range: NSRange        // khoảng của TOÀN BỘ match trong dòng
    var form: String          // dot | comma | commaBare
}

/// Kết quả phân loại một dòng cho tầng món.
struct ClassifiedItemLine {
    enum Kind {
        case skip          // ngày tháng / dòng trống ngữ nghĩa
        case weight        // dòng phụ cân "W lb @ $U/lb"
        case atLine        // dòng phụ AT thuần "k AT 1 FOR u a"
        case qtyLink       // dòng phụ "N @ u" đứng một mình
        case itemLine      // tiền + chữ → ứng viên món
        case fragment      // chỉ tiền → mảnh giá (món thiếu tên)
        case excluded      // họ SUBTOTAL/TOTAL/TAX/TENDER/CHANGE/TAXSUM
        case broken        // tiền gãy vật lý → món tiền = nil
        case hang          // tên + mã/INST, không tiền → món treo
        case nameOnly      // dòng tên chờ (mỹ quan + lấp tên mảnh)
    }
    var kind: Kind = .skip
    var tokens: [ItemMoneyToken] = []
    var family: String = "NONE"
    // Dành cho itemLine/fragment:
    var amountOptions: [Int] = []   // [số chính, biến thể hậu tố…]
    var primaryCents: Int? = nil
    var primaryTokenText: String = ""
    /// G2: giá trị tiền đọc được từ các bản đọc THAY THẾ của
    /// dòng (alternates) + biến thể hậu tố của chúng — chỉ
    /// thành PHƯƠNG ÁN ở lượt cứu của pha gán, không bao giờ
    /// vào amountOptions (đường chính không đổi).
    var variantValues: [Int] = []
    var unitPrices: [Int] = []      // token trước token cuối = GIÁ ĐƠN VỊ ứng viên
    var taxFlag: String? = nil      // chỉ Y/T (§4.1)
    var itemCode: String? = nil     // THUỘC TÍNH — không bao giờ là cổng
    // Dành cho dòng phụ:
    var qty: Int? = nil
    var unitCents: Int? = nil
    var amountCents: Int? = nil     // atLine: tiền dòng nó mang
    var weightLb: Double? = nil
    var weightUnitCents: Int? = nil
    /// Tiền tố AT trên chính dòng món: ("2 AT 1 FOR u a" là dòng
    /// tiền của món treo đứng cạnh — bố cục app Sam's).
    var atPrefix: (qty: Int, unit: Int, amount: Int)? = nil
    /// Tiền tố "N @ u" trên dòng món mang tiền khác (S-0).
    var floatingQty: (qty: Int, unit: Int)? = nil
    var brokenName: String? = nil
}

enum ItemLineClassifier {

    // Cùng mẫu/biên với CandidateFactory (P1-MONEY-BOUNDARY).
    private static let moneyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d[\d,]*\.\d{2})(?!\d)(-)?"#)
    private static let commaRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\$\s*(-?\d+),(\d{2})(?!\d)"#)
    private static let bareCommaRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d+),(\d{2})(?!\d)"#)
    private static let atStartRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^\s*(\d+)\s+AT\s+"#,
                                 options: [.caseInsensitive])
    private static let qtyAtRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^\s*(\d+)\s*@\s*"#)
    private static let dateSlashRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\d{1,2}/\d{1,2}/\d{2,4}"#)
    private static let dateMonthRegex: NSRegularExpression? =
        try? NSRegularExpression(
            pattern: #"\d{1,2}-(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)-\d{2,4}"#,
            options: [.caseInsensitive])
    private static let weightRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:lb|1b|Tb)"#)
    private static let weightUnitARegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\$\s*\*?\s*(\d[\d,]*\.\d{2})"#)
    private static let weightUnitBRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d[\d,]*\.\d{2})\s*/l"#)
    private static let brokenARegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^(.*?)\s*\$\s*([\d\s]+)$"#)
    private static let formCRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^\d+\.\d{1,2}[A-Za-z]$"#)
    private static let digitRunRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\d{7,}"#)
    private static let formWordRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\bAT\b|\bFOR\b"#)
    private static let flagRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^\s*([YT])(?![A-Za-z])"#)
    private static let leadCodeRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^\s*(\d+)"#)

    /// Mọi match của một mẫu kèm nhóm bắt + khoảng nhóm.
    private static func matches(
        _ re: NSRegularExpression?, _ text: String
    ) -> [(range: NSRange, groups: [String?], groupRanges: [NSRange])] {
        guard let re else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        return re.matches(in: text, range: full).map { m in
            var groups: [String?] = []
            var ranges: [NSRange] = []
            for g in 1..<m.numberOfRanges {
                let r = m.range(at: g)
                ranges.append(r)
                groups.append(r.location == NSNotFound ? nil
                              : ns.substring(with: r))
            }
            return (m.range, groups, ranges)
        }
    }

    private static func firstGroup(_ re: NSRegularExpression?,
                                   _ text: String) -> String? {
        matches(re, text).first?.groups.first ?? nil
    }

    static func hasLetter(_ text: String) -> Bool {
        text.contains { $0.isLetter }
    }

    // MARK: Quét token tiền (tầng món)

    /// Token chấm (cùng biên CandidateFactory: bỏ token mà ngay
    /// sau phần số là "%") + token phẩy '$' (gương lastCommaMoney
    /// của v3) + token phẩy trần — token phẩy trần CHỈ nhận khi
    /// dòng đã có token tiền khác (ngữ cảnh tiền xác lập; bằng
    /// chứng D-11 "39,96" — diễn giải đã khai trong HANDOFF).
    static func scanTokens(_ text: String) -> [ItemMoneyToken] {
        let ns = text as NSString
        var toks: [ItemMoneyToken] = []
        for m in matches(moneyRegex, text) {
            guard let g1 = m.groups[0] else { continue }
            let gr1 = m.groupRanges[0]
            guard gr1.location != NSNotFound else { continue }
            // Bỏ token suất: ký tự ngay sau phần số là "%".
            let after = gr1.location + gr1.length
            if after < ns.length,
               ns.substring(with: NSRange(location: after, length: 1)) == "%" {
                continue
            }
            guard let cents = SafeMoney.parseCents(
                g1, negative: (m.groups.count > 1 && m.groups[1] != nil))
            else { continue }
            toks.append(ItemMoneyToken(cents: cents, text: g1,
                                       range: m.range, form: "dot"))
        }
        for m in matches(commaRegex, text) {
            guard let wholeRaw = m.groups[0], let frac = m.groups[1]
            else { continue }
            let negative = wholeRaw.hasPrefix("-")
            let whole = negative ? String(wholeRaw.dropFirst()) : wholeRaw
            guard whole.count <= 12,
                  var cents = SafeMoney.parseCommaCents(whole: whole, frac: frac)
            else { continue }
            if negative { cents = -cents }
            if toks.contains(where: {
                NSIntersectionRange($0.range, m.range).length > 0 }) {
                continue
            }
            toks.append(ItemMoneyToken(
                cents: cents,
                text: ns.substring(with: m.range),
                range: m.range, form: "comma"))
        }
        if !toks.isEmpty {
            for m in matches(bareCommaRegex, text) {
                guard let whole = m.groups[0], let frac = m.groups[1],
                      whole.count <= 12 else { continue }
                if toks.contains(where: {
                    NSIntersectionRange($0.range, m.range).length > 0 }) {
                    continue
                }
                guard let cents = SafeMoney.parseCents("\(whole).\(frac)")
                else { continue }
                toks.append(ItemMoneyToken(
                    cents: cents,
                    text: ns.substring(with: m.range),
                    range: m.range, form: "commaBare"))
            }
        }
        return toks.sorted { $0.range.location < $1.range.location }
    }

    /// Biến thể hậu tố của token dính (tầng ocrVariant, CHỈ tầng
    /// món): bỏ k chữ số đầu của phần nguyên (k = 1…n−1, giữ ≥1
    /// chữ số). Mọi biến thể là chuỗi con in thật của token.
    static func suffixVariants(of token: ItemMoneyToken) -> [Int] {
        let cleaned = token.text.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
        let negative = cleaned.hasPrefix("-") || token.cents < 0
        let body = cleaned.hasPrefix("-") ? String(cleaned.dropFirst())
                                          : cleaned
        let parts = body.split(separator: ".")
        guard parts.count == 2 else { return [] }
        let whole = String(parts[0]), frac = String(parts[1])
        guard whole.count >= 5, frac.count == 2 else { return [] }
        var out: [Int] = []
        var seen: Set<Int> = [token.cents]
        for k in 1..<whole.count {
            let w = String(whole.dropFirst(k))
            guard var v = SafeMoney.parseCents("\(w).\(frac)") else {
                continue
            }
            if negative { v = -v }
            if !seen.contains(v) {
                seen.insert(v)
                out.append(v)
            }
        }
        return out
    }

    // MARK: Các dạng dòng phụ

    /// Gương weightLine của v3 (dạng "/lb"): (cân, đơn giá).
    static func weightParse(_ text: String) -> (lb: Double, unit: Int?)? {
        guard text.contains("/lb") || text.contains("/1b") else {
            return nil
        }
        guard let wText = firstGroup(weightRegex, text),
              let w = Double(wText), w.isFinite, w > 0, w <= 1_000_000
        else { return nil }
        var unit: Int? = nil
        if let u = firstGroup(weightUnitARegex, text) {
            unit = SafeMoney.parseCents(u)
        } else if let u = firstGroup(weightUnitBRegex, text) {
            unit = SafeMoney.parseCents(u)
        }
        return (w, unit)
    }

    /// Tên món của dòng tiền gãy — KHÔNG dựng lại số (gương
    /// brokenMoneyName của v3 + hai siết đã khai trong HANDOFF):
    /// (a) dạng "$131 57" (dấu thập phân mất, rác là khoảng
    /// trắng); (c) token chấm bị thay đúng một glyph ở phần lẻ
    /// ("19.9Z" — ca D-18); (b) token cuối là số hỏng: bắt đầu
    /// bằng chữ số, 3–5 chữ số, 2–3 chữ rác (≥6 chữ số là mã/ID;
    /// 1 chữ rác là token dung lượng kiểu "1280Z").
    static func brokenMoneyName(_ text: String) -> String? {
        if !matches(moneyRegex, text).isEmpty { return nil }
        if let m = matches(brokenARegex, text).first,
           let name = m.groups[0], let junk = m.groups[1],
           junk.filter({ $0.isNumber }).count >= 4, hasLetter(name) {
            return name.trimmingCharacters(in: .whitespaces)
        }
        let parts = text.split(separator: " ").map(String.init)
            .filter { !$0.isEmpty }
        guard let last = parts.last else { return nil }
        func nameBeforeLast() -> String? {
            guard let r = text.range(of: last, options: .backwards)
            else { return nil }
            let name = String(text[..<r.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            return (!name.isEmpty && hasLetter(name)) ? name : nil
        }
        if !matches(formCRegex, last).isEmpty {
            return nameBeforeLast()
        }
        let letters = last.filter { $0.isLetter }.count
        let digits = last.filter { $0.isNumber }.count
        if !last.contains("$"), !last.contains("."),
           !last.contains(","), last.first?.isNumber == true,
           digits >= 3, digits <= 5, letters >= 2, letters <= 3 {
            return nameBeforeLast()
        }
        return nil
    }

    /// Số chữ còn lại sau khi bỏ token tiền + từ dạng AT/FOR +
    /// số: nhận diện dòng phụ AT (chỉ còn cờ ≤2 chữ).
    static func formResidueLetters(_ text: String,
                                   toks: [ItemMoneyToken]) -> Int {
        let blanked = NSMutableString(string: text)
        for t in toks {
            blanked.replaceCharacters(
                in: t.range,
                with: String(repeating: " ",
                             count: t.range.length))
        }
        var rest = blanked.uppercased
        if let re = formWordRegex {
            rest = re.stringByReplacingMatches(
                in: rest,
                range: NSRange(location: 0,
                               length: (rest as NSString).length),
                withTemplate: " ")
        }
        return rest.filter { $0.isLetter }.count
    }

    private static let excludedFamilies: Set<String> =
        ["SUBTOTAL", "TOTAL", "TAX", "TENDER", "CHANGE", "TAXSUM"]

    // MARK: Phân loại một dòng

    static func classify(text: String, family: String,
                         alternates: [AltText] = []) -> ClassifiedItemLine {
        var c = ClassifiedItemLine()
        c.family = family
        let toks = scanTokens(text)
        c.tokens = toks
        // G2: giá trị alternate của dòng — mọi token tiền trong
        // các văn bản thay thế + biến thể hậu tố của chúng
        // (cùng cơ chế token dính như token chính: bản đọc
        // khác có thể dính mã món vào tiền, vd "1280219.97").
        for alt in alternates {
            for tok in scanTokens(alt.text) {
                for v in [tok.cents] + suffixVariants(of: tok)
                where !c.variantValues.contains(v) {
                    c.variantValues.append(v)
                }
            }
        }
        if !matches(dateSlashRegex, text).isEmpty
            || !matches(dateMonthRegex, text).isEmpty {
            c.kind = .skip
            return c
        }
        if let w = weightParse(text) {
            c.kind = .weight
            c.weightLb = w.lb
            c.weightUnitCents = w.unit
            return c
        }
        let atMatch = matches(atStartRegex, text).first
        if let am = atMatch, !toks.isEmpty,
           formResidueLetters(text, toks: toks) <= 2 {
            // Dòng phụ AT thuần. Còn đúng MỘT token: token đó là
            // TIỀN DÒNG (đơn giá là phần dễ hỏng trước — ca D-03
            // "13.9%"); dòng AT chỉ-có-đơn-giá vô nghĩa một mình.
            c.kind = .atLine
            c.qty = am.groups[0].flatMap { Int($0) }
            c.unitCents = toks.count >= 2 ? toks[0].cents : nil
            c.amountCents = toks[toks.count - 1].cents
            return c
        }
        let qtyMatch = matches(qtyAtRegex, text).first
        if let qm = qtyMatch, toks.count == 1 {
            let t = toks[0]
            var rest = text
            if let r = Range(t.range, in: text) {
                rest = String(text[..<r.lowerBound])
                     + String(text[r.upperBound...])
            }
            if rest.filter({ $0.isLetter }).count <= 1 {
                c.kind = .qtyLink
                c.qty = qm.groups[0].flatMap { Int($0) }
                c.unitCents = t.cents
                return c
            }
        }
        if let qm = qtyMatch, toks.count >= 2 {
            c.floatingQty = (qty: qm.groups[0].flatMap { Int($0) } ?? 1,
                             unit: toks[0].cents)
        }
        if let am = atMatch, !toks.isEmpty {
            c.atPrefix = (qty: am.groups[0].flatMap { Int($0) } ?? 1,
                          unit: toks[0].cents,
                          amount: toks[toks.count - 1].cents)
        }
        if !toks.isEmpty {
            if excludedFamilies.contains(family) {
                c.kind = .excluded
                return c
            }
            let last = toks[toks.count - 1]
            c.primaryCents = last.cents
            c.primaryTokenText = last.text
            c.amountOptions = [last.cents] + suffixVariants(of: last)
            c.unitPrices = toks.dropLast().map { $0.cents }
            let ns = text as NSString
            let suffixStart = last.range.location + last.range.length
            if suffixStart <= ns.length {
                let suffix = ns.substring(from: suffixStart)
                if let fm = matches(flagRegex, suffix).first {
                    c.taxFlag = fm.groups[0]
                }
            }
            if let cm = matches(leadCodeRegex, text).first,
               let code = cm.groups[0], code.count >= 4 {
                c.itemCode = code
            }
            c.kind = hasLetter(text) ? .itemLine : .fragment
            return c
        }
        if family != "NONE" {
            c.kind = .skip
            return c
        }
        if let name = brokenMoneyName(text), hasLetter(text) {
            c.kind = .broken
            c.brokenName = name
            return c
        }
        if hasLetter(text) {
            let hang = !matches(digitRunRegex, text).isEmpty
                || text.uppercased().contains("INST")
            c.kind = hang ? .hang : .nameOnly
            return c
        }
        c.kind = .skip
        return c
    }

    /// Cửa sổ khối món (§4.5): dải liên tục kết thúc ngay trước
    /// cửa sổ khối tổng; đi lên trong khi dòng còn "giống món"
    /// (có chữ hoặc có token tiền).
    static func itemsWindow(lines: [OCRLine],
                            classified: [ClassifiedItemLine],
                            totalsStart: Int) -> (start: Int, end: Int) {
        var start = totalsStart
        var j = totalsStart - 1
        while j >= 0 {
            if hasLetter(lines[j].text) || !classified[j].tokens.isEmpty {
                start = j
                j -= 1
            } else { break }
        }
        return (start, totalsStart)
    }
}

/// Ứng viên món đã lắp (đối tượng tham chiếu — pha nối/gán đột
/// biến trạng thái tại chỗ, đúng ngữ nghĩa danh tính của món).
final class ItemCandidate {
    var line: Int               // dòng gốc (dòng tên với món treo)
    var amountLine: Int         // dòng mang tiền (== line trừ món treo)
    var name: String
    var kind: String            // line | fragment | hang | broken | atOwn
    var amountOptions: [Int] = []
    /// G2: phương án từ bản đọc thay thế (chỉ lượt cứu dùng).
    var variantOptions: [Int] = []
    var primaryCents: Int? = nil
    var primaryTokenText: String = ""
    var qty: Int = 1
    var qtyLocked: Bool = false
    var unitPriceCents: Int? = nil
    var weightLb: Double? = nil
    var weightUnitCents: Int? = nil
    var weightLinked: Bool = false
    var taxFlag: String? = nil
    var itemCode: String? = nil
    var filled: Bool = false    // món treo đã được lấp tiền
    init(line: Int, name: String, kind: String) {
        self.line = line
        self.amountLine = line
        self.name = name
        self.kind = kind
    }
}

/// Một liên kết dòng phụ (§4.2) + trạng thái phân giải của nó.
struct ItemLink {
    var kind: String            // at | atPrefix | qty | weight
    var line: Int
    var qty: Int = 1
    var unitCents: Int? = nil
    var amountCents: Int? = nil
    var weightLb: Double? = nil
    var fromItemLine: Int? = nil   // qty nổi / atPrefix: dòng nguồn
    var state: String = "open"     // open | filledHang | … | unlinked
}

enum ItemCandidateFactory {

    /// Món gần nhất theo (khoảng cách, trước-trước, thứ tự dòng).
    private static func nearest(_ cands: [ItemCandidate],
                                line: Int) -> ItemCandidate? {
        cands.min { a, b in
            let da = abs(a.line - line), db = abs(b.line - line)
            if da != db { return da < db }
            let pa = a.line < line ? 0 : 1, pb = b.line < line ? 0 : 1
            if pa != pb { return pa < pb }
            return a.line < b.line
        }
    }

    static let linkWindow = 2

    /// Lắp ứng viên món trong cửa sổ + nối dòng phụ. Trả món
    /// (gồm món treo CHƯA lấp — pha gán quyết định trình bày) và
    /// các liên kết kèm trạng thái.
    static func buildItems(
        lines: [OCRLine], classified: [ClassifiedItemLine],
        window: (start: Int, end: Int)
    ) -> (items: [ItemCandidate], links: [ItemLink]) {
        var items: [ItemCandidate] = []
        var links: [ItemLink] = []
        var pending: [(line: Int, name: String)] = []
        var hangs: [ItemCandidate] = []
        func itemAt(_ line: Int) -> ItemCandidate? {
            items.first { $0.line == line }
        }
        for i in window.start..<window.end {
            let c = classified[i]
            let text = lines[i].text
            switch c.kind {
            case .nameOnly:
                pending.append((i, text.trimmingCharacters(
                    in: .whitespaces)))
            case .hang:
                let it = ItemCandidate(line: i, name: text
                    .trimmingCharacters(in: .whitespaces), kind: "hang")
                items.append(it)
                hangs.append(it)
            case .broken:
                let it = ItemCandidate(line: i, name: c.brokenName ?? "",
                                       kind: "broken")
                // G2: món gãy mang theo giá trị alternate — nó
                // chỉ vào bể ở LƯỢT CỨU của pha gán.
                it.variantOptions = c.variantValues
                items.append(it)
            case .itemLine, .fragment:
                let it = ItemCandidate(line: i, name: c.kind == .itemLine
                    ? text.trimmingCharacters(in: .whitespaces) : "",
                                       kind: c.kind == .itemLine
                    ? "line" : "fragment")
                it.amountOptions = c.amountOptions
                // G2: phương án alternate = giá trị alternate
                // chưa có trong phương án chính.
                it.variantOptions = c.variantValues.filter {
                    !c.amountOptions.contains($0)
                }
                it.primaryCents = c.primaryCents
                it.primaryTokenText = c.primaryTokenText
                it.unitPriceCents = c.unitPrices.first
                it.taxFlag = c.taxFlag
                it.itemCode = c.itemCode
                items.append(it)
                if let f = c.floatingQty {
                    links.append(ItemLink(kind: "qty", line: i,
                                          qty: f.qty, unitCents: f.unit,
                                          fromItemLine: i))
                }
                if let ap = c.atPrefix {
                    links.append(ItemLink(kind: "atPrefix", line: i,
                                          qty: ap.qty,
                                          unitCents: ap.unit,
                                          amountCents: ap.amount,
                                          fromItemLine: i))
                }
                // Mảnh giá có '@' + tích nguyên đúng → qty suy từ
                // tích in (§4.2 kiểm nhất quán; D-13 "@34.98 69.96").
                if c.kind == .fragment, text.contains("@"),
                   c.tokens.count >= 2 {
                    let u = c.tokens[0].cents
                    if let p = c.primaryCents, u > 0, p > 0,
                       p % u == 0, p / u >= 2, p / u <= 999 {
                        it.qty = p / u
                        it.qtyLocked = true
                    }
                }
            case .atLine:
                links.append(ItemLink(kind: "at", line: i,
                                      qty: c.qty ?? 1,
                                      unitCents: c.unitCents,
                                      amountCents: c.amountCents))
            case .qtyLink:
                links.append(ItemLink(kind: "qty", line: i,
                                      qty: c.qty ?? 1,
                                      unitCents: c.unitCents,
                                      fromItemLine: nil))
            case .weight:
                links.append(ItemLink(kind: "weight", line: i,
                                      unitCents: c.weightUnitCents,
                                      weightLb: c.weightLb))
            case .skip, .excluded:
                break
            }
        }
        // Tên chờ (mỹ quan): mảnh giá lấy tên dòng chờ gần nhất.
        for it in items where it.kind == "fragment" {
            if let near = pending.min(by: { a, b in
                let da = abs(a.line - it.line), db = abs(b.line - it.line)
                if da != db { return da < db }
                let pa = a.line < it.line ? 0 : 1
                let pb = b.line < it.line ? 0 : 1
                if pa != pb { return pa < pb }
                return a.line < b.line
            }) {
                it.name = near.name
            }
        }
        // --- Tiền tố AT trên dòng món → lấp món treo (dòng bị
        // TIÊU THỤ, không đứng thành món riêng — §4.2); không có
        // món treo thì qty thuộc về chính dòng đó. ---
        for li in links.indices where links[li].kind == "atPrefix" {
            guard let srcLine = links[li].fromItemLine,
                  let src = itemAt(srcLine) else { continue }
            let cands = hangs.filter {
                !$0.filled && abs($0.line - links[li].line) <= linkWindow
            }
            if let h = nearest(cands, line: links[li].line) {
                h.filled = true
                h.amountLine = links[li].line
                h.qty = links[li].qty
                h.qtyLocked = true
                h.unitPriceCents = links[li].unitCents
                if let amt = links[li].amountCents {
                    h.amountOptions = [amt]
                    h.primaryCents = amt
                }
                items.removeAll { $0 === src }
                links[li].state = "filledHangConsumed"
            } else if !src.qtyLocked {
                src.qty = links[li].qty
                src.qtyLocked = true
                if let u = links[li].unitCents {
                    src.unitPriceCents = u
                }
                links[li].state = "selfQty"
            }
        }
        // --- Nối AT → món treo (§4.4(ii): dòng AT MANG TIỀN) ---
        for li in links.indices where links[li].kind == "at" {
            let cands = hangs.filter {
                !$0.filled && abs($0.line - links[li].line) <= linkWindow
            }
            if let h = nearest(cands, line: links[li].line) {
                h.filled = true
                h.amountLine = links[li].line
                h.qty = links[li].qty
                h.qtyLocked = true
                h.unitPriceCents = links[li].unitCents
                if let amt = links[li].amountCents {
                    h.amountOptions = [amt]
                    h.primaryCents = amt
                }
                links[li].state = "filledHang"
            } else if let amt = links[li].amountCents {
                let it = ItemCandidate(line: links[li].line, name: "",
                                       kind: "atOwn")
                it.amountOptions = [amt]
                it.primaryCents = amt
                it.qty = links[li].qty
                it.qtyLocked = true
                it.unitPriceCents = links[li].unitCents
                items.append(it)
                links[li].state = "ownItem"
            }
        }
        // --- Nối cân (metadata; qty giữ 1 — kỷ luật của v3) ---
        for li in links.indices where links[li].kind == "weight" {
            let lk = links[li]
            var prod: Int? = nil
            if let lb = lk.weightLb, let u = lk.unitCents, u != 0 {
                prod = Int(lb * Double(u) + 0.5)
            }
            let cands = items.filter {
                $0.primaryCents != nil && !$0.weightLinked
                    && abs($0.line - lk.line) <= linkWindow
            }
            let matches = cands.filter {
                prod != nil && abs(prod! - $0.primaryCents!) <= 2
            }
            var tgt = nearest(matches, line: lk.line)
                ?? nearest(cands, line: lk.line)
            if tgt == nil {
                let brk = items.filter {
                    $0.kind == "broken"
                        && abs($0.line - lk.line) <= linkWindow
                }
                tgt = nearest(brk, line: lk.line)
            }
            if let t = tgt {
                t.weightLb = lk.weightLb
                t.weightUnitCents = lk.unitCents
                t.weightLinked = true
                links[li].state = matches.isEmpty
                    ? "linkedByPosition" : "linkedByProduct"
            }
        }
        // --- Nối N@ (chỉ E3 — §4.4(i): KHÔNG nhân tiền) ---
        for li in links.indices where links[li].kind == "qty" {
            let lk = links[li]
            let src = lk.fromItemLine.flatMap { itemAt($0) }
            if lk.fromItemLine != nil, src == nil {
                links[li].state = "consumedSource"
                continue
            }
            if let s = src, let p = s.primaryCents, !s.qtyLocked,
               let u = lk.unitCents,
               let prod = SafeMoney.checkedMultiply(lk.qty, by: u),
               abs(prod - p) <= 2 {
                s.qty = lk.qty
                s.qtyLocked = true
                links[li].state = "linkedSelfProduct"
                continue
            }
            let cands = items.filter {
                $0.primaryCents != nil && !$0.qtyLocked && $0 !== src
                    && abs($0.line - lk.line) <= linkWindow
            }
            let matches = cands.filter {
                guard let u = lk.unitCents,
                      let prod = SafeMoney.checkedMultiply(lk.qty, by: u),
                      let p = $0.primaryCents else { return false }
                return abs(prod - p) <= 2
            }
            if let t = nearest(matches, line: lk.line) {
                t.qty = lk.qty
                t.qtyLocked = true
                links[li].state = "linkedByProduct"
            } else if cands.count == 1, let t = cands.first {
                t.qty = lk.qty
                t.qtyLocked = true
                links[li].state = "linkedByPosition"
            } else if links[li].state == "open" {
                links[li].state = "unlinked"
            }
        }
        return (items, links)
    }
}

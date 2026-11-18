import Foundation

// =====================================================================
//  Candidates.swift — CORE-V4 · GÓI V4-1 (DESIGN-V4 §2)
//
//  Tầng SINH ỨNG VIÊN cho khối tổng/thuế. Nguyên tắc cứng (§0/§2):
//   - Giá trị ứng viên CHỈ lấy từ token đã in trên giấy, qua
//     SafeMoney. Tổng suy ra (tổng − thuế…) KHÔNG BAO GIỜ là ứng
//     viên (§3.6: thuế hàm ý không thành dòng thuế).
//   - Ứng viên KHÔNG bị xoá ở tầng sinh. Cổng hình dạng cứng của v3
//     (vd mã món đúng 10 số) bị thay bằng gợi ý cộng điểm (§2.6):
//     gợi ý chỉ XẾP HẠNG, không bao giờ là cổng loại trừ.
//   - Mọi ứng viên mang lineIndex + vị trí token (utf16) + tier +
//     feasibleRoles + hints kèm nguồn — provenance truy được tới
//     tận token (§3.7).
//
//  Phạm vi V4-1: ứng viên tiền + suất + nhãn cho KHỐI TỔNG/THUẾ.
//  Ứng viên món/qtyLink đầy đủ là V4-2. Gợi ý hình học (cột tiền,
//  +15) cần hộp dòng — cổng luồng (harness) không có hộp nên KHÔNG
//  khai ở gói này; ghi rõ ở CHECKS.md, không im lặng.
// =====================================================================

/// Nguồn gợi ý (§2.1). Chuỗi khớp từ vựng DESIGN-V4 §2.1/§2.6.
enum CandidateHintSource {
    static let labelAdjacency = "labelAdjacency"
    static let relativeGeometry = "relativeGeometry"
    static let vendorData = "vendorData"
    static let legacyProgram = "legacyProgram"
}

/// Một gợi ý chấm điểm trên ứng viên: cộng/trừ điểm kèm lý do.
/// Điểm CHỈ dùng xếp hạng khi trọng tài phải chọn thứ tự thử —
/// quyết định cuối luôn là khép sổ (§3.1), không phải điểm.
struct CandidateHint {
    var source: String
    var delta: Int
    var reason: String
}

/// Vai trò một token tiền CÓ THỂ mang (§2.1 feasibleRoles).
/// Chuỗi khớp vai trò của TotalCandidate (P1-CANDIDATES) để hồ sơ
/// chẩn đoán dùng chung một từ vựng.
enum MoneyRole {
    static let subtotal = "subtotal"
    static let tax = "tax"
    static let total = "total"
    static let itemAmount = "itemAmount"
    static let discount = "discount"
    static let tender = "tender"
    static let change = "change"
    static let promo = "promo"
    static let unassigned = "unassigned"
}

/// Ứng viên tiền (§2.1): một token tiền đã in + ngữ cảnh của nó.
struct MoneyCandidate {
    var id: Int
    var cents: Int            // QUA SafeMoney — nil thì không sinh
    var text: String          // nguyên văn token, vd "179.28"
    var negative: Bool        // hậu tố "-" kiểu "4.50-"
    var lineIndex: Int
    var utf16Start: Int       // vị trí token trong dòng (utf16)
    var utf16Length: Int
    var tier: String          // "primary" (V4-1) | ocrVariant | roiReread | legacyProposal
    var feasibleRoles: Set<String>
    var hints: [CandidateHint]
    var hintScore: Int { hints.reduce(0) { $0 + $1.delta } }
    /// G2 (tầng cứu): NHÓM XUNG ĐỘT — hai ứng viên cùng nhóm
    /// là hai BẢN ĐỌC của cùng một token in; một nghiệm không
    /// bao giờ dùng cả hai. Primary: nhóm = id của chính nó.
    /// ocrVariant trói theo THỨ TỰ token trong văn bản
    /// alternate vào token chính cùng thứ tự (nhóm = id của
    /// token chính đó); biến thể vượt số token chính của dòng
    /// dùng nhóm-chung-của-dòng (số âm, duy nhất theo dòng).
    var conflictGroup: Int = -1
}

/// Ứng viên suất thuế (§2.1 kind "rate"): token thập phân 3–4 số
/// lẻ (8.5170) hoặc dạng phần trăm (10.05%). Suất là THUỘC TÍNH
/// của dòng thuế, không phải tiền — mẫu biên tiền (?!\d) tồn tại
/// chính vì suất 3.9170 từng đẻ token tiền ma "3.91".
struct RateCandidate {
    var text: String          // phần số nguyên văn, vd "8.5170"
    var lineIndex: Int
}

/// Họ nhãn của một dòng (§2.6 chuẩn hoá chỉ-chữ + §4.4(c) họ
/// TENDER). Chuẩn hoá: hoa + bỏ khoảng trắng TRƯỚC khi đối chiếu,
/// nên "TAX1", "TAX 1", "Tax 1" là cùng một họ — v3 chết ở đúng
/// chỗ này (mẫu `TAX\s+(\d)` đòi khoảng trắng).
struct LineLabel {
    var family: String        // SUBTOTAL | TOTAL | TAX | TENDER | CHANGE | TAXSUM | GIFTCERT | PROMO | NONE
    var rank: Int?            // TAX1 → 1
    var labelOnly: Bool       // dòng chỉ có nhãn, không token tiền
}

enum CandidateFactory {

    // Mẫu token tiền CÓ VỊ TRÍ — cùng ngữ nghĩa biên với
    // Parser.moneyTokensWithBoundary (P1-MONEY-BOUNDARY):
    // (?!\d) sau \d{2} chặn token ma từ suất (3.9170) và số dài.
    private static let moneyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d[\d,]*\.\d{2})(?!\d)(-)?"#)

    // Mẫu token tiền GÃY KHOẢNG TRẮNG (hồ sơ Gate D, ca
    // WR-dollartree-1): một khoảng trắng xẻ đôi token tại biên
    // thập phân — dạng chấm "5. 00" (mọi dòng) và dạng trần
    // "5 25" / "0 25" (CHỈ dòng mang nhãn khối tổng: ngoài
    // ngữ cảnh nhãn, cặp <số nguyên> + <2 số> quá dễ là số
    // lượng đứng cạnh giá). (?<![\d.]) chặn khớp đứng giữa
    // một số thập phân khác; (?![\d.]) chặn phần lẻ dính một
    // phần thập phân phía sau ("1 25.00" là số lượng + giá
    // 25.00, không phải 1.25).
    private static let spaceDotMoneyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(?<![\d.])(\d[\d,]*)\.\s(\d{2})(?![\d.])"#)
    private static let spaceBareMoneyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(?<![\d.])(\d[\d,]*)\s(\d{2})(?![\d.])"#)

    // Suất: 1–3 số nguyên + 3–4 số lẻ (8.5170, 4.0170), hoặc
    // 2–4 số lẻ kèm dấu % (10.05%, 8.517% — dạng 3 số lẻ + %
    // của Costco từng lọt khỏi mẫu hẹp hơn).
    private static let rateRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,3}\.\d{3,4}|\d{1,3}\.\d{2,4}\s*%)"#)

    /// F6 (hồ sơ GATE100-R41, lớp T7): dấu trừ ĐẦU token —
    /// dạng in "-0.08" của Lowe's (trừ đứng trước số, dính
    /// sát hoặc cách đúng một khoảng trắng). moneyRegex giữ
    /// NGUYÊN (chỉ số nhóm + khoảng token không đổi): hàm
    /// này nhìn ký tự ngay trước token trong dòng. Chỉ nhận
    /// khi dòng có ngữ cảnh giảm giá (DISCOUNT/COUPON/
    /// SAVINGS) — biện pháp giảm thiểu của hồ sơ: dấu gạch
    /// trang trí/ngăn cách trước số tiền trên dòng thường
    /// không bị hiểu thành âm.
    private static func leadingMinusNegates(line: String,
                                            tokenStart: Int) -> Bool {
        let upper = line.uppercased()
        guard upper.contains("DISCOUNT") || upper.contains("COUPON")
            || upper.contains("SAVINGS") else { return false }
        let ns = line as NSString
        var i = tokenStart - 1
        if i >= 0,
           ns.substring(with: NSRange(location: i, length: 1)) == " " {
            i -= 1
        }
        guard i >= 0 else { return false }
        let ch = ns.substring(with: NSRange(location: i, length: 1))
        return ch == "-" || ch == "−"
    }

    // MARK: - Họ nhãn

    /// Phân họ nhãn cho MỘT dòng. Thứ tự kiểm là luật in
    /// (§4.4(c)): họ TENDER thắng họ TOTAL — dòng "TOTAL DEBIT
    /// PURCHASE 92.24" là dòng THANH TOÁN (gồm $20 cash-back),
    /// không bao giờ là neo tổng. Đây là ca bẫy L-R09.
    /// V4-3 (§2.7): `vendorVariants` là BIẾN THỂ NHÃN RIÊNG của
    /// tiệm đã nhận diện, đọc từ DỮ LIỆU vendors.json (tiền tố
    /// nhãn đã gập trắng → họ nhãn) — tra TRƯỚC luật chung;
    /// không khớp thì rơi xuống luật chung nguyên vẹn. Đây là
    /// đường ống dữ liệu gợi ý, không phải rẽ nhánh theo tiệm:
    /// biến thể khai cho Sam's ("TAX1" → TAX) cho cùng kết quả
    /// với luật chung, và gợi ý của tiệm A áp lên tờ tiệm B tệ
    /// nhất chỉ lệch điểm, không mất trường (§2.7).
    static func labelFamily(of text: String, hasMoney: Bool,
                            vendorVariants: [String: String]? = nil) -> LineLabel {
        let squashed = text.uppercased().filter { !$0.isWhitespace }
        func make(_ family: String, _ rank: Int? = nil) -> LineLabel {
            LineLabel(family: family, rank: rank, labelOnly: !hasMoney)
        }
        if let variants = vendorVariants, !variants.isEmpty {
            // Tiền tố dài hơn thắng (xác định, không phụ thuộc
            // thứ tự băm của Dictionary).
            for prefix in variants.keys.sorted(by: { $0.count > $1.count }) {
                guard squashed.hasPrefix(prefix),
                      let family = variants[prefix] else { continue }
                var rank: Int? = nil
                if family == "TAX" {
                    for ch in squashed.dropFirst(prefix.count) {
                        if ch.isNumber { rank = Int(String(ch)) }
                        break
                    }
                }
                return make(family, rank)
            }
        }
        // Dòng đếm số lượng ("TOTAL NUMBER OF ITEMS SOLD = 12")
        // không phải nhãn tiền — nó từng đầu độc neo tổng qua
        // luật thừa kế tách dòng (ca L-R01, mô phỏng V4-1).
        if squashed.contains("ITEMS") || squashed.contains("ITEMCOUNT") {
            return make("NONE")
        }
        // "TOTAL TAX"/"TAX TOTAL" = dòng TỔNG THUẾ: giá trị kiểm
        // (tổng các dòng thuế thành phần), không phải neo tổng,
        // cũng không phải một dòng thuế thành phần.
        if squashed.hasPrefix("TOTALTAX") || squashed.hasPrefix("TAXTOTAL") {
            return make("TAXSUM")
        }
        // CHANGE đứng sau CASHBACK: "DEBIT CASH BACK" là tender.
        if squashed.contains("CASHBACK") { return make("TENDER") }
        if squashed.contains("CHANGE") { return make("CHANGE") }
        if squashed.contains("DEBIT") || squashed.contains("CREDIT")
            || squashed.contains("TEND") || squashed.contains("PURCHASE") {
            return make("TENDER")
        }
        if squashed.contains("SUBTOTAL") { return make("SUBTOTAL") }
        // P2-0/C-5 (dư): họ TIP — dòng tip ("TIP", "SUGGESTED
        // TIP") không phải dòng món cũng không phải neo tiền;
        // tầng món loại cứng họ này (excludedFamilies), tầng
        // sinh giữ vai trò mặc định như NONE trước đây.
        if squashed.hasPrefix("TIP") || squashed.contains("SUGGESTEDTIP") {
            return make("TIP")
        }
        // P2-0/C-13: "TAXABLE …" (dòng ghi số tiền CHỊU thuế),
        // "TAX EXEMPT" và "TAX ID" KHÔNG phải dòng thuế — bản
        // cũ rơi vào họ TAX theo tiền tố và đầu độc bể thuế.
        if squashed.hasPrefix("TAXABLE") || squashed.hasPrefix("TAXEXEMPT")
            || squashed.hasPrefix("TAXID") {
            return make("NONE")
        }
        if squashed.hasPrefix("TAX") || squashed.hasPrefix("SALESTAX") {
            var rank: Int? = nil
            // Hạng = số đầu tiên sau tiền tố TAX đã bỏ khoảng trắng
            // ("TAX1" → 1; "TAX 2" đã ép thành "TAX2" → 2).
            let rest = squashed.hasPrefix("SALES")
                ? squashed.dropFirst(5) : squashed[...]
            if rest.hasPrefix("TAX") {
                for ch in rest.dropFirst(3) {
                    if ch.isNumber { rank = Int(String(ch)); break }
                    break
                }
            }
            return make("TAX", rank)
        }
        // F5 (hồ sơ GATE100-R41, lớp T2): "Order Total" là
        // nhãn TẠM TÍNH theo ngữ nghĩa in của Publix (phía
        // sau còn dòng Grand Total) — nhận họ SUBTOTAL TRƯỚC
        // luật contains("TOTAL"); nếu không, token của nó bị
        // khoá vai trò total và khối không khép được (ca
        // 10-publix-1). Tiệm nào dùng "Order Total" làm tổng
        // cuối: khép E2 tự phủ quyết vai trò subtotal khi
        // không có thuế đi kèm, ca rơi về best-effort như cũ.
        if squashed.hasPrefix("ORDERTOTAL") { return make("SUBTOTAL") }
        // L1 ca 06-kroger-1 (hồ sơ GATE100-R41, lớp T6): dòng
        // biên lai quẹt thẻ EMV mang MẶT NẠ THẺ dài kèm chữ
        // TOTAL ("************5171 - C TOTAL: 6.47") là dòng
        // TENDER — phần trả bằng thẻ của một lần trả tách —
        // KHÔNG phải tổng hoá đơn. Không chặn, token của nó
        // thành neo tổng cuối khối và best-effort trình nó làm
        // tổng (647 thay vì tổng thật 1065 trên dòng BALANCE).
        // Luật chỉ chạm dòng mang dãy mặt nạ ≥ 6 ký tự: dòng
        // tổng in thường không bao giờ mang mặt nạ thẻ.
        if squashed.contains("TOTAL"), hasLongCardMask(text) {
            return make("TENDER")
        }
        if squashed.contains("TOTAL") || squashed.contains("AMOUNTDUE")
            || squashed.contains("BALANCEDUE") {
            return make("TOTAL")
        }
        // Họ GIFTCERT / PROMO (hồ sơ Gate D, ca WR-bestbuy-1):
        // dòng chứng từ quà tặng ("GIFT CERT", "FREE GIFT
        // CARD") và dòng khuyến mãi/trả giá ("PRICE MATCH",
        // "PROMO") không phải dòng món, cũng không phải neo
        // tổng. Đặt SAU họ TOTAL để các dòng tổng hợp đã mang
        // họ cũ (vd "TOTAL GIFT CARD VALUE") giữ nguyên hành
        // vi tầng tổng; tầng món loại CỨNG cả hai họ này
        // (ItemLineClassifier.excludedFamilies).
        if squashed.contains("GIFTCERT") || squashed.contains("GIFTCARD") {
            return make("GIFTCERT")
        }
        if squashed.contains("PROMO") || squashed.contains("PRICEMATCH") {
            return make("PROMO")
        }
        return make("NONE")
    }

    /// Dãy ký tự mặt nạ thẻ liên tiếp dài ≥ 6 (*, •, ●) —
    /// dấu hiệu dòng biên lai thanh toán (EMV/tender), dùng
    /// bởi luật L1 ca 06-kroger-1 trong labelFamily.
    private static func hasLongCardMask(_ text: String) -> Bool {
        var run = 0
        for ch in text {
            if ch == "*" || ch == "•" || ch == "●" {
                run += 1
                if run >= 6 { return true }
            } else {
                run = 0
            }
        }
        return false
    }

    // MARK: - Sinh ứng viên

    /// Sinh toàn bộ ứng viên từ các dòng đã chuẩn hoá (cùng mảng
    /// dòng mà ReceiptParser.parse nhìn thấy — lineIndex khớp).
    /// V4-3: `vendorVariants` (dữ liệu gợi ý của tiệm đã nhận
    /// diện) được truyền xuống labelFamily — xem chú thích ở đó.
    static func generate(lines: [OCRLine],
                         vendorVariants: [String: String]? = nil)
        -> (money: [MoneyCandidate], rates: [RateCandidate], labels: [LineLabel]) {
        var money: [MoneyCandidate] = []
        var rates: [RateCandidate] = []
        var labels: [LineLabel] = []
        var nextID = 0

        for (i, line) in lines.enumerated() {
            let ns = line.text as NSString
            let full = NSRange(location: 0, length: ns.length)

            // --- Token tiền (có vị trí) ---
            var lineMoney: [(cents: Int, text: String, negative: Bool,
                             start: Int, length: Int)] = []
            if let re = moneyRegex {
                for m in re.matches(in: line.text, range: full) {
                    let tokenRange = m.range(at: 1)
                    guard tokenRange.location != NSNotFound else { continue }
                    let token = ns.substring(with: tokenRange)
                    // Token tiền bị dấu % bám ngay sau là SUẤT
                    // (10.05%) — không sinh ứng viên tiền.
                    let afterEnd = tokenRange.location + tokenRange.length
                    if afterEnd < ns.length,
                       ns.substring(with: NSRange(location: afterEnd, length: 1)) == "%" {
                        continue
                    }
                    let negative = m.range(at: 2).location != NSNotFound
                        || leadingMinusNegates(line: line.text,
                                               tokenStart: tokenRange.location)
                    guard let cents = SafeMoney.parseCents(token, negative: negative)
                    else { continue }   // ngoài miền: bỏ TOKEN, không bỏ dòng
                    lineMoney.append((cents, token, negative,
                                      tokenRange.location, tokenRange.length))
                }
            }

            let label = labelFamily(of: line.text, hasMoney: !lineMoney.isEmpty,
                                    vendorVariants: vendorVariants)
            labels.append(label)

            // --- Vai trò khả thi theo họ nhãn (§2.6) ---
            // Tính MỘT lần theo họ, độc lập với token chính:
            // dòng không có token chính vẫn có thể có token
            // BIẾN THỂ cần vai trò (dòng nhãn in gãy — G2).
            // TAXSUM: giá trị kiểm — ứng viên vẫn được SINH
            // (luật không xoá ở tầng sinh) nhưng không mang vai
            // trò khả thi nào: không neo, không vào bể.
            let lineRoles: Set<String>
            switch label.family {
            case "SUBTOTAL": lineRoles = [MoneyRole.subtotal]
            case "TOTAL": lineRoles = [MoneyRole.total]
            case "TAX": lineRoles = [MoneyRole.tax]
            case "TENDER": lineRoles = [MoneyRole.tender]
            case "CHANGE": lineRoles = [MoneyRole.change]
            case "GIFTCERT": lineRoles = [MoneyRole.tender]
            case "PROMO": lineRoles = [MoneyRole.promo]
            case "TAXSUM": lineRoles = []
            default:
                lineRoles = [MoneyRole.subtotal, MoneyRole.tax, MoneyRole.total,
                             MoneyRole.itemAmount, MoneyRole.discount,
                             MoneyRole.tender]
            }
            var primaryIDs: [Int] = []
            for t in lineMoney {
                let roles = lineRoles
                var hints: [CandidateHint] = []
                switch label.family {
                case "SUBTOTAL":
                    hints.append(CandidateHint(
                        source: CandidateHintSource.labelAdjacency, delta: 40,
                        reason: "cùng dòng nhãn SUBTOTAL"))
                case "TOTAL":
                    hints.append(CandidateHint(
                        source: CandidateHintSource.labelAdjacency, delta: 40,
                        reason: "cùng dòng nhãn TOTAL"))
                case "TAX":
                    hints.append(CandidateHint(
                        source: CandidateHintSource.labelAdjacency, delta: 35,
                        reason: "cùng dòng nhãn TAX"))
                default:
                    break
                }
                money.append(MoneyCandidate(
                    id: nextID, cents: t.cents, text: t.text,
                    negative: t.negative, lineIndex: i,
                    utf16Start: t.start, utf16Length: t.length,
                    tier: "primary", feasibleRoles: roles, hints: hints,
                    conflictGroup: nextID))
                primaryIDs.append(nextID)
                nextID += 1
            }

            // --- G2: token BIẾN THỂ (tier ocrVariant, §2.6) ---
            // Bản đọc thay thế của ĐÚNG dòng này (OCRLine
            // .alternates: topCandidates của Vision + dòng
            // tương ứng của các lượt đọc khác của cùng ảnh).
            // Quét bằng ĐÚNG mẫu biên tiền + luật % + SafeMoney
            // như token chính — chỉ chuỗi đã thật sự đọc được
            // mới thành ứng viên, không bịa số. Trói theo THỨ
            // TỰ token: biến thể thứ k trói vào token chính thứ
            // k của dòng (cùng nhóm xung đột); trùng giá trị với
            // token chính đã trói thì BỎ (không phải bằng chứng
            // mới). Biến thể mang vai trò theo họ nhãn của dòng
            // nhưng KHÔNG mang gợi ý — không bao giờ vượt mặt
            // token chính trong thứ tự hồ. Trần 6 biến thể/dòng.
            if !line.alternates.isEmpty, let re = moneyRegex {
                var seenVariantKeys = Set<String>()
                var variantCount = 0
                for alt in line.alternates {
                    if variantCount >= 6 { break }
                    // THỪA KẾ NGỮ CẢNH TENDER (hồ sơ Gate D, ca
                    // L-R09 — nghi cơ chế D): alternate là bản
                    // đọc của một LƯỢT KHÁC; nếu chính văn bản
                    // alternate mang họ cứng TENDER / CHANGE /
                    // TAXSUM (vd dòng "TOTAL DEBIT PURCHASE
                    // 92.24" của lượt thua ráp vào dòng chủ
                    // TOTAL), token biến thể phải GIỮ họ đó —
                    // không được mượn vai trò của dòng chủ rồi
                    // thành ứng viên tổng/thuế thường ở mọi bể.
                    // Luật chỉ THU HẸP: họ cứng của alternate
                    // thắng; ngoài ra giữ nguyên vai trò dòng
                    // chủ, không bao giờ nới rộng.
                    let altFamily = labelFamily(
                        of: alt.text, hasMoney: true,
                        vendorVariants: vendorVariants).family
                    let altRoles: Set<String>
                    switch altFamily {
                    case "TENDER": altRoles = [MoneyRole.tender]
                    case "CHANGE": altRoles = [MoneyRole.change]
                    case "TAXSUM": altRoles = []
                    default: altRoles = lineRoles
                    }
                    let ans = alt.text as NSString
                    let afull = NSRange(location: 0, length: ans.length)
                    var ordinal = 0
                    for m in re.matches(in: alt.text, range: afull) {
                        if variantCount >= 6 { break }
                        let tr = m.range(at: 1)
                        guard tr.location != NSNotFound else { continue }
                        let token = ans.substring(with: tr)
                        let afterEnd = tr.location + tr.length
                        if afterEnd < ans.length,
                           ans.substring(with: NSRange(location: afterEnd, length: 1)) == "%" {
                            continue   // token suất: không chiếm thứ tự
                        }
                        let negative = m.range(at: 2).location != NSNotFound
                            || leadingMinusNegates(line: alt.text,
                                                   tokenStart: tr.location)
                        guard let cents = SafeMoney.parseCents(token, negative: negative)
                        else { continue }   // không parse được: không chiếm thứ tự
                        let myOrdinal = ordinal
                        ordinal += 1
                        let key = "\(myOrdinal)|\(cents)"
                        if !seenVariantKeys.insert(key).inserted { continue }
                        let group: Int
                        if myOrdinal < primaryIDs.count {
                            group = primaryIDs[myOrdinal]
                            if lineMoney[myOrdinal].cents == cents { continue }
                        } else {
                            group = -(1_000_000 + i)
                        }
                        money.append(MoneyCandidate(
                            id: nextID, cents: cents, text: token,
                            negative: negative, lineIndex: i,
                            utf16Start: tr.location, utf16Length: tr.length,
                            tier: "ocrVariant", feasibleRoles: altRoles,
                            hints: [], conflictGroup: group))
                        nextID += 1
                        variantCount += 1
                    }
                }
            }

            // --- Token tiền GÃY KHOẢNG TRẮNG (tier
            // ocrVariant; hồ sơ Gate D, ca WR-dollartree-1) ---
            // Giá trị GỘP từ một token in bị khoảng trắng xẻ
            // đôi tại biên thập phân ("$5. 00", "$0 25",
            // "$5 25"): bản đọc biến thể của token đã in, cùng
            // tầng với alternate — chỉ vào được qua tầng cứu
            // với khép DUY NHẤT (AMD-V4-01 nguyên vẹn), mang
            // provenance closureVariant; nguyên văn token gãy
            // giữ trong `text` để truy vết (§3.7). Trùng giá
            // trị token chính của dòng thì bỏ (không phải bằng
            // chứng mới); trần 3 biến thể/dòng; nhóm xung đột
            // dùng nhóm-chung-của-dòng như biến thể alternate
            // vượt trần.
            do {
                var spaceSeen = Set(lineMoney.map { $0.cents })
                var spaceCount = 0
                let totalsLabelled = label.family == "SUBTOTAL"
                    || label.family == "TAX" || label.family == "TOTAL"
                    || label.family == "TAXSUM"
                let spacePatterns = totalsLabelled
                    ? [spaceDotMoneyRegex, spaceBareMoneyRegex]
                    : [spaceDotMoneyRegex]
                for reOpt in spacePatterns {
                    guard let re = reOpt else { continue }
                    for m in re.matches(in: line.text, range: full) {
                        if spaceCount >= 3 { break }
                        let wr = m.range(at: 1)
                        let fr = m.range(at: 2)
                        guard wr.location != NSNotFound,
                              fr.location != NSNotFound,
                              let cents = SafeMoney.parseCents(
                                  "\(ns.substring(with: wr)).\(ns.substring(with: fr))")
                        else { continue }
                        if !spaceSeen.insert(cents).inserted { continue }
                        money.append(MoneyCandidate(
                            id: nextID, cents: cents,
                            text: ns.substring(with: m.range),
                            negative: false, lineIndex: i,
                            utf16Start: m.range.location,
                            utf16Length: m.range.length,
                            tier: "ocrVariant", feasibleRoles: lineRoles,
                            hints: [],
                            conflictGroup: -(1_000_000 + i)))
                        nextID += 1
                        spaceCount += 1
                    }
                }
            }

            // --- Token suất ---
            if let re = rateRegex {
                for m in re.matches(in: line.text, range: full) {
                    let r = m.range(at: 1)
                    guard r.location != NSNotFound else { continue }
                    var text = ns.substring(with: r)
                    // Dạng "10.05 %" → giữ phần số "10.05" (khớp
                    // rateText của v3: "8.5170").
                    text = text.filter { !$0.isWhitespace && $0 != "%" }
                    // Token thập phân 4 số lẻ KHÔNG được trùng một
                    // token tiền (không xảy ra theo mẫu biên, nhưng
                    // giữ kỷ luật: suất không đẻ từ tiền).
                    rates.append(RateCandidate(text: text, lineIndex: i))
                }
            }
        }
        return (money, rates, labels)
    }

    /// Suất đi kèm một dòng thuế: tìm ở chính dòng tiền, dòng
    /// nhãn (dạng nhãn/tiền hai dòng), hoặc dòng NGAY SAU dòng
    /// tiền — dạng in tách dòng của Sam's ("TAX2 3.82" rồi dòng
    /// kế "4.0170 ₴"): suất là thuộc tính của dòng thuế (§3.2
    /// pha 2), theo cặp in chứ không theo vị trí cứng.
    static func rateText(forTaxLine moneyLine: Int, labelLine: Int?,
                         rates: [RateCandidate]) -> String? {
        var probe = [moneyLine, moneyLine + 1]
        if let ll = labelLine { probe.append(ll) }
        for idx in probe {
            if let r = rates.first(where: { $0.lineIndex == idx }) {
                return r.text
            }
        }
        return nil
    }

    /// Token tiền có SUẤT ĐỠ: một token suất nằm trên cùng dòng
    /// hoặc dòng ngay sau — bằng chứng in rằng token là thành
    /// phần thuế (dòng phân rã thuế của Costco luôn đi kèm suất).
    /// Trọng tài dùng làm bằng chứng phân định nghiệm (§3.4) và
    /// điều kiện vào bể thuế (§3.2 pha 2).
    static func rateSupported(lineIndex: Int, rates: [RateCandidate]) -> Bool {
        rates.contains { $0.lineIndex == lineIndex || $0.lineIndex == lineIndex + 1 }
    }
}

// =====================================================================
//  V4-3 — Ứng viên THẺ (§2.3(f)) + NGÀY/GIỜ (§2.3(g))
//
//  Thay các cổng đơn-phát của v3 (findCard/findDateTime của
//  Parser.swift — giữ nguyên cho đường v3 đối chứng) bằng SINH
//  ỨNG VIÊN + CHỌN THEO BẰNG CHỨNG, một đường cho mọi tiệm.
// =====================================================================

/// Ứng viên đuôi thẻ: một cụm 4 số đứng riêng có ngữ cảnh giống
/// thẻ (mặt nạ che hoặc dòng hãng/tender) trên một dòng in.
struct CardCandidate {
    var last4: String
    var lineIndex: Int
    var score: Int            // điểm bằng chứng của RIÊNG dòng này
    var source: String        // "mask" | "tender"
}

enum CardCandidateFactory {

    private static let tailRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(?<!\d)(\d{4})(?!\d)"#)
    private static let maskRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"[*•●]{2,}|[Xx]{3,}"#)
    private static let tenderWordRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\b(DEBIT|CREDIT)\b"#,
                                 options: [.caseInsensitive])
    // Dòng định danh thiết bị/giao dịch mang mặt nạ + 4 số
    // (MID: ********2882 trên ca L-R02) — đó là SỐ HIỆU, không
    // phải đuôi thẻ: trừ nặng để không thắng ứng viên thẻ thật.
    private static let idLabelRegex: NSRegularExpression? =
        try? NSRegularExpression(
            pattern: #"\b(MID|AID|REF|TERMINAL|AUTH|SEQ|TRACE|INVOICE)\b|TC#"#,
            options: [.caseInsensitive])
    private static let brandWords = ["MASTERCARD", "MASTER CARD", "VISA",
                                     "AMEX", "AMERICAN EXPRESS", "DISCOVER"]

    /// Sinh ứng viên từ mọi dòng có dãy số/mặt nạ giống thẻ:
    /// mặt nạ sao/chấm/X kể cả HỎNG (cụm sao lệch nhịp như
    /// "**** **** * ** 2586" của ca D-06, đuôi dính liền mặt nạ)
    /// và dòng hãng/tender mang đúng 4 số đứng riêng (dạng
    /// "MASTERCARD 2586", "US DEBIT - 2586"). Số dài nguyên
    /// dãy không bao giờ thành ứng viên: đuôi phải là cụm 4 số
    /// ĐỨNG RIÊNG (biên (?<!\d)/(?!\d)) và dòng hãng/tender có
    /// ≥3 cụm 4 số (giống dãy PAN/TC#) không sinh ứng viên.
    static func generate(lines: [OCRLine]) -> [CardCandidate] {
        var out: [CardCandidate] = []
        for (i, line) in lines.enumerated() {
            let text = line.text
            let ns = text as NSString
            let full = NSRange(location: 0, length: ns.length)
            let upper = text.uppercased()
            let tails: [(value: String, start: Int)] =
                (tailRegex?.matches(in: text, range: full) ?? []).compactMap { m in
                    let r = m.range(at: 1)
                    guard r.location != NSNotFound else { return nil }
                    return (ns.substring(with: r), r.location)
                }
            if tails.isEmpty { continue }
            let masks: [NSRange] =
                (maskRegex?.matches(in: text, range: full) ?? []).map { $0.range }
            let hasBrand = brandWords.contains { upper.contains($0) }
            let hasTender = (tenderWordRegex?.firstMatch(in: text, range: full)) != nil
            let idPenalty = (idLabelRegex?.firstMatch(in: text, range: full)) != nil
                ? -50 : 0
            for tail in tails {
                var best: Int? = nil
                var source = ""
                for mr in masks {
                    let maskEnd = mr.location + mr.length
                    if maskEnd <= tail.start && tail.start - maskEnd <= 3 {
                        if best == nil || best! < 20 { best = 20; source = "mask" }
                    }
                }
                if (hasBrand || hasTender) && tails.count <= 2 {
                    let v = hasBrand ? 40 : 30
                    if best == nil || best! < v { best = v; source = "tender" }
                }
                guard let b = best else { continue }
                out.append(CardCandidate(last4: tail.value, lineIndex: i,
                                         score: b + idPenalty, source: source))
            }
        }
        return out
    }

    /// Chọn đuôi thẻ theo tổng điểm bằng chứng: cộng dồn qua
    /// các dòng (nhiều dòng cùng đuôi = corroboration, §2.3(f)),
    /// cộng điểm vùng tender (dòng ở/ sau dòng TOTAL/TENDER đầu
    /// tiên). Hai đuôi KHÁC nhau đồng điểm cao nhất = TRANH
    /// CHẤP: không chọn thầm — last4 = nil, disputed = true,
    /// caller gắn cờ. Không ứng viên → nil lặng (cờ do
    /// validate xử như cũ khi thẻ vắng).
    static func extract(lines: [OCRLine])
        -> (last4: String?, brand: String?, confidence: Double,
            disputed: Bool, trace: [String]) {
        let candidates = generate(lines: lines)
        // Vùng tender: từ dòng đầu tiên mang họ TOTAL/TENDER.
        let families = lines.map {
            CandidateFactory.labelFamily(of: $0.text, hasMoney: false).family
        }
        let zoneStart = families.firstIndex { $0 == "TOTAL" || $0 == "TENDER" }
        var totals: [String: (score: Int, lines: Set<Int>, bestLine: Int, bestScore: Int)] = [:]
        for c in candidates {
            var slot = totals[c.last4] ?? (0, [], c.lineIndex, Int.min)
            slot.score += c.score
            slot.lines.insert(c.lineIndex)
            if c.score > slot.bestScore {
                slot.bestScore = c.score
                slot.bestLine = c.lineIndex
            }
            totals[c.last4] = slot
        }
        for (tail, slot) in totals {
            if let z = zoneStart, slot.lines.contains(where: { $0 >= z }) {
                var s = slot
                s.score += 15
                totals[tail] = s
            }
        }
        if totals.isEmpty {
            return (nil, extractBrand(lines: lines), 0, false,
                    ["card: không ứng viên"])
        }
        let ranked = totals.sorted { $0.value.score > $1.value.score }
        let top = ranked[0]
        if ranked.count > 1 && ranked[1].value.score >= top.value.score {
            return (nil, extractBrand(lines: lines), 0, true,
                    ["card: tranh chấp \(ranked[0].key)/\(ranked[1].key) cùng điểm \(top.value.score)"])
        }
        let conf = lines[top.value.bestLine].confidence
        // P2-0/C-4: hãng lấy TỪ DÒNG CỦA ĐUÔI THẮNG trước —
        // bản cũ lấy dòng hãng đầu tiên của cả tờ nên tờ hai
        // thẻ ghi hãng của thẻ thua.
        let brand = extractBrand(lines: lines,
                                 winningLine: top.value.bestLine)
        return (top.key, brand, conf, false,
                ["card: \(top.key) điểm \(top.value.score) từ \(top.value.lines.count) dòng"])
    }

    /// Tên hãng (chưa kèm hậu tố Debit) trên MỘT dòng — nil khi
    /// dòng không chứa tên hãng nào.
    private static func brandName(onLine upper: String) -> String? {
        for b in brandWords where upper.contains(b) {
            var name = b == "MASTER CARD" ? "Mastercard" : b.capitalized
            if b == "AMEX" || b == "AMERICAN EXPRESS" { name = "Amex" }
            return name
        }
        return nil
    }

    /// P2-0/C-17: chữ DEBIT có nằm trong ±2 dòng quanh dòng
    /// neo (dòng đuôi thắng) hoặc trên bất kỳ dòng họ TENDER
    /// nào không — bằng chứng "thẻ ghi nợ" của giao dịch.
    private static func debitNear(lines: [OCRLine], anchor: Int) -> Bool {
        for j in lines.indices where abs(j - anchor) <= 2 {
            if lines[j].text.uppercased().contains("DEBIT") { return true }
        }
        for line in lines
        where CandidateFactory.labelFamily(of: line.text,
                                           hasMoney: false).family == "TENDER" {
            if line.text.uppercased().contains("DEBIT") { return true }
        }
        return false
    }

    /// Hãng thẻ: luật gốc của v3 (dòng đầu tiên chứa tên hãng;
    /// kèm "Debit" nếu in cùng dòng), cộng hai sửa P2-0:
    /// C-4 — có đuôi thắng thì ưu tiên hãng TRÊN DÒNG của
    /// đuôi thắng, không có mới rơi về dòng hãng đầu tiên;
    /// C-17 — dòng hãng thiếu DEBIT thì quét ±2 dòng quanh
    /// dòng đuôi thắng + các dòng TEND, thấy DEBIT thì nối
    /// hậu tố " Debit". Không có đuôi thắng (không ứng viên /
    /// tranh chấp) giữ nguyên luật gốc.
    private static func extractBrand(lines: [OCRLine],
                                     winningLine: Int? = nil) -> String? {
        if let w = winningLine, lines.indices.contains(w) {
            let upper = lines[w].text.uppercased()
            if var name = brandName(onLine: upper) {
                if upper.contains("DEBIT")
                    || debitNear(lines: lines, anchor: w) {
                    name += " Debit"
                }
                return name
            }
        }
        for line in lines {
            let upper = line.text.uppercased()
            if var name = brandName(onLine: upper) {
                if upper.contains("DEBIT") {
                    name += " Debit"
                } else if let w = winningLine,
                          debitNear(lines: lines, anchor: w) {
                    name += " Debit"
                }
                return name
            }
        }
        return nil
    }
}

/// Ứng viên ngày/giờ (§2.3(g)): mọi dạng in (số / ISO /
/// tháng-chữ / Clover / tách dòng) đều vào tập; chọn theo vị
/// trí + tính nhất quán với dòng giờ kề — không còn "thấy đầu
/// tiên thì chốt" theo từng cổng riêng của hai nhánh v3.
enum DateCandidateFactory {

    private static let dtNumRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})\s+(\d{1,2}):(\d{2})\s*([AP]M)?"#)
    private static let dtCloverRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,2})-([A-Za-z]{3})-(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AP])M?"#)
    private static let dNumRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})"#)
    private static let dIsoRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{4})-(\d{2})-(\d{2})"#)
    private static let dMonRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,2})-([A-Za-z]{3})-(\d{2,4})"#)
    private static let timeAloneRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)?$"#)
    private static let timeAnyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)?"#)
    private static let monthNames: [String: Int] = [
        "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
        "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
    ]

    private static func groups(_ re: NSRegularExpression?, _ text: String)
        -> [String?]? {
        guard let re = re else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text,
                                    range: NSRange(location: 0, length: ns.length))
        else { return nil }
        return (0...re.numberOfCaptureGroups).map { g in
            let r = m.range(at: g)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }

    private static func makeDate(month: Int?, day: Int?, year: Int?,
                                 hour: Int = 0, minute: Int = 0) -> Date? {
        guard let month = month, let day = day, var year = year else { return nil }
        if year < 100 { year += 2000 }
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        // P2-0/C-14: giờ/phút ngoài miền (25:70) phải BỊ LOẠI —
        // bản cũ để Calendar tự lăn sang ngày kế, sinh ngày
        // không hề in trên giấy.
        guard (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        guard let date = Calendar.current.date(from: comps) else { return nil }
        // Đối chiếu vòng tròn: thành phần đọc ngược từ Date
        // phải khớp đúng số đã xin (bắt ngày bất khả thi kiểu
        // 31/02 mà Calendar lăn thầm sang tháng 3).
        let back = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        guard back.year == year, back.month == month, back.day == day,
              back.hour == hour, back.minute == minute else { return nil }
        return date
    }

    private static func ampmAdjusted(_ hour: Int, _ ampm: String?) -> Int {
        guard let ap = ampm?.uppercased() else { return hour }
        if ap.hasPrefix("P") && hour < 12 { return hour + 12 }
        if ap.hasPrefix("A") && hour == 12 { return 0 }
        return hour
    }

    /// Trả (ngày, tin cậy, loại): "datetime" (ngày+giờ cùng
    /// dòng) thắng theo thứ tự dòng; không có thì ngày đầu
    /// tiên + giờ trong ±3 dòng theo luật P1-DATE-MERGE (giờ
    /// đứng riêng thắng giờ nhúng, gần thắng xa; tin cậy
    /// min × 0.9 như v3) → "merged"; còn lại "dateOnly".
    static func extract(lines: [OCRLine])
        -> (date: Date?, confidence: Double, kind: String?,
            distinctDays: Int) {
        var dtCands: [(index: Int, date: Date, conf: Double)] = []
        var dCands: [(index: Int, date: Date, conf: Double)] = []
        // P2-0/C-5 (dư): mọi ngày in SAU dòng RETURN POLICY
        // (hạn đổi trả in ở chân tờ) bị loại khỏi ứng viên —
        // chúng không phải ngày mua.
        let returnPolicyIndex = lines.firstIndex {
            let s = $0.text.uppercased()
            return s.contains("RETURN POLICY") || s.contains("RETURNPOLICY")
        }
        for (i, line) in lines.enumerated() {
            if let rp = returnPolicyIndex, i > rp { continue }
            let text = line.text
            var placed = false
            if let g = groups(dtNumRegex, text), g.count == 7,
               let d = makeDate(month: Int(g[1] ?? ""), day: Int(g[2] ?? ""),
                                year: Int(g[3] ?? ""),
                                hour: ampmAdjusted(Int(g[4] ?? "") ?? 0, g[6]),
                                minute: Int(g[5] ?? "") ?? 0) {
                dtCands.append((i, d, line.confidence))
                placed = true
            }
            if !placed, let g = groups(dtCloverRegex, text), g.count == 8,
               let mon = g[2].flatMap({ monthNames[$0.uppercased()] }),
               let d = makeDate(month: mon, day: Int(g[1] ?? ""),
                                year: Int(g[3] ?? ""),
                                hour: ampmAdjusted(Int(g[4] ?? "") ?? 0, g[7]),
                                minute: Int(g[5] ?? "") ?? 0) {
                dtCands.append((i, d, line.confidence))
                placed = true
            }
            if placed { continue }
            var found: Date? = nil
            if let g = groups(dNumRegex, text), g.count == 4 {
                found = makeDate(month: Int(g[1] ?? ""), day: Int(g[2] ?? ""),
                                 year: Int(g[3] ?? ""))
            }
            if found == nil, let g = groups(dIsoRegex, text), g.count == 4 {
                // P2-0/C-14: nhánh ISO đi qua CÙNG cửa kiểm
                // của makeDate (miền + đối chiếu vòng tròn)
                // thay vì dựng DateComponents trực tiếp.
                found = makeDate(month: Int(g[2] ?? ""),
                                 day: Int(g[3] ?? ""),
                                 year: Int(g[1] ?? ""))
            }
            if found == nil, let g = groups(dMonRegex, text), g.count == 4,
               let mon = g[2].flatMap({ monthNames[$0.uppercased()] }) {
                found = makeDate(month: mon, day: Int(g[1] ?? ""),
                                 year: Int(g[3] ?? ""))
            }
            if let d = found { dCands.append((i, d, line.confidence)) }
        }
        // Số NGÀY LỊCH khác nhau trong toàn bộ ứng viên — tín
        // hiệu mơ hồ cho parseV4 gắn cờ (phán quyết Leader
        // tích hợp V4-3, mục D5: chọn ngày in đầu tiên nhưng
        // không được im lặng khi có ≥2 ngày khác nhau).
        let distinctDays = Set((dtCands + dCands).map { c -> Int in
            let k = Calendar.current.dateComponents(
                [.year, .month, .day], from: c.date)
            return (k.year ?? 0) * 10000 + (k.month ?? 0) * 100
                + (k.day ?? 0)
        }).count
        if let first = dtCands.first {
            return (first.date, first.conf, "datetime", distinctDays)
        }
        guard let base = dCands.first else {
            return (nil, 0, nil, distinctDays)
        }
        // Ghép giờ kề (P1-DATE-MERGE): ±3 dòng, bỏ dòng mang
        // ngày cạnh tranh; khoá chọn (khoảng cách, giờ nhúng
        // thua giờ đứng riêng, chỉ số dòng).
        var best: (key: (Int, Int, Int), hour: Int, minute: Int, conf: Double)? = nil
        for (j, line) in lines.enumerated() {
            if j == base.index || abs(j - base.index) > 3 { continue }
            let text = line.text
            if groups(dNumRegex, text) != nil || groups(dIsoRegex, text) != nil
                || groups(dMonRegex, text) != nil { continue }
            var hm: (hour: Int, minute: Int)? = nil
            var standalone = false
            if let g = groups(timeAloneRegex, text), g.count == 4 {
                standalone = true
                hm = (ampmAdjusted(Int(g[1] ?? "") ?? 0, g[3]),
                      Int(g[2] ?? "") ?? 0)
            } else if let g = groups(timeAnyRegex, text), g.count == 4 {
                hm = (ampmAdjusted(Int(g[1] ?? "") ?? 0, g[3]),
                      Int(g[2] ?? "") ?? 0)
            }
            guard let v = hm else { continue }
            let key = (abs(j - base.index), standalone ? 0 : 1, j)
            if best == nil || key < best!.key {
                best = (key, v.hour, v.minute, line.confidence)
            }
        }
        // P2-0/C-14: giờ ghép kề cũng phải trong miền — giờ
        // bất khả thi (25:70) thì giữ ngày trơn thay vì lăn
        // ngày như bản cũ.
        if let b = best, (0...23).contains(b.hour),
           (0...59).contains(b.minute) {
            var comps = Calendar.current.dateComponents(
                [.year, .month, .day], from: base.date)
            comps.hour = b.hour
            comps.minute = b.minute
            if let merged = Calendar.current.date(from: comps) {
                return (merged, min(base.conf, b.conf) * 0.9, "merged",
                        distinctDays)
            }
        }
        return (base.date, base.conf, "dateOnly", distinctDays)
    }
}

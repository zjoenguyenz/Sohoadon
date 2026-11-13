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
    var family: String        // SUBTOTAL | TOTAL | TAX | TENDER | CHANGE | NONE
    var rank: Int?            // TAX1 → 1
    var labelOnly: Bool       // dòng chỉ có nhãn, không token tiền
}

enum CandidateFactory {

    // Mẫu token tiền CÓ VỊ TRÍ — cùng ngữ nghĩa biên với
    // Parser.moneyTokensWithBoundary (P1-MONEY-BOUNDARY):
    // (?!\d) sau \d{2} chặn token ma từ suất (3.9170) và số dài.
    private static let moneyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d[\d,]*\.\d{2})(?!\d)(-)?"#)

    // Suất: 1–3 số nguyên + 3–4 số lẻ (8.5170, 4.0170), hoặc
    // 2–4 số lẻ kèm dấu % (10.05%, 8.517% — dạng 3 số lẻ + %
    // của Costco từng lọt khỏi mẫu hẹp hơn).
    private static let rateRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(\d{1,3}\.\d{3,4}|\d{1,3}\.\d{2,4}\s*%)"#)

    // MARK: - Họ nhãn

    /// Phân họ nhãn cho MỘT dòng. Thứ tự kiểm là luật in
    /// (§4.4(c)): họ TENDER thắng họ TOTAL — dòng "TOTAL DEBIT
    /// PURCHASE 92.24" là dòng THANH TOÁN (gồm $20 cash-back),
    /// không bao giờ là neo tổng. Đây là ca bẫy L-R09.
    static func labelFamily(of text: String, hasMoney: Bool) -> LineLabel {
        let squashed = text.uppercased().filter { !$0.isWhitespace }
        func make(_ family: String, _ rank: Int? = nil) -> LineLabel {
            LineLabel(family: family, rank: rank, labelOnly: !hasMoney)
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
        if squashed.contains("TOTAL") || squashed.contains("AMOUNTDUE")
            || squashed.contains("BALANCEDUE") {
            return make("TOTAL")
        }
        return make("NONE")
    }

    // MARK: - Sinh ứng viên

    /// Sinh toàn bộ ứng viên từ các dòng đã chuẩn hoá (cùng mảng
    /// dòng mà ReceiptParser.parse nhìn thấy — lineIndex khớp).
    static func generate(lines: [OCRLine])
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
                    guard let cents = SafeMoney.parseCents(token, negative: negative)
                    else { continue }   // ngoài miền: bỏ TOKEN, không bỏ dòng
                    lineMoney.append((cents, token, negative,
                                      tokenRange.location, tokenRange.length))
                }
            }

            let label = labelFamily(of: line.text, hasMoney: !lineMoney.isEmpty)
            labels.append(label)

            // --- Vai trò khả thi + gợi ý theo họ nhãn (§2.6) ---
            for t in lineMoney {
                var roles: Set<String>
                var hints: [CandidateHint] = []
                switch label.family {
                case "SUBTOTAL":
                    roles = [MoneyRole.subtotal]
                    hints.append(CandidateHint(
                        source: CandidateHintSource.labelAdjacency, delta: 40,
                        reason: "cùng dòng nhãn SUBTOTAL"))
                case "TOTAL":
                    roles = [MoneyRole.total]
                    hints.append(CandidateHint(
                        source: CandidateHintSource.labelAdjacency, delta: 40,
                        reason: "cùng dòng nhãn TOTAL"))
                case "TAX":
                    roles = [MoneyRole.tax]
                    hints.append(CandidateHint(
                        source: CandidateHintSource.labelAdjacency, delta: 35,
                        reason: "cùng dòng nhãn TAX"))
                case "TENDER":
                    roles = [MoneyRole.tender]
                case "CHANGE":
                    roles = [MoneyRole.change]
                case "TAXSUM":
                    // Giá trị kiểm: ứng viên vẫn được SINH (luật
                    // không xoá ở tầng sinh) nhưng không mang vai
                    // trò khả thi nào — không neo, không vào bể.
                    roles = []
                default:
                    roles = [MoneyRole.subtotal, MoneyRole.tax, MoneyRole.total,
                             MoneyRole.itemAmount, MoneyRole.discount,
                             MoneyRole.tender]
                }
                money.append(MoneyCandidate(
                    id: nextID, cents: t.cents, text: t.text,
                    negative: t.negative, lineIndex: i,
                    utf16Start: t.start, utf16Length: t.length,
                    tier: "primary", feasibleRoles: roles, hints: hints))
                nextID += 1
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

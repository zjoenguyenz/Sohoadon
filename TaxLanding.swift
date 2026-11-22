// TaxLanding.swift — Pha 2 (L-2026-11-21-47): cơ chế hạ cánh bằng thuế.
//
// Tờ không đọc khép được (tam giác subtotal–thuế–total thiếu đỉnh) thì
// lõi tập trung vào khối total + mặt hàng: chọn % thuế theo ZIP × loại
// hàng rồi suy đỉnh còn thiếu. CHỈ điền đỉnh thiếu — không bao giờ ghi
// đè số đã đọc từ giấy. Số suy ra mang provenance kind "tax-landing"
// (detail mô tả phép suy) để màn Kiểm Lại gắn nhãn "ước tính" và anh
// duyệt mới lưu. Tiệm chỉ GỢI Ý (hồ sơ → cờ "theo tiệm"), không kết
// luận thay mặt hàng đọc được — luật của anh 2026-11-21 01:34 CST.
//
// File THUẦN (không IO, không UserDefaults): bảng thuế + hồ sơ rút gọn
// + khu mặc định được caller gói vào TaxLandingContext. Nhờ đó harness
// kiểm thử trực tiếp bằng Swift thật (TL01–TL18) và đường đọc của app
// lẫn harness dùng đúng một bản. Thiết kế: PHASE2-DIFF.md.

import Foundation

// MARK: - Loại hàng (vài loại thôi — lời anh)

enum TaxCategory: String, Equatable, Codable {
    case general    // hàng thường / máy móc → suất đầy đủ
    case grocery    // thực phẩm → suất thực phẩm (miễn phần bang, HB 1955)
    case prepared   // nhà hàng / đồ ăn chế biến → suất đầy đủ

    var labelVI: String {
        switch self {
        case .general: return "hàng thường"
        case .grocery: return "thực phẩm"
        case .prepared: return "đồ ăn chế biến"
        }
    }
}

// MARK: - Bảng thuế (một khu = area × phần county)

struct TaxAreaPortion: Equatable, Codable {
    var id: String              // "tulsa-tulsa"
    var areaName: String        // "Tulsa"
    var countyName: String      // "Tulsa County"
    var statePct: Double        // phần bang (Oklahoma 4.5)
    var countyPct: Double       // phần quận
    var cityPct: Double         // phần thành phố
    var zips: [String] = []

    /// Suất đầy đủ = bang + quận + thành phố (anh nhập từng phần, app cộng).
    var fullPct: Double { statePct + countyPct + cityPct }
    /// Suất thực phẩm = quận + thành phố (thực phẩm miễn phần bang).
    var groceryPct: Double { countyPct + cityPct }
    var displayName: String { "\(areaName) · \(countyName)" }

    func ratePct(for category: TaxCategory) -> Double {
        category == .grocery ? groceryPct : fullPct
    }
}

struct TaxTable: Equatable, Codable {
    var portions: [TaxAreaPortion]
    /// ZIP → portion id (ứng viên đông địa chỉ nhất của ZIP thắng —
    /// xem gen_tax_seed.py).
    var zipPortionIDs: [String: String]

    static let defaultSeedAreaID = "tulsa-tulsa"

    func portion(id: String) -> TaxAreaPortion? {
        portions.first { $0.id == id }
    }

    func portion(forZIP zip: String) -> TaxAreaPortion? {
        guard let pid = zipPortionIDs[zip] else { return nil }
        return portion(id: pid)
    }
}

// MARK: - Ngữ cảnh hạ cánh (caller chuẩn bị — lõi không tự đọc gì)

struct TaxProfileHint: Equatable {
    var zip: String? = nil
    var category: TaxCategory? = nil
}

struct TaxLandingContext: Equatable {
    var table: TaxTable
    var defaultAreaID: String
    /// Khoá = TaxLanding.profileKey(vendorKey:vendor:).
    var profileHints: [String: TaxProfileHint] = [:]
    /// Màn Kiểm Lại ép loại hàng khi anh đổi picker → tính lại.
    var forcedCategory: TaxCategory? = nil
    var enabled: Bool = true
}

// MARK: - Báo cáo hạ cánh

struct TaxLandingReport: Equatable {
    /// Điều kiện kích hoạt có đủ (tam giác thiếu đỉnh + có neo) —
    /// kể cả khi bị chặn (ZIP ngoài vùng) vẫn attempted = true để
    /// finalize ghi log được.
    var attempted: Bool = false
    /// Khoá provenance đã điền: "subtotal" | "tax[i]" | "total".
    var filledFields: [String] = []
    var areaID: String? = nil
    var areaSource: String = "none"       // zip | profile | default | none
    /// ZIP đã trích từ địa chỉ tờ (kể cả khi ngoài bảng) — để log
    /// ở finalize ghi được ZIP cụ thể khi bị chặn.
    var zip: String? = nil
    var category: TaxCategory? = nil
    var categorySource: String = "none"   // items | profile | review | default | none
    var ratePct: Double? = nil
    var blockedReason: String? = nil      // "zip-ngoai-bang" …
    /// Chuỗi mô tả phép suy — vào provenance detail + log.
    var detail: String = ""
}

extension FieldProvenance {
    static func taxLanding(_ detail: String) -> FieldProvenance {
        FieldProvenance(kind: "tax-landing", detail: detail)
    }
}

// MARK: - Lõi hạ cánh

enum TaxLanding {

    /// Khoá hồ sơ tiệm: vendorKey khi đã nhận diện; tờ generic thì
    /// dùng tên tiệm chuẩn hoá. StoreProfiles (phía app) dùng ĐÚNG
    /// hàm này khi học để hai phía khớp nhau.
    static func profileKey(vendorKey: String, vendor: String?) -> String {
        if vendorKey != "generic" { return vendorKey }
        let name = (vendor ?? "")
            .lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
        return name.isEmpty ? "generic" : "name:\(name)"
    }

    /// ZIP = cụm 5 chữ số CUỐI trong chuỗi địa chỉ (địa chỉ Mỹ kết
    /// thúc bằng ZIP). Cụm dài hơn 5 số (số điện thoại…) không khớp.
    static func extractZIP(from address: String?) -> String? {
        guard let address else { return nil }
        var found: String? = nil
        var run = ""
        for ch in address {
            if ch.isNumber {
                run.append(ch)
            } else {
                if run.count == 5 { found = run }
                run = ""
            }
        }
        if run.count == 5 { found = run }
        return found
    }

    /// Chữ nguồn chọn (vào detail/log): phân biệt đọc thật — gợi
    /// ý — mặc định, theo luật "tiệm chỉ gợi ý" của anh.
    static func sourceText(_ source: String) -> String {
        switch source {
        case "zip": return "theo ZIP trên tờ"
        case "profile": return "theo tiệm"
        case "items": return "theo món đọc được"
        case "review": return "anh chọn ở Kiểm Lại"
        case "default": return "mặc định"
        default: return source
        }
    }

    static func formatPct(_ pct: Double) -> String {
        var s = String(format: "%.3f", pct)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    // MARK: Phân loại mặt hàng (v1 — chỉ cần tách chắc THỰC PHẨM;
    // còn lại đều chịu suất đầy đủ nên phân loại sai giữa general và
    // prepared không đổi tiền thuế, chỉ đổi nhãn hiển thị)

    static let groceryKeywords: [String] = [
        "milk", "egg", "bread", "banana", "orange", "apple", "cheese",
        "butter", "yogurt", "cereal", "pasta", "rice", "flour", "sugar",
        "coffee", "chicken", "beef", "pork", "turkey", "salmon", "tuna",
        "tomato", "potato", "onion", "lettuce", "carrot",
        "gạo", "nước mắm", "nuoc mam", "bún", "trứng", "sữa", "bánh mì",
        "banh mi", "rau", "thịt",
    ]

    static let preparedKeywords: [String] = [
        "burger", "pizza", "sandwich", "burrito", "taco", "combo",
        "fries", "entree", "appetizer", "platter", "ramen bowl",
        "dine-in", "dine in",
    ]

    /// Trả nil khi không chắc (không hit, hoặc cả hai họ cùng hit) —
    /// caller rơi xuống gợi ý hồ sơ / mặc định.
    static func classifyCategory(items: [ParsedLineItem]) -> TaxCategory? {
        var grocery = 0
        var prepared = 0
        for item in items {
            let name = item.name.lowercased()
            if name.isEmpty { continue }
            let g = groceryKeywords.contains { name.contains($0) }
            let p = preparedKeywords.contains { name.contains($0) }
            if g && !p { grocery += 1 }
            if p && !g { prepared += 1 }
        }
        if grocery > 0 && prepared == 0 { return .grocery }
        if prepared > 0 && grocery == 0 { return .prepared }
        return nil
    }

    // MARK: Hạ cánh

    /// Điền các đỉnh tam giác còn thiếu. Trả nil khi cơ chế tắt.
    /// Khi điều kiện kích hoạt không đủ → report.attempted = false và
    /// result nguyên vẹn. Khi đủ mà bị chặn (ZIP ngoài bảng) →
    /// attempted = true, filledFields rỗng, blockedReason có giá trị.
    static func evaluate(_ input: ParseResult,
                         context: TaxLandingContext)
        -> (result: ParseResult, report: TaxLandingReport)? {
        guard context.enabled else { return nil }
        var report = TaxLandingReport()
        var result = input

        let hasSub = input.subtotalCents != nil
        let hasTax = !input.taxes.isEmpty
        let hasTotal = input.totalCents != nil
        let missing = !hasSub || !hasTax || !hasTotal
        let anchored = hasSub || hasTax || hasTotal
        guard missing && anchored else {
            return (input, report)
        }
        // Tờ trọng tài đã KHÉP thì KHÔNG ĐỤNG (luật §3.4): trọng
        // tài có thể khép với taxes RỖNG (tờ miễn thuế / thuế
        // không tách dòng, subtotal == total) — hạ cánh ở đó sẽ
        // bịa một dòng "Thuế ước tính" không có thật trên một tờ
        // khoẻ. arbiterStatus nil (đường đọc cũ) vẫn được xét.
        if input.arbiterStatus == "closed" {
            return (input, report)
        }
        report.attempted = true

        var sub = input.subtotalCents
        var total = input.totalCents
        var steps: [String] = []

        // — Pha A: phép không cần suất (chỉ từ số đã đọc) —
        if let s = sub, hasTax, total == nil {
            total = s + input.taxTotalCents
            result.totalCents = total
            report.filledFields.append("total")
            steps.append("subtotal+thuế→total")
        }
        if let t = total, hasTax, sub == nil {
            // Chặn subtotal ÂM khi dòng thuế đọc sai lớn hơn total
            // (tờ mờ đọc nhầm) — để trống cho Kiểm Lại xử lý.
            let derivedSub = t - input.taxTotalCents
            if derivedSub >= 0 {
                sub = derivedSub
                result.subtotalCents = sub
                report.filledFields.append("subtotal")
                steps.append("total−thuế→subtotal")
            }
        }
        if let t = total, let s = sub, result.taxes.isEmpty {
            let derived = t - s
            if derived > 0 {
                let idx = result.taxes.count
                result.taxes.append(ParsedTaxLine(
                    label: "Thuế ước tính", rateText: nil,
                    amountCents: derived, lineIndex: nil))
                report.filledFields.append("tax[\(idx)]")
                steps.append("total−subtotal→thuế")
            }
        }

        // — Pha B: phép cần suất (còn thiếu đỉnh sau pha A) —
        // Điều kiện kèm total == nil / sub == nil chặt: ca (subtotal
        // + total đều có, thuế thiếu) CHỈ thuộc Pha A rule 3 — Pha A
        // đã từ chối (total − subtotal ≤ 0, số đọc mâu thuẫn) thì
        // Pha B KHÔNG được bịa thuế theo suất mâu thuẫn cả hai neo.
        let stillNeedsRate = (sub != nil && total == nil
                && result.taxes.isEmpty)
            || (total != nil && sub == nil && result.taxes.isEmpty)
        if stillNeedsRate {
            // Chọn khu vực: ZIP của tờ → hồ sơ tiệm → mặc định.
            let hint = context.profileHints[
                profileKey(vendorKey: input.vendorKey, vendor: input.vendor)]
            var area: TaxAreaPortion? = nil
            if let zip = extractZIP(from: input.vendorAddress) {
                report.zip = zip
                if let p = context.table.portion(forZIP: zip) {
                    area = p
                    report.areaSource = "zip"
                } else {
                    report.blockedReason = "zip-ngoai-bang"
                }
            } else if let hz = hint?.zip,
                      let p = context.table.portion(forZIP: hz) {
                area = p
                report.areaSource = "profile"
            } else if let p = context.table.portion(id: context.defaultAreaID) {
                area = p
                report.areaSource = "default"
            } else {
                report.blockedReason = "thieu-khu-mac-dinh"
            }

            if let area, report.blockedReason == nil {
                report.areaID = area.id
                // Chọn loại hàng: ép (Kiểm Lại) → đọc món → hồ sơ → mặc định.
                let category: TaxCategory
                if let forced = context.forcedCategory {
                    category = forced
                    report.categorySource = "review"
                } else if let c = classifyCategory(items: input.items) {
                    category = c
                    report.categorySource = "items"
                } else if let hc = hint?.category {
                    category = hc
                    report.categorySource = "profile"
                } else {
                    category = .general
                    report.categorySource = "default"
                }
                report.category = category
                let rate = area.ratePct(for: category)
                report.ratePct = rate

                if let s = sub, total == nil, result.taxes.isEmpty {
                    let tax = Int((Double(s) * rate / 100).rounded())
                    let idx = result.taxes.count
                    result.taxes.append(ParsedTaxLine(
                        label: "Thuế ước tính",
                        rateText: "\(formatPct(rate))%",
                        amountCents: tax, lineIndex: nil))
                    report.filledFields.append("tax[\(idx)]")
                    steps.append("subtotal×suất→thuế")
                    if total == nil {
                        total = s + tax
                        result.totalCents = total
                        report.filledFields.append("total")
                        steps.append("subtotal+thuế→total")
                    }
                } else if let t = total, sub == nil, result.taxes.isEmpty {
                    let s = Int((Double(t) / (1 + rate / 100)).rounded())
                    sub = s
                    result.subtotalCents = s
                    report.filledFields.append("subtotal")
                    steps.append("total÷(1+suất)→subtotal")
                    let tax = t - s
                    let idx = result.taxes.count
                    result.taxes.append(ParsedTaxLine(
                        label: "Thuế ước tính",
                        rateText: "\(formatPct(rate))%",
                        amountCents: tax, lineIndex: nil))
                    report.filledFields.append("tax[\(idx)]")
                    steps.append("total−subtotal→thuế")
                }
            }
        }

        if report.attempted && report.filledFields.isEmpty
            && report.blockedReason == nil {
            // Kích hoạt nhưng không đỉnh nào suy được (vd neo duy
            // nhất là dòng thuế) — nói rõ lý do thay vì im lặng.
            report.blockedReason = "khong-dien-duoc-dinh-nao"
        }

        if !report.filledFields.isEmpty {
            let head: String
            if let rid = report.areaID,
               let area = context.table.portion(id: rid),
               let rate = report.ratePct,
               let cat = report.category {
                // Nguồn chọn khu/loại ĐI VÀO detail — provenance +
                // log giữ được phân biệt "theo ZIP tờ / theo tiệm /
                // mặc định" (luật của anh: tiệm chỉ gợi ý).
                head = "\(area.displayName) · \(cat.labelVI) · "
                    + "\(formatPct(rate))%"
                    + " · khu \(sourceText(report.areaSource))"
                    + " · loại \(sourceText(report.categorySource))"
            } else {
                head = "tam giác từ số đã đọc"
            }
            report.detail = head + " · " + steps.joined(separator: " · ")
        }
        return (result, report)
    }
}

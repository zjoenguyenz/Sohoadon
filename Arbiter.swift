import Foundation

// =====================================================================
//  Arbiter.swift — CORE-V4 · GÓI V4-1 (DESIGN-V4 §3)
//
//  TRỌNG TÀI khối tổng/thuế: gán vai trò subtotal/taxes/total cho
//  ứng viên tiền bằng ĐẲNG THỨC SỔ, không bằng cổng hình dạng.
//
//   Pha 0 — neo cứng theo nhãn (§3.2) + LUẬT ĐỔI NEO: neo KHÔNG
//     tuyệt đối; nghiệm khép duy nhất thắng neo, trường bị đổi
//     mang provenance anchorOverriddenByClosure. Họ TENDER không
//     bao giờ là neo (§4.4(c) — bẫy "TOTAL DEBIT PURCHASE").
//   Pha 1 — cửa sổ khối: bắt đầu ở dòng nhãn SUBTOTAL/TOTAL đầu
//     tiên (dự phòng TAX; nữa: toàn luồng), lùi lên trên qua các
//     dòng CHỈ-CÓ-TIỀN liên tiếp ngay trước đó (dạng cột của
//     Costco: "125.48"/"9.38" đứng trước dòng "**** TOTAL …").
//   Pha 2 — tập con thuế: cần = total − subtotal; bể = ứng viên
//     khả-thuế trong cửa sổ CÓ BẰNG CHỨNG thuế (dòng họ TAX,
//     hoặc suất đỡ cùng dòng/dòng kề, hoặc nằm giữa hai neo của
//     cặp); tập con ≤4 phần tử khép cần trong dung sai E2. Cặp
//     neo phải đúng thứ tự in (tạm tính trước tổng). Mọi tìm
//     kiếm nằm trong NGÂN SÁCH §3.3 — chạm trần thì fail-closed
//     về nhánh không-nghiệm kèm cờ searchBudgetExceeded, KHÔNG
//     BAO GIỜ chọn nghiệm "gần nhất" vì hết ngân sách.
//
//  Luật nghiệm (§3.4 + khung §6):
//   - Duy nhất theo GIÁ TRỊ → chốt kèm provenance từng trường.
//     (Hai cách gán chỉ khác token trùng giá trị là MỘT nghiệm.)
//   - Còn ≥2 nghiệm khác giá trị sau THANG PHÂN ĐỊNH dưới đây
//     → trường nào khác nhau giữa các nghiệm thì ĐỂ TRỐNG (§6
//     thắng cách đọc "trình bày tạm" của §3.4 đối với trường
//     tiền chính); trường mọi nghiệm đồng ý thì chốt với
//     provenance ambiguousConsensus; toàn bộ nghiệm cạnh tranh
//     ghi vào disputedSolutions cho hồ sơ chẩn đoán.
//   - 0 nghiệm → (§3.5) giữ bản đọc neo/nhãn tốt nhất với
//     provenance hintOnlyUnclosed + thâm hụt δ2 định vị khối.
//
//  THANG PHÂN ĐỊNH (mỗi bậc chỉ LỌC khi còn ≥2 nghiệm khác giá
//  trị và bậc đó còn giữ lại ≥1 nghiệm — không bậc nào tự nó
//  bịa ra nghiệm): (1) khép tuyệt đối (δ=0) thắng khép mức
//  giấy (≤2¢); (2) tập thuế được SUẤT ĐỠ TRỌN (khác rỗng, mọi
//  token có suất cùng dòng/dòng kề — bằng chứng in của dòng
//  phân rã thuế) thắng tập không được đỡ trọn; (3) tổng được
//  CHỨNG THỰC LẶP (giá trị xuất hiện ≥2 lần trên tờ — §3.8
//  "corroboration") thắng tổng xuất hiện một lần; (4) tổng LỚN
//  NHẤT (tổng của tờ ≥ mọi sổ con in lại ở đuôi); (5) token
//  tổng SỚM NHẤT (khối tổng chính đứng trước phần đuôi).
//  Thang này là diễn giải thi công của §3.4 bằng bằng chứng in,
//  rút ra từ ca L-R01 — đã khai trong CHECKS.md để Leader phán.
//
//  Thuế hàm ý (§3.6): hiệu total − subtotal − Σthuế CHỈ là tín
//  hiệu (cờ qua validate() sẵn có) — không bao giờ thành dòng
//  thuế, không vào tổng thuế, không hiển thị như đã đọc.
//
//  Phạm vi V4-1: trọng tài này chỉ phán khối tổng. E1 (Σmón) và
//  E3 (số lượng) được ĐO và ghi thâm hụt/vết — món là của v3 ở
//  gói này; khép E1/E3 thuộc V4-2 (§3.2 pha 3/4).
// =====================================================================

/// Kết quả trọng tài khối tổng — đầu vào duy nhất mà parseV4
/// dùng để thay khối tổng/thuế của v3.
struct TotalsArbitration {
    var subtotalCents: Int? = nil
    var taxes: [ParsedTaxLine] = []
    var totalCents: Int? = nil
    /// Confidence của dòng chứa token tổng đã chốt (0 nếu không có).
    var totalLineConfidence: Double = 0
    /// closed | ambiguous | unclosed | budgetExceeded
    var status: String = "unclosed"
    /// Provenance từng trường khối tổng (§3.7) — khoá "subtotal",
    /// "tax[0]"…, "total"; ghi vào ngăn provenance của chẩn đoán.
    var provenance: [String: FieldProvenance] = [:]
    /// Mô tả các nghiệm cạnh tranh khi ambiguous (§3.4).
    var disputedSolutions: [String] = []
    /// δ1 = Σmón − tạm tính trên bản gán đã chốt/tốt nhất (nil nếu
    /// thiếu một phía) — định vị thâm hụt sang khối món.
    var deficitE1: Int? = nil
    /// δ2 = tạm tính + Σthuế − tổng trên bản gán tốt nhất.
    var deficitE2: Int? = nil
    /// Gợi ý vùng đọc lại (§3.5): "items-block/…" | "totals-block/…".
    var regionHint: String? = nil
    var evaluationsUsed: Int = 0
    /// Vết quyết định ngắn gọn (đưa vào chẩn đoán qua selectionTrace).
    var trace: [String] = []
    /// Bản đồ ứng viên cửa sổ → vai trò phán quyết (P1-CANDIDATES).
    var totalCandidates: [TotalCandidate] = []
}

enum TotalsArbiter {

    // Ngân sách tìm kiếm §3.3 — hằng số cứng, chạm là fail-closed.
    static let maxTaxSubsetSize = 4
    static let maxSubsetTrials = 10_000
    static let maxEvaluations = 50_000
    static let maxWindowCandidatesPerRole = 64
    /// Số ứng viên tối đa cho mỗi vai trò khi dựng cặp neo (neo
    /// trước, dự phòng theo điểm gợi ý lấp tới trần này).
    static let maxRoleCandidates = 6
    /// Số cặp neo tối đa được thử.
    static let maxAnchorPairs = 36
    /// Dung sai E2 mức giấy (SCORECARD): khép trong ±2¢ vẫn là khép.
    static let e2ToleranceCents = 2
    /// Cửa sổ lùi qua tối đa ngần này dòng chỉ-có-tiền (pha 1).
    static let maxWindowLookback = 4

    /// Một nghiệm khép theo GIÁ TRỊ (token chỉ để dựng dòng thuế
    /// + provenance; danh tính nghiệm là bộ giá trị).
    private struct Solution {
        var subtotal: Int
        var taxTokens: [MoneyCandidate]   // theo thứ tự dòng
        var total: Int
        var totalToken: MoneyCandidate
        var subtotalToken: MoneyCandidate
        var diff: Int                     // |Σthuế − cần| (0 = khép tuyệt đối)
        var key: String {
            let tv = taxTokens.map { $0.cents }.sorted()
            return "\(subtotal)|\(tv.map(String.init).joined(separator: ","))|\(total)"
        }
        var describe: String {
            let tv = taxTokens.map { $0.cents }
            return "S=\(subtotal) taxes=\(tv) T=\(total)"
        }
    }

    static func arbitrate(lines: [OCRLine], itemsSumCents: Int?) -> TotalsArbitration {
        var out = TotalsArbitration()
        let (money, rates, labels) = CandidateFactory.generate(lines: lines)
        var evaluations = 0
        var budgetHit = false

        // ---- Pha 1: cửa sổ khối tổng ----
        var windowStart: Int? = nil
        for (i, l) in labels.enumerated()
        where l.family == "SUBTOTAL" || l.family == "TOTAL" {
            windowStart = i; break
        }
        if windowStart == nil {
            for (i, l) in labels.enumerated() where l.family == "TAX" {
                windowStart = i; break
            }
        }
        var wStart = windowStart ?? 0
        // Lùi qua các dòng CHỈ-CÓ-TIỀN liên tiếp ngay trước dòng
        // nhãn đầu tiên (cột tiền không nhãn của Costco).
        var back = 0
        while wStart - back - 1 >= 0 && back < maxWindowLookback {
            let j = wStart - back - 1
            let toks = money.filter { $0.lineIndex == j }
            let hasLetters = lines[j].text.contains { $0.isLetter }
            if toks.count == 1 && !hasLetters { back += 1 } else { break }
        }
        wStart -= back
        let window = money.filter { $0.lineIndex >= wStart }
        out.trace.append("window-start=\(wStart) candidates=\(window.count)")

        // ---- Pha 0: neo nhãn ----
        // Token trên dòng nhãn; dòng nhãn KHÔNG token → token đầu
        // tiên của dòng kế KHI dòng kế không có nhãn riêng (dạng
        // in tách nhãn/tiền hai dòng).
        func anchorTokens(_ family: String) -> [MoneyCandidate] {
            var result: [MoneyCandidate] = []
            for (i, l) in labels.enumerated() where l.family == family {
                let onLine = money.filter { $0.lineIndex == i }
                if let first = onLine.first {
                    result.append(first)
                } else if l.labelOnly, i + 1 < lines.count,
                          labels[i + 1].family == "NONE",
                          let next = money.filter({ $0.lineIndex == i + 1 }).first {
                    result.append(next)
                }
            }
            return result
        }
        let subAnchors = anchorTokens("SUBTOTAL")
        let totAnchors = anchorTokens("TOTAL")

        // Danh sách ứng viên cho một vai trò: NEO TRƯỚC, dự phòng
        // (ứng viên khả-vai trong cửa sổ, điểm gợi ý giảm dần rồi
        // thứ tự dòng) lấp tới trần. Ứng viên dòng TENDER/CHANGE/
        // TAXSUM không bao giờ vào: feasibleRoles của chúng không
        // chứa subtotal/total (luật §4.4(c) ở cả hai tầng).
        func roleCandidates(_ role: String, anchors: [MoneyCandidate]) -> [MoneyCandidate] {
            var result: [MoneyCandidate] = []
            var seen = Set<Int>()
            for c in anchors where !seen.contains(c.id) {
                seen.insert(c.id); result.append(c)
            }
            let pool = window.filter { $0.feasibleRoles.contains(role) }
                .sorted { a, b in
                    if a.hintScore != b.hintScore { return a.hintScore > b.hintScore }
                    return a.lineIndex < b.lineIndex
                }
            for c in pool where result.count < maxRoleCandidates {
                if !seen.contains(c.id) {
                    seen.insert(c.id); result.append(c)
                }
            }
            return result
        }
        let subCands = roleCandidates(MoneyRole.subtotal, anchors: subAnchors)
        let totCands = roleCandidates(MoneyRole.total, anchors: totAnchors)
        // Cặp neo: đúng thứ tự in (tạm tính không sau tổng), hai
        // đầu không dùng chung một token.
        var pairs: [(MoneyCandidate, MoneyCandidate)] = []
        for s in subCands { for t in totCands
        where s.id != t.id && s.lineIndex <= t.lineIndex {
            pairs.append((s, t))
        } }
        if pairs.count > maxAnchorPairs { pairs = Array(pairs.prefix(maxAnchorPairs)) }
        out.trace.append("pairs=\(pairs.count) subAnchors=\(subAnchors.count) totAnchors=\(totAnchors.count)")

        // ---- Pha 2: tập con thuế trong ngân sách ----
        var solutions: [Solution] = []
        var seenKeys = Set<String>()
        var trials = 0

        pairLoop: for (sTok, tTok) in pairs {
            guard let need = SafeMoney.checkedSubtract(tTok.cents, sTok.cents),
                  need >= 0 else { continue }
            // Bể thuế: khả-thuế trong cửa sổ, trừ chính hai token
            // neo của cặp, trừ token 0 (§3.1 — nghiệm suy biến) và
            // token âm (thuế in không âm); và phải CÓ BẰNG CHỨNG
            // thuế: dòng họ TAX, suất đỡ, hoặc nằm giữa hai neo.
            let lo = min(sTok.lineIndex, tTok.lineIndex)
            let hi = max(sTok.lineIndex, tTok.lineIndex)
            let pool = window.filter {
                $0.feasibleRoles.contains(MoneyRole.tax)
                    && $0.id != sTok.id && $0.id != tTok.id
                    && $0.cents > 0
                    && (labels[$0.lineIndex].family == "TAX"
                        || CandidateFactory.rateSupported(lineIndex: $0.lineIndex, rates: rates)
                        || (lo <= $0.lineIndex && $0.lineIndex <= hi))
            }.sorted { $0.lineIndex < $1.lineIndex }
            if pool.count > maxWindowCandidatesPerRole {
                budgetHit = true
                out.trace.append("searchBudgetExceeded:pool=\(pool.count)")
                break pairLoop
            }
            // Liệt kê tập con ≤4 phần tử theo thứ tự chỉ số dòng
            // (xác định, không phụ thuộc thứ tự băm). Mọi nút của
            // cây liệt kê = một tập con, gồm cả tập rỗng ở gốc.
            let n = pool.count
            let maxK = min(maxTaxSubsetSize, n)
            var chosen: [Int] = []
            func enumerate(_ start: Int, _ depth: Int) {
                if budgetHit { return }
                do {
                    trials += 1; evaluations += 1
                    if trials > maxSubsetTrials || evaluations > maxEvaluations {
                        budgetHit = true
                        out.trace.append("searchBudgetExceeded:trials=\(trials)")
                        return
                    }
                    var sum = 0
                    var ok = true
                    for idx in chosen {
                        if let v = SafeMoney.checkedAdd(sum, pool[idx].cents) {
                            sum = v
                        } else { ok = false; break }
                    }
                    if ok {
                        let diff = Swift.abs(sum - need)
                        // LUẬT BẰNG CHỨNG THUẾ (Leader, tích hợp
                        // V4-1): bể thuế có bằng chứng mà tập thuế
                        // RỖNG là không thể chấp nhận — token thuế
                        // đã in phải được tính tới (§3.6). Giết
                        // nghiệm suy biến S==T/bỏ thuế (L-R05/06).
                        if diff <= e2ToleranceCents
                            && !(chosen.isEmpty && !pool.isEmpty) {
                            let sol = Solution(
                                subtotal: sTok.cents,
                                taxTokens: chosen.map { pool[$0] },
                                total: tTok.cents,
                                totalToken: tTok, subtotalToken: sTok,
                                diff: diff)
                            if !seenKeys.contains(sol.key) {
                                seenKeys.insert(sol.key)
                                solutions.append(sol)
                            }
                        }
                    }
                }
                guard depth < maxK else { return }
                var i = start
                while i < n {
                    chosen.append(i)
                    enumerate(i + 1, depth + 1)
                    chosen.removeLast()
                    if budgetHit { return }
                    i += 1
                }
            }
            enumerate(0, 0)
            if budgetHit { break pairLoop }
        }
        out.evaluationsUsed = evaluations

        // ---- Thang phân định nghiệm (đầu file) ----
        func distinctKeys(_ sols: [Solution]) -> Set<String> { Set(sols.map { $0.key }) }
        var effective = solutions
        let exact = effective.filter { $0.diff == 0 }
        if !exact.isEmpty { effective = exact }
        if distinctKeys(effective).count > 1 {
            // Bậc 2: tập thuế được suất đỡ trọn — đòi tập KHÁC
            // RỖNG (tập rỗng "đỡ trọn" theo nghĩa chân không sẽ
            // giết mọi ca thuế không in suất).
            let supported = effective.filter {
                !$0.taxTokens.isEmpty && $0.taxTokens.allSatisfy {
                    CandidateFactory.rateSupported(lineIndex: $0.lineIndex, rates: rates)
                }
            }
            if !supported.isEmpty { effective = supported }
        }
        if distinctKeys(effective).count > 1 {
            // Bậc 3: tổng được chứng thực lặp trên toàn tờ.
            let corro = effective.filter { sol in
                money.filter { $0.cents == sol.total }.count >= 2
            }
            if !corro.isEmpty { effective = corro }
        }
        // Bậc 4–5 (tổng lớn nhất / token tổng sớm nhất) là
        // heuristic thuần tuý, KHÔNG phải bằng chứng in: theo
        // phán quyết Leader khi tích hợp V4-1 (thi hành §3.4
        // "không chọn thầm"), nếu sau bậc 3 vẫn còn >1 nghiệm
        // khác giá trị thì kết cục là MƠ HỒ — bậc 4/5 bị vô
        // hiệu hoá cho mục đích chốt, tập nghiệm giữ nguyên
        // như sau bậc 3 để nhánh mơ hồ trình bày đầy đủ.
        if distinctKeys(effective).count > 1 {
            out.trace.append("ladder: post-evidence rivals=\(distinctKeys(effective).count) -> ambiguous (§3.4)")
        }
        out.trace.append("solutions=\(solutions.count) effective=\(distinctKeys(effective).count)")

        // ---- Dựng dòng thuế từ token của một nghiệm ----
        func buildTaxes(_ toks: [MoneyCandidate]) -> [ParsedTaxLine] {
            toks.map { tok in
                let lab = labels[tok.lineIndex]
                let labelLine: Int? = lab.family == "TAX" ? tok.lineIndex
                    : (tok.lineIndex > 0 && labels[tok.lineIndex - 1].family == "TAX"
                        && labels[tok.lineIndex - 1].labelOnly
                        ? tok.lineIndex - 1 : nil)
                let rank = lab.family == "TAX" ? lab.rank
                    : (labelLine != nil ? labels[labelLine!].rank : nil)
                return ParsedTaxLine(
                    label: rank != nil ? "TAX \(rank!)" : "TAX",
                    rateText: CandidateFactory.rateText(
                        forTaxLine: tok.lineIndex, labelLine: labelLine, rates: rates),
                    amountCents: tok.cents,
                    lineIndex: tok.lineIndex)
            }
        }
        func prov(_ kind: String, _ detail: String) -> FieldProvenance {
            FieldProvenance(kind: kind, detail: detail)
        }
        // Luật provenance cho trường neo: đúng token neo → hardAnchor;
        // có neo khác bị nghiệm khép lật → anchorOverriddenByClosure;
        // không có neo → closureUnique.
        func anchorRule(chosen: MoneyCandidate, anchors: [MoneyCandidate]) -> (String, String) {
            if anchors.contains(where: { $0.id == chosen.id }) {
                return ("anchored", "hardAnchor")
            }
            if !anchors.isEmpty {
                return ("anchored", "anchorOverriddenByClosure")
            }
            return ("read", "closureUnique")
        }
        func deficits(subtotal: Int?, taxes: [ParsedTaxLine], total: Int?) {
            if let s = subtotal, let isum = itemsSumCents {
                out.deficitE1 = SafeMoney.checkedSubtract(isum, s)
            }
            if let s = subtotal, let t = total,
               let taxSum = SafeMoney.sumCents(taxes.map { $0.amountCents }),
               let st = SafeMoney.checkedAdd(s, taxSum) {
                out.deficitE2 = SafeMoney.checkedSubtract(st, t)
            }
        }
        func candidateMap(chosenTaxIDs: Set<Int>, subtotalID: Int?, totalID: Int?) {
            out.totalCandidates = window.map { c in
                var role = MoneyRole.unassigned
                var chosen = false
                if let sid = subtotalID, c.id == sid {
                    role = MoneyRole.subtotal; chosen = true
                } else if let tid = totalID, c.id == tid {
                    role = MoneyRole.total; chosen = true
                } else if chosenTaxIDs.contains(c.id) {
                    role = MoneyRole.tax; chosen = true
                } else if c.feasibleRoles.count == 1 {
                    role = c.feasibleRoles.first ?? MoneyRole.unassigned
                }
                return TotalCandidate(lineIndex: c.lineIndex, cents: c.cents,
                                      role: role, chosen: chosen)
            }
        }

        if budgetHit {
            // Fail-closed: về nhánh không-nghiệm, gắn cờ ngân sách.
            out.status = "budgetExceeded"
            applyBestEffort(&out, lines: lines, labels: labels, money: money,
                            window: window, subAnchors: subAnchors,
                            totAnchors: totAnchors, rates: rates,
                            buildTaxes: buildTaxes, prov: prov)
            deficits(subtotal: out.subtotalCents, taxes: out.taxes, total: out.totalCents)
            out.regionHint = "totals-block/search-budget-exceeded"
            candidateMap(chosenTaxIDs: [], subtotalID: nil, totalID: nil)
            return out
        }

        if distinctKeys(effective).count == 1, let sol = effective.first {
            // ---- DUY NHẤT theo giá trị → chốt (§3.4) ----
            out.status = "closed"
            out.subtotalCents = sol.subtotal
            out.taxes = buildTaxes(sol.taxTokens)
            out.totalCents = sol.total
            out.totalLineConfidence = lines[sol.totalToken.lineIndex].confidence
            let (sk, sd) = anchorRule(chosen: sol.subtotalToken, anchors: subAnchors)
            out.provenance["subtotal"] = prov(sk, sd)
            let (tk, td) = anchorRule(chosen: sol.totalToken, anchors: totAnchors)
            out.provenance["total"] = prov(tk, td)
            for (i, _) in out.taxes.enumerated() {
                out.provenance["tax[\(i)]"] = prov("read", "closureUnique")
            }
            out.trace.append("solution=\(sol.describe) diff=\(sol.diff)")
            deficits(subtotal: out.subtotalCents, taxes: out.taxes, total: out.totalCents)
            if let d1 = out.deficitE1, d1 != 0 {
                out.regionHint = "items-block/e1-deficit:\(d1)"
            }
            candidateMap(chosenTaxIDs: Set(sol.taxTokens.map { $0.id }),
                         subtotalID: sol.subtotalToken.id, totalID: sol.totalToken.id)
            return out
        }

        if distinctKeys(effective).count > 1 {
            // ---- MƠ HỒ (§3.4 + §6): trường tranh chấp để trống ----
            out.status = "ambiguous"
            out.disputedSolutions = effective.map { $0.describe }
            out.trace.append("ambiguous solutions=\(effective.count)")
            let subValues = Set(effective.map { $0.subtotal })
            let totValues = Set(effective.map { $0.total })
            let taxKeys = Set(effective.map {
                $0.taxTokens.map { $0.cents }.sorted()
            })
            if subValues.count == 1, let s = subValues.first {
                out.subtotalCents = s
                out.provenance["subtotal"] = prov("read", "ambiguousConsensus")
            }
            if totValues.count == 1, let t = totValues.first,
               let sol = effective.first(where: { $0.total == t }) {
                out.totalCents = t
                out.totalLineConfidence = lines[sol.totalToken.lineIndex].confidence
                out.provenance["total"] = prov("read", "ambiguousConsensus")
            }
            if taxKeys.count == 1, let sol = effective.first {
                out.taxes = buildTaxes(sol.taxTokens)
                for (i, _) in out.taxes.enumerated() {
                    out.provenance["tax[\(i)]"] = prov("read", "ambiguousConsensus")
                }
            }
            deficits(subtotal: out.subtotalCents, taxes: out.taxes, total: out.totalCents)
            out.regionHint = "totals-block/ambiguous"
            candidateMap(chosenTaxIDs: [], subtotalID: nil, totalID: nil)
            return out
        }

        // ---- 0 nghiệm (§3.5): bản đọc neo/nhãn tốt nhất + thâm hụt ----
        out.status = "unclosed"
        applyBestEffort(&out, lines: lines, labels: labels, money: money,
                        window: window, subAnchors: subAnchors,
                        totAnchors: totAnchors, rates: rates,
                        buildTaxes: buildTaxes, prov: prov)
        deficits(subtotal: out.subtotalCents, taxes: out.taxes, total: out.totalCents)
        if let d2 = out.deficitE2, d2 != 0 {
            out.regionHint = "totals-block/e2-deficit:\(d2)"
        } else {
            out.regionHint = "totals-block/no-closure"
        }
        candidateMap(chosenTaxIDs: [], subtotalID: nil, totalID: nil)
        return out
    }

    /// Bản đọc tốt nhất khi không khép: neo nhãn CUỐI theo vai
    /// (tạm tính/tổng in cuối khối là bản cuối của tờ) + dòng thuế
    /// thu hoạch từ bằng chứng in (token trên dòng TAX — thừa kế
    /// tách dòng chỉ khi dòng kế không nhãn riêng — cộng token
    /// không-nhãn nhưng có suất đỡ nằm giữa hai neo: khối thuế
    /// thật của T-Johnnys in không có chữ TAX). Tất cả mang
    /// provenance hintOnlyUnclosed, khử trùng theo id token.
    private static func applyBestEffort(
        _ out: inout TotalsArbitration, lines: [OCRLine], labels: [LineLabel],
        money: [MoneyCandidate], window: [MoneyCandidate],
        subAnchors: [MoneyCandidate], totAnchors: [MoneyCandidate],
        rates: [RateCandidate],
        buildTaxes: ([MoneyCandidate]) -> [ParsedTaxLine],
        prov: (String, String) -> FieldProvenance) {
        if let s = subAnchors.last {
            out.subtotalCents = s.cents
            out.provenance["subtotal"] = prov("read", "hintOnlyUnclosed")
        }
        if let t = totAnchors.last {
            out.totalCents = t.cents
            out.totalLineConfidence = lines[t.lineIndex].confidence
            out.provenance["total"] = prov("read", "hintOnlyUnclosed")
        }
        var taxTokens: [MoneyCandidate] = []
        var used = Set<Int>()
        for (i, l) in labels.enumerated() where l.family == "TAX" {
            var cand: MoneyCandidate? = nil
            if let tok = money.first(where: { $0.lineIndex == i }) {
                cand = tok
            } else if l.labelOnly, i + 1 < lines.count,
                      labels[i + 1].family == "NONE" {
                cand = money.first(where: { $0.lineIndex == i + 1 })
            }
            if let c = cand, !used.contains(c.id) {
                used.insert(c.id)
                taxTokens.append(c)
            }
        }
        if let sLast = subAnchors.last, let tLast = totAnchors.last {
            for c in window
            where !used.contains(c.id) && c.cents > 0
                && sLast.lineIndex < c.lineIndex && c.lineIndex < tLast.lineIndex
                && CandidateFactory.rateSupported(lineIndex: c.lineIndex, rates: rates) {
                used.insert(c.id)
                taxTokens.append(c)
            }
        }
        taxTokens.sort { $0.lineIndex < $1.lineIndex }
        out.taxes = buildTaxes(taxTokens)
        for (i, _) in out.taxes.enumerated() {
            out.provenance["tax[\(i)]"] = prov("read", "hintOnlyUnclosed")
        }
    }
}

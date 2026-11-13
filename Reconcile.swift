// ============================================================
// Sổ Hóa Đơn — Reconcile.swift (TẦNG 5: đối chiếu số học + gợi ý
// vùng đọc lại). TÁCH từ khối giữ-nguyên-văn trong Parser.swift
// của Pha 1 (dòng 2126-3057) tại Pha 3 theo DESIGN-FINAL §3.5 +
// §7 điều kiện Pha 3.1: module riêng, GIA CỐ SafeMoney toàn bộ
// phép tính tiền (kể cả phép `implied * 100` cuối cùng), luật
// chứng cứ R1-R7 giữ nguyên.
//
// THIẾT KẾ: core-redo/RECONCILE-DESIGN.md. NGUYÊN TẮC CỨNG:
// reconcile có đúng 3 hành động — gắn cờ, đẩy Review Inbox,
// gợi ý vùng đọc lại (ROI). Nó KHÔNG BAO GIỜ ghi một con số suy
// diễn vào sổ: mọi sửa đổi đều TỪNG CHỮ SỐ có bằng chứng tại chỗ
// (bộ ba nội tại / token dung sai / dòng mồ côi), gắn provenance
// `inferred`, và ép needsReview. Sửa đổi thuần số học (đổi 1 chữ
// số cho khớp tổng) CHỈ là gợi ý — xem ca bẫy C6 trong bộ kiểm.
//
// NỐI ĐƯỜNG ĐỌC (Pha 3): ReadPipeline.swift gọi
// ReceiptParser.reconcile(...) ngay sau parse (F4) và điều phối
// vòng đọc-lại ROI qua ReconcileSession + RegionReReader. Khối
// này KHÔNG còn là mã chết kể từ Pha 3.
//
// LƯU Ý TÁCH FILE: ba helper của ReceiptParser mà module này
// dùng (matchGroups, matchQtyLine, trailingAmount) phải ở mức
// internal trong Parser.swift (bỏ `private`) — cùng một nguồn,
// cấm sao chép logic (luật một-module-đọc).
//
// MỌI phép tính tiền trong file này đi qua SafeMoney (kiểm tràn
// miền Int64) — cổng chuyển đổi duy nhất; phép toán trần trên
// giá trị tiền bị cấm (kiểm tĩnh Pha 3 quét việc này).
// ============================================================

import Foundation
import CoreGraphics

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
    // CANDIDATE (OPEN-F5-2): biến thể từ topCandidates(3) của đúng
    // token tiền của món. Oracle@3 đo tại Pha 3 trên corpus = 0/7 token (0/4
    // ca) token chết => GIỮ tier 3 (chỉ gợi ý) như DIGIT; tốt
    // nghiệp lên tier 2 chỉ khi phép đo thiết bị với top-3 bảo
    // đảm cho ra số oracle đủ cao (DESIGN-FINAL §3.5).
    case candidate = "CANDIDATE"

    var tier: Int {
        switch self {
        case .force: return 1
        case .token, .orphan: return 2
        case .digit, .sign, .candidate: return 3
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

// GÓI V4-4 / D-V4-3: toàn bộ ĐỘNG CƠ sửa sổ của v3 dưới đây (DFS,
// ReceiptParser.reconcile/parseAndReconcile + ReconcileSession) KHÔNG
// biên dịch vào bản giao khi project.yml của app khai
// GLKEEPER_V4_ONLY. Các KIỂU ở trên (ReconcileReport/Fix/RegionHint,
// ReOCRService, ReconcileConstants) VẪN biên dịch vì ReadOutcome, hồ
// sơ chẩn đoán và PendingDraft DTO dùng chúng. Harness không khai
// điều kiện này nên vẫn giữ nguyên đường đối chứng v3.
#if !GLKEEPER_V4_ONLY

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
    /// True khi một tổng hậu tố tràn miền Int64 trong lúc dựng —
    /// khi đó CẮT TỈA BỊ TẮT HẲN (fail-closed về phía tìm đủ: kết
    /// quả không đổi, chỉ mất tốc độ). Trên thực tế không tới được:
    /// mọi delta ứng viên bị chặn ở cổng ứng viên (|delta| <=
    /// 2 × maxAmountCents) và số món bị chặn bởi số dòng OCR, nên
    /// |tổng hậu tố| luôn nhỏ hơn miền Int64 nhiều bậc.
    private let boundsSaturated: Bool

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
        var saturated = false
        if n > 0 {
            for j in stride(from: n - 1, through: 0, by: -1) {
                let ds = self.byItem[j].map { $0.delta }
                // GIA CỐ PHA 3: cộng qua SafeMoney; tràn => đánh
                // dấu bão hoà để tắt tỉa (xem boundsSaturated).
                if let lo = SafeMoney.checkedAdd(sMin[j + 1], min(0, ds.min() ?? 0)) {
                    sMin[j] = lo
                } else { saturated = true }
                if let hi = SafeMoney.checkedAdd(sMax[j + 1], max(0, ds.max() ?? 0)) {
                    sMax[j] = hi
                } else { saturated = true }
            }
        }
        self.sufMin = sMin
        self.sufMax = sMax
        self.boundsSaturated = saturated
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
        if !boundsSaturated && (remaining < sufMin[j] || remaining > sufMax[j]) { return }
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

// MARK: - P2-3 — Lớp trọng tài (extension của ReceiptParser).
// BA helper dùng chung với F4 — matchGroups, matchQtyLine,
// trailingAmount — PHẢI ở mức internal trong Parser.swift kể từ
// khi tách file (Pha 3); chuyển đổi tiền qua SafeMoney.parseCents
// (Pha 0), không còn cổng moneyToCents nào trong dòng v3.

extension ReceiptParser {

    // MARK: Điểm vào

    /// parse() nguyên vẹn + một lượt trọng tài. Cảnh báo trả về =
    /// cảnh báo validate() gốc (tính trên kết quả CHƯA sửa) + ghi chú
    /// của lớp trọng tài — validate() không bị sửa, lớp này chỉ bổ
    /// sung. Quyết định trình bày cuối cùng thuộc gói tích hợp.
    static func parseAndReconcile(lines: [OCRLine], lineBoxes: [CGRect?]? = nil,
                                  candidateVariants: [Int: [Int]] = [:])
        -> (result: ParseResult, report: ReconcileReport) {
        let parsed = parse(lines: lines)
        let (report, reconciled) = reconcile(result: parsed, lines: lines,
                                             lineBoxes: lineBoxes,
                                             candidateVariants: candidateVariants)
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
    /// `candidateVariants`: chỉ số món -> các giá trị xu biến thể
    /// từ topCandidates(3) của token tiền của món đó (kênh
    /// CANDIDATE). Mặc định rỗng = kênh ngủ (trạng thái Pha 3).
    static func reconcile(result r: ParseResult, lines rawLines: [OCRLine],
                          lineBoxes: [CGRect?]? = nil,
                          candidateVariants: [Int: [Int]] = [:])
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
            // GIA CỐ PHA 3: tổng thuế + tổng neo đi qua SafeMoney —
            // tràn miền => không kiểm chứng được => từ chối theo
            // xung đột neo (fail-closed), không để phép cộng trần
            // bẫy tiến trình (họ lỗi L-2026-11-11-8).
            let taxSum = SafeMoney.sumCents(r.taxes.map { $0.amountCents })
            let anchorDiff = taxSum
                .flatMap { SafeMoney.checkedAdd(subtotal, $0) }
                .flatMap { SafeMoney.checkedSubtract($0, total) }
            if anchorDiff == nil || abs(anchorDiff!) > 2 {
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
            // GIA CỐ PHA 3 (khoản treo của Pha 1): phép trừ trần +
            // phép `implied * 100` trần CUỐI CÙNG của khối — nay
            // qua SafeMoney. withinPercent dùng dạng chia
            // implied <= (15 * base) / 100 với tử số kiểm tràn, và
            // trả false khi base <= 0 — nên điều kiện `subtotal > 0`
            // được GIỮ NGUYÊN để hành vi ở subtotal == 0 không đổi
            // (tương đương đã chứng minh trên 200k cặp ở crashfix).
            // Tràn khi trừ => neo không kiểm chứng được => xung
            // đột neo (fail-closed).
            guard let implied = SafeMoney.checkedSubtract(total, subtotal) else {
                rep.status = .anchorConflict
                rep.notes.append("total - subtotal tràn miền số nguyên — số neo không kiểm chứng được, từ chối sửa.")
                rawHints.append((.totals, .anchorConflict, nil))
                rep.regionHints = finalizeHints()
                rep.requiresReview = true
                return (rep, r)
            }
            if implied < 0 || (subtotal > 0 && !SafeMoney.withinPercent(implied: implied, ofBase: subtotal, percent: 15)) {
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

        // GIA CỐ PHA 3: Σ món + hiệu số qua SafeMoney. Tràn không
        // thể xảy ra với đầu vào đã qua cổng SafeMoney của F4,
        // nhưng lớp này không tự giả định — tràn => từ chối theo
        // họ TOO_COMPLEX (fail-closed, không sửa gì).
        guard let sumItems = SafeMoney.sumCents(items.map { $0.amountCents ?? 0 }),
              let delta = SafeMoney.checkedSubtract(subtotal, sumItems) else {
            rep.status = .tooComplex
            rep.notes.append("Tổng tiền các món tràn miền số nguyên — không đối chiếu được, từ chối sửa (fail-closed).")
            rep.requiresReview = true
            return (rep, r)
        }
        rep.moneyDeltaCents = delta
        if let sold = r.itemsSold {
            // NỐI LUẬT IN (Pha 3): đích E3 tính theo printSemantics
            // của hãng (dữ liệu vendors.json) đúng như validate()
            // của F4 — onePerLine đếm DÒNG tiền dương, byQuantity
            // cộng số lượng. Không nối luật này, hoá đơn Walmart có
            // dòng qty = 2 hợp lệ bị báo lệch lượng GIẢ (ca L-R04
            // trong expectations.md mục B).
            rep.qtyDelta = sold - reconcileQtySum(items, contribution: r.soldContribution)
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
                        // GIA CỐ PHA 3: qty × unit qua SafeMoney —
                        // tràn => không sinh ứng viên FORCE
                        // (fail-closed ngay tại cổng ứng viên).
                        let forced = SafeMoney.checkedMultiply(it.qty, by: it.unitPriceCents ?? 0)
                        if let forced = forced, forced != amount,
                           abs(forced) < ReconcileConstants.maxAmountCents,
                           let fdelta = SafeMoney.checkedSubtract(forced, amount) {
                            cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                         oldValue: amount, newValue: forced,
                                                         delta: fdelta,
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
                        // GIA CỐ PHA 3: delta của mọi ứng viên qua
                        // SafeMoney (trừ/nhân kiểm tràn) — tràn =>
                        // bỏ ứng viên đó, không bẫy.
                        for v in reconcileDigitVariants(amount) {
                            if let vdelta = SafeMoney.checkedSubtract(v, amount) {
                                cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                             oldValue: amount, newValue: v,
                                                             delta: vdelta,
                                                             channel: .digit, tier: 3))
                            }
                        }
                        if let neg = SafeMoney.checkedMultiply(amount, by: -1),
                           let sdelta = SafeMoney.checkedSubtract(neg, amount) {
                            cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                         oldValue: amount, newValue: neg,
                                                         delta: sdelta,
                                                         channel: .sign, tier: 3))
                        }
                        // KÊNH CANDIDATE (OPEN-F5-2, DESIGN-FINAL
                        // §3.5): biến thể từ topCandidates(3) của
                        // ĐÚNG token tiền của món này, do tầng OCR
                        // cung cấp qua tham số candidateVariants.
                        // Số oracle@3 đo ở Pha 3 trên corpus = 0/7 token (0/4
                        // ca) token chết (văn kiện oracle trong
                        // v3-phase3/) => kênh GIỮ Ở TẦNG GỢI Ý
                        // (tier 3 như DIGIT) cho tới khi phép đo
                        // thiết bị với topCandidates(3) bảo đảm cho
                        // ra số oracle khác — điều kiện tốt nghiệp
                        // ghi ở DESIGN-FINAL. ReadPipeline không
                        // truyền variants ở bản này => kênh ngủ.
                        for v in candidateVariants[k] ?? [] where v != amount {
                            if let vdelta = SafeMoney.checkedSubtract(v, amount) {
                                cands[k].append(ReconcileFix(itemIndex: k, field: .amount,
                                                             oldValue: amount, newValue: v,
                                                             delta: vdelta,
                                                             channel: .candidate, tier: 3))
                            }
                        }
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
            let qd = sold - reconcileQtySum(r2.items, contribution: r.soldContribution)
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
                if SafeMoney.checkedMultiply(it.qty, by: nu) == amount {
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
        // GIA CỐ PHA 3: Σ sau sửa qua SafeMoney; tràn (không tới
        // được với đầu vào đã qua cổng) => coi như chưa khép.
        let sum2 = SafeMoney.sumCents(r2.items.map { $0.amountCents ?? 0 }) ?? Int.min
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
        // GIA CỐ PHA 3: tích qua SafeMoney; tràn => KHÔNG nhất
        // quán (fail-closed — probe FORCE tự nó cũng bị chặn ở
        // cổng nhân kiểm tràn nên không ứng viên nào lọt).
        return (true, SafeMoney.checkedMultiply(it.qty, by: unit) == amount)
    }

    /// Σ đóng góp số lượng các món tiền dương (đích E3) theo LUẬT
    /// IN của hãng: byQuantity cộng số lượng; onePerLine đếm số
    /// DÒNG tiền dương (khớp validate() của F4). Món âm (giảm giá)
    /// không tính ở cả hai luật.
    static func reconcileQtySum(_ its: [ParsedLineItem],
                                contribution: String = "byQuantity") -> Int {
        let positives = its.filter { ($0.amountCents ?? 0) > 0 }
        if contribution == "onePerLine" { return positives.count }
        return positives.reduce(0) { $0 + $1.qty }
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
            guard let cents = SafeMoney.parseCents(norm, negative: negative) else { continue }
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

#endif // !GLKEEPER_V4_ONLY — hết động cơ sửa sổ v3 (V4-4)

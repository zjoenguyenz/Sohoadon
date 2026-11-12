import Foundation
import CoreGraphics

// F3 — RÁP DÒNG (LineAssembly), CORE-V3 Pha 2.
// Đặc tả: DESIGN-FINAL §3.3 (+ ghép xuyên trang §3.1(d)/§3.3(a)
// bản chốt). Gương Python: assembly_mirror.py — hai bản cài CÙNG
// một thuật toán; gương là căn cứ số ở Pha 2, bản Swift được kiểm
// bằng lexer tĩnh + cổng biên dịch CI ở pha tích hợp (C2).
//
// LUẬT RÁP (AssemblyPolicy "assembly-v3-p2"):
//  1. KHỬ TRÙNG TRƯỚC RÁP trên các cặp hộp giao mạnh (IoU ≥ 0.5):
//     bất đồng tiền trên cùng vùng -> CONTESTED-MERGE (giữ mảnh
//     tin cậy cao hơn, mảnh thua thành biến thể + cờ contested —
//     nguyên liệu F5); tương đồng chữ ≥ 0.8 hoặc chứa-lẫn-nhau ->
//     TRÙNG MỜ (giữ tin cậy cao hơn, hợp nhất alternates). Sau
//     bước này bất biến chống nhân đôi (IoU ≥ 0.5 ∧ tương đồng
//     ≥ 0.8 giữa các mảnh giữ lại) đúng theo xây dựng — vẫn ĐO
//     lại và ghi vào kết quả.
//  2. RÁP HÀNG: mảnh B nhập hàng của neo A khi khoảng tâm dọc
//     ≤ 0.75 × chiều cao dòng trung vị (ngoài biên = cấm nối) VÀ
//     (chồng dọc ≥ 50% chiều cao nhỏ hơn HOẶC khoảng tâm ≤ 0.5 ×
//     trung vị) VÀ tương thích ngang (chồng-x với phạm vi hàng
//     ≤ 10% bề rộng mảnh nhỏ hơn — hai mảnh chồng theo cột là
//     hai dòng in khác nhau). Hiệu chuẩn trên hộp thật L-R10:
//     luật dọc thuần cho 21/25 dòng; luật đầy đủ cho 25/25
//     (test_f3.py T-F3-1). Trong hàng: sắp theo x, spans + mốc
//     ngắt cột (khoảng trống > 15% bề rộng tờ).
//  3. GHÉP XUYÊN TRANG cho hoá đơn dài: bỏ phiếu dy thô -> neo
//     chắc (IoU + chữ) -> khớp affine dọc (s, t) trên tâm neo ->
//     một lần ráp chung. Không neo -> fail-closed "unanchored".

struct Fragment {
    var id: Int
    var text: String
    var alternates: [AltText]
    var confidence: Double
    var box: CGRect             // chuẩn hoá 0..1, gốc dưới-trái
    var passID: String
    var tileIndex: Int?
    var regionID: String?
    var pageIndex: Int = 0
    /// Biến thể thua trong contested-merge (chỉ trong bộ nhớ —
    /// sang chẩn đoán qua alternates + cờ contested của dòng).
    var contestedFrom: [String] = []
}

struct AssembledLine {
    var text: String
    var confidence: Double
    var box: CGRect
    var spans: [DiagSpan]
    var passSources: [String]
    var contested: Bool
    var alternates: [AltText]
    /// Chỉ số span mà sau nó có ngắt cột (> 15% bề rộng tờ).
    /// Trong bộ nhớ cho F4 — giản đồ chẩn đoán v2 chưa có trường.
    var columnBreaks: [Int]
}

struct AssemblyResult {
    var lines: [AssembledLine]
    var dedupeDropped: [DiagDroppedFragment]
    var invariantViolations: Int
    /// Chỉ đường lát trên thiết bị điền (Pha 2b) — ngoại tuyến để rỗng.
    var tileMap: [DiagRect] = []
    var blindBands: [DiagRect] = []
}

struct StitchInfo {
    var status: String          // single-page | anchored |
                                // anchored-translation-only | unanchored
    var transforms: [Int: (scale: Double, shift: Double)]
    var anchors: Int
}

enum AssemblyPolicy {
    static let policyID = "assembly-v3-p2"
    static let dedupeIoU = 0.5
    static let dedupeSimilarity = 0.8
    static let rowOverlapFraction = 0.5
    static let rowCenterHalfMedian = 0.5
    static let rowCenterForbiddenMedian = 0.75
    static let rowXOverlapTolerance = 0.10
    static let columnGapFraction = 0.15
    /// Ngưỡng neo chắc khi ghép trang.
    static let stitchAnchorIoU = 0.3
    static let stitchVoteSimilarity = 0.9
    static let stitchTextAnchorSimilarity = 0.85
    static let stitchTextAnchorMinLength = 12
}

/// Tương đồng chữ Ratcliff–Obershelp (khối khớp dài nhất, đệ
/// quy) — cùng thuật toán với difflib.SequenceMatcher.ratio mà
/// gương dùng; miền chuỗi hoá đơn ngắn không chạm autojunk.
enum TextSimilarity {
    static func ratio(_ a: String, _ b: String) -> Double {
        if a.isEmpty && b.isEmpty { return 1 }
        if a.isEmpty || b.isEmpty { return 0 }
        let x = Array(a), y = Array(b)
        let m = matched(x, y, 0, x.count, 0, y.count)
        return 2.0 * Double(m) / Double(x.count + y.count)
    }

    private static func matched(_ a: [Character], _ b: [Character],
                                _ alo: Int, _ ahi: Int,
                                _ blo: Int, _ bhi: Int) -> Int {
        if alo >= ahi || blo >= bhi { return 0 }
        var bestI = alo, bestJ = blo, bestK = 0
        for i in alo..<ahi {
            for j in blo..<bhi {
                var k = 0
                while i + k < ahi && j + k < bhi && a[i + k] == b[j + k] {
                    k += 1
                }
                if k > bestK { bestI = i; bestJ = j; bestK = k }
            }
        }
        if bestK == 0 { return 0 }
        return bestK
            + matched(a, b, alo, bestI, blo, bestJ)
            + matched(a, b, bestI + bestK, ahi, bestJ + bestK, bhi)
    }

    static func normalized(_ t: String) -> String {
        t.uppercased().split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func containsEither(_ a: String, _ b: String) -> Bool {
        let na = normalized(a), nb = normalized(b)
        if na.isEmpty || nb.isEmpty { return false }
        return na.contains(nb) || nb.contains(na)
    }
}

enum LineAssembly {

    // MARK: hình học + tiền

    static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let iw = max(0.0, min(a.maxX, b.maxX) - max(a.minX, b.minX))
        let ih = max(0.0, min(a.maxY, b.maxY) - max(a.minY, b.minY))
        let inter = iw * ih
        let union = a.width * a.height + b.width * b.height - inter
        return union > 0 ? inter / union : 0
    }

    private static func centerY(_ f: Fragment) -> Double {
        Double(f.box.midY)
    }

    private static func moneyValues(_ text: String) -> Set<Int> {
        var out = Set<Int>()
        for t in SafeMoney.tokens(in: text) {
            if let v = SafeMoney.parseCents(t.token, negative: t.negative) {
                out.insert(v)
            }
        }
        return out
    }

    private static func median(_ xs: [Double]) -> Double {
        if xs.isEmpty { return 0 }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    // MARK: khử trùng

    private static func mergeAlternates(winner: inout Fragment,
                                        loser: Fragment) {
        var seen = Set(winner.alternates.map { $0.text })
        seen.insert(winner.text)
        let extra = [AltText(text: loser.text,
                             confidence: loser.confidence)]
            + loser.alternates
        for a in extra where !seen.contains(a.text) {
            winner.alternates.append(a)
            seen.insert(a.text)
        }
    }

    static func dedupe(_ fragments: [Fragment])
        -> (kept: [Fragment], dropped: [DiagDroppedFragment]) {
        // Thứ tự: tâm dọc giảm dần, x tăng dần, id tăng dần.
        let ordered = fragments.sorted(by: {
            if centerY($0) != centerY($1) { return centerY($0) > centerY($1) }
            if $0.box.minX != $1.box.minX { return $0.box.minX < $1.box.minX }
            return $0.id < $1.id
        })
        var kept: [Fragment] = []
        var dropped: [DiagDroppedFragment] = []
        for f in ordered {
            var handled = false
            for ki in kept.indices {
                let k = kept[ki]
                if iou(f.box, k.box) < AssemblyPolicy.dedupeIoU { continue }
                let mf = moneyValues(f.text), mk = moneyValues(k.text)
                let contested = !mf.isEmpty && !mk.isEmpty
                    && mf.isDisjoint(with: mk)
                if !contested
                    && TextSimilarity.ratio(f.text, k.text)
                        < AssemblyPolicy.dedupeSimilarity
                    && !TextSimilarity.containsEither(f.text, k.text) {
                    continue
                }
                var winner = f.confidence > k.confidence ? f : k
                let loser = f.confidence > k.confidence ? k : f
                mergeAlternates(winner: &winner, loser: loser)
                let reason: String
                if contested {
                    winner.contestedFrom.append(loser.text)
                    reason = "contested-variant"
                } else if TextSimilarity.containsEither(f.text, k.text)
                            && TextSimilarity.ratio(f.text, k.text)
                                < AssemblyPolicy.dedupeSimilarity {
                    reason = "contained-duplicate"
                } else {
                    reason = "fuzzy-duplicate"
                }
                dropped.append(DiagDroppedFragment(fragmentID: loser.id,
                                                   reason: reason))
                if winner.id == f.id {
                    kept.remove(at: ki)
                    kept.append(winner)
                } else {
                    kept[ki] = winner
                }
                handled = true
                break
            }
            if !handled { kept.append(f) }
        }
        return (kept, dropped)
    }

    static func countInvariantViolations(_ kept: [Fragment]) -> Int {
        var v = 0
        for i in kept.indices {
            for j in kept.indices where j > i {
                if iou(kept[i].box, kept[j].box)
                    >= AssemblyPolicy.dedupeIoU
                    && TextSimilarity.ratio(kept[i].text, kept[j].text)
                        >= AssemblyPolicy.dedupeSimilarity {
                    v += 1
                }
            }
        }
        return v
    }

    // MARK: ráp hàng

    static func assemble(_ fragments: [Fragment],
                         xCompat: Bool = true) -> AssemblyResult {
        let (kept0, dropped) = dedupe(fragments)
        let violations = countInvariantViolations(kept0)
        if kept0.isEmpty {
            return AssemblyResult(lines: [], dedupeDropped: dropped,
                                  invariantViolations: violations)
        }
        let med = median(kept0.map { Double($0.box.height) })
        let pageW = kept0.map { Double($0.box.maxX) }.max()!
            - kept0.map { Double($0.box.minX) }.min()!
        let ordered = kept0.sorted(by: {
            if centerY($0) != centerY($1) { return centerY($0) > centerY($1) }
            if $0.box.minX != $1.box.minX { return $0.box.minX < $1.box.minX }
            return $0.id < $1.id
        })
        struct Row {
            var anchor: Fragment
            var members: [Fragment]
            var x0: Double
            var x1: Double
        }
        var rows: [Row] = []
        for f in ordered {
            var best: (dc: Double, idx: Int)? = nil
            for (ri, r) in rows.enumerated() {
                let a = r.anchor
                let dc = abs(centerY(f) - centerY(a))
                if dc > AssemblyPolicy.rowCenterForbiddenMedian * med {
                    continue
                }
                let ov = min(Double(f.box.maxY), Double(a.box.maxY))
                    - max(Double(f.box.minY), Double(a.box.minY))
                let vert = (ov / min(Double(f.box.height),
                                     Double(a.box.height))
                            >= AssemblyPolicy.rowOverlapFraction)
                    || (dc <= AssemblyPolicy.rowCenterHalfMedian * med)
                if !vert { continue }
                if xCompat {
                    let ox = min(Double(f.box.maxX), r.x1)
                        - max(Double(f.box.minX), r.x0)
                    if ox > AssemblyPolicy.rowXOverlapTolerance
                        * min(Double(f.box.width), r.x1 - r.x0) {
                        continue
                    }
                }
                if best == nil || dc < best!.dc { best = (dc, ri) }
            }
            if let b = best {
                rows[b.idx].members.append(f)
                rows[b.idx].x0 = min(rows[b.idx].x0, Double(f.box.minX))
                rows[b.idx].x1 = max(rows[b.idx].x1, Double(f.box.maxX))
            } else {
                rows.append(Row(anchor: f, members: [f],
                                x0: Double(f.box.minX),
                                x1: Double(f.box.maxX)))
            }
        }
        var lines: [AssembledLine] = []
        for r in rows {
            let ms = r.members.sorted(by: {
                if $0.box.minX != $1.box.minX {
                    return $0.box.minX < $1.box.minX
                }
                return $0.id < $1.id
            })
            var text = ""
            var spans: [DiagSpan] = []
            var breaks: [Int] = []
            var prevX1: Double? = nil
            for (idx, f) in ms.enumerated() {
                if let p = prevX1,
                   Double(f.box.minX) - p
                    > AssemblyPolicy.columnGapFraction * pageW {
                    breaks.append(idx - 1)
                }
                let start = text.count + (text.isEmpty ? 0 : 1)
                text = text.isEmpty ? f.text : text + " " + f.text
                spans.append(DiagSpan(fragmentID: f.id,
                                      charStart: start,
                                      charEnd: start + f.text.count))
                prevX1 = Double(f.box.maxX)
            }
            let x0 = ms.map { $0.box.minX }.min()!
            let y0 = ms.map { $0.box.minY }.min()!
            let x1 = ms.map { $0.box.maxX }.max()!
            let y1 = ms.map { $0.box.maxY }.max()!
            var alts: [AltText] = []
            var seen: Set<String> = [text]
            var contested = false
            for f in ms {
                if !f.contestedFrom.isEmpty { contested = true }
                for a in f.alternates where !seen.contains(a.text) {
                    alts.append(a)
                    seen.insert(a.text)
                }
            }
            lines.append(AssembledLine(
                text: text,
                confidence: ms.map { $0.confidence }.min()!,
                box: CGRect(x: x0, y: y0, width: x1 - x0,
                            height: y1 - y0),
                spans: spans,
                passSources: Array(Set(ms.map { $0.passID })).sorted(),
                contested: contested,
                alternates: alts,
                columnBreaks: breaks))
        }
        return AssemblyResult(lines: lines, dedupeDropped: dropped,
                              invariantViolations: violations)
    }

    // MARK: ghép xuyên trang (hoá đơn dài)

    private static func fitAffine(_ pairs: [(Double, Double)])
        -> (Double, Double)? {
        let xs = pairs.map { $0.0 }
        guard let mx = xs.max(), let mn = xs.min(), mx - mn >= 0.05,
              !pairs.isEmpty else { return nil }
        let n = Double(pairs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = pairs.map { $0.1 }.reduce(0, +) / n
        var sxx = 0.0, sxy = 0.0
        for (x, y) in pairs {
            sxx += (x - meanX) * (x - meanX)
            sxy += (x - meanX) * (y - meanY)
        }
        if sxx <= 0 { return nil }
        let s = sxy / sxx
        return (s, meanY - s * meanX)
    }

    static func assemblePages(_ fragments: [Fragment])
        -> (result: AssemblyResult, stitch: StitchInfo) {
        let pages = Array(Set(fragments.map { $0.pageIndex })).sorted()
        if pages.count <= 1 {
            return (assemble(fragments),
                    StitchInfo(status: "single-page", transforms: [:],
                               anchors: 0))
        }
        var merged: [Fragment] = fragments.filter {
            $0.pageIndex == pages[0]
        }
        var transforms: [Int: (scale: Double, shift: Double)] = [:]
        var totalAnchors = 0
        var status = "anchored"
        for p in pages.dropFirst() {
            var cand = fragments.filter { $0.pageIndex == p }
            var votes: [(dy: Double, fid: Int)] = []
            for g in merged {
                for f in cand
                where TextSimilarity.ratio(g.text, f.text)
                        >= AssemblyPolicy.stitchVoteSimilarity {
                    votes.append((centerY(g) - centerY(f), f.id))
                }
            }
            if votes.isEmpty {
                transforms[p] = (1.0, -1.05 * Double(p))
                status = "unanchored"
                for i in cand.indices {
                    cand[i].box = cand[i].box.offsetBy(
                        dx: 0, dy: CGFloat(-1.05 * Double(p)))
                }
                merged.append(contentsOf: cand)
                continue
            }
            // Bỏ phiếu bin 0.01 (làm tròn nửa-chẵn như Python round).
            var binOrder: [Int] = []
            var bins: [Int: [(Double, Int)]] = [:]
            for v in votes {
                let key = Int((v.dy / 0.01).rounded(.toNearestOrEven))
                if bins[key] == nil { binOrder.append(key) }
                bins[key, default: []].append(v)
            }
            var winKey = binOrder[0]
            var winScore = (-1, -1)
            for key in binOrder {
                let vs = bins[key]!
                let score = (vs.count, Set(vs.map { $0.1 }).count)
                if score > winScore { winScore = score; winKey = key }
            }
            let dy0 = median(bins[winKey]!.map { $0.0 })
            var shifted = cand
            for i in shifted.indices {
                shifted[i].box = shifted[i].box.offsetBy(dx: 0,
                                                         dy: CGFloat(dy0))
            }
            var pairs: [(Double, Double)] = []
            var anchored = Set<Int>()
            for f in shifted {
                var best: (Double, Fragment)? = nil
                for g in merged {
                    let v = iou(f.box, g.box)
                    if v >= AssemblyPolicy.stitchAnchorIoU
                        && TextSimilarity.ratio(f.text, g.text)
                            >= AssemblyPolicy.dedupeSimilarity {
                        if best == nil || v > best!.0 { best = (v, g) }
                    }
                }
                if let b = best {
                    pairs.append((centerY(f), centerY(b.1)))
                    anchored.insert(f.id)
                }
            }
            var fit = pairs.count >= 2 ? fitAffine(pairs) : nil
            if fit == nil {
                var pairs2: [(Double, Double)] = []
                var ids2 = Set<Int>()
                for f in cand where f.text.count
                        >= AssemblyPolicy.stitchTextAnchorMinLength {
                    var best: (Double, Fragment)? = nil
                    for g in merged
                    where TextSimilarity.ratio(f.text, g.text)
                            >= AssemblyPolicy.stitchTextAnchorSimilarity {
                        let dd = abs((centerY(g) - centerY(f)) - dy0)
                        if best == nil || dd < best!.0 { best = (dd, g) }
                    }
                    if let b = best {
                        pairs2.append((centerY(f) + dy0, centerY(b.1)))
                        ids2.insert(f.id)
                    }
                }
                if pairs2.count >= 2, let f2 = fitAffine(pairs2) {
                    fit = f2
                    anchored = ids2
                }
            }
            if let (sLoc, tLoc) = fit {
                let tTot = sLoc * dy0 + tLoc
                transforms[p] = (sLoc, tTot)
                totalAnchors += anchored.count
                for i in cand.indices {
                    let c = centerY(cand[i])
                    let newH = sLoc * Double(cand[i].box.height)
                    let newCenter = sLoc * c + tTot
                    cand[i].box = CGRect(
                        x: cand[i].box.minX,
                        y: CGFloat(newCenter - newH / 2),
                        width: cand[i].box.width,
                        height: CGFloat(newH))
                }
                merged.append(contentsOf: cand)
            } else {
                transforms[p] = (1.0, dy0)
                if status == "anchored" {
                    status = "anchored-translation-only"
                }
                totalAnchors += anchored.count
                merged.append(contentsOf: shifted)
            }
        }
        return (assemble(merged),
                StitchInfo(status: status, transforms: transforms,
                           anchors: totalAnchors))
    }
}

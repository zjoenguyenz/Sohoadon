// ============================================================
// Sổ Hóa Đơn — RegionReReader.swift (đọc-lại-ROI, TẦNG 5 phụ)
//
// NHÃN TRUNG THỰC (giữ nguyên văn theo DESIGN-FINAL §3.5(d)):
// đọc-lại-ROI là SÁNG TÁC TỔNG HỢP của dự án — không hãng nào
// trong bộ mổ xẻ công bố nó như một phương pháp; họ hàng gần
// nhất là chấm chất lượng theo đoạn (biết đọc lại ở đâu) và
// liệt kê mode tăng cường theo vùng dòng (đọc lại bằng gì).
// Điều kiện sống còn của nó là số đo trên các ca mang tên
// (L-R05/08/09), không phải lập luận.
//
// VAI TRÒ: biến ReconcileRegionHint (từ Reconcile.swift) thành
// vùng ảnh cụ thể để đọc lại, theo luật chốt của DESIGN-FINAL
// §3.5(d) + giao thức RECONCILE-DESIGN §6:
//   - Đích nhắm = regionHints ∩ QualityMap: vùng có CẢ hai tín
//     hiệu (lệch sổ + điểm chất lượng thấp) xếp trước; vùng chỉ
//     một tín hiệu vẫn đủ điều kiện nhưng xếp sau.
//   - Vùng = hợp hộp các dòng của hint, NỚI ±50% CHIỀU CAO MỖI
//     PHÍA (tổng ×2, kẹp [0,1]) theo AMD-001 (AMENDMENTS.md,
//     2026-11-11 — điểm nối Pha 4): luật nới vùng thống nhất cho
//     MỌI thành phần dựng vùng, khớp RECONCILE-DESIGN §6 và
//     band() trong Reconcile.swift (cùng ±50% mỗi phía). Văn bản
//     DESIGN-FINAL §3.5(d) ghi ×1.5 tổng — AMD-001 ghi rõ là nó
//     THAY THẾ số đó. Chiều ngang: band luôn là toàn bề rộng
//     (x = 0, w = 1) theo cấu trúc của file này nên nới ngang
//     ±50% bị kẹp [0,1] nuốt trọn — không đổi hình học. band dựng
//     sẵn của hint chỉ dùng khi KHÔNG có hộp dòng thô để tự dựng
//     (đường dự phòng, không nới lại lần hai).
//   - Ngân sách: ≤ 2 vùng/vòng, ≤ 2 vòng (ReconcileSession giữ
//     luật vòng), trần mềm 4 giây cho toàn F5 (fail-closed: hết
//     giờ => giữ trạng thái tốt nhất đã có, không nhận thêm).
//   - Luật đơn điệu 3 bậc nằm ở ReconcileSession.isBetter — file
//     này chỉ chọn vùng + gọi bộ nhận dạng; QUYẾT ĐỊNH NHẬN hay
//     KHÔNG thuộc về session.
//
// NGOẠI TUYẾN (Pha 3): bộ nhận dạng ảnh thật KHÔNG nằm ở đây —
// nó là closure được tiêm vào (trên thiết bị: cắt vùng từ ảnh
// gốc + phóng + engine của Pha 2; trong kiểm ngoại tuyến: mô
// phỏng từ candidates đã ghi). Không tiêm recognizer =>
// recognizeRegion trả [] => vòng ROI kết thúc vô hại (giữ kết
// quả tốt nhất), đúng kỷ luật fail-closed.
// ============================================================

import Foundation
import CoreGraphics

/// Một vùng đích đọc lại đã xếp hạng.
struct ROITargetRegion {
    /// Khung vùng (toạ độ chuẩn hoá 0..1, gốc dưới-trái như hộp Vision).
    var band: CGRect
    /// Chỉ số các hint đã góp vào vùng này (sau khi gộp chồng lấn).
    var hintIndices: [Int]
    /// Có tín hiệu QualityMap thấp giao với vùng hay không.
    var hasQualitySignal: Bool
    /// Điểm chất lượng thấp nhất của QualityMap trong vùng (nil = không có mục nào).
    var lowestQualityScore: Double?
    /// Thứ hạng: 0 = hai tín hiệu (ưu tiên cao nhất), 1 = một tín hiệu.
    var rank: Int { hasQualitySignal ? 0 : 1 }
}

final class RegionReReader: ReOCRService {

    /// Hệ số nới dọc TỔNG của vùng so với hợp hộp dòng: 2.0 =
    /// ±50% mỗi phía (AMD-001 — thay số 1.5 của DESIGN-FINAL).
    static let verticalExpansionFactor: Double = 2.0
    /// Ngưỡng "điểm chất lượng thấp" của QualityMap (thang 0–100 của Pha 0/2).
    static let lowQualityThreshold: Double = 50.0
    /// Trần vùng mỗi vòng (khớp ReconcileSession.maxRegionsPerRound).
    static let maxRegionsPerRound = 2
    /// Trần mềm 4 giây cho toàn bộ phần F5+ROI của một lần đọc
    /// (DESIGN-FINAL §3.5): đo bằng đồng hồ đơn điệu; quá trần thì
    /// vòng lặp dừng và giữ trạng thái tốt nhất (fail-closed).
    static let softDeadlineSeconds: Double = 4.0

    private let qualityMap: [QualityMapEntry]
    /// Bộ nhận dạng vùng: (vùng, hệ số phóng) -> dòng đọc lại.
    /// Trên thiết bị do Pha 4 tiêm vào; nil = không đọc lại được.
    private let recognizer: ((CGRect, Double) -> [OCRLine])?

    init(qualityMap: [QualityMapEntry] = [],
         recognizer: ((CGRect, Double) -> [OCRLine])? = nil) {
        self.qualityMap = qualityMap
        self.recognizer = recognizer
    }

    // MARK: - Dựng vùng (thuần — kiểm ngoại tuyến được)

    /// Hợp hộp của các dòng trong range, nới dọc ±50% mỗi phía
    /// (tổng ×2 theo AMD-001), kẹp [0,1]. nil khi không dòng nào có hộp.
    static func band(for range: ClosedRange<Int>, lineBoxes: [CGRect?]) -> CGRect? {
        let boxes = range.compactMap { i -> CGRect? in
            (i >= 0 && i < lineBoxes.count) ? lineBoxes[i] : nil
        }
        guard let lo = boxes.map({ $0.minY }).min(),
              let hi = boxes.map({ $0.maxY }).max() else { return nil }
        let h = hi - lo
        let grow = h * (verticalExpansionFactor - 1) / 2
        let y0 = max(0.0, lo - grow)
        let y1 = min(1.0, hi + grow)
        return CGRect(x: 0, y: y0, width: 1, height: max(0, y1 - y0))
    }

    /// Nới một khung có sẵn theo cùng luật AMD-001 (±50% mỗi phía,
    /// tổng ×2) (dùng khi hint chỉ cho hộp mảnh, chưa phải band).
    static func expanded(_ box: CGRect) -> CGRect {
        let grow = box.height * (verticalExpansionFactor - 1) / 2
        let y0 = max(0.0, Double(box.minY) - grow)
        let y1 = min(1.0, Double(box.maxY) + grow)
        return CGRect(x: 0, y: y0, width: 1, height: max(0, y1 - y0))
    }

    /// Chọn + xếp hạng vùng đích từ danh sách hint.
    /// - Hạt giống vùng: hộp dòng của hint (lineRange + lineBoxes);
    ///   thiếu hộp dòng thì dùng band dựng sẵn của hint (không nới lại).
    /// - Giao QualityMap: mục nào hộp của nó giao với vùng và
    ///   (điểm < ngưỡng thấp HOẶC có suspectedDefect) => tín hiệu thứ hai.
    /// - Gộp các vùng chồng lấn theo trục dọc thành một vùng.
    /// - Sắp: hai-tín-hiệu trước, rồi theo priority của hint, rồi
    ///   điểm chất lượng thấp nhất. Cắt ở maxRegions.
    static func targetRegions(hints: [ReconcileRegionHint],
                              lineBoxes: [CGRect?]? = nil,
                              qualityMap: [QualityMapEntry] = [],
                              maxRegions: Int = RegionReReader.maxRegionsPerRound)
        -> [ROITargetRegion] {
        var seeded: [ROITargetRegion] = []
        for (idx, hint) in hints.enumerated() {
            var seed: CGRect? = nil
            if let range = hint.lineRange, let boxes = lineBoxes {
                seed = band(for: range, lineBoxes: boxes)
            }
            if seed == nil { seed = hint.band } // dự phòng: band của Reconcile, đã nới theo luật của nó
            guard let band = seed else { continue }
            var lowest: Double? = nil
            var hasQ = false
            for entry in qualityMap {
                let eb = CGRect(x: entry.box.x, y: entry.box.y,
                                width: entry.box.width, height: entry.box.height)
                guard eb.intersects(band) else { continue }
                if entry.score < lowQualityThreshold || entry.suspectedDefect != nil {
                    hasQ = true
                    lowest = min(lowest ?? entry.score, entry.score)
                }
            }
            seeded.append(ROITargetRegion(band: band, hintIndices: [idx],
                                          hasQualitySignal: hasQ,
                                          lowestQualityScore: lowest))
        }
        // Gộp vùng chồng lấn dọc (các band đều full-width nên chỉ
        // cần so khoảng y).
        seeded.sort { $0.band.minY < $1.band.minY }
        var merged: [ROITargetRegion] = []
        for r in seeded {
            if var last = merged.last,
               r.band.minY <= last.band.maxY && r.band.maxY >= last.band.minY {
                let y0 = min(last.band.minY, r.band.minY)
                let y1 = max(last.band.maxY, r.band.maxY)
                last.band = CGRect(x: 0, y: y0, width: 1, height: max(0, y1 - y0))
                last.hintIndices += r.hintIndices
                last.hasQualitySignal = last.hasQualitySignal || r.hasQualitySignal
                switch (last.lowestQualityScore, r.lowestQualityScore) {
                case let (a?, b?): last.lowestQualityScore = min(a, b)
                case (nil, let b?): last.lowestQualityScore = b
                default: break
                }
                merged[merged.count - 1] = last
            } else {
                merged.append(r)
            }
        }
        // Xếp hạng: hai tín hiệu trước; trong cùng hạng theo
        // priority nhỏ nhất của hint góp vào; cuối cùng điểm thấp hơn trước.
        func minPriority(_ r: ROITargetRegion) -> Int {
            r.hintIndices.map { hints[$0].priority }.min() ?? Int.max
        }
        merged.sort {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            let p0 = minPriority($0), p1 = minPriority($1)
            if p0 != p1 { return p0 < p1 }
            return ($0.lowestQualityScore ?? 101) < ($1.lowestQualityScore ?? 101)
        }
        return Array(merged.prefix(maxRegions))
    }

    // MARK: - ReOCRService

    /// Đọc lại MỘT hint: chọn vùng đích của riêng hint đó (giao
    /// QualityMap như luật chung) rồi gọi recognizer đã tiêm.
    /// Không có recognizer => [] (fail-closed: session giữ nguyên
    /// trạng thái, vòng ROI kết thúc).
    func recognizeRegion(_ hint: ReconcileRegionHint, upscale: Double) -> [OCRLine] {
        guard let recognizer = recognizer else { return [] }
        let regions = RegionReReader.targetRegions(hints: [hint],
                                                   qualityMap: qualityMap,
                                                   maxRegions: 1)
        guard let region = regions.first else { return [] }
        return recognizer(region.band, upscale)
    }
}

import CoreGraphics
import CoreImage
import Foundation
import Vision

/// TÁI LẬP A0 / OCRFIX Ở TẦNG ĐIỀU PHỐI BENCH.
///
/// Nguồn tái lập: `ocrfix/ScanView.swift` (bản OCRFIX trong lịch sử
/// file) — cùng thứ tự: chuẩn hoá đã được BenchRunner làm bằng cách
/// nạp thẳng CGImage; ứng viên gốc luôn đọc; ứng viên phái sinh chỉ
/// thắng khi yieldScore cao hơn hẳn; lát 1600 chồng 200 khi cao
/// > 2000px; dedupeOverlap và mergeRows F2a giữ nguyên luật.
///
/// Khác biệt duy nhất là lớp bọc đo: ocrfix vứt hộp/candidates khi
/// trả [OCRLine], Bench giữ hộp union của hàng và candidates của
/// observation để xuất JSON chẩn đoán. Text, confidence của dòng
/// (MIN các mảnh), thứ tự dòng và phép chọn winner không đổi.
enum BenchLegacyOCR {
    private struct Frag {
        var text: String
        var confidence: Double
        var box: CGRect
        var candidates: [BenchCandidateData]
    }

    static func run(on cgImage: CGImage) -> BenchRunData {
        let totalStart = CFAbsoluteTimeGetCurrent()

        let originalStart = CFAbsoluteTimeGetCurrent()
        let originalLines = ocrLines(from: cgImage)
        let originalDuration = CFAbsoluteTimeGetCurrent() - originalStart
        let originalPass = BenchPassData(
            passID: "raw-a-original", role: "raw", engine: "vision-classic",
            variant: "original", durationMS: originalDuration * 1000,
            lines: originalLines,
            notes: "A0/OCRFIX — ứng viên gốc, luôn được đọc.")

        var passes = [originalPass]
        var winnerLines = originalLines
        var winnerVariant = "original"
        var notes = [
            "yieldScore(gốc) = \(yieldScore(originalLines.map(legacy)))"
        ]

        if let derived = derivedOCRImage(cgImage) {
            let derivedStart = CFAbsoluteTimeGetCurrent()
            let derivedLines = ocrLines(from: derived)
            let derivedDuration = CFAbsoluteTimeGetCurrent() - derivedStart
            passes.append(BenchPassData(
                passID: "raw-a-derived", role: "raw", engine: "vision-classic",
                variant: "derived", durationMS: derivedDuration * 1000,
                lines: derivedLines,
                notes: "A0/OCRFIX — ứng viên phái sinh cũ (tứ giác + perspective + tương phản 1.1); hộp nằm trong không gian ảnh phái sinh."))
            let derivedScore = yieldScore(derivedLines.map(legacy))
            notes.append("yieldScore(phái sinh) = \(derivedScore)")
            if derivedScore > yieldScore(originalLines.map(legacy)) {
                winnerLines = derivedLines
                winnerVariant = "derived"
                notes.append("A0 winner = derived (điểm cao hơn hẳn theo luật OCRFIX).")
            } else {
                notes.append("A0 winner = original (phái sinh không cao hơn hẳn; hoà cũng giữ gốc).")
            }
        } else {
            notes.append("A0: không tạo được ứng viên phái sinh — chỉ có gốc.")
        }

        let final = BenchPassData(
            passID: "final", role: "final", engine: "vision-classic",
            variant: winnerVariant,
            durationMS: (CFAbsoluteTimeGetCurrent() - totalStart) * 1000,
            lines: winnerLines,
            notes: "Bộ A0 được chọn đúng luật OCRFIX: phái sinh chỉ thắng khi yieldScore cao hơn gốc.")
        return BenchRunData(passes: passes, finalPass: final, notes: notes)
    }

    private static func legacy(_ line: BenchLineData) -> OCRLine {
        OCRLine(text: line.text, confidence: line.confidence)
    }

    private static func ocrLines(from cgImage: CGImage) -> [BenchLineData] {
        mergeRows(dedupeOverlap(collectFragments(cgImage: cgImage)))
    }

    /// Nguyên văn công thức OCRFIX (chỉ đổi kiểu đầu vào sang DTO).
    private static func yieldScore(_ lines: [OCRLine]) -> Int {
        var contentLines = 0
        var alnumChars = 0
        var hasSubtotal = false
        var hasTotal = false
        var hasPercent = false
        var hasDate = false
        for line in lines {
            let text = line.text
            let alnum = text.unicodeScalars.filter {
                CharacterSet.alphanumerics.contains($0)
            }.count
            if alnum > 0 {
                contentLines += 1
                alnumChars += alnum
            }
            let upper = text.uppercased()
            if upper.contains("SUBTOTAL") {
                hasSubtotal = true
            } else if upper.contains("TOTAL") {
                hasTotal = true
            }
            if text.contains("%") { hasPercent = true }
            if !hasDate,
               text.range(of: #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#,
                          options: .regularExpression) != nil {
                hasDate = true
            }
        }
        var score = contentLines * 10 + alnumChars / 10
        if hasSubtotal { score += 30 }
        if hasTotal { score += 40 }
        if hasPercent { score += 20 }
        if hasDate { score += 20 }
        return score
    }

    /// Nguyên văn thuật toán phái sinh của OCRFIX.
    private static func derivedOCRImage(_ cgImage: CGImage) -> CGImage? {
        let detect = VNDetectRectanglesRequest()
        detect.minimumConfidence = 0.5
        detect.maximumObservations = 1
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([detect])
        } catch {
            return nil
        }
        guard let quad = (detect.results ?? []).first else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        func ciPoint(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * w, y: p.y * h)
        }
        let source = CIImage(cgImage: cgImage)
        guard let perspective = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        perspective.setValue(source, forKey: kCIInputImageKey)
        perspective.setValue(ciPoint(quad.topLeft), forKey: "inputTopLeft")
        perspective.setValue(ciPoint(quad.topRight), forKey: "inputTopRight")
        perspective.setValue(ciPoint(quad.bottomLeft), forKey: "inputBottomLeft")
        perspective.setValue(ciPoint(quad.bottomRight), forKey: "inputBottomRight")
        guard let corrected = perspective.outputImage else { return nil }
        guard let enhance = CIFilter(name: "CIColorControls") else { return nil }
        enhance.setValue(corrected, forKey: kCIInputImageKey)
        enhance.setValue(NSNumber(value: 0.0), forKey: kCIInputSaturationKey)
        enhance.setValue(NSNumber(value: 1.1), forKey: kCIInputContrastKey)
        enhance.setValue(NSNumber(value: 0.0), forKey: kCIInputBrightnessKey)
        guard let output = enhance.outputImage else { return nil }
        let context = CIContext(options: nil)
        return context.createCGImage(output, from: output.extent)
    }

    /// Nguyên văn ngưỡng/lưới lát của OCRFIX.
    private static func collectFragments(cgImage: CGImage) -> [Frag] {
        let w = cgImage.width
        let h = cgImage.height
        guard h > 2000 else {
            return ocrFragments(tile: cgImage, tileTopPx: 0,
                                tileHeightPx: h, fullHeightPx: h)
        }
        var all: [Frag] = []
        let tileHeight = 1600
        let overlap = 200
        let step = tileHeight - overlap
        var top = 0
        while top < h {
            let th = min(tileHeight, h - top)
            if let tile = cgImage.cropping(to: CGRect(x: 0, y: top,
                                                       width: w, height: th)) {
                all += ocrFragments(tile: tile, tileTopPx: top,
                                    tileHeightPx: th, fullHeightPx: h)
            }
            if top + th >= h { break }
            top += step
        }
        return all
    }

    private static func ocrFragments(tile: CGImage, tileTopPx: Int,
                                     tileHeightPx: Int,
                                     fullHeightPx: Int) -> [Frag] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: tile, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let observations = (request.results ?? [])
        return observations.compactMap { obs in
            let candidates = obs.topCandidates(3)
            guard let candidate = candidates.first else { return nil }
            let b = obs.boundingBox
            let topFromFullTop = Double(tileTopPx)
                + (1.0 - Double(b.maxY)) * Double(tileHeightPx)
            let heightFull = Double(b.height) * Double(tileHeightPx)
                / Double(fullHeightPx)
            let maxYFull = 1.0 - topFromFullTop / Double(fullHeightPx)
            let box = CGRect(x: b.minX,
                             y: CGFloat(maxYFull - heightFull),
                             width: b.width,
                             height: CGFloat(heightFull))
            return Frag(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                box: box,
                candidates: candidates.map {
                    BenchCandidateData(text: $0.string,
                                       confidence: Double($0.confidence))
                })
        }
    }

    /// Nguyên văn luật khử trùng vùng chồng của OCRFIX/F2c.
    private static func dedupeOverlap(_ frags: [Frag]) -> [Frag] {
        var kept: [Frag] = []
        for f in frags.sorted(by: { $0.confidence > $1.confidence }) {
            let isDuplicate = kept.contains { k in
                guard k.text == f.text else { return false }
                let inter = k.box.intersection(f.box)
                guard !inter.isNull else { return false }
                let smaller = min(k.box.width * k.box.height,
                                  f.box.width * f.box.height)
                return smaller > 0
                    && (inter.width * inter.height) / smaller >= 0.5
            }
            if !isDuplicate { kept.append(f) }
        }
        return kept
    }

    /// Nguyên văn mergeRows F2a của OCRFIX; phần Bench cộng là hộp
    /// union của hàng (ocrfix không giữ hộp ở [OCRLine]) và candidates
    /// khi hàng chỉ gồm đúng một mảnh. Text/thứ tự/confidence giữ
    /// nguyên: nối bằng một khoảng trắng, confidence = MIN mảnh.
    private static func mergeRows(_ fragsIn: [Frag]) -> [BenchLineData] {
        var frags = fragsIn
        frags.sort { $0.box.maxY > $1.box.maxY }
        var rows: [[Frag]] = []
        for f in frags {
            if var row = rows.last, let anchor = row.first {
                let overlap = min(f.box.maxY, anchor.box.maxY)
                    - max(f.box.minY, anchor.box.minY)
                let shorter = min(f.box.height, anchor.box.height)
                if shorter > 0 && overlap / shorter >= 0.5 {
                    row.append(f)
                    rows[rows.count - 1] = row
                    continue
                }
            }
            rows.append([f])
        }
        return rows.map { row in
            let sorted = row.sorted { $0.box.minX < $1.box.minX }
            let text = sorted.map(\.text).joined(separator: " ")
            let box = sorted.dropFirst().reduce(sorted[0].box) {
                $0.union($1.box)
            }
            let candidates = sorted.count == 1
                ? sorted[0].candidates
                : [BenchCandidateData(text: text,
                                      confidence: sorted.map(\.confidence).min() ?? 0)]
            return BenchLineData(
                text: text,
                confidence: sorted.map(\.confidence).min() ?? 0,
                box: BenchBoxData(box),
                candidates: candidates)
        }
    }
}

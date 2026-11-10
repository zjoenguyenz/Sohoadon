import CoreImage
import Foundation
import UIKit
import Vision

/// Engine (b) — RecognizeDocumentsRequest (Vision, iOS 26).
/// API đã đối chiếu 2 nguồn độc lập ngày 2026-11-10 (ca trực):
/// tài liệu WWDC25 "Read documents using the Vision framework" và
/// bài viết kèm code chạy của Daniel Saidi (2026-01-10):
///   var request = RecognizeDocumentsRequest()
///   request.textRecognitionOptions.useLanguageCorrection = true
///   let observations = try await request.perform(on: cgImage)
///   observations.first?.document            -> DocumentObservation.Container
///   container.paragraphs.map { $0.transcript }
///   container.tables / container.lists      -> cấu trúc phụ
/// Mọi thành viên API ngoài danh sách trên đều KHÔNG được dùng ở đây
/// cho tới khi có bằng chứng biên dịch (build cloud) — tránh viết theo
/// trí nhớ (TEAM.md lỗi #4).
enum EngineB {
    struct Result {
        /// Dòng văn bản đưa vào cùng parser như ứng viên (a): mỗi đoạn
        /// (paragraph) tách theo ký tự xuống dòng trong transcript.
        var lines: [String]
        var paragraphCount: Int
        var tableCount: Int
        var listCount: Int
        var elapsedSeconds: Double
    }

    enum EngineBError: Error {
        case noCGImage
        case noDocument
    }

    /// Đọc 1 ảnh bằng engine (b). Ném lỗi ra ngoài để màn hình ghi lại
    /// nguyên văn — bản test không nuốt lỗi.
    static func recognize(_ image: UIImage) async throws -> Result {
        guard let cg = image.cgImage else { throw EngineBError.noCGImage }
        let start = Date()
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: cg)
        guard let container = observations.first?.document else {
            throw EngineBError.noDocument
        }
        let paragraphs = container.paragraphs.map { $0.transcript }
        let lines = paragraphs.flatMap {
            $0.components(separatedBy: "\n")
        }.filter { !$0.isEmpty }
        return Result(
            lines: lines,
            paragraphCount: paragraphs.count,
            tableCount: container.tables.count,
            listCount: container.lists.count,
            elapsedSeconds: Date().timeIntervalSince(start)
        )
    }

    /// Ảnh phái sinh cho cấu hình đo thứ 2 của MỌI ứng viên (WP4-SPEC §2:
    /// gốc / phái sinh). Thuật toán chép đúng wp4-prep bước 2 của ứng
    /// viên (a) — VNDetectRectanglesRequest (tin cậy >= 0.5) ->
    /// CIPerspectiveCorrection -> CIColorControls (bỏ màu, tương phản
    /// 1.1) — để hai ứng viên chấm trên CÙNG một ảnh phái sinh.
    /// Fail-open: không thấy tứ giác / lỗi -> nil, gọi bằng ảnh gốc.
    /// [CHƯA KIỂM CHỨNG trên máy — cùng trạng thái với wp4-prep.]
    static func derivedImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
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
        guard let out = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: out)
    }
}

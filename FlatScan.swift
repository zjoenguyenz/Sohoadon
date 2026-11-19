import Foundation
import CoreGraphics
import CoreImage
import Vision
import UIKit

// ============================================================
// S2 (gói camera tự dựng, SCAN-CARD-AUDIT mục 2.5 — anh duyệt
// 2026-11-18): BẢN SCAN PHẲNG LƯU TRỮ. Khối phối cảnh vốn chỉ
// sống tạm trong tầng đọc (ReadPipeline.perspectiveCandidate:
// phát hiện tứ giác -> QuadGate luật đầy đủ ->
// CIPerspectiveCorrection) được nâng thành SẢN PHẨM CHÍNH ở
// tầng nạp:
//   - sau chụp, ảnh phẳng toàn phân giải được dựng từ 4 góc
//     phát hiện được và LƯU KÈM hoá đơn làm bản scan hiển thị;
//   - đường đọc dùng ảnh phẳng làm đầu vào chính khi có; không
//     có góc tin cậy (detector trượt hoặc QuadGate từ chối)
//     thì lùi về ảnh gốc như hiện tại — fail-closed, không ép;
//   - ảnh GỐC thô giữ nguyên làm bằng chứng: file phẳng là file
//     RIÊNG, không ghi đè, không thay thế.
//
// QUY ƯỚC TÊN FILE (không đổi model SwiftData): file phẳng của
// một ảnh gốc "X.jpg" là "X-flat.jpg" trong CÙNG thư mục
// ReceiptImages. Mọi điểm cần (hiển thị Kiểm Lại / Chi Tiết,
// dọn dẹp khi xoá tờ / huỷ nháp) suy tên từ tên file gốc — tờ
// nạp PDF không có bản phẳng (tên không phải .jpg -> nil).
//
// File này CHỈ ở target app (như MirrorSync): bench/harness
// không liên kết — tầng đọc không đổi một chữ, điểm nối duy
// nhất là ẢNH ĐẦU VÀO mà ScanView truyền cho ReadRequest.
// ============================================================

enum FlatScan {

    /// Hậu tố quy ước của file bản scan phẳng.
    static let fileSuffix = "-flat"

    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    // MARK: - Quy ước tên file

    /// Tên file phẳng suy từ tên file gốc; nil khi tên không
    /// phải ảnh JPEG (PDF/tệp khác không có bản phẳng).
    static func flatFileName(forOriginal name: String) -> String? {
        guard name.lowercased().hasSuffix(".jpg") else { return nil }
        return String(name.dropLast(4)) + fileSuffix + ".jpg"
    }

    /// Tên file phẳng KHI FILE THẬT SỰ TỒN TẠI trên đĩa (điểm
    /// hiển thị dùng — không hiện mục scan phẳng cho tờ chưa có).
    static func existingFlatFileName(forOriginal name: String) -> String? {
        guard let flat = flatFileName(forOriginal: name) else { return nil }
        let url = ImageStore.directory.appendingPathComponent(flat)
        return FileManager.default.fileExists(atPath: url.path) ? flat : nil
    }

    /// Ảnh phẳng đã lưu của một file gốc (nil khi chưa có).
    static func loadFlatImage(forOriginal name: String) -> UIImage? {
        guard let flat = existingFlatFileName(forOriginal: name)
        else { return nil }
        return ImageStore.load(fileName: flat)
    }

    /// Ảnh để HIỂN THỊ ở Kiểm Lại: bản phẳng khi có (đó là bản
    /// scan như máy scan), không thì ảnh gốc như trước.
    static func displayImage(forOriginal name: String) -> UIImage? {
        loadFlatImage(forOriginal: name) ?? ImageStore.load(fileName: name)
    }

    /// Xoá file phẳng đi kèm một file gốc (dọn dẹp khi xoá tờ /
    /// huỷ bản nháp / đọc rỗng — cùng kỷ luật dọn file gốc).
    static func deleteFlat(forOriginal name: String) {
        guard let flat = flatFileName(forOriginal: name) else { return }
        ImageStore.delete(fileName: flat)
    }

    // MARK: - Dựng ảnh phẳng

    /// Phát hiện tứ giác tài liệu trên ảnh toàn phân giải:
    /// VNDetectDocumentSegmentationRequest TRƯỚC (detector
    /// chuyên tài liệu — thắng detector hình chữ nhật trên nền
    /// bừa), trượt mới tới VNDetectRectanglesRequest NỚI cho
    /// hoá đơn (aspect 0.15, tolerance 30°, confidence 0.7,
    /// size 0.2 — bộ số của SCAN-CARD-AUDIT mục 2.4). Trả
    /// quan sát Vision (toạ độ chuẩn hoá gốc-dưới) hoặc nil.
    /// Dùng chung cho S2 (ảnh tĩnh) và S1 (khung hình camera —
    /// camera tự hạ mẫu trước khi gọi).
    static func detectDocumentQuad(in image: CGImage)
        -> VNRectangleObservation? {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let segmentation = VNDetectDocumentSegmentationRequest()
        if (try? handler.perform([segmentation])) != nil,
           let obs = segmentation.results?.first {
            return obs
        }
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 1
        rectangles.minimumConfidence = 0.7
        rectangles.minimumAspectRatio = 0.15
        rectangles.quadratureTolerance = 30
        rectangles.minimumSize = 0.2
        if (try? handler.perform([rectangles])) != nil {
            return rectangles.results?.first
        }
        return nil
    }

    /// Dựng ảnh phẳng toàn phân giải từ ảnh gốc: phát hiện tứ
    /// giác -> QuadGate LUẬT ĐẦY ĐỦ (đúng cổng của ứng viên
    /// phối cảnh trong tầng đọc) -> CIPerspectiveCorrection
    /// (nới lề 1,5% như bước phối cảnh hiện hành). nil ở MỌI
    /// điểm cổng chặn — nơi gọi lùi về ảnh gốc, không ép.
    /// Toán đổi hệ + nới lề chép theo ReadPipeline
    /// .perspectiveCandidate (L-2026-11-12-12: phải nhân điểm
    /// chuẩn hoá với kích thước pixel TRƯỚC khi qua QuadGate).
    static func makeFlatImage(from image: CGImage) -> CGImage? {
        guard let obs = detectDocumentQuad(in: image) else { return nil }
        let quad = [obs.topLeft, obs.topRight,
                    obs.bottomRight, obs.bottomLeft]
        let pixelQuad = quad.map {
            CGPoint(x: Double($0.x) * Double(image.width),
                    y: Double($0.y) * Double(image.height))
        }
        switch QuadGate.evaluate(quad: pixelQuad,
                                 imageWidth: image.width,
                                 imageHeight: image.height) {
        case .rejected(_):
            // B1 (kiểm duyệt vòng 3): QuadVerdict.rejected mang
            // associated value String — mẫu trần `case .rejected:`
            // KHÔNG qua biên dịch (tiền lệ đúng: ReadPipeline
            // .perspectiveCandidate dùng `case .rejected(let:)`).
            return nil
        case .allowed:
            break
        }
        // Nới lề 1,5%: kéo mỗi đỉnh ra xa tâm tứ giác (không
        // gian chuẩn hoá, như bước phối cảnh của tầng đọc).
        let cx = quad.reduce(0.0) { $0 + Double($1.x) } / 4
        let cy = quad.reduce(0.0) { $0 + Double($1.y) } / 4
        func px(_ p: CGPoint) -> CGPoint {
            let x = Double(p.x) + (Double(p.x) - cx) * 0.015
            let y = Double(p.y) + (Double(p.y) - cy) * 0.015
            return CGPoint(x: x * Double(image.width),
                           y: y * Double(image.height))
        }
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection")
        else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: px(quad[0])),
                        forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: px(quad[1])),
                        forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: px(quad[2])),
                        forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: px(quad[3])),
                        forKey: "inputBottomLeft")
        guard let out = filter.outputImage,
              let cg = ciContext.createCGImage(out, from: out.extent)
        else { return nil }
        return cg
    }

    /// Lưu ảnh phẳng cạnh file gốc theo quy ước tên. Trả tên
    /// file phẳng đã lưu, nil khi không suy được tên hoặc ghi
    /// lỗi — nơi gọi coi như tờ này không có bản phẳng (đọc
    /// bằng ảnh gốc), không chặn luồng chụp.
    @discardableResult
    static func saveFlatImage(_ flat: CGImage,
                              forOriginal name: String) -> String? {
        guard let flatName = flatFileName(forOriginal: name),
              let data = UIImage(cgImage: flat)
                .jpegData(compressionQuality: 0.9) else { return nil }
        let url = ImageStore.directory.appendingPathComponent(flatName)
        do {
            // Ghi NGUYÊN TỬ như mọi đường ghi file của dự án
            // (kiểm duyệt vòng 1 NHỎ-3 + vòng 3 N2): app bị giết
            // giữa lúc ghi không để lại file -flat.jpg cụt.
            try data.write(to: url, options: .atomic)
            return flatName
        } catch {
            return nil
        }
    }

    // MARK: - Cảnh báo ống kính bẩn (iOS 26+ — chỉ cảnh báo)

    /// DetectLensSmudgeRequest (Vision, iOS 26 — cần A14+;
    /// máy đích thừa chuẩn): trả độ tin cậy "ảnh chụp qua ống
    /// kính bẩn/mờ" 0..1, nil khi OS cũ hơn hoặc request lỗi.
    /// Ngưỡng cảnh báo theo WWDC25 là 0.9. CHỈ dùng để nhắc
    /// nhẹ sau chụp (SCAN-CARD-AUDIT mục 2.5 S1) — không bao
    /// giờ chặn hay loại ảnh: mờ do chuyển động/sương cũng có
    /// thể kích hoạt oan, anh là người quyết giữ hay chụp lại.
    static func lensSmudgeConfidence(for image: CGImage) async -> Float? {
        guard #available(iOS 26, *) else { return nil }
        let request = DetectLensSmudgeRequest()
        guard let observation = try? await request.perform(on: image)
        else { return nil }
        return Float(observation.confidence)
    }
}

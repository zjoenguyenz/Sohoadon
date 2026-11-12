import Foundation
import CoreGraphics
import Vision

// F2 — ADAPTER ENGINE (OCREngine), CORE-V3 Pha 2.
// Đặc tả: DESIGN-FINAL §3.2 + phép đo cô lập §4 (việc Pha 3).
// Pha 2 xây GIAO THỨC + GHIM cấu hình họ cổ điển + KHUNG adapter
// họ tài liệu. CẤM kết luận thắng/thua engine ở pha này: dữ liệu
// A3 là hợp nhất (đã đo là có hại), họ tài liệu chưa từng được
// đo cô lập — phép đo §4 (E-A..E-E) chạy ở Pha 3 trên BenchShell.
// Gương Python: engine_mirror.py (ngôn ngữ hiệu lực, chính sách
// correction, topCandidates, manifest + băm).
//
// Luật cứng của adapter cổ điển (§3.2(b)):
//  - revision GHIM Rev3, mức .accurate.
//  - topCandidates(3) giữ XUYÊN ỐNG: mảnh mang ứng viên chính +
//    tối đa 2 biến thể với điểm tin cậy — F5 (kênh CANDIDATE,
//    Pha 3) đọc đúng các biến thể này; adapter không được vứt.
//  - Ngôn ngữ hiệu lực = ưu tiên [vi-VN, en-US] ∩ danh sách
//    runtime supportedRecognitionLanguages, ghi vào manifest
//    (máy không có vi -> [en-US] + ghi chú; không bịa).
//  - languageCorrection: OFF vô điều kiện cho trường số/mã ở
//    mọi tay; trường chữ OFF ở đường chính — ON chỉ là tay đo
//    E-B. Adapter đường chính luôn dựng usesLanguageCorrection
//    = false và manifest ghi đúng vậy.

enum FieldClass {
    case numericOrCode
    case text
}

enum MeasurementArm {
    case main
    case eB     // tay đo: correction ON cho trường chữ (§4)
}

enum CorrectionPolicy {
    static func allowed(for fieldClass: FieldClass,
                        arm: MeasurementArm) -> Bool {
        switch fieldClass {
        case .numericOrCode:
            return false
        case .text:
            return arm == .eB
        }
    }
}

enum LanguagePolicy {
    static let priority = ["vi-VN", "en-US"]

    /// (hiệu lực, ghi chú) — gương: effective_languages.
    static func effective(supported: [String])
        -> (languages: [String], note: String?) {
        var eff = priority.filter { supported.contains($0) }
        var note: String? = nil
        if !eff.contains("vi-VN") {
            note = "vi-VN không có trong supportedRecognitionLanguages "
                + "của máy này — chạy [en-US], ghi manifest đúng vậy"
        }
        if eff.isEmpty {
            eff = ["en-US"]
            note = "runtime không báo ngôn ngữ ưu tiên nào — dự phòng "
                + "en-US, cờ trong manifest"
        }
        return (eff, note)
    }
}

/// Adapter engine: một họ engine sau MỘT giao thức. Mọi lượt
/// đọc đều khai manifest; mảnh ra theo đúng kiểu Fragment của
/// F3 (hộp chuẩn hoá gốc-dưới của Vision — không lật trục).
protocol OCREngine {
    var manifest: EngineManifest { get }
    /// Đọc một ảnh (hoặc một vùng khi region != nil — đường ROI
    /// của Pha 3 dùng cùng giao thức này).
    func recognize(in image: CGImage, region: CGRect?) throws
        -> [Fragment]
}

enum OCREngineError: Error {
    case noObservations
    case unsupportedRevision
    /// Họ documents (Swift-native): adapter là KHUNG đo — điểm
    /// chuyển đổi observation -> Fragment chưa nối (chờ phép đo
    /// cô lập §4.5 trên thiết bị). Mọi lời gọi đọc đều ném lỗi
    /// này (fail-closed) thay vì trả rỗng lặng lẽ. CI-FIX-2,
    /// 2026-11-12: bản khung cũ bắc cầu qua VNImageRequestHandler
    /// .perform([VNRequest]) — không hợp lệ với request
    /// Swift-native (kiểu async perform(on:), T2 §2) và là lỗi
    /// biên dịch duy nhất của run #40.
    case documentsAdapterNotWired
}

// MARK: - Họ cổ điển (GHIM Rev3)

final class ClassicTextEngine: OCREngine {
    static let topCandidates = 3        // luật cứng — không đổi
    let manifest: EngineManifest
    let languageNote: String?
    let minimumTextHeight: Float
    private let languages: [String]

    init(minimumTextHeight: Float = 0) {
        // SDK hiện hành: lời gọi này THROW (bằng chứng: bản
        // BenchRunner đã biên dịch xanh ở run #33 dùng try?).
        // init không throw -> try? + dự phòng [] để
        // LanguagePolicy.effective đi đúng nhánh rỗng đã thiết
        // kế ([en-US] + ghi chú trung thực trong manifest).
        let supported = (try? VNRecognizeTextRequest
            .supportedRecognitionLanguages(
                for: .accurate,
                revision: VNRecognizeTextRequestRevision3)) ?? []
        let eff = LanguagePolicy.effective(supported: supported)
        self.languages = eff.languages
        self.languageNote = eff.note
        self.minimumTextHeight = minimumTextHeight
        self.manifest = EngineManifest(
            family: "classic", revision: "rev3", level: "accurate",
            languagesEffective: eff.languages,
            usesLanguageCorrection: false,
            minimumTextHeight: Double(minimumTextHeight))
    }

    func recognize(in image: CGImage, region: CGRect?) throws
        -> [Fragment] {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = false
        request.minimumTextHeight = minimumTextHeight
        if let region {
            // Vision regionOfInterest: chuẩn hoá gốc-dưới — cùng
            // không gian với hộp mảnh, không lật.
            request.regionOfInterest = region
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observations = request.results else {
            throw OCREngineError.noObservations
        }
        var out: [Fragment] = []
        var nextID = 1
        for obs in observations {
            let cands = obs.topCandidates(Self.topCandidates)
            guard let top = cands.first else { continue }
            out.append(Fragment(
                id: nextID,
                text: top.string,
                alternates: cands.dropFirst().map {
                    AltText(text: $0.string,
                            confidence: Double($0.confidence))
                },
                confidence: Double(top.confidence),
                box: obs.boundingBox,
                passID: "classic-rev3",
                tileIndex: nil,
                regionID: nil))
            nextID += 1
        }
        return out
    }
}

// MARK: - Họ tài liệu (KHUNG — chưa đo, không kết luận)

/// Adapter RecognizeDocumentsRequest (iOS 26). Pha 2 chỉ dựng
/// KHUNG: manifest đúng họ, đường gọi + điểm chuyển đổi mảnh.
/// Việc chuyển đổi cấu trúc (bảng/đoạn/dòng) và MỌI kết luận về
/// họ này thuộc phép đo cô lập Pha 3 (§4 tay E-C/E-D) — cấm suy
/// từ dữ liệu hợp nhất A3. detectedData của engine được ghi
/// riêng (kênh phụ cho F4 đối chiếu), KHÔNG đi vào parse.
@available(iOS 26.0, *)
final class DocumentsEngine: OCREngine {
    let manifest: EngineManifest
    let languageNote: String?
    /// Kênh phụ: dữ liệu có cấu trúc engine tự nhận (ngày/tiền
    /// theo detectedData) — chỉ để đối chiếu ở Pha 3.
    private(set) var lastDetectedData: [String] = []

    init() {
        // Họ tài liệu tự chọn ngôn ngữ theo tài liệu; manifest
        // ghi nhận trung thực: hiệu lực = ưu tiên ∩ runtime của
        // họ cổ điển chỉ là THAM CHIẾU — Pha 3 chốt cách khai.
        // (try?: như ClassicTextEngine ở trên — lời gọi throw.)
        let supported = (try? VNRecognizeTextRequest
            .supportedRecognitionLanguages(
                for: .accurate,
                revision: VNRecognizeTextRequestRevision3)) ?? []
        let eff = LanguagePolicy.effective(supported: supported)
        self.languageNote = eff.note
        self.manifest = EngineManifest(
            family: "documents", revision: "doc-v1",
            level: "accurate", languagesEffective: eff.languages,
            usesLanguageCorrection: false, minimumTextHeight: 0)
    }

    func recognize(in image: CGImage, region: CGRect?) throws
        -> [Fragment] {
        // KHUNG PHA 2: dựng request + thực thi; chuyển đổi
        // observation -> Fragment là điểm nối của Pha 3 (cần đo
        // cấu trúc thật trên thiết bị trước khi chốt cách bóc
        // dòng/đoạn — không đoán mò cấu trúc ở đây).
        // KHUNG: request Swift-native thực thi bằng async
        // perform(on:) (T2 §2) — KHÔNG đi qua VNImageRequestHandler
        // (cầu bắc đó không hợp lệ theo kiểu, CI run #40). Việc
        // bóc DocumentObservation thành Fragment chờ phép đo cô
        // lập E-C/E-D (§4.5) trên thiết bị; cho tới lúc đó adapter
        // fail-closed bằng lỗi tường minh, không trả rỗng.
        lastDetectedData = []
        throw OCREngineError.documentsAdapterNotWired
    }
}

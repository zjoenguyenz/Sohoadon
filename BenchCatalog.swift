import Foundation

struct BenchConfigDefinition: Identifiable {
    var id: String
    var name: String
    var engine: String
    var variant: String
    var baseline: Bool?
    var summary: String

    var json: BenchJSONConfig {
        BenchJSONConfig(id: id, name: name, engine: engine,
                        variant: variant, baseline: baseline)
    }
}

struct BenchImageDefinition: Identifiable {
    var id: String
    var form: String
    var difficulty: String
    var origin: String
    var gtID: String
    var sourceFile: String?
    var resourceName: String?
    var resourceExtension: String = "jpg"
    var pages: Int?
    var statusNote: String

    var isAvailable: Bool { resourceName != nil }

    func json(widthPX: Int, heightPX: Int) -> BenchJSONImage {
        BenchJSONImage(id: id, form: form, difficulty: difficulty,
                       origin: origin, gtID: gtID, sourceFile: sourceFile,
                       pages: pages, widthPX: widthPX, heightPX: heightPX)
    }
}

enum BenchCatalog {
    static let appBuild = "benchapp-1"

    static let configs: [BenchConfigDefinition] = [
        BenchConfigDefinition(
            id: "A0", name: "A0 — OCRFIX đối chứng",
            engine: "vision-classic", variant: "ocrfix",
            baseline: true,
            summary: "Tái lập OCRFIX ở tầng điều phối: gốc + phái sinh cũ, chọn bằng yieldScore."),
        BenchConfigDefinition(
            id: "A1", name: "A1 — (a) đa pass + hợp nhất",
            engine: "merged-core", variant: "classic-multipass-merge",
            baseline: nil,
            summary: "Các pass cổ điển của p2-fix, hợp nhất hình học; không (b), không reconcile/ROI."),
        BenchConfigDefinition(
            id: "A2", name: "A2 — A1 + pass (b)",
            engine: "merged-core", variant: "classic-plus-document-merge",
            baseline: nil,
            summary: "Pass cổ điển + RecognizeDocumentsRequest của p2-fix, hợp nhất chung; không reconcile/ROI."),
        BenchConfigDefinition(
            id: "A3", name: "A3 — đường đầy đủ p2-fix",
            engine: "merged-core", variant: "full-v2",
            baseline: nil,
            summary: "Đa pass + (b) + chọn bằng reconcile + tối đa 2 vòng đọc lại theo vùng."),
    ]

    /// Toàn bộ danh mục theo BENCH-MANIFEST. Bốn ca đầu có file thật
    /// trong BenchImages/; mọi ca còn lại chỉ hiện THIẾU, không có
    /// resourceName và không bao giờ được đưa vào runs của JSON.
    static let images: [BenchImageDefinition] = [
        BenchImageDefinition(
            id: "N-001", form: "N", difficulty: "L0", origin: "real",
            gtID: "GT-SAMS-F",
            sourceFile: "sample-001-sams-club-app-screenshot.jpg",
            resourceName: "N-001", pages: nil,
            statusNote: "Sẵn sàng — ảnh app Sam's Club."),
        BenchImageDefinition(
            id: "N-002", form: "N", difficulty: "L4", origin: "real",
            gtID: "GT-SAMS-F",
            sourceFile: "sample-002-sams-downloaded-receipt.jpg",
            resourceName: "N-002", pages: nil,
            statusNote: "Sẵn sàng — file tải về, phân giải thấp."),
        BenchImageDefinition(
            id: "C-003", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-HD-003",
            sourceFile: "sample-003-homedepot-paper-crop.jpg",
            resourceName: "C-003", pages: nil,
            statusNote: "Sẵn sàng — bản crop trong repo; manifest ưu tiên ảnh gốc ở buổi chuẩn bị."),
        BenchImageDefinition(
            id: "S-0", form: "S", difficulty: "L0", origin: "real",
            gtID: "GT-SAMS-F",
            sourceFile: "sample-004-sams-paper-scan.jpg",
            resourceName: "S-0", pages: 1,
            statusNote: "Sẵn sàng — CA CỔNG DANH DỰ, bản giấy Sam's qua máy scan."),
        BenchImageDefinition(
            id: "S-1", form: "S", difficulty: "L1", origin: "real",
            gtID: "GT-HD-003", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — cần quét tờ Home Depot ở buổi chuẩn bị."),
        BenchImageDefinition(
            id: "S-2", form: "S", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — cần quét một tờ nhăn thật và đóng băng đáp án mới."),
        BenchImageDefinition(
            id: "C-002C", form: "C", difficulty: "L0", origin: "real",
            gtID: "GT-SAMS-F", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — cần chụp thường chính tờ Sam's giấy."),
        BenchImageDefinition(
            id: "L1-01", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — ca nhăn/cũ thật 1/3 từ kho của anh."),
        BenchImageDefinition(
            id: "L1-02", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — ca nhăn/cũ thật 2/3 từ kho của anh."),
        BenchImageDefinition(
            id: "L1-03", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — ca nhăn/cũ thật 3/3 từ kho của anh."),
        BenchImageDefinition(
            id: "L2-01", form: "C", difficulty: "L2", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — tờ nhiệt phai thật 1/2."),
        BenchImageDefinition(
            id: "L2-02", form: "C", difficulty: "L2", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — tờ nhiệt phai thật 2/2."),
        BenchImageDefinition(
            id: "L3-01", form: "C", difficulty: "L3", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — chụp lại L1-01 dưới sáng lệch, dùng chung đáp án khi đã đóng băng."),
        BenchImageDefinition(
            id: "L3-02", form: "C", difficulty: "L3", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — chụp lại L1-02 dưới sáng lệch, dùng chung đáp án khi đã đóng băng."),
        BenchImageDefinition(
            id: "L4-02", form: "N", difficulty: "L4", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — file tải về thật khác khi anh có."),
        BenchImageDefinition(
            id: "L5-01", form: "C", difficulty: "L5", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — tờ nhiều món nhất trong kho thật; cấm ghép giả."),
        BenchImageDefinition(
            id: "PDF-SAM", form: "N", difficulty: "L0", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — PDF Sam's thật; BenchApp bản này chỉ đo ảnh."),
        BenchImageDefinition(
            id: "D-SYN-18", form: "N", difficulty: "L1", origin: "synthetic",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — 18 ảnh suy biến kỹ thuật số chưa tạo theo manifest."),
    ]

    static var availableImages: [BenchImageDefinition] {
        images.filter(\.isAvailable)
    }
}

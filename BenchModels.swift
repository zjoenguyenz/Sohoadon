import CoreGraphics
import Foundation

// MARK: - Dữ liệu trung gian của một lượt chạy đo
//
// Các kiểu này là DTO ở tầng điều phối Bench. Chúng không phải một
// pipeline mới: BenchLegacyOCR sinh chúng từ bản tái lập OCRFIX, còn
// bridge BENCH trong ScanView.swift sinh chúng từ đúng các pass của
// p2-fix. BenchRunner chỉ việc gói DTO vào JSON schema v1.

struct BenchCandidateData {
    var text: String
    var confidence: Double
}

struct BenchBoxData {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        w = Double(rect.size.width)
        h = Double(rect.size.height)
    }
}

struct BenchLineData {
    var text: String
    var confidence: Double
    var box: BenchBoxData?
    var candidates: [BenchCandidateData]
}

struct BenchTableCellData {
    var text: String
    var box: BenchBoxData?
}

struct BenchTableData {
    var box: BenchBoxData?
    var rows: [[BenchTableCellData]]
}

struct BenchDetectedData {
    var kind: String
    var text: String
    var value: String?
}

struct BenchPassData {
    var passID: String
    var role: String // final | raw | roi
    var engine: String // vision-classic | recognize-documents | merged-core
    var variant: String
    var durationMS: Double
    var lines: [BenchLineData]
    var tables: [BenchTableData] = []
    var detectedData: [BenchDetectedData] = []
    var tablesNote: String? = nil
    var notes: String? = nil
}

struct BenchRunData {
    var passes: [BenchPassData]
    var finalPass: BenchPassData
    var notes: [String] = []

    var allPassesInJSONOrder: [BenchPassData] {
        // JSON không quy định thứ tự pass; để final cuối cùng giúp người
        // đọc file bằng mắt thấy raw/roi trước, final sau. Bộ chấm chỉ
        // tìm đúng một pass role=final.
        passes + [finalPass]
    }
}

struct BenchDocumentRunData {
    var pass: BenchPassData?
    var note: String?
    var structureNote: String?
}

// MARK: - JSON schema v1 (bench-prep/BENCH-JSON-SPEC.md)

struct BenchJSONDocument: Encodable {
    var schema: String = "sohoadon-bench"
    var schemaVersion: Int = 1
    var generatedAt: String
    var app: BenchJSONApp
    var device: BenchJSONDevice
    var supportedLanguages: BenchJSONSupportedLanguages
    var configs: [BenchJSONConfig]
    var images: [BenchJSONImage]
    var runs: [BenchJSONRun]

    enum CodingKeys: String, CodingKey {
        case schema
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case app
        case device
        case supportedLanguages = "supported_languages"
        case configs
        case images
        case runs
    }
}

struct BenchJSONApp: Encodable {
    var name: String = "BenchApp"
    var build: String
    var parserVersion: String

    enum CodingKeys: String, CodingKey {
        case name
        case build
        case parserVersion = "parser_version"
    }
}

struct BenchJSONDevice: Encodable {
    var model: String
    var ios: String
}

struct BenchJSONSupportedLanguages: Encodable {
    var visionClassic: [String]
    var recognizeDocuments: [String]

    enum CodingKeys: String, CodingKey {
        case visionClassic = "vision_classic"
        case recognizeDocuments = "recognize_documents"
    }
}

struct BenchJSONConfig: Encodable {
    var id: String
    var name: String
    var engine: String
    var variant: String
    var baseline: Bool?
}

struct BenchJSONImage: Encodable {
    var id: String
    var form: String
    var difficulty: String
    var origin: String
    var gtID: String
    var sourceFile: String?
    var pages: Int?
    var widthPX: Int
    var heightPX: Int

    enum CodingKeys: String, CodingKey {
        case id
        case form
        case difficulty
        case origin
        case gtID = "gt_id"
        case sourceFile = "source_file"
        case pages
        case widthPX = "width_px"
        case heightPX = "height_px"
    }
}

struct BenchJSONRun: Encodable {
    var imageID: String
    var configID: String
    var passes: [BenchJSONPass]

    enum CodingKeys: String, CodingKey {
        case imageID = "image_id"
        case configID = "config_id"
        case passes
    }
}

struct BenchJSONPass: Encodable {
    var passID: String
    var role: String
    var engine: String
    var variant: String
    var durationMS: Double
    var lines: [BenchJSONLine]
    var tables: [BenchJSONTable]
    var detectedData: [BenchJSONDetectedData]
    var tablesNote: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case passID = "pass_id"
        case role
        case engine
        case variant
        case durationMS = "duration_ms"
        case lines
        case tables
        case detectedData = "detected_data"
        case tablesNote = "tables_note"
        case notes
    }

    init(_ pass: BenchPassData) {
        passID = pass.passID
        role = pass.role
        engine = pass.engine
        variant = pass.variant
        durationMS = pass.durationMS
        lines = pass.lines.map(BenchJSONLine.init)
        tables = pass.tables.map(BenchJSONTable.init)
        detectedData = pass.detectedData.map(BenchJSONDetectedData.init)
        tablesNote = pass.tablesNote
        notes = pass.notes
    }
}

struct BenchJSONLine: Encodable {
    var text: String
    var confidence: Double
    var box: BenchJSONBox?
    var candidates: [BenchJSONCandidate]

    init(_ line: BenchLineData) {
        text = line.text
        confidence = line.confidence
        box = line.box.map(BenchJSONBox.init)
        candidates = line.candidates.map(BenchJSONCandidate.init)
    }
}

struct BenchJSONBox: Encodable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ box: BenchBoxData) {
        x = box.x
        y = box.y
        w = box.w
        h = box.h
    }
}

struct BenchJSONCandidate: Encodable {
    var text: String
    var confidence: Double

    init(_ candidate: BenchCandidateData) {
        text = candidate.text
        confidence = candidate.confidence
    }
}

struct BenchJSONTable: Encodable {
    var box: BenchJSONBox?
    var rows: [[BenchJSONTableCell]]

    init(_ table: BenchTableData) {
        box = table.box.map(BenchJSONBox.init)
        rows = table.rows.map { $0.map(BenchJSONTableCell.init) }
    }
}

struct BenchJSONTableCell: Encodable {
    var text: String
    var box: BenchJSONBox?

    init(_ cell: BenchTableCellData) {
        text = cell.text
        box = cell.box.map(BenchJSONBox.init)
    }
}

struct BenchJSONDetectedData: Encodable {
    var kind: String
    var text: String
    var value: String?

    init(_ item: BenchDetectedData) {
        kind = item.kind
        text = item.text
        value = item.value
    }
}

import Foundation

// MARK: - M2 · ReadDiagnostics — bản ghi chẩn đoán schema v2 (CORE-V3, Pha 0)
//
// Đặc tả: DESIGN-DETAIL §1.5 (giữ nguyên văn ở DESIGN-FINAL §2),
// cộng hai trường thuần thêm của bản chốt: `qualityMap`
// (DESIGN-FINAL §3.1(c)) và `corrections[]` (DomainCorrection,
// DESIGN-FINAL §3.4(b)) cùng provenance `.domainCorrected`
// (DESIGN-FINAL §2/§3.7).
//
// Kế thừa OCRDiagnostics schema v1 của p2-1 và NÂNG LÊN v2 — điểm
// thiếu quyết định của v1 là nó chỉ lưu SỐ ĐẾM của các pass chứ
// không lưu MẢNH, nên không tái hiện offline được (đó là lý do sự
// cố L-R08 2026-11-11 không chốt được cơ chế lệch dòng). v2 bắt
// buộc lưu TOÀN BỘ mảnh trước ráp + dòng sau ráp + snapshot parse/
// reconcile + các vòng ROI — đầu vào chính thức của ReplayHarness.
// Cấu trúc lồng (identity/input/config/assembly/outcome) chép
// đúng cây giản đồ của §1.5.
//
// LUẬT CỨNG của module (nguyên tắc T3 1.7 thành luật):
//   KHÔNG CÓ BẢN GHI = LẦN ĐỌC KHÔNG TỒN TẠI VỀ MẶT KIỂM CHỨNG.
// ReadPipeline (Pha 2+) không trả outcome "sạch" nếu ghi chẩn
// đoán thất bại — xem ReadFinalizer ở cuối file: nó trả outcome
// kèm `diagnosticsWriteFailed = true` và tờ bị ép cờ (hợp đồng
// §1.5). File này chỉ cung cấp API + kho lưu; việc ép cờ thuộc
// ReadPipeline/ReceiptViews ở pha tích hợp.
//
// Định dạng: file phụ `<imageFileName>.ocrdiag.json` cạnh ảnh gốc
// trong thư mục bằng chứng — KHÔNG qua SwiftData (§1.4: không đổi
// model). Mọi kiểu đều Codable tường minh; hộp dùng DiagRect
// (CGRect không Codable). Lệch có chủ đích so với p2-1: spans của
// dòng lưu theo KHOẢNG KÝ TỰ (start/end Int) thay cho
// Range<String.Index> (không Codable được); createdAt lưu dạng
// chuỗi ISO8601 để file tự mô tả, không phụ thuộc chiến lược
// giải mã của bên đọc.

// MARK: Kiểu nền

/// Hộp chuẩn hoá gốc dưới-trái, không gian ảnh gốc (kế thừa
/// OCRDiagRect của p2-1).
struct DiagRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    init(_ rect: CGRect) {
        x = Double(rect.origin.x); y = Double(rect.origin.y)
        width = Double(rect.size.width); height = Double(rect.size.height)
    }

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

/// Ứng viên chữ phụ của một mảnh (Vision topCandidates 2–3).
struct AltText: Codable, Equatable {
    var text: String
    var confidence: Double
}

/// Nguồn gốc một trường trong kết quả đọc (§3.7 + bản chốt §2).
/// kind: "read" | "inferred" | "roiRecovered" | "anchored" |
///       "domainCorrected". detail: kênh trọng tài / số vòng ROI /
///       phiên bản lexicon — tuỳ kind.
struct FieldProvenance: Codable, Equatable {
    var kind: String
    var detail: String? = nil

    static let read = FieldProvenance(kind: "read")
    static func inferred(channel: String) -> FieldProvenance {
        FieldProvenance(kind: "inferred", detail: channel)
    }
    static func roiRecovered(round: Int) -> FieldProvenance {
        FieldProvenance(kind: "roiRecovered", detail: String(round))
    }
    static let anchored = FieldProvenance(kind: "anchored")
    static func domainCorrected(lexiconVersion: String) -> FieldProvenance {
        FieldProvenance(kind: "domainCorrected", detail: lexiconVersion)
    }
}

// MARK: Các ngăn của bản ghi (§1.5)

/// identity — danh tính lần đọc + tem bộ đọc.
struct DiagIdentity: Codable, Equatable {
    var diagnosticsID: String       // UUID dạng chuỗi
    var createdAt: String           // ISO8601
    var appBuild: String
    var parserVersion: String       // tem bộ đọc (B2 Điều 3)
    var deviceModel: String
    var osVersion: String
}

/// input — truy vết đầu vào (nguồn / kích thước / EXIF / ảnh gốc).
struct DiagInput: Codable, Equatable {
    var source: String              // documentScanner | photoLibrary | cameraPhoto | pdfTextLayer | storedText
    var imageFileName: String       // khoá tới ảnh gốc + tên file phụ
    var pixelWidth: Int? = nil
    var pixelHeight: Int? = nil
    var exifOrientation: Int? = nil
    var byteSize: Int? = nil
    var pdfRenderScale: Double? = nil
}

/// Manifest của engine đã đọc (ghi vào MỌI bản ghi — A3 của cổng
/// phát hành đối chiếu manifest này giữa đường kiểm và đường giao).
struct EngineManifest: Codable, Equatable {
    var family: String              // "classic" | "documents"
    var revision: String            // "rev3" (ghim — §3.2 bản thảo)
    var level: String               // "accurate"
    var languagesEffective: [String]
    var usesLanguageCorrection: Bool
    var minimumTextHeight: Double
}

/// config — cấu hình hiệu lực + hash (hai lần đọc cùng hash = cùng
/// cấu hình; A3 đối chiếu hash giữa đường kiểm và đường giao).
struct DiagConfig: Codable, Equatable {
    var engineManifest: EngineManifest
    var tilePolicyID: String
    var tileParams: [String: Double] = [:]
    var candidatePolicyID: String
    var readerConfigHash: String
}

/// Một ứng viên ảnh của F1 (gốc/phối cảnh/tăng cường/nắn) + điểm
/// chọn của hàm điểm ứng viên (F3-2 — ĐO-Ở-PHA-2 ở bản chốt).
struct DiagCandidate: Codable, Equatable {
    var kind: String                // "original" | "perspective" | "dewarp" | "shadowRemoved" | "enhanced" | "binarized"
    var transformDesc: String       // tứ giác / tham số lọc — mô tả biến đổi (§1.5)
    var gateVerdict: String? = nil  // verdict cổng tứ giác D-2.3 nếu có
    var scoreComponents: [String: Double] = [:]
    var scoreTotal: Double? = nil
    var winner: Bool = false
}

/// Một ô của QualityMap — điểm chất lượng CÓ VỊ TRÍ (DESIGN-FINAL
/// §3.1(c)): đích nhắm đọc-lại-ROI ở F5 + hạng tử của hàm chọn
/// ứng viên ảnh. suspectedDefect đặt tên theo taxonomy khuyết tật
/// của Google ("defect_faint", "defect_text_too_small", ...).
struct QualityMapEntry: Codable, Equatable {
    var box: DiagRect
    var score: Double               // 0–100 theo đoạn/khối
    var suspectedDefect: String? = nil
}

/// Một mảnh chữ TRƯỚC ráp (đơn vị hồ sơ nhỏ nhất — kế thừa
/// OCRFragment2 của p2-1, chuyển Codable tường minh).
struct DiagFragment: Codable, Equatable {
    var id: Int
    var text: String
    var alternates: [AltText]
    var confidence: Double
    var box: DiagRect
    var passID: String              // "original" | "derived" | "tile" | "reread" | "pdfText"
    var tileIndex: Int? = nil
    var regionID: Int? = nil
}

/// Khoảng ký tự một mảnh chiếm trong dòng sau ráp.
struct DiagSpan: Codable, Equatable {
    var fragmentID: Int
    var charStart: Int
    var charEnd: Int
}

/// Một dòng SAU ráp (sản phẩm của F3 — suy ra được từ fragments,
/// lưu kèm để đối chiếu khi replay).
struct DiagLine: Codable, Equatable {
    var text: String
    var confidence: Double
    var box: DiagRect
    var spans: [DiagSpan]
    var passSources: [String]
    var contested: Bool = false
    var alternates: [AltText] = []
}

/// Mảnh bị khử trùng loại ở F3 (giữ vết + lý do — bất biến chống
/// nhân đôi kiểm được từ chính trường này + invariantViolations).
struct DiagDroppedFragment: Codable, Equatable {
    var fragmentID: Int
    var reason: String
}

/// assembly — kết quả ráp F3: bản đồ lát, vùng mù, mảnh bị loại,
/// số vi phạm bất biến, dòng sau ráp.
struct DiagAssembly: Codable, Equatable {
    var tileMap: [DiagRect] = []
    var blindBands: [DiagRect] = []
    var dedupeDropped: [DiagDroppedFragment] = []
    var invariantViolations: Int = 0
    var lines: [DiagLine] = []
}

struct DiagItem: Codable, Equatable {
    var name: String
    var qty: Int
    var unitPriceCents: Int? = nil
    var amountCents: Int? = nil
    var taxFlag: String? = nil
    var itemCode: String? = nil
}

struct DiagTaxLine: Codable, Equatable {
    var label: String
    var rateText: String? = nil
    var amountCents: Int
}

/// Snapshot ParseResult tại thời điểm kết thúc F4 (trước F5) —
/// replay phải tái lập TRÙNG TỪNG TRƯỜNG với snapshot này
/// (DESIGN-DETAIL §5.2).
struct DiagParseSnapshot: Codable, Equatable {
    var vendor: String? = nil
    var vendorKey: String = "generic"
    var vendorSource: String? = nil
    var dateISO: String? = nil      // ISO8601 của ngày đọc được
    var items: [DiagItem] = []
    var subtotalCents: Int? = nil
    var taxes: [DiagTaxLine] = []
    var totalCents: Int? = nil
    var itemsSold: Int? = nil
    var cardLast4: String? = nil
    var cardBrand: String? = nil
    var warnings: [String] = []
    /// Nguồn gốc theo trường, khoá = tên trường ("vendor",
    /// "total", "items[3].amount", ...).
    var provenance: [String: FieldProvenance] = [:]
}

/// Một lần sửa của DomainCorrection (chỉ CHỮ — §3.4(b) bản chốt).
struct DiagCorrection: Codable, Equatable {
    var field: String
    var itemIndex: Int? = nil
    var from: String
    var to: String
    var lexiconVersion: String
    var rule: String
}

struct DiagFix: Codable, Equatable {
    var channel: String             // FORCE | TOKEN | ORPHAN | DIGIT | SIGN | DEFICIT | CANDIDATE
    var field: String
    var itemIndex: Int? = nil
    var oldValue: String
    var newValue: String
}

struct DiagRegionHint: Codable, Equatable {
    var box: DiagRect
    var reason: String              // kênh/khuyết tật sinh ra gợi ý
    var field: String? = nil
}

/// Snapshot F5 (trọng tài) sau khi áp.
struct DiagReconcileSnapshot: Codable, Equatable {
    var status: String              // "closed" | "flagged" | "suggestedOnly" | "notRun"
    var fixes: [DiagFix] = []
    var suggestions: [String] = []
    var regionHints: [DiagRegionHint] = []
}

/// Một vòng đọc-lại-ROI (giao thức §3.5 bản thảo: ≤ 2 vòng).
struct DiagROIRound: Codable, Equatable {
    var round: Int
    var hints: [DiagRegionHint] = []
    var fragmentsAdded: Int = 0
    var stateBefore: String         // trạng thái cổng sổ trước vòng (E1/E2/E3 dạng chữ)
    var stateAfter: String
    var accepted: Bool = false
}

/// outcome — cờ + thời gian + lỗi của lần đọc.
struct DiagOutcome: Codable, Equatable {
    var flags: [String] = []
    var elapsedMs: Int = 0
    var error: String? = nil
}

// MARK: Bản ghi gốc — schema v2

struct ReadDiagnostics: Codable, Equatable {
    var schemaVersion: Int = 2
    var identity: DiagIdentity
    var input: DiagInput
    var config: DiagConfig
    var candidates: [DiagCandidate] = []
    var qualityMap: [QualityMapEntry] = []
    var fragments: [DiagFragment] = []
    var assembly: DiagAssembly = DiagAssembly()
    var parse: DiagParseSnapshot = DiagParseSnapshot()
    var reconcile: DiagReconcileSnapshot =
        DiagReconcileSnapshot(status: "notRun")
    var roiRounds: [DiagROIRound] = []
    var corrections: [DiagCorrection] = []
    var outcome: DiagOutcome = DiagOutcome()

    /// Băm cấu hình hiệu lực (FNV-1a 64 trên chuỗi chuẩn hoá của
    /// manifest + policy) — hàm băm truy vết, KHÔNG phải băm mật
    /// mã: mục đích là hai lần đọc cùng cấu hình cho cùng hash và
    /// mọi lệch cấu hình đều đổi hash.
    static func computeConfigHash(manifest: EngineManifest,
                                  tilePolicyID: String,
                                  candidatePolicyID: String) -> String {
        let canonical = [
            manifest.family, manifest.revision, manifest.level,
            manifest.languagesEffective.joined(separator: ","),
            manifest.usesLanguageCorrection ? "corr1" : "corr0",
            String(manifest.minimumTextHeight),
            tilePolicyID, candidatePolicyID,
        ].joined(separator: "|")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    /// JSON xuất từ bản ghi (nút xuất ở màn Chi Tiết — §1.2 M12).
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - Kho lưu file phụ + cổng ghi fail-closed

/// Writer có thể TIÊM hàm ghi (điểm tiêm cho test mô phỏng lỗi
/// ghi ở Pha 0 — xem diagnostics_mirror.py và AFTER.md).
struct DiagnosticsWriter {
    var writeData: (Data, URL) throws -> Void = { data, url in
        try data.write(to: url, options: [.atomic])
    }

    func persist(_ record: ReadDiagnostics,
                 directory: URL) throws -> String {
        let data = try record.exportJSON()
        let url = DiagnosticsStore.sidecarURL(
            directory: directory, imageFileName: record.input.imageFileName)
        try writeData(data, url)
        return record.identity.diagnosticsID
    }
}

/// Kho file phụ JSON cạnh ảnh gốc (`<imageFileName>.ocrdiag.json`).
/// `directory` truyền tường minh: file này không phụ thuộc
/// ImageStore của app chính (module đọc phải đứng độc lập được —
/// cùng tập file liên kết vào BenchShell/ReplayHarness, §1.1).
enum DiagnosticsStore {
    static func fileName(forImageFileName imageFileName: String) -> String {
        imageFileName + ".ocrdiag.json"
    }

    static func sidecarURL(directory: URL, imageFileName: String) -> URL {
        directory.appendingPathComponent(fileName(forImageFileName: imageFileName))
    }

    static func load(directory: URL, imageFileName: String) -> ReadDiagnostics? {
        let url = sidecarURL(directory: directory, imageFileName: imageFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ReadDiagnostics.self, from: data)
    }
}

/// Kết quả chốt một lần đọc qua cổng ghi chẩn đoán.
struct FinalizedOutcome<Outcome> {
    var outcome: Outcome
    var diagnosticsID: String?
    /// true = ghi chẩn đoán THẤT BẠI. Theo hợp đồng §1.5,
    /// ReadPipeline chỉ được trả outcome này kèm cờ ép lên tờ
    /// (diagnosticsWriteFailed) — KHÔNG tồn tại đường trả outcome
    /// "sạch" khi bản ghi không ghi được.
    var diagnosticsWriteFailed: Bool
}

/// Cổng chốt fail-closed: ghi chẩn đoán TRƯỚC khi outcome được
/// coi là hoàn tất. Ghi lỗi không nuốt outcome (tờ vẫn đọc được)
/// nhưng outcome bị đánh dấu vĩnh viễn qua diagnosticsWriteFailed.
enum ReadFinalizer {
    static func finalize<Outcome>(_ outcome: Outcome,
                                  diagnostics: ReadDiagnostics,
                                  directory: URL,
                                  writer: DiagnosticsWriter = DiagnosticsWriter())
        -> FinalizedOutcome<Outcome> {
        do {
            let id = try writer.persist(diagnostics, directory: directory)
            return FinalizedOutcome(outcome: outcome,
                                    diagnosticsID: id,
                                    diagnosticsWriteFailed: false)
        } catch {
            return FinalizedOutcome(outcome: outcome,
                                    diagnosticsID: nil,
                                    diagnosticsWriteFailed: true)
        }
    }
}

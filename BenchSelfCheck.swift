import Foundation
import CoreGraphics

/// Gate D — TỰ KIỂM MỘT CHẠM của BenchShell (G5, xây theo đặc
/// tả core-expert/G1-BENCH-SELFCHECK-SPEC.md). File này CHỈ
/// thuộc target bench (xem project.yml): app chính không liên
/// kết nó và không đổi một dòng vì Gate D (đặc tả §10).
///
/// Bốn khối:
///   A — 43 ảnh đóng băng qua ReceiptReader.read (ĐÚNG điểm
///       vào của app, cấm gọi thẳng ReceiptParser.parse) + tự
///       chấm theo bảng sự thật đóng băng bench-gt.json đi
///       cùng bundle. Kết quả ghi XUỐNG ĐĨA theo từng ảnh +
///       marker "đang đọc ảnh n": app chết giữa chừng thì lần
///       mở sau ghi ca đó CRASHED và chạy tiếp được.
///   B — ma trận vòng đời MỘT LẦN GIẾT: gieo đồng thời nháp
///       (PendingDraftStore, kèm lớp sửa dở reviewEdits của
///       G3) + trạng thái bị chặn (PendingBlockStore của G3)
///       vào container RIÊNG của bench; kỳ vọng đóng băng
///       xuống đĩa TRƯỚC khi anh giết app; mở lại tự đối
///       chiếu từng trường.
///   C — replay chẩn đoán: nạp file .ocrdiag.json anh xuất từ
///       app thật, chạy lại đường chữ qua ReceiptReader
///       (textLines từ ngăn assembly của chính hồ sơ) và đối
///       chiếu với snapshot đã ghi trong hồ sơ.
///   D — phân phối hiệu chuẩn cổng chất lượng (từ số đo thô
///       của Phần A — chỉ ghi, không phán ngưỡng; hiệu chuẩn
///       là việc G4) + kịch bản L-18/L-17 ở mức logic thuần
///       (ReceiptLogic — cơ chế commit trong ReceiptDetailView
///       không thuộc target bench nên tương tác View đầy đủ
///       không dựng lại ở đây; xem verdict.method trong file
///       kết quả).
/// Xuất ĐÚNG MỘT file JSON (đặc tả §7) qua writeFinalResult.
enum BenchSelfCheck {

    // MARK: - Bảng sự thật đóng băng (bench-gt.json)

    struct GTEntry: Codable {
        var vendorAliases: [String]
        var date: String?
        var subtotal: Int?
        var taxes: [Int]
        var total: Int?
        var lines: Int
        var sold: Int?
        var card: String?
        var seed: Bool
    }

    struct GTFile: Codable {
        var gtVersion: String
        var cases: [String: GTEntry]
    }

    static func loadGT() -> GTFile? {
        guard let url = Bundle.main.url(forResource: "bench-gt",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GTFile.self, from: data)
    }

    // MARK: - Kết quả từng ảnh (Phần A) + kho tiến trình

    struct Entry: Codable {
        var file: String
        var parserVersion: String
        var arbiterStatus: String
        var blocks: [String] = []
        var vendor: String? = nil
        var dateText: String? = nil
        var subtotal: Int? = nil
        var taxes: [Int] = []
        var total: Int? = nil
        var itemsCount: Int = 0
        var sumItems: Int? = nil
        var sold: Int? = nil
        var card: String? = nil
        var roiRounds: Int = 0
        var roiAccepted: Int = 0
        var qualityDecision: String = "unknown"
        var blur: Double = 0
        var glare: Double = 0
        var contrast: Double = 0
        var elapsedMs: Int = 0
        var diagnosticsID: String? = nil
        var scoreClass: String = "NOT-SCORED"
        var wrongFields: [String] = []
    }

    struct Progress: Codable {
        var startedAt: String = ""
        var entries: [Entry] = []
        var partB: [PartBItem] = []
        var partC: [ReplayItem] = []
        var lifecycleSeededAt: String? = nil
    }

    struct PartBItem: Codable {
        var id: String
        var expected: String
        var actual: String
        var verdict: String   // PASS | FAIL | KNOWN-GAP
        var diffs: [String] = []
    }

    struct ReplayItem: Codable {
        var file: String
        var oldParserVersion: String
        var newParserVersion: String
        var oldDiagnosticsID: String
        var diffs: [String] = []
    }

    static var selfCheckDirectory: URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("SelfCheck",
                                              isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var progressURL: URL {
        selfCheckDirectory.appendingPathComponent("progress.json")
    }

    private static var markerURL: URL {
        selfCheckDirectory.appendingPathComponent("current-image.txt")
    }

    static func loadProgress() -> Progress {
        guard let data = try? Data(contentsOf: progressURL),
              let p = try? JSONDecoder().decode(Progress.self,
                                                 from: data)
        else { return Progress() }
        return p
    }

    static func saveProgress(_ p: Progress) {
        guard let data = try? JSONEncoder().encode(p) else { return }
        try? data.write(to: progressURL, options: [.atomic])
    }

    static func resetProgress() {
        try? FileManager.default.removeItem(at: progressURL)
        try? FileManager.default.removeItem(at: markerURL)
    }

    // MARK: - Phần A: đọc một ảnh qua đường app + chấm

    /// Ghi marker TRƯỚC khi đọc (đặc tả §2.3): chết giữa ảnh
    /// nào thì marker còn nguyên tên ảnh đó.
    static func beginImage(_ name: String) {
        try? name.write(to: markerURL, atomically: true,
                        encoding: .utf8)
    }

    /// Ảnh chết ở phiên trước: marker còn mà tiến trình chưa
    /// có kết quả của nó.
    static func pendingCrash() -> String? {
        guard let name = try? String(contentsOf: markerURL,
                                     encoding: .utf8),
              !name.isEmpty else { return nil }
        let p = loadProgress()
        return p.entries.contains { $0.file == name } ? nil : name
    }

    static func completeImage(_ entry: Entry) {
        var p = loadProgress()
        p.entries.removeAll { $0.file == entry.file }
        p.entries.append(entry)
        saveProgress(p)
        try? FileManager.default.removeItem(at: markerURL)
    }

    static func crashedEntry(_ name: String) -> Entry {
        var e = Entry(file: name,
                      parserVersion: ReadCoreVersion.parserVersion,
                      arbiterStatus: "crashed")
        e.scoreClass = "CRASHED"
        return e
    }

    /// Đọc một ảnh bundle qua ReceiptReader (đường app) và
    /// chấm theo GT. diagnosticsDirectory: thư mục Bench
    /// Diagnostics của BenchView (hồ sơ phụ ghi như lệ bench).
    static func readOne(name: String, cg: CGImage, gt: GTEntry?,
                        diagnosticsDirectory: URL) -> Entry {
        let outcome = ReceiptReader.read(ReadRequest(
            source: .photoLibrary,
            imageFileName: name,
            image: cg,
            diagnosticsDirectory: diagnosticsDirectory))
        let r = outcome.result
        var e = Entry(file: name,
                      parserVersion: ReadCoreVersion.parserVersion,
                      arbiterStatus: r.arbiterStatus ?? "nil")
        if let hint = r.arbiterRegionHint { e.blocks.append(hint) }
        if let d1 = r.arbiterDeficitE1,
           abs(d1) > ItemsArbiter.e1ToleranceCents,
           !e.blocks.contains("items-block") {
            e.blocks.append("items-block")
        }
        e.vendor = r.vendor
        e.dateText = r.date.map { dateText(of: $0) }
        e.subtotal = r.subtotalCents
        e.taxes = r.taxes.map { $0.amountCents }
        e.total = r.totalCents
        e.itemsCount = r.items.count
        e.sumItems = SafeMoney.sumCents(r.items.map { $0.amountCents ?? 0 })
        e.sold = r.itemsSold
        e.card = r.cardLast4
        e.roiRounds = outcome.diagnostics.roiRounds.count
        e.roiAccepted = outcome.diagnostics.roiRounds
            .filter { $0.accepted }.count
        e.qualityDecision = outcome.qualityOutcome?.decision.rawValue
            ?? "unknown"
        if let grid = LuminanceGrid.fromImage(cg) {
            let s = grid.signals()
            e.blur = s.blurVariance
            e.glare = s.glareFraction
            e.contrast = s.localContrast
        }
        e.elapsedMs = outcome.diagnostics.outcome.elapsedMs
        e.diagnosticsID = outcome.diagnosticsID
        if let gt {
            let scored = score(gt: gt, result: r, outcome: outcome)
            e.scoreClass = scored.cls
            e.wrongFields = scored.wrong
        }
        return e
    }

    private static func dateText(of date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Chấm một ca theo ngữ nghĩa SCORECARD (Cổng Sổ Món):
    /// FULL-LEDGER khi mọi trường có sự thật đều đúng; PARTIAL
    /// khi sổ của chính tờ khép mà có trường lệch sự thật;
    /// SILENT-WRONG khi có trường sai/thiếu mà KHÔNG cờ nào
    /// phủ (warnings rỗng + không ép Kiểm Lại); còn lại
    /// FLAGGED-LOSS (thất bại trung thực).
    static func score(gt: GTEntry, result r: ParseResult,
                      outcome: ReadOutcome)
        -> (cls: String, wrong: [String]) {
        var wrong: [String] = []
        if let vendor = r.vendor {
            let v = vendor.lowercased()
            if !gt.vendorAliases.contains(where: { v.contains($0) }) {
                wrong.append("vendor")
            }
        } else { wrong.append("vendor") }
        if let gd = gt.date {
            if r.date.map({ dateText(of: $0) }) != gd {
                wrong.append("date")
            }
        }
        if let gs = gt.subtotal {
            if r.subtotalCents != gs { wrong.append("subtotal") }
            if r.taxes.map({ $0.amountCents }).sorted() != gt.taxes.sorted() {
                wrong.append("taxes")
            }
            let sum = SafeMoney.sumCents(r.items.map { $0.amountCents ?? 0 })
            if sum.map({ abs($0 - gs) > 2 }) ?? true {
                wrong.append("sumItems")
            }
        }
        if r.totalCents != gt.total { wrong.append("total") }
        if r.items.count != gt.lines { wrong.append("itemsCount") }
        if let sold = gt.sold, r.itemsSold != sold {
            wrong.append("sold")
        }
        if let card = gt.card, r.cardLast4 != card {
            wrong.append("card")
        }
        if wrong.isEmpty { return ("FULL-LEDGER", wrong) }
        var ownClosure = false
        if let subtotal = r.subtotalCents, let total = r.totalCents,
           let sum = SafeMoney.sumCents(r.items.map { $0.amountCents ?? 0 }) {
            ownClosure = abs(sum - subtotal) <= 2
                && abs(subtotal + r.taxTotalCents - total) <= 2
        }
        if ownClosure { return ("PARTIAL", wrong) }
        if r.warnings.isEmpty && !outcome.report.requiresReview {
            return ("SILENT-WRONG", wrong)
        }
        return ("FLAGGED-LOSS", wrong)
    }

    // MARK: - Phần B: gieo + đối chiếu vòng đời một-lần-giết

    /// Nội dung gieo ĐÓNG BĂNG của kịch bản (mọi trường biết
    /// trước — đối chiếu theo đúng các giá trị này).
    static let seedVendor = "BenchSeed"
    static let seedSubtotal = 1000
    static let seedTax = 83
    static let seedTotal = 1083
    static let seedImageFileName = "bench-seed-b1.jpg"
    static let seedEditedVendor = "BenchSeed-Edited"

    static func seedResult() -> ParseResult {
        var r = ParseResult()
        r.vendor = seedVendor
        r.vendorKey = "generic"
        r.date = Date(timeIntervalSince1970: 1_767_225_600)
        r.items = [ParsedLineItem(name: "BENCH SEED ITEM 1", qty: 1,
                                  unitPriceCents: seedSubtotal,
                                  amountCents: seedSubtotal)]
        r.subtotalCents = seedSubtotal
        r.taxes = [ParsedTaxLine(label: "TAX", amountCents: seedTax)]
        r.totalCents = seedTotal
        r.cardLast4 = "2586"
        r.itemsSold = 1
        r.rawText = "BENCH SEED B1 RAW"
        return r
    }

    static func seedEdits() -> ReviewEditsDTO {
        ReviewEditsDTO(
            vendorText: seedEditedVendor,
            dateValue: Date(timeIntervalSince1970: 1_767_225_600),
            subtotalText: "10.00", taxText: "0.83",
            totalText: "10.83", kindRaw: "business",
            category: "Supplies",
            purposeText: "Mua cho khách trong tiệm",
            reasonText: "", suggestionApplied: true)
    }

    /// Gieo đồng thời B1 (nháp + lớp sửa dở B3 trong cùng bản
    /// chụp — cùng một ô PendingDraftStore như app thật) và
    /// B2 (trạng thái chặn qua PendingBlockStore). Kỳ vọng
    /// ghi vào progress TRƯỚC khi anh giết app.
    @discardableResult
    static func seedLifecycle() -> Bool {
        var snapshot = PendingDraftSnapshot(
            result: seedResult(),
            imageFileName: seedImageFileName,
            sourceTypeRaw: "photoLibrary",
            sourceFileName: nil,
            originalFileNames: [seedImageFileName],
            rawTextIsPDFTextLayer: false,
            provenance: [:],
            reconcileReport: nil,
            diagnosticsID: "bench-b1",
            diagnosticsWriteFailed: false)
        snapshot.reviewEdits = seedEdits()
        let block = PendingBlockSnapshot(
            draftSnapshot: snapshot,
            quality: QualityOutcome(detected: ["blur", "lowContrast"],
                                    decision: .block, failSafe: false,
                                    consecutiveRejects: 1))
        let okDraft = PendingDraftStore.save(snapshot)
        let okBlock = PendingBlockStore.save(block)
        var p = loadProgress()
        p.lifecycleSeededAt = ISO8601DateFormatter().string(from: Date())
        p.partB = [
            PartBItem(id: "B1", expected: "nháp khôi phục nguyên trường",
                      actual: "", verdict: "SEEDED"),
            PartBItem(id: "B2", expected: "trạng thái chặn khôi phục, quyết định .block",
                      actual: "", verdict: "SEEDED"),
            PartBItem(id: "B3", expected: "lớp sửa dở khôi phục nguyên trường",
                      actual: "", verdict: "SEEDED"),
            PartBItem(id: "B-FACEID-TAB",
                      expected: "vị trí tab + cây giao diện qua chu trình khoá",
                      actual: "BenchShell không có cổng khoá Face ID/tab",
                      verdict: "KNOWN-GAP"),
        ]
        saveProgress(p)
        return okDraft && okBlock
    }

    static func lifecycleSeeded() -> Bool {
        loadProgress().lifecycleSeededAt != nil
    }

    /// Chạy ở lần mở app SAU khi giết: đối chiếu từng trường
    /// đã gieo, ghi verdict vào progress, dọn kho gieo.
    static func verifyLifecycle() -> [PartBItem] {
        var items: [PartBItem] = []
        let loaded = PendingDraftStore.load()
        // B1 — nháp nguyên trường
        var b1 = PartBItem(id: "B1",
                           expected: "vendor=\(seedVendor) subtotal=\(seedSubtotal) total=\(seedTotal)",
                           actual: "", verdict: "FAIL")
        if let s = loaded {
            var diffs: [String] = []
            if s.result.vendor != seedVendor { diffs.append("vendor") }
            if s.result.subtotalCents != seedSubtotal { diffs.append("subtotal") }
            if s.result.totalCents != seedTotal { diffs.append("total") }
            if s.result.taxes.map({ $0.amountCents }) != [seedTax] { diffs.append("taxes") }
            if s.result.items.count != 1 { diffs.append("itemsCount") }
            if s.result.cardLast4 != "2586" { diffs.append("card") }
            if s.imageFileName != seedImageFileName { diffs.append("imageFileName") }
            b1.diffs = diffs
            b1.actual = "load được, lệch: \(diffs.isEmpty ? "không" : diffs.joined(separator: ","))"
            b1.verdict = diffs.isEmpty ? "PASS" : "FAIL"
        } else {
            b1.actual = "load = nil (bản chụp mất)"
            b1.diffs = ["missing"]
        }
        items.append(b1)
        // B3 — lớp sửa dở phủ trên cùng bản chụp
        var b3 = PartBItem(id: "B3",
                           expected: "reviewEdits khôi phục nguyên trường",
                           actual: "", verdict: "FAIL")
        if let edits = loaded?.reviewEdits {
            var diffs: [String] = []
            if edits.vendorText != seedEditedVendor { diffs.append("vendorText") }
            if edits.subtotalText != "10.00" { diffs.append("subtotalText") }
            if edits.taxText != "0.83" { diffs.append("taxText") }
            if edits.totalText != "10.83" { diffs.append("totalText") }
            if edits.kindRaw != "business" { diffs.append("kindRaw") }
            if edits.category != "Supplies" { diffs.append("category") }
            if edits.purposeText != "Mua cho khách trong tiệm" { diffs.append("purposeText") }
            if !edits.suggestionApplied { diffs.append("suggestionApplied") }
            if Int(edits.dateValue.timeIntervalSince1970) != 1_767_225_600 {
                diffs.append("dateValue")
            }
            b3.diffs = diffs
            b3.actual = "lớp sửa có mặt, lệch: \(diffs.isEmpty ? "không" : diffs.joined(separator: ","))"
            b3.verdict = diffs.isEmpty ? "PASS" : "FAIL"
        } else {
            b3.actual = "reviewEdits = nil (lớp sửa mất)"
            b3.diffs = ["missing"]
        }
        items.append(b3)
        // B2 — trạng thái chặn
        var b2 = PartBItem(id: "B2",
                           expected: "PendingBlock khôi phục, quyết định .block",
                           actual: "", verdict: "FAIL")
        if let block = PendingBlockStore.load() {
            var diffs: [String] = []
            if block.draft.imageFileName != seedImageFileName {
                diffs.append("imageFileName")
            }
            let qo = block.qualityOutcome()
            if qo?.decision != .block { diffs.append("decision") }
            if qo?.detected.sorted() != ["blur", "lowContrast"] {
                diffs.append("detected")
            }
            b2.diffs = diffs
            b2.actual = "load được, lệch: \(diffs.isEmpty ? "không" : diffs.joined(separator: ","))"
            b2.verdict = diffs.isEmpty ? "PASS" : "FAIL"
        } else {
            b2.actual = "load = nil (trạng thái chặn mất)"
            b2.diffs = ["missing"]
        }
        items.append(b2)
        items.append(PartBItem(
            id: "B-FACEID-TAB",
            expected: "vị trí tab + cây giao diện qua chu trình khoá",
            actual: "BenchShell không có cổng khoá Face ID/tab — kiểm trên app chính",
            verdict: "KNOWN-GAP"))
        var p = loadProgress()
        p.partB = items
        p.lifecycleSeededAt = nil
        saveProgress(p)
        PendingDraftStore.clear()
        PendingBlockStore.clear()
        return items
    }

    // MARK: - Phần C: replay chẩn đoán

    /// Replay một file .ocrdiag.json: đường chữ qua
    /// ReceiptReader (textLines = dòng assembly của chính hồ
    /// sơ) rồi đối chiếu snapshot parse đã ghi. Kết quả cộng
    /// vào progress (theo tên file gốc, nạp lại thì thay).
    @discardableResult
    static func replayAndStore(diagData: Data) -> ReplayItem? {
        guard let diag = try? JSONDecoder().decode(
            ReadDiagnostics.self, from: diagData) else { return nil }
        let lines = diag.assembly.lines.map {
            OCRLine(text: $0.text, confidence: $0.confidence)
        }
        let outcome = ReceiptReader.read(ReadRequest(
            source: .storedText,
            imageFileName: diag.input.imageFileName,
            textLines: lines,
            diagnosticsDirectory: nil))
        let r = outcome.result
        let s = diag.parse
        var diffs: [String] = []
        if r.subtotalCents != s.subtotalCents { diffs.append("subtotal") }
        if r.taxes.map({ $0.amountCents }).sorted()
            != s.taxes.map({ $0.amountCents }).sorted() {
            diffs.append("taxes")
        }
        if r.totalCents != s.totalCents { diffs.append("total") }
        if r.items.count != s.items.count { diffs.append("itemsCount") }
        let sumNew = SafeMoney.sumCents(r.items.map { $0.amountCents ?? 0 })
        let sumOld = SafeMoney.sumCents(s.items.map { $0.amountCents ?? 0 })
        if sumNew != sumOld { diffs.append("sumItems") }
        if r.cardLast4 != s.cardLast4 { diffs.append("card") }
        let item = ReplayItem(
            file: diag.input.imageFileName,
            oldParserVersion: diag.identity.parserVersion,
            newParserVersion: ReadCoreVersion.parserVersion,
            oldDiagnosticsID: diag.identity.diagnosticsID,
            diffs: diffs)
        var p = loadProgress()
        p.partC.removeAll { $0.file == item.file }
        p.partC.append(item)
        saveProgress(p)
        return item
    }

    // MARK: - Phần D: logic L-18/L-17 + phân phối chất lượng

    struct LogicChecks {
        var scL18Pass: Bool
        var scL17Pass: Bool
    }

    /// SC-L18 ở mức HỆ QUẢ THUẦN (đặc tả §5 ghi rõ cơ chế đầy
    /// đủ sống trong ReceiptDetailView — ngoài target bench):
    /// bản ghi business đã cam kết mục đích "B" thì bộ cờ
    /// KHÔNG còn cờ thiếu mục đích; cùng bản ghi với mục đích
    /// rỗng thì cờ PHẢI có. SC-L17: canReparse chỉ phụ thuộc
    /// ocrRawText (còn chữ = còn bấm được).
    static func runLogicChecks() -> LogicChecks {
        let amounts: [Int?] = [1948, 3896, 1948, 1728, 1898, 5498]
        let committed = ReceiptFlagInput(
            subtotalCents: 16916, itemAmountCents: amounts,
            totalCents: 17928, taxCents: 1012, kind: .business,
            businessPurpose: "B", hasOriginalImage: true)
        var uncommitted = committed
        uncommitted.businessPurpose = ""
        let flagsB = ReceiptLogic.flags(for: committed)
        let flagsEmpty = ReceiptLogic.flags(for: uncommitted)
        let l18 = !flagsB.contains(missingPurposeFlagText)
            && flagsEmpty.contains(missingPurposeFlagText)
        let l17 = ReceiptLogic.canReparse(ocrRawText: "BENCH RAW")
            && !ReceiptLogic.canReparse(ocrRawText: "")
        return LogicChecks(scL18Pass: l18, scL17Pass: l17)
    }

    // MARK: - File kết quả duy nhất (đặc tả §7)

    private static func percentile(_ sorted: [Int], _ q: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int((q * Double(sorted.count)).rounded(.up)) - 1
        return sorted[max(0, min(idx, sorted.count - 1))]
    }

    private static func entryDict(_ e: Entry) -> [String: Any] {
        var d: [String: Any] = [
            "file": e.file,
            "parserVersion": e.parserVersion,
            "arbiterStatus": e.arbiterStatus,
            "blocks": e.blocks,
            "taxes": e.taxes,
            "itemsCount": e.itemsCount,
            "roiRounds": e.roiRounds,
            "roiAccepted": e.roiAccepted,
            "qualityDecision": e.qualityDecision,
            "qualitySignals": ["blur": e.blur, "glare": e.glare,
                               "contrast": e.contrast],
            "elapsedMs": e.elapsedMs,
            "scoreClass": e.scoreClass,
            "wrongFields": e.wrongFields,
        ]
        if let v = e.vendor { d["vendor"] = v }
        if let v = e.dateText { d["date"] = v }
        if let v = e.subtotal { d["subtotal"] = v }
        if let v = e.total { d["total"] = v }
        if let v = e.sumItems { d["sumItems"] = v }
        if let v = e.sold { d["sold"] = v }
        if let v = e.card { d["card"] = v }
        if let v = e.diagnosticsID { d["diagnosticsID"] = v }
        return d
    }

    /// Dựng + ghi file kết quả; trả URL file. verdict theo
    /// tiêu chí cứng §8 của đặc tả (KNOWN-GAP ở B-FACEID-TAB
    /// không chặn PASS vì BenchShell về nguyên tắc không có
    /// cổng khoá — đã khai trong chính mục đó).
    /// L-2026-11-16-23: JSONSerialization NÉM NGOẠI LỆ ObjC (không
    /// phải Swift error, try? KHÔNG bắt được) khi gặp Double NaN/∞ —
    /// crash ngay nút Xuất file trên máy anh 2026-11-16. Các tín hiệu
    /// chất lượng (blur/glare/contrast) là Double tính từ ảnh thật,
    /// NaN tới được qua phép chia mẫu rỗng. Hàm này duyệt đệ quy toàn
    /// bộ cây kết quả: số không hữu hạn -> chuỗi "non-finite" (giữ
    /// bằng chứng trong chính file xuất ra), còn lại giữ nguyên.
    private static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let d as Double:
            return d.isFinite ? d : "non-finite"
        case let f as Float:
            return f.isFinite ? f : "non-finite"
        case let dict as [String: Any]:
            return dict.mapValues { jsonSafe($0) }
        case let arr as [Any]:
            return arr.map { jsonSafe($0) }
        default:
            return value
        }
    }

    static func writeFinalResult(deviceModel: String,
                                 osVersion: String) -> URL? {
        let p = loadProgress()
        let entries = p.entries.sorted { $0.file < $1.file }
        var counts: [String: Int] = [:]
        for e in entries { counts[e.scoreClass, default: 0] += 1 }
        let elapsed = entries.map { $0.elapsedMs }.sorted()
        let logic = runLogicChecks()
        // Phần D — phân phối hiệu chuẩn (chỉ ghi số đo thô).
        var decisionCounts: [String: Int] = [:]
        for e in entries {
            decisionCounts[e.qualityDecision, default: 0] += 1
        }
        func stats(_ values: [Double]) -> [String: Any] {
            guard !values.isEmpty else { return [:] }
            let s = values.sorted()
            return ["min": s.first ?? 0,
                    "p50": s[s.count / 2],
                    "max": s.last ?? 0]
        }
        // Verdict §8.
        var failures: [String] = []
        if entries.count != 43 {
            failures.append("partA: \(entries.count)/43 ảnh")
        }
        if (counts["CRASHED"] ?? 0) > 0 { failures.append("partA: CRASHED > 0") }
        if (counts["SILENT-WRONG"] ?? 0) > 0 { failures.append("partA: SILENT-WRONG > 0") }
        if (counts["DIED"] ?? 0) > 0 { failures.append("partA: DIED > 0") }
        for item in p.partB where item.verdict == "FAIL" {
            failures.append("partB: \(item.id) FAIL")
        }
        if p.partB.isEmpty { failures.append("partB: chưa chạy") }
        if p.partC.isEmpty { failures.append("partC: chưa nạp file nào") }
        if !logic.scL18Pass { failures.append("partD: SC-L18 FAIL") }
        if !logic.scL17Pass { failures.append("partD: SC-L17 FAIL") }
        let iso = ISO8601DateFormatter()
        let root: [String: Any] = [
            "identity": [
                "parserVersion": ReadCoreVersion.parserVersion,
                "appBuild": (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "?",
                "deviceModel": deviceModel,
                "osVersion": osVersion,
                "startedAt": p.startedAt,
                "finishedAt": iso.string(from: Date()),
                "gtVersion": loadGT()?.gtVersion ?? "unloaded",
            ],
            "partA": [
                "entries": entries.map { entryDict($0) },
                "counts": counts,
                "elapsedMs": ["p50": percentile(elapsed, 0.50),
                              "p95": percentile(elapsed, 0.95),
                              "max": elapsed.last ?? 0],
            ],
            "partB": p.partB.map {
                ["id": $0.id, "expected": $0.expected,
                 "actual": $0.actual, "verdict": $0.verdict,
                 "diffs": $0.diffs]
            },
            "partC": p.partC.map {
                ["file": $0.file,
                 "oldParserVersion": $0.oldParserVersion,
                 "newParserVersion": $0.newParserVersion,
                 "oldDiagnosticsID": $0.oldDiagnosticsID,
                 "diffs": $0.diffs]
            },
            "partD": [
                "qualityDistribution": [
                    "decisions": decisionCounts,
                    "blur": stats(entries.map { $0.blur }),
                    "glare": stats(entries.map { $0.glare }),
                    "contrast": stats(entries.map { $0.contrast }),
                ],
                "scL18": [
                    "verdict": logic.scL18Pass ? "PASS" : "FAIL",
                    "method": "logic-downstream (ReceiptLogic.flags tren ban ghi da cam ket muc dich B) — co che commit day du song trong ReceiptDetailView, ngoai target bench",
                ],
                "scL17": [
                    "verdict": logic.scL17Pass ? "PASS" : "FAIL",
                    "method": "ReceiptLogic.canReparse chi phu thuoc ocrRawText",
                ],
            ],
            "verdict": failures.isEmpty ? "PASS" : "FAIL",
            "firstFailures": failures,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: jsonSafe(root),
            options: [.prettyPrinted, .sortedKeys]) else { return nil }
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyyMMdd-HHmm"
        let name = "glkeeper-selfcheck-\(ReadCoreVersion.parserVersion)-\(stamp.string(from: Date())).json"
        let url = selfCheckDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch { return nil }
    }
}

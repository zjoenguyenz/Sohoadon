import Foundation

// MARK: - P-DRAFT: bản chụp bản nháp đọc xuống đĩa (L-2026-11-13-14)
//
// Sự cố gốc: bản nháp sau khi đọc (ScanDraft ở ScanView) chỉ sống
// trong @State của app — anh quét xong chưa kịp Lưu, chuyển app
// khác lâu, iOS giết app nền, mở lại thì bản nháp mất sạch (chỉ
// còn file ảnh mồ côi trong ReceiptImages). Gói này chụp TOÀN BỘ
// trạng thái của bản nháp xuống một file JSON trong Documents
// ngay khi bản nháp ra đời, và khôi phục lại màn Kiểm Lại ở lần
// mở app / hiện tab Quét tiếp theo. Xoá bản chụp đúng ở hai điểm
// kết thúc tường minh của ReviewView (lưu thành công / bấm Huỷ)
// — xem điểm nối ở ScanView.swift.
//
// Kỷ luật gói (DESIGN-V4 §9 mục P-DRAFT + luật §0):
// - DTO Codable THUẦN CỘNG THÊM: ParseResult / ReconcileReport
//   không phải Codable nên có DTO riêng ánh xạ HAI CHIỀU ở file
//   này; KHÔNG đổi model SwiftData, KHÔNG sửa các kiểu gốc.
// - File này KHÔNG phụ thuộc tầng UI (không ScanView/Models):
//   nó chỉ biết các kiểu của tầng đọc (Parser/Reconcile/
//   ReadDiagnostics). Ánh xạ ScanDraft <-> Snapshot nằm ở
//   ScanView.swift nơi ScanDraft được khai báo.
// - Ghi file NGUYÊN TỬ: ghi file tạm cùng thư mục rồi đổi tên —
//   app chết giữa lúc ghi cũng không để lại file JSON nửa vời.
// - Snapshot hỏng / lạ phiên bản: xoá lặng + ghi một dòng log
//   chẩn đoán (PendingDraft.log cùng thư mục), app mở bình
//   thường — khôi phục là đường phụ, không bao giờ được chặn
//   hay làm crash app.

// MARK: DTO cho ParsedLineItem (Parser.swift)

struct ParsedLineItemDTO: Codable, Equatable {
    var name: String
    var qty: Int
    var unitPriceCents: Int?
    var amountCents: Int?
    var taxFlag: String?
    var itemCode: String?
    var weightLb: Double?
    var weightUnitCents: Int?
    var lineIndex: Int?

    init(_ item: ParsedLineItem) {
        name = item.name
        qty = item.qty
        unitPriceCents = item.unitPriceCents
        amountCents = item.amountCents
        taxFlag = item.taxFlag
        itemCode = item.itemCode
        weightLb = item.weightLb
        weightUnitCents = item.weightUnitCents
        lineIndex = item.lineIndex
    }

    func toOriginal() -> ParsedLineItem {
        var item = ParsedLineItem(name: name)
        item.qty = qty
        item.unitPriceCents = unitPriceCents
        item.amountCents = amountCents
        item.taxFlag = taxFlag
        item.itemCode = itemCode
        item.weightLb = weightLb
        item.weightUnitCents = weightUnitCents
        item.lineIndex = lineIndex
        return item
    }
}

// MARK: DTO cho ParsedTaxLine (Parser.swift)

struct ParsedTaxLineDTO: Codable, Equatable {
    var label: String
    var rateText: String?
    var amountCents: Int
    var lineIndex: Int?

    init(_ line: ParsedTaxLine) {
        label = line.label
        rateText = line.rateText
        amountCents = line.amountCents
        lineIndex = line.lineIndex
    }

    func toOriginal() -> ParsedTaxLine {
        var line = ParsedTaxLine(label: label, amountCents: amountCents)
        line.rateText = rateText
        line.lineIndex = lineIndex
        return line
    }
}

// MARK: DTO cho TotalCandidate (Parser.swift)

struct TotalCandidateDTO: Codable, Equatable {
    var lineIndex: Int
    var cents: Int
    var role: String
    var chosen: Bool

    init(_ candidate: TotalCandidate) {
        lineIndex = candidate.lineIndex
        cents = candidate.cents
        role = candidate.role
        chosen = candidate.chosen
    }

    func toOriginal() -> TotalCandidate {
        TotalCandidate(lineIndex: lineIndex, cents: cents, role: role, chosen: chosen)
    }
}

// MARK: DTO cho ParseResult (Parser.swift)
//
// Ánh xạ MỌI thuộc tính lưu trữ của ParseResult (thuộc tính tính
// toán taxTotalCents suy ra từ taxes nên không lưu). Bộ kiểm tại
// bàn checks/verify_dto_coverage.py đối chiếu danh sách trường
// này với mã nguồn thật để không trường nào bị rơi lặng lẽ.

struct ParseResultDTO: Codable, Equatable {
    var vendor: String?
    var vendorKey: String
    var date: Date?
    var items: [ParsedLineItemDTO]
    var subtotalCents: Int?
    var taxes: [ParsedTaxLineDTO]
    var totalCents: Int?
    var cardLast4: String?
    var cardBrand: String?
    var cardConfidence: Double
    var cardLineContaminated: Bool
    var dedupeKey: String?
    var itemsSold: Int?
    var warnings: [String]
    var vendorConfidence: Double
    var dateConfidence: Double
    var totalConfidence: Double
    var vendorAddress: String?
    var vendorPhone: String?
    var storeNumber: String?
    var vendorSource: String?
    var vendorSuggestion: String?
    var vendorAnchorDisputed: Bool
    var rawText: String
    var corrections: [DiagCorrection]
    var selectionTrace: [String]
    var totalCandidates: [TotalCandidateDTO]
    var totalsProvenance: [String: FieldProvenance]
    var itemsProvenance: [String: FieldProvenance]
    var arbiterStatus: String?
    var arbiterDisputed: [String]
    var arbiterDeficitE1: Int?
    var arbiterDeficitE2: Int?
    var arbiterRegionHint: String?
    var geometricCandidates: [ParsedLineItemDTO]
    var itemsSoldLabelSeen: Bool
    var soldContribution: String
    var vendorDataVersion: String

    init(_ result: ParseResult) {
        vendor = result.vendor
        vendorKey = result.vendorKey
        date = result.date
        items = result.items.map(ParsedLineItemDTO.init)
        subtotalCents = result.subtotalCents
        taxes = result.taxes.map(ParsedTaxLineDTO.init)
        totalCents = result.totalCents
        cardLast4 = result.cardLast4
        cardBrand = result.cardBrand
        cardConfidence = result.cardConfidence
        cardLineContaminated = result.cardLineContaminated
        dedupeKey = result.dedupeKey
        itemsSold = result.itemsSold
        warnings = result.warnings
        vendorConfidence = result.vendorConfidence
        dateConfidence = result.dateConfidence
        totalConfidence = result.totalConfidence
        vendorAddress = result.vendorAddress
        vendorPhone = result.vendorPhone
        storeNumber = result.storeNumber
        vendorSource = result.vendorSource
        vendorSuggestion = result.vendorSuggestion
        vendorAnchorDisputed = result.vendorAnchorDisputed
        rawText = result.rawText
        corrections = result.corrections
        selectionTrace = result.selectionTrace
        totalCandidates = result.totalCandidates.map(TotalCandidateDTO.init)
        totalsProvenance = result.totalsProvenance
        itemsProvenance = result.itemsProvenance
        arbiterStatus = result.arbiterStatus
        arbiterDisputed = result.arbiterDisputed
        arbiterDeficitE1 = result.arbiterDeficitE1
        arbiterDeficitE2 = result.arbiterDeficitE2
        arbiterRegionHint = result.arbiterRegionHint
        geometricCandidates = result.geometricCandidates.map(ParsedLineItemDTO.init)
        itemsSoldLabelSeen = result.itemsSoldLabelSeen
        soldContribution = result.soldContribution
        vendorDataVersion = result.vendorDataVersion
    }

    func toOriginal() -> ParseResult {
        var result = ParseResult()
        result.vendor = vendor
        result.vendorKey = vendorKey
        result.date = date
        result.items = items.map { $0.toOriginal() }
        result.subtotalCents = subtotalCents
        result.taxes = taxes.map { $0.toOriginal() }
        result.totalCents = totalCents
        result.cardLast4 = cardLast4
        result.cardBrand = cardBrand
        result.cardConfidence = cardConfidence
        result.cardLineContaminated = cardLineContaminated
        result.dedupeKey = dedupeKey
        result.itemsSold = itemsSold
        result.warnings = warnings
        result.vendorConfidence = vendorConfidence
        result.dateConfidence = dateConfidence
        result.totalConfidence = totalConfidence
        result.vendorAddress = vendorAddress
        result.vendorPhone = vendorPhone
        result.storeNumber = storeNumber
        result.vendorSource = vendorSource
        result.vendorSuggestion = vendorSuggestion
        result.vendorAnchorDisputed = vendorAnchorDisputed
        result.rawText = rawText
        result.corrections = corrections
        result.selectionTrace = selectionTrace
        result.totalCandidates = totalCandidates.map { $0.toOriginal() }
        result.totalsProvenance = totalsProvenance
        result.itemsProvenance = itemsProvenance
        result.arbiterStatus = arbiterStatus
        result.arbiterDisputed = arbiterDisputed
        result.arbiterDeficitE1 = arbiterDeficitE1
        result.arbiterDeficitE2 = arbiterDeficitE2
        result.arbiterRegionHint = arbiterRegionHint
        result.geometricCandidates = geometricCandidates.map { $0.toOriginal() }
        result.itemsSoldLabelSeen = itemsSoldLabelSeen
        result.soldContribution = soldContribution
        result.vendorDataVersion = vendorDataVersion
        return result
    }
}

// MARK: DTO cho ReconcileFix (Reconcile.swift)
//
// field/channel là enum rawValue String ở kiểu gốc — DTO lưu
// dạng chuỗi; ánh xạ ngược TRẢ NIL khi gặp mã lạ (bản chụp của
// phiên bản khác): thà coi snapshot là hỏng còn hơn dựng lại
// một sửa đối chiếu sai nghĩa (fix mang cờ ép duyệt của tờ).

struct ReconcileFixDTO: Codable, Equatable {
    var itemIndex: Int
    var fieldRaw: String
    var oldValue: Int?
    var newValue: Int
    var delta: Int
    var channelRaw: String
    var tier: Int
    var insertName: String?
    var insertQty: Int?
    var insertUnitCents: Int?
    var insertCode: String?
    var evidence: String?

    init(_ fix: ReconcileFix) {
        itemIndex = fix.itemIndex
        fieldRaw = fix.field.rawValue
        oldValue = fix.oldValue
        newValue = fix.newValue
        delta = fix.delta
        channelRaw = fix.channel.rawValue
        tier = fix.tier
        insertName = fix.insertName
        insertQty = fix.insertQty
        insertUnitCents = fix.insertUnitCents
        insertCode = fix.insertCode
        evidence = fix.evidence
    }

    func toOriginal() -> ReconcileFix? {
        guard let field = ReconcileFix.Field(rawValue: fieldRaw),
              let channel = ReconcileChannel(rawValue: channelRaw) else { return nil }
        var fix = ReconcileFix(itemIndex: itemIndex, field: field,
                               oldValue: oldValue, newValue: newValue,
                               delta: delta, channel: channel, tier: tier)
        fix.insertName = insertName
        fix.insertQty = insertQty
        fix.insertUnitCents = insertUnitCents
        fix.insertCode = insertCode
        fix.evidence = evidence
        return fix
    }
}

// MARK: DTO cho ReconcileRegionHint (Reconcile.swift)
//
// band là CGRect (không Codable) -> DiagRect, đúng tiền lệ của
// hồ sơ chẩn đoán v2. lineRange tách hai đầu mút.

struct ReconcileRegionHintDTO: Codable, Equatable {
    var blockRaw: String
    var reasonRaw: String
    var priority: Int
    var deltaCents: Int?
    var lineRangeLower: Int?
    var lineRangeUpper: Int?
    var band: DiagRect?

    init(_ hint: ReconcileRegionHint) {
        blockRaw = hint.block.rawValue
        reasonRaw = hint.reason.rawValue
        priority = hint.priority
        deltaCents = hint.deltaCents
        lineRangeLower = hint.lineRange?.lowerBound
        lineRangeUpper = hint.lineRange?.upperBound
        band = hint.band.map(DiagRect.init)
    }

    func toOriginal() -> ReconcileRegionHint? {
        guard let block = ReconcileRegionHint.Block(rawValue: blockRaw),
              let reason = ReconcileRegionHint.Reason(rawValue: reasonRaw) else { return nil }
        var range: ClosedRange<Int>? = nil
        if let lower = lineRangeLower, let upper = lineRangeUpper {
            guard lower <= upper else { return nil }
            range = lower...upper
        }
        var hint = ReconcileRegionHint(block: block, reason: reason)
        hint.priority = priority
        hint.deltaCents = deltaCents
        hint.lineRange = range
        hint.band = band?.cgRect
        return hint
    }
}

// MARK: DTO cho ReconcileReport (Reconcile.swift)

struct ReconcileReportDTO: Codable, Equatable {
    var statusRaw: String
    var moneyDeltaCents: Int?
    var qtyDelta: Int?
    var fixes: [ReconcileFixDTO]
    var suggestions: [[ReconcileFixDTO]]
    var solutionCount: Int
    var regionHints: [ReconcileRegionHintDTO]
    var notes: [String]
    var nodesVisited: Int
    var taxMissing: Bool
    var impliedTaxCents: Int?
    var anchorsPresent: [String]
    var anchorsMissing: [String]
    var requiresReview: Bool

    init(_ report: ReconcileReport) {
        statusRaw = report.status.rawValue
        moneyDeltaCents = report.moneyDeltaCents
        qtyDelta = report.qtyDelta
        fixes = report.fixes.map(ReconcileFixDTO.init)
        suggestions = report.suggestions.map { $0.map(ReconcileFixDTO.init) }
        solutionCount = report.solutionCount
        regionHints = report.regionHints.map(ReconcileRegionHintDTO.init)
        notes = report.notes
        nodesVisited = report.nodesVisited
        taxMissing = report.taxMissing
        impliedTaxCents = report.impliedTaxCents
        anchorsPresent = report.anchorsPresent
        anchorsMissing = report.anchorsMissing
        requiresReview = report.requiresReview
    }

    /// Ánh xạ ngược TOÀN-HAY-KHÔNG: một fix/hint lạ mã -> nil cả
    /// báo cáo (nơi gọi coi snapshot là hỏng), không dựng nửa vời.
    func toOriginal() -> ReconcileReport? {
        guard let status = ReconcileStatus(rawValue: statusRaw) else { return nil }
        var mappedFixes: [ReconcileFix] = []
        for dto in fixes {
            guard let fix = dto.toOriginal() else { return nil }
            mappedFixes.append(fix)
        }
        var mappedSuggestions: [[ReconcileFix]] = []
        for group in suggestions {
            var mappedGroup: [ReconcileFix] = []
            for dto in group {
                guard let fix = dto.toOriginal() else { return nil }
                mappedGroup.append(fix)
            }
            mappedSuggestions.append(mappedGroup)
        }
        var mappedHints: [ReconcileRegionHint] = []
        for dto in regionHints {
            guard let hint = dto.toOriginal() else { return nil }
            mappedHints.append(hint)
        }
        var report = ReconcileReport()
        report.status = status
        report.moneyDeltaCents = moneyDeltaCents
        report.qtyDelta = qtyDelta
        report.fixes = mappedFixes
        report.suggestions = mappedSuggestions
        report.solutionCount = solutionCount
        report.regionHints = mappedHints
        report.notes = notes
        report.nodesVisited = nodesVisited
        report.taxMissing = taxMissing
        report.impliedTaxCents = impliedTaxCents
        report.anchorsPresent = anchorsPresent
        report.anchorsMissing = anchorsMissing
        report.requiresReview = requiresReview
        return report
    }
}

// MARK: - Bản chụp nháp (snapshot) — một ô duy nhất

/// Toàn bộ trạng thái của MỘT bản nháp đang chờ Kiểm Lại, dạng
/// lưu được. Ô duy nhất theo đúng thực tế giao diện: ScanView
/// tại một thời điểm chỉ giữ một ScanDraft (sheet Kiểm Lại là
/// modal) — bản nháp mới ra đời ghi đè bản chụp cũ.
struct PendingDraftSnapshot: Codable, Equatable {
    // G3 (luật bền hoá trạng thái): v2 CỘNG THÊM lớp sửa dở ở
    // màn Kiểm Lại (reviewEdits, tuỳ chọn) — v1 không có trường
    // này vẫn nạp được (reviewEdits = nil), xem cổng schema ở
    // PendingDraftStore.load. Ngoài khoảng 1...2 vẫn coi là lạ.
    static let currentSchemaVersion = 2

    var schemaVersion: Int = PendingDraftSnapshot.currentSchemaVersion
    /// Thời điểm chụp (để chẩn đoán/log; không hiển thị cho anh).
    var createdAt: Date
    var result: ParseResultDTO
    var imageFileName: String
    /// SourceType.rawValue — ánh xạ về enum ở ScanView (nơi khai
    /// ScanDraft); mã lạ hạ về .unknown thay vì mất cả bản nháp,
    /// vì đây chỉ là nhãn nguồn nạp F3, không phải số tiền.
    var sourceTypeRaw: String
    var sourceFileName: String? = nil
    var originalFileNames: [String] = []
    var rawTextIsPDFTextLayer: Bool = false
    var provenance: [String: FieldProvenance] = [:]
    var reconcileReport: ReconcileReportDTO? = nil
    var diagnosticsID: String? = nil
    var diagnosticsWriteFailed: Bool = false
    /// G3: lớp SỬA DỞ ở màn Kiểm Lại phủ lên bản chụp gốc —
    /// nil khi anh chưa sửa gì (mọi bản chụp v1 và bản chụp
    /// lúc nháp ra đời). ReviewView ghi lại trường này mỗi khi
    /// anh sửa; khôi phục thì ReviewView dựng các ô từ lớp này
    /// thay vì từ kết quả đọc gốc. Cộng thêm thuần tuý: KHÔNG
    /// trường cũ nào đổi nghĩa.
    var reviewEdits: ReviewEditsDTO? = nil

    init(result: ParseResult,
         imageFileName: String,
         sourceTypeRaw: String,
         sourceFileName: String?,
         originalFileNames: [String],
         rawTextIsPDFTextLayer: Bool,
         provenance: [String: FieldProvenance],
         reconcileReport: ReconcileReport?,
         diagnosticsID: String?,
         diagnosticsWriteFailed: Bool,
         createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.result = ParseResultDTO(result)
        self.imageFileName = imageFileName
        self.sourceTypeRaw = sourceTypeRaw
        self.sourceFileName = sourceFileName
        self.originalFileNames = originalFileNames
        self.rawTextIsPDFTextLayer = rawTextIsPDFTextLayer
        self.provenance = provenance
        self.reconcileReport = reconcileReport.map(ReconcileReportDTO.init)
        self.diagnosticsID = diagnosticsID
        self.diagnosticsWriteFailed = diagnosticsWriteFailed
    }
}

// MARK: - Kho lưu bản chụp (Documents/PendingDraft.json)

enum PendingDraftStore {
    static let fileName = "PendingDraft.json"
    static let logFileName = "PendingDraft.log"

    /// Thư mục gốc của bản chụp: Documents của app (cùng nơi
    /// UIFileSharingEnabled phơi ra ở Files — anh/đội chẩn đoán
    /// nhìn thấy được). Ảnh gốc KHÔNG nằm ở đây: nó đã ở
    /// ReceiptImages qua ImageStore từ lúc nạp, bản chụp chỉ giữ
    /// TÊN file để Review dựng lại.
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Ghi bản chụp NGUYÊN TỬ: mã hoá -> ghi file tạm cùng thư
    /// mục -> đổi tên đè (replaceItemAt/moveItem). Trả false khi
    /// ghi hỏng để nơi gọi nói thật với anh; TUYỆT ĐỐI không ném
    /// lỗi ra ngoài — đường đọc chính không được chết vì đường phụ.
    @discardableResult
    static func save(_ snapshot: PendingDraftSnapshot,
                     in directory: URL = defaultDirectory) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return false }
        let target = fileURL(in: directory)
        let temp = directory.appendingPathComponent(fileName + ".tmp")
        do {
            try data.write(to: temp)
            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: target)
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: temp)
            return false
        }
    }

    /// Đọc bản chụp. Không có file -> nil (trường hợp thường).
    /// File hỏng / JSON không giải được / schema lạ -> XOÁ lặng +
    /// ghi log chẩn đoán rồi trả nil: app mở bình thường như
    /// không có nháp chờ, không crash, không kẹt ở màn lỗi.
    static func load(in directory: URL = defaultDirectory) -> PendingDraftSnapshot? {
        let target = fileURL(in: directory)
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        do {
            let data = try Data(contentsOf: target)
            let snapshot = try JSONDecoder().decode(PendingDraftSnapshot.self, from: data)
            // G3: chấp nhận cả v1 (chưa có reviewEdits — giải mã
            // ra nil) lẫn v2 hiện hành; ngoài khoảng này là bản
            // chụp của một thế hệ khác hẳn -> coi là hỏng như cũ.
            guard (1...PendingDraftSnapshot.currentSchemaVersion).contains(snapshot.schemaVersion) else {
                discardCorrupt(in: directory,
                               reason: "schemaVersion=\(snapshot.schemaVersion) không được hỗ trợ")
                return nil
            }
            return snapshot
        } catch {
            discardCorrupt(in: directory, reason: "không đọc được: \(error.localizedDescription)")
            return nil
        }
    }

    /// Xoá bản chụp (lưu thành công / huỷ tường minh / dọn bản
    /// hỏng). Không có file cũng không sao.
    static func clear(in directory: URL = defaultDirectory) {
        try? FileManager.default.removeItem(at: fileURL(in: directory))
    }

    /// Đường xoá dành cho bản chụp hỏng: xoá + để lại một dòng
    /// log chẩn đoán (PendingDraft.log cùng thư mục) để đội còn
    /// biết việc đã xảy ra thay vì mất dấu lặng lẽ.
    static func discardCorrupt(in directory: URL = defaultDirectory, reason: String) {
        clear(in: directory)
        appendLog("Snapshot nháp hỏng đã bị xoá: \(reason)", in: directory)
    }

    /// Ghi nối một dòng log chẩn đoán. Mọi lỗi ghi log đều nuốt:
    /// log là đường phụ của đường phụ, không được gây hậu quả.
    static func appendLog(_ message: String, in directory: URL = defaultDirectory) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = directory.appendingPathComponent(logFileName)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

// MARK: - G3: lớp sửa dở ở màn Kiểm Lại (ReviewEditsDTO)
//
// Sự cố gốc (TEAM3 mục 1.2): bản chụp P-DRAFT chỉ chụp MỘT lần
// lúc bản nháp ra đời; mọi sửa chữa của anh trong Kiểm Lại (tên
// tiệm, ngày, số tiền, loại, mục, mục đích) chỉ sống ở @State
// của ReviewView — khôi phục được bản nháp thì về trạng thái
// NGUYÊN VẸN lúc đọc, công sửa mất sạch. DTO này là lớp phủ
// sửa dở: ReviewView ghi nó vào CÙNG bản chụp nháp mỗi khi anh
// sửa (chốt theo sự kiện rời rạc + chống dội, xem ReviewView),
// khôi phục thì dựng các ô từ lớp phủ thay vì kết quả đọc gốc.
//
// Các trường giữ ĐÚNG DẠNG Ô NHẬP (chuỗi tiền chưa đổi đơn vị,
// ngày dạng Date) để khôi phục là dựng lại y hệt những gì anh
// đang nhìn — không qua đổi đơn vị hai chiều nào có thể lệch
// xu. kindRaw là Classification.rawValue dạng chuỗi; mã lạ ở
// tầng dựng (ReviewView) hạ về gợi ý mặc định như sourceType
// của P-DRAFT, không đáng đánh đổi cả bản nháp vì một nhãn.

struct ReviewEditsDTO: Codable, Equatable {
    var vendorText: String
    var dateValue: Date
    var subtotalText: String
    var taxText: String
    var totalText: String
    /// Classification.rawValue ("personal"/"business"/"unknown").
    var kindRaw: String
    var category: String
    var purposeText: String
    var reasonText: String
    /// Đã áp gợi ý phân loại một lần hay chưa — khôi phục phải
    /// giữ true để applySuggestionOnce KHÔNG chạy lại và ghi
    /// đè lựa chọn anh đã sửa (kiểm trùng vẫn chạy ở attemptSave).
    var suggestionApplied: Bool
    /// PHA 2: mốc hạ cánh gần nhất theo trường tiền + loại hàng
    /// đã áp tại lúc chụp. Khôi phục phải giữ đúng mốc này —
    /// thiếu nó, reland sau khôi phục sẽ coi ước tính đã tính
    /// lại là số gõ tay và làm rơi nhãn "ước tính". Optional:
    /// bản chụp cũ (chưa có hai trường này) vẫn giải mã được.
    var landingTexts: [String: String]? = nil
    var landingAppliedCategoryRaw: String? = nil
    /// PHA 2: hai chuỗi CHÚ THÍCH hạ cánh (chi tiết phép suy +
    /// dòng khu vực/suất) tại lúc chụp — khôi phục phải hiện lại
    /// đúng chú thích của loại đã tính lại, không phải chú thích
    /// gốc của lần đọc (số đã theo loại mới mà chú thích còn loại
    /// cũ là ghi nhãn sai). Optional như hai trường trên.
    var landingDetail: String? = nil
    var landingAreaText: String? = nil
}

// MARK: - G3: DTO cho QualityOutcome (CaptureIntake.swift)
//
// QualityOutcome không phải Codable (nó là kết quả sống của
// cổng) — DTO lưu 4 trường nguyên thuỷ (+ cờ leo thang
// Optional từ G4, xem QualityOutcomeDTO.escalated); decision
// qua rawValue
// và ánh xạ ngược TRẢ NIL khi gặp mã lạ, đúng kỷ luật
// toàn-hay-không của ReconcileReportDTO: quyết định chặn là
// QUYẾT ĐỊNH CHƯA THI HÀNH, dựng sai nghĩa còn tệ hơn mất.

struct QualityOutcomeDTO: Codable, Equatable {
    var detected: [String]
    var decisionRaw: String
    var failSafe: Bool
    var consecutiveRejects: Int
    /// G4: cờ leo thang cảnh báo — Optional CÓ CHỦ ĐÍCH: bản
    /// chụp do bản TRƯỚC G4 ghi không có khoá này -> giải mã
    /// ra nil -> toOriginal hiểu là false; bản TRƯỚC G4 đọc
    /// bản chụp MỚI thì khoá lạ bị Codable bỏ qua. Tương thích
    /// hai chiều, schema của PendingBlockSnapshot giữ nguyên 1.
    var escalated: Bool? = nil

    init(_ outcome: QualityOutcome) {
        detected = outcome.detected
        decisionRaw = outcome.decision.rawValue
        failSafe = outcome.failSafe
        consecutiveRejects = outcome.consecutiveRejects
        escalated = outcome.escalated
    }

    func toOriginal() -> QualityOutcome? {
        guard let decision = QualityDecision(rawValue: decisionRaw) else { return nil }
        return QualityOutcome(detected: detected, decision: decision,
                              failSafe: failSafe,
                              consecutiveRejects: consecutiveRejects,
                              escalated: escalated ?? false)
    }
}

// MARK: - G3: bản chụp tờ BỊ CỔNG CHẤT LƯỢNG CHẶN (PendingBlock)
//
// Sự cố gốc (2026-11-15, O-V44-1 thành thiệt hại thật): tờ bị
// cổng phán .block chỉ sống ở @State của ScanView (blockedDraft
// / blockedQuality) và runRead CỐ Ý không chụp snapshot — anh
// thoát app trước khi bấm "Vẫn đọc tờ này" là tờ biến mất khỏi
// giao diện, không đường khôi phục (ảnh gốc + chẩn đoán còn
// trên đĩa nhưng không màn hình nào trỏ tới). Theo luật bền
// hoá G3, quyết định chặn phải XUỐNG ĐĨA NGAY KHI RA ĐỜI:
// ScanView chụp bản này cùng khoảnh khắc dựng trạng thái chặn,
// và dựng lại đúng khung chặn ở lần mở app sau cho tới khi anh
// quyết một trong hai nút (cả hai nút đều xoá bản chụp).
//
// Bản chụp GỒM bản chụp nháp đầy đủ (PendingDraftSnapshot —
// dùng lại toàn bộ DTO đã kiểm ở G1) + kết quả cổng. Ô duy
// nhất như P-DRAFT: giao diện tại một thời điểm chỉ giữ một
// tờ bị chặn (mọi đường đọc mới đều bị canh bởi blockedDraft).

struct PendingBlockSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = PendingBlockSnapshot.currentSchemaVersion
    var createdAt: Date
    var draft: PendingDraftSnapshot
    var quality: QualityOutcomeDTO

    init(draftSnapshot: PendingDraftSnapshot,
         quality: QualityOutcome,
         createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.draft = draftSnapshot
        self.quality = QualityOutcomeDTO(quality)
    }

    /// Kết quả cổng dựng lại từ DTO — nil khi mã quyết định lạ
    /// (bản chụp của phiên bản khác): nơi gọi coi bản chụp là
    /// hỏng. Tách thuần ở tầng này để harness kiểm được mà
    /// không cần tầng UI (makeBlocked ở ScanView chỉ cộng thêm
    /// bước dựng ScanDraft từ draft.makeDraft()).
    func qualityOutcome() -> QualityOutcome? {
        quality.toOriginal()
    }
}

// MARK: - Kho lưu bản chụp bị chặn (Documents/PendingBlock.json)
//
// Cùng mẫu PendingDraftStore: ghi nguyên tử temp -> đổi tên,
// hỏng/lạ -> xoá lặng + một dòng log (PendingBlock.log), không
// bao giờ ném lỗi ra đường chính.

enum PendingBlockStore {
    static let fileName = "PendingBlock.json"
    static let logFileName = "PendingBlock.log"

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    @discardableResult
    static func save(_ snapshot: PendingBlockSnapshot,
                     in directory: URL = defaultDirectory) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return false }
        let target = fileURL(in: directory)
        let temp = directory.appendingPathComponent(fileName + ".tmp")
        do {
            try data.write(to: temp)
            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: target)
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: temp)
            return false
        }
    }

    static func load(in directory: URL = defaultDirectory) -> PendingBlockSnapshot? {
        let target = fileURL(in: directory)
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        do {
            let data = try Data(contentsOf: target)
            let snapshot = try JSONDecoder().decode(PendingBlockSnapshot.self, from: data)
            guard snapshot.schemaVersion == PendingBlockSnapshot.currentSchemaVersion else {
                discardCorrupt(in: directory,
                               reason: "schemaVersion=\(snapshot.schemaVersion) không được hỗ trợ")
                return nil
            }
            return snapshot
        } catch {
            discardCorrupt(in: directory, reason: "không đọc được: \(error.localizedDescription)")
            return nil
        }
    }

    static func clear(in directory: URL = defaultDirectory) {
        try? FileManager.default.removeItem(at: fileURL(in: directory))
    }

    static func discardCorrupt(in directory: URL = defaultDirectory, reason: String) {
        clear(in: directory)
        appendLog("Snapshot bị chặn hỏng đã bị xoá: \(reason)", in: directory)
    }

    static func appendLog(_ message: String, in directory: URL = defaultDirectory) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = directory.appendingPathComponent(logFileName)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

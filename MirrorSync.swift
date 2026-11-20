import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import CryptoKit

// MARK: - P2-1: Lớp gương thư mục Files (PHASE2-PLAN §2.2 / AMD-002)
//
// Bố cục theo §2.1 — dùng chung cho gương Files (gói này) và
// Drive sync (P2-2 sau này):
//   <thư mục anh chọn>/GL-Keeper/
//     manifest.json            (mục lục: id, hash, trạng thái)
//     receipts/<id>/receipt.json + original-1.jpg|pdf …
//     _deleted/<id>/…          (xoá = CHUYỂN vào đây, không biến mất)
//
// Kỷ luật cứng của lớp này:
// - Kho SwiftData trên máy là GỐC; gương là lớp PHỤ — mọi lỗi
//   gương chỉ được GHI NHẬN vào trạng thái (hiện ở Thẻ & Cài
//   Đặt), không bao giờ chặn hay làm hỏng luồng lưu hoá đơn.
// - KHÔNG đổi model SwiftData: cài đặt + bookmark + trạng thái
//   nằm ở UserDefaults; danh tính thư mục của tờ = stableID đã
//   có sẵn (tờ đời cũ chưa có stableID thì suy id xác định từ
//   trường bất biến — xem MirrorReceiptSnapshot.folderID).
// - Lượt gương là ĐỐI CHIẾU TOÀN KHO theo manifest: tờ có mặt
//   thì ghi/cập nhật, tờ từng có trong manifest mà nay biến mất
//   khỏi kho thì chuyển thư mục sang _deleted/. Nhờ vậy việc
//   xoá được nhận diện ở MỌI đường xoá, không lệ thuộc từng
//   điểm hook; thư mục lạ không thuộc manifest thì KHÔNG đụng.
// - JSON chỉ qua Codable + cặp encoder/decoder an toàn (luật
//   L-2026-11-16-24): snapshot chứa Double (độ tin cậy) nên
//   encoder gắn .convertToString — cấm JSONSerialization.

// MARK: DTO receipt.json

struct MirrorItemSnapshot: Codable {
    var name: String
    var qty: Int
    var unitPriceCents: Int?
    var amountCents: Int?
    var taxFlag: String?
    var itemCode: String?
    var sortIndex: Int
    var classificationRaw: String
    var category: String
    var scheduleCLine: String?
}

struct MirrorTaxLineSnapshot: Codable {
    var label: String
    var rateText: String?
    var amountCents: Int
    var sortIndex: Int
}

/// Một file bằng chứng trong thư mục gương của tờ: tên file
/// gương (original-N.<đuôi>) + tên file nguồn trong kho máy +
/// số byte thật lúc gương (nil + missing khi file nguồn đã mất
/// trên máy — ghi nhận trung thực, không bịa).
struct MirrorOriginalRef: Codable {
    var mirrorFileName: String
    var sourceFileName: String
    var byteCount: Int?
    var missing: Bool
}

/// Toàn bộ trường của một hoá đơn cho receipt.json (PHASE2-PLAN
/// §2.3: "toàn bộ trường đã duyệt + độ tin cậy"). Thuần giá trị
/// (Sendable theo từng trường) — dựng trên main actor từ bản ghi
/// SwiftData rồi giao cho tác vụ nền ghi đĩa.
struct MirrorReceiptSnapshot: Codable {
    var folderID: String
    var stableID: String
    var vendor: String
    var date: Date
    var createdAt: Date
    var subtotalCents: Int?
    /// taxCents chân tương thích Build 1 + taxTotalCents (C4:
    /// Σ taxLines khi có, không thì taxCents) — ghi cả hai để
    /// khôi phục về sau không phải suy lại luật ưu tiên.
    var taxCents: Int?
    var taxTotalCents: Int?
    var totalCents: Int?
    var totalPrintedCents: Int?
    var tipAmountCents: Int?
    var amountPaidCents: Int?
    var cardLast4: String?
    var cardBrand: String?
    var paymentMethodRaw: String
    var classificationRaw: String
    var classificationReason: String
    var category: String
    var scheduleCLine: String?
    var businessPurpose: String
    var mealsAttendees: String
    var capitalizationFlagRaw: String
    var taxYear: Int
    var taxYearOverride: Int?
    var vendorAddress: String
    var vendorPhone: String?
    var storeNumber: String?
    var transactionRef: String?
    var authCode: String?
    var dedupeKey: String?
    var duplicateOfStableID: String?
    var excludedFromTotals: Bool
    var confirmedWithFlag: Bool
    var isReturn: Bool
    var statusRaw: String
    var reviewedAt: Date?
    var userEnteredFieldNames: [String]
    var parserVersion: String
    var vendorConfidence: Double
    var dateConfidence: Double
    var totalConfidence: Double
    var sourceTypeRaw: String
    var sourceFileName: String?
    var rawTextFromPDFTextLayer: Bool
    var retentionUntil: Date?
    var ocrRawText: String
    var imageFileName: String
    /// Mọi ảnh gốc theo đúng thứ tự bằng chứng (helper
    /// allOriginalImageFileNames của model) — writer suy tên
    /// file gương original-N từ vị trí trong danh sách này.
    var sourceOriginalFileNames: [String]
    var enhancedImageFileName: String?
    var items: [MirrorItemSnapshot]
    var taxLines: [MirrorTaxLineSnapshot]

    /// Danh tính thư mục: stableID khi đã có. Tờ đời cũ
    /// (pre-WP2) stableID rỗng -> id suy XÁC ĐỊNH từ các trường
    /// gần như bất biến của chính tờ (mốc tạo + tiệm + tổng +
    /// tên ảnh chính lúc gương lần đầu). Nếu các trường đó bị
    /// sửa về sau, thư mục cũ thành thư mục mồ côi — lượt gương
    /// KHÔNG tự xoá thư mục lạ (luật an toàn ở đầu file), chỉ
    /// thư mục mới được tạo thêm; ghi nhận rõ giới hạn này ở
    /// P2-1-DIFF.md.
    static func folderID(for receipt: Receipt) -> String {
        if !receipt.stableID.isEmpty { return receipt.stableID }
        let seed = "\(receipt.createdAt.timeIntervalSince1970)"
            + "|\(receipt.vendor)|\(receipt.totalCents ?? -1)"
            + "|\(receipt.imageFileName)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "pre2-" + String(hex.prefix(16))
    }

    static func make(from receipt: Receipt) -> MirrorReceiptSnapshot {
        MirrorReceiptSnapshot(
            folderID: folderID(for: receipt),
            stableID: receipt.stableID,
            vendor: receipt.vendor,
            date: receipt.date,
            createdAt: receipt.createdAt,
            subtotalCents: receipt.subtotalCents,
            taxCents: receipt.taxCents,
            taxTotalCents: receipt.taxTotalCents,
            totalCents: receipt.totalCents,
            totalPrintedCents: receipt.totalPrintedCents,
            tipAmountCents: receipt.tipAmountCents,
            amountPaidCents: receipt.amountPaidCents,
            cardLast4: receipt.cardLast4,
            cardBrand: receipt.cardBrand,
            paymentMethodRaw: receipt.paymentMethodRaw,
            classificationRaw: receipt.classificationRaw,
            classificationReason: receipt.classificationReason,
            category: receipt.category,
            scheduleCLine: receipt.scheduleCLine,
            businessPurpose: receipt.businessPurpose,
            mealsAttendees: receipt.mealsAttendees,
            capitalizationFlagRaw: receipt.capitalizationFlagRaw,
            taxYear: receipt.taxYear,
            taxYearOverride: receipt.taxYearOverride,
            vendorAddress: receipt.vendorAddress,
            vendorPhone: receipt.vendorPhone,
            storeNumber: receipt.storeNumber,
            transactionRef: receipt.transactionRef,
            authCode: receipt.authCode,
            dedupeKey: receipt.dedupeKey,
            duplicateOfStableID: receipt.duplicateOfStableID,
            excludedFromTotals: receipt.excludedFromTotals,
            confirmedWithFlag: receipt.confirmedWithFlag,
            isReturn: receipt.isReturn,
            statusRaw: receipt.statusRaw,
            reviewedAt: receipt.reviewedAt,
            userEnteredFieldNames: receipt.userEnteredFieldNames,
            parserVersion: receipt.parserVersion,
            vendorConfidence: receipt.vendorConfidence,
            dateConfidence: receipt.dateConfidence,
            totalConfidence: receipt.totalConfidence,
            sourceTypeRaw: receipt.sourceTypeRaw,
            sourceFileName: receipt.sourceFileName,
            rawTextFromPDFTextLayer: receipt.rawTextFromPDFTextLayer,
            retentionUntil: receipt.retentionUntil,
            ocrRawText: receipt.ocrRawText,
            imageFileName: receipt.imageFileName,
            sourceOriginalFileNames: receipt.allOriginalImageFileNames,
            enhancedImageFileName: receipt.enhancedImageFileName,
            items: receipt.items
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { item in
                    MirrorItemSnapshot(
                        name: item.name, qty: item.qty,
                        unitPriceCents: item.unitPriceCents,
                        amountCents: item.amountCents,
                        taxFlag: item.taxFlag, itemCode: item.itemCode,
                        sortIndex: item.sortIndex,
                        classificationRaw: item.classificationRaw,
                        category: item.category,
                        scheduleCLine: item.scheduleCLine)
                },
            taxLines: receipt.taxLines
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { line in
                    MirrorTaxLineSnapshot(
                        label: line.label, rateText: line.rateText,
                        amountCents: line.amountCents,
                        sortIndex: line.sortIndex)
                })
    }

    /// Hash nội dung (SHA-256 của JSON mã hoá xác định) — lượt
    /// gương so hash này với manifest để bỏ qua tờ không đổi.
    /// mirroredAt KHÔNG nằm trong snapshot nên hash ổn định
    /// giữa các lượt khi tờ không đổi thật.
    func contentHash() -> String {
        guard let data = try? MirrorJSON.encoder().encode(self)
        else { return "" }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }.joined()
    }
}

/// Phong bì receipt.json trên đĩa: snapshot + mốc gương + danh
/// sách file bằng chứng đã sao (số byte đo thật ở lượt ghi).
struct MirrorReceiptFile: Codable {
    var formatVersion: Int
    var mirroredAt: Date
    var receipt: MirrorReceiptSnapshot
    var originals: [MirrorOriginalRef]
    var enhanced: MirrorOriginalRef?
}

// MARK: Manifest (mục lục ở gốc thư mục gương)

struct MirrorManifestEntry: Codable {
    var id: String
    var stableID: String
    var vendor: String
    var date: Date
    var totalCents: Int?
    var contentHash: String
    var updatedAt: Date
    /// "active" | "deleted" — xoá là trạng thái có dấu vết,
    /// không phải biến mất khỏi mục lục (§2.1).
    var status: String
    var deletedAt: Date?
}

struct MirrorManifest: Codable {
    var formatVersion: Int = 1
    var updatedAt: Date
    var entries: [MirrorManifestEntry]
}

// MARK: JSON an toàn (luật L-2026-11-16-24)

enum MirrorJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+inf", negativeInfinity: "-inf",
            nan: "nan")
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "+inf", negativeInfinity: "-inf",
            nan: "nan")
        return decoder
    }
}

// MARK: Cài đặt + trạng thái gương (UserDefaults — không đổi model)

enum MirrorSettings {
    private static let enabledKey = "glkeeper.mirror.enabled"
    private static let bookmarkKey = "glkeeper.mirror.bookmarkData"
    private static let folderNameKey = "glkeeper.mirror.folderName"
    private static let lastRunKey = "glkeeper.mirror.lastRunAt"
    private static let lastSummaryKey = "glkeeper.mirror.lastSummary"
    private static let lastErrorKey = "glkeeper.mirror.lastError"
    private static let lastErrorAtKey = "glkeeper.mirror.lastErrorAt"
    private static let lastPickerOutcomeKey = "glkeeper.mirror.lastPickerOutcome"
    private static let lastPickerAtKey = "glkeeper.mirror.lastPickerAt"
    private static let lastPickerFolderKey = "glkeeper.mirror.lastPickerFolder"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var bookmarkData: Data? {
        get { UserDefaults.standard.data(forKey: bookmarkKey) }
        set { UserDefaults.standard.set(newValue, forKey: bookmarkKey) }
    }

    static var folderDisplayName: String? {
        get { UserDefaults.standard.string(forKey: folderNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: folderNameKey) }
    }

    /// Lần gương gần nhất CHẠY XONG một lượt (kể cả lượt có
    /// tờ lỗi lẻ — lỗi lẻ nằm ở lastError, xem recordPass).
    static var lastRunAt: Date? {
        get { UserDefaults.standard.object(forKey: lastRunKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastRunKey) }
    }

    static var lastSummary: String? {
        get { UserDefaults.standard.string(forKey: lastSummaryKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSummaryKey) }
    }

    static var lastError: String? {
        get { UserDefaults.standard.string(forKey: lastErrorKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastErrorKey) }
    }

    static var lastErrorAt: Date? {
        get { UserDefaults.standard.object(forKey: lastErrorAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastErrorAtKey) }
    }

    /// Loại kết quả một lần mở bộ chọn thư mục (Gói 1 — điểm
    /// yếu 2.6 trong bản đánh giá): picked = anh chọn được
    /// thư mục; cancelled = anh tự đóng bộ chọn; noResponse
    /// = lệnh trình bị nuốt, bộ chọn không hề hiện.
    enum PickerOutcome: String {
        case picked
        case cancelled
        case noResponse
    }

    /// Kết quả lần mở bộ chọn thư mục gần nhất (lưu bằng mã
    /// máy; UI dịch sang tiếng Việt khi hiển thị).
    static var lastPickerOutcome: PickerOutcome? {
        get {
            UserDefaults.standard.string(forKey: lastPickerOutcomeKey)
                .flatMap { PickerOutcome(rawValue: $0) }
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue,
                                      forKey: lastPickerOutcomeKey)
        }
    }

    static var lastPickerAt: Date? {
        get { UserDefaults.standard.object(forKey: lastPickerAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastPickerAtKey) }
    }

    /// Tên thư mục của lần chọn thành công gần nhất (chỉ có
    /// nghĩa khi lastPickerOutcome == .picked).
    static var lastPickerFolderName: String? {
        get { UserDefaults.standard.string(forKey: lastPickerFolderKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastPickerFolderKey) }
    }

    /// Đã nối = có bookmark thư mục. Mất quyền truy cập được
    /// phát hiện ở lượt gương (bookmark không giải được) và
    /// nằm ở lastError — UI đọc cả hai để nói trạng thái thật.
    static var isConnected: Bool { bookmarkData != nil }

    /// Phát thông báo đổi trạng thái TRÊN MAIN QUEUE.
    /// recordPass/recordFailure được gọi từ hàng đợi nền của
    /// lượt gương, còn phía nhận (CardsView.onReceive) sửa
    /// @State — sửa state ngoài main thread là hành vi không
    /// xác định (kiểm duyệt P2-1 vòng 1, lỗi L1). Mọi điểm
    /// phát đi qua đây cho nhất quán; adoptFolder gọi từ giao
    /// diện (đang ở main) thì chỉ lùi sang nhịp runloop kế.
    private static func postStatusChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: MirrorSync.statusChangedNotification, object: nil)
        }
    }

    /// Nhận thư mục anh vừa chọn: tạo security-scoped bookmark
    /// trong lúc quyền truy cập của picker còn hiệu lực, lưu
    /// bền + bật gương. Tạo bookmark hỏng -> ghi lỗi thật,
    /// KHÔNG giả vờ đã nối (luật B-2).
    static func adoptFolder(_ url: URL) {
        // LOGKIT (L-2026-11-19-39): chỉ cộng lời gọi log —
        // logic nhận thư mục giữ nguyên từng chữ.
        DiagLog.log(.mirror,
                    "adoptFolder bắt đầu: \(url.lastPathComponent)")
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try url.bookmarkData(
                options: [], includingResourceValuesForKeys: nil,
                relativeTo: nil)
            bookmarkData = data
            folderDisplayName = url.lastPathComponent
            isEnabled = true
            lastError = nil
            lastErrorAt = nil
            DiagLog.log(.mirror,
                        "adoptFolder: tạo bookmark THÀNH CÔNG cho \(url.lastPathComponent)")
        } catch {
            let nsError = error as NSError
            DiagLog.log(.mirror,
                        "adoptFolder: tạo bookmark THẤT BẠI — \(nsError.domain) code=\(nsError.code)")
            lastError = "Không lưu được quyền truy cập thư mục đã chọn — anh thử chọn lại giúp."
            lastErrorAt = Date()
        }
        postStatusChanged()
    }

    /// Ghi kết quả một lượt gương chạy xong: mốc + tóm tắt;
    /// error != nil khi có tờ lỗi lẻ hoặc ảnh gốc thiếu (lượt
    /// vẫn tính là đã chạy — lượt sau tự bù).
    static func recordPass(summary: String, error: String?) {
        lastRunAt = Date()
        lastSummary = summary
        lastError = error
        lastErrorAt = error == nil ? nil : Date()
        postStatusChanged()
    }

    /// Ghi lỗi CẤP LƯỢT (không vào được thư mục / không ghi
    /// được manifest): lượt coi như chưa chạy — lastRunAt giữ
    /// nguyên mốc thành công gần nhất để UI nói thật.
    static func recordFailure(_ message: String) {
        lastError = message
        lastErrorAt = Date()
        postStatusChanged()
    }

    /// Ghi kết quả một lần mở bộ chọn thư mục — gọi từ MỌI
    /// lối thoát của MirrorFolderPickerPresenter (chọn xong /
    /// anh tự huỷ / trình bị nuốt) để mỗi lần mở đều để lại
    /// dấu vết quan sát được (điểm yếu 2.6: trước đây một lần
    /// mở kết thúc ra sao không ai biết — ca L-36 phải chẩn
    /// đoán qua video quay màn hình). Ghi xong phát thông
    /// báo đổi trạng thái theo cùng mẫu các hàm record*.
    static func recordPickerOutcome(_ outcome: PickerOutcome,
                                    folderName: String?) {
        lastPickerOutcome = outcome
        lastPickerAt = Date()
        lastPickerFolderName = folderName
        postStatusChanged()
    }
}

// MARK: Điểm kích hoạt gương

enum MirrorSync {
    static let statusChangedNotification =
        Notification.Name("glkeeper.mirror.statusChanged")

    /// Hàng đợi SERIAL của riêng lớp gương: các lượt gương
    /// không bao giờ chạy chồng nhau (hai kích hoạt gần nhau —
    /// vừa lưu xong app lại về foreground — xếp hàng lần lượt;
    /// lượt sau đối chiếu lại từ manifest mới nhất nên không
    /// giẫm kết quả của lượt trước).
    private static let passQueue = DispatchQueue(
        label: "glkeeper.mirror.pass", qos: .utility)

    /// Điểm kích hoạt DUY NHẤT — gọi sau mỗi lần lưu / sửa /
    /// duyệt / xoá hoá đơn thành công, khi mở app và khi app
    /// quay lại foreground (bắt kịp). Chưa bật gương hoặc chưa
    /// chọn thư mục -> thoát ngay, không ghi lỗi (chưa nối
    /// không phải lỗi). Đọc sổ lỗi ở bước này cũng nuốt im:
    /// gương là lớp phụ, lượt mở app sau tự bù.
    static func requestSync(using context: ModelContext) {
        guard MirrorSettings.isEnabled,
              let bookmark = MirrorSettings.bookmarkData else { return }
        let receipts: [Receipt]
        do {
            receipts = try context.fetch(FetchDescriptor<Receipt>())
        } catch {
            return
        }
        let snapshots = receipts.map { MirrorReceiptSnapshot.make(from: $0) }
        let imageDirectory = ImageStore.directory
        passQueue.async {
            MirrorWriter.runPass(snapshots: snapshots,
                                 bookmarkData: bookmark,
                                 imageDirectory: imageDirectory)
        }
    }
}

// MARK: Engine ghi gương (chạy nền, thuần file)

enum MirrorWriter {
    /// Một lượt gương trọn vẹn trong MỘT phiên mở quyền
    /// security-scope. Mọi lỗi cấp lượt -> MirrorSettings
    /// .recordFailure; lỗi lẻ từng tờ được gom vào tóm tắt.
    static func runPass(snapshots: [MirrorReceiptSnapshot],
                        bookmarkData: Data,
                        imageDirectory: URL) {
        // LOGKIT (L-2026-11-19-39): chỉ cộng lời gọi log —
        // logic lượt gương giữ nguyên từng chữ.
        DiagLog.log(.mirror,
                    "runPass bắt đầu: \(snapshots.count) hoá đơn")
        var isStale = false
        let folderURL: URL
        do {
            folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI], relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            DiagLog.log(.mirror,
                        "runPass: resolve bookmark OK (stale: \(isStale))")
        } catch {
            let nsError = error as NSError
            DiagLog.log(.mirror,
                        "runPass: resolve bookmark THẤT BẠI — \(nsError.domain) code=\(nsError.code)")
            MirrorSettings.recordFailure(
                "Mất quyền truy cập thư mục gương — anh chọn lại thư mục trong Thẻ & Cài Đặt giúp.")
            return
        }
        let scoped = folderURL.startAccessingSecurityScopedResource()
        defer { if scoped { folderURL.stopAccessingSecurityScopedResource() } }
        // Bookmark cũ (thư mục đã dời/đổi tên): làm mới ngay
        // khi còn đang giữ quyền, để các lượt sau không lệ
        // thuộc đường cũ.
        if isStale,
           let fresh = try? folderURL.bookmarkData(
               options: [], includingResourceValuesForKeys: nil,
               relativeTo: nil) {
            MirrorSettings.bookmarkData = fresh
            MirrorSettings.folderDisplayName = folderURL.lastPathComponent
            DiagLog.log(.mirror,
                        "runPass: bookmark stale — đã làm mới")
        }
        do {
            let outcome = try performPass(root: folderURL,
                                          snapshots: snapshots,
                                          imageDirectory: imageDirectory)
            DiagLog.log(.mirror,
                        "runPass kết thúc: \(outcome.summary)")
            if let passError = outcome.error {
                DiagLog.log(.mirror,
                            "runPass lỗi lẻ: \(passError)")
            }
            MirrorSettings.recordPass(summary: outcome.summary,
                                      error: outcome.error)
        } catch {
            let nsError = error as NSError
            DiagLog.log(.mirror,
                        "runPass THẤT BẠI cấp lượt — \(nsError.domain) code=\(nsError.code)")
            MirrorSettings.recordFailure(
                "Gương chưa chạy được: \(error.localizedDescription) — lượt sau app sẽ tự thử lại.")
        }
    }

    private struct PassOutcome {
        var summary: String
        var error: String?
    }

    private static func performPass(
        root: URL,
        snapshots: [MirrorReceiptSnapshot],
        imageDirectory: URL
    ) throws -> PassOutcome {
        let fm = FileManager.default
        let base = root.appendingPathComponent("GL-Keeper", isDirectory: true)
        let receiptsDir = base.appendingPathComponent("receipts", isDirectory: true)
        let deletedDir = base.appendingPathComponent("_deleted", isDirectory: true)
        try fm.createDirectory(at: receiptsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: deletedDir, withIntermediateDirectories: true)

        // Thư mục trên iCloud Drive có thể đang ở trạng thái
        // bị trục xuất (placeholder): xin tải về trước khi đọc
        // manifest — best-effort, lỗi thì lượt này đọc như
        // manifest trống (hướng an toàn: không phát hiện xoá
        // nhầm, lượt sau bù).
        _ = try? fm.startDownloadingUbiquitousItem(
            at: base.appendingPathComponent("manifest.json"))

        var manifest = loadManifest(base: base)
            ?? MirrorManifest(updatedAt: Date(), entries: [])
        var byID: [String: MirrorManifestEntry] = [:]
        for entry in manifest.entries { byID[entry.id] = entry }
        let currentIDs = Set(snapshots.map { $0.folderID })

        var writtenCount = 0
        var failedReceipts = 0
        var missingOriginals = 0

        // --- 1) Mọi tờ đang có trong kho ---
        for snapshot in snapshots {
            // Hash tính MỘT lần mỗi lượt cho mỗi tờ (kiểm
            // duyệt vòng 1, N2): mirrorOne dùng để so "không
            // đổi", entry manifest dùng lại nguyên giá trị đó
            // — trước đây mỗi nơi tự mã hoá lại một lần.
            let hash = snapshot.contentHash()
            do {
                let result = try mirrorOne(
                    snapshot: snapshot, fm: fm,
                    receiptsDir: receiptsDir, deletedDir: deletedDir,
                    imageDirectory: imageDirectory,
                    previous: byID[snapshot.folderID],
                    contentHash: hash)
                missingOriginals += result.missingOriginals
                if result.wroteJSON { writtenCount += 1 }
                byID[snapshot.folderID] = MirrorManifestEntry(
                    id: snapshot.folderID, stableID: snapshot.stableID,
                    vendor: snapshot.vendor, date: snapshot.date,
                    totalCents: snapshot.totalCents,
                    contentHash: hash,
                    updatedAt: Date(), status: "active", deletedAt: nil)
            } catch {
                // Lỗi lẻ một tờ: ghi nhận và đi tiếp — một tờ
                // hỏng không được giết cả lượt gương.
                // LOGKIT: cộng dòng log domain+code của lỗi lẻ.
                let nsError = error as NSError
                DiagLog.log(.mirror,
                            "gương tờ \(snapshot.folderID) lỗi — \(nsError.domain) code=\(nsError.code)")
                failedReceipts += 1
            }
        }

        // --- 2) Tờ từng gương mà nay biến mất khỏi kho -> _deleted ---
        // Chốt danh sách id TRƯỚC (không vừa duyệt vừa ghi vào
        // cùng một dictionary — hành vi không xác định).
        var movedToDeleted = 0
        var failedDeletes = 0
        let vanishedIDs = byID.values
            .filter { $0.status == "active" && !currentIDs.contains($0.id) }
            .map { $0.id }
        for id in vanishedIDs {
            guard let entry = byID[id] else { continue }
            let source = receiptsDir.appendingPathComponent(id, isDirectory: true)
            let target = deletedDir.appendingPathComponent(id, isDirectory: true)
            if fm.fileExists(atPath: source.path) {
                // Cùng id từng bị xoá rồi sống lại rồi xoá nữa:
                // bản _deleted cũ của CHÍNH tờ này được thay
                // bằng bản mới nhất (không phải dọn thư mục lạ).
                if fm.fileExists(atPath: target.path) {
                    try? fm.removeItem(at: target)
                }
                do {
                    try fm.moveItem(at: source, to: target)
                } catch {
                    // Lỗi lẻ ở bước chuyển: gom lại như kỷ
                    // luật bước 1 — KHÔNG giết cả lượt (manifest
                    // vẫn được ghi ở bước 3), KHÔNG đánh dấu
                    // deleted: entry giữ "active" để lượt sau
                    // thử chuyển lại (kiểm duyệt vòng 1, L3).
                    // LOGKIT: cộng dòng log domain+code của lỗi lẻ.
                    let nsError = error as NSError
                    DiagLog.log(.mirror,
                                "chuyển _deleted tờ \(id) lỗi — \(nsError.domain) code=\(nsError.code)")
                    failedDeletes += 1
                    continue
                }
                movedToDeleted += 1
            }
            var updated = entry
            updated.status = "deleted"
            updated.deletedAt = Date()
            byID[id] = updated
        }

        // --- 3) Ghi manifest (nguyên tử) ---
        manifest.entries = byID.values.sorted { $0.id < $1.id }
        manifest.updatedAt = Date()
        let manifestData = try MirrorJSON.encoder().encode(manifest)
        try manifestData.write(
            to: base.appendingPathComponent("manifest.json"),
            options: [.atomic])

        var parts = ["\(snapshots.count) hoá đơn"]
        if writtenCount > 0 { parts.append("ghi mới/cập nhật \(writtenCount)") }
        if movedToDeleted > 0 { parts.append("\(movedToDeleted) tờ vào _deleted") }
        var error: String? = nil
        if failedReceipts > 0 {
            error = "\(failedReceipts) tờ gương lỗi ở lượt này — app sẽ tự gương lại ở lượt sau."
        } else if failedDeletes > 0 {
            error = "\(failedDeletes) tờ chưa chuyển được sang _deleted ở lượt này — app sẽ tự thử lại ở lượt sau."
        } else if missingOriginals > 0 {
            error = "Thiếu \(missingOriginals) ảnh gốc trên máy nên bản gương chưa đủ bằng chứng — ảnh gốc của các tờ đó đã mất trong kho máy."
        }
        return PassOutcome(summary: parts.joined(separator: " · "),
                           error: error)
    }

    private struct OneResult {
        var wroteJSON: Bool
        var missingOriginals: Int
    }

    /// Gương một tờ: sao ảnh gốc (chỉ khi thiếu hoặc khác kích
    /// thước), ghi receipt.json khi nội dung đổi hoặc file
    /// đích thiếu/lệch kích thước (tự chữa), dọn file
    /// original-* thừa không còn trong danh sách bằng chứng.
    private static func mirrorOne(
        snapshot: MirrorReceiptSnapshot,
        fm: FileManager,
        receiptsDir: URL,
        deletedDir: URL,
        imageDirectory: URL,
        previous: MirrorManifestEntry?,
        contentHash: String
    ) throws -> OneResult {
        let dir = receiptsDir.appendingPathComponent(
            snapshot.folderID, isDirectory: true)
        // Tờ từng ở _deleted mà nay có mặt lại trong kho
        // (xoá rồi khôi phục/nạp lại cùng danh tính): chuyển
        // thư mục về receipts/ trước khi cập nhật.
        if previous?.status == "deleted" {
            let oldDir = deletedDir.appendingPathComponent(
                snapshot.folderID, isDirectory: true)
            if fm.fileExists(atPath: oldDir.path)
                && !fm.fileExists(atPath: dir.path) {
                try fm.moveItem(at: oldDir, to: dir)
            }
        }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let unchanged = previous?.status == "active"
            && previous?.contentHash == contentHash
        var originals: [MirrorOriginalRef] = []
        var missing = 0
        var keepNames = Set<String>()
        for (index, sourceName) in snapshot.sourceOriginalFileNames.enumerated() {
            let ext = (sourceName as NSString).pathExtension
            let mirrorName = "original-\(index + 1)."
                + (ext.isEmpty ? "jpg" : ext)
            keepNames.insert(mirrorName)
            let source = imageDirectory.appendingPathComponent(sourceName)
            let target = dir.appendingPathComponent(mirrorName)
            guard let attributes = try? fm.attributesOfItem(atPath: source.path),
                  let size = attributes[.size] as? Int else {
                missing += 1
                originals.append(MirrorOriginalRef(
                    mirrorFileName: mirrorName, sourceFileName: sourceName,
                    byteCount: nil, missing: true))
                continue
            }
            let targetSize = (try? fm.attributesOfItem(atPath: target.path))
                .flatMap { $0[.size] as? Int }
            if !unchanged || targetSize != size {
                let data = try Data(contentsOf: source)
                try data.write(to: target, options: [.atomic])
            }
            originals.append(MirrorOriginalRef(
                mirrorFileName: mirrorName, sourceFileName: sourceName,
                byteCount: size, missing: false))
        }

        // Ảnh tăng nét (bằng chứng phái sinh) — gương kèm khi có.
        var enhancedRef: MirrorOriginalRef? = nil
        if let enhancedName = snapshot.enhancedImageFileName,
           !enhancedName.isEmpty {
            let ext = (enhancedName as NSString).pathExtension
            let mirrorName = "enhanced." + (ext.isEmpty ? "jpg" : ext)
            keepNames.insert(mirrorName)
            let source = imageDirectory.appendingPathComponent(enhancedName)
            let target = dir.appendingPathComponent(mirrorName)
            if let attributes = try? fm.attributesOfItem(atPath: source.path),
               let size = attributes[.size] as? Int {
                let targetSize = (try? fm.attributesOfItem(atPath: target.path))
                    .flatMap { $0[.size] as? Int }
                if !unchanged || targetSize != size {
                    let data = try Data(contentsOf: source)
                    try data.write(to: target, options: [.atomic])
                }
                enhancedRef = MirrorOriginalRef(
                    mirrorFileName: mirrorName, sourceFileName: enhancedName,
                    byteCount: size, missing: false)
            } else {
                enhancedRef = MirrorOriginalRef(
                    mirrorFileName: mirrorName, sourceFileName: enhancedName,
                    byteCount: nil, missing: true)
            }
        }

        // Dọn file bằng chứng gương không còn được tham chiếu
        // (bằng chứng đã thay bằng bản quét mới): CHỈ đụng
        // file original-*/enhanced.* do chính lớp gương tạo.
        if let existing = try? fm.contentsOfDirectory(atPath: dir.path) {
            for name in existing
            where (name.hasPrefix("original-") || name.hasPrefix("enhanced."))
                && !keepNames.contains(name) {
                try? fm.removeItem(at: dir.appendingPathComponent(name))
            }
        }

        // receipt.json: ghi khi nội dung đổi — và TỰ CHỮA khi
        // file đích thiếu hoặc khác kích thước dù hash khớp,
        // cùng kỷ luật với file ảnh ở trên (kiểm duyệt vòng 1,
        // lỗi L2: trước đây manifest khớp là bỏ qua vĩnh viễn,
        // file bị xoá/hỏng trong thư mục gương không bao giờ
        // được ghi lại). Mã hoá mỗi lượt để có kích thước đích
        // cần so; snapshot không đổi thì byte sinh ra ổn định
        // (khoá đã sắp xếp, ngày tháng ISO8601 bề rộng cố định)
        // nên kích thước khớp = không ghi lại.
        let file = MirrorReceiptFile(
            formatVersion: 1, mirroredAt: Date(),
            receipt: snapshot, originals: originals,
            enhanced: enhancedRef)
        let data = try MirrorJSON.encoder().encode(file)
        let jsonTarget = dir.appendingPathComponent("receipt.json")
        let jsonTargetSize = (try? fm.attributesOfItem(atPath: jsonTarget.path))
            .flatMap { $0[.size] as? Int }
        var wroteJSON = false
        if !unchanged || jsonTargetSize != data.count {
            try data.write(to: jsonTarget, options: [.atomic])
            wroteJSON = true
        }
        return OneResult(wroteJSON: wroteJSON, missingOriginals: missing)
    }

    /// Manifest đọc hỏng (file chưa có, JSON lỗi, iCloud chưa
    /// tải xong) -> nil: lượt này coi như chưa có mục lục.
    /// Hướng an toàn: không mục lục thì không phát hiện xoá,
    /// chỉ ghi mới/cập nhật — không bao giờ xoá nhầm.
    private static func loadManifest(base: URL) -> MirrorManifest? {
        let url = base.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? MirrorJSON.decoder().decode(MirrorManifest.self,
                                                 from: data)
    }
}

// MARK: Bộ chọn thư mục — trình bằng UIKit thuần từ VC trên cùng
//
// Bài học L-2026-11-19-36 (bản 146 trên máy anh, ký lại bằng
// KravaSigner): bọc UIDocumentPickerViewController trong .sheet
// SwiftUI (UIViewControllerRepresentable) thì cửa sổ chọn hiện
// lên nhưng thao tác bấm Open BỊ NUỐT — không đóng, không kết
// quả, không lỗi, delegate không bao giờ chạy, ở MỌI thư mục
// (Receipts / iCloud Drive / On My iPhone đều vậy). Cùng triệu
// chứng đã ghi nhận ở các bản cài sideload: ngữ cảnh trình diễn
// do SwiftUI quản bị dỡ ngay dưới picker nên lệnh chọn không
// tới được delegate.
// Cách trình đúng: tạo picker và PRESENT bằng UIKit thuần từ
// view controller trên cùng của cửa sổ chính; coordinator được
// GIỮ TĨNH tới khi picker đóng; lùi một nhịp runloop để không
// đụng nhịp dỡ ngữ cảnh của nút bấm vừa bấm. Kỷ luật cấp thấp
// giữ nguyên: KHÔNG fileImporter (Test 0 — tự huỷ im lặng).

enum MirrorFolderPickerPresenter {
    /// Coordinator của lượt chọn đang mở. Delegate của picker
    /// là weak nên phải có tham chiếu mạnh giữ nó sống tới khi
    /// picker báo xong; nhả ngay trong callback.
    private static var activeCoordinator: Coordinator?

    static func present(onPick: @escaping (URL) -> Void,
                        onCancel: @escaping () -> Void) {
        // LOGKIT (L-2026-11-19-39): chỉ cộng lời gọi log ở
        // mọi chặng của lượt trình — logic giữ nguyên từng chữ.
        DiagLog.log(.picker, "present() được gọi")
        // Lùi một nhịp runloop: nút bấm nằm trong List của
        // SwiftUI — trình ngay trong cùng nhịp sự kiện là đúng
        // cơ chế nuốt thao tác đã dính ở bản 146.
        DispatchQueue.main.async {
            // Khoá tái nhập (kiểm duyệt L36 vòng 1): hai thao
            // tác mở rất nhanh không được sinh hai picker — lần
            // mở sau ghi đè biến tĩnh sẽ làm coordinator của
            // picker trước mất tham chiếu mạnh, delegate chết và
            // Open của picker đó chết theo (đúng triệu chứng
            // L-36). Picker modal chỉ có hai lối ra (chọn/huỷ),
            // cả hai đều nhả biến tĩnh bằng defer nên chốt này
            // không thể gây kẹt.
            guard activeCoordinator == nil else {
                DiagLog.log(.picker,
                            "present bị chặn bởi khoá tái nhập (đang có picker mở)")
                return
            }
            guard let presenter = topPresenter() else {
                // Không có cửa sổ nào để trình: bộ chọn không
                // hề hiện và sẽ không có phản hồi nào tới — ghi
                // loại "không có phản hồi" (cùng kết cục quan
                // sát được như đường tự nhả 0,6 s ở dưới).
                DiagLog.log(.picker,
                            "topPresenter = nil — không có cửa sổ để trình")
                MirrorSettings.recordPickerOutcome(.noResponse,
                                                   folderName: nil)
                onCancel()
                return
            }
            DiagLog.log(.picker,
                        "topPresenter có: \(type(of: presenter))")
            let coordinator = Coordinator(onPick: onPick,
                                          onCancel: onCancel)
            activeCoordinator = coordinator
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [UTType.folder], asCopy: false)
            picker.delegate = coordinator
            picker.allowsMultipleSelection = false
            presenter.present(picker, animated: true)
            DiagLog.log(.picker, "đã gọi present(picker)")
            // Lối thoát thứ ba (kiểm duyệt L36 vòng 2): nếu
            // UIKit NUỐT lệnh present (VC đích đang giữa một
            // chuyển cảnh đóng/mở modal khác) thì picker không
            // hề hiện, cả hai callback delegate không bao giờ
            // chạy — biến tĩnh sẽ kẹt và khoá mở trùng chặn mọi
            // lần mở sau tới khi khởi động lại app. Sau khoảng
            // thời gian trình diễn chuẩn, tự kiểm lại: picker
            // không có presentingViewController mà biến tĩnh
            // vẫn là coordinator của lượt này thì tự nhả chốt.
            // (presentingViewController được UIKit gán ngay khi
            // bắt đầu trình, trước khi hoạt ảnh chạy xong, nên
            // nhịp kiểm này không bắn nhầm picker đang mở.)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if picker.presentingViewController == nil,
                   MirrorFolderPickerPresenter.activeCoordinator === coordinator {
                    MirrorFolderPickerPresenter.activeCoordinator = nil
                    // Tách khỏi huỷ tay (điểm yếu 2.6): đường
                    // này là present BỊ NUỐT — ghi loại "không
                    // có phản hồi"; hành vi anh thấy giữ nguyên
                    // (vẫn gọi onCancel như trước).
                    // LOGKIT: cộng dòng log kết quả nhịp kiểm.
                    DiagLog.log(.picker,
                                "nhịp kiểm 0,6s: picker KHÔNG có presentingViewController — present bị nuốt, tự nhả chốt")
                    MirrorSettings.recordPickerOutcome(.noResponse,
                                                       folderName: nil)
                    onCancel()
                } else if picker.presentingViewController != nil {
                    // LOGKIT: chỉ cộng dòng log — nhánh này
                    // không đổi trạng thái nào.
                    DiagLog.log(.picker,
                                "nhịp kiểm 0,6s: picker đang hiện (có presentingViewController)")
                } else {
                    // LOGKIT: picker đã kết thúc qua delegate
                    // trước nhịp kiểm — chỉ cộng dòng log.
                    DiagLog.log(.picker,
                                "nhịp kiểm 0,6s: picker đã kết thúc qua delegate trước nhịp kiểm")
                }
            }
        }
    }

    /// View controller trên cùng của cửa sổ khoá thuộc scene
    /// đang foreground (không có thì lấy scene cửa sổ đầu tiên).
    private static func topPresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first
        guard let root = scene?.windows
            .first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene?.windows.first?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        var onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void,
             onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            defer { MirrorFolderPickerPresenter.activeCoordinator = nil }
            guard let url = urls.first else {
                // Picker trả về rỗng: không thư mục nào được
                // chọn — đi đường huỷ như trước và ghi theo
                // đúng đường đó.
                // LOGKIT: cộng dòng log nhánh rỗng.
                DiagLog.log(.picker, "didPick NHƯNG urls rỗng")
                MirrorSettings.recordPickerOutcome(.cancelled,
                                                   folderName: nil)
                onCancel()
                return
            }
            // Ghi TRƯỚC onPick: kết quả của bộ chọn là "đã
            // chọn được thư mục này"; bước nhận thư mục
            // (adoptFolder) thành hay bại nằm ở lastError,
            // không trộn vào bản ghi này.
            // LOGKIT: cộng dòng log didPick (chỉ tên thư mục).
            DiagLog.log(.picker,
                        "didPick: \(url.lastPathComponent)")
            MirrorSettings.recordPickerOutcome(
                .picked, folderName: url.lastPathComponent)
            onPick(url)
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            defer { MirrorFolderPickerPresenter.activeCoordinator = nil }
            // LOGKIT: cộng dòng log huỷ.
            DiagLog.log(.picker, "documentPickerWasCancelled")
            MirrorSettings.recordPickerOutcome(.cancelled,
                                               folderName: nil)
            onCancel()
        }
    }
}

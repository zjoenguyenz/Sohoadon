import Foundation
#if canImport(UIKit)
import SwiftData
#endif

// MARK: - Bảo vệ ảnh gốc: kho an toàn + kiểm kê (L-2026-11-20-42)
//
// Vụ mất 14 ảnh gốc (TEAM.md L-2026-11-20-42 / thư viện lỗi
// FL-338): file trong Documents/ReceiptImages biến mất trong
// khi dữ liệu SwiftData ở Application Support nguyên vẹn;
// nguyên nhân CHƯA KẾT ÁN. Gói này không truy thủ phạm — nó
// làm cho việc mất file KHÔNG còn phá huỷ được dữ liệu:
//
// 1. KHO AN TOÀN (OriginalVault): thư mục Application
//    Support/OriginalVault/ — cùng khu vực đã sống sót trong
//    vụ mất. Mọi ảnh gốc ghi qua phễu ImageStore.saveJPEG /
//    saveFile (Models.swift) được chép thêm một bản vào đây
//    ngay lúc ghi (best-effort: chép kho hỏng chỉ ghi log,
//    không bao giờ làm hỏng đường lưu chính). Kiểm kê chép
//    BỔ SUNG cho các file có từ trước gói này (Điều 2 của
//    luật B2: sửa phải áp cho dữ liệu đã lưu).
// 2. KIỂM KÊ (ImageIntegrity): mỗi lần mở app, TRƯỚC các
//    trigger đồng bộ — đối chiếu mọi file được hoá đơn tham
//    chiếu với kho chính + kho an toàn: kho chính mất mà kho
//    an toàn còn -> TỰ KHÔI PHỤC; kho chính có mà kho thiếu
//    -> chép bổ sung; mất cả hai -> đếm + nêu tên tờ trong
//    log; file ở lần kiểm trước còn mà nay mất -> MẤT MỚI
//    (bắt ngay ở lần mở app kế tiếp, kèm mốc giờ của log).
//    Bộ đếm này ĐỘC LẬP với bộ đếm của lượt đồng bộ Drive
//    (đính chính hệ quả vá L-41: đường verify nhẹ của Drive
//    không đếm lại ảnh mất nữa nên dòng trạng thái đồng bộ
//    không còn là nguồn sự thật cho việc đủ/thiếu ảnh).
// 3. ĐƯỜNG XOÁ (điểm gọi ở ReceiptViews): trước khi xoá bất
//    kỳ file bằng chứng nào phải kiểm tra hoá đơn KHÁC còn
//    tham chiếu không — còn thì bỏ qua; xoá thật thì xoá cả
//    bản kho an toàn; MỌI lần xoá/bỏ qua đều ghi log.
//
// Planner là logic THUẦN (không chạm đĩa) để harness kiểm
// bằng Swift thật (test IG01… trong UnitTests.swift); phần
// thực thi mới chạm FileManager. Phần keo SwiftData/UI
// (gom hoá đơn, xoá bằng chứng kèm phái sinh -flat/.ocrdiag)
// nằm sau #if canImport(UIKit) như tiền lệ ReadPipeline —
// harness macOS không biên dịch phần đó, app iOS biên dịch đủ.
//
// File này CHỈ ở target app (như MirrorSync/DriveSync) +
// harness; bench không liên kết.

/// Cầu log của gói: trên iOS ghi vào DiagLog mục integrity;
/// trong harness (không có Diagnostics.swift) là no-op.
private func integrityLog(_ message: String) {
    #if canImport(UIKit)
    DiagLog.log(.integrity, message)
    #endif
}

/// Chép một file giữa hai thư mục theo tên — dùng chung cho
/// kho an toàn + kiểm kê. Trả false + ghi log khi chép hỏng;
/// nơi gọi quyết định hệ quả (best-effort ở đường ghi, đếm
/// thiếu ở kiểm kê).
///
/// Chép NGUYÊN TỬ (rà soát R1 ghế B — LOGIC): chép vào file
/// tạm CÙNG thư mục đích (hậu tố .tmp-<UUID>), so KÍCH THƯỚC
/// bản tạm với nguồn — bằng mới đổi tên vào vị trí chính
/// thức. App bị giết giữa lúc chép chỉ để lại file tạm mồ
/// côi (không tên nào tham chiếu tới), KHÔNG bao giờ để lại
/// một file đích cắt ngắn mà các lượt kiểm sau tin là bản
/// tốt. Mọi nhánh lỗi đều dọn file tạm + trả false + ghi
/// log. Đích đã có sẵn -> coi như đã chép (mọi bản ở đích do
/// helper này tạo ra đều đã qua cổng nguyên tử trên).
private func integrityCopyFile(_ fileName: String,
                               from sourceDir: URL,
                               to destDir: URL) -> Bool {
    let fm = FileManager.default
    let source = sourceDir.appendingPathComponent(fileName)
    let dest = destDir.appendingPathComponent(fileName)
    if fm.fileExists(atPath: dest.path) {
        return true
    }
    let temp = destDir.appendingPathComponent(
        fileName + ".tmp-" + UUID().uuidString)
    do {
        try fm.copyItem(at: source, to: temp)
        let sourceSize = (try? fm.attributesOfItem(
            atPath: source.path))?[.size] as? Int
        let tempSize = (try? fm.attributesOfItem(
            atPath: temp.path))?[.size] as? Int
        guard let sourceSize, let tempSize,
              sourceSize == tempSize else {
            try? fm.removeItem(at: temp)
            integrityLog("chép file \(fileName): kích thước "
                + "sau chép không khớp nguồn — huỷ bản tạm, "
                + "lượt sau chép lại")
            return false
        }
        try fm.moveItem(at: temp, to: dest)
        return true
    } catch {
        try? fm.removeItem(at: temp)
        let nsError = error as NSError
        integrityLog("chép file \(fileName) THẤT BẠI — "
            + "\(nsError.domain) code=\(nsError.code)")
        return false
    }
}

// MARK: - Kho an toàn (Application Support/OriginalVault)

enum OriginalVault {
    /// Thư mục kho an toàn — tạo nếu chưa có, cùng mẫu
    /// ImageStore.directory. Nằm ở Application Support:
    /// khu vực chứa kho SwiftData, đã nguyên vẹn trong vụ
    /// mất L-42 (vụ mất chỉ chạm Documents).
    static var directory: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(
            "OriginalVault", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func contains(fileName: String) -> Bool {
        guard !fileName.isEmpty else { return false }
        return FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(fileName).path)
    }

    /// Chép một ảnh gốc vừa ghi ở kho chính sang kho an
    /// toàn. Best-effort tuyệt đối: trả false khi chép hỏng
    /// (đã ghi log trong integrityCopyFile) và nơi gọi
    /// KHÔNG được đổi hành vi vì kết quả này.
    @discardableResult
    static func backfill(fileName: String,
                         mainDirectory: URL) -> Bool {
        guard !fileName.isEmpty else { return false }
        return integrityCopyFile(fileName,
                                 from: mainDirectory,
                                 to: directory)
    }

    /// Xoá bản kho an toàn của một file — CHỈ gọi khi file
    /// chính bị xoá thật ở đường xoá hoá đơn (không còn hoá
    /// đơn nào tham chiếu). File không có ở kho -> im lặng.
    static func removeCopy(fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(
            at: directory.appendingPathComponent(fileName))
    }
}

// MARK: - Planner thuần (harness test được)

/// Một hành động kiểm kê cho MỘT tên file. Planner làm
/// việc ở mức TÊN FILE (không phải mức hoá đơn): một file
/// được nhiều hoá đơn cùng tham chiếu chỉ sinh hành động
/// một lần, và việc một hoá đơn biến mất khỏi bản đồ tham
/// chiếu không tự nó thành "mất file".
enum IntegrityAction: Equatable {
    /// Kho chính mất, kho an toàn còn -> chép về kho chính.
    case restoreFromVault(fileName: String)
    /// Kho chính có, kho an toàn thiếu -> chép bổ sung.
    case backfillVault(fileName: String)
    /// Mất cả hai kho -> không cứu được ở lượt này.
    case missingUnrecoverable(fileName: String)
    /// Lần kiểm trước file còn ở kho chính, nay mất (dù cứu
    /// được từ kho an toàn hay không) -> dấu vết mất mới.
    case newlyLost(fileName: String)

    var fileName: String {
        switch self {
        case .restoreFromVault(let name),
             .backfillVault(let name),
             .missingUnrecoverable(let name),
             .newlyLost(let name):
            return name
        }
    }
}

enum IntegrityPlanner {
    /// Quyết định thuần: nhận bản đồ tham chiếu (tên file ->
    /// tập id hoá đơn còn tham chiếu), tập tên file hiện có
    /// ở kho chính, tập tên file hiện có ở kho an toàn, và
    /// tập "đã biết còn" (file có ở kho chính tại lần kiểm
    /// trước) — trả danh sách hành động theo thứ tự tên file
    /// tăng dần (ổn định để test + đọc log). File không được
    /// hoá đơn nào tham chiếu thì KHÔNG xét (mồ côi ở kho là
    /// việc của mục liệt kê riêng ở Cài đặt, không phải mất
    /// bằng chứng).
    static func plan(references: [String: Set<String>],
                     mainFiles: Set<String>,
                     vaultFiles: Set<String>,
                     knownPresent: Set<String>) -> [IntegrityAction] {
        var actions: [IntegrityAction] = []
        for name in references.keys.sorted() where !name.isEmpty {
            let inMain = mainFiles.contains(name)
            let inVault = vaultFiles.contains(name)
            if inMain {
                if !inVault {
                    actions.append(.backfillVault(fileName: name))
                }
            } else {
                if inVault {
                    actions.append(.restoreFromVault(fileName: name))
                } else {
                    actions.append(.missingUnrecoverable(fileName: name))
                }
                // Mất mới tính theo KHO CHÍNH: lần trước còn
                // mà nay không — kể cả khi kho an toàn cứu
                // được, sự kiện mất vẫn phải để lại dấu vết.
                if knownPresent.contains(name) {
                    actions.append(.newlyLost(fileName: name))
                }
            }
        }
        return actions
    }
}

// MARK: - Tóm tắt một lượt kiểm kê

struct IntegritySummary: Equatable {
    var checkedAt: Date
    /// Tổng số file đang được hoá đơn tham chiếu.
    var referencedCount: Int
    /// Số file tham chiếu còn ở kho chính SAU khi thực thi
    /// (đã gồm các file vừa khôi phục).
    var presentCount: Int
    var restoredCount: Int
    var backfilledCount: Int
    /// Số file mất cả hai kho (không cứu được ở lượt này).
    var missingCount: Int
    var newlyLostCount: Int
    var missingFileNames: [String]
}

// MARK: - Trạng thái kiểm kê (UserDefaults — không đổi model)

/// Cùng kỷ luật MirrorSettings: khoá riêng có tiền tố,
/// kiểu nguyên thuỷ (Int/String/Date/mảng chuỗi — không
/// JSON), phát thông báo đổi trạng thái TRÊN MAIN QUEUE để
/// CardsView vẽ lại an toàn.
enum IntegritySettings {
    private static let lastCheckAtKey = "glkeeper.integrity.lastCheckAt"
    private static let referencedCountKey = "glkeeper.integrity.referencedCount"
    private static let presentCountKey = "glkeeper.integrity.presentCount"
    private static let restoredCountKey = "glkeeper.integrity.restoredCount"
    private static let backfilledCountKey = "glkeeper.integrity.backfilledCount"
    private static let missingCountKey = "glkeeper.integrity.missingCount"
    private static let newlyLostCountKey = "glkeeper.integrity.newlyLostCount"
    private static let knownPresentKey = "glkeeper.integrity.knownPresent"

    static var lastCheckAt: Date? {
        get { UserDefaults.standard.object(forKey: lastCheckAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastCheckAtKey) }
    }

    /// Tóm tắt lượt kiểm gần nhất dựng lại từ các khoá
    /// nguyên thuỷ; nil khi chưa từng kiểm kê.
    static var lastSummary: IntegritySummary? {
        guard let at = lastCheckAt else { return nil }
        let defaults = UserDefaults.standard
        return IntegritySummary(
            checkedAt: at,
            referencedCount: defaults.integer(forKey: referencedCountKey),
            presentCount: defaults.integer(forKey: presentCountKey),
            restoredCount: defaults.integer(forKey: restoredCountKey),
            backfilledCount: defaults.integer(forKey: backfilledCountKey),
            missingCount: defaults.integer(forKey: missingCountKey),
            newlyLostCount: defaults.integer(forKey: newlyLostCountKey),
            missingFileNames: [])
    }

    /// Tập "đã biết còn": tên file có ở kho chính tại lần
    /// kiểm trước — căn cứ để planner bắt MẤT MỚI ở lần
    /// kiểm sau.
    static var knownPresent: Set<String> {
        Set(UserDefaults.standard.stringArray(
            forKey: knownPresentKey) ?? [])
    }

    /// Ghi kết quả một lượt kiểm + thay tập đã-biết-còn
    /// bằng trạng thái sau lượt này, rồi phát thông báo.
    static func recordAudit(summary: IntegritySummary,
                            knownPresent: Set<String>) {
        let defaults = UserDefaults.standard
        defaults.set(summary.checkedAt, forKey: lastCheckAtKey)
        defaults.set(summary.referencedCount, forKey: referencedCountKey)
        defaults.set(summary.presentCount, forKey: presentCountKey)
        defaults.set(summary.restoredCount, forKey: restoredCountKey)
        defaults.set(summary.backfilledCount, forKey: backfilledCountKey)
        defaults.set(summary.missingCount, forKey: missingCountKey)
        defaults.set(summary.newlyLostCount, forKey: newlyLostCountKey)
        defaults.set(knownPresent.sorted(), forKey: knownPresentKey)
        postStatusChanged()
    }

    /// Phát thông báo đổi trạng thái TRÊN MAIN QUEUE —
    /// recordAudit được gọi từ hàng đợi nền của kiểm kê,
    /// còn phía nhận (CardsView.onReceive) sửa @State
    /// (cùng bài học L1 của kiểm duyệt P2-1 ở MirrorSettings).
    private static func postStatusChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ImageIntegrity.statusChangedNotification,
                object: nil)
        }
    }
}

// MARK: - Bộ kiểm kê (thực thi — chạm đĩa, không chạm model)

enum ImageIntegrity {
    static let statusChangedNotification =
        Notification.Name("glkeeper.integrity.statusChanged")

    /// Hàng đợi SERIAL riêng của kiểm kê: các lượt kiểm
    /// không chạy chồng nhau (cùng kỷ luật hàng đợi của
    /// MirrorSync/DriveSync).
    private static let auditQueue = DispatchQueue(
        label: "glkeeper.integrity.audit", qos: .utility)

    /// Thực thi một lượt kiểm kê trên đĩa: liệt kê hai kho,
    /// hỏi planner, làm từng hành động (chép về / chép bổ
    /// sung), ghi log TỪNG hành động + một dòng tổng kết.
    /// Trả tóm tắt + tập đã-biết-còn MỚI (file tham chiếu
    /// còn ở kho chính sau khi thực thi). Hàm này không tự
    /// ghi UserDefaults — nơi gọi (keo mở app) ghi qua
    /// IntegritySettings.recordAudit. Chỉ stat/copy, KHÔNG
    /// giải mã ảnh — lượt kiểm phải nhẹ.
    static func executeAudit(
        references: [String: Set<String>],
        mainDirectory: URL,
        vaultDirectory: URL,
        knownPresent: Set<String>
    ) -> (summary: IntegritySummary, knownPresent: Set<String>) {
        let fm = FileManager.default
        let mainFiles = Set(
            (try? fm.contentsOfDirectory(atPath: mainDirectory.path)) ?? [])
        let vaultFiles = Set(
            (try? fm.contentsOfDirectory(atPath: vaultDirectory.path)) ?? [])
        let actions = IntegrityPlanner.plan(
            references: references,
            mainFiles: mainFiles,
            vaultFiles: vaultFiles,
            knownPresent: knownPresent)

        var restored = 0
        var backfilled = 0
        var missing: [String] = []
        var newlyLost = 0
        for action in actions {
            let name = action.fileName
            let owners = (references[name] ?? []).sorted()
                .joined(separator: ", ")
            switch action {
            case .restoreFromVault:
                if integrityCopyFile(name, from: vaultDirectory,
                                     to: mainDirectory) {
                    restored += 1
                    integrityLog("tự khôi phục từ kho an toàn: "
                        + "\(name) (tờ \(owners))")
                } else {
                    missing.append(name)
                    integrityLog("khôi phục THẤT BẠI, tính là mất: "
                        + "\(name) (tờ \(owners))")
                }
            case .backfillVault:
                if integrityCopyFile(name, from: mainDirectory,
                                     to: vaultDirectory) {
                    backfilled += 1
                    integrityLog("chép bổ sung vào kho an toàn: \(name)")
                }
            case .missingUnrecoverable:
                missing.append(name)
                integrityLog("MẤT HẲN (cả hai kho đều không có): "
                    + "\(name) (tờ \(owners))")
            case .newlyLost:
                newlyLost += 1
                integrityLog("MẤT MỚI so với lần kiểm trước: "
                    + "\(name) (tờ \(owners))")
            }
        }

        let mainAfter = Set(
            (try? fm.contentsOfDirectory(atPath: mainDirectory.path)) ?? [])
        let presentNames = references.keys.filter {
            !$0.isEmpty && mainAfter.contains($0)
        }
        let summary = IntegritySummary(
            checkedAt: Date(),
            referencedCount: references.keys.filter { !$0.isEmpty }.count,
            presentCount: presentNames.count,
            restoredCount: restored,
            backfilledCount: backfilled,
            missingCount: missing.count,
            newlyLostCount: newlyLost,
            missingFileNames: missing.sorted())
        integrityLog("kiểm kê xong: tham chiếu \(summary.referencedCount) file"
            + " · đủ \(summary.presentCount)"
            + " · khôi phục \(restored)"
            + " · chép bổ sung \(backfilled)"
            + " · mất hẳn \(missing.count)"
            + " · mất mới \(newlyLost)")
        return (summary, Set(presentNames))
    }
}

// MARK: - Keo tầng app (chỉ biên dịch ở target iOS)

#if canImport(UIKit)
extension ImageIntegrity {

    /// Điểm kích hoạt kiểm kê LÚC MỞ APP — gọi từ
    /// TabShellView.task TRƯỚC các trigger MirrorSync/
    /// DriveSync: completion chỉ chạy SAU khi kiểm kê xong
    /// (trên main queue) để lượt đồng bộ luôn nhìn thấy kho
    /// đã được khôi phục/bổ sung. Đọc sổ lỗi ở bước gom ->
    /// bỏ lượt kiểm nhưng completion VẪN chạy: kiểm kê là
    /// lớp bảo vệ, không được chặn đồng bộ (cùng kỷ luật
    /// thoát im lặng của MirrorSync.requestSync).
    static func runLaunchAudit(using context: ModelContext,
                               completion: @escaping () -> Void) {
        let receipts: [Receipt]
        do {
            receipts = try context.fetch(FetchDescriptor<Receipt>())
        } catch {
            integrityLog("kiểm kê mở app: đọc sổ THẤT BẠI — "
                + "bỏ lượt này, đồng bộ vẫn chạy")
            completion()
            return
        }
        var references: [String: Set<String>] = [:]
        for receipt in receipts {
            let owner = receipt.stableID.isEmpty
                ? "(chưa có stableID)" : receipt.stableID
            for name in receipt.allOriginalImageFileNames {
                references[name, default: []].insert(owner)
            }
        }
        let mainDirectory = ImageStore.directory
        let vaultDirectory = OriginalVault.directory
        auditQueue.async {
            // Đọc tập đã-biết-còn NGAY TRONG hàng đợi kiểm
            // kê (rà soát R1 ghế B — MINOR): đọc và ghi
            // (recordAudit) cùng chạy trên auditQueue serial
            // nên hai lượt kiểm không bao giờ cùng chụp một
            // knownPresent cũ rồi báo MẤT MỚI trùng nhau.
            let known = IntegritySettings.knownPresent
            let outcome = executeAudit(
                references: references,
                mainDirectory: mainDirectory,
                vaultDirectory: vaultDirectory,
                knownPresent: known)
            IntegritySettings.recordAudit(
                summary: outcome.summary,
                knownPresent: outcome.knownPresent)
            DispatchQueue.main.async { completion() }
        }
    }

    /// Xoá bộ file bằng chứng của MỘT hoá đơn vừa bị xoá
    /// khỏi sổ (nơi gọi đã lưu context thành công trước —
    /// luật C9-FIX: bản ghi đi trước, file đi sau). Với
    /// TỪNG file gốc (chính + phụ): hoá đơn KHÁC còn tham
    /// chiếu cùng tên -> BỎ QUA (giữ file + bản kho an
    /// toàn + phái sinh); không còn ai tham chiếu -> xoá
    /// file chính + bản kho an toàn + .ocrdiag + -flat.
    /// MỌI lần xoá và MỌI lần bỏ qua đều ghi log integrity
    /// kèm tên file + id hoá đơn + lý do — từ nay một file
    /// bằng chứng biến mất qua đường xoá luôn có dấu vết.
    static func deleteReceiptEvidence(mainName: String,
                                      extraNames: [String],
                                      receiptID: String,
                                      stillReferenced: Set<String>) {
        var seen = Set<String>()
        for name in [mainName] + extraNames
        where !name.isEmpty && seen.insert(name).inserted {
            if stillReferenced.contains(name) {
                integrityLog("xoá hoá đơn \(receiptID): BỎ QUA "
                    + "file \(name) — còn hoá đơn khác tham chiếu")
                continue
            }
            ImageStore.delete(fileName: name)
            OriginalVault.removeCopy(fileName: name)
            ImageStore.delete(fileName: DiagnosticsStore.fileName(
                forImageFileName: name))
            FlatScan.deleteFlat(forOriginal: name)
            integrityLog("xoá hoá đơn \(receiptID): đã xoá file "
                + "\(name) (+ bản kho an toàn, .ocrdiag, -flat nếu có)")
        }
    }
}
#endif

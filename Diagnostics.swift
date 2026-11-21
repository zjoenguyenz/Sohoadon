import Foundation
import UIKit

// MARK: - Bộ log chẩn đoán trong app (LOGKIT — L-2026-11-19-39)
//
// Luật cứng của anh (2026-11-18 21:55, LOG RETRIEVAL LAW): mọi
// app từ nay phải có đường lấy log chẩn đoán ra. GL-Keeper nợ
// luật này tới ca L-36/L-38: bộ chọn thư mục chết trên máy anh
// mà app không để lại MỘT dòng log nào — chẩn đoán phải đi qua
// video quay màn hình. File này là bộ ghi log tối thiểu khép
// món nợ đó:
//
// - Append-only, thread-safe bằng hàng đợi serial riêng: mọi
//   điểm gắn log (picker / gương / drive / đọc / khởi động) chỉ gọi
//   DiagLog.log(...) — không tự đụng file.
// - File nằm ở Documents/diagnostics.log (đi cùng kênh Files
//   của app); vượt ~512 KB thì xoay vòng: bản hiện tại thành
//   diagnostics.old.log (thay bản cũ), ghi tiếp vào file mới.
// - Mỗi dòng: <ISO8601> [<category>] <message>. Ghi xong flush
//   ngay (synchronize) như kỷ luật của BenchView.stageLog —
//   app chết giữa chừng vẫn còn dòng cuối chỉ chỗ chết.
// - Xuất log (DiagLogSharePresenter ở dưới): nội dung đi qua
//   bộ lọc thay tiền tố đường dẫn thư mục nhà bằng "~" TRƯỚC
//   khi rời máy. Token OAuth của Google Drive (P2-2) nằm ở
//   Keychain và KHÔNG BAO GIỜ đi qua bộ log — các điểm gắn
//   log chỉ ghi tên thư mục/số đếm + domain/code của lỗi hệ
//   thống; email tài khoản cũng không ghi log (chỉ hiện ở
//   Cài đặt), nên ngoài đường dẫn nhà ra không có gì khác
//   phải lọc.
//
// File này CHỈ ở target app (như MirrorSync/FlatScan): bench
// không liên kết — bench có màn thám tử riêng tự chứa trong
// BenchView.swift.

enum DiagLog {
    enum Category: String {
        case picker
        case mirror
        case drive
        case read
        case app
// L-2026-11-20-42: kiểm kê + kho an toàn ảnh gốc
        // (ImageIntegrity.swift) — khôi phục/chép bổ sung/
        // mất mới/mất hẳn và mọi lần xoá file bằng chứng.
        case integrity
    }

    /// Hàng đợi serial riêng của bộ log: mọi lần ghi/xoá/đọc
    /// đều xếp hàng ở đây — không khoá tay, không đua ghi.
    private static let queue = DispatchQueue(
        label: "glkeeper.diaglog", qos: .utility)

    /// Ngưỡng xoay vòng ~512 KB.
    private static let maxBytes = 512 * 1024

    static var fileURL: URL {
        FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("diagnostics.log")
    }

    private static var rotatedURL: URL {
        fileURL.deletingPathExtension()
            .appendingPathExtension("old.log")
    }

    /// Bộ định dạng ISO8601 — CHỈ chạm trên hàng đợi riêng
    /// (mọi lần dùng đều nằm trong queue) nên an toàn luồng.
    private static let stampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime,
                                   .withFractionalSeconds]
        return formatter
    }()

    /// Điểm gắn log DUY NHẤT. Gọi được từ mọi luồng; việc ghi
    /// thật chạy bất đồng bộ trên hàng đợi riêng. Lỗi ghi log
    /// bị nuốt im tuyệt đối — bộ log không bao giờ được làm
    /// hỏng luồng chính của app.
    static func log(_ category: Category, _ message: String) {
        queue.async {
            let line = "\(stampFormatter.string(from: Date())) "
                + "[\(category.rawValue)] \(message)"
            writeLine(line)
        }
    }

    /// Đọc toàn văn file log hiện tại (đã xếp hàng sau mọi lần
    /// ghi đang chờ nên không hụt dòng vừa ghi). File chưa có
    /// -> chuỗi rỗng.
    static func readAllText() -> String {
        queue.sync {
            (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        }
    }

    /// Bản xuất ra ngoài: toàn văn đã qua bộ lọc — thay MỌI
    /// lần xuất hiện của đường dẫn thư mục nhà (chứa UUID của
    /// container sandbox) bằng "~".
    static func exportText() -> String {
        readAllText().replacingOccurrences(
            of: NSHomeDirectory(), with: "~")
    }

    /// Xoá cả file log hiện tại lẫn bản xoay vòng.
    static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: rotatedURL)
        }
    }

    /// Kích thước file log hiện tại để UI hiển thị (đọc thẳng,
    /// best-effort — không qua hàng đợi vì chỉ để anh nhìn).
    static var currentSizeText: String {
        let size = (try? FileManager.default.attributesOfItem(
            atPath: fileURL.path)).flatMap { $0[.size] as? Int } ?? 0
        return ByteCountFormatter.string(
            fromByteCount: Int64(size), countStyle: .file)
    }

    /// Ghi một dòng (chạy trên hàng đợi riêng): xoay vòng
    /// trước nếu cộng dòng này sẽ vượt ngưỡng, rồi append +
    /// synchronize ngay như kỷ luật stageLog của bench.
    private static func writeLine(_ line: String) {
        let fm = FileManager.default
        let url = fileURL
        guard let data = (line + "\n").data(using: .utf8) else { return }
        let currentSize = (try? fm.attributesOfItem(atPath: url.path))
            .flatMap { $0[.size] as? Int } ?? 0
        if currentSize + data.count > maxBytes {
            try? fm.removeItem(at: rotatedURL)
            try? fm.moveItem(at: url, to: rotatedURL)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.synchronize()
        } else {
            try? data.write(to: url)
        }
    }
}

// MARK: - Trình phiếu chia sẻ log (UIKit thuần từ VC trên cùng)
//
// Cùng kỷ luật trình diễn với MirrorFolderPickerPresenter
// (bài học L-2026-11-19-36): KHÔNG ShareLink, KHÔNG .sheet
// SwiftUI cho hành động xuất — dựng UIActivityViewController
// và present bằng UIKit thuần từ view controller trên cùng,
// lùi một nhịp runloop. Nội dung xuất là FILE TẠM chứa bản đã
// lọc (DiagLog.exportText) — không xuất thẳng file gốc trong
// Documents để đường dẫn nhà không lọt ra ngoài qua metadata.

enum DiagLogSharePresenter {
    static func presentShare() {
        let text = DiagLog.exportText()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("glkeeper-diagnostics.log")
        try? text.data(using: .utf8)?.write(to: url, options: [.atomic])
        DispatchQueue.main.async {
            guard let presenter = topPresenter() else { return }
            let controller = UIActivityViewController(
                activityItems: [url], applicationActivities: nil)
            // App ghim iPhone (TARGETED_DEVICE_FAMILY "1")
            // nên không có popover iPad; vẫn gắn neo cho chắc
            // nếu sau này app mở sang iPad.
            controller.popoverPresentationController?.sourceView =
                presenter.view
            presenter.present(controller, animated: true)
        }
    }

    /// View controller trên cùng của cửa sổ khoá thuộc scene
    /// đang foreground — cùng thuật toán với
    /// MirrorFolderPickerPresenter.topPresenter (tự chứa ở
    /// đây để file log đứng độc lập, không phụ thuộc lớp
    /// gương).
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
}

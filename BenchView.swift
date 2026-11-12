import SwiftUI
import UIKit
import Vision

/// Màn BenchShell tối thiểu (Pha 4): liệt kê ảnh đóng băng trong
/// bundle (BenchImages — corpus 15 ca thật + 18 biến thể tổng
/// hợp), chạy ReceiptReader trên từng ảnh hoặc cả bộ, hiện tóm
/// tắt kết quả + xuất file phụ chẩn đoán; in danh sách ngôn ngữ
/// engine hỗ trợ trên máy đích (điều kiện C1 / giao thức M-1).
/// Mọi lần đọc đều là đường đọc của app chính — view này không
/// chứa logic đọc nào ngoài việc gọi ReceiptReader.
struct BenchView: View {
    @State private var results: [String: BenchRunSummary] = [:]
    @State private var running: String? = nil
    @State private var languageOutput: String = ""
    @State private var documentsOutput: String = ""

    private var imageNames: [String] {
        let urls = Bundle.main.urls(
            forResourcesWithExtension: "jpg",
            subdirectory: "BenchImages")
            ?? Bundle.main.urls(forResourcesWithExtension: "jpg",
                                subdirectory: nil)
            ?? []
        return urls.map { $0.lastPathComponent }.sorted()
    }

    /// Thư mục chẩn đoán của bench (Documents/BenchDiagnostics) —
    /// tách khỏi kho bằng chứng của app chính.
    private var diagnosticsDirectory: URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("BenchDiagnostics",
                                              isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Ngôn ngữ engine trên máy này (C1 / M-1)") {
                    Button("In supportedRecognitionLanguages") {
                        printLanguages()
                    }
                    if !languageOutput.isEmpty {
                        Text(languageOutput)
                            .font(.caption2)
                            .textSelection(.enabled)
                        ShareLink(item: languageOutput) {
                            Label("Chia sẻ bản in ngôn ngữ",
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("Họ documents — đo cô lập (M-3)") {
                    Button("Chạy DocumentsEngine trên ảnh đầu tiên") {
                        runDocumentsProbe()
                    }
                    if !documentsOutput.isEmpty {
                        Text(documentsOutput)
                            .font(.caption2)
                            .textSelection(.enabled)
                    }
                }

                Section("Ảnh đóng băng (\(imageNames.count))") {
                    Button("Chạy tất cả qua ReceiptReader") {
                        runAll()
                    }
                    .disabled(running != nil)
                    ForEach(imageNames, id: \.self) { name in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(name).font(.callout.bold())
                                Spacer()
                                if running == name {
                                    ProgressView()
                                } else {
                                    Button("Chạy") { runOne(name) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                            if let summary = results[name] {
                                Text(summary.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let url = summary.diagnosticsURL {
                                    ShareLink(item: url) {
                                        Label("Xuất chẩn đoán JSON",
                                              systemImage: "square.and.arrow.up")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("BenchShell — Đo OCR")
        }
    }

    // MARK: - Chạy pipeline trên ảnh bundle

    private func loadCGImage(_ name: String) -> CGImage? {
        let base = (name as NSString).deletingPathExtension
        let url = Bundle.main.url(forResource: base,
                                  withExtension: "jpg",
                                  subdirectory: "BenchImages")
            ?? Bundle.main.url(forResource: base, withExtension: "jpg")
        guard let url, let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return nil }
        return ReceiptReader.uprightCGImage(from: ui)
    }

    private func runOne(_ name: String) {
        guard running == nil, let cg = loadCGImage(name) else { return }
        running = name
        let directory = diagnosticsDirectory
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = ReceiptReader.read(ReadRequest(
                source: .photoLibrary,
                imageFileName: name,
                image: cg,
                diagnosticsDirectory: directory))
            let r = outcome.result
            let text = [
                "tiệm: \(r.vendor ?? "—")",
                "tạm tính: \(r.subtotalCents.map { moneyText($0) } ?? "—")",
                "thuế: \(moneyText(r.taxTotalCents))",
                "tổng: \(r.totalCents.map { moneyText($0) } ?? "—")",
                "món: \(r.items.count)",
                "đối chiếu: \(outcome.report.status.rawValue)",
                "cờ: \(r.warnings.count)",
                outcome.diagnosticsWriteFailed
                    ? "CHẨN ĐOÁN: GHI THẤT BẠI"
                    : "chẩn đoán: \(outcome.diagnosticsID ?? "—")",
            ].joined(separator: " · ")
            let url = outcome.diagnosticsWriteFailed ? nil
                : DiagnosticsStore.sidecarURL(directory: directory,
                                              imageFileName: name)
            DispatchQueue.main.async {
                results[name] = BenchRunSummary(text: text,
                                                diagnosticsURL: url)
                running = nil
            }
        }
    }

    private func runAll() {
        // Tuần tự từng ảnh (giữ trạng thái running để anh thấy
        // tiến độ; pipeline tự nó đã nặng, không chạy song song).
        var queue = imageNames
        func next() {
            guard !queue.isEmpty else { return }
            let name = queue.removeFirst()
            runOne(name)
            // runOne là bất đồng bộ: chờ nó xong bằng vòng kiểm tra
            // nhẹ trên main — bench là app đo, không phải bản giao.
            func poll() {
                if running == nil { next() } else {
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + 0.3) { poll() }
                }
            }
            poll()
        }
        next()
    }

    // MARK: - Bản in ngôn ngữ (nguyên logic LanguageProbe, Pha 0)

    private func printLanguages() {
        var out: [String] = []
        out.append("=== LanguageProbe — supportedRecognitionLanguages ===")
        out.append("máy: \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)")
        // Dạng gọi ĐÚNG như adapter ClassicTextEngine dùng:
        // supportedRecognitionLanguages(for: .accurate, revision:).
        for (label, rev) in [("Revision1", VNRecognizeTextRequestRevision1),
                             ("Revision2", VNRecognizeTextRequestRevision2),
                             ("Revision3", VNRecognizeTextRequestRevision3)] {
            let langs = VNRecognizeTextRequest
                .supportedRecognitionLanguages(for: .accurate,
                                               revision: rev)
            out.append("classic/accurate/\(label): \(langs)")
        }
        out.append("classic/currentRevision: \(VNRecognizeTextRequest.currentRevision)")
        out.append("classic/supportedRevisions: \(VNRecognizeTextRequest.supportedRevisions)")
        let fast = VNRecognizeTextRequest
            .supportedRecognitionLanguages(
                for: .fast, revision: VNRecognizeTextRequestRevision3)
        out.append("classic/fast/Revision3: \(fast)")
        languageOutput = out.joined(separator: "\n")
        // Họ documents (Swift-native, iOS 26+): async — điền tiếp
        // vào cùng bản in khi Task xong. Hai dòng này giữ nhãn
        // CONFIRM-AT-COMPILE của LanguageProbe (chữ ký tra từ tài
        // liệu, đối chiếu SDK ở lần biên dịch CI đầu tiên).
        if #available(iOS 26.0, *) {
            Task {
                let docLangs = await RecognizeDocumentsRequest
                    .supportedRecognitionLanguages
                let textLangs = await RecognizeTextRequest
                    .supportedRecognitionLanguages
                await MainActor.run {
                    languageOutput += "\ndocuments/RecognizeDocumentsRequest: \(docLangs)"
                    languageOutput += "\ndocuments/RecognizeTextRequest: \(textLangs)"
                    languageOutput += "\n=== LanguageProbe xong ==="
                }
            }
        } else {
            languageOutput += "\ndocuments: OS < 26 — họ Swift-native không tồn tại"
        }
    }

    // MARK: - Đo cô lập họ documents (khung Pha 3 — trung thực)

    private func runDocumentsProbe() {
        guard let first = imageNames.first,
              let cg = loadCGImage(first) else {
            documentsOutput = "Không tải được ảnh đầu tiên."
            return
        }
        let engine = DocumentsEngine()
        do {
            let fragments = try engine.recognize(in: cg, region: nil)
            documentsOutput = """
                DocumentsEngine trên \(first): \(fragments.count) mảnh.
                manifest: family=\(engine.manifest.family) revision=\(engine.manifest.revision)
                TRẠNG THÁI TRUNG THỰC: adapter họ documents là KHUNG của Pha 3 (chuyển đổi observation->Fragment để trống có chủ đích, TODO(PHA-3)) — 0 mảnh ở đây KHÔNG phải kết luận về engine; phép đo cô lập thật chạy khi adapter được nối ở phiên đo (DESIGN-FINAL §4.5).
                """
        } catch {
            documentsOutput = "DocumentsEngine ném lỗi: \(error)"
        }
    }
}

/// Tóm tắt một lần chạy bench (chỉ để hiện — số chuẩn nằm trong
/// file chẩn đoán JSON đi kèm).
private struct BenchRunSummary {
    var text: String
    var diagnosticsURL: URL?
}

/// Định dạng xu -> "$d.cc" NỘI BỘ của bench: BenchShell không
/// liên kết Models.swift của app chính (formatMoney sống ở đó)
/// nên không mượn được — và không được fork logic đọc, còn định
/// dạng hiển thị của app đo thì tự chứa ở đây là đúng phạm vi.
private func moneyText(_ cents: Int) -> String {
    let sign = cents < 0 ? "-" : ""
    let absCents = abs(cents)
    return "\(sign)$\(absCents / 100).\(String(format: "%02d", absCents % 100))"
}

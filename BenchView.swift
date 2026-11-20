import SwiftUI
import UIKit
import Vision
import UniformTypeIdentifiers

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
    @State private var enhancerOn: Bool = false
    @State private var stageLogText: String = ""
    // CI-FIX-7: trạng thái chia đôi cấu hình engine — công tắc
    // vẫn giữ làm dụng cụ bisect khi cần.
    // N5-FIX (FULL-REVIEW 2026-11-12): MẶC ĐỊNH phải là cấu
    // hình APP GIAO (top-3 + chính sách ngôn ngữ runtime,
    // trên máy anh là vi-VT). Mặc định cũ của CI-FIX-7 (top-1
    // + ép thẳng ["vi-VN","en-US"]) đo một cấu hình app giao
    // không bao giờ chạy — mọi hồ sơ bench mặc định, kể cả
    // readerConfigHash, đều lệch khỏi đường giao.
    @State private var top3On: Bool = true
    @State private var langMode: Int = 0
    // Gate D (G5): trạng thái tự kiểm một chạm — tiến trình
    // thật nằm trong BenchSelfCheck (ghi xuống đĩa từng bước),
    // các biến này chỉ là hiển thị của phiên hiện tại.
    @State private var selfCheckStatus: String = ""
    @State private var selfCheckBusy: Bool = false
    @State private var lifecycleStatus: String = ""
    @State private var replayStatus: String = ""
    @State private var showDiagImporter: Bool = false
    @State private var resultFileURL: URL? = nil
    // Picker Probe (bậc 2 thang chẩn đoán Gói 1 — L-38):
    // khung sự kiện của bộ chọn thư mục TRẦN, in ngay trên
    // màn này để anh chụp lại.
    @State private var probeOutput: String = ""

    private var imageNames: [String] {
        // CI-FIX-4 (2026-11-12): XcodeGen LAM PHANG tai nguyen vao
        // GOC bundle (bai hoc run #33) — thu muc BenchImages khong
        // ton tai trong .app. Ban cu dung ?? tren mang: luot tra
        // trong (khong nil) cua subdirectory khong kich hoat
        // fallback goc -> 0 anh tren may that. Tra ca hai noi va
        // hop nhat, khong phu thuoc nil/trong.
        let sub = Bundle.main.urls(
            forResourcesWithExtension: "jpg",
            subdirectory: "BenchImages") ?? []
        let root = Bundle.main.urls(
            forResourcesWithExtension: "jpg",
            subdirectory: nil) ?? []
        let names = Set(sub.map { $0.lastPathComponent })
            .union(root.map { $0.lastPathComponent })
        return names.sorted()
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

    // MARK: - Nhật ký giai đoạn (CI-FIX-6 / L-2026-11-12-12)

    /// File breadcrumb trong Documents của bench — ghi TRƯỚC
    /// mỗi bước của chuỗi đọc và flush ngay (synchronize), nên
    /// app chết giữa chừng vẫn còn dòng cuối chỉ tầng chết.
    private static var stageLogURL: URL {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("bench-stage-log.txt")
    }

    static func stageLog(_ line: String) {
        let stamped = "\(Date()) \(line)\n"
        guard let data = stamped.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: stageLogURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.synchronize()
        } else {
            try? data.write(to: stageLogURL)
        }
    }

    /// Áp trạng thái chia đôi vào engine (đọc lại ở mỗi lần
    /// chạy — engine khởi tạo mới cho từng lượt đọc).
    private func applyEngineBisect() {
        ClassicTextEngine.topCandidates = top3On ? 3 : 1
        switch langMode {
        case 1:
            LanguagePolicy.directLanguagesOverride =
                ["vi-VN", "en-US"]
        case 2:
            LanguagePolicy.directLanguagesOverride = ["en-US"]
        default:
            LanguagePolicy.directLanguagesOverride = nil
        }
    }

    private func loadStageLog() {
        stageLogText = (try? String(contentsOf: Self.stageLogURL,
                                    encoding: .utf8)) ?? ""
    }

    /// Cộng một dòng sự kiện Picker Probe kèm mốc giờ
    /// (HH:mm:ss) vào khung trên màn. Mọi callback của
    /// PickerProbe đều về main nên cộng thẳng vào @State.
    private func probeEvent(_ line: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        probeOutput += "[\(formatter.string(from: Date()))] \(line)\n"
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

                Section("Chẩn đoán crash (CI-FIX-6)") {
                    Toggle("CIDocumentEnhancer (nghi phạm H1)",
                           isOn: $enhancerOn)
                        .onChange(of: enhancerOn) { _, newValue in
                            ReceiptReader.documentEnhancerEnabled =
                                newValue
                        }
                    Toggle("topCandidates(3) (tắt = top-1 như bản cũ)",
                           isOn: $top3On)
                    Picker("Ngôn ngữ engine", selection: $langMode) {
                        Text("Hiện tại: vi-VT + en-US").tag(0)
                        Text("Bản cũ: vi-VN + en-US").tag(1)
                        Text("Chỉ en-US").tag(2)
                    }
                    Button("Đọc lại nhật ký giai đoạn") {
                        loadStageLog()
                    }
                    if !stageLogText.isEmpty {
                        Text(stageLogText)
                            .font(.caption2)
                            .textSelection(.enabled)
                        ShareLink(item: stageLogText) {
                            Label("Chia sẻ nhật ký giai đoạn",
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("Tự kiểm một chạm — Gate D (G5)") {
                    Button("Chạy tự kiểm (Phần A — 43 ảnh qua đường app)") {
                        runSelfCheck()
                    }
                    .disabled(selfCheckBusy)
                    Button("Gieo trạng thái vòng đời (Phần B)") {
                        let ok = BenchSelfCheck.seedLifecycle()
                        lifecycleStatus = ok
                            ? "Đã gieo B1+B2+B3 — hãy VUỐT GIẾT app rồi mở lại BenchShell, app tự đối chiếu."
                            : "Gieo thất bại: kho bền ghi lỗi."
                    }
                    Button("Nạp file chẩn đoán .ocrdiag.json (Phần C)") {
                        showDiagImporter = true
                    }
                    Button("Xuất file kết quả (1 file JSON)") {
                        resultFileURL = BenchSelfCheck.writeFinalResult(
                            deviceModel: UIDevice.current.model,
                            osVersion: UIDevice.current.systemVersion)
                    }
                    Button("Xoá tiến trình tự kiểm", role: .destructive) {
                        BenchSelfCheck.resetProgress()
                        selfCheckStatus = "Đã xoá tiến trình."
                        resultFileURL = nil
                    }
                    if !selfCheckStatus.isEmpty {
                        Text(selfCheckStatus).font(.caption2)
                            .textSelection(.enabled)
                    }
                    if !lifecycleStatus.isEmpty {
                        Text(lifecycleStatus).font(.caption2)
                            .textSelection(.enabled)
                    }
                    if !replayStatus.isEmpty {
                        Text(replayStatus).font(.caption2)
                            .textSelection(.enabled)
                    }
                    if let url = resultFileURL {
                        ShareLink(item: url) {
                            Label("Gửi file kết quả",
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .fileImporter(isPresented: $showDiagImporter,
                              allowedContentTypes: [.json],
                              allowsMultipleSelection: true) { result in
                    if case .success(let urls) = result {
                        var n = 0
                        for url in urls {
                            let scoped =
                                url.startAccessingSecurityScopedResource()
                            let data = try? Data(contentsOf: url)
                            if scoped {
                                url.stopAccessingSecurityScopedResource()
                            }
                            if let data,
                               BenchSelfCheck.replayAndStore(diagData: data) != nil {
                                n += 1
                            }
                        }
                        replayStatus = "Phần C: đã replay \(n) file chẩn đoán."
                    }
                }

                // Picker Probe: bộ chọn thư mục TRẦN — không
                // qua presenter của app, không gương, không
                // bookmark; chỉ trình picker và in MỌI sự
                // kiện lên khung dưới để phân biệt "present
                // bị nuốt" với "delegate không chạy" (ca
                // L-36/L-38). Không đụng đường tự kiểm A/B/D.
                Section("Picker Probe — thám tử bộ chọn thư mục (L-36)") {
                    Button {
                        probeEvent("anh bấm nút Mở bộ chọn (trần)")
                        PickerProbe.present { line in
                            probeEvent(line)
                        }
                    } label: {
                        Label("Mở bộ chọn thư mục (trần)",
                              systemImage: "folder.badge.questionmark")
                            .font(.body.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    if !probeOutput.isEmpty {
                        Text(probeOutput)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Xoá khung sự kiện", role: .destructive) {
                            probeOutput = ""
                        }
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
            .onAppear {
                ReceiptReader.documentEnhancerEnabled = enhancerOn
                applyEngineBisect()
                loadStageLog()
                // Gate D: mở lại sau lần giết ở Phần B -> tự
                // đối chiếu ngay; phiên Phần A chết dở -> báo
                // đích danh ảnh chết để anh chạy tiếp.
                if BenchSelfCheck.lifecycleSeeded() {
                    let items = BenchSelfCheck.verifyLifecycle()
                    lifecycleStatus = "Phần B sau giết app — "
                        + items.map { "\($0.id): \($0.verdict)" }
                            .joined(separator: " · ")
                }
                if let crashed = BenchSelfCheck.pendingCrash() {
                    selfCheckStatus = "Phiên trước chết ở ảnh \(crashed) — bấm Chạy tự kiểm để ghi CRASHED và chạy tiếp."
                }
            }
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
        applyEngineBisect()
        ReceiptReader.stageBreadcrumb = { step in
            BenchView.stageLog("stage \(step)")
        }
        BenchView.stageLog("file-begin \(name)")
        let directory = diagnosticsDirectory
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = ReceiptReader.read(ReadRequest(
                source: .photoLibrary,
                imageFileName: name,
                image: cg,
                diagnosticsDirectory: directory))
            BenchView.stageLog("file-end \(name)")
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

    // MARK: - Gate D Phần A: tự kiểm 43 ảnh (BenchSelfCheck)

    /// Chạy tuần tự trên hàng đợi nền; tiến trình ghi xuống
    /// đĩa theo từng ảnh trong BenchSelfCheck nên app chết
    /// giữa chừng vẫn tiếp tục được ở lần mở sau (marker ->
    /// CRASHED). Cấu hình engine theo đúng các công tắc bisect
    /// hiện tại của bench (mặc định = cấu hình app giao).
    private func runSelfCheck() {
        guard !selfCheckBusy else { return }
        guard let gt = BenchSelfCheck.loadGT() else {
            selfCheckStatus = "Không nạp được bench-gt.json trong bundle."
            return
        }
        selfCheckBusy = true
        applyEngineBisect()
        let names = imageNames
        let dir = diagnosticsDirectory
        DispatchQueue.global(qos: .userInitiated).async {
            var progress = BenchSelfCheck.loadProgress()
            if progress.startedAt.isEmpty {
                progress.startedAt =
                    ISO8601DateFormatter().string(from: Date())
                BenchSelfCheck.saveProgress(progress)
            }
            if let crashed = BenchSelfCheck.pendingCrash() {
                BenchSelfCheck.completeImage(
                    BenchSelfCheck.crashedEntry(crashed))
            }
            let done = Set(BenchSelfCheck.loadProgress()
                .entries.map { $0.file })
            for name in names where !done.contains(name) {
                BenchSelfCheck.beginImage(name)
                guard let cg = loadCGImage(name) else {
                    var e = BenchSelfCheck.crashedEntry(name)
                    e.scoreClass = "DIED"
                    e.arbiterStatus = "load-failed"
                    BenchSelfCheck.completeImage(e)
                    continue
                }
                let entry = BenchSelfCheck.readOne(
                    name: name, cg: cg, gt: gt.cases[name],
                    diagnosticsDirectory: dir)
                BenchSelfCheck.completeImage(entry)
                let count = BenchSelfCheck.loadProgress().entries.count
                DispatchQueue.main.async {
                    selfCheckStatus =
                        "Đang tự kiểm… \(count)/\(names.count)"
                }
            }
            DispatchQueue.main.async {
                selfCheckBusy = false
                let total = BenchSelfCheck.loadProgress().entries.count
                selfCheckStatus =
                    "Phần A xong: \(total)/\(names.count) ảnh. Đủ 4 phần thì bấm Xuất file kết quả."
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
            // CI-FIX-1 (cùng họ lỗi 3 của run #39 — lời gọi này
            // throw trên SDK hiện hành; BenchView chưa tới lượt
            // biên dịch ở run #39 vì build dừng ở app chính):
            // try? như BenchRunner đã biên dịch xanh (run #33).
            let langs = (try? VNRecognizeTextRequest
                .supportedRecognitionLanguages(for: .accurate,
                                               revision: rev)) ?? []
            out.append("classic/accurate/\(label): \(langs)")
        }
        out.append("classic/currentRevision: \(VNRecognizeTextRequest.currentRevision)")
        out.append("classic/supportedRevisions: \(VNRecognizeTextRequest.supportedRevisions)")
        let fast = (try? VNRecognizeTextRequest
            .supportedRecognitionLanguages(
                for: .fast, revision: VNRecognizeTextRequestRevision3)) ?? []
        out.append("classic/fast/Revision3: \(fast)")
        languageOutput = out.joined(separator: "\n")
        // Họ documents (Swift-native, iOS 26+): async — điền tiếp
        // vào cùng bản in khi Task xong. Hai dòng này giữ nhãn
        // CONFIRM-AT-COMPILE của LanguageProbe (chữ ký tra từ tài
        // liệu, đối chiếu SDK ở lần biên dịch CI đầu tiên).
        if #available(iOS 26.0, *) {
            Task {
                // CI-FIX-3 (run #41): supportedRecognitionLanguages
                // la thuoc tinh cua INSTANCE, khong phai type member
                // — phai tao instance truoc khi doc.
                let docLangs = await RecognizeDocumentsRequest()
                    .supportedRecognitionLanguages
                let textLangs = await RecognizeTextRequest()
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

/// Picker Probe — bộ chọn thư mục TRẦN của BenchShell (bậc 2
/// thang chẩn đoán Gói 1, ca L-2026-11-19-38): dựng thẳng
/// UIDocumentPickerViewController(forOpeningContentTypes:
/// [.folder], asCopy: false), delegate là coordinator giữ
/// tĩnh, trình bằng UIKit thuần từ view controller trên cùng.
/// TỰ CHỨA trong file bench — không dùng presenter, không
/// dùng MirrorSettings, không tạo bookmark, không gương:
/// mục đích duy nhất là quan sát thô các sự kiện của picker
/// trên đúng bản cài đã ký (phân biệt present-bị-nuốt /
/// picker-hiện-nhưng-Open-câm / delegate-chạy-được) qua khung
/// sự kiện in trên màn BenchView cho anh chụp lại.
enum PickerProbe {
    private static var activeCoordinator: Coordinator?

    static func present(report: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            guard activeCoordinator == nil else {
                report("present bị chặn: đang có một picker probe mở")
                return
            }
            guard let presenter = topPresenter() else {
                report("topPresenter = nil — không có cửa sổ để trình")
                return
            }
            let coordinator = Coordinator(report: report)
            activeCoordinator = coordinator
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [UTType.folder], asCopy: false)
            picker.delegate = coordinator
            picker.allowsMultipleSelection = false
            presenter.present(picker, animated: true)
            report("đã gọi present(picker) từ VC trên cùng")
            // Nhịp kiểm 0,6 s như presenter của app: phân
            // biệt picker đang hiện / đã xong qua delegate /
            // present bị nuốt. Nếu bị nuốt thì nhả chốt giữ
            // coordinator để anh bấm thử lại được ngay (khung
            // sự kiện vẫn còn nguyên dòng kết luận bị nuốt).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if picker.presentingViewController != nil {
                    report("sau 0,6s: picker CÓ presentingViewController — đang hiện")
                } else if PickerProbe.activeCoordinator === coordinator {
                    PickerProbe.activeCoordinator = nil
                    report("sau 0,6s: picker KHÔNG có presentingViewController — present bị nuốt, delegate sẽ không bao giờ chạy")
                } else {
                    report("sau 0,6s: picker đã kết thúc qua delegate")
                }
            }
        }
    }

    /// View controller trên cùng của cửa sổ khoá thuộc scene
    /// đang foreground — tự chứa ở đây, không mượn code app.
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
        var report: (String) -> Void

        init(report: @escaping (String) -> Void) {
            self.report = report
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            defer { PickerProbe.activeCoordinator = nil }
            guard let url = urls.first else {
                report("didPick NHƯNG urls RỖNG")
                return
            }
            report("didPick: \(url.lastPathComponent)")
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            defer { PickerProbe.activeCoordinator = nil }
            report("documentPickerWasCancelled — picker đã đóng qua đường huỷ")
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

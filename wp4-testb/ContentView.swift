import PhotosUI
import SwiftUI
import UIKit

/// Màn hình bản test engine (b): chọn 1 ảnh hoá đơn mẫu -> chạy engine
/// (b) ở 2 cấu hình đo (ảnh gốc / ảnh phái sinh — WP4-SPEC §2) -> hiện
/// văn bản thô + số đoạn/bảng/danh sách + thời gian, copy được để dán
/// vào hồ sơ chấm điểm. Không lưu gì, không parser — việc chấm điểm
/// (đưa dòng qua parser + đối chiếu đáp án) làm ở hồ sơ WP4-GATE /
/// SCORECARD, không làm trong app test.
struct ContentView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var status = "Chưa chọn ảnh"
    @State private var originalReport = ""
    @State private var derivedReport = ""
    @State private var running = false

    var body: some View {
        NavigationStack {
            List {
                Section("Bài test engine (b) — WP4 bước 3") {
                    Text("Chọn ảnh 1 hoá đơn mẫu (001/002/003 hoặc tờ Sam's chụp camera cho mẫu 002-C), app chạy RecognizeDocumentsRequest trên ảnh gốc và ảnh phái sinh, hiện văn bản thô để copy về chấm điểm. App test này không lưu dữ liệu.")
                        .font(.callout)
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Chọn ảnh hoá đơn")
                    }
                    if pickedImage != nil {
                        Button(running ? "Đang đọc…" : "Chạy engine (b) — 2 cấu hình") {
                            runBoth()
                        }
                        .disabled(running)
                    }
                    Text(status)
                }
                if !originalReport.isEmpty {
                    Section("Cấu hình 1 — ảnh gốc") {
                        reportView(originalReport)
                    }
                }
                if !derivedReport.isEmpty {
                    Section("Cấu hình 2 — ảnh phái sinh") {
                        reportView(derivedReport)
                    }
                }
                Section("Máy của anh") {
                    Text("iOS: \(UIDevice.current.systemVersion)")
                    Text("Thiết bị: \(UIDevice.current.model)")
                    Text("Bundle: \(Bundle.main.bundleIdentifier ?? "?")")
                }
            }
            .navigationTitle("Test B — Engine iOS 26")
            .onChange(of: pickerItem) { _, newItem in
                loadImage(newItem)
            }
        }
    }

    private func reportView(_ text: String) -> some View {
        Group {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            Button("Copy toàn bộ") {
                UIPasteboard.general.string = text
            }
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    status = "Không đọc được ảnh đã chọn"
                    return
                }
                pickedImage = image
                originalReport = ""
                derivedReport = ""
                status = "Đã chọn ảnh \(Int(image.size.width))×\(Int(image.size.height)) — bấm Chạy engine (b)"
            } catch {
                status = "Chọn ảnh thất bại: \(error.localizedDescription)"
            }
        }
    }

    private func runBoth() {
        guard let image = pickedImage else { return }
        running = true
        status = "Đang chạy…"
        Task {
            var lines: [String] = []
            do {
                let r = try await EngineB.recognize(image)
                lines.append(Self.header("GỐC", r))
                lines.append(contentsOf: r.lines)
                originalReport = lines.joined(separator: "\n")
            } catch {
                originalReport = "LỖI (ảnh gốc): \(error.localizedDescription)"
            }
            if let derived = EngineB.derivedImage(image) {
                do {
                    let r = try await EngineB.recognize(derived)
                    var dLines = [Self.header("PHÁI SINH", r)]
                    dLines.append(contentsOf: r.lines)
                    derivedReport = dLines.joined(separator: "\n")
                } catch {
                    derivedReport = "LỖI (ảnh phái sinh): \(error.localizedDescription)"
                }
            } else {
                derivedReport = "Không tạo được ảnh phái sinh (không thấy tứ giác đạt ngưỡng) — cấu hình phái sinh không đo được trên ảnh này."
            }
            status = "Đã chạy xong — copy 2 mục kết quả về hồ sơ chấm điểm."
            running = false
        }
    }

    private static func header(_ label: String, _ r: EngineB.Result) -> String {
        String(format: "=== (b) %@ — %.2fs — đoạn %d · bảng %d · danh sách %d · dòng %d ===",
               label, r.elapsedSeconds, r.paragraphCount, r.tableCount,
               r.listCount, r.lines.count)
    }
}

import SwiftUI

/// Màn Bench — cố ý tối thiểu: danh sách ca (sẵn sàng / THIẾU),
/// danh sách cấu hình, một nút chạy toàn bộ, tiến độ theo
/// (ảnh × cấu hình), và ShareLink xuất đúng một file JSON.
struct BenchView: View {
    @State private var isRunning = false
    @State private var completed = 0
    @State private var total = 0
    @State private var currentLabel = ""
    @State private var exportURL: URL? = nil
    @State private var errorText: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Ảnh bench") {
                    ForEach(BenchCatalog.images) { image in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: image.isAvailable
                                  ? "checkmark.circle.fill"
                                  : "exclamationmark.triangle.fill")
                                .foregroundStyle(image.isAvailable
                                                 ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(image.id) · \(image.form)/\(image.difficulty) · \(image.origin)")
                                    .font(.headline)
                                Text(image.statusNote)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Cấu hình thi đấu") {
                    ForEach(BenchCatalog.configs) { config in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(config.name).font(.headline)
                            Text(config.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Chạy đo") {
                    if isRunning || total > 0 {
                        ProgressView(value: Double(completed),
                                     total: Double(max(total, 1)))
                        Text(currentLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(completed)/\(total) lượt (ảnh × cấu hình)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        start()
                    } label: {
                        Label(isRunning ? "Đang chạy đo…" : "Chạy đo toàn bộ",
                              systemImage: "play.circle.fill")
                    }
                    .disabled(isRunning)

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Xuất file JSON kết quả",
                                  systemImage: "square.and.arrow.up")
                        }
                        Text(exportURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("BenchApp — Đo OCR")
        }
    }

    private func start() {
        isRunning = true
        errorText = nil
        exportURL = nil
        completed = 0
        total = BenchCatalog.availableImages.count * BenchCatalog.configs.count
        currentLabel = "Đang nạp ảnh bench…"
        Task {
            do {
                let url = try await BenchRunner.runAll { done, all, label in
                    completed = done
                    total = all
                    currentLabel = label
                }
                exportURL = url
                currentLabel = "Đo xong — hãy xuất file JSON."
            } catch {
                errorText = error.localizedDescription
                currentLabel = "Đo lỗi."
            }
            isRunning = false
        }
    }
}

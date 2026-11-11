import Foundation
import ImageIO
import UIKit
import Vision

/// Điều phối buổi đo: nạp MỘT CGImage cho mỗi ảnh bench (mọi cấu
/// hình dùng đúng cùng CGImage đó), chạy A0–A3, gói JSON schema v1
/// và ghi ra thư mục tạm để ShareLink xuất đi. Không đáp án nào đi
/// qua đây — file đo chỉ chứa gt_id (BENCH-JSON-SPEC §6.5).
enum BenchRunner {
    struct LoadedImage {
        var definition: BenchImageDefinition
        var cgImage: CGImage
    }

    enum BenchError: Error, CustomStringConvertible {
        case missingResource(String)
        case cannotDecode(String)
        case noImages

        var description: String {
            switch self {
            case .missingResource(let id):
                return "Không tìm thấy file ảnh nhúng cho ca \(id) trong bundle."
            case .cannotDecode(let id):
                return "Không giải mã được ảnh nhúng của ca \(id) thành CGImage."
            case .noImages:
                return "Không có ca bench nào sẵn sàng."
            }
        }
    }

    static func loadImages() throws -> [LoadedImage] {
        var loaded: [LoadedImage] = []
        for definition in BenchCatalog.availableImages {
            guard let name = definition.resourceName,
                  let url = Bundle.main.url(forResource: name,
                                            withExtension: definition.resourceExtension)
            else {
                throw BenchError.missingResource(definition.id)
            }
            let data = try Data(contentsOf: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw BenchError.cannotDecode(definition.id)
            }
            loaded.append(LoadedImage(definition: definition, cgImage: cgImage))
        }
        guard !loaded.isEmpty else { throw BenchError.noImages }
        return loaded
    }

    static func supportedLanguages() -> BenchJSONSupportedLanguages {
        let classic = (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
            for: .accurate, revision: VNRecognizeTextRequestRevision3))
            ?? ["vi-VN", "en-US"]
        var documents: [String] = []
        if #available(iOS 26.0, *) {
            documents = RecognizeDocumentsRequest()
                .supportedRecognitionLanguages
                .map { $0.languageCode?.identifier ?? $0.minimalIdentifier }
        }
        return BenchJSONSupportedLanguages(visionClassic: classic,
                                           recognizeDocuments: documents)
    }

    static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// Chạy toàn bộ (ảnh sẵn sàng × A0–A3). progress được gọi trên
    /// MainActor sau mỗi (ảnh × cấu hình): (đã xong, tổng, nhãn hiện tại).
    static func runAll(
        progress: @escaping @MainActor (Int, Int, String) -> Void
    ) async throws -> URL {
        let loaded = try loadImages()
        let configs = BenchCatalog.configs
        let total = loaded.count * configs.count
        var completed = 0

        var jsonImages: [BenchJSONImage] = []
        var runs: [BenchJSONRun] = []

        for image in loaded {
            jsonImages.append(image.definition.json(
                widthPX: image.cgImage.width,
                heightPX: image.cgImage.height))

            for config in configs {
                await progress(completed, total,
                               "\(image.definition.id) × \(config.id)")
                let runData: BenchRunData
                switch config.id {
                case "A0":
                    let cgImage = image.cgImage
                    runData = await Task.detached(priority: .userInitiated) {
                        BenchLegacyOCR.run(on: cgImage)
                    }.value
                case "A1":
                    let cgImage = image.cgImage
                    runData = await Task.detached(priority: .userInitiated) {
                        ScanView.benchClassicRun(on: cgImage)
                    }.value
                case "A2":
                    let cgImage = image.cgImage
                    runData = await Task.detached(priority: .userInitiated) {
                        await ScanView.benchMergedRun(on: cgImage)
                    }.value
                default: // A3
                    let cgImage = image.cgImage
                    runData = await Task.detached(priority: .userInitiated) {
                        await ScanView.benchFullRun(on: cgImage)
                    }.value
                }
                runs.append(BenchJSONRun(
                    imageID: image.definition.id,
                    configID: config.id,
                    passes: runData.allPassesInJSONOrder.map(BenchJSONPass.init)))
                completed += 1
                await progress(completed, total,
                               "Đã xong \(image.definition.id) × \(config.id)")
            }
        }

        let document = BenchJSONDocument(
            generatedAt: isoTimestamp(Date()),
            app: BenchJSONApp(build: BenchCatalog.appBuild,
                              parserVersion: currentParserVersion),
            device: BenchJSONDevice(model: UIDevice.current.model,
                                    ios: UIDevice.current.systemVersion),
            supportedLanguages: supportedLanguages(),
            configs: configs.map(\.json),
            images: jsonImages,
            runs: runs)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)

        let stamp = isoTimestamp(Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sohoadon-bench-\(stamp).json")
        try data.write(to: url, options: [.atomic])
        return url
    }
}

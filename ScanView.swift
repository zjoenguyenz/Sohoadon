import SwiftUI
import VisionKit
import Vision
import PhotosUI
import UIKit

/// Bản nháp sau khi đọc xong 1 hoá đơn — đưa sang màn Review để anh kiểm/sửa rồi mới lưu.
struct ScanDraft: Identifiable {
    let id = UUID()
    var result: ParseResult
    var imageFileName: String
    /// WP2 bước 2: nguồn nạp (ACCOUNTING-SPEC F3) — ScanView ghi theo đúng
    /// đường vào (.camera cho quét tài liệu, .photoLibrary cho chọn ảnh);
    /// ReviewView.save() chép vào Receipt.sourceType lúc lưu. Mặc định
    /// .unknown để mọi điểm dựng draft khác (nếu có) vẫn biên dịch được.
    var sourceType: SourceType = .unknown
}

/// Màn Chụp: camera quét tài liệu của Apple (VisionKit) -> lưu ảnh gốc vào
/// thư mục của app -> đọc chữ bằng Vision NGAY TRÊN MÁY (offline) -> Parser
/// -> màn Review. Không có bước nào gửi ảnh ra ngoài iPhone.
struct ScanView: View {
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isProcessing = false
    @State private var statusText: String? = nil
    @State private var errorText: String? = nil
    @State private var draft: ScanDraft? = nil

    private var cameraSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Chụp hoá đơn giấy, app tự đọc: tiệm, ngày, từng món, tổng tiền và đuôi thẻ — rồi gợi ý Cá nhân / Business theo thẻ đã đăng ký.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isProcessing {
                    ProgressView()
                    Text(statusText ?? "Đang đọc hoá đơn…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        errorText = nil
                        showCamera = true
                    } label: {
                        Label("Quét hoá đơn", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!cameraSupported)
                    .padding(.horizontal)

                    Button {
                        errorText = nil
                        showPhotoPicker = true
                    } label: {
                        Label("Chọn ảnh có sẵn", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal)

                    if !cameraSupported {
                        Text("Máy này không hỗ trợ quét tài liệu (thường là máy ảo) — anh dùng nút Chọn ảnh có sẵn.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                if let statusText, !isProcessing {
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
                Text("Đọc ngay trên máy — ảnh hoá đơn không rời khỏi iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Chụp Hoá Đơn")
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView(
                    onScan: { scan in
                        showCamera = false
                        guard scan.pageCount > 0 else {
                            errorText = "Chưa chụp được trang nào — anh thử lại giúp."
                            return
                        }
                        // Build 1: xử lý trang đầu (hoá đơn dài nhiều trang -> bản sau).
                        process(image: scan.imageOfPage(at: 0), source: .camera)
                    },
                    onCancel: { showCamera = false },
                    onError: { error in
                        showCamera = false
                        errorText = "Quét thất bại: \(error.localizedDescription)"
                    }
                )
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        process(image: image, source: .photoLibrary)
                    } else {
                        errorText = "Không mở được ảnh đã chọn."
                    }
                    pickerItem = nil
                }
            }
            .sheet(item: $draft) { d in
                ReviewView(draft: d) { draft = nil }
            }
        }
    }

    // MARK: Pipeline: lưu ảnh gốc -> OCR trên máy -> Parser -> bản nháp

    private func process(image: UIImage, source: SourceType) {
        guard let fileName = ImageStore.saveJPEG(image) else {
            errorText = "Không lưu được ảnh gốc vào máy — anh kiểm tra dung lượng trống giúp."
            return
        }
        isProcessing = true
        statusText = "Đang đọc hoá đơn…"
        errorText = nil
        recognizeLines(in: image) { lines in
            DispatchQueue.main.async {
                isProcessing = false
                if lines.isEmpty {
                    statusText = nil
                    errorText = "Không đọc được chữ nào trong ảnh — anh chụp lại rõ hơn, đủ sáng giúp."
                    return
                }
                let result = ReceiptParser.parse(lines: lines)
                statusText = nil
                draft = ScanDraft(result: result, imageFileName: fileName, sourceType: source)
            }
        }
    }

    /// Vision VNRecognizeTextRequest — API cổ điển, ổn định từ iOS 13.
    /// (Không dùng RecognizeDocumentsRequest của iOS 26 — xem BUILD1-NOTES.)
    private func recognizeLines(in image: UIImage, completion: @escaping ([OCRLine]) -> Void) {
        // Chuẩn hoá hướng ảnh trước khi OCR: ảnh từ thư viện có thể mang hướng EXIF
        // mà cgImage bỏ qua — không chuẩn hoá thì Vision đọc chữ bị xoay, ra rác.
        let upright: UIImage
        if image.imageOrientation == .up {
            upright = image
        } else {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            upright = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        }
        guard let cgImage = upright.cgImage else {
            completion([])
            return
        }
        let request = VNRecognizeTextRequest { req, _ in
            let rawResults: [VNObservation] = req.results ?? []
            let observations = rawResults.compactMap { $0 as? VNRecognizedTextObservation }
            // Vision dùng gốc toạ độ dưới-trái: sắp xếp dòng từ trên xuống.
            let sorted = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            let lines: [OCRLine] = sorted.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return OCRLine(text: candidate.string, confidence: Double(candidate.confidence))
            }
            completion(lines)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        // Hoá đơn đầy mã số — tắt tự sửa chính tả để khỏi "sửa" nhầm mã/tiền.
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion([])
            }
        }
    }
}

// MARK: - Bọc VNDocumentCameraViewController cho SwiftUI

struct DocumentCameraView: UIViewControllerRepresentable {
    var onScan: (VNDocumentCameraScan) -> Void
    var onCancel: () -> Void
    var onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentCameraView
        init(parent: DocumentCameraView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan(scan)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }
    }
}

import SwiftUI
import VisionKit
import Vision
import CoreImage
import PhotosUI
import UIKit
import PDFKit
import UniformTypeIdentifiers

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
    /// WP3: tên file gốc như anh chọn trong Files (vd "sams-club.pdf") —
    /// ReviewView.save() chép vào Receipt.sourceFileName. Chỉ đường nạp
    /// file mới có; camera/Photos để nil.
    var sourceFileName: String? = nil
    /// WP3: file bằng chứng gốc đi kèm ngoài imageFileName — với PDF là
    /// chính file PDF đã lưu nguyên byte vào ReceiptImages (khi lớp chữ
    /// đọc thẳng thì imageFileName CŨNG là file PDF đó; khi render->OCR
    /// thì imageFileName là JPEG render còn PDF nằm ở đây).
    /// ReviewView.save() chép vào Receipt.originalImageFileNames.
    var originalFileNames: [String] = []
    /// WP3 bước 2: true CHỈ khi rawText trích thẳng từ lớp chữ của PDF
    /// (đường textLayerLines). PDF không lớp chữ -> render -> OCR thì
    /// false dù sourceType vẫn là .pdfImport. Nhãn F3 ở Kiểm Lại/Chi Tiết
    /// quyết theo cờ này (CODE-AUDIT F3 mục 3: nhãn phải nói đúng đường
    /// nào sinh ra chữ). ReviewView.save() chép vào Receipt.
    var rawTextIsPDFTextLayer: Bool = false
}

/// Màn Chụp: camera quét tài liệu của Apple (VisionKit) -> lưu ảnh gốc vào
/// thư mục của app -> đọc chữ bằng Vision NGAY TRÊN MÁY (offline) -> Parser
/// -> màn Review. Không có bước nào gửi ảnh ra ngoài iPhone.
/// WP3 thêm đường nạp file từ Files: PDF có lớp chữ -> trích thẳng vào cùng
/// bộ bóc tách (không qua OCR); PDF không lớp chữ -> render trang -> OCR;
/// file ảnh -> OCR như đường chọn ảnh.
struct ScanView: View {
    /// WP3 bước 2: file anh mở bằng "Mở bằng Sổ Hóa Đơn" / Share Sheet —
    /// ContentView nhận qua onOpenURL rồi truyền xuống đây; ScanView hút
    /// vào CÙNG importQueue của đường Files (không có đường nạp thứ hai).
    @Binding var externalImportURLs: [URL]
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isProcessing = false
    @State private var statusText: String? = nil
    @State private var errorText: String? = nil
    @State private var draft: ScanDraft? = nil
    /// WP3: hàng chờ nạp NHIỀU file một lúc (Master Plan WP3) — xử lý lần
    /// lượt từng file, mỗi file một màn Review; đóng Review thì nạp tiếp.
    @State private var importQueue: [URL] = []

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

                    Button {
                        errorText = nil
                        showFileImporter = true
                    } label: {
                        Label("Nạp file (PDF / ảnh tải về)", systemImage: "folder")
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
            // WP3: nạp từ Files — CHỌN FILE (không phải chọn thư mục; bài học
            // Test 0 ở TEAM.md lỗi #3 là chọn thư mục của chính app bị huỷ im
            // lặng — chế độ chọn file này vẫn phải có bài kiểm riêng trên máy
            // anh ở mốc M1, ghi ở WP3-GATE.md). Cho chọn nhiều file một lúc.
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    importQueue = urls
                    processNextImportedFile()
                case .failure(let error):
                    errorText = "Không nạp được file: \(error.localizedDescription)"
                }
            }
            .sheet(item: $draft, onDismiss: { processNextImportedFile() }) { d in
                ReviewView(draft: d) { draft = nil }
            }
            // WP3 bước 2: file tới qua onOpenURL trong lúc màn Chụp đã
            // hiện -> hút ngay vào hàng chờ chung.
            .onChange(of: externalImportURLs) { _, _ in consumeExternalImports() }
            // Lần đầu màn Chụp hiện: hút file đã chờ sẵn (anh mở file khi
            // app đang khoá Face ID / đang ở tab khác) + quét thư mục
            // Inbox phòng trường hợp hệ thống chép file vào trước khi
            // onOpenURL kịp chạy (khởi động lạnh).
            .onAppear {
                consumeExternalImports()
                sweepInbox()
            }
        }
    }

    /// Đổ URL từ onOpenURL vào hàng chờ nạp chung rồi xoá danh sách chờ —
    /// điểm nạp DUY NHẤT vẫn là processNextImportedFile/processImportedFile.
    private func consumeExternalImports() {
        guard !externalImportURLs.isEmpty else { return }
        importQueue.append(contentsOf: externalImportURLs)
        externalImportURLs = []
        processNextImportedFile()
    }

    /// Thư mục Documents/Inbox là nơi iOS chép file khi app được mở bằng
    /// một file mà không mở-tại-chỗ. File còn sót ở đó (onOpenURL chưa
    /// chạy hoặc app bị giết giữa chừng) được nạp nốt ở đây; bản sao
    /// Inbox bị xoá ngay trong processImportedFile sau khi đọc xong
    /// dữ liệu, nên quét lại không nạp trùng.
    private func sweepInbox() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let inbox = docs.appendingPathComponent("Inbox", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else { return }
        let stray = files.filter { !$0.hasDirectoryPath }
        guard !stray.isEmpty else { return }
        importQueue.append(contentsOf: stray)
        processNextImportedFile()
    }

    // MARK: Pipeline: lưu ảnh gốc -> OCR trên máy -> Parser -> bản nháp

    private func process(image: UIImage, source: SourceType,
                         sourceFileName: String? = nil,
                         originalFileNames: [String] = []) {
        guard let fileName = ImageStore.saveJPEG(image) else {
            errorText = "Không lưu được ảnh gốc vào máy — anh kiểm tra dung lượng trống giúp."
            processNextImportedFile()
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
                    processNextImportedFile()
                    return
                }
                let result = ReceiptParser.parse(lines: lines)
                statusText = nil
                draft = ScanDraft(result: result, imageFileName: fileName, sourceType: source,
                                  sourceFileName: sourceFileName, originalFileNames: originalFileNames)
            }
        }
    }

    // MARK: - WP3: nạp file từ Files (CODE-AUDIT F1)

    /// Lấy file tiếp theo trong hàng chờ — chỉ chạy khi không có bản nháp
    /// nào đang mở và không có OCR nào đang chạy. Được gọi từ: kết quả
    /// fileImporter, lúc đóng màn Review (onDismiss), và các nhánh lỗi của
    /// đường nạp file (để một file hỏng không chặn cả lô).
    private func processNextImportedFile() {
        guard draft == nil, !isProcessing, !importQueue.isEmpty else { return }
        let url = importQueue.removeFirst()
        processImportedFile(url: url)
    }

    private func processImportedFile(url: URL) {
        // File nằm ngoài sandbox: mở quyền truy cập bảo mật và LUÔN đóng
        // trong cùng lượt gọi này. Mọi lần đọc file đều ĐỒNG BỘ tại đây —
        // đường OCR bất đồng bộ phía sau chỉ dùng UIImage + JPEG đã lưu
        // trong app, không chạm lại URL này nữa.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorText = "Không đọc được file \(url.lastPathComponent)."
            processNextImportedFile()
            return
        }
        // File do hệ thống chép vào Documents/Inbox của app: dữ liệu đã
        // nằm trong bộ nhớ (và PDF sẽ được lưu nguyên byte vào
        // ReceiptImages ở bước sau) nên xoá bản sao Inbox ngay — để sót
        // là lần mở sau quét Inbox sẽ nạp trùng tờ này. File mở-tại-chỗ
        // từ Files KHÔNG nằm trong Inbox -> tuyệt đối không đụng vào
        // file gốc của anh.
        removeInboxCopyIfNeeded(url)
        if url.pathExtension.lowercased() == "pdf" {
            processImportedPDF(data: data, sourceFileName: url.lastPathComponent)
        } else if let image = UIImage(data: data) {
            process(image: image, source: .fileImport, sourceFileName: url.lastPathComponent)
        } else {
            errorText = "File \(url.lastPathComponent) không phải PDF hay ảnh đọc được."
            processNextImportedFile()
        }
    }

    /// Xoá `url` CHỈ khi nó nằm trong Documents/Inbox của chính app.
    private func removeInboxCopyIfNeeded(_ url: URL) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let inboxPath = docs.appendingPathComponent("Inbox", isDirectory: true).standardizedFileURL.path
        if url.standardizedFileURL.path.hasPrefix(inboxPath + "/") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func processImportedPDF(data: Data, sourceFileName: String) {
        // Bằng chứng gốc lưu TRƯỚC, nguyên byte (CODE-AUDIT F1 mục 5) —
        // lưu hỏng thì báo lỗi thật, không đi tiếp như đã có bằng chứng.
        guard let storedPDFName = ImageStore.saveFile(data: data, fileExtension: "pdf") else {
            errorText = "Không lưu được file PDF gốc vào máy — anh kiểm tra dung lượng trống giúp."
            processNextImportedFile()
            return
        }
        if let lines = textLayerLines(pdfData: data) {
            // Lớp chữ là chữ thật do hệ thống của tiệm tạo ra — không phải
            // chữ đoán — nên độ tin cậy 1.0 (CODE-AUDIT F1 mục 4). Kiểm
            // chứng số học vẫn chạy đủ trong ReceiptParser.validate();
            // độ tin cậy tự nó KHÔNG duyệt được tờ nào (Master Plan §5.5).
            // File PDF chính là bằng chứng: imageFileName trỏ thẳng tới
            // nó, các màn hiển thị render trang 1 qua ImageStore.load.
            let result = ReceiptParser.parse(lines: lines)
            draft = ScanDraft(result: result, imageFileName: storedPDFName,
                              sourceType: .pdfImport, sourceFileName: sourceFileName,
                              originalFileNames: [storedPDFName],
                              rawTextIsPDFTextLayer: true)
            return
        }
        // Không có lớp chữ (PDF là ảnh scan): render trang 1 -> đường OCR.
        // PDF gốc vẫn là bằng chứng chính (originalFileNames); JPEG render
        // là nguồn đọc. Hoá đơn PDF nhiều trang -> xử lý nhiều trang ở WP8;
        // bước này giữ đúng giới hạn 1 trang như Build 1 và ghi rõ ở cổng.
        guard let doc = PDFDocument(data: data), doc.pageCount > 0,
              let image = renderPageImage(doc.page(at: 0)) else {
            errorText = "PDF không có lớp chữ và không render được trang nào để đọc."
            processNextImportedFile()
            return
        }
        process(image: image, source: .pdfImport, sourceFileName: sourceFileName,
                originalFileNames: [storedPDFName])
    }

    /// Trích lớp chữ nhúng trong PDF (PDFKit — có từ iOS 11, không phải
    /// framework lạ lúc khởi động; chỉ chạm khi anh bấm nạp file, đúng
    /// luật TEAM.md #1). Trả nil khi PDF không chứa dòng chữ nào — đó là
    /// tín hiệu rẽ sang đường render->OCR, KHÔNG phải lỗi.
    /// Thứ tự dòng = thứ tự nội dung từng trang (page.string); với hoá đơn
    /// do máy tạo thì đó là thứ tự đọc (CODE-AUDIT F1 mục 3). Cùng bộ
    /// ReceiptParser như mọi đường khác — không có parser thứ hai.
    private func textLayerLines(pdfData: Data) -> [OCRLine]? {
        guard let doc = PDFDocument(data: pdfData) else { return nil }
        var lines: [OCRLine] = []
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index), let text = page.string else { continue }
            for rawLine in text.components(separatedBy: .newlines) {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    lines.append(OCRLine(text: trimmed, confidence: 1.0))
                }
            }
        }
        return lines.isEmpty ? nil : lines
    }

    /// Render 1 trang PDF thành ảnh ~200 dpi cho đường OCR. Phép biến đổi
    /// lật trục Y theo mẫu chuẩn của Quartz (PDF gốc toạ độ dưới-trái,
    /// ảnh bitmap trên-trái) — hướng ảnh render phải được kiểm trên máy ở
    /// mốc M1 (ghi ở WP3-GATE.md, mục chưa kiểm chứng).
    private func renderPageImage(_ page: PDFPage?) -> UIImage? {
        guard let page = page else { return nil }
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scaleFactor = 200.0 / 72.0
        let size = CGSize(width: bounds.width * scaleFactor, height: bounds.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: size.width / bounds.width, y: -size.height / bounds.height)
            page.draw(with: .cropBox, to: cg)
        }
    }

    // MARK: - WP4 ứng viên (a): Vision cổ điển + ráp hàng F2a + cắt lát F2c
    // + tiền xử lý ảnh phái sinh (bước 2: phát hiện tứ giác -> nắn
    // perspective -> tăng tương phản — TOP-APPS-RESEARCH ý #3, WP4-SPEC §1).
    // (Đặc tả đo + luật chọn thắng/thua: WP4-SPEC.md. Ảnh GỐC không bao
    //  giờ bị sửa: process() đã lưu JPEG gốc TRƯỚC khi đọc; phái sinh chỉ
    //  tồn tại trong bộ nhớ ở đường đọc này, không lưu, không thay gốc.)

    /// Một mảnh chữ Vision kèm hộp toạ độ chuẩn hoá (gốc dưới-trái) trong
    /// KHÔNG GIAN ẢNH ĐẦY ĐỦ — mảnh của lát cắt đã quy đổi về trước khi ráp.
    struct OCRFrag {
        var text: String
        var confidence: Double
        var box: CGRect
    }

    /// Vision VNRecognizeTextRequest — API cổ điển, ổn định từ iOS 13.
    /// (Ứng viên (b) RecognizeDocumentsRequest của iOS 26 thi đấu ở bản test
    /// pipeline RIÊNG — WP4-SPEC.md; không đưa vào bản chính ở bước này.)
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
        DispatchQueue.global(qos: .userInitiated).async {
            // Cấu hình đo của ứng viên (a) (WP4-SPEC §2): đọc trên ảnh
            // PHÁI SINH khi cờ bật và phái sinh tạo được; mọi lỗi ở tầng
            // phái sinh đều fail-open về ảnh gốc — không có đường nào mà
            // tiền xử lý hỏng lại làm mất lượt đọc.
            let ocrImage = Self.useDerivedImage
                ? (Self.derivedOCRImage(cgImage) ?? cgImage)
                : cgImage
            let frags = Self.collectFragments(cgImage: ocrImage)
            let lines = Self.mergeRows(Self.dedupeOverlap(frags))
            completion(lines)
        }
    }

    /// WP4-SPEC §2: hai cấu hình đo của TỪNG ứng viên là "đọc trên ảnh
    /// gốc" và "đọc trên ảnh phái sinh" — cờ này là công tắc để bước 3
    /// chạy thi đấu hai cấu hình trên cùng một bản code. Bản trình cổng
    /// giữ `true`: phái sinh chỉ được dùng khi phát hiện được tứ giác đủ
    /// tin cậy (xem derivedOCRImage), còn lại tự rơi về ảnh gốc.
    private static let useDerivedImage = true

    /// Tạo ảnh PHÁI SINH trong bộ nhớ để đọc (không bao giờ lưu):
    /// VNDetectRectanglesRequest tìm tứ giác hoá đơn -> CIPerspective-
    /// Correction nắn thẳng -> CIColorControls bỏ màu + tăng tương phản.
    /// Trả nil (= dùng ảnh gốc) khi: không thấy tứ giác nào đạt ngưỡng
    /// tin cậy, hoặc bất kỳ bước lọc nào lỗi. Ngưỡng 0.5 và hệ số tương
    /// phản 1.1 là GIÁ TRỊ KHỞI ĐIỂM cho bước 3 đo trên bộ mẫu — chưa
    /// có bằng chứng chúng tối ưu, không được đọc là "đã tinh chỉnh".
    /// [CHƯA KIỂM CHỨNG trên máy: VNDetectRectanglesRequest + phép đổi
    /// toạ độ Vision (gốc dưới-trái, chuẩn hoá) sang toạ độ CI (gốc
    /// dưới-trái, điểm ảnh) — cùng gốc nên chỉ nhân với kích thước ảnh;
    /// bài kiểm thật ở bước 3 / mốc M1.]
    private static func derivedOCRImage(_ cgImage: CGImage) -> CGImage? {
        let detect = VNDetectRectanglesRequest()
        detect.minimumConfidence = 0.5
        detect.maximumObservations = 1
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([detect])
        } catch {
            return nil
        }
        guard let quad = (detect.results ?? []).first else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        func ciPoint(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * w, y: p.y * h)
        }
        let source = CIImage(cgImage: cgImage)
        guard let perspective = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        perspective.setValue(source, forKey: kCIInputImageKey)
        perspective.setValue(ciPoint(quad.topLeft), forKey: "inputTopLeft")
        perspective.setValue(ciPoint(quad.topRight), forKey: "inputTopRight")
        perspective.setValue(ciPoint(quad.bottomLeft), forKey: "inputBottomLeft")
        perspective.setValue(ciPoint(quad.bottomRight), forKey: "inputBottomRight")
        guard let corrected = perspective.outputImage else { return nil }
        guard let enhance = CIFilter(name: "CIColorControls") else { return nil }
        enhance.setValue(corrected, forKey: kCIInputImageKey)
        enhance.setValue(NSNumber(value: 0.0), forKey: kCIInputSaturationKey)
        enhance.setValue(NSNumber(value: 1.1), forKey: kCIInputContrastKey)
        enhance.setValue(NSNumber(value: 0.0), forKey: kCIInputBrightnessKey)
        guard let output = enhance.outputImage else { return nil }
        let context = CIContext(options: nil)
        return context.createCGImage(output, from: output.extent)
    }

    /// Trích mảnh chữ từ ảnh đầy đủ. F2c: ảnh RẤT cao (tỉ lệ cao/rộng > 3.0
    /// và cao > 1600px — dạng hoá đơn dài như Mẫu 002) được cắt thành lát
    /// dọc ~1600px chồng nhau 200px, OCR từng lát, rồi quy đổi hộp của mỗi
    /// mảnh về toạ độ ảnh đầy đủ TRƯỚC khi ráp hàng. Ngoài ngưỡng đó: 1 lượt
    /// OCR như cũ. handler.perform là ĐỒNG BỘ nên vòng lát chạy tuần tự
    /// trong hàng đợi nền — không có request nào chạy song song.
    private static func collectFragments(cgImage: CGImage) -> [OCRFrag] {
        let w = cgImage.width
        let h = cgImage.height
        guard h > 1600, Double(h) / Double(max(w, 1)) > 3.0 else {
            return ocrFragments(tile: cgImage, tileTopPx: 0, tileHeightPx: h, fullHeightPx: h)
        }
        var all: [OCRFrag] = []
        let tileHeight = 1600
        let overlap = 200
        let step = tileHeight - overlap
        var top = 0
        while top < h {
            let th = min(tileHeight, h - top)
            if let tile = cgImage.cropping(to: CGRect(x: 0, y: top, width: w, height: th)) {
                all += ocrFragments(tile: tile, tileTopPx: top, tileHeightPx: th, fullHeightPx: h)
            }
            if top + th >= h { break }
            top += step
        }
        return all
    }

    /// OCR 1 lát (hoặc cả ảnh khi không cắt) và quy đổi hộp về ảnh đầy đủ.
    /// Trục Y: Vision dùng gốc dưới-trái TRONG lát; lát bắt đầu ở tileTopPx
    /// tính từ ĐỈNH ảnh đầy đủ (toạ độ cắt của CGImage) — công thức dưới
    /// đổi cạnh-trên của hộp thành khoảng cách từ đỉnh ảnh đầy đủ rồi mới
    /// lật về gốc dưới-trái chuẩn hoá. [Hướng cắt CGImage + phép quy đổi
    /// này CHƯA KIỂM CHỨNG trên máy — bài kiểm mốc M1/WP4 bước 3.]
    private static func ocrFragments(tile: CGImage, tileTopPx: Int, tileHeightPx: Int, fullHeightPx: Int) -> [OCRFrag] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        // Hoá đơn đầy mã số — tắt tự sửa chính tả để khỏi "sửa" nhầm mã/tiền.
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: tile, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let observations = (request.results ?? [])
        return observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let b = obs.boundingBox
            let topFromFullTop = Double(tileTopPx) + (1.0 - Double(b.maxY)) * Double(tileHeightPx)
            let heightFull = Double(b.height) * Double(tileHeightPx) / Double(fullHeightPx)
            let maxYFull = 1.0 - topFromFullTop / Double(fullHeightPx)
            let box = CGRect(x: b.minX, y: CGFloat(maxYFull - heightFull),
                             width: b.width, height: CGFloat(heightFull))
            return OCRFrag(text: candidate.string, confidence: Double(candidate.confidence), box: box)
        }
    }

    /// Khử mảnh trùng sinh ra trong vùng chồng 200px giữa hai lát: cùng
    /// chữ + hộp giao nhau >= 50% diện tích hộp nhỏ hơn -> giữ bản có độ
    /// tin cậy cao hơn (đúng luật CODE-AUDIT F2c). Hai dòng THẬT khác nhau
    /// không bao giờ giao hộp tới mức này nên không bị xoá nhầm.
    static func dedupeOverlap(_ frags: [OCRFrag]) -> [OCRFrag] {
        var kept: [OCRFrag] = []
        for f in frags.sorted(by: { $0.confidence > $1.confidence }) {
            let isDuplicate = kept.contains { k in
                guard k.text == f.text else { return false }
                let inter = k.box.intersection(f.box)
                guard !inter.isNull else { return false }
                let smaller = min(k.box.width * k.box.height, f.box.width * f.box.height)
                return smaller > 0 && (inter.width * inter.height) / smaller >= 0.5
            }
            if !isDuplicate { kept.append(f) }
        }
        return kept
    }

    /// F2a — ráp mảnh thành HÀNG THỊ GIÁC (nguyên văn thuật toán CODE-AUDIT
    /// F2a): sắp trên->xuống theo maxY; gom mảnh có khoảng Y chồng >= 50%
    /// chiều cao mảnh NGẮN HƠN vào cùng hàng; trong hàng sắp trái->phải
    /// theo minX và nối bằng 1 khoảng trắng; độ tin cậy của dòng ráp = MIN
    /// của các mảnh (mảnh yếu nhất quyết định — không để tiền mờ trốn sau
    /// nhãn nét). Hàng giữ thứ tự trên->xuống vì mảnh đã sắp và chỉ nối
    /// vào hàng đang mở cuối cùng.
    static func mergeRows(_ fragsIn: [OCRFrag]) -> [OCRLine] {
        var frags = fragsIn
        frags.sort { $0.box.maxY > $1.box.maxY }
        var rows: [[OCRFrag]] = []
        for f in frags {
            if var row = rows.last, let anchor = row.first {
                let overlap = min(f.box.maxY, anchor.box.maxY) - max(f.box.minY, anchor.box.minY)
                let shorter = min(f.box.height, anchor.box.height)
                if shorter > 0 && overlap / shorter >= 0.5 {
                    row.append(f)
                    rows[rows.count - 1] = row
                    continue
                }
            }
            rows.append([f])
        }
        return rows.map { row in
            let sorted = row.sorted { $0.box.minX < $1.box.minX }
            return OCRLine(text: sorted.map(\.text).joined(separator: " "),
                           confidence: sorted.map(\.confidence).min() ?? 0)
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

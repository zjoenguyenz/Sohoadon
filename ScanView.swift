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
    /// P2-1 (làm lại cốt lõi OCR, Lớp 5 — chẩn đoán bắt buộc): vết cấp
    /// pass/hình học của lượt đọc sinh ra bản nháp này. ScanView.process
    /// ghi bản JSON của nó thành file phụ cạnh ảnh gốc ngay khi đọc xong
    /// (xem OCRDiagnosticsStore) — KHÔNG qua model SwiftData. Trường này
    /// để ReviewView/màn chẩn đoán dùng tại chỗ khi cần; nil ở các đường
    /// dựng draft không qua OCR (giai đoạn chuyển tiếp).
    var diagnostics: OCRDiagnostics? = nil
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
        // P2-2: đọc qua analyzeReceiptFull — đường ống ĐA PASS mới
        // (gốc / khử nghiêng / phái sinh qua cổng / phóng to / engine
        // tài liệu) + hợp nhất v2 + chọn bộ thắng bằng đối chiếu số
        // học + vòng đọc lại có mục tiêu. Kết quả đưa sang Review là
        // ParseResult ĐÃ QUA ReconcileSession (không parse lại thô ở
        // đây như đường cũ). OCRDiagnostics ghi thành file phụ cạnh
        // ảnh gốc NGAY tại đây (khoá theo fileName): tờ có được lưu
        // hay không, sự cố của lượt đọc này vẫn truy lại được bằng
        // bằng chứng cấp pass/bộ ứng viên/vòng đối chiếu.
        analyzeReceiptFull(in: image) { outcome in
            let lines = outcome.lines
            let diagnostics = outcome.diagnostics
            if let diagnostics {
                OCRDiagnosticsStore.save(diagnostics, imageFileName: fileName)
            }
            DispatchQueue.main.async {
                isProcessing = false
                if lines.isEmpty {
                    statusText = nil
                    errorText = "Không đọc được chữ nào trong ảnh — anh chụp lại rõ hơn, đủ sáng giúp."
                    processNextImportedFile()
                    return
                }
                // Đường lùi an toàn: outcome.result chỉ nil khi không
                // bộ ứng viên nào đọc được dòng — đã bị chặn bởi kiểm
                // lines.isEmpty ở trên; nhánh parse thô này tồn tại để
                // process() không bao giờ kẹt vì một outcome thiếu kết
                // quả, đúng luật fail-open của gói.
                let result = outcome.result ?? ReceiptParser.parse(lines: lines)
                statusText = nil
                draft = ScanDraft(result: result, imageFileName: fileName, sourceType: source,
                                  sourceFileName: sourceFileName, originalFileNames: originalFileNames,
                                  diagnostics: diagnostics)
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
            // P2-1: đường lớp chữ không qua OCR vẫn có vết chẩn đoán tối
            // thiểu (pass = pdfTextLayer, không hình học) — ghi file phụ
            // cạnh chính file PDF bằng chứng, cùng khoá như đường OCR.
            let diagnostics = OCRDiagnostics.pdfTextLayer(lineCount: lines.count)
            OCRDiagnosticsStore.save(diagnostics, imageFileName: storedPDFName)
            draft = ScanDraft(result: result, imageFileName: storedPDFName,
                              sourceType: .pdfImport, sourceFileName: sourceFileName,
                              originalFileNames: [storedPDFName],
                              rawTextIsPDFTextLayer: true,
                              diagnostics: diagnostics)
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
                let trimmed = rawLine.trimmingCharacters(in: CharacterSet.whitespaces)
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

    // MARK: - P2-2: Đường ống OCR ĐA PASS (kiến trúc 6 lớp đã duyệt)
    //
    // Lịch sử rút gọn: WP4 đọc 1 ảnh phái sinh thay gốc; OCRFIX sửa
    // thành 2 ứng viên thi yieldScore — cả hai luật chọn đều bị bằng
    // chứng thực địa kết tội (điểm sản lượng không có thành phần toàn
    // vẹn tiền + thắng-lấy-hết vứt vùng tốt của bộ thua — PIPELINE-
    // AUDIT D-2.1/D-2.2, TEAM.md L-2026-11-10-6/-7). P2-1 dựng hạ
    // tầng (OCRFragment2/OCRLine2, hình học chạy bóng, cổng tứ giác,
    // chẩn đoán). P2-2 KÍCH HOẠT: nhiều pass trên cùng một tờ -> hợp
    // nhất cấp mảnh theo hình học (OCRFragmentMerger) -> các BỘ DÒNG
    // ứng viên (từng pass + bộ hợp nhất) -> chọn bộ thắng bằng ĐỐI
    // CHIẾU SỐ HỌC của Parser + Reconcile (P2-3), yieldScore chỉ còn
    // trong chẩn đoán -> vòng đọc lại có mục tiêu theo
    // ReconcileSession (tối đa 2 vòng × 2 vùng, đơn điệu).
    // Bất biến: ảnh GỐC đã lưu trước khi đọc, không bao giờ bị sửa;
    // mọi tầng mới đều fail-open — lỗi ở bất kỳ pass/tầng nào thì rơi
    // về bộ pass đơn tốt nhất, không bao giờ trả rỗng khi còn một
    // pass đọc được dòng.

    /// Một mảnh chữ Vision kèm hộp toạ độ chuẩn hoá (gốc dưới-trái) trong
    /// KHÔNG GIAN ẢNH ĐẦY ĐỦ — mảnh của lát cắt đã quy đổi về trước khi ráp.
    struct OCRFrag {
        var text: String
        var confidence: Double
        var box: CGRect
        /// P2-1 (PIPELINE-AUDIT D-2.4): ứng viên 2–3 của Vision cho cùng
        /// observation — trước đây bị vứt ngay tại ocrFragments, trong
        /// khi với hoá đơn, đáp án đúng của một token tiền đọc phân vân
        /// ("38.96" vs "38.9G") thường nằm ở đây. Chỉ là DỮ LIỆU KÈM:
        /// ứng viên 1 (text/confidence) và mọi luật phía sau không đổi.
        var alternates: [(text: String, confidence: Double)] = []
        /// P2-1: lát sinh ra mảnh này (số thứ tự trong lưới lát của
        /// collectFragments); nil = lượt đọc toàn khung không cắt lát.
        /// Mang theo mảnh qua khử trùng/ráp để OCRFragment2 truy vết.
        var tileIndex: Int? = nil
    }

    /// Điểm vào đọc dòng GIỮ NGUYÊN chữ ký từ các gói trước — thân
    /// nay uỷ cho đường ống P2-2 trọn vẹn (analyzeReceiptFull): kết
    /// quả là bộ dòng của bộ ứng viên thắng theo đối chiếu số học,
    /// không còn là bộ thắng theo yieldScore của OCRFIX.
    private func recognizeLines(in image: UIImage, completion: @escaping ([OCRLine]) -> Void) {
        analyzeReceiptFull(in: image) { outcome in
            completion(outcome.lines)
        }
    }

    /// Như recognizeLines nhưng trả kèm OCRDiagnostics của lượt đọc
    /// (chữ ký giữ nguyên). Chẩn đoán P2-2 ghi: từng pass (mảnh/dòng/
    /// thời gian/vùng mù), điểm số học của mọi bộ ứng viên + bộ thắng,
    /// trạng thái reconcile từng vòng đọc lại, verdict cổng tứ giác
    /// THẬT (không còn chế độ bóng), và cấu trúc engine tài liệu.
    private func analyzeReceipt(in image: UIImage,
                                completion: @escaping ([OCRLine], OCRDiagnostics?) -> Void) {
        analyzeReceiptFull(in: image) { outcome in
            completion(outcome.lines, outcome.diagnostics)
        }
    }

    /// Đầu ra đầy đủ của một lượt đọc P2-2: bộ dòng thắng (dạng
    /// OCRLine cho các điểm gọi cũ + dạng OCRLine2 giữ hình học),
    /// ParseResult ĐÃ QUA ReconcileSession kèm ReconcileReport của
    /// nó, chẩn đoán, và ảnh đã chuẩn hoá hướng (không gian gốc cho
    /// mọi hộp/đọc lại). result/report chỉ nil khi không bộ ứng viên
    /// nào đọc được dòng nào.
    private struct OCRPipelineOutcome {
        var lines: [OCRLine] = []
        var lines2: [OCRLine2] = []
        var result: ParseResult? = nil
        var report: ReconcileReport? = nil
        var diagnostics: OCRDiagnostics? = nil
        var cgImage: CGImage? = nil
    }

    /// Đường ống P2-2 trọn vẹn trên một ảnh: chuẩn hoá hướng (ghim
    /// scale — D-1.1) -> các pass cổ điển chạy đồng bộ trên hàng đợi
    /// nền (gốc -> khử nghiêng -> phái sinh qua cổng -> phóng to có
    /// điều kiện) -> pass engine tài liệu (bất đồng bộ, fail-open)
    /// -> hợp nhất + chọn theo số học + vòng đọc lại
    /// (finishPipeline). Mọi nhánh lỗi đều thu về outcome rỗng hoặc
    /// bộ pass đơn tốt nhất — không nhánh nào ném lỗi ra ngoài.
    private func analyzeReceiptFull(in image: UIImage,
                                    completion: @escaping (OCRPipelineOutcome) -> Void) {
        guard let cgImage = Self.normalizedCGImage(from: image) else {
            completion(OCRPipelineOutcome())
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let classic = Self.runClassicPasses(on: cgImage)
            Self.documentPass(from: cgImage) { documentOutcome in
                DispatchQueue.global(qos: .userInitiated).async {
                    completion(Self.finishPipeline(on: cgImage, classic: classic,
                                                   document: documentOutcome))
                }
            }
        }
    }

    /// Chuẩn hoá hướng ảnh trước khi OCR: ảnh từ thư viện có thể mang
    /// hướng EXIF mà cgImage bỏ qua — không chuẩn hoá thì Vision đọc
    /// chữ bị xoay, ra rác. P2-2 sửa D-1.1 của audit: renderer GHIM
    /// format.scale = image.scale (bản cũ dùng format mặc định lấy
    /// scale theo màn hình chính, làm số pixel đầu ra — và mọi ngưỡng
    /// pixel phía sau — lệ thuộc màn hình thay vì ảnh thật).
    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up {
            return image.cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let upright = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return upright.cgImage
    }

    /// Kết quả một PASS đọc trên một ảnh — nguyên liệu truy vết đầy
    /// đủ của pass đó: dòng cấp 2 (hình học + spans + nguồn pass),
    /// mảnh cấp 2 ĐÃ khử trùng mờ, số lát, vùng mù, thời gian chạy.
    /// `lines` là bản legacy của lines2 (cùng nội dung, qua .legacy).
    private struct TracedPassOutcome {
        var passID: OCRPassID
        var lines: [OCRLine] = []
        var lines2: [OCRLine2] = []
        var fragments: [OCRFragment2] = []
        var tileCount: Int = 0
        var blindBands: [OCRDiagRect] = []
        var elapsedSeconds: Double = 0
    }

    /// Một pass Vision cổ điển trọn vẹn trên MỘT ảnh: thu mảnh (cắt
    /// lát theo cơ chế hiện có khi ảnh cao) -> ánh xạ hộp về không
    /// gian ảnh gốc (boxTransform — pass phái sinh/khử nghiêng/đọc
    /// lại dùng; pass gốc/phóng to để nil vì toạ độ chuẩn hoá của
    /// chúng đã là không gian gốc) -> hợp nhất v2 (OCRFragmentMerger:
    /// khử trùng MỜ + ráp hàng cụm-Y có chốt chặn). Đây là điểm thay
    /// thế dedupeOverlap + mergeRows F2a ở đường mới; hai hàm cũ vẫn
    /// còn trong file làm bề mặt tương thích nhưng đường P2-2 không
    /// gọi tới.
    private static func ocrPass(from cgImage: CGImage, passID: OCRPassID,
                                boxTransform: ((CGRect) -> CGRect)? = nil,
                                regionID: Int? = nil) -> TracedPassOutcome {
        let start = CFAbsoluteTimeGetCurrent()
        let collected = collectFragments(cgImage: cgImage)
        var provisional: [OCRFragment2] = []
        provisional.reserveCapacity(collected.fragments.count)
        for (index, fragment) in collected.fragments.enumerated() {
            let mappedBox = boxTransform?(fragment.box) ?? fragment.box
            provisional.append(OCRFragment2(
                fragmentID: index,
                text: fragment.text.trimmingCharacters(in: CharacterSet.whitespaces),
                alternates: fragment.alternates,
                confidence: fragment.confidence,
                box: OCRFragmentMerger.clampedBox(mappedBox),
                passID: passID,
                tileIndex: fragment.tileIndex,
                regionID: regionID))
        }
        let assembled = OCRFragmentMerger.assemble(provisional)
        var outcome = TracedPassOutcome(passID: passID)
        outcome.lines2 = assembled.lines
        outcome.lines = assembled.lines.legacyLines
        outcome.fragments = assembled.representatives
        outcome.tileCount = collected.tileCount
        outcome.blindBands = collected.blindBands
        outcome.elapsedSeconds = CFAbsoluteTimeGetCurrent() - start
        return outcome
    }

    /// Các pass cổ điển (đồng bộ) của một lượt đọc + vết hình học/
    /// cổng phái sinh đi kèm. Pass engine tài liệu chạy riêng (bất
    /// đồng bộ) và được cộng vào ở finishPipeline.
    private struct ClassicPassesOutcome {
        var passOutcomes: [TracedPassOutcome] = []
        var geometry: OCRGeometryRecord? = nil
        var derivedGate: OCRDerivedGateRecord? = nil
        var notes: [String] = []
    }

    /// Chạy các pass engine (a) theo thứ tự: GỐC (bắt buộc) -> KHỬ
    /// NGHIÊNG (khi Lớp 0 cho biến thể hợp lệ) -> PHÁI SINH (chỉ khi
    /// tứ giác qua cổng, dùng expandedQuad, KHÔNG tăng tương phản vô
    /// điều kiện) -> PHÓNG TO (chỉ khi chiều cao dòng trung vị ước
    /// lượng của pass gốc < ngưỡng audit). Mọi pass đều ánh xạ hộp về
    /// KHÔNG GIAN ẢNH GỐC trước khi trả ra (điều kiện để hợp nhất
    /// theo hình học ở finishPipeline có nghĩa).
    private static func runClassicPasses(on cgImage: CGImage) -> ClassicPassesOutcome {
        var state = ClassicPassesOutcome()

        // Pass 1 — ẢNH GỐC: luôn chạy, là đường lùi an toàn cuối cùng.
        let original = ocrPass(from: cgImage, passID: .original)
        state.passOutcomes.append(original)

        // Lớp 0 — đo nghiêng trên chính ảnh gốc (một lượt thăm dò).
        let assessment = ReceiptGeometry.assessSkew(in: cgImage)
        var geometry = OCRGeometryRecord(assessment: assessment)

        // Pass 2 — KHỬ NGHIÊNG: chỉ khi assessSkew tin được và biến
        // thể được sản xuất. Ánh xạ hộp về gốc: biến thể theo dải có
        // canvas CÙNG kích thước gốc (mỗi dải đặt lại đúng tâm danh
        // nghĩa) nên toạ độ chuẩn hoá giữ nguyên; biến thể quay toàn
        // cục đổi kích thước khung nên hộp phải quay NGƯỢC qua tâm.
        if let variant = ReceiptGeometry.deskewedVariant(of: cgImage, assessment: assessment) {
            let variantWidth = variant.width
            let variantHeight = variant.height
            var transform: ((CGRect) -> CGRect)? = nil
            if variantWidth != cgImage.width || variantHeight != cgImage.height,
               let angle = assessment.globalDegrees {
                transform = { box in
                    mapBoxFromGloballyRotatedVariant(box,
                                                     variantWidth: variantWidth,
                                                     variantHeight: variantHeight,
                                                     sourceWidth: cgImage.width,
                                                     sourceHeight: cgImage.height,
                                                     screenSlopeDegrees: angle)
                }
            }
            let deskewed = ocrPass(from: variant, passID: .deskewed, boxTransform: transform)
            state.passOutcomes.append(deskewed)
            geometry.deskewVariantProduced = true
            geometry.deskewVariantFragmentCount = deskewed.fragments.count
            geometry.deskewVariantLineCount = deskewed.lines.count
        }
        state.geometry = geometry

        // Pass 3 — PHÁI SINH QUA CỔNG D-2.3: cổng là đường THẬT từ
        // P2-2 (không còn chế độ bóng như P2-1): trượt cổng = không
        // có pass phái sinh. Hộp của pass này được ánh xạ ngược qua
        // phép chiếu (homography) từ tứ giác đã nới lề về ảnh gốc.
        let derived = derivedVariant(from: cgImage)
        state.derivedGate = derived.record
        if let derivedImage = derived.image, let quad = derived.expandedQuad {
            let pass = ocrPass(from: derivedImage, passID: .derived,
                               boxTransform: { box in
                                   mapBoxFromPerspectiveVariant(box, expandedQuad: quad)
                               })
            state.passOutcomes.append(pass)
        }

        // Pass 4 — PHÓNG TO CHO ẢNH PHÂN GIẢI THẤP: ngưỡng theo
        // PIPELINE-AUDIT §4.3 + ENGINE-REPORT §3 — chiều cao dòng
        // TRUNG VỊ ước lượng từ hộp mảnh của pass gốc < 16px (Mẫu
        // 002: chữ cao ~12–15px) thì phóng 2× Lanczos rồi đọc thêm
        // một pass. Đo bằng chiều cao dòng thật thay vì bề rộng ảnh
        // vì đó là đại lượng trực tiếp giới hạn OCR. Ảnh phóng đều
        // hai chiều nên hộp chuẩn hoá của pass này đã ở không gian
        // gốc — không cần boxTransform.
        if let medianPx = medianLineHeightPixels(of: original, imageHeight: cgImage.height),
           medianPx < PipelineConstants.lowResolutionLineHeightPx {
            if let upscaled = upscaledVariant(of: cgImage, factor: PipelineConstants.upscaleFactor) {
                state.passOutcomes.append(ocrPass(from: upscaled, passID: .upscaled))
                state.notes.append("Pass phóng to \(Int(PipelineConstants.upscaleFactor))× (Lanczos) được kích hoạt: chiều cao dòng trung vị ước lượng \(String(format: "%.1f", medianPx))px < \(Int(PipelineConstants.lowResolutionLineHeightPx))px — ngưỡng KHỞI ĐIỂM (audit §4.3), BenchApp kết án.")
            }
        }
        return state
    }

    /// Một BỘ DÒNG ứng viên đã qua Parser + ReconcileSession, kèm
    /// điểm theo đúng thứ tự ưu tiên của audit §4.6 / RECONCILE:
    /// (1) |Σmón − subtotal| tăng dần; (2) số neo (tiệm/ngày/
    /// subtotal/total) giảm dần; (3) hạng trạng thái reconcile tăng
    /// dần; (4) preference (bộ hợp nhất trước, rồi gốc, rồi các pass
    /// phụ theo thứ tự chạy) — chỉ dùng khi ba tiêu chí trên hoà.
    private struct CandidateEvaluation {
        var name: String
        var preference: Int
        var lines2: [OCRLine2]
        var fragments: [OCRFragment2]
        var session: ReconcileSession
        var ledgerDeltaAbs: Int
        var anchorNames: [String]
        var result: ParseResult { session.bestResult }
        var report: ReconcileReport { session.bestReport }
    }

    /// Chạy một bộ ứng viên qua Parser.parse + ReconcileSession
    /// (phiên tự chạy lượt reconcile đầu trong init) và tính điểm.
    /// lineBoxes truyền thẳng hộp của lines2 — chỉ phục vụ tính dải
    /// cho RegionHint của P2-3, không ảnh hưởng quyết định sửa.
    private static func evaluateCandidate(name: String, preference: Int,
                                          lines2: [OCRLine2],
                                          fragments: [OCRFragment2]) -> CandidateEvaluation {
        let legacy = lines2.legacyLines
        let parsed = ReceiptParser.parse(lines: legacy)
        let boxes: [CGRect?] = lines2.map { $0.box }
        let session = ReconcileSession(result: parsed, lines: legacy, lineBoxes: boxes)
        let result = session.bestResult
        let delta: Int
        if let reported = session.bestReport.moneyDeltaCents {
            delta = abs(reported)
        } else if let subtotal = result.subtotalCents {
            delta = abs(subtotal - result.items.reduce(0) { $0 + ($1.amountCents ?? 0) })
        } else {
            delta = Int.max
        }
        var anchors: [String] = []
        if result.vendor != nil { anchors.append("vendor") }
        if result.date != nil { anchors.append("date") }
        if result.subtotalCents != nil { anchors.append("subtotal") }
        if result.totalCents != nil { anchors.append("total") }
        return CandidateEvaluation(name: name, preference: preference,
                                   lines2: lines2, fragments: fragments,
                                   session: session, ledgerDeltaAbs: delta,
                                   anchorNames: anchors)
    }

    /// Thứ tự "tốt hơn" giữa hai bộ ứng viên — đúng thứ tự đã ghi ở
    /// CandidateEvaluation. Trả true khi a thắng b.
    private static func candidateIsBetter(_ a: CandidateEvaluation,
                                          _ b: CandidateEvaluation) -> Bool {
        if a.ledgerDeltaAbs != b.ledgerDeltaAbs { return a.ledgerDeltaAbs < b.ledgerDeltaAbs }
        if a.anchorNames.count != b.anchorNames.count { return a.anchorNames.count > b.anchorNames.count }
        let rankA = reconcileStatusRank(a.report.status)
        let rankB = reconcileStatusRank(b.report.status)
        if rankA != rankB { return rankA < rankB }
        return a.preference < b.preference
    }

    /// Hạng trạng thái reconcile cho tiêu chí (3): khớp/sửa-có-bằng-
    /// chứng đứng đầu; các trạng thái thiếu neo/mâu thuẫn neo đứng
    /// cuối. Đây là thứ hạng CHỌN BỘ của pipeline — không đổi luật
    /// đơn điệu của ReconcileSession (vẫn là luật duy nhất phán các
    /// vòng đọc lại).
    private static func reconcileStatusRank(_ status: ReconcileStatus) -> Int {
        switch status {
        case .ok: return 0
        case .repaired: return 1
        case .partial: return 2
        case .suggestionOnly: return 3
        case .ambiguous: return 4
        case .noSolution: return 5
        case .tooComplex: return 6
        case .totalOnly: return 7
        case .anchorConflict: return 8
        case .noAnchor: return 9
        }
    }

    /// Ưu tiên hoà điểm giữa các pass đơn: gốc là đường lùi chuẩn;
    /// bộ hợp nhất dùng preference 0 riêng (gán tại finishPipeline).
    private static func preference(for passID: OCRPassID) -> Int {
        switch passID {
        case .original: return 1
        case .deskewed: return 2
        case .derived: return 3
        case .upscaled: return 4
        case .document: return 5
        case .reread: return 6
        case .pdfTextLayer: return 7
        }
    }

    /// Dịch ReconcileRegionHint (P2-3) sang RegionHint (P2-1) cho
    /// dịch vụ đọc lại. HỢP ĐỒNG NỚI DẢI (tránh nới hai lần): band do
    /// P2-3 tính đã được nới 50% chiều cao mỗi phía ngay trong
    /// reconcile() — khi hint có band, dùng NGUYÊN VĂN, RegionGeometry
    /// chỉ còn lo phép cắt pixel. Khi hint không có band nhưng có
    /// lineRange, dải được dựng bằng RegionGeometry.band(forLines:)
    /// (luật nới ×1.5 của P2-1) trên đúng các dòng của bộ thắng.
    private static func regionHint(from hint: ReconcileRegionHint,
                                   lines: [OCRLine2]) -> RegionHint? {
        let reason: RegionHint.Reason
        switch hint.reason {
        case .missingOrUnrepairable: reason = .missingOrUnrepairable
        case .qtyMismatch: reason = .qtyMismatch
        case .anchorConflict: reason = .anchorConflict
        case .totalOnlyAnchor: reason = .totalOnlyAnchor
        }
        if let band = hint.band {
            return RegionHint(band: band, reason: reason, priority: hint.priority)
        }
        if let range = hint.lineRange {
            let subset = lines.enumerated()
                .filter { range.contains($0.offset) }
                .map { $0.element }
            if let band = RegionGeometry.band(forLines: subset) {
                return RegionHint(band: band, reason: reason, priority: hint.priority)
            }
        }
        return nil
    }

    /// Nửa sau của đường ống: cộng pass engine tài liệu -> dựng các
    /// bộ ứng viên (từng pass + bộ hợp nhất khi có ≥ 2 pass) -> chọn
    /// bộ thắng bằng số học -> vòng đọc lại có mục tiêu theo
    /// ReconcileSession -> đóng gói outcome + chẩn đoán schema 2.
    private static func finishPipeline(on cgImage: CGImage,
                                       classic: ClassicPassesOutcome,
                                       document: DocumentPassOutcome) -> OCRPipelineOutcome {
        var diagnostics = OCRDiagnostics()
        diagnostics.schemaVersion = 2
        diagnostics.sourceImagePixels = "\(cgImage.width)x\(cgImage.height)"
        diagnostics.geometry = classic.geometry
        diagnostics.derivedGate = classic.derivedGate
        diagnostics.notes += classic.notes
        if let structure = document.structure {
            diagnostics.documentStructure = structure
        }
        if let note = document.note {
            diagnostics.notes.append(note)
        }

        var passOutcomes = classic.passOutcomes
        if let documentOutcome = document.outcome {
            passOutcomes.append(documentOutcome)
        }
        for outcome in passOutcomes {
            diagnostics.passes.append(OCRPassRecord(
                passID: outcome.passID, tileCount: outcome.tileCount,
                fragmentCount: outcome.fragments.count,
                lineCount: outcome.lines.count,
                yieldScore: yieldScore(outcome.lines),
                blindBands: outcome.blindBands,
                elapsedSeconds: outcome.elapsedSeconds))
        }
        diagnostics.blindBands = diagnostics.passes.flatMap(\.blindBands)

        // Các bộ ứng viên: từng pass riêng + bộ hợp nhất toàn pass.
        var evaluations: [CandidateEvaluation] = []
        for outcome in passOutcomes where !outcome.lines2.isEmpty {
            evaluations.append(evaluateCandidate(name: outcome.passID.rawValue,
                                                 preference: preference(for: outcome.passID),
                                                 lines2: outcome.lines2,
                                                 fragments: outcome.fragments))
        }
        if passOutcomes.count > 1 {
            let pooled = OCRFragmentMerger.uniquelyIdentified(passOutcomes.flatMap(\.fragments))
            let merged = OCRFragmentMerger.assemble(pooled)
            if !merged.lines.isEmpty {
                evaluations.append(evaluateCandidate(name: "merged", preference: 0,
                                                     lines2: merged.lines,
                                                     fragments: merged.representatives))
            }
        }

        guard let winnerIndex = evaluations.indices.min(by: {
                  candidateIsBetter(evaluations[$0], evaluations[$1])
              }),
              !evaluations.isEmpty else {
            diagnostics.notes.append("Mọi pass đều không đọc được dòng nào — outcome rỗng, process() báo lỗi chụp lại như cũ.")
            return OCRPipelineOutcome(lines: [], diagnostics: diagnostics, cgImage: cgImage)
        }
        let winner = evaluations[winnerIndex]
        diagnostics.candidateScores = evaluations.map { evaluation in
            OCRCandidateScoreRecord(
                candidateName: evaluation.name,
                ledgerDeltaCents: evaluation.ledgerDeltaAbs == Int.max ? nil : evaluation.ledgerDeltaAbs,
                anchorCount: evaluation.anchorNames.count,
                anchorsPresent: evaluation.anchorNames,
                reconcileStatus: evaluation.report.status.rawValue,
                itemCount: evaluation.result.items.count,
                lineCount: evaluation.lines2.count,
                yieldScore: yieldScore(evaluation.lines2.legacyLines),
                winner: evaluation.name == winner.name)
        }
        diagnostics.winningCandidate = winner.name
        diagnostics.notes.append("Bộ thắng: \(winner.name) — chọn bằng |Σmón − subtotal| -> số neo -> trạng thái reconcile; yieldScore chỉ còn trong chẩn đoán, không tham gia quyết định (audit §4.6).")

        // Vòng đọc lại có mục tiêu (RECONCILE-DESIGN §6 qua
        // ReconcileSession của P2-3): tối đa 2 vòng × 2 vùng; mỗi
        // vòng gộp mảnh đọc lại vào HỒ MẢNH của bộ thắng, ráp lại
        // toàn bộ, parse lại và nộp vòng — phiên chỉ nhận khi tốt
        // hơn theo luật đơn điệu của chính nó; không tốt hơn thì giữ
        // kết quả cũ và dừng.
        let session = winner.session
        var bestLines2 = winner.lines2
        var bestFragments = winner.fragments
        var roundRecords: [OCRReconcileRoundRecord] = [
            OCRReconcileRoundRecord(round: 0, regionReasons: [], accepted: true,
                                    reconcileStatus: session.bestReport.status.rawValue,
                                    moneyDeltaCents: session.bestReport.moneyDeltaCents,
                                    itemCount: session.bestResult.items.count)
        ]
        let reReader = TargetedReOCRService(image: cgImage)
        while session.roundsUsed < ReconcileSession.maxRounds {
            let hints = session.pendingHints
            guard !hints.isEmpty else { break }
            var roundFragments: [OCRFragment2] = []
            var roundReasons: [String] = []
            for hint in hints {
                guard let target = regionHint(from: hint, lines: bestLines2) else { continue }
                let outcome = reReader.reReadOutcome(target,
                                                     upscale: PipelineConstants.reReadUpscaleFactor)
                if !outcome.fragments.isEmpty {
                    roundFragments += outcome.fragments
                    roundReasons.append(hint.reason.rawValue)
                }
            }
            guard !roundFragments.isEmpty else {
                diagnostics.notes.append("Đọc lại: có hint nhưng không vùng nào cắt/đọc lại được — dừng vòng, giữ kết quả hiện tại.")
                break
            }
            let pooled = OCRFragmentMerger.uniquelyIdentified(bestFragments + roundFragments)
            let assembled = OCRFragmentMerger.assemble(pooled)
            guard !assembled.lines.isEmpty else { break }
            let legacy = assembled.lines.legacyLines
            let parsed = ReceiptParser.parse(lines: legacy)
            let boxes: [CGRect?] = assembled.lines.map { $0.box }
            let accepted = session.submitRound(result: parsed, lines: legacy, lineBoxes: boxes)
            roundRecords.append(OCRReconcileRoundRecord(
                round: session.roundsUsed, regionReasons: roundReasons,
                accepted: accepted,
                reconcileStatus: session.bestReport.status.rawValue,
                moneyDeltaCents: session.bestReport.moneyDeltaCents,
                itemCount: session.bestResult.items.count))
            if accepted {
                bestLines2 = assembled.lines
                bestFragments = assembled.representatives
            } else {
                break
            }
        }
        diagnostics.reconcileRounds = roundRecords

        var result = session.bestResult
        // Cảnh báo trình anh = cảnh báo validate() gốc của kết quả
        // thắng + ghi chú của lớp trọng tài (đúng hợp đồng của
        // parseAndReconcile ở P2-3), khử trùng lặp.
        result.warnings = result.warnings
            + session.bestReport.notes.filter { !result.warnings.contains($0) }
        return OCRPipelineOutcome(lines: bestLines2.legacyLines, lines2: bestLines2,
                                  result: result, report: session.bestReport,
                                  diagnostics: diagnostics, cgImage: cgImage)
    }

    /// Đầu ra của pass engine tài liệu (b): pass đã ráp (chỉ có khi
    /// đọc được dòng hợp lệ), bản ghi cấu trúc cho chẩn đoán, và ghi
    /// chú fail-open khi pass vắng/lỗi.
    private struct DocumentPassOutcome {
        var outcome: TracedPassOutcome? = nil
        var structure: OCRDocumentStructureRecord? = nil
        var note: String? = nil
    }

    /// Pass engine (b) — iOS 26 RecognizeDocumentsRequest. Cầu nối
    /// completion: thân request là async nên chạy trong Task tách;
    /// MỌI lỗi (không có document, request ném lỗi, hệ điều hành <
    /// iOS 26) đều thu về outcome không-pass + ghi chú — fail-open,
    /// không chặn các pass cổ điển đã chạy trước.
    private static func documentPass(from cgImage: CGImage,
                                     completion: @escaping (DocumentPassOutcome) -> Void) {
        if #available(iOS 26.0, *) {
            Task.detached(priority: .userInitiated) {
                let outcome = await runDocumentPass(on: cgImage)
                completion(outcome)
            }
        } else {
            completion(DocumentPassOutcome(
                note: "Engine tài liệu cần iOS 26 — hệ điều hành thấp hơn, pass (b) vắng, fail-open."))
        }
    }

    /// Thân engine (b). Cấu hình theo kỷ luật project (đối chiếu tài
    /// liệu Apple của RecognizeDocumentsRequest.TextRecognitionOptions):
    /// recognitionLanguages đặt TƯỜNG MINH [vi-VN, en-US] (cùng thứ
    /// tự ưu tiên như engine (a)); useLanguageCorrection = false
    /// (TestB đặt true là lỗi công bằng đã ghi ở ENGINE-REPORT);
    /// automaticallyDetectLanguage = false (ngôn ngữ đã tường minh);
    /// maximumCandidateCount = 3 (khớp topCandidates(3) của (a));
    /// minimumTextHeightFraction = 0.005 — giá trị KHỞI ĐIỂM thấp
    /// có chủ đích: mặc định 1/32 ≈ 0.03125 sẽ lọc mất toàn bộ dòng
    /// của hoá đơn phân giải thấp (Mẫu 002: dòng ~13px trên ảnh cao
    /// 1457px ≈ 0.009). customWords: không đặt (chưa có bằng chứng
    /// bộ từ vựng riêng thắng; để trống như mặc định).
    /// Xuất: dòng qua Container.Text.lines ([RecognizedTextObservation]
    /// — hộp từ boundingRegion.normalizedPath, ứng viên qua
    /// topCandidates(3)); khi text.lines rỗng thì lùi về paragraphs.
    /// Cấu trúc (paragraphs/tables/lists/barcodes/detectedData) chỉ
    /// vào CHẨN ĐOÁN — không cấp đặc quyền nào cho pass này.
    @available(iOS 26.0, *)
    private static func runDocumentPass(on cgImage: CGImage) async -> DocumentPassOutcome {
        let start = CFAbsoluteTimeGetCurrent()
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [
            Locale.Language(identifier: "vi-VN"),
            Locale.Language(identifier: "en-US")
        ]
        request.textRecognitionOptions.useLanguageCorrection = false
        request.textRecognitionOptions.automaticallyDetectLanguage = false
        request.textRecognitionOptions.maximumCandidateCount = 3
        request.textRecognitionOptions.minimumTextHeightFraction = 0.005
        do {
            let observations = try await request.perform(on: cgImage)
            guard let document = observations.first?.document else {
                return DocumentPassOutcome(
                    note: "Engine tài liệu: không có DocumentObservation — pass (b) vắng, fail-open.")
            }
            var lineObservations = document.text.lines
            if lineObservations.isEmpty {
                lineObservations = document.paragraphs.flatMap { $0.lines }
            }
            var fragments: [OCRFragment2] = []
            for (index, observation) in lineObservations.enumerated() {
                let candidates = observation.topCandidates(3)
                guard let top = candidates.first else { continue }
                let text = top.string.trimmingCharacters(in: CharacterSet.whitespaces)
                guard !text.isEmpty else { continue }
                let rect = observation.boundingRegion.normalizedPath.boundingBoxOfPath
                guard !rect.isNull, !rect.isInfinite, rect.width > 0, rect.height > 0 else { continue }
                fragments.append(OCRFragment2(
                    fragmentID: index, text: text,
                    alternates: candidates.dropFirst().map {
                        (text: $0.string, confidence: Double($0.confidence))
                    },
                    confidence: Double(top.confidence),
                    box: OCRFragmentMerger.clampedBox(rect),
                    passID: .document, tileIndex: nil))
            }
            // Cấu trúc cho chẩn đoán: đếm tại chỗ, không giữ nội dung
            // detectedData (chỉ số lượng — tránh chép dữ liệu nhạy
            // cảm của anh vào file chẩn đoán).
            var tableCellCount = 0
            var detectedDataCount = document.text.detectedData.count
            for table in document.tables {
                for row in table.rows {
                    tableCellCount += row.count
                    for cell in row {
                        detectedDataCount += cell.content.text.detectedData.count
                    }
                }
            }
            let structure = OCRDocumentStructureRecord(
                paragraphCount: document.paragraphs.count,
                tableCount: document.tables.count,
                tableRowCount: document.tables.reduce(0) { $0 + $1.rows.count },
                tableCellCount: tableCellCount,
                listCount: document.lists.count,
                barcodeCount: document.barcodes.count,
                detectedDataCount: detectedDataCount,
                lineCount: fragments.count)
            guard !fragments.isEmpty else {
                return DocumentPassOutcome(
                    structure: structure,
                    note: "Engine tài liệu chạy nhưng không cho dòng hợp lệ nào — pass (b) vắng, fail-open.")
            }
            let assembled = OCRFragmentMerger.assemble(fragments)
            var outcome = TracedPassOutcome(passID: .document)
            outcome.lines2 = assembled.lines
            outcome.lines = assembled.lines.legacyLines
            outcome.fragments = assembled.representatives
            outcome.elapsedSeconds = CFAbsoluteTimeGetCurrent() - start
            return DocumentPassOutcome(outcome: outcome, structure: structure)
        } catch {
            return DocumentPassOutcome(
                note: "Engine tài liệu lỗi (\(error.localizedDescription)) — pass (b) vắng, fail-open.")
        }
    }

    /// Dịch vụ đọc lại một vùng — THÂN THẬT của P2-2 cho giao diện
    /// RECONCILE-DESIGN §6 (cắt vùng từ ẢNH GỐC -> phóng to -> đọc
    /// -> ánh xạ hộp về không gian gốc, qua RegionGeometry của
    /// P2-1). Đặt lồng trong ScanView để dùng thẳng ocrPass/
    /// upscaledVariant của đường ống.
    ///
    /// TRÙNG TÊN ReOCRService — GIẢI QUYẾT CÓ CHỦ ĐÍCH: P2-1 định
    /// nghĩa một protocol tên ReOCRService (RegionHint, bất đồng
    /// bộ, trả [OCRLine2]) ở phần khung dưới file, trong khi P2-3
    /// cũng định nghĩa protocol ReOCRService (ReconcileRegionHint,
    /// đồng bộ, trả [OCRLine]). Hai định nghĩa cùng tên KHÔNG thể
    /// cùng tồn tại trong một module. Xử lý của P2-2: (1) gỡ định
    /// nghĩa protocol của P2-1 (chỗ cũ để lại ghi chú trỏ về đây);
    /// (2) lớp này TUÂN THỦ protocol ReOCRService của P2-3 — chữ ký
    /// hướng-reconcile duy nhất còn lại — và đồng thời phơi
    /// reReadOutcome (bản giàu hình học) cho đường ống dùng nội bộ,
    /// vì chữ ký của P2-3 không mang theo ảnh gốc lẫn hộp nên một
    /// mình nó không giữ được truy vết cấp mảnh.
    private final class TargetedReOCRService: ReOCRService {
        private let image: CGImage

        init(image: CGImage) {
            self.image = image
        }

        /// Chữ ký của P2-3: dịch hint (band của nó đã nới sẵn trong
        /// reconcile()) sang RegionHint rồi chạy thân chung; trả
        /// [OCRLine] legacy như giao diện yêu cầu.
        func recognizeRegion(_ hint: ReconcileRegionHint, upscale: Double) -> [OCRLine] {
            guard let band = hint.band else { return [] }
            let reason: RegionHint.Reason
            switch hint.reason {
            case .missingOrUnrepairable: reason = .missingOrUnrepairable
            case .qtyMismatch: reason = .qtyMismatch
            case .anchorConflict: reason = .anchorConflict
            case .totalOnlyAnchor: reason = .totalOnlyAnchor
            }
            let target = RegionHint(band: band, reason: reason, priority: hint.priority)
            return reReadOutcome(target, upscale: upscale).lines
        }

        /// Thân đọc lại giàu hình học. Vùng cắt lấy từ ẢNH GỐC bằng
        /// RegionGeometry.pixelCropRect (phép lật gốc trên-trái cho
        /// CGImage.cropping); hộp của mảnh đọc lại được ánh xạ từ
        /// không gian vùng về không gian ảnh gốc bằng boxTransform
        /// (tỉ lệ vùng/ảnh theo từng trục, cộng đáy vùng đã lật về
        /// gốc dưới-trái). regionID của mảnh = priority của hint.
        /// Fail-open: vùng suy biến/cắt lỗi -> outcome rỗng, vòng
        /// đọc lại tự dừng ở tầng trên.
        /// [PHÉP LẬT Y CHƯA KIỂM CHỨNG TRÊN MÁY — RECONCILE-DESIGN
        /// §6 điểm đo 1: BenchApp kết án bằng hint biết trước vị trí.]
        func reReadOutcome(_ hint: RegionHint, upscale: Double) -> TracedPassOutcome {
            let empty = TracedPassOutcome(passID: .reread)
            let rawCrop = RegionGeometry.pixelCropRect(band: hint.band,
                                                       imageWidth: image.width,
                                                       imageHeight: image.height)
            let cropRect = rawCrop.integral
                .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !cropRect.isNull, cropRect.width >= 8, cropRect.height >= 8,
                  let crop = image.cropping(to: cropRect) else {
                return empty
            }
            let source = ScanView.upscaledVariant(of: crop, factor: upscale) ?? crop
            let imageWidth = CGFloat(image.width)
            let imageHeight = CGFloat(image.height)
            let cropBottomNormalized = 1.0 - cropRect.maxY / imageHeight
            let transform: (CGRect) -> CGRect = { box in
                CGRect(x: (cropRect.minX + box.minX * cropRect.width) / imageWidth,
                       y: cropBottomNormalized + box.minY * (cropRect.height / imageHeight),
                       width: box.width * cropRect.width / imageWidth,
                       height: box.height * cropRect.height / imageHeight)
            }
            return ScanView.ocrPass(from: source, passID: .reread,
                                    boxTransform: transform, regionID: hint.priority)
        }
    }

    /// OCRFIX: điểm SẢN LƯỢNG của một bộ dòng — ước lượng "bộ này có
    /// giống một lượt đọc hoá đơn thành công không". TỪ P2-2: hàm
    /// này CHỈ còn được gọi để ghi số vào chẩn đoán (đối chiếu
    /// cũ/mới ở BenchApp) — nó KHÔNG còn chọn ứng viên ở bất kỳ
    /// đường quyết định nào (luật chọn nay là đối chiếu số học của
    /// Parser + Reconcile, xem finishPipeline). Ba thành phần, hệ
    /// số tròn trị:
    ///  1. +10 cho mỗi dòng chứa ít nhất 1 ký tự chữ-số (dòng rác
    ///     thuần ký hiệu không tính).
    ///  2. +(tổng số ký tự chữ-số của mọi dòng) / 10, chia nguyên —
    ///     thưởng cho lượng thông tin thật, để một ứng viên không
    ///     thắng chỉ nhờ nhiều dòng vụn ngắn.
    ///  3. Neo cấu trúc, mỗi loại tối đa 1 lần: SUBTOTAL +30; TOTAL
    ///     trên dòng KHÔNG phải SUBTOTAL +40; ký tự % +20; mẫu ngày
    ///     dd/dd/dd(dd) hoặc dd-dd-dd(dd) +20. Hoá đơn đọc trúng gần
    ///     như luôn có các neo này.
    /// Hiệu chuẩn trên chính sự cố Mẫu 001 (bản gương Python của
    /// đúng công thức này, xem AFTER.md gói OCRFIX): bộ rác 3 dòng
    /// ("28200860 / IV Z / 9969080000") được 3×10 + 21/10 + 0 = 32
    /// điểm; một bộ dòng Sam's trúng RÚT GỌN còn 14 dòng đã đạt 271
    /// điểm (đủ 4 neo = +110) — cách biệt ~8,5 lần ngay trên bản rút
    /// gọn, lượt đọc đầy đủ còn cao hơn; không nằm ở vùng nhiễu của
    /// phép chọn.
    private static func yieldScore(_ lines: [OCRLine]) -> Int {
        var contentLines = 0
        var alnumChars = 0
        var hasSubtotal = false
        var hasTotal = false
        var hasPercent = false
        var hasDate = false
        for line in lines {
            let text = line.text
            let alnum = text.unicodeScalars.filter {
                CharacterSet.alphanumerics.contains($0)
            }.count
            if alnum > 0 {
                contentLines += 1
                alnumChars += alnum
            }
            let upper = text.uppercased()
            if upper.contains("SUBTOTAL") {
                hasSubtotal = true
            } else if upper.contains("TOTAL") {
                hasTotal = true
            }
            if text.contains("%") { hasPercent = true }
            if !hasDate,
               text.range(of: #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#,
                          options: .regularExpression) != nil {
                hasDate = true
            }
        }
        var score = contentLines * 10 + alnumChars / 10
        if hasSubtotal { score += 30 }
        if hasTotal { score += 40 }
        if hasPercent { score += 20 }
        if hasDate { score += 20 }
        return score
    }

    /// Kết quả một lần thử tạo biến thể phái sinh: ảnh đã nắn (chỉ
    /// có khi cổng qua), tứ giác ĐÃ NỚI LỀ dùng cho phép nắn + ánh
    /// xạ hộp ngược, và verdict cổng để ghi chẩn đoán.
    private struct DerivedAttempt {
        var image: CGImage? = nil
        var expandedQuad: ReceiptGeometry.ReceiptQuad? = nil
        var record: OCRDerivedGateRecord
    }

    /// Tạo ảnh PHÁI SINH trong bộ nhớ (không bao giờ lưu) — luật
    /// P2-2 thay derivedOCRImage cũ: (1) phát hiện tứ giác; (2) tứ
    /// giác phải QUA CỔNG validateQuad của P2-1 (diện tích/tỉ lệ/
    /// lồi) — cổng nay là đường thật, không còn chế độ bóng; (3)
    /// phép nắn dùng expandedQuad (đã nới lề 1.5% mỗi cạnh) để
    /// không cắt mất cột tiền sát mép; (4) CHỈ CIPerspective-
    /// Correction — CIColorControls bỏ màu/tăng tương phản vô điều
    /// kiện của bản cũ đã GỠ (audit §4.3: grayscale/tương phản mặc
    /// định TẮT cho tới khi BenchApp chứng minh nó thắng). Mọi lỗi
    /// đều thu về "không có pass phái sinh" kèm lý do trong verdict.
    private static func derivedVariant(from cgImage: CGImage) -> DerivedAttempt {
        let detect = VNDetectRectanglesRequest()
        detect.minimumConfidence = PipelineConstants.quadDetectMinConfidence
        detect.maximumObservations = 1
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([detect])
        } catch {
            return DerivedAttempt(record: OCRDerivedGateRecord(
                quadDetected: false, gatePassed: nil, areaFraction: nil, aspect: nil,
                reasons: ["VNDetectRectanglesRequest lỗi: \(error.localizedDescription)"]))
        }
        guard let quad = (detect.results ?? []).first else {
            return DerivedAttempt(record: OCRDerivedGateRecord(
                quadDetected: false, gatePassed: nil, areaFraction: nil, aspect: nil,
                reasons: ["Không phát hiện được tứ giác nào."]))
        }
        let gate = ReceiptGeometry.validateQuad(quad, imageWidth: cgImage.width,
                                                imageHeight: cgImage.height)
        var record = OCRDerivedGateRecord(quadDetected: true, gatePassed: gate.passed,
                                          areaFraction: gate.areaFraction, aspect: gate.aspect,
                                          reasons: gate.reasons)
        guard gate.passed, let expanded = gate.expandedQuad else {
            record.reasons.append("Cổng trượt — không sinh pass phái sinh.")
            return DerivedAttempt(record: record)
        }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        func ciPoint(_ point: [Double]) -> CIVector {
            CIVector(x: CGFloat(point[0]) * w, y: CGFloat(point[1]) * h)
        }
        let source = CIImage(cgImage: cgImage)
        guard let perspective = CIFilter(name: "CIPerspectiveCorrection") else {
            record.reasons.append("Không tạo được CIPerspectiveCorrection — bỏ pass phái sinh.")
            return DerivedAttempt(record: record)
        }
        perspective.setValue(source, forKey: kCIInputImageKey)
        perspective.setValue(ciPoint(expanded.topLeft), forKey: "inputTopLeft")
        perspective.setValue(ciPoint(expanded.topRight), forKey: "inputTopRight")
        perspective.setValue(ciPoint(expanded.bottomLeft), forKey: "inputBottomLeft")
        perspective.setValue(ciPoint(expanded.bottomRight), forKey: "inputBottomRight")
        guard let corrected = perspective.outputImage else {
            record.reasons.append("CIPerspectiveCorrection không cho ảnh ra — bỏ pass phái sinh.")
            return DerivedAttempt(record: record)
        }
        let context = CIContext(options: nil)
        guard let image = context.createCGImage(corrected, from: corrected.extent) else {
            record.reasons.append("Không kết xuất được ảnh phái sinh — bỏ pass phái sinh.")
            return DerivedAttempt(record: record)
        }
        record.reasons.append("Cổng qua — pass phái sinh dùng expandedQuad, KHÔNG qua CIColorControls.")
        return DerivedAttempt(image: image, expandedQuad: expanded, record: record)
    }

    /// Phóng một ảnh theo hệ số bằng CILanczosScaleTransform (đúng
    /// bộ lọc audit §4.3 chỉ định cho P-UPSCALED; cũng dùng cho vùng
    /// đọc lại). Fail-open: lỗi ở bất kỳ bước nào -> nil.
    private static func upscaledVariant(of cgImage: CGImage, factor: Double) -> CGImage? {
        guard factor > 1 else { return nil }
        let source = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: factor), forKey: kCIInputScaleKey)
        filter.setValue(NSNumber(value: 1.0), forKey: kCIInputAspectRatioKey)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        return context.createCGImage(output, from: output.extent)
    }

    /// Chiều cao dòng TRUNG VỊ ước lượng (pixel) từ hộp mảnh của một
    /// pass: trung vị của (chiều cao chuẩn hoá × chiều cao ảnh).
    /// nil khi pass không có mảnh nào — không có cơ sở kích hoạt
    /// pass phóng to.
    private static func medianLineHeightPixels(of outcome: TracedPassOutcome,
                                               imageHeight: Int) -> Double? {
        guard !outcome.fragments.isEmpty else { return nil }
        let heights = outcome.fragments
            .map { Double($0.box.height) * Double(imageHeight) }
            .sorted()
        let mid = heights.count / 2
        if heights.count % 2 == 1 { return heights[mid] }
        return (heights[mid - 1] + heights[mid]) / 2
    }

    /// Ánh xạ NGƯỢC một hộp chuẩn hoá từ biến thể QUAY TOÀN CỤC về
    /// không gian ảnh gốc: biến thể là ảnh gốc quay quanh tâm theo
    /// góc dốc màn hình φ (đúng phép của ReceiptGeometry.rotated),
    /// khung biến thể là hộp bao của ảnh đã quay nên tâm của nó
    /// trùng tâm ảnh gốc; hộp đích = hộp bao của 4 góc sau khi quay
    /// ngược −φ quanh tâm, đổi về chuẩn hoá gốc.
    /// [CHƯA KIỂM CHỨNG TRÊN MÁY — cùng họ rủi ro dấu quay của P2-1:
    /// BenchApp kiểm bằng ảnh nghiêng nhân tạo góc biết trước.]
    private static func mapBoxFromGloballyRotatedVariant(_ box: CGRect,
                                                         variantWidth: Int, variantHeight: Int,
                                                         sourceWidth: Int, sourceHeight: Int,
                                                         screenSlopeDegrees: Double) -> CGRect {
        let center = CGPoint(x: Double(sourceWidth) / 2, y: Double(sourceHeight) / 2)
        let extentMin = CGPoint(x: center.x - Double(variantWidth) / 2,
                                y: center.y - Double(variantHeight) / 2)
        let radians = -screenSlopeDegrees * Double.pi / 180.0
        let cosR = cos(radians)
        let sinR = sin(radians)
        func unrotate(_ corner: CGPoint) -> CGPoint {
            let px = Double(corner.x) * Double(variantWidth) + Double(extentMin.x)
            let py = Double(corner.y) * Double(variantHeight) + Double(extentMin.y)
            let dx = px - Double(center.x)
            let dy = py - Double(center.y)
            return CGPoint(x: (Double(center.x) + dx * cosR - dy * sinR) / Double(sourceWidth),
                           y: (Double(center.y) + dx * sinR + dy * cosR) / Double(sourceHeight))
        }
        let corners = [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                       CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY)]
            .map(unrotate)
        let xs = corners.map { $0.x }
        let ys = corners.map { $0.y }
        return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                      width: (xs.max() ?? 0) - (xs.min() ?? 0),
                      height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    /// Ánh xạ NGƯỢC một hộp chuẩn hoá từ ảnh phái sinh (đã nắn bằng
    /// CIPerspectiveCorrection trên expandedQuad) về không gian ảnh
    /// gốc bằng phép chiếu (homography) hình vuông đơn vị -> tứ
    /// giác đích: góc (0,0)/(1,0)/(1,1)/(0,1) của ảnh đã nắn tương
    /// ứng bottomLeft/bottomRight/topRight/topLeft của tứ giác gốc.
    /// Hộp đích = hộp bao trục-thẳng của 4 góc đã chiếu (xấp xỉ có
    /// chủ đích: hộp mảnh trong ảnh nắn là hình thang trong ảnh
    /// gốc, tầng hợp nhất chỉ cần hộp bao của nó).
    /// [CHƯA KIỂM CHỨNG TRÊN MÁY — hướng/chiều của phép chiếu là một
    /// trong các điểm BenchApp phải kết án.]
    private static func mapBoxFromPerspectiveVariant(_ box: CGRect,
                                                     expandedQuad: ReceiptGeometry.ReceiptQuad) -> CGRect {
        let d00 = expandedQuad.bottomLeft
        let d10 = expandedQuad.bottomRight
        let d11 = expandedQuad.topRight
        let d01 = expandedQuad.topLeft
        guard d00.count == 2, d10.count == 2, d11.count == 2, d01.count == 2 else { return box }
        // Giải hệ homography (chuẩn hoá h33 = 1) theo công thức
        // hình vuông -> tứ giác; suy biến (mẫu số 0) -> phép affine.
        let dx1 = d10[0] - d11[0]
        let dx2 = d01[0] - d11[0]
        let dx3 = d00[0] - d10[0] + d11[0] - d01[0]
        let dy1 = d10[1] - d11[1]
        let dy2 = d01[1] - d11[1]
        let dy3 = d00[1] - d10[1] + d11[1] - d01[1]
        var g = 0.0
        var hh = 0.0
        let denominator = dx1 * dy2 - dx2 * dy1
        if abs(dx3) > 1e-12 || abs(dy3) > 1e-12 {
            guard abs(denominator) > 1e-12 else { return box }
            g = (dx3 * dy2 - dx2 * dy3) / denominator
            hh = (dx1 * dy3 - dx3 * dy1) / denominator
        }
        let a = d10[0] * (g + 1) - d00[0]
        let b = d01[0] * (hh + 1) - d00[0]
        let c = d00[0]
        let d = d10[1] * (g + 1) - d00[1]
        let e = d01[1] * (hh + 1) - d00[1]
        let f = d00[1]
        func project(_ point: CGPoint) -> CGPoint {
            let x = Double(point.x)
            let y = Double(point.y)
            let w = g * x + hh * y + 1
            guard abs(w) > 1e-12 else { return point }
            return CGPoint(x: (a * x + b * y + c) / w, y: (d * x + e * y + f) / w)
        }
        let corners = [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                       CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY)]
            .map(project)
        let xs = corners.map { $0.x }
        let ys = corners.map { $0.y }
        return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                      width: (xs.max() ?? 0) - (xs.min() ?? 0),
                      height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    /// Trích mảnh chữ từ ảnh đầy đủ. F2c: ảnh cao được cắt thành lát
    /// dọc ~1600px chồng nhau 200px, OCR từng lát, rồi quy đổi hộp của
    /// mỗi mảnh về toạ độ ảnh đầy đủ TRƯỚC khi ráp hàng. Ngoài ngưỡng
    /// đó: 1 lượt OCR như cũ. handler.perform là ĐỒNG BỘ nên vòng lát
    /// chạy tuần tự trong hàng đợi nền — không có request nào chạy
    /// song song.
    /// OCRFIX — NGƯỠNG CẮT MỚI: cao > 2000px là cắt, BẤT KỂ tỉ lệ
    /// (WP4 đòi thêm tỉ lệ cao/rộng > 3.0). Lý do: hoá đơn giấy dài
    /// là ca THƯỜNG chứ không phải ca cá biệt theo tỉ lệ — Mẫu 001
    /// (1320×2868, tỉ lệ 2.17) bị ngưỡng cũ bỏ qua, phải đọc một lượt
    /// trên toàn chiều cao 2868px. Rủi ro vùng chồng 200px sinh mảnh
    /// trùng: từ P2-2 do KHỬ TRÙNG MỜ của OCRFragmentMerger xử (so
    /// giống hệt của dedupeOverlap cũ đã bị thay ở đường mới — xem
    /// AFTER gói P2-2); phân tích rủi ro gốc ở AFTER.md gói OCRFIX.
    /// P2-1: kết quả thu mảnh của một lượt đọc — ngoài các mảnh còn có
    /// số lát đã chạy và các VÙNG MÙ (dải ảnh mà lượt OCR của lát đó
    /// ném lỗi; PIPELINE-AUDIT D-2.5: trước đây lát lỗi bị nuốt im lặng
    /// thành [] và không tầng nào biết để nghi ngờ khoảng trống đó).
    private struct CollectedFragments {
        var fragments: [OCRFrag] = []
        var tileCount: Int = 0
        var blindBands: [OCRDiagRect] = []
    }

    private static func collectFragments(cgImage: CGImage) -> CollectedFragments {
        let w = cgImage.width
        let h = cgImage.height
        guard h > 2000 else {
            let single = ocrFragments(tile: cgImage, tileTopPx: 0, tileHeightPx: h,
                                      fullHeightPx: h, tileOrdinal: nil)
            var collected = CollectedFragments()
            collected.fragments = single.fragments
            collected.tileCount = 1
            if single.failed {
                collected.blindBands = [OCRDiagRect(x: 0, y: 0, width: 1, height: 1)]
            }
            return collected
        }
        var collected = CollectedFragments()
        let tileHeight = 1600
        let overlap = 200
        let step = tileHeight - overlap
        var top = 0
        var ordinal = 0
        while top < h {
            let th = min(tileHeight, h - top)
            if let tile = cgImage.cropping(to: CGRect(x: 0, y: top, width: w, height: th)) {
                let part = ocrFragments(tile: tile, tileTopPx: top, tileHeightPx: th,
                                        fullHeightPx: h, tileOrdinal: ordinal)
                collected.fragments += part.fragments
                collected.tileCount += 1
                if part.failed {
                    // Dải mù theo toạ độ chuẩn hoá gốc dưới-trái của
                    // ảnh đầy đủ: lát chiếm các hàng pixel từ top tới
                    // top+th tính từ ĐỈNH -> lật về gốc dưới-trái.
                    let yMin = 1.0 - Double(top + th) / Double(h)
                    collected.blindBands.append(OCRDiagRect(x: 0, y: yMin, width: 1,
                                                            height: Double(th) / Double(h)))
                }
            }
            ordinal += 1
            if top + th >= h { break }
            top += step
        }
        return collected
    }

    /// OCR 1 lát (hoặc cả ảnh khi không cắt) và quy đổi hộp về ảnh đầy đủ.
    /// Trục Y: Vision dùng gốc dưới-trái TRONG lát; lát bắt đầu ở tileTopPx
    /// tính từ ĐỈNH ảnh đầy đủ (toạ độ cắt của CGImage) — công thức dưới
    /// đổi cạnh-trên của hộp thành khoảng cách từ đỉnh ảnh đầy đủ rồi mới
    /// lật về gốc dưới-trái chuẩn hoá. [Hướng cắt CGImage + phép quy đổi
    /// này CHƯA KIỂM CHỨNG trên máy — bài kiểm mốc M1/WP4 bước 3.]
    /// P2-1: trả thêm cờ `failed` — perform() ném lỗi thì lát này là
    /// VÙNG MÙ phải ghi vào chẩn đoán (D-2.5), không còn là [] im lặng.
    /// Mảnh nay giữ ứng viên 2–3 của Vision (alternates, D-2.4) và số
    /// thứ tự lát (tileIndex) — ứng viên 1 và phép quy đổi hộp KHÔNG đổi.
    private static func ocrFragments(tile: CGImage, tileTopPx: Int, tileHeightPx: Int,
                                     fullHeightPx: Int, tileOrdinal: Int?) -> (fragments: [OCRFrag], failed: Bool) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        // Hoá đơn đầy mã số — tắt tự sửa chính tả để khỏi "sửa" nhầm mã/tiền.
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: tile, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ([], true)
        }
        let observations = (request.results ?? [])
        let fragments = observations.compactMap { obs -> OCRFrag? in
            let candidates = obs.topCandidates(3)
            guard let candidate = candidates.first else { return nil }
            let b = obs.boundingBox
            let topFromFullTop = Double(tileTopPx) + (1.0 - Double(b.maxY)) * Double(tileHeightPx)
            let heightFull = Double(b.height) * Double(tileHeightPx) / Double(fullHeightPx)
            let maxYFull = 1.0 - topFromFullTop / Double(fullHeightPx)
            let box = CGRect(x: b.minX, y: CGFloat(maxYFull - heightFull),
                             width: b.width, height: CGFloat(heightFull))
            return OCRFrag(text: candidate.string, confidence: Double(candidate.confidence), box: box,
                           alternates: candidates.dropFirst().map { (text: $0.string, confidence: Double($0.confidence)) },
                           tileIndex: tileOrdinal)
        }
        return (fragments, false)
    }

    /// [TƯƠNG THÍCH — đường P2-2 KHÔNG gọi hàm này nữa] Khử mảnh
    /// trùng sinh ra trong vùng chồng 200px giữa hai lát theo luật
    /// cũ: cùng chữ (so GIỐNG HỆT) + hộp giao nhau >= 50% diện tích
    /// hộp nhỏ hơn -> giữ bản có độ tin cậy cao hơn (CODE-AUDIT
    /// F2c). Giữ lại làm bề mặt tương thích cho các điểm gọi ngoài
    /// đường ống mới; khử trùng ở đường mới là bản MỜ của
    /// OCRFragmentMerger (audit D-3.1 kết tội so-giống-hệt).
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

    /// [TƯƠNG THÍCH — đường P2-2 KHÔNG gọi hàm này nữa] F2a — ráp
    /// mảnh thành HÀNG THỊ GIÁC (nguyên văn thuật toán CODE-AUDIT
    /// F2a): sắp trên->xuống theo maxY; gom mảnh có khoảng Y chồng >= 50%
    /// chiều cao mảnh NGẮN HƠN vào cùng hàng; trong hàng sắp trái->phải
    /// theo minX và nối bằng 1 khoảng trắng; độ tin cậy của dòng ráp = MIN
    /// của các mảnh (mảnh yếu nhất quyết định — không để tiền mờ trốn sau
    /// nhãn nét). Hàng giữ thứ tự trên->xuống vì mảnh đã sắp và chỉ nối
    /// vào hàng đang mở cuối cùng. Ráp hàng ở đường mới là bản cụm-Y
    /// có chốt chặn của OCRFragmentMerger (audit D-3.3 kết tội cơ
    /// chế neo-hàng-cuối của F2a).
    static func mergeRows(_ fragsIn: [OCRFrag]) -> [OCRLine] {
        // P2-1: mergeRows nay là lớp vỏ mỏng trên mergeRowsTraced —
        // THUẬT TOÁN KHÔNG ĐỔI (cùng sắp xếp, cùng luật gom, cùng phép
        // nối, cùng luật min-confidence); bản traced chỉ trả thêm danh
        // sách mảnh cấu thành để OCRLine2 truy vết (D-3.2).
        mergeRowsTraced(fragsIn).map(\.line)
    }

    /// Bản có truy vết của mergeRows: mỗi dòng kèm chỉ số (trong mảng
    /// `fragsIn` gốc) của các mảnh cấu thành, THEO ĐÚNG THỨ TỰ NỐI
    /// (trái->phải sau khi sắp trong hàng) — để tầng trên ánh xạ sang
    /// fragmentID mà không phải đoán lại phép gom.
    static func mergeRowsTraced(_ fragsIn: [OCRFrag]) -> [(line: OCRLine, memberIndices: [Int])] {
        // Sắp trên->dưới theo maxY — mang theo chỉ số gốc. sort(by:)
        // của Swift ổn định (stable) nên thứ tự khi maxY bằng nhau
        // trùng đúng bản không-truy-vết.
        let order = fragsIn.indices.sorted { fragsIn[$0].box.maxY > fragsIn[$1].box.maxY }
        var rows: [[Int]] = []
        for index in order {
            let f = fragsIn[index]
            if let row = rows.last, let anchorIndex = row.first {
                let anchor = fragsIn[anchorIndex]
                let overlap = min(f.box.maxY, anchor.box.maxY) - max(f.box.minY, anchor.box.minY)
                let shorter = min(f.box.height, anchor.box.height)
                if shorter > 0 && overlap / shorter >= 0.5 {
                    rows[rows.count - 1].append(index)
                    continue
                }
            }
            rows.append([index])
        }
        return rows.map { row in
            let sorted = row.sorted { fragsIn[$0].box.minX < fragsIn[$1].box.minX }
            let line = OCRLine(text: sorted.map { fragsIn[$0].text }.joined(separator: " "),
                               confidence: sorted.map { fragsIn[$0].confidence }.min() ?? 0)
            return (line: line, memberIndices: sorted)
        }
    }
}

// MARK: - P2-1: Hằng số đường ống (PIPELINE-AUDIT §4.8)

/// Mọi ngưỡng của đường ống mới gom về MỘT bảng. Mỗi hằng số ghi trạng
/// thái: KHỞI ĐIỂM = giá trị có chủ đích nhưng CHƯA đo trên bench —
/// không được mô tả là "đã tinh chỉnh" trong bất kỳ tài liệu giao nào
/// (luật rút từ sự cố L-2026-11-10-6). ĐÃ ĐO phải kèm ngày + bộ bench.
enum PipelineConstants {
    /// Cạnh dài tối đa của ảnh thăm dò đo nghiêng (góc không đổi theo
    /// tỉ lệ thu nhỏ; ảnh nhỏ đọc nhanh hơn). KHỞI ĐIỂM.
    static let skewProbeMaxDimension = 1400
    /// Số dòng đo được góc tối thiểu để tin ước lượng nghiêng. KHỞI ĐIỂM.
    static let skewMinReliableLines = 6
    /// Số dải ngang cho khử nghiêng theo dải (giấy lượn sóng). KHỞI ĐIỂM.
    static let skewBandCount = 4
    /// Góc dưới ngưỡng này coi như giấy đã phẳng — không sản xuất biến
    /// thể nắn (tránh biến đổi thừa). KHỞI ĐIỂM.
    static let skewMinAngleDegrees = 0.3
    /// Góc trên ngưỡng này coi như ước lượng không tin được (hoá đơn
    /// nghiêng tới mức đó nên chụp/quét lại) — không nắn. KHỞI ĐIỂM.
    static let skewMaxAngleDegrees = 12.0
    /// Mọi dải lệch khỏi góc toàn cục dưới ngưỡng này -> chỉ cần nắn
    /// toàn cục một phép quay. KHỞI ĐIỂM.
    static let bandDeviationForGlobalOnlyDegrees = 0.5
    /// Tỉ lệ chồng lấp giữa các dải khi nắn theo dải. KHỞI ĐIỂM.
    static let bandOverlapFraction = 0.3
    /// Ngưỡng tin cậy phát hiện tứ giác — GIỮ 0.5 như luật phát
    /// hiện của derivedOCRImage cũ để verdict của cổng so sánh được
    /// với hành vi đã chạy. KHỞI ĐIỂM.
    static let quadDetectMinConfidence: Float = 0.5
    /// Cổng tứ giác (audit §4.3): diện tích tứ giác tối thiểu so với
    /// ảnh. KHỞI ĐIỂM.
    static let quadMinAreaFraction = 0.55
    /// Cổng tứ giác: tỉ lệ cao/rộng của tờ hoá đơn. KHỞI ĐIỂM.
    static let quadAspectMin = 1.2
    static let quadAspectMax = 12.0
    /// Cổng tứ giác: nới lề mỗi cạnh trước khi nắn (audit §4.3). KHỞI ĐIỂM.
    static let quadMarginFraction = 0.015
    /// Đọc lại có mục tiêu: nới dải-y mỗi phía theo hệ số này
    /// (RECONCILE-DESIGN §6 — luật của tầng đối chiếu, không phải
    /// ngưỡng tự chọn).
    static let regionBandExpansion: CGFloat = 1.5

    // MARK: P2-2 — ngưỡng hợp nhất v2 + kích hoạt pass (audit §4.4/§4.5/§4.3)
    // Mọi giá trị dưới đây đều là KHỞI ĐIỂM (chưa đo) — BenchApp kết án.

    /// Khử trùng mờ: hai hộp được coi là chồng nhau khi IoU >= giá
    /// trị này. KHỞI ĐIỂM (audit §4.4).
    static let dedupeIoUThreshold = 0.4
    /// Khử trùng mờ: hoặc khi phần giao >= tỉ lệ này của hộp NHỎ
    /// hơn (bắt mảnh cụt nằm trọn trong mảnh trọn ở vùng chồng lát).
    /// KHỞI ĐIỂM.
    static let dedupeContainmentThreshold = 0.5
    /// Khử trùng mờ: hoặc khi chồng-Y >= tỉ lệ này của chiều cao
    /// mảnh ngắn hơn VÀ khoảng cách tâm-X <= dedupeCenterXDistance-
    /// Heights lần chiều cao mảnh ngắn hơn. KHỞI ĐIỂM (audit §4.4).
    static let dedupeYOverlapFraction = 0.5
    static let dedupeCenterXDistanceHeights = 0.5
    /// Khử trùng mờ: hai text là "cùng một dòng đọc lại" khi khoảng
    /// cách sửa trên bản chuẩn hoá <= max(1, tỉ lệ này × độ dài).
    /// KHỞI ĐIỂM (audit §4.4).
    static let fuzzyEditDistanceFraction = 0.15
    /// Ráp hàng v2: hai mảnh cùng hàng khi khoảng Y (đã hiệu chỉnh
    /// nghiêng) giao nhau >= tỉ lệ này của chiều cao mảnh ngắn hơn.
    /// KHỞI ĐIỂM (audit §4.5).
    static let rowYOverlapFraction = 0.40
    /// Ráp hàng v2: chốt chặn nuốt hàng — cụm có tổng chiều cao vượt
    /// hệ số này × chiều cao dòng trung vị thì tách tại khe Y lớn
    /// nhất. KHỞI ĐIỂM (audit §4.5).
    static let rowSplitHeightMultiple = 1.6
    /// Pass phóng to: kích hoạt khi chiều cao dòng trung vị ước
    /// lượng của pass gốc < ngưỡng này (pixel). KHỞI ĐIỂM (audit
    /// §4.3, ENGINE-REPORT §3 — ca Mẫu 002 chữ cao ~12–15px).
    static let lowResolutionLineHeightPx = 16.0
    /// Hệ số phóng của pass phóng to (Lanczos). KHỞI ĐIỂM (audit §4.3).
    static let upscaleFactor = 2.0
    /// Hệ số phóng vùng đọc lại có mục tiêu. KHỞI ĐIỂM
    /// (RECONCILE-DESIGN §6 để ngỏ 2×/3× cho buổi đo trên máy).
    static let reReadUpscaleFactor = 2.0
}

// MARK: - P2-1: Mô hình dòng/mảnh cấp 2 (PIPELINE-AUDIT §4.1, diệt D-3.2)

/// Lượt đọc sinh ra một mảnh/dòng. P2-2 dùng đủ: .original /
/// .deskewed / .derived / .upscaled / .document (engine (b) iOS 26
/// RecognizeDocumentsRequest — ca riêng để truy vết nguồn không bị
/// mạo danh là .original) / .reread; .pdfTextLayer cho đường lớp
/// chữ PDF (không qua OCR).
enum OCRPassID: String, Codable {
    case original
    case deskewed
    case derived
    case upscaled
    case document
    case reread
    case pdfTextLayer
}

/// Mảnh chữ cấp 2: đơn vị hồ sơ nhỏ nhất của đường ống mới. Khác
/// OCRFrag ở chỗ mảnh mang DANH TÍNH truy vết (fragmentID + passID +
/// tileIndex) và ứng viên phụ của Vision — để mọi hợp nhất phía sau
/// đều kiểm lại được, không tầng nào phải vứt thông tin (audit §4).
struct OCRFragment2 {
    /// Khoá truy vết: tăng dần theo thứ tự đọc trong MỘT lượt đọc của
    /// MỘT tờ (gán sau khử trùng — xem ScanView.ocrPass).
    var fragmentID: Int
    /// Ứng viên 1 của Vision.
    var text: String
    /// Ứng viên 2–3 của Vision cho cùng observation (rỗng nếu không có).
    var alternates: [(text: String, confidence: Double)]
    /// Độ tin cậy của ứng viên 1.
    var confidence: Double
    /// Hộp chuẩn hoá gốc dưới-trái, KHÔNG GIAN ẢNH GỐC ĐẦY ĐỦ.
    var box: CGRect
    var passID: OCRPassID
    /// Lát sinh ra mảnh (nil = đọc toàn khung).
    var tileIndex: Int?
    /// Vùng đọc lại sinh ra mảnh (chỉ .reread mới có; P2-2/P2-3).
    var regionID: Int? = nil
    // LƯU Ý THIẾT KẾ (ghi rõ thay vì im lặng): audit §4.1 phác cả
    // charConfidences, nhưng VNRecognizeTextRequest CHỈ phơi độ tin
    // cậy của TOÀN ứng viên (VNRecognizedText.confidence) — không có
    // độ tin cậy theo ký tự để mà lấy. Muốn độ mịn ký tự phải đo
    // đường API khác ở BenchApp (RECONCILE-DESIGN §6 điểm đo 4);
    // P2-1 không chế trường không có nguồn dữ liệu thật.
}

/// Dòng chữ cấp 2: như OCRLine nhưng giữ hộp hợp nhất, spans truy về
/// từng mảnh cấu thành, các lượt đọc đã góp mặt, và biến thể tranh
/// chấp (hai lượt bất đồng trên token tiền — nguyên liệu cho tầng đối
/// chiếu ở P2-3 phán, audit §4.6).
struct OCRLine2 {
    var text: String
    var confidence: Double
    /// Hợp nhất (union) hộp của mọi mảnh cấu thành.
    var box: CGRect
    /// Mỗi mảnh cấu thành + khoảng ký tự nó chiếm trong `text`.
    var spans: [(fragmentID: Int, rangeInLine: Range<String.Index>)]
    var passSources: Set<OCRPassID>
    /// Hai lượt đọc bất đồng trên token tiền của dòng này.
    var contested: Bool = false
    /// Các biến thể text đã bị nuốt khi hợp nhất (kèm độ tin cậy).
    var alternates: [(text: String, confidence: Double)] = []

    /// Lớp tương thích: Parser hiện hành dùng OCRLine nguyên trạng
    /// trong giai đoạn chuyển tiếp — chuyển đổi này là đường DUY NHẤT
    /// được phép quên hình học, và chỉ quên ở ranh giới Parser.
    var legacy: OCRLine {
        OCRLine(text: text, confidence: confidence)
    }
}

extension Array where Element == OCRLine2 {
    /// Chuyển cả bộ dòng cấp 2 sang [OCRLine] cho Parser hiện hành.
    var legacyLines: [OCRLine] {
        map(\.legacy)
    }
}

// MARK: - P2-1: Chẩn đoán bắt buộc mỗi tờ (PIPELINE-AUDIT §4.7)

/// Hình chữ nhật chuẩn hoá (gốc dưới-trái) dạng Codable — CGRect
/// không mang theo khi ghi JSON nên chẩn đoán dùng kiểu này.
struct OCRDiagRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Vết của MỘT lượt đọc trong chẩn đoán: chạy mấy lát, ra bao nhiêu
/// mảnh/dòng, vùng mù nào (lát lỗi) — đủ để sự cố lần sau tự kết án
/// ở cấp pass trước khi cần tới cấp mảnh.
struct OCRPassRecord: Codable {
    var passID: OCRPassID
    var tileCount: Int
    var fragmentCount: Int
    var lineCount: Int
    /// Điểm yieldScore của bộ dòng — TỪ P2-2 CHỈ CÒN LÀ SỐ LỊCH SỬ
    /// trong chẩn đoán (luật chọn theo yieldScore đã bị loại khỏi
    /// đường quyết định — audit §4.6); giữ lại để đối chiếu hành vi
    /// cũ/mới trên cùng một tờ ở BenchApp.
    var yieldScore: Int?
    var blindBands: [OCRDiagRect]
    /// Thời gian chạy của pass (giây) — P2-2 bổ sung cho ngân sách
    /// độ trễ đa pass (audit §4.8). Optional để file chẩn đoán
    /// schema 1 của P2-1 vẫn giải mã được.
    var elapsedSeconds: Double? = nil
}

/// Ai thắng trong luật chọn OCRFIX (giai đoạn chuyển tiếp) — đây là
/// đúng mẩu bằng chứng còn thiếu trong sự cố Mẫu 001 (audit §5 mục 2:
/// "ứng viên nào đã thắng trên máy" vĩnh viễn không biết với bản cũ;
/// từ P2-1 trở đi nó được ghi lại). TỪ P2-2: luật chọn OCRFIX đã
/// chết; trường này chỉ còn để file chẩn đoán cũ giải mã được —
/// đường ống mới để nó nil và ghi bộ thắng ở trường candidateScores/
/// winningCandidate (schema 2).
struct OCRLegacySelectionRecord: Codable {
    var originalScore: Int
    var derivedScore: Int?
    var winner: String // "original" | "derived"
}

/// Quyết định của Lớp 0 (hình học) trong lượt đọc này.
struct OCRGeometryRecord: Codable {
    /// Góc dốc màn hình toàn cục đo được (độ; + = dòng chúc xuống về
    /// phía phải; nil = không đo được/không tin).
    var globalSkewDegrees: Double?
    /// Góc theo dải, thứ tự TỪ TRÊN XUỐNG (nil ở dải không đủ mẫu).
    var bandSkewDegreesTopToBottom: [Double?]
    var sampleLineCount: Int
    var reliable: Bool
    var decision: String
    /// Biến thể đã nắn có được sản xuất không, và lượt đọc THỬ trên
    /// biến thể (chỉ ghi số mảnh/dòng ở P2-1 — nội dung chưa dùng).
    var deskewVariantProduced: Bool = false
    var deskewVariantFragmentCount: Int? = nil
    var deskewVariantLineCount: Int? = nil

    init(assessment: ReceiptGeometry.SkewAssessment) {
        globalSkewDegrees = assessment.globalDegrees
        bandSkewDegreesTopToBottom = assessment.bandDegreesTopToBottom
        sampleLineCount = assessment.sampleLineCount
        reliable = assessment.reliable
        decision = assessment.decision
    }
}

/// Verdict của cổng tứ giác D-2.3: ở P2-1 nó chạy ở chế độ bóng
/// (ghi lại, chưa chặn); TỪ P2-2 verdict này là ĐƯỜNG THẬT —
/// ScanView.derivedVariant tính nó qua ReceiptGeometry.validateQuad
/// và chỉ sinh pass phái sinh khi cổng qua (xem OCRDerivedGateRecord).
struct OCRDerivedGateRecord: Codable {
    var quadDetected: Bool
    var gatePassed: Bool?
    var areaFraction: Double?
    var aspect: Double?
    var reasons: [String]
}

/// P2-2: điểm số học của MỘT bộ ứng viên trong lượt chọn bộ thắng
/// — bằng chứng để sự cố "bộ này thắng bộ kia" tự kết án được
/// (khác hẳn sự cố OCRFIX, nơi không ai biết ứng viên nào đã thắng
/// và vì sao). ledgerDeltaCents nil = bộ không có subtotal để tính
/// lệch (xấu nhất trong phép chọn).
struct OCRCandidateScoreRecord: Codable {
    var candidateName: String
    var ledgerDeltaCents: Int?
    var anchorCount: Int
    var anchorsPresent: [String]
    var reconcileStatus: String
    var itemCount: Int
    var lineCount: Int
    /// Chỉ ghi để đối chiếu — KHÔNG tham gia quyết định (audit §4.6).
    var yieldScore: Int?
    var winner: Bool
}

/// P2-2: vết của MỘT vòng trong phiên đối chiếu/đọc lại (vòng 0 =
/// lượt reconcile đầu trên bộ thắng, luôn accepted = true theo
/// định nghĩa "kết quả hiện hành"; các vòng sau ghi accepted theo
/// đúng phán quyết đơn điệu của ReconcileSession).
struct OCRReconcileRoundRecord: Codable {
    var round: Int
    var regionReasons: [String]
    var accepted: Bool
    var reconcileStatus: String
    var moneyDeltaCents: Int?
    var itemCount: Int
}

/// P2-2: cấu trúc mà engine tài liệu (b) nhìn thấy trên tờ — chỉ
/// SỐ LƯỢNG (paragraphs/tables/lists/barcodes/detectedData), không
/// chép nội dung detectedData vào chẩn đoán.
struct OCRDocumentStructureRecord: Codable {
    var paragraphCount: Int
    var tableCount: Int
    var tableRowCount: Int
    var tableCellCount: Int
    var listCount: Int
    var barcodeCount: Int
    var detectedDataCount: Int
    var lineCount: Int
}

/// Chẩn đoán đầy đủ của một lượt đọc một tờ — ghi thành file phụ JSON
/// cạnh ảnh gốc (OCRDiagnosticsStore), KHÔNG qua model SwiftData.
/// Schema 2 (P2-2) cộng các trường optional (candidateScores /
/// winningCandidate / reconcileRounds / documentStructure) — file
/// schema 1 của P2-1 vẫn giải mã được vì mọi trường mới đều optional.
struct OCRDiagnostics: Codable {
    var schemaVersion: Int = 2
    var createdAt: Date = Date()
    var parserVersion: String = currentParserVersion
    /// "1320x2868" cho đường OCR; "pdf" cho đường lớp chữ.
    var sourceImagePixels: String = ""
    var passes: [OCRPassRecord] = []
    var legacySelection: OCRLegacySelectionRecord? = nil
    var geometry: OCRGeometryRecord? = nil
    var derivedGate: OCRDerivedGateRecord? = nil
    /// Mọi vùng mù của mọi pass, gộp phẳng để màn chẩn đoán đọc nhanh.
    var blindBands: [OCRDiagRect] = []
    var notes: [String] = []
    /// P2-2 (schema 2, optional): điểm số học của mọi bộ ứng viên.
    var candidateScores: [OCRCandidateScoreRecord]? = nil
    /// P2-2 (schema 2, optional): tên bộ thắng ("merged" hoặc tên pass).
    var winningCandidate: String? = nil
    /// P2-2 (schema 2, optional): vết các vòng reconcile/đọc lại.
    var reconcileRounds: [OCRReconcileRoundRecord]? = nil
    /// P2-2 (schema 2, optional): cấu trúc engine tài liệu nhìn thấy.
    var documentStructure: OCRDocumentStructureRecord? = nil

    /// Vết tối thiểu cho đường lớp chữ PDF (không qua OCR): vẫn có
    /// chẩn đoán để mọi tờ trong kho đều truy được nguồn gốc bộ dòng.
    static func pdfTextLayer(lineCount: Int) -> OCRDiagnostics {
        var diagnostics = OCRDiagnostics()
        diagnostics.sourceImagePixels = "pdf"
        diagnostics.passes = [OCRPassRecord(passID: .pdfTextLayer, tileCount: 0,
                                            fragmentCount: lineCount, lineCount: lineCount,
                                            yieldScore: nil, blindBands: [])]
        diagnostics.notes = ["Đường lớp chữ PDF — không qua OCR, không đánh giá hình học."]
        return diagnostics
    }

    func jsonString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Lưu/đọc OCRDiagnostics bằng FILE PHỤ cạnh ảnh gốc trong cùng thư
/// mục bằng chứng (ImageStore.directory): `<tên file ảnh>.ocrdiag.json`.
/// Đường này KHÔNG đổi model SwiftData — vết đi theo file bằng chứng,
/// cùng vòng đời với ảnh (xoá ảnh ở các luồng hiện có không tự xoá
/// file phụ; file vài KB, dọn kèm là việc của gói tích hợp sau).
enum OCRDiagnosticsStore {
    static func fileName(forImageFileName imageFileName: String) -> String {
        imageFileName + ".ocrdiag.json"
    }

    @discardableResult
    static func save(_ diagnostics: OCRDiagnostics, imageFileName: String) -> Bool {
        guard !imageFileName.isEmpty,
              let data = diagnostics.jsonString()?.data(using: .utf8) else { return false }
        let url = ImageStore.directory.appendingPathComponent(fileName(forImageFileName: imageFileName))
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    static func load(imageFileName: String) -> OCRDiagnostics? {
        let url = ImageStore.directory.appendingPathComponent(fileName(forImageFileName: imageFileName))
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OCRDiagnostics.self, from: data)
    }
}

// MARK: - P2-1: Lớp 0 — hình học (ước lượng nghiêng, khử nghiêng, cổng tứ giác)

/// Lớp hình học của kiến trúc đã duyệt. Kỷ luật bất biến: lớp này CHỈ
/// SẢN XUẤT THÊM biến thể đã nắn — ảnh gốc không bao giờ bị thay, và
/// mọi phép nắn đều fail-open (lỗi ở đâu -> không có biến thể ở đó).
/// Mọi hàm đo/nắn ở đây đều là KHỞI ĐIỂM chưa kiểm chứng trên máy —
/// BenchApp là nơi kết án (xem HONESTY gói P2-1).
enum ReceiptGeometry {

    /// Kết quả ước lượng nghiêng của một ảnh.
    struct SkewAssessment {
        /// Góc dốc màn hình toàn cục (độ; + = dòng chữ chúc xuống về
        /// phía phải khi nhìn ảnh). nil = không đo được.
        var globalDegrees: Double? = nil
        /// Góc theo dải (thứ tự TỪ TRÊN XUỐNG; nil = dải thiếu mẫu).
        var bandDegreesTopToBottom: [Double?] = []
        /// Số dòng chữ dùng được để đo góc.
        var sampleLineCount: Int = 0
        /// Đủ mẫu + qua cổng sanity mới true.
        var reliable: Bool = false
        /// Câu quyết định dạng chữ — ghi thẳng vào chẩn đoán.
        var decision: String = ""
    }

    /// Ước lượng góc nghiêng bằng MỘT lượt Vision thăm dò trên ảnh hạ
    /// mẫu: góc của một dòng = góc đường nối tâm hộp-TỪ-ĐẦU-TIÊN tới
    /// tâm hộp-TỪ-CUỐI-CÙNG của dòng đó (VNRecognizedText.boundingBox
    /// (for:) cho hộp theo khoảng chữ — hộp observation nguyên dòng là
    /// hộp trục-thẳng nên tự nó KHÔNG mang góc). Góc toàn cục/dải =
    /// trung vị có trọng số (trọng số = bề ngang dòng theo pixel, dòng
    /// dài đáng tin hơn). Chọn thăm-dò-Vision thay vì chỉ dựa vào cạnh
    /// tứ giác vì: giấy lượn sóng không có một cạnh thẳng duy nhất để
    /// tin, còn góc dòng chữ là đúng đại lượng làm vỡ phân đoạn dòng.
    static func assessSkew(in cgImage: CGImage) -> SkewAssessment {
        var assessment = SkewAssessment()
        guard let probe = scaledDown(cgImage, maxDimension: PipelineConstants.skewProbeMaxDimension) else {
            assessment.decision = "Không tạo được ảnh thăm dò — bỏ qua đánh giá nghiêng."
            return assessment
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: probe, options: [:])
        do {
            try handler.perform([request])
        } catch {
            assessment.decision = "Lượt thăm dò Vision lỗi — bỏ qua đánh giá nghiêng."
            return assessment
        }
        let imageW = Double(probe.width)
        let imageH = Double(probe.height)
        struct Sample {
            var angle: Double
            var weight: Double
            /// Tâm dòng theo Y chuẩn hoá (gốc dưới-trái) để chia dải.
            var midY: Double
        }
        var samples: [Sample] = []
        /// Số dòng bị bỏ vì `boundingBox(for:)` ném lỗi — ghi vào
        /// quyết định chẩn đoán ở cuối hàm, không nuốt im lặng.
        var boxLookupFailures = 0
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            var wordRanges: [Range<String.Index>] = []
            candidate.string.enumerateSubstrings(in: candidate.string.startIndex..<candidate.string.endIndex,
                                                 options: .byWords) { _, range, _, _ in
                wordRanges.append(range)
            }
            guard wordRanges.count >= 2 else { continue }
            // P2-FIX (run #28, lỗi 13–14): từ SDK iOS 18, `boundingBox
            // (for:)` của VNRecognizedText là hàm THROWS (ném khi khoảng
            // chữ không hợp lệ). Lỗi ở 1 dòng chỉ được bỏ dòng đó
            // (fail-open như mọi tầng của đường ống) và ĐẾM vào chẩn
            // đoán ở cuối hàm — không để một dòng hỏng giết cả lượt
            // thăm dò, cũng không nuốt lỗi im lặng.
            let firstBoxOpt: VNRectangleObservation?
            let lastBoxOpt: VNRectangleObservation?
            do {
                firstBoxOpt = try candidate.boundingBox(for: wordRanges.first!)
                lastBoxOpt = try candidate.boundingBox(for: wordRanges.last!)
            } catch {
                boxLookupFailures += 1
                continue
            }
            guard let firstBox = firstBoxOpt, let lastBox = lastBoxOpt else { continue }
            // Tâm từ, đổi sang toạ độ pixel gốc TRÊN-TRÁI (y hướng
            // xuống) — góc tính trong hệ này là góc dốc MÀN HÌNH.
            // P2-FIX (run #28, lỗi 8–11): firstBox/lastBox là
            // VNRectangleObservation — .midX/.midY là thuộc tính của
            // CGRect, phải qua .boundingBox.
            let x1 = Double(firstBox.boundingBox.midX) * imageW
            let y1 = (1.0 - Double(firstBox.boundingBox.midY)) * imageH
            let x2 = Double(lastBox.boundingBox.midX) * imageW
            let y2 = (1.0 - Double(lastBox.boundingBox.midY)) * imageH
            let dx = x2 - x1
            guard dx >= 0.06 * imageW else { continue }
            let angle = atan2(y2 - y1, dx) * 180.0 / .pi
            samples.append(Sample(angle: angle, weight: dx,
                                  midY: Double(observation.boundingBox.midY)))
        }
        assessment.sampleLineCount = samples.count
        guard samples.count >= PipelineConstants.skewMinReliableLines else {
            assessment.decision = "Chỉ \(samples.count) dòng đo được góc (< \(PipelineConstants.skewMinReliableLines)) — không đủ tin để nắn."
                + (boxLookupFailures > 0 ? " (\(boxLookupFailures) dòng bị bỏ vì hộp từ ném lỗi.)" : "")
            return assessment
        }
        assessment.globalDegrees = weightedMedian(samples.map { (value: $0.angle, weight: $0.weight) })
        // Dải: chia theo tâm dòng (gốc dưới-trái, dải 0 = đáy tờ);
        // xuất ra theo thứ tự trên-xuống cho khớp trực giác đọc tờ.
        var bandsBottomToTop: [Double?] = []
        for band in 0..<PipelineConstants.skewBandCount {
            let low = Double(band) / Double(PipelineConstants.skewBandCount)
            let high = Double(band + 1) / Double(PipelineConstants.skewBandCount)
            let inBand = samples.filter { $0.midY >= low && $0.midY < high }
            bandsBottomToTop.append(inBand.count >= 2
                ? weightedMedian(inBand.map { (value: $0.angle, weight: $0.weight) })
                : nil)
        }
        assessment.bandDegreesTopToBottom = Array(bandsBottomToTop.reversed())
        assessment.reliable = assessment.globalDegrees != nil
        assessment.decision = assessment.reliable
            ? "Đo được góc nghiêng từ \(samples.count) dòng."
            : "Có \(samples.count) dòng nhưng trung vị góc không xác định — không nắn."
        if boxLookupFailures > 0 {
            assessment.decision += " (\(boxLookupFailures) dòng bị bỏ vì hộp từ ném lỗi.)"
        }
        return assessment
    }

    /// Sản xuất biến thể đã khử nghiêng từ một đánh giá. Trả nil khi:
    /// đánh giá không tin được; góc dưới ngưỡng phẳng; góc vượt ngưỡng
    /// sanity (nắn bừa còn hại hơn để nguyên); hoặc phép nắn lỗi.
    /// Quyết định toàn-cục-hay-theo-dải: mọi dải lệch khỏi góc toàn cục
    /// < bandDeviationForGlobalOnlyDegrees -> MỘT phép quay toàn cục;
    /// ngược lại -> nắn THEO DẢI (giấy lượn sóng: mỗi dải một góc).
    static func deskewedVariant(of cgImage: CGImage, assessment: SkewAssessment) -> CGImage? {
        guard assessment.reliable, let global = assessment.globalDegrees else { return nil }
        let bandAngles = assessment.bandDegreesTopToBottom.compactMap { $0 }
        let maxDeviation = bandAngles.map { abs($0 - global) }.max() ?? 0
        let needsCorrection = abs(global) >= PipelineConstants.skewMinAngleDegrees
            || maxDeviation >= PipelineConstants.skewMinAngleDegrees
        guard needsCorrection else { return nil }
        guard abs(global) <= PipelineConstants.skewMaxAngleDegrees,
              bandAngles.allSatisfy({ abs($0) <= PipelineConstants.skewMaxAngleDegrees }) else { return nil }
        if maxDeviation < PipelineConstants.bandDeviationForGlobalOnlyDegrees {
            return rotated(cgImage, screenSlopeDegrees: global)
        }
        return bandDeskewed(cgImage, bandAnglesTopToBottom: assessment.bandDegreesTopToBottom,
                            fallbackAngle: global)
            ?? rotated(cgImage, screenSlopeDegrees: global)
    }

    /// Quay ảnh để triệt góc dốc màn hình `screenSlopeDegrees`.
    /// PHÉP QUAY: nội dung nghiêng THUẬN kim đồng hồ một góc φ (đúng
    /// định nghĩa góc của assessSkew) thì phải quay NGƯỢC kim đồng hồ
    /// φ mới nằm ngang. CoreImage làm việc trong hệ gốc dưới-trái (y
    /// hướng lên), nơi CGAffineTransform(rotationAngle: a) quay ngược
    /// kim đồng hồ khi a > 0 — nên a = +φ (radian). Vùng góc thừa sau
    /// quay được lấp nền trắng (giấy hoá đơn là nền sáng).
    /// [DẤU QUAY CHƯA KIỂM CHỨNG NGOÀI MÁY — BenchApp bắt buộc kiểm
    /// bằng ảnh nghiêng nhân tạo góc biết trước: góc đo lại sau nắn
    /// phải về ~0°, TUYỆT ĐỐI không được gấp đôi góc. Xem HONESTY.]
    private static func rotated(_ cgImage: CGImage, screenSlopeDegrees: Double) -> CGImage? {
        let source = CIImage(cgImage: cgImage)
        let center = CGPoint(x: source.extent.midX, y: source.extent.midY)
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: CGFloat(screenSlopeDegrees * .pi / 180.0))
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        let rotatedImage = source.transformed(by: transform)
        let background = CIImage(color: CIColor(red: 1, green: 1, blue: 1))
            .cropped(to: rotatedImage.extent)
        let composed = rotatedImage.composited(over: background)
        let context = CIContext(options: nil)
        return context.createCGImage(composed, from: rotatedImage.extent)
    }

    /// Khử nghiêng THEO DẢI cho giấy lượn sóng: cắt ảnh thành các dải
    /// ngang CHỒNG LẤP, quay mỗi dải quanh tâm của nó theo góc dải,
    /// rồi ghép các dải đã quay lên một nền trắng cùng kích thước gốc,
    /// căn theo tâm dải. Đây là phép XẤP XỈ có chủ đích (một tờ giấy
    /// sóng liên tục không phẳng lại được bằng các phép quay rời rạc)
    /// — đường nối giữa các dải có thể lệch nhẹ; biến thể này là một
    /// LƯỢT ĐỌC THÊM cho P2-2 hợp nhất theo vùng, không bao giờ là ảnh
    /// hiển thị hay thay thế gốc. Lỗi ở bất kỳ bước nào -> nil.
    private static func bandDeskewed(_ cgImage: CGImage,
                                     bandAnglesTopToBottom: [Double?],
                                     fallbackAngle: Double) -> CGImage? {
        let imageW = cgImage.width
        let imageH = cgImage.height
        let bandCount = PipelineConstants.skewBandCount
        guard bandAnglesTopToBottom.count == bandCount, imageH >= bandCount else { return nil }
        let stripHeight = Double(imageH) / Double(bandCount)
        let overlap = stripHeight * PipelineConstants.bandOverlapFraction
        var canvas = CIImage(color: CIColor(red: 1, green: 1, blue: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: imageW, height: imageH))
        // Ghép từ dải ĐÁY lên để dải trên đè lên vùng chồng của dải
        // dưới (thứ tự thị giác: nội dung phía trên thắng ở vùng nối).
        for bandFromTop in stride(from: bandCount - 1, through: 0, by: -1) {
            let angle = bandAnglesTopToBottom[bandFromTop] ?? fallbackAngle
            let topY = Double(bandFromTop) * stripHeight
            let cropTop = max(0.0, topY - overlap / 2)
            let cropBottom = min(Double(imageH), topY + stripHeight + overlap / 2)
            let cropRect = CGRect(x: 0, y: cropTop, width: Double(imageW), height: cropBottom - cropTop)
            guard let strip = cgImage.cropping(to: cropRect),
                  let rotatedStrip = rotated(strip, screenSlopeDegrees: angle) else { return nil }
            let stripImage = CIImage(cgImage: rotatedStrip)
            // Căn tâm dải đã quay vào đúng tâm dải trên nền: tâm dải
            // theo toạ độ CI (gốc dưới-trái) = (W/2, H - (topY + stripHeight/2)).
            let targetCenter = CGPoint(x: Double(imageW) / 2,
                                       y: Double(imageH) - (topY + stripHeight / 2))
            let offset = CGPoint(x: targetCenter.x - stripImage.extent.midX,
                                 y: targetCenter.y - stripImage.extent.midY)
            let placed = stripImage.transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y))
            canvas = placed.composited(over: canvas)
        }
        let context = CIContext(options: nil)
        return context.createCGImage(canvas, from: CGRect(x: 0, y: 0, width: imageW, height: imageH))
    }

    /// Hạ mẫu một ảnh về cạnh dài tối đa (cho lượt thăm dò đo góc —
    /// góc không đổi theo tỉ lệ). Nền lấp trắng vì ảnh gốc có thể có
    /// kênh alpha sau các bước xử lý trước.
    private static func scaledDown(_ cgImage: CGImage, maxDimension: Int) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let longest = max(width, height)
        guard longest > maxDimension else { return cgImage }
        let scale = Double(maxDimension) / Double(longest)
        let newWidth = max(1, Int(Double(width) * scale))
        let newHeight = max(1, Int(Double(height) * scale))
        guard let context = CGContext(data: nil, width: newWidth, height: newHeight,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    private static func weightedMedian(_ values: [(value: Double, weight: Double)]) -> Double? {
        let sorted = values.filter { $0.weight > 0 }.sorted { $0.value < $1.value }
        let total = sorted.reduce(0.0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var accumulated = 0.0
        for entry in sorted {
            accumulated += entry.weight
            if accumulated >= total / 2 { return entry.value }
        }
        return sorted.last?.value
    }

    // MARK: Cổng hợp lệ cho tứ giác phái sinh (PIPELINE-AUDIT D-2.3)

    /// Tứ giác hoá đơn dạng Codable (góc chuẩn hoá gốc dưới-trái).
    struct ReceiptQuad: Codable {
        var topLeft: [Double]
        var topRight: [Double]
        var bottomLeft: [Double]
        var bottomRight: [Double]
    }

    struct QuadGateResult {
        var passed: Bool
        var areaFraction: Double
        var aspect: Double
        /// Lý do từng kiểm tra (đạt/trượt) — ghi vào chẩn đoán/báo cáo.
        var reasons: [String]
        /// Tứ giác ĐÃ NỚI LỀ (chỉ có khi passed) — đầu vào cho phép nắn
        /// của P2-2.
        var expandedQuad: ReceiptQuad?
    }

    /// Cổng hợp lệ D-2.3 cho tứ giác phát hiện được: (1) diện tích >=
    /// quadMinAreaFraction diện tích ảnh; (2) tỉ lệ cao/rộng trong
    /// [quadAspectMin, quadAspectMax] (hoá đơn luôn cao hẹp); (3) bốn
    /// góc lồi, đúng thứ tự vòng (tích chéo các cạnh liên tiếp cùng
    /// dấu). Đạt cả ba mới được nới lề quadMarginFraction mỗi cạnh
    /// (xấp xỉ: phóng các góc ra xa trọng tâm theo hệ số
    /// 1 + 2×margin — mỗi cạnh lùi ra ~margin lần khoảng cách
    /// trọng-tâm-tới-cạnh) và kẹp trong biên ảnh nới nhẹ.
    static func validateQuad(_ quad: VNRectangleObservation,
                             imageWidth: Int, imageHeight: Int) -> QuadGateResult {
        let w = Double(imageWidth)
        let h = Double(imageHeight)
        func pixel(_ point: CGPoint) -> (x: Double, y: Double) {
            (Double(point.x) * w, Double(point.y) * h)
        }
        let tl = pixel(quad.topLeft)
        let tr = pixel(quad.topRight)
        let br = pixel(quad.bottomRight)
        let bl = pixel(quad.bottomLeft)
        let corners = [tl, tr, br, bl]
        // Diện tích theo công thức shoelace trên vòng TL->TR->BR->BL.
        var twiceArea = 0.0
        for i in 0..<4 {
            let a = corners[i]
            let b = corners[(i + 1) % 4]
            twiceArea += a.x * b.y - b.x * a.y
        }
        let areaFraction = abs(twiceArea) / 2.0 / (w * h)
        func distance(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
            hypot(a.x - b.x, a.y - b.y)
        }
        let widthEdges = (distance(tl, tr) + distance(bl, br)) / 2
        let heightEdges = (distance(tl, bl) + distance(tr, br)) / 2
        let aspect = widthEdges > 0 ? heightEdges / widthEdges : 0
        // Độ lồi: tích chéo z của các cặp cạnh liên tiếp cùng dấu.
        var crosses: [Double] = []
        for i in 0..<4 {
            let a = corners[i]
            let b = corners[(i + 1) % 4]
            let c = corners[(i + 2) % 4]
            let ab = (x: b.x - a.x, y: b.y - a.y)
            let bc = (x: c.x - b.x, y: c.y - b.y)
            crosses.append(ab.x * bc.y - ab.y * bc.x)
        }
        let convex = crosses.allSatisfy { $0 > 0 } || crosses.allSatisfy { $0 < 0 }
        var reasons: [String] = []
        let areaOK = areaFraction >= PipelineConstants.quadMinAreaFraction
        reasons.append("Diện tích \(String(format: "%.1f%%", areaFraction * 100)) \(areaOK ? ">=" : "<") ngưỡng \(Int(PipelineConstants.quadMinAreaFraction * 100))%.")
        let aspectOK = aspect >= PipelineConstants.quadAspectMin && aspect <= PipelineConstants.quadAspectMax
        reasons.append("Tỉ lệ cao/rộng \(String(format: "%.2f", aspect)) \(aspectOK ? "trong" : "NGOÀI") [\(PipelineConstants.quadAspectMin), \(PipelineConstants.quadAspectMax)].")
        reasons.append(convex ? "Bốn góc lồi, thứ tự vòng nhất quán." : "Tứ giác KHÔNG lồi hoặc góc sai thứ tự.")
        let passed = areaOK && aspectOK && convex
        var expanded: ReceiptQuad? = nil
        if passed {
            let centroid = (x: (quad.topLeft.x + quad.topRight.x + quad.bottomLeft.x + quad.bottomRight.x) / 4,
                            y: (quad.topLeft.y + quad.topRight.y + quad.bottomLeft.y + quad.bottomRight.y) / 4)
            let factor = 1.0 + 2.0 * PipelineConstants.quadMarginFraction
            func expand(_ point: CGPoint) -> [Double] {
                let x = centroid.x + (Double(point.x) - centroid.x) * factor
                let y = centroid.y + (Double(point.y) - centroid.y) * factor
                return [min(1.05, max(-0.05, x)), min(1.05, max(-0.05, y))]
            }
            expanded = ReceiptQuad(topLeft: expand(quad.topLeft), topRight: expand(quad.topRight),
                                   bottomLeft: expand(quad.bottomLeft), bottomRight: expand(quad.bottomRight))
        }
        return QuadGateResult(passed: passed, areaFraction: areaFraction, aspect: aspect,
                              reasons: reasons, expandedQuad: expanded)
    }

    /// Verdict của cổng ở CHẾ ĐỘ BÓNG cho một ảnh (hạ tầng P2-1):
    /// chạy phát hiện tứ giác (cùng ngưỡng 0.5) rồi tính cổng mà
    /// KHÔNG sinh biến thể. Từ P2-2 đường sản xuất KHÔNG gọi hàm
    /// này nữa — ScanView.derivedVariant tự chạy phát hiện + cổng
    /// và dùng ReceiptQuad đã nới lề cho phép nắn thật; hàm này giữ
    /// lại cho BenchApp đối chiếu verdict bóng/thật trên cùng ảnh.
    static func shadowGateVerdict(in cgImage: CGImage) -> OCRDerivedGateRecord {
        let detect = VNDetectRectanglesRequest()
        detect.minimumConfidence = PipelineConstants.quadDetectMinConfidence
        detect.maximumObservations = 1
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([detect])
        } catch {
            return OCRDerivedGateRecord(quadDetected: false, gatePassed: nil, areaFraction: nil,
                                        aspect: nil, reasons: ["VNDetectRectanglesRequest lỗi: \(error.localizedDescription)"])
        }
        guard let quad = (detect.results ?? []).first else {
            return OCRDerivedGateRecord(quadDetected: false, gatePassed: nil, areaFraction: nil,
                                        aspect: nil, reasons: ["Không phát hiện được tứ giác nào."])
        }
        let gate = validateQuad(quad, imageWidth: cgImage.width, imageHeight: cgImage.height)
        return OCRDerivedGateRecord(quadDetected: true, gatePassed: gate.passed,
                                    areaFraction: gate.areaFraction, aspect: gate.aspect,
                                    reasons: gate.reasons)
    }
}

// MARK: - P2-1: Khung đọc-lại-có-mục-tiêu (RECONCILE-DESIGN §6 — thân thuộc P2-2)

/// Gợi ý vùng đọc lại từ tầng đối chiếu (P2-3) sang tầng đọc: dải nào,
/// vì sao, ưu tiên bao nhiêu. `band` dùng toạ độ chuẩn hoá gốc
/// DƯỚI-TRÁI trong không gian ảnh gốc đầy đủ — cùng hệ với hộp của
/// OCRFragment2/OCRLine2 và với regionOfInterest của Vision.
struct RegionHint {
    enum Reason: String {
        case missingOrUnrepairable
        case qtyMismatch
        case anchorConflict
        case totalOnlyAnchor
    }

    var band: CGRect
    var reason: Reason
    var priority: Int
}

/// GIAO DIỆN ĐỌC LẠI — P2-2 ĐÃ GỠ ĐỊNH NGHĨA PROTOCOL Ở ĐÂY:
/// P2-1 từng định nghĩa `protocol ReOCRService` tại vị trí này
/// (RegionHint, bất đồng bộ, trả [OCRLine2]), nhưng P2-3 cũng định
/// nghĩa một protocol CÙNG TÊN (ReconcileRegionHint, đồng bộ, trả
/// [OCRLine]) — hai định nghĩa không thể cùng tồn tại trong một
/// module khi tích hợp. Từ P2-2: tên ReOCRService chỉ còn MỘT định
/// nghĩa duy nhất (của P2-3, trong Parser.swift); thân đọc lại thật
/// là ScanView.TargetedReOCRService — tuân thủ protocol của P2-3 và
/// phơi thêm bản giàu hình học reReadOutcome cho đường ống. Phần
/// hình học thuần của giao diện vẫn ở RegionGeometry ngay dưới đây.

/// Phần hình học của giao diện đọc lại — thuần hàm, kiểm được bằng
/// số học mà không cần máy.
enum RegionGeometry {
    /// Nới dải theo chiều Y: thêm (expansion − 1)/2 chiều cao dải vào
    /// mỗi phía rồi kẹp trong [0, 1] — đúng luật RECONCILE-DESIGN §6
    /// (nới ×1.5 mỗi phía theo hệ số regionBandExpansion).
    static func expandedBand(_ band: CGRect) -> CGRect {
        let extra = band.height * (PipelineConstants.regionBandExpansion - 1) / 2
        let y0 = max(0, band.minY - extra)
        let y1 = min(1, band.maxY + extra)
        return CGRect(x: band.minX, y: y0, width: band.width, height: max(0, y1 - y0))
    }

    /// Dải-y của một khối dòng (khối món / khối tổng): hộp hợp nhất
    /// của các dòng thuộc khối, đã nới + kẹp theo luật trên.
    static func band(forLines lines: [OCRLine2]) -> CGRect? {
        guard let first = lines.first else { return nil }
        var union = first.box
        for line in lines.dropFirst() {
            union = union.union(line.box)
        }
        return expandedBand(union)
    }

    /// Rect cắt theo PIXEL, gốc TRÊN-TRÁI, cho CGImage.cropping(to:)
    /// từ một dải chuẩn hoá gốc dưới-trái.
    /// [PHÉP LẬT PHẢI KIỂM TRÊN MÁY — RECONCILE-DESIGN §6 điểm đo 1:
    /// regionOfInterest của Vision dùng gốc dưới-trái, cropping dùng
    /// gốc trên-trái; nhầm một lần là đọc lại vùng ở đầu kia của tờ.]
    static func pixelCropRect(band: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect {
        let x = band.minX * CGFloat(imageWidth)
        let width = band.width * CGFloat(imageWidth)
        let height = band.height * CGFloat(imageHeight)
        let yTop = (1.0 - band.maxY) * CGFloat(imageHeight)
        return CGRect(x: x, y: yTop, width: width, height: height)
    }

    /// regionOfInterest cho VNRecognizeTextRequest: dùng THẲNG dải
    /// chuẩn hoá gốc dưới-trái (đúng hệ toạ độ của Vision).
    static func visionRegionOfInterest(band: CGRect) -> CGRect {
        band
    }
}

// MARK: - P2-2: Hợp nhất v2 (thay dedupeOverlap + mergeRows ở đường mới)
//
// PIPELINE-AUDIT §4.4/§4.5/§4.6 thể chế hoá:
//  1. KHỬ TRÙNG MỜ: cụm hoá (hợp phần liên thông) trên các mảnh
//     CHỒNG HỘP theo hình học; trong cụm, hai text là "cùng một lần
//     đọc lại" khi khoảng cách sửa trên bản chuẩn hoá <= max(1, 15%
//     độ dài) hoặc bản ngắn là chuỗi con của bản dài (mảnh cụt vùng
//     chồng lát bị bản trọn nuốt). Hai mảnh chồng hộp gần như trùng
//     khít mà text khác hẳn ngưỡng mờ vẫn gom một cụm tranh chấp —
//     biến thể bị thua được giữ trong alternates, và nếu token tiền
//     khác nhau giữa các pass thì dòng mang contested = true cho
//     tầng đối chiếu phán.
//  2. RÁP HÀNG: hiệu chỉnh nghiêng toàn cục bằng hồi quy trên tâm
//     mảnh, gom hàng bằng cụm khoảng Y (giao >= 40% chiều cao mảnh
//     ngắn hơn), CHỐT CHẶN nuốt hàng: cụm cao hơn 1.6× chiều cao
//     dòng trung vị thì tách tại khe Y lớn nhất. Trong hàng sắp
//     trái->phải; confidence dòng = trung bình trọng số độ dài,
//     riêng token tiền lấy MIN của các mảnh chứa nó (giữ tinh thần
//     F2a đúng chỗ quyết định tiền).
// Mọi ngưỡng nằm ở PipelineConstants và đều là KHỞI ĐIỂM chưa đo.

enum OCRFragmentMerger {

    /// Kết quả hợp nhất: dòng cấp 2 + mảnh đại diện (đã đánh số lại
    /// theo thứ tự đọc; spans của dòng trỏ đúng vào các ID này).
    struct Assembly {
        var lines: [OCRLine2]
        var representatives: [OCRFragment2]
    }

    /// Một cụm khử trùng mờ: mảnh đại diện + mọi thành viên đã nuốt.
    private struct Cluster {
        var representative: OCRFragment2
        var members: [OCRFragment2]
        var passSources: Set<OCRPassID>
        /// Mọi text bị thua trong cụm (của thành viên + ứng viên phụ
        /// của chúng), đã khử trùng theo bản chuẩn hoá.
        var variants: [(text: String, confidence: Double)]
        /// Các pass trong cụm bất đồng trên token tiền.
        var contestedMoney: Bool
    }

    /// Mảnh đã hiệu chỉnh khoảng Y theo nghiêng toàn cục để gom hàng.
    private struct AdjustedCluster {
        var cluster: Cluster
        var minY: Double
        var maxY: Double
        var centerY: Double
    }

    /// Hợp phần liên thông tối thiểu cho cụm hoá.
    private struct DisjointSet {
        private var parent: [Int]
        init(count: Int) { parent = Array(0..<count) }
        mutating func find(_ x: Int) -> Int {
            if parent[x] != x { parent[x] = find(parent[x]) }
            return parent[x]
        }
        mutating func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }
        mutating func groups() -> [[Int]] {
            var dict: [Int: [Int]] = [:]
            for i in parent.indices { dict[find(i), default: []].append(i) }
            return dict.sorted { ($0.value.min() ?? 0) < ($1.value.min() ?? 0) }
                .map { $0.value }
        }
    }

    /// Kẹp một hộp về [0, 1] (hộp sau ánh xạ ngược có thể nhô nhẹ
    /// khỏi biên); hộp suy biến/rỗng -> .zero.
    static func clampedBox(_ rect: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0, !rect.isNull, !rect.isInfinite else { return .zero }
        let x0 = min(max(Double(rect.minX), 0), 1)
        let y0 = min(max(Double(rect.minY), 0), 1)
        let x1 = min(max(Double(rect.maxX), 0), 1)
        let y1 = min(max(Double(rect.maxY), 0), 1)
        guard x1 > x0, y1 > y0 else {
            return CGRect(x: x0, y: y0, width: 0.0005, height: 0.0005)
        }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Cấp lại fragmentID duy nhất theo thứ tự vào — bắt buộc trước
    /// khi hợp nhất mảnh của NHIỀU pass (ID gốc chỉ duy nhất trong
    /// từng pass).
    static func uniquelyIdentified(_ fragments: [OCRFragment2]) -> [OCRFragment2] {
        fragments.enumerated().map { index, fragment in
            var copy = fragment
            copy.fragmentID = index
            return copy
        }
    }

    /// Điểm vào hợp nhất: khử trùng mờ -> ráp hàng -> đánh số lại
    /// mảnh đại diện theo thứ tự đọc và ánh xạ lại spans.
    static func assemble(_ fragmentsIn: [OCRFragment2]) -> Assembly {
        let fragments = fragmentsIn.filter {
            !$0.text.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty
        }
        guard !fragments.isEmpty else { return Assembly(lines: [], representatives: []) }
        let clusters = clusterDuplicates(fragments)
        let lines = assembleRows(clusters)
        let representatives = clusters.map { $0.representative }
        let order = representatives.indices.sorted { a, b in
            let fa = representatives[a], fb = representatives[b]
            if fa.box.maxY != fb.box.maxY { return fa.box.maxY > fb.box.maxY }
            return fa.box.minX < fb.box.minX
        }
        var idMap: [Int: Int] = [:]
        for (newID, oldIndex) in order.enumerated() {
            idMap[representatives[oldIndex].fragmentID] = newID
        }
        var renumbered: [OCRFragment2] = []
        for oldIndex in order {
            var fragment = representatives[oldIndex]
            fragment.fragmentID = idMap[fragment.fragmentID] ?? fragment.fragmentID
            renumbered.append(fragment)
        }
        let remappedLines = lines.map { line -> OCRLine2 in
            var copy = line
            copy.spans = line.spans.map {
                (fragmentID: idMap[$0.fragmentID] ?? $0.fragmentID,
                 rangeInLine: $0.rangeInLine)
            }
            return copy
        }
        return Assembly(lines: remappedLines, representatives: renumbered)
    }

    // MARK: Khử trùng mờ

    private static func clusterDuplicates(_ fragments: [OCRFragment2]) -> [Cluster] {
        var set = DisjointSet(count: fragments.count)
        for i in fragments.indices {
            for j in (i + 1)..<fragments.count
            where isSamePhysicalFragment(fragments[i], fragments[j]) {
                set.union(i, j)
            }
        }
        return set.groups().map { memberIndices in
            makeCluster(members: memberIndices.map { fragments[$0] })
        }
    }

    /// Hai mảnh có phải cùng một vùng vật lý bị đọc lại không: hình
    /// học phải gần (IoU / chứa / chồng-Y + tâm-X gần) VÀ text phải
    /// mờ-giống; riêng trường hợp hộp gần như trùng khít mà text
    /// khác hẳn vẫn gom — đó là một mảnh bị đọc tranh chấp, không
    /// phải hai mảnh thật.
    private static func isSamePhysicalFragment(_ a: OCRFragment2, _ b: OCRFragment2) -> Bool {
        let inter = a.box.intersection(b.box)
        let interArea = inter.isNull ? 0 : Double(inter.width * inter.height)
        let areaA = Double(a.box.width * a.box.height)
        let areaB = Double(b.box.width * b.box.height)
        let smallerArea = min(areaA, areaB)
        let unionArea = areaA + areaB - interArea
        let iou = unionArea > 0 ? interArea / unionArea : 0
        let containment = smallerArea > 0 ? interArea / smallerArea : 0
        let shorterHeight = Double(min(a.box.height, b.box.height))
        let yOverlap = Double(min(a.box.maxY, b.box.maxY) - max(a.box.minY, b.box.minY))
        let yOverlapFraction = shorterHeight > 0 ? max(0, yOverlap) / shorterHeight : 0
        let centerXDistance = Double(abs(a.box.midX - b.box.midX))
        let geometricClose = iou >= PipelineConstants.dedupeIoUThreshold
            || containment >= PipelineConstants.dedupeContainmentThreshold
            || (yOverlapFraction >= PipelineConstants.dedupeYOverlapFraction
                && centerXDistance <= PipelineConstants.dedupeCenterXDistanceHeights * shorterHeight)
        guard geometricClose else { return false }
        if isFuzzySameText(a.text, b.text) { return true }
        let centerYDistance = Double(abs(a.box.midY - b.box.midY))
        return containment >= 0.85
            && centerXDistance <= 0.25 * shorterHeight
            && centerYDistance <= 0.25 * shorterHeight
    }

    /// "Cùng một lần đọc lại" ở cấp text: bằng nhau sau chuẩn hoá,
    /// bản ngắn là chuỗi con của bản dài (mảnh cụt), hoặc khoảng
    /// cách sửa trong ngưỡng theo độ dài.
    private static func isFuzzySameText(_ a: String, _ b: String) -> Bool {
        let na = normalizedForCompare(a)
        let nb = normalizedForCompare(b)
        if na == nb { return true }
        let shorter = na.count <= nb.count ? na : nb
        let longer = na.count <= nb.count ? nb : na
        if shorter.count >= 3 && longer.contains(shorter) { return true }
        let limit = max(1, Int((PipelineConstants.fuzzyEditDistanceFraction
                                * Double(max(na.count, nb.count))).rounded(.down)))
        return levenshtein(na, nb, limit: limit) <= limit
    }

    /// Bản chuẩn hoá CHỈ để so sánh (không bao giờ sửa text gốc):
    /// hoa hoá, gộp khoảng trắng, ánh xạ ký tự dễ nhầm về một phía
    /// (0/O, 1/I/l, 5/S, 8/B, dấu thập phân ,/.).
    private static func normalizedForCompare(_ text: String) -> String {
        var s = text.uppercased()
        s = s.replacingOccurrences(of: "O", with: "0")
        s = s.replacingOccurrences(of: "I", with: "1")
        s = s.replacingOccurrences(of: "L", with: "1")
        s = s.replacingOccurrences(of: "S", with: "5")
        s = s.replacingOccurrences(of: "B", with: "8")
        s = s.replacingOccurrences(of: ",", with: ".")
        return s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Khoảng cách sửa Levenshtein có cắt sớm khi vượt `limit`.
    private static func levenshtein(_ a: String, _ b: String, limit: Int) -> Int {
        let ac = Array(a), bc = Array(b)
        if abs(ac.count - bc.count) > limit { return limit + 1 }
        if ac.isEmpty { return bc.count }
        if bc.isEmpty { return ac.count }
        var prev = Array(0...bc.count)
        var curr = [Int](repeating: 0, count: bc.count + 1)
        for i in 1...ac.count {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...bc.count {
                let cost = ac[i - 1] == bc[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
                rowMin = min(rowMin, curr[j])
            }
            if rowMin > limit { return limit + 1 }
            swap(&prev, &curr)
        }
        return prev[bc.count]
    }

    /// Dựng một cụm: chọn đại diện + gom biến thể + phán contested.
    /// Đại diện: nếu trong cụm có quan hệ chứa-trọn-text (bản trọn
    /// vùng chồng lát) thì bản DÀI NHẤT thắng; ngoài ra confidence
    /// cao nhất thắng (hoà: dài hơn, rồi ID nhỏ hơn).
    private static func makeCluster(members: [OCRFragment2]) -> Cluster {
        let normalized = members.map { normalizedForCompare($0.text) }
        let hasContainment = members.indices.contains { i in
            members.indices.contains { j in
                i != j && normalized[i].contains(normalized[j])
                    && members[i].text.count > members[j].text.count
            }
        }
        let representative = members.sorted { a, b in
            if hasContainment && a.text.count != b.text.count { return a.text.count > b.text.count }
            if a.confidence != b.confidence { return a.confidence > b.confidence }
            if a.text.count != b.text.count { return a.text.count > b.text.count }
            return a.fragmentID < b.fragmentID
        }.first!
        let representativeNormalized = normalizedForCompare(representative.text)
        var variantByNormalized: [String: (text: String, confidence: Double)] = [:]
        for member in members {
            if normalizedForCompare(member.text) != representativeNormalized {
                variantByNormalized[normalizedForCompare(member.text)] = (member.text, member.confidence)
            }
            for alternate in member.alternates
            where normalizedForCompare(alternate.text) != representativeNormalized
                    && variantByNormalized[normalizedForCompare(alternate.text)] == nil {
                variantByNormalized[normalizedForCompare(alternate.text)] = alternate
            }
        }
        let variants = variantByNormalized.values.sorted { $0.confidence > $1.confidence }
        var rep = representative
        rep.alternates = variants
        let moneySets = Set(members.map { moneyTokenSet($0.text) })
        let contested = members.count > 1
            && Set(members.map { $0.passID }).count > 1
            && moneySets.count > 1
        return Cluster(representative: rep, members: members,
                       passSources: Set(members.map { $0.passID }),
                       variants: variants, contestedMoney: contested)
    }

    // MARK: Ráp hàng

    private static func assembleRows(_ clusters: [Cluster]) -> [OCRLine2] {
        guard !clusters.isEmpty else { return [] }
        let medianHeight = median(clusters.map { Double($0.representative.box.height) })
        let slope = fittedSlope(clusters)
        let adjusted = clusters.map { cluster -> AdjustedCluster in
            let box = cluster.representative.box
            let center = Double(box.midY) - slope * (Double(box.midX) - 0.5)
            let half = Double(box.height) / 2
            return AdjustedCluster(cluster: cluster,
                                   minY: center - half, maxY: center + half,
                                   centerY: center)
        }
        var set = DisjointSet(count: adjusted.count)
        for i in adjusted.indices {
            for j in (i + 1)..<adjusted.count {
                let overlap = min(adjusted[i].maxY, adjusted[j].maxY)
                    - max(adjusted[i].minY, adjusted[j].minY)
                let shorter = min(Double(adjusted[i].cluster.representative.box.height),
                                  Double(adjusted[j].cluster.representative.box.height))
                if shorter > 0 && overlap / shorter >= PipelineConstants.rowYOverlapFraction {
                    set.union(i, j)
                }
            }
        }
        var rows: [[AdjustedCluster]] = []
        for group in set.groups() {
            rows += splitComponent(group.map { adjusted[$0] }, medianHeight: medianHeight)
        }

        var built: [(line: OCRLine2, sortKey: Double)] = []
        for row in rows {
            let sorted = row.sorted {
                $0.cluster.representative.box.minX < $1.cluster.representative.box.minX
            }
            // Gấp các cụm gần như trùng khít còn sót (tranh chấp hình
            // học) vào đoạn trước làm biến thể thay vì in hai lần.
            var segments: [Cluster] = []
            var foldedVariants: [(text: String, confidence: Double)] = []
            var foldedContested = false
            for entry in sorted {
                if let last = segments.last {
                    let a = last.representative.box
                    let b = entry.cluster.representative.box
                    let inter = a.intersection(b)
                    let interArea = inter.isNull ? 0 : Double(inter.width * inter.height)
                    let smaller = min(Double(a.width * a.height), Double(b.width * b.height))
                    let containment = smaller > 0 ? interArea / smaller : 0
                    let centerDistance = Double(abs(a.midX - b.midX))
                    if containment >= 0.85
                        && centerDistance <= 0.25 * Double(min(a.height, b.height)) {
                        foldedVariants.append((text: entry.cluster.representative.text,
                                               confidence: entry.cluster.representative.confidence))
                        foldedVariants += entry.cluster.variants
                        if moneyTokenSet(entry.cluster.representative.text) != moneyTokenSet(last.representative.text) {
                            foldedContested = true
                        }
                        continue
                    }
                }
                segments.append(entry.cluster)
            }
            guard !segments.isEmpty else { continue }

            var text = ""
            var spans: [(fragmentID: Int, rangeInLine: Range<String.Index>)] = []
            var box: CGRect? = nil
            var passSources: Set<OCRPassID> = []
            var variants = foldedVariants
            var contested = foldedContested
            var weightedConfidence = 0.0
            var totalWeight = 0
            var moneyConfidences: [Double] = []
            for (index, cluster) in segments.enumerated() {
                let rep = cluster.representative
                if index > 0 { text += " " }
                let start = text.endIndex
                text += rep.text
                spans.append((fragmentID: rep.fragmentID, rangeInLine: start..<text.endIndex))
                box = box?.union(rep.box) ?? rep.box
                passSources.formUnion(cluster.passSources)
                variants += cluster.variants
                contested = contested || cluster.contestedMoney
                let weight = max(1, rep.text.count)
                weightedConfidence += rep.confidence * Double(weight)
                totalWeight += weight
                if containsMoneyToken(rep.text) { moneyConfidences.append(rep.confidence) }
            }
            var confidence = totalWeight > 0 ? weightedConfidence / Double(totalWeight) : 0
            if let weakestMoney = moneyConfidences.min() {
                confidence = min(confidence, weakestMoney)
            }
            let finalNormalized = normalizedForCompare(text)
            var seen = Set<String>()
            let lineVariants = variants.filter { variant in
                let key = normalizedForCompare(variant.text)
                guard key != finalNormalized, !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }.sorted { $0.confidence > $1.confidence }
            let line = OCRLine2(text: text, confidence: confidence,
                                box: box ?? .zero, spans: spans,
                                passSources: passSources, contested: contested,
                                alternates: lineVariants)
            built.append((line: line, sortKey: row.map { $0.maxY }.max() ?? 0))
        }
        return built.sorted { $0.sortKey > $1.sortKey }.map { $0.line }
    }

    /// Chốt chặn nuốt hàng: cụm có chiều cao tổng vượt 1.6× chiều
    /// cao dòng trung vị thì tách tại khe Y lớn nhất, đệ quy.
    private static func splitComponent(_ component: [AdjustedCluster],
                                       medianHeight: Double) -> [[AdjustedCluster]] {
        guard component.count > 1 else { return [component] }
        let span = (component.map { $0.maxY }.max() ?? 0)
            - (component.map { $0.minY }.min() ?? 0)
        guard span > PipelineConstants.rowSplitHeightMultiple * medianHeight else {
            return [component]
        }
        let sorted = component.sorted { $0.centerY > $1.centerY }
        var bestGap = -Double.infinity
        var bestIndex = 0
        for i in 0..<(sorted.count - 1) {
            let gap = sorted[i].minY - sorted[i + 1].maxY
            if gap > bestGap {
                bestGap = gap
                bestIndex = i
            }
        }
        let upper = Array(sorted[0...bestIndex])
        let lower = Array(sorted[(bestIndex + 1)...])
        return splitComponent(upper, medianHeight: medianHeight)
            + splitComponent(lower, medianHeight: medianHeight)
    }

    /// Độ dốc toàn cục của các dòng chữ (hồi quy có trọng số trên
    /// tâm mảnh tin cậy >= 0.5, bề ngang >= 0.08): Y' = midY −
    /// slope × (midX − 0.5). Dốc bị kẹp trong ±12° như Lớp 0; mẫu
    /// không đủ tin -> 0 (không hiệu chỉnh).
    private static func fittedSlope(_ clusters: [Cluster]) -> Double {
        let samples = clusters.filter {
            $0.representative.confidence >= 0.5 && $0.representative.box.width >= 0.08
        }
        guard samples.count >= 3 else { return 0 }
        var totalWeight = 0.0, sumX = 0.0, sumY = 0.0
        for cluster in samples {
            let weight = Double(cluster.representative.box.width) * cluster.representative.confidence
            totalWeight += weight
            sumX += weight * Double(cluster.representative.box.midX)
            sumY += weight * Double(cluster.representative.box.midY)
        }
        guard totalWeight > 0 else { return 0 }
        let meanX = sumX / totalWeight
        let meanY = sumY / totalWeight
        var numerator = 0.0, denominator = 0.0
        for cluster in samples {
            let weight = Double(cluster.representative.box.width) * cluster.representative.confidence
            let dx = Double(cluster.representative.box.midX) - meanX
            numerator += weight * dx * (Double(cluster.representative.box.midY) - meanY)
            denominator += weight * dx * dx
        }
        guard denominator > 1e-9 else { return 0 }
        let maxSlope = tan(PipelineConstants.skewMaxAngleDegrees * Double.pi / 180)
        return min(max(numerator / denominator, -maxSlope), maxSlope)
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[mid] }
        return (sorted[mid - 1] + sorted[mid]) / 2
    }

    // MARK: Token tiền (cho contested + luật confidence)

    private static let moneyRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"\$?\d[\d,]*\.\d{2}"#)

    /// Các token tiền dạng 1,234.56 trong một text, đã bỏ $ và dấu
    /// phẩy để so sánh giữa các biến thể đọc.
    static func moneyTokens(in text: String) -> [String] {
        guard let regex = moneyRegex else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return text[r]
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
        }
    }

    private static func moneyTokenSet(_ text: String) -> Set<String> {
        Set(moneyTokens(in: text))
    }

    static func containsMoneyToken(_ text: String) -> Bool {
        !moneyTokens(in: text).isEmpty
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

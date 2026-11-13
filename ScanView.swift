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
    /// V3 (Pha 4): provenance từng trường của lần đọc (đọc thẳng /
    /// suy luận F5 / đọc-lại-ROI / sửa chữ theo từ điển) — ReviewView
    /// hiển thị ở mức dữ liệu cạnh trường tương ứng (M12, §7 Pha 4).
    var provenance: [String: FieldProvenance] = [:]
    /// V3 (Pha 4): báo cáo trọng tài của lần đọc — ReviewView dùng
    /// requiresReview cho công thức trạng thái và suggestions để
    /// trình gợi ý đối chiếu (chỉ trình, không tự áp).
    var reconcileReport: ReconcileReport? = nil
    /// V3 (Pha 4): mã hồ sơ chẩn đoán v2 của lần đọc (nil khi ghi
    /// chẩn đoán thất bại hoặc không có thư mục ghi).
    var diagnosticsID: String? = nil
    /// V3 (Pha 4): ghi chẩn đoán THẤT BẠI -> tờ bị ép vào Kiểm Lại
    /// khi lưu (hợp đồng fail-closed §1.5: không có lần đọc nào
    /// "sạch" mà không có bản ghi kiểm chứng được).
    var diagnosticsWriteFailed: Bool = false
}

/// Màn Chụp: camera quét tài liệu của Apple (VisionKit) -> lưu ảnh gốc vào
/// thư mục của app -> đọc bằng ĐƯỜNG ĐỌC V3 (ReceiptReader trong
/// ReadPipeline.swift: F1->F2->F3->F4->F5+ROI, chẩn đoán v2 bắt buộc) ->
/// màn Review. Không có bước nào gửi ảnh ra ngoài iPhone.
/// WP3 thêm đường nạp file từ Files: PDF có lớp chữ -> trích thẳng vào cùng
/// đường đọc (không qua OCR); PDF không lớp chữ -> render trang -> đọc;
/// file ảnh -> đọc như đường chọn ảnh.
/// V3 (Pha 4): file này chỉ còn là VỎ UI + hàng chờ nạp — toàn bộ cơ chế
/// đọc cũ (recognizeLines/yieldScore/cắt lát/ứng viên phái sinh kiểu
/// OCRFIX) đã GỠ sang module dùng chung; không còn bộ đọc thứ hai nào
/// trong app (luật 1.6).
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
    /// GÓI V4-4 (D-V4-2, sửa A2-05): cổng chất lượng theo TỪNG TỜ —
    /// mỗi lần đọc tạo một QualityGate MỚI (xem các điểm gọi
    /// runRead), không còn instance sống cho cả phiên. Tờ bị cổng
    /// chặn (.block) được giữ ở hai trạng thái riêng dưới đây và
    /// hiện khung quyết định riêng trong body: không mở Review
    /// thầm, không chụp snapshot P-DRAFT, không biến mất.
    @State private var blockedDraft: ScanDraft? = nil
    @State private var blockedQuality: QualityOutcome? = nil

    private var cameraSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                // UI-2026-11-13: biểu tượng thương hiệu + tiêu đề
                // lớn ở tab Chụp (điểm vào chính của app).
                ZStack {
                    Circle()
                        .fill(DS.heroGradient)
                        .frame(width: 104, height: 104)
                        .shadow(color: Color(red: 0.016, green: 0.235, blue: 0.157).opacity(0.45), radius: 14, x: 0, y: 7)
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 46))
                        .foregroundStyle(.white)
                }
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
                    }
                    .buttonStyle(PrimaryButtonStyle())
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
                    .tint(DS.brand)
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
                    .tint(DS.brand)
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
                // GÓI V4-4 (D-V4-2): trạng thái giao diện RIÊNG của
                // tờ bị cổng chất lượng chặn. Tờ nằm yên ở đây cho
                // tới khi anh chọn một trong hai hành động — hàng
                // chờ nạp cũng đứng chờ (processNextImportedFile
                // canh blockedDraft), không tờ nào chen qua mặt.
                if blockedDraft != nil, let blockedQuality {
                    VStack(spacing: 12) {
                        Label("Tờ này bị cổng chất lượng chặn",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text("Ảnh \(qualityIssueText(blockedQuality)) — app chưa mở tờ này để kiểm hay lưu. Ảnh gốc của tờ vẫn đã lưu trong máy. Anh chụp / chọn lại rõ hơn, hoặc vẫn đọc tờ này nếu không chụp lại được.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Button {
                                blockedDraft = nil
                                blockedQuality = nil
                                statusText = nil
                                errorText = nil
                                processNextImportedFile()
                            } label: {
                                Label("Chụp / chọn lại", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button {
                                guard let d = blockedDraft,
                                      let q = blockedQuality else { return }
                                blockedDraft = nil
                                blockedQuality = nil
                                presentDraft(d, note: blockedNote(q))
                            } label: {
                                Label("Vẫn đọc tờ này", systemImage: "doc.text.magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(DS.brand)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                Spacer()
                Text("Đọc ngay trên máy — ảnh hoá đơn không rời khỏi iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .dsScreenBackground()
            .navigationTitle("Chụp Hoá Đơn")
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView(
                    onScan: { scan in
                        showCamera = false
                        guard scan.pageCount > 0 else {
                            errorText = "Chưa chụp được trang nào — anh thử lại giúp."
                            return
                        }
                        // V3 (Pha 4): đọc MỌI trang của lượt quét
                        // (hoá đơn dài nhiều trang — nối chữ ở tầng
                        // ráp dòng của pipeline), thay giới hạn
                        // trang đầu của Build 1.
                        process(scan: scan)
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
                // P-DRAFT (L-2026-11-13-14): onDone của ReviewView
                // CHỈ cháy ở đúng hai điểm — lưu thành công (cuối
                // save()) và nút "Huỷ, không lưu" tường minh — nên
                // xoá bản chụp nháp tại đây là khớp cả hai trường
                // hợp kết thúc. Vuốt đóng sheet KHÔNG qua onDone:
                // bản chụp còn nguyên trên đĩa để lần mở app/tab
                // sau khôi phục lại đúng bản nháp này.
                ReviewView(draft: d) {
                    PendingDraftStore.clear()
                    draft = nil
                }
            }
            // WP3 bước 2: file tới qua onOpenURL trong lúc màn Chụp đã
            // hiện -> hút ngay vào hàng chờ chung.
            .onChange(of: externalImportURLs) { _, _ in consumeExternalImports() }
            // Lần đầu màn Chụp hiện: hút file đã chờ sẵn (anh mở file khi
            // app đang khoá Face ID / đang ở tab khác) + quét thư mục
            // Inbox phòng trường hợp hệ thống chép file vào trước khi
            // onOpenURL kịp chạy (khởi động lạnh).
            .onAppear {
                // P-DRAFT (L-2026-11-13-14): khôi phục bản nháp chờ
                // TRƯỚC — khi có draft, processNextImportedFile tự
                // giữ hàng chờ nạp đứng chờ theo luật cũ, không có
                // đường nạp nào chen vào bản nháp vừa khôi phục.
                restorePendingDraftIfNeeded()
                consumeExternalImports()
                sweepInbox()
            }
        }
    }

    /// P-DRAFT (L-2026-11-13-14): mở lại màn Kiểm Lại với bản nháp
    /// đã chụp xuống đĩa ở lượt trước (app bị hệ thống giết trong
    /// lúc anh đang kiểm dở). Chỉ khôi phục khi đang rảnh tay:
    /// đang có draft khác hoặc đang đọc dở thì bỏ qua — lượt tạo
    /// draft mới sẽ tự chụp snapshot mới đè lên. Snapshot hỏng:
    /// PendingDraftStore.load/discardCorrupt tự xoá + ghi log,
    /// hàm này trả về lặng, app mở bình thường.
    private func restorePendingDraftIfNeeded() {
        guard draft == nil, !isProcessing else { return }
        guard let snapshot = PendingDraftStore.load() else { return }
        guard let restored = snapshot.makeDraft() else {
            PendingDraftStore.discardCorrupt(
                reason: "snapshot không ánh xạ lại được thành ScanDraft")
            return
        }
        draft = restored
        statusText = "Đã khôi phục bản nháp chưa lưu từ lần mở trước — anh kiểm lại rồi bấm Lưu giúp."
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


    // MARK: Pipeline V3: lưu ảnh gốc -> ReceiptReader (đường đọc duy
    // nhất) -> bản nháp. Mọi đường nạp đều qua runRead ở dưới.

    /// Ánh xạ nguồn nạp của app (SourceType) sang nguồn nạp của
    /// pipeline (IntakeSource — ghi vào hồ sơ chẩn đoán).
    private func intakeSource(for source: SourceType) -> IntakeSource {
        switch source {
        case .camera: return .documentScanner
        case .photoLibrary: return .photoLibrary
        case .fileImport, .pdfImport: return .fileImport
        case .screenshot, .unknown: return .photoLibrary
        }
    }

    /// Đường quét tài liệu: lưu MỌI trang làm bằng chứng TRƯỚC
    /// (trang 1 = ảnh chính, mọi trang vào originalFileNames —
    /// cùng luật toàn-hay-không của applyRescannedOriginal: lưu
    /// dở dang thì xoá phần đã lưu và báo lỗi, không đọc nửa vời),
    /// rồi đọc đa trang qua pipeline (nối chữ ở tầng ráp dòng).
    private func process(scan: VNDocumentCameraScan) {
        // Tờ bị chặn chưa được quyết định thì không đọc tờ mới
        // chen qua (trạng thái bị chặn là của riêng tờ đó).
        guard blockedDraft == nil else {
            statusText = "Anh quyết định tờ đang bị chặn trước, rồi mới đọc tờ tiếp theo giúp."
            return
        }
        var names: [String] = []
        var images: [UIImage] = []
        for index in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: index)
            guard let name = ImageStore.saveJPEG(image) else {
                for saved in names { ImageStore.delete(fileName: saved) }
                errorText = "Không lưu được ảnh gốc vào máy — anh kiểm tra dung lượng trống giúp."
                return
            }
            names.append(name)
            images.append(image)
        }
        guard let firstName = names.first else { return }
        let pageCG = images.compactMap { ReceiptReader.uprightCGImage(from: $0) }
        guard pageCG.count == images.count, let firstCG = pageCG.first else {
            errorText = "Không dựng được ảnh đã quét để đọc."
            return
        }
        runRead(request: ReadRequest(
                    source: .documentScanner,
                    imageFileName: firstName,
                    image: firstCG,
                    pageImages: pageCG,
                    diagnosticsDirectory: ImageStore.directory,
                    qualityGate: QualityGate()),
                sourceType: .camera,
                originalFileNames: names)
    }

    /// Đường ảnh đơn (chọn ảnh / file ảnh / trang PDF đã render):
    /// lưu JPEG gốc trước, dựng thẳng ở pixel gốc, rồi đọc.
    private func process(image: UIImage, source: SourceType,
                         sourceFileName: String? = nil,
                         originalFileNames: [String] = [],
                         pdfRenderScale: Double? = nil) {
        guard blockedDraft == nil else {
            statusText = "Anh quyết định tờ đang bị chặn trước, rồi mới đọc tờ tiếp theo giúp."
            processNextImportedFile()
            return
        }
        guard let fileName = ImageStore.saveJPEG(image) else {
            errorText = "Không lưu được ảnh gốc vào máy — anh kiểm tra dung lượng trống giúp."
            processNextImportedFile()
            return
        }
        guard let cg = ReceiptReader.uprightCGImage(from: image) else {
            errorText = "Không dựng được ảnh để đọc."
            processNextImportedFile()
            return
        }
        runRead(request: ReadRequest(
                    source: intakeSource(for: source),
                    imageFileName: fileName,
                    image: cg,
                    pdfRenderScale: pdfRenderScale,
                    diagnosticsDirectory: ImageStore.directory,
                    qualityGate: QualityGate()),
                sourceType: source,
                sourceFileName: sourceFileName,
                originalFileNames: originalFileNames)
    }

    /// Chạy MỘT lần đọc trên hàng đợi nền (pipeline gồm nhiều ứng
    /// viên + tối đa 2 vòng ROI — không chạy trên main) rồi hạ
    /// cánh thành bản nháp trên main, đúng kỷ luật bất đồng bộ
    /// của đường đọc cũ.
    private func runRead(request: ReadRequest,
                         sourceType: SourceType,
                         sourceFileName: String? = nil,
                         originalFileNames: [String] = [],
                         rawTextIsPDFTextLayer: Bool = false) {
        isProcessing = true
        statusText = "Đang đọc hoá đơn…"
        errorText = nil
        var request = request
        // GÓI V4-4 (D-V4-2): cổng MỚI cho riêng lần đọc này khi
        // tầng gọi chưa cấp — không bao giờ dùng cổng của tờ khác.
        if request.qualityGate == nil { request.qualityGate = QualityGate() }
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = ReceiptReader.read(request)
            DispatchQueue.main.async {
                isProcessing = false
                // Không dòng chữ nào đọc được -> cùng thông báo lỗi
                // như đường cũ, không mở Review với tờ rỗng.
                if outcome.result.rawText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    statusText = nil
                    errorText = "Không đọc được chữ nào trong ảnh — anh chụp lại rõ hơn, đủ sáng giúp."
                    processNextImportedFile()
                    return
                }
                let newDraft = ScanDraft(
                    result: outcome.result,
                    imageFileName: request.imageFileName,
                    sourceType: sourceType,
                    sourceFileName: sourceFileName,
                    originalFileNames: originalFileNames,
                    rawTextIsPDFTextLayer: rawTextIsPDFTextLayer,
                    provenance: outcome.provenance,
                    reconcileReport: outcome.report,
                    diagnosticsID: outcome.diagnosticsID,
                    diagnosticsWriteFailed: outcome.diagnosticsWriteFailed)
                // GÓI V4-4 (D-V4-2): cổng phán .block => tờ KHÔNG
                // vào Review và KHÔNG chụp snapshot P-DRAFT; nó
                // nằm ở trạng thái bị chặn riêng cho tới khi anh
                // quyết định (xem khung cảnh báo trong body).
                if outcome.qualityOutcome?.decision == .block {
                    blockedDraft = newDraft
                    blockedQuality = outcome.qualityOutcome
                    statusText = "Một tờ đã bị cổng chất lượng chặn — anh quyết định ở khung cảnh báo bên dưới giúp."
                    return
                }
                presentDraft(newDraft,
                             note: qualityNote(outcome.qualityOutcome))
            }
        }
    }

    /// Trình MỘT bản nháp lên màn Kiểm Lại + chụp snapshot
    /// P-DRAFT — điểm hạ cánh DUY NHẤT của cả đường đọc thường
    /// lẫn đường "Vẫn đọc tờ này" từ trạng thái bị chặn, để hợp
    /// đồng chống mất bản nháp (L-2026-11-13-14) chỉ có một nơi
    /// thi hành.
    private func presentDraft(_ newDraft: ScanDraft, note: String?) {
        statusText = note
        draft = newDraft
        // P-DRAFT (L-2026-11-13-14): chụp bản nháp xuống đĩa NGAY
        // khi nó được trình, TRƯỚC khi sheet Kiểm Lại hiện — từ
        // khoảnh khắc này, việc dở của anh sống trên đĩa chứ
        // không chỉ trong @State. Ghi hỏng (hết dung lượng...)
        // thì nói thật bằng dòng trạng thái để anh biết mà lưu
        // sớm, không lặng im quay về chế độ dễ mất như trước.
        if !PendingDraftStore.save(PendingDraftSnapshot(draft: newDraft)) {
            let warning = "Chưa ghi được bản nháp phòng hờ xuống máy — anh lưu sớm giúp, đừng rời app lâu kẻo mất bản đang kiểm."
            statusText = statusText.map { $0 + " " + warning } ?? warning
        }
    }

    /// Chữ mô tả các vấn đề chất lượng đã phát hiện — dùng chung
    /// cho dòng nhắc .warn, khung .block và dòng ghi đè.
    private func qualityIssueText(_ outcome: QualityOutcome) -> String {
        var issues: [String] = []
        for detected in outcome.detected {
            switch detected {
            case "blur": issues.append("hơi mờ")
            case "glare": issues.append("bị chói sáng")
            case "lowContrast": issues.append("tương phản thấp (chữ nhạt)")
            default: issues.append(detected)
            }
        }
        return issues.isEmpty ? "chất lượng chưa đạt"
            : issues.joined(separator: ", ")
    }

    /// Dòng nhắc chất lượng lúc chụp cho quyết định .warn.
    /// Quyết định .block KHÔNG đi qua đây — nó có trạng thái
    /// giao diện riêng (GÓI V4-4 / D-V4-2).
    private func qualityNote(_ outcome: QualityOutcome?) -> String? {
        guard let outcome, outcome.decision == .warn else { return nil }
        return "Ảnh \(qualityIssueText(outcome)) — anh kiểm tra kỹ các số ở màn sau giúp."
    }

    /// Dòng trạng thái khi anh bấm "Vẫn đọc tờ này" ở khung bị
    /// chặn: nói rõ đây là đọc theo quyết định của anh.
    private func blockedNote(_ outcome: QualityOutcome) -> String {
        "Đã đọc tờ bị chặn theo yêu cầu của anh (ảnh \(qualityIssueText(outcome))) — anh kiểm tra kỹ các số ở màn sau giúp."
    }

    // MARK: - WP3: nạp file từ Files (CODE-AUDIT F1)

    /// Lấy file tiếp theo trong hàng chờ — chỉ chạy khi không có bản nháp
    /// nào đang mở và không có OCR nào đang chạy. Được gọi từ: kết quả
    /// fileImporter, lúc đóng màn Review (onDismiss), và các nhánh lỗi của
    /// đường nạp file (để một file hỏng không chặn cả lô).
    private func processNextImportedFile() {
        guard draft == nil, blockedDraft == nil, !isProcessing, !importQueue.isEmpty else { return }
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
            // chữ đoán — nên độ tin cậy 1.0 (CODE-AUDIT F1 mục 4). Đường
            // chữ đi vào CÙNG ReceiptReader như mọi đường khác (không
            // parser thứ hai): F4+F5 chạy trên đúng các dòng này, hồ sơ
            // chẩn đoán ghi nguồn pdfTextLayer. File PDF chính là bằng
            // chứng: imageFileName trỏ thẳng tới nó, các màn hiển thị
            // render trang 1 qua ImageStore.load.
            runRead(request: ReadRequest(
                        source: .pdfTextLayer,
                        imageFileName: storedPDFName,
                        byteSize: data.count,
                        textLines: lines,
                        diagnosticsDirectory: ImageStore.directory,
                        qualityGate: QualityGate()),
                    sourceType: .pdfImport,
                    sourceFileName: sourceFileName,
                    originalFileNames: [storedPDFName],
                    rawTextIsPDFTextLayer: true)
            return
        }
        // Không có lớp chữ (PDF là ảnh scan): render trang 1 -> đường ảnh.
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
                originalFileNames: [storedPDFName],
                pdfRenderScale: 200.0 / 72.0)
    }

    /// Trích lớp chữ nhúng trong PDF (PDFKit — có từ iOS 11, không phải
    /// framework lạ lúc khởi động; chỉ chạm khi anh bấm nạp file, đúng
    /// luật TEAM.md #1). Trả nil khi PDF không chứa dòng chữ nào — đó là
    /// tín hiệu rẽ sang đường render->OCR, KHÔNG phải lỗi.
    /// Thứ tự dòng = thứ tự nội dung từng trang (page.string); với hoá đơn
    /// do máy tạo thì đó là thứ tự đọc (CODE-AUDIT F1 mục 3).
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
        var size = CGSize(width: bounds.width * scaleFactor, height: bounds.height * scaleFactor)
        // A2-06 (rà soát vòng 2, 2026-11-13): trần cạnh dài
        // 4096px — PDF khổ lớn ở 200dpi có thể dựng bitmap
        // hàng chục MP và bị hệ thống giết vì bộ nhớ ngay
        // trong thao tác nạp. Hạ kích thước tương ứng, giữ
        // tỉ lệ (phép vẽ ở dưới tỉ lệ theo size/bounds nên
        // tự đúng); trang PDF thường (Letter/A4 ~1700x2200)
        // không chạm trần này.
        let maxSide: CGFloat = 4096
        let longest = max(size.width, size.height)
        if longest > maxSide {
            let shrink = maxSide / longest
            size = CGSize(width: size.width * shrink, height: size.height * shrink)
        }
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
}


// MARK: - P-DRAFT: ánh xạ ScanDraft <-> PendingDraftSnapshot
//
// Ánh xạ sống ở file này vì ScanDraft khai ở đây; các DTO + kho
// lưu (PendingDraft.swift) không phụ thuộc tầng UI. Trường `id`
// của ScanDraft là định danh phiên hiển thị (Identifiable) —
// KHÔNG chụp: bản nháp khôi phục nhận id mới, đúng nghĩa của nó.

extension PendingDraftSnapshot {
    /// Chụp từ bản nháp đang sống trong bộ nhớ (gọi ngay khi
    /// draft ra đời ở runRead).
    init(draft: ScanDraft) {
        self.init(result: draft.result,
                  imageFileName: draft.imageFileName,
                  sourceTypeRaw: draft.sourceType.rawValue,
                  sourceFileName: draft.sourceFileName,
                  originalFileNames: draft.originalFileNames,
                  rawTextIsPDFTextLayer: draft.rawTextIsPDFTextLayer,
                  provenance: draft.provenance,
                  reconcileReport: draft.reconcileReport,
                  diagnosticsID: draft.diagnosticsID,
                  diagnosticsWriteFailed: draft.diagnosticsWriteFailed)
    }

    /// Dựng lại bản nháp để mở Kiểm Lại. Trả nil khi báo cáo đối
    /// chiếu chứa mã enum lạ (bản chụp của phiên bản khác) — nơi
    /// gọi xử như snapshot hỏng (xoá + log). Riêng sourceType lạ
    /// thì hạ về .unknown: đó là nhãn nguồn nạp (F3), không đáng
    /// đánh đổi cả bản nháp vì một nhãn.
    func makeDraft() -> ScanDraft? {
        var restoredReport: ReconcileReport? = nil
        if let reportDTO = reconcileReport {
            guard let report = reportDTO.toOriginal() else { return nil }
            restoredReport = report
        }
        return ScanDraft(result: result.toOriginal(),
                         imageFileName: imageFileName,
                         sourceType: SourceType(rawValue: sourceTypeRaw) ?? .unknown,
                         sourceFileName: sourceFileName,
                         originalFileNames: originalFileNames,
                         rawTextIsPDFTextLayer: rawTextIsPDFTextLayer,
                         provenance: provenance,
                         reconcileReport: restoredReport,
                         diagnosticsID: diagnosticsID,
                         diagnosticsWriteFailed: diagnosticsWriteFailed)
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

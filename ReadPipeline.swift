// ============================================================
// Sổ Hóa Đơn — ReadPipeline.swift (KHUNG NỐI ĐƯỜNG ĐỌC, Pha 3)
//
// Bản đồ module của DESIGN-FINAL §3: F1 nạp (CaptureIntake của
// Pha 2) -> F2 engine (adapter Pha 2) -> F3 ráp dòng
// (LineAssembly của Pha 2) -> F4 bóc tách (Parser.swift) -> F5
// trọng tài (Reconcile.swift) -> vòng đọc-lại ROI
// (RegionReReader.swift). File này là KHUNG NỐI F3->F4->F5: nó
// nhận các dòng ĐÃ RÁP từ F3 (kèm hộp), chạy parse -> reconcile
// -> ROI (khi có gợi ý vùng + có bộ đọc lại được tiêm), và trả
// outcome gồm: kết quả cuối + báo cáo trọng tài + BẢN ĐỒ
// PROVENANCE cho hồ sơ chẩn đoán v2 (Pha 0) + snapshot reconcile
// + nhật ký các vòng ROI.
//
// ĐIỂM NỐI F5 (điều kiện nghiệm thu riêng của Pha 3): thứ tự
// parse (F4) -> reconcile (F5) -> điểm kích hoạt ROI nằm ở đây,
// dùng NGUYÊN API của ReconcileSession (P2-3): session tự chạy
// reconcile lượt nền trong init, giữ trạng thái tốt nhất, và
// submitRound(result:lines:) tự parse-lại-đối-chiếu + áp luật
// đơn điệu 3 bậc. Khung này không tự chế lại luật nào của F5.
//
// LUẬT GIỮ NGUYÊN:
// - F4 (parse) KHÔNG tự sửa số — nó chỉ gắn cờ (luật toàn cục 1).
// - F5 chỉ áp sửa DUY NHẤT + có bằng chứng tại chỗ; mọi sửa gắn
//   provenance .inferred(channel) ở outcome này và ép
//   needsReview qua ReconcileReport.requiresReview.
// - TOTAL_ONLY không bao giờ suy subtotal/thuế (Reconcile tự giữ).
// - ROI: vòng bị session TỪ CHỐI => phiên kết thúc (session tự
//   đóng), khung giữ trạng thái tốt nhất. Trần mềm 4 giây cho
//   F5+ROI: quá trần => không mở vòng mới (fail-closed).
// - Kênh CANDIDATE: ReadPipeline KHÔNG truyền variants — kênh
//   ngủ theo kết luận oracle@3 của Pha 3; đường đo kênh nằm ở
//   ReceiptParser.reconcile(candidateVariants:) (gương ngoại
//   tuyến), không qua khung này cho tới khi kênh tốt nghiệp.
// - Diagnostics là điều kiện của outcome (bất biến của thiết
//   kế): hàm này trả outcome kèm đủ provenance + snapshot +
//   roiRounds để lớp gọi ghi hồ sơ; ghi hồ sơ thất bại => lớp
//   gọi KHÔNG được coi outcome là "sạch" (ReadDiagnostics).
//
// NGOẠI TUYẾN (Pha 3): F1/F2/F3 chạy ở mức adapter của Pha 2 —
// khung này nhận đầu vào là dòng đã ráp; nối VisionKit thật vào
// khung là việc của Pha 4.
// ============================================================

import Foundation
import CoreGraphics
// PHA 4 (điểm nối): nửa trước đường đọc nối ở cuối file này cần
// UIKit (dựng thẳng ảnh, mã máy), CoreImage (ứng viên phái sinh)
// và Vision (phát hiện tứ giác cho ứng viên phối cảnh).
import UIKit
import CoreImage
import Vision

/// Kết quả một lần chạy đường đọc F3->F4->F5(+ROI).
struct ReadPipelineOutcome {
    /// Kết quả cuối (F4 + các sửa F5 đã áp + vòng ROI đã nhận).
    var result: ParseResult
    /// PHA 4 (điểm nối, ghi ở AFTER): kết quả F4 TRƯỚC F5 — nguồn
    /// cho DiagParseSnapshot của hồ sơ chẩn đoán v2 (sơ đồ §1.5
    /// định nghĩa snapshot là trạng thái cuối F4). Pha 3 chưa lộ
    /// trường này ra outcome; Pha 4 cần nó để ghi chẩn đoán mà
    /// không chạy lại parse (chạy lại = fork hành vi).
    var parsedBeforeReconcile: ParseResult
    /// Báo cáo trọng tài của trạng thái cuối.
    var report: ReconcileReport
    /// Provenance từng trường cho DiagParseSnapshot:
    /// khoá "items[i].amount" | "items[i].qty" | "items[i].unitPrice"
    /// | "items[i]" (món chèn) | "subtotal" | "taxes" | "total".
    var provenance: [String: FieldProvenance]
    /// Snapshot reconcile cho hồ sơ chẩn đoán v2.
    var reconcileSnapshot: DiagReconcileSnapshot
    /// Nhật ký các vòng ROI đã thử (rỗng = không chạy ROI).
    var roiRounds: [DiagROIRound]
    /// Có vòng ROI nào được CHẤP NHẬN hay không.
    var usedROI: Bool
    /// needsReview tổng: lấy từ báo cáo trọng tài của trạng thái cuối.
    var requiresReview: Bool { report.requiresReview }
}

enum ReadPipeline {

    /// Gộp dòng đọc-lại vào danh sách dòng đầy đủ (ranh giới F3):
    /// mặc định thay thế các dòng trong lineRange của hint bằng
    /// dòng mới (xử lý theo thứ tự range giảm dần để chỉ số không
    /// lệch); hint không có lineRange => nối cuối. Trên thiết bị,
    /// Pha 4 thay hàm này bằng khử-trùng-theo-hộp của F3.
    typealias RegionLineMerger = (_ current: [OCRLine],
                                  _ replacements: [(hint: ReconcileRegionHint, lines: [OCRLine])])
        -> [OCRLine]

    static func defaultMerge(current: [OCRLine],
                             replacements: [(hint: ReconcileRegionHint, lines: [OCRLine])])
        -> [OCRLine] {
        var out = current
        let ordered = replacements.sorted {
            ($0.hint.lineRange?.lowerBound ?? Int.max) > ($1.hint.lineRange?.lowerBound ?? Int.max)
        }
        for rep in ordered {
            guard !rep.lines.isEmpty else { continue }
            if let range = rep.hint.lineRange,
               range.lowerBound >= 0, range.upperBound < out.count {
                out.replaceSubrange(range, with: rep.lines)
            } else {
                out.append(contentsOf: rep.lines)
            }
        }
        return out
    }

    /// Chạy toàn đường đọc trên dòng đã ráp.
    /// - lines: dòng từ F3 (hàm tự chuẩn hoá giống parse/reconcile
    ///   để chỉ số dòng thống nhất giữa các tầng).
    /// - lineBoxes: hộp song song với dòng SAU chuẩn hoá (cho band ROI).
    /// - reReader: nil => không chạy ROI (đường đọc thuần F4->F5).
    static func run(lines rawLines: [OCRLine],
                    lineBoxes: [CGRect?]? = nil,
                    qualityMap: [QualityMapEntry] = [],
                    reReader: RegionReReader? = nil,
                    mergeRegionLines: RegionLineMerger = ReadPipeline.defaultMerge)
        -> ReadPipelineOutcome {
        let started = Date()
        let lines = rawLines
            .map { OCRLine(text: $0.text.trimmingCharacters(in: .whitespaces),
                           confidence: $0.confidence) }
            .filter { !$0.text.isEmpty }

        // ── F4 -> F5: session tự chạy reconcile lượt nền ──────
        let f4 = ReceiptParser.parse(lines: lines)
        let session = ReconcileSession(result: f4, lines: lines, lineBoxes: lineBoxes)

        // ── Vòng ROI: đích nhắm = pendingHints ∩ QualityMap ───
        var roiRounds: [DiagROIRound] = []
        var lastAcceptedRound = 0
        if let reReader = reReader {
            while !session.isFinished && session.roundsUsed < ReconcileSession.maxRounds {
                // Trần mềm 4 giây: quá trần => không mở vòng mới.
                if Date().timeIntervalSince(started) > RegionReReader.softDeadlineSeconds { break }
                let hints = session.pendingHints
                if hints.isEmpty { break }
                let regions = RegionReReader.targetRegions(
                    hints: hints, lineBoxes: lineBoxes, qualityMap: qualityMap,
                    maxRegions: ReconcileSession.maxRegionsPerRound)
                if regions.isEmpty { break }
                var replacements: [(hint: ReconcileRegionHint, lines: [OCRLine])] = []
                var added = 0
                for region in regions {
                    guard let firstHintIdx = region.hintIndices.first else { continue }
                    let hint = hints[firstHintIdx]
                    let fresh = reReader.recognizeRegion(hint, upscale: 2.0)
                    if !fresh.isEmpty {
                        replacements.append((hint, fresh))
                        added += fresh.count
                    }
                }
                if replacements.isEmpty { break }
                let before = stateString(session.bestReport, session.bestResult)
                let merged = mergeRegionLines(lines, replacements)
                let reparsed = ReceiptParser.parse(lines: merged)
                let accepted = session.submitRound(result: reparsed, lines: merged,
                                                   lineBoxes: lineBoxes)
                roiRounds.append(DiagROIRound(
                    round: session.roundsUsed,
                    hints: regions.flatMap { $0.hintIndices }.map { diagHint(hints[$0]) },
                    fragmentsAdded: added,
                    stateBefore: before,
                    stateAfter: stateString(session.bestReport, session.bestResult),
                    accepted: accepted))
                if accepted { lastAcceptedRound = session.roundsUsed } else { break }
            }
        }

        let finalResult = session.bestResult
        let finalReport = session.bestReport

        // ── Provenance ─────────────────────────────────────────
        var provenance: [String: FieldProvenance] = [:]
        for fix in finalReport.fixes {
            switch fix.field {
            case .amount: provenance["items[\(fix.itemIndex)].amount"] = .inferred(channel: fix.channel.rawValue)
            case .qty: provenance["items[\(fix.itemIndex)].qty"] = .inferred(channel: fix.channel.rawValue)
            case .unit: provenance["items[\(fix.itemIndex)].unitPrice"] = .inferred(channel: fix.channel.rawValue)
            case .insert: provenance["items[\(fix.itemIndex)]"] = .inferred(channel: fix.channel.rawValue)
            }
        }
        if lastAcceptedRound > 0 {
            // Trường ĐỔI so với F4 mà không có fix của trọng tài =>
            // giá trị đến từ vòng đọc lại (bằng chứng tại chỗ mới).
            let n = min(f4.items.count, finalResult.items.count)
            for i in 0..<n {
                let a = f4.items[i], b = finalResult.items[i]
                if a.amountCents != b.amountCents, provenance["items[\(i)].amount"] == nil {
                    provenance["items[\(i)].amount"] = .roiRecovered(round: lastAcceptedRound)
                }
                if a.qty != b.qty, provenance["items[\(i)].qty"] == nil {
                    provenance["items[\(i)].qty"] = .roiRecovered(round: lastAcceptedRound)
                }
                if a.unitPriceCents != b.unitPriceCents, provenance["items[\(i)].unitPrice"] == nil {
                    provenance["items[\(i)].unitPrice"] = .roiRecovered(round: lastAcceptedRound)
                }
            }
            if f4.subtotalCents != finalResult.subtotalCents, provenance["subtotal"] == nil {
                provenance["subtotal"] = .roiRecovered(round: lastAcceptedRound)
            }
            if f4.totalCents != finalResult.totalCents, provenance["total"] == nil {
                provenance["total"] = .roiRecovered(round: lastAcceptedRound)
            }
            if f4.taxes.map({ $0.amountCents }) != finalResult.taxes.map({ $0.amountCents }),
               provenance["taxes"] == nil {
                provenance["taxes"] = .roiRecovered(round: lastAcceptedRound)
            }
        }

        // ── Snapshot cho hồ sơ chẩn đoán ───────────────────────
        let snapshot = DiagReconcileSnapshot(
            status: snapshotStatus(finalReport.status),
            fixes: finalReport.fixes.map {
                DiagFix(channel: $0.channel.rawValue, field: fieldName($0.field),
                        itemIndex: $0.itemIndex,
                        oldValue: $0.oldValue.map { String($0) } ?? "nil",
                        newValue: String($0.newValue))
            },
            suggestions: finalReport.suggestions.flatMap { sol in
                sol.map { "món#\($0.itemIndex) \(fieldName($0.field)) \($0.oldValue.map { String($0) } ?? "nil")→\($0.newValue) [\($0.channel.rawValue)]" }
            },
            regionHints: finalReport.regionHints.map { diagHint($0) })

        return ReadPipelineOutcome(result: finalResult,
                                   parsedBeforeReconcile: f4,
                                   report: finalReport,
                                   provenance: provenance,
                                   reconcileSnapshot: snapshot,
                                   roiRounds: roiRounds,
                                   usedROI: lastAcceptedRound > 0)
    }

    // MARK: - Phụ trợ trình bày hồ sơ

    private static func snapshotStatus(_ s: ReconcileStatus) -> String {
        switch s {
        case .ok, .repaired: return "closed"
        case .suggestionOnly: return "suggestedOnly"
        default: return "flagged"
        }
    }

    private static func fieldName(_ f: ReconcileFix.Field) -> String {
        switch f {
        case .amount: return "amount"
        case .qty: return "qty"
        case .unit: return "unitPrice"
        case .insert: return "insert"
        }
    }

    private static func diagHint(_ h: ReconcileRegionHint) -> DiagRegionHint {
        DiagRegionHint(
            box: h.band.map { DiagRect(x: Double($0.minX), y: Double($0.minY),
                                       width: Double($0.width), height: Double($0.height)) }
                ?? DiagRect(x: 0, y: 0, width: 0, height: 0),
            reason: "\(h.block.rawValue)/\(h.reason.rawValue)",
            field: nil)
    }

    private static func stateString(_ rep: ReconcileReport, _ r: ParseResult) -> String {
        let d = rep.moneyDeltaCents.map { String(abs($0)) } ?? "nil"
        return "\(rep.status.rawValue) |Δ|=\(d) món=\(r.items.count)"
    }
}


// ============================================================
// PHA 4 — NỬA TRƯỚC ĐƯỜNG ĐỌC: ReceiptReader (ĐIỂM NỐI LỚN)
//
// Pha 3 để lại khung F3->F4->F5 ở trên; nửa F1->F2->F3 nối ở
// đây, trong CÙNG file, vì M10 là module điều phối duy nhất của
// bản đồ §1.1 và đường đọc duy nhất của app (luật 1.6: BenchShell
// liên kết đúng file này, không có bản sao đường đọc thứ hai).
//
// ReceiptReader.read là cửa vào DUY NHẤT của mọi lần đọc:
//   - ảnh (máy quét tài liệu / thư viện / chụp): F1 metadata ->
//     chuỗi ứng viên §3.1(e) (mỗi ứng viên chạy trọn F2->F3->F4,
//     chấm bằng CandidateScorer §3.6, hoà -> gốc thắng) -> ứng
//     viên thắng vào khung ReadPipeline.run ở trên (F5 + ROI).
//   - trang PDF có lớp chữ / chữ đã lưu (nút Đọc lại): dòng chữ
//     vào thẳng khung, không engine, không ứng viên ảnh.
// Mọi lần đọc đều dựng hồ sơ chẩn đoán v2 và qua cổng
// ReadFinalizer TRƯỚC khi trả outcome (§1.5: không bản ghi =
// lần đọc không tồn tại cho kiểm chứng; ghi lỗi -> cờ
// diagnosticsWriteFailed ép tờ vào Kiểm Lại ở tầng UI).
//
// GIỚI HẠN ĐÃ GHI (đo trên thiết bị, không phải việc của bàn
// giấy): chính sách lát = đọc toàn khung một lượt (phương án
// (a) §3.3 — thi đấu lát (b)/(c)/(d) thuộc phiên đo thiết bị vì
// hồ sơ phiên 2026-11-11 không chứa hình học lát); ứng viên
// dewarp CHƯA có bản thực thi ở bất kỳ pha nào -> không sinh,
// ghi cờ "candidate-dewarp-not-produced" trong mọi hồ sơ ảnh;
// ứng viên "enhanced theo vùng dòng" hiện thực bằng biến thể
// CoreImage toàn khung (hiệu chuẩn theo vùng thuộc phiên đo);
// tờ nhiều trang chỉ đọc ứng viên gốc mỗi trang (đa dạng ứng
// viên cho đa trang để sau phiên đo lát).
// ============================================================

/// Tem bộ đọc thế hệ v3 — NGUỒN DUY NHẤT của tem: ReceiptViews
/// (currentParserVersion) tham chiếu hằng này và hồ sơ chẩn
/// đoán ghi đúng giá trị này ở identity.parserVersion, nên tem
/// trong app và tem trong hồ sơ không thể lệch nhau.
enum ReadCoreVersion {
    /// core-v3-2 (2026-11-12): bản giao patch lớn đầu tiên của
    /// thế hệ v3 — crash-fix matchGroups (L-2026-11-12-13) +
    /// gói FULL-REVIEW (T1/T2/N1-N5/C8/C9) + trap-fix họ A
    /// dạng hữu-hạn-khổng-lồ ở 3 site binning. Harness run
    /// #21 xanh trọn 4 cổng trên core-v3-1 + trap-fix; bản
    /// này chỉ đổi tem so với commit đó, và lượt harness xác
    /// nhận trên đúng commit giao là điều kiện giao bản.
    static let parserVersion = "core-v3-2"
}

/// Yêu cầu đọc (DESIGN-DETAIL §1.3, cụ thể hoá cho các đường
/// nạp thật của app). Tầng gọi (ScanView/BenchView/ReceiptViews)
/// lưu ẢNH GỐC trước rồi mới gọi — pipeline không sở hữu việc lưu.
struct ReadRequest {
    var source: IntakeSource
    /// Tên file gốc đã lưu (khoá của file phụ chẩn đoán).
    var imageFileName: String
    /// Ảnh trang 1 ĐÃ DỰNG THẲNG ở pixel gốc (xem
    /// ReceiptReader.uprightCGImage). nil ở đường chữ.
    var image: CGImage? = nil
    /// Mọi trang (kể cả trang 1) khi quét tài liệu nhiều trang;
    /// rỗng = một trang (dùng `image`).
    var pageImages: [CGImage] = []
    var byteSize: Int? = nil
    /// Hệ số dựng trang PDF (dpi/72) — chỉ đường PDF render.
    var pdfRenderScale: Double? = nil
    /// Đường chữ: lớp chữ PDF hoặc chữ đã lưu (Đọc lại).
    var textLines: [OCRLine]? = nil
    /// Thư mục ghi file phụ chẩn đoán (app: ImageStore.directory;
    /// nil = không ghi — chỉ dùng cho kiểm ngoại tuyến).
    var diagnosticsDirectory: URL? = nil
    /// Cổng chất lượng dùng CHUNG cho cả phiên chụp (trạng thái
    /// fail-safe đếm liên tiếp nằm trong instance; ScanView giữ
    /// một instance). nil = cổng mới cho lần đọc này.
    var qualityGate: QualityGate? = nil
    var receiptID: UUID? = nil
}

/// Kết quả một lần đọc trọn ống — thứ tầng UI hạ cánh.
struct ReadOutcome {
    var result: ParseResult
    var report: ReconcileReport
    /// Provenance mức UI: hợp nhất provenance F5/ROI của khung +
    /// domainCorrected suy từ result.corrections.
    var provenance: [String: FieldProvenance]
    var diagnostics: ReadDiagnostics
    /// Chỉ có khi file phụ đã ghi thành công.
    var diagnosticsID: String? = nil
    /// true = ghi chẩn đoán THẤT BẠI -> tầng UI ép Kiểm Lại.
    var diagnosticsWriteFailed: Bool = false
    /// Quyết định cổng chất lượng lúc chụp (đường ảnh).
    var qualityOutcome: QualityOutcome? = nil
    var usedROI: Bool = false
    var requiresReview: Bool { report.requiresReview || diagnosticsWriteFailed }
}

enum ReceiptReader {
    // CI-FIX-6 (L-2026-11-12-12): móc truy vết giai đoạn — vỏ
    // đo (BenchShell) gán closure ghi xuống đĩa TRƯỚC mỗi bước
    // của chuỗi ứng viên; app chính để nil (không đổi hành vi).
    // App chết giữa chuỗi thì dòng cuối cùng chỉ đích danh tầng
    // chết — thay cho việc phải xin .ips vòng ngoài.
    static var stageBreadcrumb: ((String) -> Void)? = nil

    // CI-FIX-6: CIDocumentEnhancer (lọc ML của CoreImage) là
    // nghi phạm H1 của crash run #44 và lợi ích của nó chưa
    // từng được đo trên thiết bị — cách ly sau cờ mặc định TẮT
    // ở cả hai app (D3: ứng viên phải đo-mới-được-sống);
    // BenchShell có công tắc bật lại cho phép đo A/B có kiểm
    // soát trên thiết bị.
    static var documentEnhancerEnabled = false

    /// Chính sách lát hiệu lực: toàn khung một lượt (§3.3(a)).
    static let tilePolicyID = "full-frame-v3"

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    // MARK: - Cửa vào duy nhất

    static func read(_ req: ReadRequest) -> ReadOutcome {
        let started = Date()
        var meta = IntakeMetadata(source: req.source,
                                  imageFileName: req.imageFileName,
                                  byteSize: req.byteSize)
        let pages = req.pageImages.isEmpty
            ? (req.image.map { [$0] } ?? []) : req.pageImages
        if let first = pages.first {
            meta.pixelWidth = first.width
            meta.pixelHeight = first.height
        }
        meta.pageCount = max(1, pages.count)
        var diagInput = meta.diagInput()
        if let scale = req.pdfRenderScale { diagInput.pdfRenderScale = scale }

        let identity = DiagIdentity(
            diagnosticsID: UUID().uuidString,
            createdAt: iso8601.string(from: started),
            appBuild: appBuildString(),
            parserVersion: ReadCoreVersion.parserVersion,
            deviceModel: deviceModelString(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString)

        if let textLines = req.textLines {
            return finishTextPath(req: req, lines: textLines,
                                  identity: identity, input: diagInput,
                                  started: started)
        }
        guard !pages.isEmpty else {
            return finishEmpty(req: req, identity: identity,
                               input: diagInput, started: started)
        }
        return finishImagePath(req: req, pages: pages,
                               identity: identity, input: diagInput,
                               started: started)
    }

    // MARK: - Dựng thẳng ảnh (chuẩn hoá hướng ở F1)

    /// Dựng UIImage thành CGImage đã thẳng (orientation .up) ở
    /// ĐÚNG pixel gốc: orientation .up thì trả thẳng cgImage,
    /// còn lại vẽ lại qua renderer tỉ lệ 1 với khung = kích
    /// thước pixel sau xoay — cùng cách bản cũ làm, không đổi
    /// mẫu theo điểm (point) ở tỉ lệ hiển thị.
    static func uprightCGImage(from image: UIImage) -> CGImage? {
        guard let cg = image.cgImage else { return nil }
        if image.imageOrientation == .up { return cg }
        let swap: Bool
        switch image.imageOrientation {
        case .left, .right, .leftMirrored, .rightMirrored: swap = true
        default: swap = false
        }
        let w = swap ? cg.height : cg.width
        let h = swap ? cg.width : cg.height
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: w, height: h), format: format)
        let ui = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return ui.cgImage
    }

    // MARK: - Đường chữ (PDF text layer / Đọc lại từ chữ đã lưu)

    private static func finishTextPath(req: ReadRequest,
                                       lines rawLines: [OCRLine],
                                       identity: DiagIdentity,
                                       input: DiagInput,
                                       started: Date) -> ReadOutcome {
        let passID = req.source == .pdfTextLayer
            ? "pdf-text-layer" : "stored-text"
        // Mảnh tổng hợp: mỗi dòng chữ là một mảnh (không hộp —
        // đường chữ không có hình học; F4 chạy chế độ chữ thuần
        // như đường reparse di sản, boxes = nil).
        var fragments: [Fragment] = []
        var assembled: [AssembledLine] = []
        for (i, line) in rawLines.enumerated() {
            fragments.append(Fragment(
                id: i + 1, text: line.text, alternates: [],
                confidence: line.confidence, box: .zero,
                passID: passID, tileIndex: nil, regionID: nil))
            assembled.append(AssembledLine(
                text: line.text, confidence: line.confidence,
                box: .zero,
                spans: [DiagSpan(fragmentID: i + 1, charStart: 0,
                                 charEnd: line.text.count)],
                passSources: [passID], contested: false,
                alternates: [], columnBreaks: []))
        }
        let assembly = AssemblyResult(lines: assembled,
                                      dedupeDropped: [],
                                      invariantViolations: 0)
        let manifest = EngineManifest(
            family: "none-text", revision: "", level: "",
            languagesEffective: [], usesLanguageCorrection: false,
            minimumTextHeight: 0)
        let outcome = ReadPipeline.run(lines: rawLines,
                                       lineBoxes: nil,
                                       qualityMap: [],
                                       reReader: nil)
        let candidate = DiagCandidate(
            kind: "text", transformDesc: passID, gateVerdict: nil,
            scoreComponents: [:], scoreTotal: nil, winner: true)
        return finalize(req: req, outcome: outcome,
                        identity: identity, input: input,
                        manifest: manifest, candidates: [candidate],
                        qualityMap: [], fragments: fragments,
                        assembly: assembly, qualityOutcome: nil,
                        extraFlags: [], started: started)
    }

    /// Không ảnh, không chữ: outcome rỗng + cờ lỗi — fail-closed,
    /// không crash, vẫn qua cổng ghi chẩn đoán như mọi lần đọc.
    private static func finishEmpty(req: ReadRequest,
                                    identity: DiagIdentity,
                                    input: DiagInput,
                                    started: Date) -> ReadOutcome {
        var empty = ParseResult()
        empty.warnings = ["Không có ảnh hoặc dòng chữ để đọc"]
        let outcome = ReadPipelineOutcome(
            result: empty, parsedBeforeReconcile: empty,
            report: ReconcileReport(status: .noAnchor,
                                    requiresReview: true),
            provenance: [:],
            reconcileSnapshot: DiagReconcileSnapshot(status: "notRun"),
            roiRounds: [], usedROI: false)
        let manifest = EngineManifest(
            family: "none", revision: "", level: "",
            languagesEffective: [], usesLanguageCorrection: false,
            minimumTextHeight: 0)
        return finalize(req: req, outcome: outcome,
                        identity: identity, input: input,
                        manifest: manifest, candidates: [],
                        qualityMap: [], fragments: [],
                        assembly: AssemblyResult(lines: [],
                                                 dedupeDropped: [],
                                                 invariantViolations: 0),
                        qualityOutcome: nil,
                        extraFlags: [],
                        error: "no-input",
                        started: started)
    }


    // MARK: - Đường ảnh (F1 -> chuỗi ứng viên -> F5/ROI)

    /// Một ứng viên đã chạy trọn F2->F3->F4 và được chấm.
    private struct CandidateRun {
        var step: CandidateStep
        var image: CGImage
        var fragments: [Fragment]
        var assembly: AssemblyResult
        var parsed: ParseResult
        var evaluation: CandidateEvaluation
        var scoreTotal: Double
        var scoreComponents: [String: Double]
        var gateVerdict: String? = nil
        var stitchStatus: String? = nil
    }

    private static func finishImagePath(req: ReadRequest,
                                        pages: [CGImage],
                                        identity: DiagIdentity,
                                        input: DiagInput,
                                        started: Date) -> ReadOutcome {
        let engine = ClassicTextEngine()
        let multiPage = pages.count > 1
        var flags: [String] = ["candidate-dewarp-not-produced"]
        var runs: [CandidateRun] = []

        // Ứng viên theo đúng thứ tự CandidateChain.steps; bước
        // nào không sinh được thì bỏ qua (trừ original — luôn có).
        var enhancedSeen = 0
        var anyE1Closed = false
        for step in CandidateChain.steps {
            stageBreadcrumb?("candidate-\(step.kind)")
            switch step.kind {
            case "original":
                if let run = runCandidate(step: step, images: pages,
                                          engine: engine) {
                    runs.append(run)
                    anyE1Closed = anyE1Closed || run.evaluation.e1Closed
                }
            case "perspective":
                // Đa trang: đa dạng ứng viên để sau phiên đo (xem
                // đầu mục) — chỉ đường một trang mới sinh phái sinh.
                guard !multiPage, let first = pages.first else { continue }
                let (img, verdict) = perspectiveCandidate(from: first)
                guard let img else { continue }
                if let run = runCandidate(step: step, images: [img],
                                          engine: engine) {
                    var run = run
                    run.gateVerdict = verdict
                    runs.append(run)
                    anyE1Closed = anyE1Closed || run.evaluation.e1Closed
                }
            case "dewarp":
                continue // chưa có bản thực thi — cờ đã ghi ở trên
            case "shadowRemoved":
                guard !multiPage, let first = pages.first,
                      let img = ciVariant(first, kind: "shadowRemoved")
                else { continue }
                if let run = runCandidate(step: step, images: [img],
                                          engine: engine) {
                    runs.append(run)
                    anyE1Closed = anyE1Closed || run.evaluation.e1Closed
                }
            case "enhanced":
                enhancedSeen += 1
                guard !multiPage, let first = pages.first else { continue }
                let variant = enhancedSeen == 1 ? "enhancedContrast"
                    : "enhancedDocument"
                if variant == "enhancedDocument",
                   !documentEnhancerEnabled {
                    flags.append("document-enhancer-off")
                    continue
                }
                guard let img = ciVariant(first, kind: variant)
                else { continue }
                if let run = runCandidate(step: step, images: [img],
                                          engine: engine) {
                    runs.append(run)
                    anyE1Closed = anyE1Closed || run.evaluation.e1Closed
                }
            case "binarized":
                // CUỐI CÙNG và chỉ khi chưa ứng viên nào khép E1.
                guard !anyE1Closed, !multiPage, let first = pages.first,
                      let img = ciVariant(first, kind: "binarized")
                else { continue }
                if let run = runCandidate(step: step, images: [img],
                                          engine: engine) {
                    runs.append(run)
                }
            default:
                continue
            }
        }

        // Phòng thủ fail-closed: original luôn sinh được khi có
        // ảnh; nếu engine ném lỗi ở mọi ứng viên thì runs rỗng —
        // dựng outcome rỗng có cờ thay vì crash.
        guard !runs.isEmpty else {
            return finishEmpty(req: req, identity: identity,
                               input: input, started: started)
        }

        stageBreadcrumb?("scoring")
        let winnerIndex = CandidateScorer.pickWinner(
            runs.map { $0.evaluation })
        let winner = runs[winnerIndex]
        if multiPage, let status = winner.stitchStatus {
            flags.append("stitch-\(status)")
        }

        // N3-FIX (FULL-REVIEW): thả ảnh toàn phân giải của các
        // ứng viên THUA ngay sau khi có winner. Bản cũ giữ
        // CGImage 12-24MP của MỌI ứng viên tới tận cuối lần
        // đọc — đỉnh bộ nhớ vài trăm MB/lần đọc, bề mặt jetsam
        // cấu trúc. Sau điểm này ứng viên thua chỉ còn được
        // dùng ở tầng metadata (hồ sơ chẩn đoán: kind/điểm/cờ)
        // và fragments/assembly — KHÔNG còn ai đọc ảnh của
        // chúng; ảnh winner đi tiếp qua bản sao `winner`.
        if let tiny = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage() {
            for i in runs.indices where i != winnerIndex {
                runs[i].image = tiny
            }
        }

        // QualityMap theo vị trí trên ảnh THẮNG + cổng chất
        // lượng lúc chụp (quyết định 3 tầng của Pha 2; chặn mặc
        // định TẮT trong QualityThresholds).
        var qualityMap: [QualityMapEntry] = []
        var qualityOutcome: QualityOutcome? = nil
        if let grid = LuminanceGrid.fromImage(winner.image) {
            let thresholds = QualityThresholds()
            qualityMap = winner.assembly.lines.map {
                grid.qualityMapEntry(for: $0.box, thresholds: thresholds)
            }
            let gate = req.qualityGate ?? QualityGate()
            qualityOutcome = gate.evaluate(grid.signals())
            if let qo = qualityOutcome, qo.decision != .pass {
                flags.append("quality-\(qo.decision.rawValue):"
                    + qo.detected.joined(separator: ","))
            }
        }

        // ROI: bộ đọc lại vùng cắt từ ẢNH THẮNG (ứng viên thắng
        // là ảnh đã thật sự được đọc — cắt từ ảnh gốc khi thắng
        // là phái sinh sẽ lệch hệ toạ độ hộp dòng).
        let winnerImage = winner.image
        let reReader = RegionReReader(qualityMap: qualityMap) { band, upscale in
            guard let crop = cropForROI(winnerImage, band: band,
                                        upscale: upscale),
                  let frags = try? engine.recognize(in: crop,
                                                    region: nil)
            else { return [] }
            return frags.map { OCRLine(text: $0.text,
                                       confidence: $0.confidence) }
        }

        let winLines = winner.assembly.lines.map {
            OCRLine(text: $0.text, confidence: $0.confidence)
        }
        let winBoxes: [CGRect?] = winner.assembly.lines.map { $0.box }
        let outcome = ReadPipeline.run(lines: winLines,
                                       lineBoxes: winBoxes,
                                       qualityMap: qualityMap,
                                       reReader: reReader)

        var diagCandidates: [DiagCandidate] = []
        for (i, run) in runs.enumerated() {
            diagCandidates.append(DiagCandidate(
                kind: run.step.kind,
                transformDesc: run.step.transformDesc,
                gateVerdict: run.gateVerdict,
                scoreComponents: run.scoreComponents,
                scoreTotal: run.scoreTotal,
                winner: i == winnerIndex))
        }

        return finalize(req: req, outcome: outcome,
                        identity: identity, input: input,
                        manifest: engine.manifest,
                        candidates: diagCandidates,
                        qualityMap: qualityMap,
                        fragments: winner.fragments,
                        assembly: winner.assembly,
                        qualityOutcome: qualityOutcome,
                        extraFlags: flags,
                        started: started)
    }

    /// Chạy MỘT ứng viên: engine trên từng trang -> ráp (đa
    /// trang qua assemblePages) -> parse -> dựng CandidateEvaluation.
    private static func runCandidate(step: CandidateStep,
                                     images: [CGImage],
                                     engine: ClassicTextEngine)
        -> CandidateRun? {
        stageBreadcrumb?("ocr-\(step.kind)")
        var fragments: [Fragment] = []
        do {
            for (page, image) in images.enumerated() {
                let frags = try engine.recognize(in: image, region: nil)
                for var f in frags {
                    f.pageIndex = page
                    if images.count > 1 {
                        // id mảnh của engine khởi động lại mỗi
                        // trang: cộng offset trang để id duy nhất
                        // trong toàn hồ sơ (span trỏ đúng mảnh).
                        f.id += page * 100_000
                        // Giản đồ v2 chưa có trường trang: giữ số
                        // trang trong passID để hồ sơ không mất
                        // truy vết trang.
                        f.passID = f.passID + "#p\(page + 1)"
                    }
                    fragments.append(f)
                }
            }
        } catch {
            return nil
        }
        stageBreadcrumb?("candidate-recognize-done")
        let assembly: AssemblyResult
        var stitchStatus: String? = nil
        if images.count > 1 {
            let stitched = LineAssembly.assemblePages(fragments)
            assembly = stitched.result
            stitchStatus = stitched.stitch.status
        } else {
            assembly = LineAssembly.assemble(fragments)
        }
        stageBreadcrumb?("candidate-assemble-done")
        let lines = assembly.lines.map {
            OCRLine(text: $0.text, confidence: $0.confidence)
        }
        let boxes: [CGRect?] = assembly.lines.map { $0.box }
        let parsed = ReceiptParser.parse(lines: lines, boxes: boxes)
        stageBreadcrumb?("candidate-parse-done")
        // V4-1 (quyết định D-V4-2; audit A2-04): QualityMap của
        // CHÍNH ứng viên này khi ứng viên là MỘT ảnh — trước đây
        // CandidateScorer.integrity luôn chạy với bản đồ rỗng nên
        // hạng tử QualityMap trong hàm điểm là mã chết. Cách dựng
        // bản đồ bám đúng đường winner ở dưới (cùng grid + ngưỡng).
        // Đa trang giữ []: hộp dòng thuộc hệ toạ độ ảnh đã ghép,
        // không thuộc ảnh đầu — không bịa bản đồ.
        var candidateQualityMap: [QualityMapEntry] = []
        if images.count == 1, let firstImage = images.first,
           let grid = LuminanceGrid.fromImage(firstImage) {
            let thresholds = QualityThresholds()
            candidateQualityMap = assembly.lines.map {
                grid.qualityMapEntry(for: $0.box, thresholds: thresholds)
            }
        }
        let evaluation = makeEvaluation(parsed: parsed,
                                        assembly: assembly,
                                        isOriginal: step.kind == "original",
                                        qualityMap: candidateQualityMap)
        stageBreadcrumb?("candidate-evaluation-done")
        let scored = CandidateScorer.score(evaluation)
        return CandidateRun(step: step, image: images[0],
                            fragments: fragments, assembly: assembly,
                            parsed: parsed, evaluation: evaluation,
                            scoreTotal: scored.total,
                            scoreComponents: scored.components,
                            stitchStatus: stitchStatus)
    }

    /// CandidateEvaluation từ kết quả F4 của ứng viên (công thức
    /// điểm ở CandidateScorer — hàm này chỉ ĐO các thành phần):
    /// E1 = Σ món khép đúng subtotal; E2 = subtotal + thuế khép
    /// total trong 2¢; E3 = số lượng bán khép theo ngữ nghĩa in
    /// của tiệm (một-dòng-một cho Walmart, cộng qty còn lại).
    private static func makeEvaluation(parsed: ParseResult,
                                       assembly: AssemblyResult,
                                       isOriginal: Bool,
                                       qualityMap: [QualityMapEntry] = [])
        -> CandidateEvaluation {
        var e1 = false
        if let subtotal = parsed.subtotalCents,
           let sum = SafeMoney.sumCents(
               parsed.items.map { $0.amountCents ?? 0 }) {
            e1 = sum == subtotal
        }
        var e2 = false
        if let subtotal = parsed.subtotalCents,
           let total = parsed.totalCents {
            let implied = SafeMoney.checkedAdd(subtotal,
                                               parsed.taxTotalCents)
            e2 = implied.map { abs($0 - total) <= 2 } ?? false
        }
        var e3 = false
        if let sold = parsed.itemsSold {
            let positive = parsed.items.filter {
                ($0.amountCents ?? 0) > 0
            }
            let counted = parsed.soldContribution == "onePerLine"
                ? positive.count
                : positive.reduce(0) { $0 + $1.qty }
            e3 = counted == sold
        }
        let boundary = CandidateScorer.totalsBoundary(assembly.lines)
        let missing = assembly.lines[..<boundary].filter {
            SafeMoney.tokens(in: $0.text).isEmpty && $0.text.count > 2
        }.count
        let alnum = assembly.lines.reduce(0) {
            $0 + $1.text.filter { $0.isLetter || $0.isNumber }.count
        }
        return CandidateEvaluation(
            e1Closed: e1, e2Within2c: e2, e3Closed: e3,
            integrity: CandidateScorer.integrity(assembly.lines,
                                                 qualityMap: qualityMap),
            hasSubtotal: parsed.subtotalCents != nil,
            hasTotal: parsed.totalCents != nil,
            hasTaxLine: !parsed.taxes.isEmpty,
            hasDate: parsed.date != nil,
            vendorResolved: parsed.vendor != nil,
            itemsMissingAmount: missing,
            alnumChars: alnum,
            isOriginal: isOriginal)
    }

    // MARK: - Ứng viên phái sinh (CoreImage + cổng tứ giác)

    /// Ứng viên phối cảnh: phát hiện tứ giác -> QuadGate luật
    /// ĐẦY ĐỦ -> CIPerspectiveCorrection (nới lề ~1,5% theo ghi
    /// chú của bước trong CandidateChain). Trả (ảnh, verdict);
    /// (nil, lý do) khi cổng chặn hoặc không thấy tứ giác.
    private static func perspectiveCandidate(from image: CGImage)
        -> (CGImage?, String?) {
        stageBreadcrumb?("perspective-detect")
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.2
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return (nil, "detect-error")
        }
        guard let obs = request.results?.first else {
            return (nil, "no-quad")
        }
        // Vision trả điểm CHUẨN HOÁ 0..1 (gốc dưới-trái);
        // QuadGate tính theo ĐIỂM ẢNH (hợp đồng của cổng ghi rõ
        // trong CaptureIntake) — phải đổi hệ TRƯỚC khi gọi.
        // L-2026-11-12-12: bản cũ truyền thẳng điểm chuẩn hoá
        // khiến diện tích luôn < 55% khung pixel → ứng viên bị
        // loại 100% trên thiết bị (fail-closed, không crash —
        // lỗi riêng, không trình bày là bản sửa crash).
        let quad = [obs.topLeft, obs.topRight,
                    obs.bottomRight, obs.bottomLeft]
        let pixelQuad = quad.map {
            CGPoint(x: Double($0.x) * Double(image.width),
                    y: Double($0.y) * Double(image.height))
        }
        let verdict = QuadGate.evaluate(quad: pixelQuad,
                                        imageWidth: image.width,
                                        imageHeight: image.height)
        switch verdict {
        case .rejected(let reason):
            return (nil, "rejected:\(reason)")
        case .allowed:
            break
        }
        // Nới lề 1,5%: kéo mỗi đỉnh ra xa tâm tứ giác.
        let cx = quad.reduce(0.0) { $0 + Double($1.x) } / 4
        let cy = quad.reduce(0.0) { $0 + Double($1.y) } / 4
        func px(_ p: CGPoint) -> CGPoint {
            let x = Double(p.x) + (Double(p.x) - cx) * 0.015
            let y = Double(p.y) + (Double(p.y) - cy) * 0.015
            return CGPoint(x: x * Double(image.width),
                           y: y * Double(image.height))
        }
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            return (nil, "filter-missing")
        }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: px(quad[0])),
                        forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: px(quad[1])),
                        forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: px(quad[2])),
                        forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: px(quad[3])),
                        forKey: "inputBottomLeft")
        guard let out = filter.outputImage,
              let cg = ciContext.createCGImage(out, from: out.extent)
        else { return (nil, "render-failed") }
        return (cg, "allowed")
    }

    /// Các biến thể CoreImage toàn khung cho bước shadowRemoved /
    /// enhanced / binarized. Khoá tham số kiểm bằng inputKeys —
    /// thiếu khoá thì bỏ ứng viên (fail-closed), không ép.
    private static func ciVariant(_ image: CGImage, kind: String)
        -> CGImage? {
        stageBreadcrumb?("civariant-\(kind)")
        let ci = CIImage(cgImage: image)
        let filter: CIFilter?
        switch kind {
        case "shadowRemoved":
            // Xoá bóng GIỮ MÀU: nâng vùng tối, không nhị phân hoá.
            filter = CIFilter(name: "CIHighlightShadowAdjust")
            filter?.setValue(ci, forKey: kCIInputImageKey)
            if let f = filter, f.inputKeys.contains("inputShadowAmount") {
                f.setValue(0.8, forKey: "inputShadowAmount")
            }
            if let f = filter, f.inputKeys.contains("inputHighlightAmount") {
                f.setValue(0.0, forKey: "inputHighlightAmount")
            }
        case "enhancedContrast":
            // Đứng thay "tăng cường theo vùng dòng" cho tới phiên
            // đo hiệu chuẩn theo vùng (ghi ở đầu mục này).
            filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ci, forKey: kCIInputImageKey)
            filter?.setValue(1.25, forKey: "inputContrast")
            filter?.setValue(0.03, forKey: "inputBrightness")
            filter?.setValue(0.0, forKey: "inputSaturation")
        case "enhancedDocument":
            filter = CIFilter(name: "CIDocumentEnhancer")
            filter?.setValue(ci, forKey: kCIInputImageKey)
            if let f = filter, f.inputKeys.contains("inputAmount") {
                f.setValue(1.0, forKey: "inputAmount")
            }
        case "binarized":
            filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ci, forKey: kCIInputImageKey)
            filter?.setValue(0.0, forKey: "inputSaturation")
            filter?.setValue(1.6, forKey: "inputContrast")
            filter?.setValue(-0.05, forKey: "inputBrightness")
        default:
            return nil
        }
        guard let out = filter?.outputImage,
              let cg = ciContext.createCGImage(out, from: out.extent)
        else { return nil }
        return cg
    }

    /// Cắt vùng ROI từ ảnh thắng + phóng: band là toạ độ Vision
    /// (gốc dưới-trái, chuẩn hoá) -> hình chữ nhật pixel gốc
    /// TRÊN-trái của CGImage.cropping. Hệ toạ độ này là điểm đo
    /// lật cổ điển của RECONCILE §6 — ca kiểm lật chạy ở phiên
    /// đo thiết bị trước khi ROI được tin (Pha 3 §9).
    private static func cropForROI(_ image: CGImage, band: CGRect,
                                   upscale: Double) -> CGImage? {
        let w = Double(image.width), h = Double(image.height)
        let rect = CGRect(x: Double(band.minX) * w,
                          y: (1.0 - Double(band.maxY)) * h,
                          width: Double(band.width) * w,
                          height: Double(band.height) * h)
            .integral
        guard rect.width >= 2, rect.height >= 2,
              let crop = image.cropping(to: rect) else { return nil }
        guard upscale > 1.05 else { return crop }
        let outW = Int((Double(crop.width) * upscale).rounded())
        let outH = Int((Double(crop.height) * upscale).rounded())
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return crop }
        ctx.interpolationQuality = .high
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        return ctx.makeImage() ?? crop
    }


    // MARK: - Chốt: dựng hồ sơ chẩn đoán + cổng ghi fail-closed

    private static func finalize(req: ReadRequest,
                                 outcome: ReadPipelineOutcome,
                                 identity: DiagIdentity,
                                 input: DiagInput,
                                 manifest: EngineManifest,
                                 candidates: [DiagCandidate],
                                 qualityMap: [QualityMapEntry],
                                 fragments: [Fragment],
                                 assembly: AssemblyResult,
                                 qualityOutcome: QualityOutcome?,
                                 extraFlags: [String],
                                 error: String? = nil,
                                 started: Date) -> ReadOutcome {
        stageBreadcrumb?("finalize")
        let result = outcome.result

        // Provenance mức snapshot (trạng thái cuối F4): chỉ các
        // sửa chữ của DomainCorrector — sửa F5/ROI nằm ở
        // reconcile.fixes + roiRounds, không trộn vào snapshot.
        var snapshotProvenance: [String: FieldProvenance] = [:]
        for correction in outcome.parsedBeforeReconcile.corrections {
            if correction.field == "itemName",
               let index = correction.itemIndex {
                snapshotProvenance["items[\(index)].name"] =
                    .domainCorrected(
                        lexiconVersion: correction.lexiconVersion)
            }
        }
        // CORE-V4 (gói V4-1): provenance khối tổng của trọng tài
        // (chỉ có khi lần đọc đi qua parseV4) vào CÙNG ngăn này —
        // khoá "subtotal"/"tax[i]"/"total" không trùng khoá sửa
        // chữ ở trên; cộng thêm thuần, schema chẩn đoán giữ v2.
        for (key, value) in outcome.parsedBeforeReconcile.totalsProvenance
        where snapshotProvenance[key] == nil {
            snapshotProvenance[key] = value
        }
        // Provenance mức UI = provenance khung (F5/ROI) + corrected.
        var uiProvenance = outcome.provenance
        for (key, value) in snapshotProvenance {
            if uiProvenance[key] == nil { uiProvenance[key] = value }
        }

        var flags = result.warnings
        if outcome.report.requiresReview {
            flags.append("reconcile-needs-review")
        }
        flags.append(contentsOf: extraFlags)

        var diag = ReadDiagnostics(identity: identity, input: input,
                                   config: DiagConfig(
                                       engineManifest: manifest,
                                       tilePolicyID: tilePolicyID,
                                       tileParams: [:],
                                       candidatePolicyID:
                                           CandidateChain.policyID,
                                       readerConfigHash:
                                           ReadDiagnostics.computeConfigHash(
                                               manifest: manifest,
                                               tilePolicyID: tilePolicyID,
                                               candidatePolicyID:
                                                   CandidateChain.policyID)))
        diag.candidates = candidates
        diag.qualityMap = qualityMap
        // qty: ParsedLineItem.qty và DiagItem.qty đều là Int
        // (trọng lượng dòng cân nằm ở weightLb riêng của F4,
        // không vào snapshot — giản đồ v2 không có trường cân).
        diag.parse = DiagParseSnapshot(
            vendor: outcome.parsedBeforeReconcile.vendor,
            vendorKey: outcome.parsedBeforeReconcile.vendorKey,
            vendorSource: outcome.parsedBeforeReconcile.vendorSource,
            vendorDataVersion: outcome.parsedBeforeReconcile.vendorDataVersion,
            dateISO: outcome.parsedBeforeReconcile.date.map {
                iso8601.string(from: $0)
            },
            items: outcome.parsedBeforeReconcile.items.map {
                DiagItem(name: $0.name, qty: $0.qty,
                         unitPriceCents: $0.unitPriceCents,
                         amountCents: $0.amountCents,
                         taxFlag: $0.taxFlag, itemCode: $0.itemCode)
            },
            subtotalCents: outcome.parsedBeforeReconcile.subtotalCents,
            taxes: outcome.parsedBeforeReconcile.taxes.map {
                DiagTaxLine(label: $0.label, rateText: $0.rateText,
                            amountCents: $0.amountCents)
            },
            totalCents: outcome.parsedBeforeReconcile.totalCents,
            itemsSold: outcome.parsedBeforeReconcile.itemsSold,
            cardLast4: outcome.parsedBeforeReconcile.cardLast4,
            cardBrand: outcome.parsedBeforeReconcile.cardBrand,
            warnings: outcome.parsedBeforeReconcile.warnings,
            provenance: snapshotProvenance)
        // regionID: Fragment giữ String?, giản đồ giữ Int? — engine
        // hiện hành không phát regionID (nil) nên ánh xạ mất mát
        // này chưa chạm dữ liệu thật; ghi nhận ở AFTER (P4-D3).
        diag.fragments = fragments.map {
            DiagFragment(id: $0.id, text: $0.text,
                         alternates: $0.alternates,
                         confidence: $0.confidence,
                         box: DiagRect($0.box),
                         passID: $0.passID,
                         tileIndex: $0.tileIndex,
                         regionID: $0.regionID.flatMap { Int($0) })
        }
        diag.assembly = DiagAssembly(
            tileMap: assembly.tileMap,
            blindBands: assembly.blindBands,
            dedupeDropped: assembly.dedupeDropped,
            invariantViolations: assembly.invariantViolations,
            lines: assembly.lines.map {
                DiagLine(text: $0.text, confidence: $0.confidence,
                         box: DiagRect($0.box), spans: $0.spans,
                         passSources: $0.passSources,
                         contested: $0.contested,
                         alternates: $0.alternates)
            })
        diag.corrections = result.corrections
        diag.reconcile = outcome.reconcileSnapshot
        diag.roiRounds = outcome.roiRounds
        diag.outcome = DiagOutcome(
            flags: flags,
            elapsedMs: Int(Date().timeIntervalSince(started) * 1000),
            error: error)

        var out = ReadOutcome(result: result,
                              report: outcome.report,
                              provenance: uiProvenance,
                              diagnostics: diag,
                              qualityOutcome: qualityOutcome,
                              usedROI: outcome.usedROI)
        if let directory = req.diagnosticsDirectory {
            let fin = ReadFinalizer.finalize(out, diagnostics: diag,
                                             directory: directory)
            out = fin.outcome
            out.diagnosticsID = fin.diagnosticsID
            out.diagnosticsWriteFailed = fin.diagnosticsWriteFailed
        } else {
            // N4-FIX (FULL-REVIEW; DESIGN-FINAL §1.5): không có
            // thư mục chẩn đoán = không có bản ghi = lần đọc
            // KHÔNG được mang cờ sạch. Bản cũ bỏ qua hẳn
            // ReadFinalizer mà diagnosticsWriteFailed vẫn false
            // — một đường né cổng fail-closed (chạm được từ
            // ReceiptViews khi imageFileName rỗng). Nay ép cờ
            // hỏng chẩn đoán: ReviewView sẽ giữ tờ ở chờ duyệt.
            out.diagnosticsWriteFailed = true
        }
        return out
    }

    // MARK: - Thông tin môi trường cho identity

    private static func appBuildString() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static func deviceModelString() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self,
                                  capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.isEmpty ? UIDevice.current.model : machine
    }
}

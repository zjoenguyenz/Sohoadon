import Foundation
import CoreGraphics

// MARK: - G1: bộ test logic + vòng đời chạy bằng Swift thật
//
// Chế độ `unittests` của harness (cổng C trong TEAM1-
// VERIFICATION §3, bản macOS theo luật tối ưu chi phí của anh
// 2026-11-15: logic chạy kèm job harness có sẵn; phần giết-app
// thật nằm ở BenchShell tự kiểm trên máy anh — đặc tả ở
// core-expert/G1-BENCH-SELFCHECK-SPEC.md).
//
// Trước G1 toàn project có 0 test target: file test vòng đời
// của P-DRAFT (p-draft/tests/PendingDraftRoundTripTest.swift)
// chưa từng thuộc target nào nên chưa từng chạy. Bộ này là hậu
// duệ của file đó: giữ nguyên các ca vòng đời (đối chiếu lại
// với PendingDraft.swift hiện hành — bản tích hợp KHÔNG còn
// đường ScanDraft/makeDraft ở tầng này nên các ca mã-lạ kiểm ở
// mức DTO toOriginal, là đúng lớp mà PendingDraftStore bảo
// vệ), cộng test cho logic điều kiện thuần vừa tách sang
// ReceiptLogic.swift (khoá L-2026-11-13-17 và L-2026-11-13-20).
//
// KHÔNG dùng XCTest: harness là CLI tool; runAll() trả các
// dòng "UNITTEST PASS/FAIL <tên>" máy-đọc-được, main.swift in
// ra và thoát mã 1 nếu có FAIL — CI grep dòng SURVIVED.

enum HarnessUnitTests {

    static func runAll() -> [String] {
        var lines: [String] = []
        func check(_ name: String, _ ok: Bool) {
            lines.append("UNITTEST \(ok ? "PASS" : "FAIL") \(name)")
        }

        runPendingDraftTests(check)
        runCanReparseTests(check)
        runHasLoadableOriginalTests(check)
        runFlagsTests(check)
        return lines
    }

    // MARK: - Dựng dữ liệu kiểm (bản nháp đầy đủ trường)

    private static func makeSnapshot() -> PendingDraftSnapshot {
        var result = ParseResult()
        result.vendor = "Sam's Club"
        result.vendorKey = "sams"
        result.date = Date(timeIntervalSince1970: 1_791_000_000)
        result.items = [
            ParsedLineItem(name: "COKE 12PK", qty: 2, unitPriceCents: 1948,
                           amountCents: 3896, taxFlag: "A", itemCode: "980012379",
                           weightLb: nil, weightUnitCents: nil, lineIndex: 4),
            ParsedLineItem(name: "BANANA", qty: 1, unitPriceCents: nil,
                           amountCents: 318, taxFlag: nil, itemCode: nil,
                           weightLb: 2.5, weightUnitCents: 127, lineIndex: 9),
        ]
        result.subtotalCents = 4214
        result.taxes = [
            ParsedTaxLine(label: "TAX 1", rateText: "8.5170", amountCents: 359, lineIndex: 20),
            ParsedTaxLine(label: "TAX 2", rateText: "4.0170", amountCents: 25, lineIndex: 21),
        ]
        result.totalCents = 4598
        result.cardLast4 = "2586"
        result.cardBrand = "US DEBIT"
        result.cardConfidence = 0.9
        result.cardLineContaminated = true
        result.dedupeKey = "SAMS-TC-9087"
        result.itemsSold = 3
        result.warnings = ["Sổ chưa khớp"]
        result.vendorConfidence = 0.95
        result.dateConfidence = 0.8
        result.totalConfidence = 0.85
        result.vendorAddress = "123 W Example St"
        result.vendorPhone = "918-555-0100"
        result.storeNumber = "2427"
        result.vendorSource = "tier2-anchor"
        result.vendorSuggestion = nil
        result.vendorAnchorDisputed = true
        result.rawText = "SAM'S CLUB\nCOKE 12PK 38.96"
        result.selectionTrace = ["anchor:subtotal@18"]
        result.totalCandidates = [
            TotalCandidate(lineIndex: 18, cents: 4214, role: "subtotal", chosen: true),
            TotalCandidate(lineIndex: 22, cents: 4598, role: "total", chosen: true),
        ]
        result.totalsProvenance = [
            "total": FieldProvenance(kind: "read", detail: "closureUnique"),
        ]
        result.itemsProvenance = [
            "item[0]": FieldProvenance(kind: "read", detail: "sameLine"),
        ]
        result.arbiterStatus = "closed"
        result.arbiterDisputed = []
        result.arbiterDeficitE1 = 0
        result.arbiterDeficitE2 = 0
        result.geometricCandidates = [result.items[1]]
        result.itemsSoldLabelSeen = true
        result.soldContribution = "byQuantity"
        result.vendorDataVersion = "2026-11-01"

        var fix = ReconcileFix(itemIndex: 1, field: .insert, oldValue: nil,
                               newValue: 318, delta: 318, channel: .orphan, tier: 2)
        fix.insertName = "BANANA"
        fix.insertQty = 1
        fix.insertUnitCents = 318
        fix.insertCode = "123456"
        fix.evidence = "line 9: BANANA 3.18"
        var report = ReconcileReport()
        report.status = .repaired
        report.moneyDeltaCents = 0
        report.qtyDelta = 1
        report.fixes = [fix]
        report.suggestions = [[ReconcileFix(itemIndex: 0, field: .amount, oldValue: 3896,
                                            newValue: 3986, delta: 90, channel: .digit, tier: 3)]]
        report.solutionCount = 1
        var hint = ReconcileRegionHint(block: .items, reason: .qtyMismatch)
        hint.priority = 1
        hint.deltaCents = 318
        hint.lineRange = 4...9
        hint.band = CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.3)
        report.regionHints = [hint]
        report.notes = ["đã áp 1 sửa ORPHAN"]
        report.nodesVisited = 42
        report.taxMissing = false
        report.impliedTaxCents = 384
        report.anchorsPresent = ["subtotal", "total"]
        report.anchorsMissing = []
        report.requiresReview = true

        return PendingDraftSnapshot(
            result: result,
            imageFileName: "TEST-IMG.jpg",
            sourceTypeRaw: "camera",
            sourceFileName: nil,
            originalFileNames: ["TEST-IMG.jpg", "TEST-IMG-2.jpg"],
            rawTextIsPDFTextLayer: false,
            provenance: ["total": FieldProvenance(kind: "read", detail: "closureUnique")],
            reconcileReport: report,
            diagnosticsID: "diag-test-001",
            diagnosticsWriteFailed: true,
            createdAt: Date(timeIntervalSince1970: 1_791_000_100))
    }

    // MARK: - A. PendingDraftStore: vòng đời bản chụp nháp

    private static func runPendingDraftTests(_ check: (String, Bool) -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HarnessUnitTests-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            check("PD00-dung-thu-muc-kiem", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshot = makeSnapshot()
        let fileURL = PendingDraftStore.fileURL(in: dir)

        // Thư mục trống: load == nil (ca thường, không phải lỗi).
        check("PD01-load-khi-chua-co-file-nil", PendingDraftStore.load(in: dir) == nil)

        // Vòng Codable thuần: encode -> decode -> bằng nhau.
        if let data = try? JSONEncoder().encode(snapshot),
           let back = try? JSONDecoder().decode(PendingDraftSnapshot.self, from: data) {
            check("PD02-codable-roundtrip-bang-nhau", back == snapshot)
        } else {
            check("PD02-codable-roundtrip-bang-nhau", false)
        }

        // Vòng qua đĩa: save -> load khớp (Equatable của snapshot
        // + DTO là so TỪNG TRƯỜNG đệ quy; thêm chốt điểm danh
        // các trường chính để khi đỏ biết ngay trường nào lệch).
        check("PD03-save-tra-true", PendingDraftStore.save(snapshot, in: dir))
        let tmpLeft = FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(PendingDraftStore.fileName + ".tmp").path)
        check("PD04-save-khong-de-file-tmp", !tmpLeft)
        let loaded = PendingDraftStore.load(in: dir)
        check("PD05-load-bang-snapshot-tung-truong", loaded == snapshot)
        check("PD06-truong-imageFileName", loaded?.imageFileName == "TEST-IMG.jpg")
        check("PD07-truong-vendor", loaded?.result.vendor == "Sam's Club")
        check("PD08-truong-totalCents", loaded?.result.totalCents == 4598)
        check("PD09-truong-items",
              loaded?.result.items.count == 2 && loaded?.result.items[0].amountCents == 3896)
        check("PD10-truong-taxes",
              loaded?.result.taxes.count == 2 && loaded?.result.taxes[0].amountCents == 359)
        check("PD11-truong-report-statusRaw", loaded?.reconcileReport?.statusRaw == "REPAIRED")
        check("PD12-truong-diagnosticsID", loaded?.diagnosticsID == "diag-test-001")

        // Dựng lại kiểu gốc từ DTO đã nạp: toàn-hay-không.
        if let restored = loaded?.result.toOriginal() {
            check("PD13-dto-restore-parseresult",
                  restored.vendor == "Sam's Club" && restored.totalCents == 4598
                    && restored.itemsSold == 3 && restored.items.count == 2)
        } else {
            check("PD13-dto-restore-parseresult", false)
        }
        if let restoredReport = loaded?.reconcileReport?.toOriginal() {
            check("PD14-dto-restore-report",
                  restoredReport.status == .repaired && restoredReport.fixes.count == 1
                    && restoredReport.regionHints.count == 1)
        } else {
            check("PD14-dto-restore-report", false)
        }

        // Ghi đè: bản mới thắng.
        var newer = snapshot
        newer.imageFileName = "TEST-IMG-MOI.jpg"
        check("PD15-save-lan-2-tra-true", PendingDraftStore.save(newer, in: dir))
        check("PD16-ghi-de-ban-moi-thang", PendingDraftStore.load(in: dir) == newer)

        // Xoá: load -> nil; xoá lần nữa không crash.
        PendingDraftStore.clear(in: dir)
        check("PD17-load-sau-clear-nil", PendingDraftStore.load(in: dir) == nil)
        PendingDraftStore.clear(in: dir)
        check("PD18-clear-lan-2-khong-crash", true)

        // File hỏng: load nil + file bị xoá + có dòng log chẩn đoán.
        _ = PendingDraftStore.save(snapshot, in: dir)
        try? Data("đây không phải JSON {{{".utf8).write(to: fileURL)
        check("PD19-load-file-hong-nil", PendingDraftStore.load(in: dir) == nil)
        check("PD20-file-hong-bi-xoa", !FileManager.default.fileExists(atPath: fileURL.path))
        let logText = (try? String(contentsOf: dir.appendingPathComponent(PendingDraftStore.logFileName),
                                   encoding: .utf8)) ?? ""
        check("PD21-log-ghi-ban-hong", logText.contains("Snapshot nháp hỏng"))

        // Schema lạ: load nil + file bị xoá.
        _ = PendingDraftStore.save(snapshot, in: dir)
        if let data = try? Data(contentsOf: fileURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json["schemaVersion"] = 99
            if let edited = try? JSONSerialization.data(withJSONObject: json) {
                try? edited.write(to: fileURL)
            }
        }
        check("PD22-load-schema-la-nil", PendingDraftStore.load(in: dir) == nil)
        check("PD23-file-schema-la-bi-xoa", !FileManager.default.fileExists(atPath: fileURL.path))

        // Mã enum lạ ở tầng DTO: dựng lại phải trả nil TOÀN PHẦN
        // (kỷ luật toàn-hay-không của PendingDraft.swift — bản
        // chụp của phiên bản khác không được dựng nửa vời). Đây
        // là lớp tương đương hai ca makeDraft của bộ test cũ:
        // makeDraft sống ở ScanView (tầng UI) nên ngoài harness;
        // hợp đồng nó dựa vào chính là toOriginal ở đây.
        if var alienReport = snapshot.reconcileReport {
            alienReport.fixes[0].channelRaw = "KENH_KHONG_TON_TAI"
            check("PD24-ma-kenh-la-report-nil", alienReport.toOriginal() == nil)
        } else {
            check("PD24-ma-kenh-la-report-nil", false)
        }
        if var alienStatus = snapshot.reconcileReport {
            alienStatus.statusRaw = "TRANG_THAI_LA"
            check("PD25-ma-trang-thai-la-report-nil", alienStatus.toOriginal() == nil)
        } else {
            check("PD25-ma-trang-thai-la-report-nil", false)
        }
    }

    // MARK: - B. canReparse (khoá L-2026-11-13-17)

    private static func runCanReparseTests(_ check: (String, Bool) -> Void) {
        // Còn văn bản đã lưu -> bấm được. Điều kiện thuần chỉ
        // còn phụ thuộc văn bản (không tem, không trạng thái) —
        // ba ca này khoá đúng hợp đồng đó.
        check("CR01-co-van-ban-true",
              ReceiptLogic.canReparse(ocrRawText: "SAM'S CLUB\nCOKE 19.48"))
        check("CR02-rong-false",
              !ReceiptLogic.canReparse(ocrRawText: ""))
        // Nguyên văn !isEmpty: chuỗi chỉ xuống dòng VẪN là còn
        // văn bản (không cắt trắng — giữ hành vi trước tách).
        check("CR03-chi-xuong-dong-true",
              ReceiptLogic.canReparse(ocrRawText: "\n"))
    }

    // MARK: - C. hasLoadableOriginal (IMGFIX)

    private static func runHasLoadableOriginalTests(_ check: (String, Bool) -> Void) {
        check("IM01-danh-sach-rong-false",
              !ReceiptLogic.hasLoadableOriginal(fileNames: [], isLoadable: { _ in true }))
        check("IM02-khong-file-nao-tai-duoc-false",
              !ReceiptLogic.hasLoadableOriginal(fileNames: ["a.jpg", "b.jpg"],
                                                isLoadable: { _ in false }))
        check("IM03-file-thu-hai-tai-duoc-true",
              ReceiptLogic.hasLoadableOriginal(fileNames: ["a.jpg", "b.jpg"],
                                               isLoadable: { $0 == "b.jpg" }))
        check("IM04-file-dau-tai-duoc-true",
              ReceiptLogic.hasLoadableOriginal(fileNames: ["a.jpg"],
                                               isLoadable: { _ in true }))
    }

    // MARK: - D. ReceiptLogic.flags (khoá L-2026-11-13-20 + IMGFIX)

    private static func flagInput(
        subtotal: Int? = 4214,
        items: [Int?] = [3896, 318],
        total: Int? = 4598,
        tax: Int? = 384,
        kind: ReceiptKindTag = .business,
        purpose: String = "Mua cho khách trong tiệm",
        hasImage: Bool = true
    ) -> ReceiptFlagInput {
        ReceiptFlagInput(subtotalCents: subtotal, itemAmountCents: items,
                         totalCents: total, taxCents: tax, kind: kind,
                         businessPurpose: purpose, hasOriginalImage: hasImage)
    }

    private static func runFlagsTests(_ check: (String, Bool) -> Void) {
        // Tờ sạch hoàn toàn -> không cờ nào.
        check("FL01-to-sach-khong-co",
              ReceiptLogic.flags(for: flagInput()) == [])
        // Business + mục đích rỗng -> đúng một cờ mục đích.
        check("FL02-business-thieu-muc-dich",
              ReceiptLogic.flags(for: flagInput(purpose: ""))
                == [missingPurposeFlagText])
        // Mục đích chỉ toàn khoảng trắng vẫn tính là thiếu
        // (bản gốc cắt .whitespaces trước khi so rỗng).
        check("FL03-muc-dich-toan-khoang-trang",
              ReceiptLogic.flags(for: flagInput(purpose: "   "))
                .contains(missingPurposeFlagText))
        // Đã có mục đích -> cờ mục đích tắt kể cả khi cờ khác còn.
        check("FL04-co-muc-dich-chi-con-co-anh",
              ReceiptLogic.flags(for: flagInput(hasImage: false))
                == [missingOriginalImageFlagText])
        // Cá nhân + mục đích rỗng -> KHÔNG cờ mục đích.
        check("FL05-ca-nhan-khong-co-muc-dich",
              ReceiptLogic.flags(for: flagInput(kind: .personal, purpose: "")) == [])
        // Chưa rõ -> cờ chưa phân loại, không cờ mục đích.
        check("FL06-chua-ro-chi-co-phan-loai",
              ReceiptLogic.flags(for: flagInput(kind: .unknown, purpose: ""))
                == ["Chưa phân loại Cá nhân / Business"])
        // Thiếu tổng tiền.
        check("FL07-thieu-tong-tien",
              ReceiptLogic.flags(for: flagInput(total: nil))
                .contains("Thiếu tổng tiền"))
        // Subtotal + thuế lệch tổng 3 xu -> cờ; lệch đúng 2 xu
        // (trong dung sai) -> không cờ.
        check("FL08-lech-tong-3-xu-co",
              ReceiptLogic.flags(for: flagInput(total: 4601))
                .contains("Subtotal + thuế khác tổng tiền"))
        check("FL09-lech-tong-2-xu-khong-co",
              !ReceiptLogic.flags(for: flagInput(total: 4600))
                .contains("Subtotal + thuế khác tổng tiền"))
        // taxCents nil được tính là 0 (nguyên văn bản gốc).
        check("FL10-thue-nil-tinh-0",
              ReceiptLogic.flags(for: flagInput(total: 4214, tax: nil)) == [])
        // Σ món lệch subtotal: 3 xu -> cờ kèm đúng số đã định
        // dạng; đúng 2 xu -> không cờ.
        check("FL11-lech-mon-3-xu-co-dung-chu",
              ReceiptLogic.flags(for: flagInput(items: [3896, 315]))
                .contains("Tổng các món ($42.11) khác subtotal ($42.14)"))
        check("FL12-lech-mon-2-xu-khong-co",
              ReceiptLogic.flags(for: flagInput(items: [3896, 316])) == [])
        // Không có dòng món -> không cờ món dù có subtotal.
        check("FL13-khong-mon-khong-co-mon",
              ReceiptLogic.flags(for: flagInput(items: [])) == [])
        // Dòng món không có tiền tính 0 vào Σ.
        check("FL14-mon-nil-tinh-0",
              ReceiptLogic.flags(for: flagInput(items: [3896, nil]))
                .contains("Tổng các món ($38.96) khác subtotal ($42.14)"))
        // Thứ tự cờ khoá cứng: món -> mục đích -> ảnh gốc.
        check("FL15-thu-tu-co",
              ReceiptLogic.flags(for: flagInput(subtotal: 500, items: [100],
                                                total: 500, tax: 0,
                                                purpose: "", hasImage: false))
                == ["Tổng các món ($1.00) khác subtotal ($5.00)",
                    missingPurposeFlagText,
                    missingOriginalImageFlagText])
    }
}

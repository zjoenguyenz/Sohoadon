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
        runPendingBlockTests(check)
        runReviewEditsTests(check)
        runCanReparseTests(check)
        runHasLoadableOriginalTests(check)
        runFlagsTests(check)
        runVariantRescueTests(check)
        return lines
    }

    // MARK: - G2: tầng cứu bằng hồ alternate (DESIGN-V4 §2.6)
    //
    // Các ca tổng hợp chạy qua ĐÚNG đường đọc của app
    // (ReceiptParser.parseV4 trên OCRLine có alternates) —
    // kiểm luật cứu: biến thể chỉ thắng khi làm đẳng thức
    // khép mà giá trị chính không khép được; không alternate
    // thì kết quả y hệt đường cũ; hai bản đọc của cùng một
    // token in không bao giờ cộng vào nhau.

    private static func vline(_ text: String,
                              alts: [String] = []) -> OCRLine {
        OCRLine(text: text, confidence: 0.9,
                alternates: alts.map { AltText(text: $0, confidence: 0.8) })
    }

    private static func runVariantRescueTests(
        _ check: (String, Bool) -> Void) {

        // VT01 — ví dụ §3.9 (ca L-R08): thuế in 1.23, bản đọc
        // thay thế 13.23 → tập thuế {133, 1323} khép duy nhất,
        // dòng thuế thứ hai mang provenance closureVariant.
        let vt01 = ReceiptParser.parseV4(lines: [
            vline("STORE A"),
            vline("SUBTOTAL 155.64"),
            vline("TAX 1.33"),
            vline("TAX 1.23", alts: ["TAX 13.23"]),
            vline("TOTAL 170.20"),
        ])
        check("VT01-status-closed", vt01.arbiterStatus == "closed")
        check("VT01-taxes", vt01.taxes.map { $0.amountCents } == [133, 1323])
        check("VT01-prov", vt01.totalsProvenance["tax[1]"]?.detail == "closureVariant")
        check("VT01-total", vt01.totalCents == 17020)

        // VT02 — cùng tờ, KHÔNG alternate: hồ chính không
        // khép → unclosed, thuế đọc tốt nhất giữ nguyên in.
        let vt02 = ReceiptParser.parseV4(lines: [
            vline("STORE A"),
            vline("SUBTOTAL 155.64"),
            vline("TAX 1.33"),
            vline("TAX 1.23"),
            vline("TOTAL 170.20"),
        ])
        check("VT02-status-unclosed", vt02.arbiterStatus == "unclosed")
        check("VT02-taxes-primary", vt02.taxes.map { $0.amountCents } == [133, 123])

        // VT03 — hồ chính ĐÃ khép: biến thể lạ không được
        // lật kết quả (cứu chỉ chạy khi 0 nghiệm).
        let vt03 = ReceiptParser.parseV4(lines: [
            vline("STORE A"),
            vline("SUBTOTAL 56.75", alts: ["SUBTOTAL 99.99"]),
            vline("TAX 2.28"),
            vline("TOTAL 59.03"),
        ])
        check("VT03-closed-primary", vt03.arbiterStatus == "closed"
              && vt03.subtotalCents == 5675 && vt03.totalCents == 5903)

        // VT04 — hồ biến thể cho HAI nghiệm khác giá trị:
        // mơ hồ ở tầng cứu → từ chối, kết cục chính đứng
        // nguyên (unclosed, thuế tốt nhất = mọi dòng thuế in).
        let vt04 = ReceiptParser.parseV4(lines: [
            vline("STORE A"),
            vline("SUBTOTAL 100.00"),
            vline("TAX 5.00", alts: ["TAX 20.00"]),
            vline("TAX 8.00"),
            vline("TAX 9.00", alts: ["TAX 12.00"]),
            vline("TOTAL 120.00"),
        ])
        check("VT04-ambiguous-rescue-refused",
              vt04.arbiterStatus == "unclosed"
              && vt04.taxes.map { $0.amountCents } == [500, 800, 900])

        // VT05 — mẫu D-18: món gãy "19.9Z", alternate chứa
        // token dính "1280219.97" → biến thể hậu tố 1997 khép
        // E1, provenance closureVariant.
        let vt05 = ReceiptParser.parseV4(lines: [
            vline("ITEM ONE 6.98"),
            vline("HARDWD FLOOR CLEANER 19.9Z",
                  alts: ["HARDWD FLOOR CLEANER 1280219.97"]),
            vline("ITEM THREE 69.96"),
            vline("SUBTOTAL 96.91"),
            vline("SALES TAX 8.25"),
            vline("TOTAL 105.16"),
        ])
        check("VT05-items-closed", vt05.items.count == 3
              && vt05.items[1].amountCents == 1997
              && vt05.arbiterDeficitE1 == 0)
        check("VT05-prov", vt05.itemsProvenance["item[1]"]?.detail == "closureVariant")

        // VT06 — mẫu L-R05: biến thể khá hơn nhưng KHÔNG khép
        // E1 → bị từ chối, số in đứng nguyên.
        let vt06 = ReceiptParser.parseV4(lines: [
            vline("ITEM A 2.19"),
            vline("PATTY 0.29", alts: ["PATTY 6.29"]),
            vline("ITEM B 9.19"),
            vline("SUBTOTAL 20.00"),
            vline("TAX 0.50"),
            vline("TOTAL 20.50"),
        ])
        check("VT06-variant-refused", vt06.items.count == 3
              && vt06.items[1].amountCents == 29
              && vt06.arbiterDeficitE1 == 1167 - 2000)

        // VT07 — mẫu D-17: dòng TOTAL in gãy không token,
        // alternate của chính dòng đó mang 105.16 → tổng chốt
        // bằng closureVariant, sổ khép.
        let vt07 = ReceiptParser.parseV4(lines: [
            vline("SUBTOTAL 96.91"),
            vline("SALES TAX 8.25"),
            vline("TOTAL $105.1G", alts: ["TOTAL 105.16"]),
        ])
        check("VT07-total-rescued", vt07.arbiterStatus == "closed"
              && vt07.totalCents == 10516
              && vt07.totalsProvenance["total"]?.detail == "closureVariant")

        // VT08 — nhóm xung đột: 1.23 và bản thay thế 13.23
        // của nó KHÔNG được cộng nhau (123 + 1323 = 1446
        // đúng bằng thiếu hụt giả) — hai bản đọc của cùng
        // một token in không phải hai dòng thuế.
        let vt08 = ReceiptParser.parseV4(lines: [
            vline("STORE A"),
            vline("SUBTOTAL 100.00"),
            vline("TAX 1.23", alts: ["TAX 13.23"]),
            vline("TOTAL 114.46"),
        ])
        check("VT08-same-token-not-summed", vt08.arbiterStatus == "unclosed")
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

    // MARK: - A2. PendingBlockStore: vòng đời bản chụp bị chặn (G3)
    //
    // Vá sự cố thật 2026-11-15: tờ bị cổng phán .block thoát
    // app là mất. Bộ này khoá hợp đồng của kho mới ở mức THUẦN
    // tách được: round-trip từng trường (bản nháp lồng + kết
    // quả cổng), hỏng -> nil + tự xoá + log, schema lạ -> nil,
    // mã quyết định lạ -> qualityOutcome() nil (dựng lại
    // toàn-hay-không). Phần giết-app thật + khung chặn hiện
    // lại thuộc Gate D trên máy anh (đặc tả G1 §ma trận vòng
    // đời, ca trạng thái bị chặn) — CI không bao phủ.

    private static func makeBlockSnapshot() -> PendingBlockSnapshot {
        let outcome = QualityOutcome(detected: ["blur", "glare"],
                                     decision: .block,
                                     failSafe: false,
                                     consecutiveRejects: 1)
        return PendingBlockSnapshot(
            draftSnapshot: makeSnapshot(),
            quality: outcome,
            createdAt: Date(timeIntervalSince1970: 1_791_000_200))
    }

    private static func runPendingBlockTests(_ check: (String, Bool) -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HarnessUnitTests-Block-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            check("PB00-dung-thu-muc-kiem", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshot = makeBlockSnapshot()
        let fileURL = PendingBlockStore.fileURL(in: dir)

        check("PB01-load-khi-chua-co-file-nil", PendingBlockStore.load(in: dir) == nil)

        if let data = try? JSONEncoder().encode(snapshot),
           let back = try? JSONDecoder().decode(PendingBlockSnapshot.self, from: data) {
            check("PB02-codable-roundtrip-bang-nhau", back == snapshot)
        } else {
            check("PB02-codable-roundtrip-bang-nhau", false)
        }

        check("PB03-save-tra-true", PendingBlockStore.save(snapshot, in: dir))
        let tmpLeft = FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(PendingBlockStore.fileName + ".tmp").path)
        check("PB04-save-khong-de-file-tmp", !tmpLeft)
        let loaded = PendingBlockStore.load(in: dir)
        check("PB05-load-bang-snapshot-tung-truong", loaded == snapshot)
        check("PB06-truong-quality-detected", loaded?.quality.detected == ["blur", "glare"])
        check("PB07-truong-quality-decisionRaw", loaded?.quality.decisionRaw == "block")
        check("PB08-truong-nhap-long",
              loaded?.draft.imageFileName == "TEST-IMG.jpg"
                && loaded?.draft.result.totalCents == 4598)

        // Dựng lại kết quả cổng ở mức thuần: quyết định + các
        // trường nguyên thuỷ khớp nguyên văn.
        if let outcome = loaded?.qualityOutcome() {
            check("PB09-restore-quality-outcome",
                  outcome.decision == .block && outcome.detected == ["blur", "glare"]
                    && outcome.failSafe == false && outcome.consecutiveRejects == 1)
        } else {
            check("PB09-restore-quality-outcome", false)
        }

        // Ghi đè: bản mới thắng.
        var newer = snapshot
        newer.quality = QualityOutcomeDTO(QualityOutcome(
            detected: ["lowContrast"], decision: .block,
            failSafe: false, consecutiveRejects: 2))
        check("PB10-save-lan-2-tra-true", PendingBlockStore.save(newer, in: dir))
        check("PB11-ghi-de-ban-moi-thang", PendingBlockStore.load(in: dir) == newer)

        // Xoá: load -> nil; xoá lần nữa không crash.
        PendingBlockStore.clear(in: dir)
        check("PB12-load-sau-clear-nil", PendingBlockStore.load(in: dir) == nil)
        PendingBlockStore.clear(in: dir)
        check("PB13-clear-lan-2-khong-crash", true)

        // File hỏng: load nil + file bị xoá + có dòng log.
        _ = PendingBlockStore.save(snapshot, in: dir)
        try? Data("không phải JSON {{{".utf8).write(to: fileURL)
        check("PB14-load-file-hong-nil", PendingBlockStore.load(in: dir) == nil)
        check("PB15-file-hong-bi-xoa", !FileManager.default.fileExists(atPath: fileURL.path))
        let logText = (try? String(contentsOf: dir.appendingPathComponent(PendingBlockStore.logFileName),
                                   encoding: .utf8)) ?? ""
        check("PB16-log-ghi-ban-hong", logText.contains("Snapshot bị chặn hỏng"))

        // Schema lạ: load nil + file bị xoá.
        _ = PendingBlockStore.save(snapshot, in: dir)
        if let data = try? Data(contentsOf: fileURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json["schemaVersion"] = 99
            if let edited = try? JSONSerialization.data(withJSONObject: json) {
                try? edited.write(to: fileURL)
            }
        }
        check("PB17-load-schema-la-nil", PendingBlockStore.load(in: dir) == nil)
        check("PB18-file-schema-la-bi-xoa", !FileManager.default.fileExists(atPath: fileURL.path))

        // Mã quyết định lạ: DTO vẫn giải mã được (nó chỉ là
        // chuỗi) nhưng dựng lại kết quả cổng phải trả nil —
        // quyết định chặn sai nghĩa còn tệ hơn mất bản chụp.
        var alien = snapshot
        alien.quality.decisionRaw = "CHAN_KHONG_TON_TAI"
        check("PB19-ma-quyet-dinh-la-outcome-nil", alien.qualityOutcome() == nil)
    }

    // MARK: - A3. Lớp sửa dở Kiểm Lại trong bản chụp nháp (G3)
    //
    // Khoá ba hợp đồng: (1) bản chụp KHÔNG lớp sửa (mặc định)
    // round-trip với reviewEdits == nil; (2) bản chụp CÓ lớp
    // sửa round-trip khớp từng trường của lớp phủ; (3) TƯƠNG
    // THÍCH NGƯỢC v1: file schema 1 không có khoá reviewEdits
    // (đúng định dạng bản 106 đang chạy trên máy anh) vẫn nạp
    // được; schema trên trần hiện hành (3) bị từ chối + xoá.

    private static func runReviewEditsTests(_ check: (String, Bool) -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HarnessUnitTests-Edits-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            check("RE00-dung-thu-muc-kiem", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: dir) }

        let base = makeSnapshot()
        let fileURL = PendingDraftStore.fileURL(in: dir)

        // (1) Mặc định: không lớp sửa.
        check("RE01-mac-dinh-khong-lop-sua", base.reviewEdits == nil)
        check("RE02-save-ban-thuong", PendingDraftStore.save(base, in: dir))
        check("RE03-load-ban-thuong-reviewEdits-nil",
              PendingDraftStore.load(in: dir)?.reviewEdits == nil)

        // (2) Có lớp sửa: khớp toàn bộ + chốt các trường chính.
        var edited = base
        edited.reviewEdits = ReviewEditsDTO(
            vendorText: "Sam's Club Tulsa",
            dateValue: Date(timeIntervalSince1970: 1_791_050_000),
            subtotalText: "42.14", taxText: "3.84", totalText: "45.98",
            kindRaw: "business", category: "Vật Tư",
            purposeText: "Mua cho khách trong tiệm",
            reasonText: "Theo thẻ •• 2586", suggestionApplied: true)
        check("RE04-save-ban-co-lop-sua", PendingDraftStore.save(edited, in: dir))
        let loadedEdited = PendingDraftStore.load(in: dir)
        check("RE05-load-bang-tung-truong", loadedEdited == edited)
        check("RE06-truong-vendorText", loadedEdited?.reviewEdits?.vendorText == "Sam's Club Tulsa")
        check("RE07-truong-kindRaw", loadedEdited?.reviewEdits?.kindRaw == "business")
        check("RE08-truong-purposeText",
              loadedEdited?.reviewEdits?.purposeText == "Mua cho khách trong tiệm")
        check("RE09-truong-suggestionApplied",
              loadedEdited?.reviewEdits?.suggestionApplied == true)

        // (3) Tương thích ngược v1: gỡ khoá reviewEdits + hạ
        // schemaVersion về 1 -> vẫn nạp, lớp sửa nil, phần còn
        // lại nguyên vẹn.
        if let data = try? Data(contentsOf: fileURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json["schemaVersion"] = 1
            json.removeValue(forKey: "reviewEdits")
            if let v1Data = try? JSONSerialization.data(withJSONObject: json) {
                try? v1Data.write(to: fileURL)
            }
        }
        let loadedV1 = PendingDraftStore.load(in: dir)
        check("RE10-file-v1-van-nap-duoc",
              loadedV1 != nil && loadedV1?.reviewEdits == nil
                && loadedV1?.result.totalCents == 4598)

        // Schema trên trần (3): từ chối + xoá như mã lạ.
        if let data = try? Data(contentsOf: fileURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json["schemaVersion"] = 3
            if let v3Data = try? JSONSerialization.data(withJSONObject: json) {
                try? v3Data.write(to: fileURL)
            }
        }
        check("RE11-schema-3-bi-tu-choi", PendingDraftStore.load(in: dir) == nil)
        check("RE12-file-schema-3-bi-xoa", !FileManager.default.fileExists(atPath: fileURL.path))
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

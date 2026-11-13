import Foundation
import CoreGraphics
import ImageIO
import Vision

// MARK: - SoHoaDonHarness — driver tự chạy cốt lõi đọc (CI macOS)
//
// Thi hành LUẬT 2026-11-12 của anh: Muse TỰ CHẠY đường đọc
// Swift THẬT (engine Vision -> ráp dòng -> parse -> chấm) trên
// hạ tầng của mình, tối thiểu 100 lượt liên tiếp thành công,
// trước khi bất kỳ bản nào tới tay anh test.
//
// Driver biên dịch NGUYÊN VĂN các file nguồn app sau vào cùng
// module (xem project-harness.yml): Money, ReadDiagnostics,
// CaptureIntake, OCREngine, LineAssembly, VendorData, Parser,
// Reconcile, RegionReReader. KHÔNG file nào bị sửa để vào đây;
// điểm nối duy nhất là HarnessShims.swift (biểu tượng
// ReceiptReader.stageBreadcrumb của ReadPipeline — file đó
// thuộc tầng UIKit, ngoài phạm vi harness).
//
// Chế độ:
//   probe
//       In ngôn ngữ engine hỗ trợ trên máy chạy (Rev3) + phiên
//       bản dữ liệu vendors/lexicon đã nạp. Harness CHỈ có giá
//       trị khi dataVersion != "unloaded".
//   images --dir DIR [--lang current|old|enus] [--topk 1|3]
//          [--sets N] [--dump DIR]
//       Chạy toàn bộ ảnh .jpg trong DIR qua đường đọc thật.
//       Mặc định --lang old --topk 1 = đúng mặc định BenchShell
//       run #46 (cấu hình "đã chứng minh"); --lang current
//       --topk 3 = cấu hình run #45. Mỗi ảnh in: điều tra hộp
//       (bao nhiêu hộp không-hữu-hạn — đầu mối ứng viên A của
//       HARNESS-REPRO) + tóm tắt parse + E1/E2. --dump ghi
//       luồng mảnh + dòng ráp + kết quả từng ảnh ra JSON.
//   fixture FILE [--nobox]
//       Parse luồng ĐÃ GHI trong fixture JSON (ca kiểm chứng:
//       luồng L-R01 của engine cũ — audit đã minh oan; harness
//       phải tái xác nhận bằng Swift thật: SURVIVED).
//   fuzz FIXTURE --list | fuzz FIXTURE <id>
//       Bẫy đột biến trên luồng fixture: MỖI đột biến chạy như
//       MỘT process riêng (CI lặp lời gọi) để trap không giết
//       driver. In "SURVIVED <id>" ở cuối nếu parse trở về.
//
// Mọi chế độ chạm parse đều in dòng cuối "SURVIVED ..." — CI
// grep dòng này; thiếu nó + mã thoát/signal != 0 = tái hiện.

// stdout KHÔNG đệm: print() qua pipe mặc định bị đệm theo khối —
// process chết vì trap thì mọi dòng đã in mà chưa xả đều MẤT
// (bài học run #5: cổng control chết lặng không một dòng log).
// Mọi mốc giai đoạn phải chạm được log kể cả khi process chết.
setvbuf(stdout, nil, _IONBF, 0)

// Bẫy tín hiệu TỰ CHẨN ĐOÁN (run #13: macOS không để lại .ips nào
// cho process CLI trên runner CI — thư mục crashreports rỗng).
// Handler in số tín hiệu + ngăn xếp lời gọi ra stderr (không đệm)
// rồi thoát 128+sig, để log CI tự nói chết vì gì và chết ở đâu.
for sig in [SIGILL, SIGSEGV, SIGTRAP, SIGABRT, SIGBUS] {
    signal(sig, { s in
        let head = "HARNESS-SIGNAL sig=\(s)\n"
        FileHandle.standardError.write(Data(head.utf8))
        let stack = Thread.callStackSymbols.joined(separator: "\n") + "\n"
        FileHandle.standardError.write(Data(stack.utf8))
        _exit(128 + s)
    })
}

let args = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write(Data("HARNESS-ERROR: \(msg)\n".utf8))
    exit(code)
}

func argValue(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}
func hasFlag(_ name: String) -> Bool { args.contains(name) }

// MARK: - Cấu hình engine (gương công tắc BenchShell CI-FIX-7)

func applyEngineConfig() {
    switch argValue("--lang") ?? "old" {
    case "old":
        LanguagePolicy.directLanguagesOverride = ["vi-VN", "en-US"]
    case "enus":
        LanguagePolicy.directLanguagesOverride = ["en-US"]
    case "current":
        LanguagePolicy.directLanguagesOverride = nil
    default:
        fail("--lang phải là current|old|enus")
    }
    switch argValue("--topk") ?? "1" {
    case "1": ClassicTextEngine.topCandidates = 1
    case "3": ClassicTextEngine.topCandidates = 3
    default: fail("--topk phải là 1|3")
    }
    ReceiptReader.stageBreadcrumb = { step in
        print("  [stage] \(step)")
    }
}

func requireDataLoaded() {
    // Harness im lặng mà mất dữ liệu = đo sai mà không biết:
    // VendorData rỗng thì identifyVendor rơi generic toàn bộ,
    // DomainCorrector trơ — kết quả vẫn "chạy được" nhưng vô
    // nghĩa. Chặn fail-closed ngay từ cửa.
    if VendorData.shared.dataVersion == "unloaded" {
        fail("vendors.json KHÔNG nạp được (dataVersion=unloaded) — đặt vendors.json cạnh binary harness", code: 3)
    }
    if DomainCorrector.lexiconVersion == "unloaded" {
        fail("lexicon.json KHÔNG nạp được (lexiconVersion=unloaded) — đặt lexicon.json cạnh binary harness", code: 3)
    }
}

// MARK: - Điều tra hộp (ứng viên A: hộp không-hữu-hạn)

func boxCensus(_ boxes: [CGRect]) -> String {
    var nonFinite = 0
    var maxAbsMaxX = 0.0
    for b in boxes {
        let comps = [b.origin.x, b.origin.y, b.width, b.height]
        if comps.contains(where: { !$0.isFinite }) { nonFinite += 1 }
        if b.maxX.isFinite { maxAbsMaxX = max(maxAbsMaxX, abs(Double(b.maxX))) }
    }
    return "boxes=\(boxes.count) nonFinite=\(nonFinite) maxAbsMaxX=\(String(format: "%.4f", maxAbsMaxX))"
}

// MARK: - Chấm E1/E2 + điểm ứng viên (bản driver của makeEvaluation)
//
// ReadPipeline.makeEvaluation là private trong file UIKit nên
// harness không gọi được; bản này tính CÙNG các đại lượng từ
// ParseResult bằng đúng CandidateScorer.score của app
// (CaptureIntake — biên dịch nguyên văn vào harness). integrity
// = tỉ lệ dòng tiền trước ranh giới vùng tổng có cạnh phải
// trong dải cột tiền (moneyColumnBand của app); band nil -> 1.0.
// Ghi nhãn trung thực: công thức integrity là bản driver, cổng
// LUẬT của harness là SỐNG + khép E1/E2, không phải khớp điểm
// tuyệt đối với BenchShell.

func evaluate(parsed: ParseResult, assembly: AssemblyResult) -> (e1: Bool, e2: Bool, score: Double) {
    var e1 = false
    if let subtotal = parsed.subtotalCents,
       let sum = SafeMoney.sumCents(parsed.items.map { $0.amountCents ?? 0 }) {
        e1 = sum == subtotal
    }
    var e2 = false
    if let subtotal = parsed.subtotalCents, let total = parsed.totalCents {
        let implied = SafeMoney.checkedAdd(subtotal, parsed.taxTotalCents)
        e2 = implied.map { abs($0 - total) <= 2 } ?? false
    }
    var e3 = false
    if let sold = parsed.itemsSold {
        let positive = parsed.items.filter { ($0.amountCents ?? 0) > 0 }
        let counted = parsed.soldContribution == "onePerLine"
            ? positive.count
            : positive.reduce(0) { $0 + $1.qty }
        e3 = counted == sold
    }
    let boundary = CandidateScorer.totalsBoundary(assembly.lines)
    var integrity = 1.0
    if let band = CandidateScorer.moneyColumnBand(assembly.lines) {
        let pre = assembly.lines[..<boundary].filter {
            !SafeMoney.tokens(in: $0.text).isEmpty
        }
        if !pre.isEmpty {
            let inside = pre.filter {
                Double($0.box.maxX) >= band.lo && Double($0.box.maxX) <= band.hi
            }.count
            integrity = Double(inside) / Double(pre.count)
        }
    }
    let ev = CandidateEvaluation(
        e1Closed: e1, e2Within2c: e2, e3Closed: e3,
        integrity: integrity,
        hasSubtotal: parsed.subtotalCents != nil,
        hasTotal: parsed.totalCents != nil,
        hasTaxLine: !parsed.taxes.isEmpty,
        hasDate: parsed.date != nil,
        vendorResolved: parsed.vendor != nil,
        itemsMissingAmount: parsed.items.filter { $0.amountCents == nil }.count,
        alnumChars: assembly.lines.reduce(0) {
            $0 + $1.text.filter { $0.isLetter || $0.isNumber }.count
        },
        isOriginal: true)
    return (e1, e2, CandidateScorer.score(ev).total)
}

func parseSummary(_ p: ParseResult) -> String {
    let sum = SafeMoney.sumCents(p.items.map { $0.amountCents ?? 0 })
    return "vendor=\(p.vendor ?? "nil") subtotal=\(p.subtotalCents.map(String.init) ?? "nil") "
        + "tax=\(p.taxTotalCents) total=\(p.totalCents.map(String.init) ?? "nil") "
        + "items=\(p.items.count) sumItems=\(sum.map(String.init) ?? "nil") "
        + "sold=\(p.itemsSold.map(String.init) ?? "nil") card=\(p.cardLast4 ?? "nil") "
        + "warnings=\(p.warnings.count)"
}

// MARK: - Nạp ảnh (ImageIO — không UIKit)

func loadCGImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    return img
}

// MARK: - Một lượt đọc đầy đủ trên ảnh (đúng thân runCandidate)

struct ImageRun {
    var fragments: [Fragment]
    var assembly: AssemblyResult
    var parsed: ParseResult
    var e1: Bool
    var e2: Bool
    var score: Double
}

func runImage(_ cg: CGImage, engine: ClassicTextEngine) throws -> ImageRun {
    let fragments = try engine.recognize(in: cg, region: nil)
    let assembly = LineAssembly.assemble(fragments)
    let lines = assembly.lines.map {
        OCRLine(text: $0.text, confidence: $0.confidence)
    }
    let boxes: [CGRect?] = assembly.lines.map { $0.box }
    let parsed = ReceiptParser.parse(lines: lines, boxes: boxes)
    let ev = evaluate(parsed: parsed, assembly: assembly)
    return ImageRun(fragments: fragments, assembly: assembly,
                    parsed: parsed, e1: ev.e1, e2: ev.e2, score: ev.score)
}

func boxDict(_ b: CGRect) -> [String: Double] {
    // JSONSerialization NÉM LỖI trên Double không-hữu-hạn — mà
    // hộp không-hữu-hạn lại chính là bằng chứng săn ở ứng viên
    // A. Ánh xạ: NaN -> -999999, +/-inf -> +/-999999 (census ở
    // stdout giữ con số đếm chính xác; dump chỉ là phụ chứng).
    func fin(_ v: Double) -> Double {
        if v.isNaN { return -999999 }
        if v == .infinity { return 999999 }
        if v == -.infinity { return -999999 }
        return v
    }
    return ["x": fin(Double(b.origin.x)), "y": fin(Double(b.origin.y)),
            "w": fin(Double(b.width)), "h": fin(Double(b.height))]
}

func dumpImageRun(name: String, run: ImageRun, dir: URL) {
    let obj: [String: Any] = [
        "image": name,
        "fragmentCensus": boxCensus(run.fragments.map { $0.box }),
        "fragments": run.fragments.map {
            ["text": $0.text, "confidence": $0.confidence,
             "box": boxDict($0.box), "alternates": $0.alternates.count]
        },
        "assembled": run.assembly.lines.map {
            ["text": $0.text, "confidence": $0.confidence, "box": boxDict($0.box)]
        },
        "parse": parseSummary(run.parsed),
        "e1": run.e1, "e2": run.e2, "score": run.score,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: obj,
                                              options: [.prettyPrinted, .sortedKeys]) {
        let out = dir.appendingPathComponent(
            name.replacingOccurrences(of: ".jpg", with: "") + ".stream.json")
        try? data.write(to: out)
    }
}

// MARK: - Fixture (luồng đã ghi)

struct FixtureData {
    var lines: [OCRLine]
    var boxes: [CGRect?]
}

func loadFixture(_ path: String) -> FixtureData {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rawLines = obj["lines"] as? [[String: Any]] else {
        fail("không đọc được fixture \(path)")
    }
    var lines: [OCRLine] = []
    var boxes: [CGRect?] = []
    for raw in rawLines {
        let text = raw["text"] as? String ?? ""
        let conf = (raw["confidence"] as? NSNumber)?.doubleValue ?? 0.5
        lines.append(OCRLine(text: text, confidence: conf))
        if let b = raw["box"] as? [String: Any] {
            boxes.append(CGRect(
                x: (b["x"] as? NSNumber)?.doubleValue ?? 0,
                y: (b["y"] as? NSNumber)?.doubleValue ?? 0,
                width: (b["w"] as? NSNumber)?.doubleValue ?? 0,
                height: (b["h"] as? NSNumber)?.doubleValue ?? 0))
        } else {
            boxes.append(nil)
        }
    }
    return FixtureData(lines: lines, boxes: boxes)
}

// MARK: - Bẫy đột biến (mỗi id = một process riêng phía CI)
//
// Căn cứ thiết kế: hai điểm Double->Int DUY NHẤT trong
// Parser.swift mà dữ liệu OCR chạm tới được (điều tra tĩnh
// HARNESS-REPRO, grep Int( toàn file):
//   (A) Parser.swift:1999 columnModel — Int((maxX/0.01).rounded())
//       trên cạnh phải hộp của dòng CÓ TIỀN; maxX NaN/inf/>=9.2e16
//       -> TRAP. Luồng ghi: mọi maxX hữu hạn [0.42, 0.60] nên
//       không bao giờ kích hoạt ở đó.
//   (B) Parser.swift:1223 extractSamelineItems — Int(lb * unit)
//       trên dòng cân; lb từ regex số KHÔNG chặn chữ số ->
//       Double khổng lồ/inf -> TRAP. Điều kiện tới được: dòng
//       chứa "/lb" hoặc "/1b", lb KHÔNG đứng đầu dòng (đầu dòng
//       là số dài thì nhánh khối UPC nuốt trước), có đơn giá.
// Cộng các họ trong brief: kéo dài token số, trigger ở dòng
// cuối, hộp suy biến, nhân đôi dòng, token tiền lạ, cấu trúc.

func extendDigitRuns(_ text: String, toLength n: Int) -> String {
    guard let re = try? NSRegularExpression(pattern: #"\d+"#) else { return text }
    var out = text
    let matches = re.matches(in: text, options: [],
                             range: NSRange(text.startIndex..., in: text)).reversed()
    for m in matches {
        guard let r = Range(m.range, in: out) else { continue }
        let run = String(out[r])
        if run.count < n {
            out.replaceSubrange(r, with: run + String(repeating: "9", count: n - run.count))
        }
    }
    return out
}

typealias Mutation = (inout [OCRLine], inout [CGRect?]) -> Void

func mutationTable() -> [(id: String, body: Mutation)] {
    var table: [(id: String, body: Mutation)] = []
    func add(_ id: String, _ body: @escaping Mutation) { table.append((id, body)) }
    func insert(_ line: String, at pos: String) -> Mutation {
        { lines, boxes in
            let i = pos == "start" ? 0 : (pos == "end" ? lines.count : lines.count / 2)
            lines.insert(OCRLine(text: line, confidence: 0.9), at: i)
            boxes.insert(CGRect(x: 0.30, y: 0.50, width: 0.28, height: 0.015), at: i)
        }
    }
    func appendLine(_ line: String) -> Mutation {
        { lines, boxes in
            lines.append(OCRLine(text: line, confidence: 0.9))
            boxes.append(CGRect(x: 0.30, y: 0.03, width: 0.28, height: 0.015))
        }
    }

    add("base") { _, _ in }
    add("base-nobox") { _, boxes in boxes = boxes.map { _ in nil } }

    // (a) kéo dài token số
    for n in [13, 16, 19] {
        add("digits\(n)-all") { lines, _ in
            for i in lines.indices { lines[i].text = extendDigitRuns(lines[i].text, toLength: n) }
        }
    }
    add("digits25-longest") { lines, _ in
        // chỉ dãy số dài nhất (mã vạch 23 số của L-R01) -> 25 số
        var best: (line: Int, len: Int) = (0, 0)
        for (i, l) in lines.enumerated() {
            for run in l.text.split(whereSeparator: { !$0.isNumber }) where run.count > best.len {
                best = (i, run.count)
            }
        }
        if best.line < lines.count {
            lines[best.line].text = extendDigitRuns(lines[best.line].text, toLength: 25)
        }
    }

    // (b) dòng cân — họ (B): lb khổng lồ đứng SAU nhãn chữ
    add("weight-ok-mid", insert("CRAWFISH 1.69 lb @ $2.99/lb", at: "mid"))
    add("weight-tjohnnys-mid", insert("LIVE CRAWFISH 43 lb @ $3.99/lb", at: "mid"))
    add("weight-huge-mid", insert("CRAWFISH 99999999999999999999 lb @ $3.99/lb", at: "mid"))
    add("weight-huge-start", insert("CRAWFISH 99999999999999999999 lb @ $3.99/lb", at: "start"))
    add("weight-barcode-lb-mid", insert("CRAWFISH 21120720301342609141417 lb @ $3.99/lb", at: "mid"))
    add("weight-inf-mid", insert("CRAWFISH " + String(repeating: "9", count: 400) + " lb @ $3.99/lb", at: "mid"))

    // (c) trigger ở DÒNG CUỐI (săn index+1 thiếu chặn)
    add("last-baremoney", appendLine("125.48"))
    add("last-subtotal-label", appendLine("SUBTOTAL"))
    add("last-itemcount-label", appendLine("ITEM COUNT:"))
    add("last-money-then-total") { lines, boxes in
        lines.append(OCRLine(text: "134.86", confidence: 0.9))
        boxes.append(CGRect(x: 0.30, y: 0.03, width: 0.28, height: 0.015))
        lines.append(OCRLine(text: "TOTAL", confidence: 0.9))
        boxes.append(CGRect(x: 0.30, y: 0.02, width: 0.28, height: 0.015))
    }
    add("last-date", appendLine("09/14/2026"))
    add("last-instsv", appendLine("INST SV 4.50-"))

    // (d) hộp suy biến — họ (A): dòng 28 của fixture là "125.48"
    // (dòng tiền trần) — columnModel chỉ quét dòng CÓ TIỀN.
    add("box-nan-maxx-moneyline") { _, boxes in
        if boxes.count > 28 { boxes[28] = CGRect(x: CGFloat.nan, y: 0.47, width: 0.05, height: 0.013) }
    }
    add("box-inf-maxx-moneyline") { _, boxes in
        if boxes.count > 28 { boxes[28] = CGRect(x: 0.52, y: 0.47, width: .infinity, height: 0.013) }
    }
    add("box-huge-maxx-moneyline") { _, boxes in
        if boxes.count > 28 { boxes[28] = CGRect(x: 0, y: 0.47, width: 1e17, height: 0.013) }
    }
    add("box-nan-firstline") { _, boxes in
        if !boxes.isEmpty { boxes[0] = CGRect(x: CGFloat.nan, y: .nan, width: .nan, height: .nan) }
    }
    add("box-nan-everywhere") { _, boxes in
        boxes = boxes.map { _ in CGRect(x: CGFloat.nan, y: .nan, width: .nan, height: .nan) }
    }
    add("box-all-identical") { _, boxes in
        boxes = boxes.map { _ in CGRect(x: 0.3, y: 0.5, width: 0.28, height: 0.015) }
    }
    add("box-all-zero") { _, boxes in
        boxes = boxes.map { _ in CGRect.zero }
    }
    add("box-negative") { _, boxes in
        boxes = boxes.map { _ in CGRect(x: -0.5, y: -0.5, width: 0.28, height: 0.015) }
    }
    add("box-short") { _, boxes in
        if boxes.count > 10 { boxes = Array(boxes.prefix(10)) }
    }

    // (e) nhân đôi dòng
    add("dup2") { lines, boxes in
        var l2: [OCRLine] = []; var b2: [CGRect?] = []
        for i in lines.indices { l2.append(lines[i]); l2.append(lines[i]); b2.append(boxes[i]); b2.append(boxes[i]) }
        lines = l2; boxes = b2
    }
    add("dup3") { lines, boxes in
        var l2: [OCRLine] = []; var b2: [CGRect?] = []
        for i in lines.indices { for _ in 0..<3 { l2.append(lines[i]); b2.append(boxes[i]) } }
        lines = l2; boxes = b2
    }

    // (f) token tiền lạ
    add("money-thousands") { lines, _ in
        if lines.count > 28 { lines[28].text = "1,234,567.89" }
    }
    add("money-thousands-total", appendLine("TOTAL 1,234,567.89"))
    add("money-dot99", appendLine("TOTAL .99"))
    add("money-99dot", appendLine("TOTAL 99."))
    add("money-comma-decimal", appendLine("TOTAL $2,79"))
    add("money-baht-tax", appendLine("TAX 1 8.517% ฿9.60"))

    // (g) cấu trúc cực đoan
    add("merge-all") { lines, boxes in
        let joined = lines.map { $0.text }.joined(separator: " ")
        lines = [OCRLine(text: joined, confidence: 0.9)]
        boxes = [CGRect(x: 0.3, y: 0.5, width: 0.3, height: 0.9)]
    }
    add("charbomb-5000") { lines, boxes in
        lines = [OCRLine(text: String(repeating: "9", count: 5000) + " TOTAL 134.86", confidence: 0.9)]
        boxes = [CGRect(x: 0.3, y: 0.5, width: 0.3, height: 0.015)]
    }
    add("token-500-letters") { lines, boxes in
        lines = [OCRLine(text: String(repeating: "A", count: 500) + " 12.34", confidence: 0.9)]
        boxes = [CGRect(x: 0.3, y: 0.5, width: 0.3, height: 0.015)]
    }
    add("empty") { lines, boxes in lines = []; boxes = [] }
    add("single-baremoney") { lines, boxes in
        lines = [OCRLine(text: "125.48", confidence: 0.9)]
        boxes = [CGRect(x: 0.5, y: 0.5, width: 0.05, height: 0.013)]
    }
    return table
}

// MARK: - Điều phối chế độ

let mode = args.first ?? "probe"

switch mode {
case "probe":
    let supported = (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
        for: .accurate, revision: VNRecognizeTextRequestRevision3)) ?? []
    print("supported(rev3, accurate) = \(supported)")
    print("vendors dataVersion = \(VendorData.shared.dataVersion)")
    print("lexicon version = \(DomainCorrector.lexiconVersion)")
    print("SURVIVED probe")

case "fixture":
    guard args.count >= 2 else { fail("fixture cần đường dẫn file") }
    print("[fixture] start path=\(args[1])")
    requireDataLoaded()
    print("[fixture] data-loaded")
    let fx = loadFixture(args[1])
    let boxes: [CGRect?]? = hasFlag("--nobox") ? nil : fx.boxes
    print("fixture lines=\(fx.lines.count) boxes=\(boxes != nil ? "yes" : "nil")")
    print("[fixture] parsing")
    let parsed = ReceiptParser.parse(lines: fx.lines, boxes: boxes)
    print("[fixture] parsed")
    print(parseSummary(parsed))
    print("SURVIVED fixture")

case "parseonly":
    // Process CON cho bisect: parse đúng một lựa chọn dòng của
    // fixture rồi thoát. Chết vì signal = lựa chọn đó gây chết.
    //   --keep i,j,k   chỉ giữ các dòng theo chỉ số 0-based
    //   --count k      giữ k dòng đầu
    //   --text "..."   parse đúng một dòng chữ thô này (hộp lấy
    //                  từ dòng 8 của fixture — hộp của ca chết)
    guard args.count >= 2 else { fail("parseonly cần đường dẫn file") }
    requireDataLoaded()
    let fx = loadFixture(args[1])
    if let t = argValue("--text") {
        let box: CGRect? = fx.boxes.indices.contains(8) ? fx.boxes[8] : nil
        print("[parseonly] rawtext=\(t)")
        _ = ReceiptParser.parse(lines: [OCRLine(text: t, confidence: 1.0)],
                                boxes: [box])
        print("SURVIVED parseonly")
        exit(0)
    }
    var idx = Array(fx.lines.indices)
    if let keep = argValue("--keep") {
        idx = keep.split(separator: ",").compactMap { Int($0) }
            .filter { fx.lines.indices.contains($0) }
    } else if let c = argValue("--count"), let k = Int(c) {
        idx = Array(fx.lines.indices.prefix(max(0, k)))
    }
    let lines = idx.map { fx.lines[$0] }
    let boxes = idx.map { fx.boxes[$0] }
    print("[parseonly] lines=\(lines.count) idx=\(idx.map(String.init).joined(separator: ","))")
    _ = ReceiptParser.parse(lines: lines, boxes: boxes)
    print("SURVIVED parseonly")

case "streamone":
    // Process con của "streams": parse đúng một file luồng (mỗi
    // dòng = một OCRLine, confidence = recoveredLineConfidence
    // như đường reparse) rồi in STREAM-RESULT. Chết vì signal =
    // ca đó gây chết — cha ghi STREAM-DIED thay cho kết quả.
    // Thuế in TỪNG DÒNG để bàn chấm Ledger Gate theo SCORECARD.
    guard args.count >= 2 else { fail("streamone cần đường dẫn file") }
    requireDataLoaded()
    guard let raw = try? String(contentsOfFile: args[1], encoding: .utf8) else {
        fail("streamone: không đọc được \(args[1])")
    }
    let streamLines = raw.split(separator: "\n")
        .map { OCRLine(text: String($0), confidence: ReceiptParser.recoveredLineConfidence) }
    // V4-1: --core v4 chạy parseV4 (ứng viên + trọng tài khối
    // tổng, DESIGN-V4 §8: công tắc chỉ ở harness/bench) và in
    // STREAM4-RESULT = STREAM-RESULT + prov= (số trường khối
    // tổng có provenance: subtotal/tax[i]/total) + arb=
    // (trạng thái trọng tài). Không tham số = v3 như cũ.
    let useV4 = argValue("--core") == "v4"
    let parsed = useV4 ? ReceiptParser.parseV4(lines: streamLines)
                       : ReceiptParser.parse(lines: streamLines)
    let taxList = parsed.taxes.map { String($0.amountCents) }.joined(separator: ",")
    let qtySum = parsed.items.reduce(0) { $0 + $1.qty }
    let qtyPos = parsed.items.filter { ($0.amountCents ?? 0) > 0 }.reduce(0) { $0 + $1.qty }
    if useV4 {
        let provCount = parsed.totalsProvenance.keys.filter {
            $0 == "subtotal" || $0 == "total" || $0.hasPrefix("tax[")
        }.count
        print("STREAM4-RESULT file=\((args[1] as NSString).lastPathComponent) \(parseSummary(parsed)) taxes=[\(taxList)] qty=\(qtySum) qtyPos=\(qtyPos) prov=\(provCount) arb=\(parsed.arbiterStatus ?? "nil")")
    } else {
        print("STREAM-RESULT file=\((args[1] as NSString).lastPathComponent) \(parseSummary(parsed)) taxes=[\(taxList)] qty=\(qtySum) qtyPos=\(qtyPos)")
    }
    print("SURVIVED streamone")

case "streams":
    // CỔNG LUỒNG (V4-0, DESIGN-V4 §7): chạy parser HIỆN HÀNH
    // trên mọi luồng .txt trong --dir. Mỗi ca ở process con
    // riêng (mẫu của bisect): một ca chết không kéo cả cổng,
    // và cái chết được ghi đích danh. Cổng hoàn thành khi in
    // STREAMS-DONE — ca chết/tệ là DỮ LIỆU ĐO của đường cơ
    // sở, không phải lỗi vận hành của cổng.
    guard let dir = argValue("--dir") else { fail("streams cần --dir") }
    requireDataLoaded()
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
        fail("streams: không đọc được thư mục \(dir)")
    }
    let files = names.filter { $0.hasSuffix(".txt") }.sorted()
    print("[streams] dir=\(dir) files=\(files.count)")
    let selfPath = CommandLine.arguments[0]
    var died = 0
    var died4 = 0
    for name in files {
        let path = (dir as NSString).appendingPathComponent(name)
        // Chạy process con streamone một lượt; extra = tham số
        // lõi (rỗng = v3, ["--core","v4"] = v4). Ngữ nghĩa chết/
        // ghi chú giữ nguyên của cổng V4-0.
        func runChildOnce(_ extra: [String]) -> (ok: Bool, note: String, out: String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: selfPath)
            p.arguments = ["streamone", path] + extra
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            var out = ""
            var spawnOK = true
            do { try p.run() } catch { spawnOK = false }
            if spawnOK {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                out = String(data: data, encoding: .utf8) ?? ""
            }
            let ok = spawnOK && p.terminationReason == .exit && p.terminationStatus == 0
            let note = !spawnOK ? "spawn-failed"
                : (p.terminationReason == .exit ? "exit \(p.terminationStatus)" : "signal \(p.terminationStatus)")
            return (ok, note, out)
        }
        let r3 = runChildOnce([])
        if r3.ok, let line = r3.out.split(separator: "\n").first(where: { $0.hasPrefix("STREAM-RESULT") }) {
            print(line)
        } else {
            died += 1
            print("STREAM-DIED file=\(name) (\(r3.note))")
        }
        // V4-1: lượt v4 trên cùng file — con chết ghi STREAM4-DIED
        // đích danh, cổng chốt bằng STREAMS4-DONE riêng để số
        // V4-0 (STREAMS-DONE) giữ nguyên ý nghĩa đối chứng.
        let r4 = runChildOnce(["--core", "v4"])
        if r4.ok, let line = r4.out.split(separator: "\n").first(where: { $0.hasPrefix("STREAM4-RESULT") }) {
            print(line)
        } else {
            died4 += 1
            print("STREAM4-DIED file=\(name) (\(r4.note))")
        }
    }
    print("STREAMS-DONE total=\(files.count) died=\(died)")
    print("STREAMS4-DONE total=\(files.count) died=\(died4)")

case "bisect":
    // Truy vết cái chết trong parse TRÊN CHÍNH luồng fixture:
    // mỗi lựa chọn dòng chạy trong process con riêng (chết vì
    // signal không kéo theo cha). Pha A: tiền tố tăng dần —
    // tiền tố chết đầu tiên khoanh đoạn cuối. Pha B: tham lam
    // bỏ từng dòng mà vẫn chết -> tập tối thiểu gây chết.
    guard args.count >= 2 else { fail("bisect cần đường dẫn file") }
    requireDataLoaded()
    let fxPath = args[1]
    let fx = loadFixture(fxPath)
    let n = fx.lines.count
    let selfPath = CommandLine.arguments[0]
    func runChild(_ keep: [Int]) -> (ok: Bool, note: String) {
        // ok = con sống (in SURVIVED); note ghi cách con kết thúc
        // (exit code hay signal) để log nói rõ cách chết.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: selfPath)
        p.arguments = ["parseonly", fxPath, "--keep",
                       keep.map(String.init).joined(separator: ",")]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return (false, "spawn-failed") }
        p.waitUntilExit()
        let ok = p.terminationReason == .exit && p.terminationStatus == 0
        let note = p.terminationReason == .exit
            ? "exit \(p.terminationStatus)" : "signal \(p.terminationStatus)"
        return (ok, note)
    }
    print("[bisect] total lines=\(n)")
    var fatalPrefix = -1
    for k in 1...n {
        let r = runChild(Array(0..<k))
        print("[bisect] prefix k=\(k) -> \(r.ok ? "ok" : "DIED (\(r.note))")")
        let ok = r.ok
        if !ok { fatalPrefix = k; break }
    }
    guard fatalPrefix > 0 else {
        print("BISECT-DONE no-death-on-any-prefix")
        exit(0)
    }
    var current = Array(0..<fatalPrefix)
    var improved = true
    var guardRounds = 0
    while improved && guardRounds < 12 {
        improved = false
        guardRounds += 1
        for i in current.reversed() {
            let trial = current.filter { $0 != i }
            if trial.isEmpty { continue }
            if !runChild(trial).ok {
                print("[bisect] drop line \(i) -> still DIED (kept dropped)")
                current = trial
                improved = true
            }
        }
    }
    print("[bisect] minimal idx=\(current.map(String.init).joined(separator: ","))")
    for i in current {
        print("[bisect] line \(i): \(fx.lines[i].text)")
    }
    print("BISECT-DONE fatalPrefix=\(fatalPrefix) minimalCount=\(current.count)")

case "variants":
    // Chẻ nhỏ dòng gây chết (run #16: trap trong
    // extractSamelineItems trên dòng 8 của L-R01) — mỗi biến
    // thể chạy trong process con riêng qua parseonly --text;
    // biến thể nào chết/sống sẽ chỉ ra đặc điểm kích hoạt.
    guard args.count >= 2 else { fail("variants cần đường dẫn fixture") }
    requireDataLoaded()
    let fxPath = args[1]
    let variants: [String] = [
        "3006152 BOUNCE 400 11.49 A",   // V1 nguyên văn dòng 8
        "BOUNCE 400 11.49 A",           // V2 bỏ mã đầu dòng
        "3006152 BOUNCE 11.49 A",       // V3 bỏ "400"
        "3006152 BOUNCE 400 11.49",     // V4 bỏ cờ đuôi "A"
        "3006152 BOUNCE 400 A",         // V5 bỏ tiền
        "BOUNCE 11.49 A",               // V6 tối thiểu tiền + cờ
        "BOUNCE 11.49",                 // V7 tiền, không cờ
        "1234567 XXXXX 999 22.50 B",    // V8 cùng dạng, số khác
        "ABCDEFG BOUNCE 400 11.49 A",   // V9 chữ thay mã số
        "3006152 BOUNCE 400 11.49 AF",  // V10 cờ đuôi 2 chữ
    ]
    let selfPath = CommandLine.arguments[0]
    for (i, v) in variants.enumerated() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: selfPath)
        p.arguments = ["parseonly", fxPath, "--text", v]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        var note = "spawn-failed"
        var ok = false
        if (try? p.run()) != nil {
            p.waitUntilExit()
            ok = p.terminationReason == .exit && p.terminationStatus == 0
            note = p.terminationReason == .exit
                ? "exit \(p.terminationStatus)" : "signal \(p.terminationStatus)"
        }
        print("[variants] V\(i + 1) \(ok ? "ok" : "DIED (\(note))"): \(v)")
    }
    print("VARIANTS-DONE")

case "fuzz":
    guard args.count >= 2 else { fail("fuzz cần đường dẫn fixture") }
    let table = mutationTable()
    if hasFlag("--list") {
        for entry in table { print(entry.id) }
        exit(0)
    }
    guard args.count >= 3 else { fail("fuzz cần id đột biến (xem --list)") }
    requireDataLoaded()
    let id = args[2]
    guard let entry = table.first(where: { $0.id == id }) else {
        fail("không có đột biến \(id)")
    }
    var fx = loadFixture(args[1])
    entry.body(&fx.lines, &fx.boxes)
    print("fuzz \(id): lines=\(fx.lines.count)")
    let parsed = ReceiptParser.parse(lines: fx.lines, boxes: fx.boxes)
    print(parseSummary(parsed))
    print("SURVIVED \(id)")

case "images":
    guard let dirPath = argValue("--dir") else { fail("images cần --dir") }
    requireDataLoaded()
    applyEngineConfig()
    let sets = Int(argValue("--sets") ?? "1") ?? 1
    let dir = URL(fileURLWithPath: dirPath)
    let files = (try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)) ?? []
    let jpgs = files.filter { $0.pathExtension.lowercased() == "jpg" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    if jpgs.isEmpty { fail("không có .jpg trong \(dirPath)") }
    var dumpDir: URL? = nil
    if let d = argValue("--dump") {
        dumpDir = URL(fileURLWithPath: d)
        try? FileManager.default.createDirectory(at: dumpDir!,
                                                 withIntermediateDirectories: true)
    }
    let engine = ClassicTextEngine()
    print("manifest: family=\(engine.manifest.family) rev=\(engine.manifest.revision) "
        + "langs=\(engine.manifest.languagesEffective) topk=\(ClassicTextEngine.topCandidates)")
    for set in 1...sets {
        var okCount = 0
        for url in jpgs {
            guard let cg = loadCGImage(url) else {
                print("SET \(set) \(url.lastPathComponent): LOAD-FAILED")
                continue
            }
            do {
                let run = try runImage(cg, engine: engine)
                print("SET \(set) \(url.lastPathComponent): frag[\(boxCensus(run.fragments.map { $0.box }))] "
                    + "asm[\(boxCensus(run.assembly.lines.map { $0.box }))] "
                    + "\(parseSummary(run.parsed)) e1=\(run.e1) e2=\(run.e2) score=\(String(format: "%.1f", run.score))")
                if let dumpDir, set == 1 {
                    dumpImageRun(name: url.lastPathComponent, run: run, dir: dumpDir)
                }
                okCount += 1
            } catch {
                print("SET \(set) \(url.lastPathComponent): ENGINE-ERROR \(error)")
            }
        }
        print("SET \(set) DONE \(okCount)/\(jpgs.count)")
        if okCount != jpgs.count { fail("set \(set) thiếu ảnh", code: 4) }
    }
    print("SURVIVED images x\(sets)")

default:
    fail("chế độ không rõ: \(mode) — probe|images|fixture|fuzz|streams")
}

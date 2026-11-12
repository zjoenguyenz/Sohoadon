import Foundation

// MARK: - VendorData (M7) — Vendor là DỮ LIỆU (DESIGN-FINAL §3.4)
//
// Toàn bộ tri thức về tiệm nằm ở vendors.json (kèm app dưới dạng
// resource; bản ở staging: v3-phase1/vendors.json, dataVersion
// "vendors-2026-11-11-p1"): tên hiển thị, các dạng tên khớp, neo
// phụ (địa chỉ/điện thoại/cụm chữ, mỗi neo có weight), món đặc
// trưng (chỉ gợi ý), và printSemantics (luật in theo vendor — vd
// Walmart: dòng 'N AT 1 FOR X' đóng góp 1 vào số món đã bán).
// Thêm một tiệm = thêm mục dữ liệu + ca sinh nó thành fixture hồi
// quy + bump dataVersion — KHÔNG sửa code (luật phủ corpus: ca nào
// có vendor đáp án mà phân giải ra nil = cổng rớt, chạy trong bộ
// kiểm Pha 1).
//
// Luật phân giải 3 nấc (giữ từ WP5, nay đọc dữ liệu thay vì bảng
// cứng trong Parser.swift):
//  NẤC 1: khớp tên trên TỪNG dòng đã chuẩn hoá — exact (needle
//    xuất hiện nguyên vẹn theo ranh giới token) thắng fuzzy (mọi
//    token của needle có token trong dòng khớp đúng hoặc mờ-1-ký-
//    tự, trừ token thuộc exactTokenOnly của chính mục đó); cùng
//    hạng thì dòng sớm hơn thắng.
//  NẤC 2: neo phụ — một neo weight "strong" một mình đủ kết luận
//    (độ tin cậy bị chặn ở 0.5); neo "weak" cần ≥2 LOẠI neo khác
//    nhau của cùng tiệm; hai tiệm cùng đủ điều kiện = tranh chấp,
//    KHÔNG điền tên.
//  NẤC 3: món đặc trưng — CHỈ gợi ý, không bao giờ tự điền.
// Neo khớp trên toàn văn đã nối (địa chỉ/cụm chữ có thể bị OCR xé
// dòng) và trên chuỗi số đã nối (điện thoại có thể bị tách).
//
// Nạp dữ liệu: Bundle.main "vendors.json". Nạp hỏng -> entries
// rỗng (nhận diện trả về nil + không gợi ý): fail-closed, tuyệt
// đối không rơi về bảng cứng nào khác.

struct VendorEntry: Decodable {
    var key: String
    var displayName: String
    var parserPath: String = "generic"     // "sams" | "generic"
    var matchNames: [String] = []
    var exactTokenOnly: [String] = []
    var anchors: [Anchor] = []
    var signatureItems: [String] = []
    var printSemantics: PrintSemantics? = nil

    struct Anchor: Decodable {
        var kind: String        // address | phone | phrase
        var value: String
        var weight: String      // strong | weak
        var note: String? = nil
    }
    struct PrintSemantics: Decodable {
        var atLineSoldContribution: String = "byQuantity"  // byQuantity | onePerLine
        var note: String? = nil
    }
    var soldContribution: String {
        printSemantics?.atLineSoldContribution ?? "byQuantity"
    }

    // Giải mã khoan dung: khóa vắng mặt -> giá trị mặc định (Swift
    // Decodable tổng hợp không tự dùng default cho khóa thiếu).
    enum CodingKeys: String, CodingKey {
        case key, displayName, parserPath, matchNames, exactTokenOnly,
             anchors, signatureItems, printSemantics
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        displayName = try c.decode(String.self, forKey: .displayName)
        parserPath = try c.decodeIfPresent(String.self, forKey: .parserPath) ?? "generic"
        matchNames = try c.decodeIfPresent([String].self, forKey: .matchNames) ?? []
        exactTokenOnly = try c.decodeIfPresent([String].self, forKey: .exactTokenOnly) ?? []
        anchors = try c.decodeIfPresent([Anchor].self, forKey: .anchors) ?? []
        signatureItems = try c.decodeIfPresent([String].self, forKey: .signatureItems) ?? []
        printSemantics = try c.decodeIfPresent(PrintSemantics.self, forKey: .printSemantics)
    }
}

struct VendorFile: Decodable {
    var dataVersion: String
    var vendors: [VendorEntry]
}

enum VendorData {
    static let shared: VendorStore = VendorStore()
}

final class VendorStore {
    let dataVersion: String
    let entries: [VendorEntry]
    var byKey: [String: VendorEntry] = [:]

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "vendors", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(VendorFile.self, from: data) {
            dataVersion = file.dataVersion
            entries = file.vendors
        } else {
            dataVersion = "unloaded"
            entries = []
        }
        for e in entries { byKey[e.key] = e }
    }

    struct Identification {
        var vendor: String? = nil
        var key: String = "generic"
        var parserPath: String = "generic"
        var confidence: Double = 0
        var source: String? = nil
        var suggestion: String? = nil
        var anchorDisputed: Bool = false
        var entry: VendorEntry? = nil
    }

    func identify(lines: [OCRLine]) -> Identification {
        var result = Identification()
        // NẤC 1
        var best: (rank: Int, lineIndex: Int, entry: VendorEntry, confidence: Double, kind: String)? = nil
        for (index, line) in lines.enumerated() {
            let normalized = VendorData.normalize(line.text)
            for entry in entries {
                for needle in entry.matchNames {
                    guard let kind = VendorData.lineMatch(entry: entry, normalizedLine: normalized, needle: needle) else { continue }
                    let rank = kind == "exact" ? 2 : 1
                    if let b = best, rank < b.rank || (rank == b.rank && index >= b.lineIndex) { continue }
                    best = (rank, index, entry, line.confidence, kind)
                }
            }
        }
        if let b = best {
            result.vendor = b.entry.displayName
            result.key = b.entry.key
            result.parserPath = b.entry.parserPath
            result.entry = b.entry
            if b.kind == "exact" {
                result.source = "tier1-exact"
                result.confidence = b.confidence
            } else {
                result.source = "tier1-fuzzy"
                result.confidence = b.confidence * 0.8
            }
            return result
        }
        // NẤC 2
        let hits = qualifying(lines: lines)
        if hits.count == 1, let only = hits.first {
            result.vendor = only.displayName
            result.key = only.key
            result.parserPath = only.parserPath
            result.entry = only
            result.source = "tier2-anchor"
            result.confidence = 0.5
            return result
        }
        if hits.count > 1 {
            result.anchorDisputed = true
        }
        // NẤC 3 — chỉ gợi ý
        let joined = lines.map { VendorData.normalize($0.text) }.joined(separator: " ")
        for entry in entries {
            for token in entry.signatureItems where joined.contains(VendorData.normalize(token)) {
                result.suggestion = entry.displayName
                return result
            }
        }
        return result
    }

    /// Tiệm đủ điều kiện ở nấc neo: ≥1 neo "strong" HOẶC ≥2 loại
    /// neo khác nhau (mọi weight).
    func qualifying(lines: [OCRLine]) -> [VendorEntry] {
        let joined = lines.map { VendorData.normalize($0.text) }.joined(separator: " ")
        let joinedDigits = lines.map { line in
            line.text.filter { $0.isASCII && $0.isNumber }
        }.joined()
        var kindsByKey: [String: Set<String>] = [:]
        for entry in entries {
            for anchor in entry.anchors {
                let ok: Bool
                switch anchor.kind {
                case "phone": ok = joinedDigits.contains(anchor.value)
                case "phrase", "address": ok = joined.contains(VendorData.normalize(anchor.value))
                default: ok = false
                }
                if ok { kindsByKey[entry.key, default: []].insert(anchor.kind) }
            }
        }
        var out: [VendorEntry] = []
        for entry in entries {
            guard let kinds = kindsByKey[entry.key] else { continue }
            let hasStrong = entry.anchors.contains {
                kinds.contains($0.kind) && $0.weight == "strong"
            }
            if hasStrong || kinds.count >= 2 {
                out.append(entry)
            }
        }
        return out
    }
}

// MARK: - Chuẩn hoá + khớp mờ (chuyển nguyên từ Parser.swift của
// bản nền WP5 — hành vi không đổi, chỉ đổi nơi ở)

extension VendorData {
    /// Thống nhất apostrophe cong/thẳng, bỏ dấu, viết hoa, ký tự
    /// không phải A-Z/0-9 thành khoảng trắng, gọn khoảng trắng.
    static func normalize(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\u{2019}", with: "'")
        t = t.replacingOccurrences(of: "\u{2018}", with: "'")
        t = t.replacingOccurrences(of: "\u{02BC}", with: "'")
        t = t.folding(options: [.diacriticInsensitive], locale: nil).uppercased()
        var out = ""
        for scalar in t.unicodeScalars {
            if (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 48 && scalar.value <= 57) {
                out.append(Character(scalar))
            } else {
                out.append(" ")
            }
        }
        return out.split(separator: " ").joined(separator: " ")
    }

    static func tokenFuzzyEqual(entry: VendorEntry, lineToken: String, needleToken: String) -> Bool {
        if lineToken == needleToken { return true }
        if entry.exactTokenOnly.contains(needleToken) { return false }
        guard lineToken.count >= 5, needleToken.count >= 5 else { return false }
        return levenshtein(lineToken, needleToken) <= 1
    }

    /// "exact" / "fuzzy" / nil — như vendorLineMatch của bản nền.
    static func lineMatch(entry: VendorEntry, normalizedLine: String, needle: String) -> String? {
        let lineTokens = normalizedLine.split(separator: " ").map(String.init)
        let needleTokens = needle.split(separator: " ").map(String.init)
        guard !needleTokens.isEmpty, !lineTokens.isEmpty else { return nil }
        if lineTokens.count >= needleTokens.count {
            for i in 0...(lineTokens.count - needleTokens.count) {
                if Array(lineTokens[i..<(i + needleTokens.count)]) == needleTokens {
                    return "exact"
                }
            }
        }
        var usedFuzzy = false
        for nt in needleTokens {
            var hit: String? = nil
            for lt in lineTokens {
                if lt == nt { hit = "exact"; break }
                if tokenFuzzyEqual(entry: entry, lineToken: lt, needleToken: nt) { hit = "fuzzy" }
            }
            guard let h = hit else { return nil }
            if h == "fuzzy" { usedFuzzy = true }
        }
        return usedFuzzy ? "fuzzy" : nil
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a), bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }
        var prev = Array(0...bChars.count)
        for i in 1...aChars.count {
            var cur = [i]
            for j in 1...bChars.count {
                cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (aChars[i - 1] == bChars[j - 1] ? 0 : 1)))
            }
            prev = cur
        }
        return prev[bChars.count]
    }
}

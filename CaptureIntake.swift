import Foundation
import CoreGraphics
import ImageIO

// F1 — NẠP + HÌNH HỌC + CHẤT LƯỢNG (CaptureIntake), CORE-V3 Pha 2.
// Đặc tả: DESIGN-FINAL §3.1 (giữ phần (Đ) của DESIGN-DETAIL §3.1)
// + hàm chọn ứng viên §3.6. Gương Python: capture_mirror.py (máy
// cổng + điểm ứng viên + cơ chế QualityMap) và platform_gate.py
// của Pha 0 (luật tứ giác). Phần đo-trên-ảnh (dewarp/bóng/tăng
// cường/CI) là mã thiết bị — giao thức đo ở
// MEASUREMENT-PROTOCOL.md; file này khai báo chuỗi + cổng + hàm
// điểm, không tự khẳng định chất lượng tiền xử lý nào.
//
// Hai đường nạp TÁCH BẠCH (không bao giờ nhập nhằng trong chẩn
// đoán): quét VisionKit và nạp ảnh/tệp. Chế độ hoá đơn dài =
// NHIỀU TRANG + ghép ở tầng chữ qua LineAssembly.assemblePages
// (bất biến chống nhân đôi áp xuyên trang); panorama điểm ảnh
// NGOÀI phạm vi (quyết định D2).

enum IntakeSource: String {
    case documentScanner
    case photoLibrary
    case cameraPhoto
    case pdfTextLayer
    case storedText
    /// PHA 4 (điểm nối cộng thêm — không đổi case nào sẵn có):
    /// file ảnh/PDF-render nạp từ Files cần giá trị nguồn riêng
    /// trong hồ sơ chẩn đoán thay vì mượn photoLibrary.
    case fileImport
}

struct IntakeMetadata {
    var source: IntakeSource
    var imageFileName: String
    var byteSize: Int?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var exifOrientation: Int = 1
    var pageCount: Int = 1
    var pageIndex: Int = 0

    func diagInput() -> DiagInput {
        DiagInput(source: source.rawValue,
                  imageFileName: imageFileName,
                  pixelWidth: pixelWidth,
                  pixelHeight: pixelHeight,
                  exifOrientation: exifOrientation,
                  byteSize: byteSize,
                  pdfRenderScale: nil)
    }
}

/// Chế độ hoá đơn dài: nhiều trang của MỘT tờ; mỗi trang giữ
/// metadata riêng, mảnh mang pageIndex, ghép ở tầng chữ.
struct LongReceiptIntake {
    static let stitchPolicyID = "text-stitch-v3-p2"
    var pages: [IntakeMetadata]
    var stitchStatus: String?   // điền từ StitchInfo sau khi ráp
}

// MARK: - Chuỗi ứng viên tiền xử lý (khai báo — thứ tự là luật)

struct CandidateStep {
    var kind: String            // DiagCandidate.kind
    var transformDesc: String
    var note: String
}

enum CandidateChain {
    /// Đúng thứ tự §3.1(e) bản chốt. Ứng viên phái sinh CHỈ được
    /// sinh khi cổng của nó cho qua (tứ giác: luật đầy đủ).
    static let steps: [CandidateStep] = [
        CandidateStep(kind: "original", transformDesc: "none",
                      note: "ứng viên 1 LUÔN là bản gốc (luật OCRFIX)"),
        CandidateStep(kind: "perspective",
                      transformDesc: "quad-gate-full-law",
                      note: "chỉ khi luật tứ giác ĐẦY ĐỦ cho qua; "
                          + "nới lề ~1.5% khi dựng ứng viên"),
        CandidateStep(kind: "dewarp", transformDesc: "band-dewarp-v1",
                      note: "nắn cong theo dải — bước riêng sau phối cảnh"),
        CandidateStep(kind: "shadowRemoved",
                      transformDesc: "shadow-color-keep",
                      note: "xoá bóng, GIỮ màu"),
        CandidateStep(kind: "enhanced",
                      transformDesc: "line-region-enhance",
                      note: "tăng cường theo vùng dòng chữ"),
        CandidateStep(kind: "enhanced",
                      transformDesc: "ci-document-enhancer",
                      note: "CIDocumentEnhancer (họ CoreImage)"),
        CandidateStep(kind: "binarized",
                      transformDesc: "adaptive-per-fragment",
                      note: "nhị phân hoá thích ứng theo mảnh — CUỐI "
                          + "CÙNG, không bao giờ là ứng viên duy nhất"),
    ]
    static let policyID = "score-v3-p2"
}

// MARK: - Luật tứ giác ĐẦY ĐỦ (cổng cho ứng viên phối cảnh)

enum QuadVerdict: Equatable {
    case allowed
    case rejected(String)
}

/// Luật đầy đủ = tính ĐƠN của tứ giác (chặn nơ-bướm — phát hiện
/// cổng Pha 0: extent thuần cho nơ-bướm QUA vì homography ánh xạ
/// 4 góc đích về đúng 4 đỉnh nguồn) ∧ luật extent của sàn an
/// toàn crashfix (hữu hạn, ≤ 4× mỗi chiều, ≤ 64MP) ∧ cổng hình
/// học D-2.3 (diện tích ≥ 55% khung, tỉ lệ cao/rộng ∈ [1.2, 12],
/// lồi + vòng nhất quán). Toạ độ: điểm ảnh, theo chu vi, ảnh đã
/// dựng thẳng theo EXIF. Gương: platform_gate.py (Pha 0).
enum QuadGate {
    static let maxExtentFactor = 4.0
    static let maxExtentPixels = 64_000_000.0
    static let minAreaFraction = 0.55
    static let aspectRange = 1.2...12.0

    static func evaluate(quad: [CGPoint], imageWidth: Int,
                         imageHeight: Int) -> QuadVerdict {
        guard quad.count == 4,
              quad.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
        else { return .rejected("degenerate") }
        if !isSimple(quad) { return .rejected("notSimple") }
        if !isConvexConsistent(quad) { return .rejected("nonConvex") }
        let area = abs(shoelace(quad)) / 2
        if area < minAreaFraction * Double(imageWidth * imageHeight) {
            return .rejected("areaTooSmall")
        }
        let w = (quad[1] - quad[0]).length + (quad[2] - quad[3]).length
        let h = (quad[3] - quad[0]).length + (quad[2] - quad[1]).length
        if w <= 0 { return .rejected("degenerate") }
        let aspect = (h / 2) / (w / 2)
        if !aspectRange.contains(aspect) {
            return .rejected("aspectOutOfRange")
        }
        guard let ext = mappedExtent(quad: quad) else {
            return .rejected("extentNonFinite")
        }
        if !(ext.w > 0 && ext.w <= maxExtentFactor * Double(imageWidth)
             && ext.h > 0 && ext.h <= maxExtentFactor * Double(imageHeight)
             && ext.w * ext.h <= maxExtentPixels) {
            return .rejected("extentTooLarge")
        }
        return .allowed
    }

    private static func cross(_ o: CGPoint, _ a: CGPoint,
                              _ b: CGPoint) -> Double {
        Double((a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x))
    }

    private static func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint,
                                          _ p3: CGPoint, _ p4: CGPoint)
        -> Bool {
        let d1 = cross(p3, p4, p1), d2 = cross(p3, p4, p2)
        let d3 = cross(p1, p2, p3), d4 = cross(p1, p2, p4)
        return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0))
    }

    static func isSimple(_ q: [CGPoint]) -> Bool {
        !segmentsIntersect(q[0], q[1], q[2], q[3])
            && !segmentsIntersect(q[1], q[2], q[3], q[0])
    }

    private static func isConvexConsistent(_ q: [CGPoint]) -> Bool {
        var sign = 0.0
        for i in 0..<4 {
            let c = cross(q[i], q[(i + 1) % 4], q[(i + 2) % 4])
            if c == 0 { return false }
            if sign == 0 { sign = c }
            else if (c > 0) != (sign > 0) { return false }
        }
        return true
    }

    private static func shoelace(_ q: [CGPoint]) -> Double {
        var s = 0.0
        for i in 0..<4 {
            let a = q[i], b = q[(i + 1) % 4]
            s += Double(a.x * b.y - b.x * a.y)
        }
        return s
    }

    /// Giải homography dst->src (Gauss–Jordan, pivot từng phần)
    /// — cổng của platform_gate.solve_homography.
    static func solveHomography(src: [CGPoint], dst: [CGPoint])
        -> [[Double]]? {
        var m: [[Double]] = []
        var v: [Double] = []
        for (s, d) in zip(src, dst) {
            let dx = Double(d.x), dy = Double(d.y)
            let sx = Double(s.x), sy = Double(s.y)
            m.append([dx, dy, 1, 0, 0, 0, -sx * dx, -sx * dy])
            v.append(sx)
            m.append([0, 0, 0, dx, dy, 1, -sy * dx, -sy * dy])
            v.append(sy)
        }
        let n = 8
        for col in 0..<n {
            var piv = col
            for r in col..<n where abs(m[r][col]) > abs(m[piv][col]) {
                piv = r
            }
            if abs(m[piv][col]) < 1e-12 { return nil }
            if piv != col {
                m.swapAt(col, piv)
                v.swapAt(col, piv)
            }
            for r in 0..<n where r != col && m[r][col] != 0 {
                let f = m[r][col] / m[col][col]
                for c in col..<n { m[r][c] -= f * m[col][c] }
                v[r] -= f * v[col]
            }
        }
        let h = (0..<n).map { v[$0] / m[$0][$0] }
        return [[h[0], h[1], h[2]], [h[3], h[4], h[5]], [h[6], h[7], 1.0]]
    }

    /// Extent của ảnh sau nắn: bao của 4 góc đích ánh xạ ngược
    /// về không gian nguồn (mô phỏng của platform_gate).
    static func mappedExtent(quad: [CGPoint]) -> (w: Double, h: Double)? {
        let xs = quad.map { $0.x }, ys = quad.map { $0.y }
        let dw = (xs.max()! - xs.min()!), dh = (ys.max()! - ys.min()!)
        if dw <= 0 || dh <= 0 { return nil }
        let dst = [CGPoint(x: 0, y: 0), CGPoint(x: CGFloat(dw), y: 0),
                   CGPoint(x: CGFloat(dw), y: CGFloat(dh)),
                   CGPoint(x: 0, y: CGFloat(dh))]
        guard let H = solveHomography(src: quad, dst: dst) else {
            return nil
        }
        var pts: [(Double, Double)] = []
        for d in dst {
            let dx = Double(d.x), dy = Double(d.y)
            let w = H[2][0] * dx + H[2][1] * dy + H[2][2]
            if w == 0 || !w.isFinite { return nil }
            let x = (H[0][0] * dx + H[0][1] * dy + H[0][2]) / w
            let y = (H[1][0] * dx + H[1][1] * dy + H[1][2]) / w
            if !x.isFinite || !y.isFinite { return nil }
            pts.append((x, y))
        }
        let ex = pts.map { $0.0 }.max()! - pts.map { $0.0 }.min()!
        let ey = pts.map { $0.1 }.max()! - pts.map { $0.1 }.min()!
        return (ex, ey)
    }
}

private extension CGPoint {
    static func - (a: CGPoint, b: CGPoint) -> CGPoint {
        CGPoint(x: a.x - b.x, y: a.y - b.y)
    }
    var length: Double {
        Double(sqrt(x * x + y * y))
    }
}

// MARK: - Cổng chất lượng 3 quyết định + QualityMap có vị trí

struct QualitySignals {
    var blurVariance: Double    // phương sai Laplacian vùng tờ (ĐÃ chuẩn hoá)
    var glareFraction: Double   // tỉ lệ điểm ảnh cháy sáng TRONG vùng tờ
    var localContrast: Double   // trung bình độ lệch chuẩn theo dải ngang, vùng tờ
    /// G4: true khi vùng tờ không xác định được (ảnh đều màu /
    /// mực ngoài miền hợp lệ) và phép đo lùi về TOÀN KHUNG —
    /// ghi ra để số đo không giả vờ là đo-trên-vùng khi không phải.
    var regionFallback: Bool = false
}

/// G4 — NGƯỠNG CỔNG = DỮ LIỆU CÓ PHIÊN BẢN (quality-thresholds.json
/// kèm bundle; nạp hỏng/vắng mặt -> bản `fallback` biên dịch sẵn
/// mang ĐÚNG cùng bộ số, nên hành vi không đổi theo môi trường).
/// Thay bộ hằng giữ chỗ của Pha 2 (blurMin 100.0 "CHỜ ĐO ở Pha
/// 2b", glareMax 0.05, contrastMin 0.25) — phiên hiệu chuẩn
/// 2026-11-15 (g4/calibration/) đã chỉ ra hai lỗi của bộ cũ:
/// (1) LỆCH THANG ĐƠN VỊ: 100.0 chỉ hợp thang mẫu BYTE 0..255
/// (phương sai lớn hơn thang 0..1 đúng 255^2 lần) trong khi
/// LuminanceGrid nạp mẫu theo thang 0..1 — trên corpus 43 ảnh,
/// cổng cũ gắn cờ mờ cho 43/43 và sẽ CHẶN 11/11 tờ khép sổ sạch;
/// đó là gốc đo của vụ chặn oan tờ mới tinh ngày 2026-11-15.
/// (2) Số chưa từng qua một phiên đo nào (M-5 chưa từng chạy).
/// Bộ số dưới đây đo trên 43 ảnh BenchImages, nhãn = kết quả
/// đóng sổ E1/E2/E3 thật của bộ đọc v4 (làn luồng DEVICE-A0,
/// run #30): cảnh báo oan trên 11 tờ khép sổ sạch = 0/11 (0%,
/// trong ngân sách <= 2% anh duyệt). Đơn vị blurMin: phương sai
/// Laplacian trên mẫu 0..1, đo trong vùng tờ, ĐÃ nhân hệ số
/// chuẩn hoá factor^blurScaleExponent.
struct QualityThresholds {
    /// Phiên bản bộ số đang biên dịch trong code — PHẢI khớp
    /// dataVersion trong quality-thresholds.json; lệch nhau là
    /// lỗi đóng gói, bản fallback vẫn thắng theo bộ số này.
    static let compiledDataVersion = "quality-gate-v4-calibrated-2026-11-15"

    var dataVersion = QualityThresholds.compiledDataVersion
    var warnEnabled = true
    // G4 (luật anh duyệt trong chương trình G1–G5): .block HẠ
    // XUỐNG .warn cho tới khi có số hiệu chuẩn đạt ngân sách
    // chặn oan <= 2% VÀ anh duyệt bật lại. Bộ số hiệu chuẩn
    // 2026-11-15 đạt ngân sách CẢNH BÁO oan 0% nhưng độ nhạy
    // trên các ca đọc-không-khép là 0/4 (các ca đó hỏng ở tầng
    // token/in ấn, cổng chất lượng chụp không nhìn thấy) —
    // chưa đủ tư cách chặn cứng, nên blockEnabled giữ false.
    // (Lịch sử: V4-4/D-V4-2 từng bật true trên ngưỡng giữ chỗ.)
    var blockEnabled = false
    var blurMin = 0.008         // min lớp TỐT đo được 0.0132, lề x0.6
    var glareMax = 0.88         // max lớp TỐT đo được 0.79, lề +0.09
    var contrastMin = 0.12      // min lớp TỐT đo được 0.174, lề x0.69
    var maxConsecutiveRejects = 3
    /// Số mũ chuẩn hoá hạ mẫu: blur = blurThô x factor^k,
    /// factor = cạnh dài ảnh gốc / cạnh dài lưới (>= 1). Đo
    /// hồi quy log-log trên 12 ảnh thật x 5 mức hạ mẫu
    /// (g4/calibration): k các ca -0.84..0.46, trung vị 0.10 —
    /// chữ nhiệt gần hai mức sáng nên phương sai Laplacian gần
    /// như không phụ thuộc tỉ lệ hạ mẫu trong miền factor
    /// 2..27 của corpus; k = 0.10 là giá trị ĐO ĐƯỢC, không
    /// phải hằng lý thuyết. Gate D trên máy anh sẽ đo lại.
    var blurScaleExponent = 0.10

    /// Bộ số nạp từ quality-thresholds.json trong bundle; nil
    /// khi file vắng/hỏng/sai phiên bản (harness CLI trước khi
    /// workflow chép file cạnh binary cũng rơi vào nhánh này).
    private static let bundled: QualityThresholds? = {
        guard let url = Bundle.main.url(forResource: "quality-thresholds",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(QualityThresholds.self,
                                                      from: data),
              decoded.dataVersion == QualityThresholds.compiledDataVersion
        else { return nil }
        return decoded
    }()

    /// Ngưỡng hiệu lực hiện hành: dữ liệu bundle khi nạp được,
    /// ngược lại bản biên dịch sẵn (cùng bộ số theo luật trên).
    static func current() -> QualityThresholds {
        bundled ?? QualityThresholds()
    }
}

extension QualityThresholds: Decodable {
    enum CodingKeys: String, CodingKey {
        case dataVersion, warnEnabled, blockEnabled, blurMin,
             glareMax, contrastMin, maxConsecutiveRejects,
             blurScaleExponent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        dataVersion = try c.decodeIfPresent(String.self,
                        forKey: .dataVersion) ?? dataVersion
        warnEnabled = try c.decodeIfPresent(Bool.self,
                        forKey: .warnEnabled) ?? warnEnabled
        blockEnabled = try c.decodeIfPresent(Bool.self,
                        forKey: .blockEnabled) ?? blockEnabled
        blurMin = try c.decodeIfPresent(Double.self,
                        forKey: .blurMin) ?? blurMin
        glareMax = try c.decodeIfPresent(Double.self,
                        forKey: .glareMax) ?? glareMax
        contrastMin = try c.decodeIfPresent(Double.self,
                        forKey: .contrastMin) ?? contrastMin
        maxConsecutiveRejects = try c.decodeIfPresent(Int.self,
                        forKey: .maxConsecutiveRejects)
            ?? maxConsecutiveRejects
        blurScaleExponent = try c.decodeIfPresent(Double.self,
                        forKey: .blurScaleExponent) ?? blurScaleExponent
    }
}

enum QualityDecision: String {
    case pass, warn, block
}

struct QualityOutcome {
    var detected: [String]
    var decision: QualityDecision
    /// Di sản tiền-G4: fail-safe cũ (cho qua lặng sau 3 lần từ
    /// chối liên tiếp). Từ G4 vai trò đó đổi thành LEO THANG
    /// CẢNH BÁO (trường `escalated`) — trường này giữ cho DTO
    /// (QualityOutcomeDTO) tương thích, luôn false ở kết quả mới.
    var failSafe: Bool
    var consecutiveRejects: Int
    /// G4: true khi đây là lượt có-vấn-đề thứ
    /// maxConsecutiveRejects liên tiếp — cảnh báo được LEO
    /// THANG (chữ mạnh hơn ở ScanView) và bộ đếm đặt lại.
    var escalated: Bool = false
}

/// Kho đếm lượt từ chối liên tiếp của cổng — G4: bộ đếm phải
/// BỀN QUA CÁC LƯỢT ĐỌC. Lỗi đã kết tội ở bản cũ: từ V4-4 mỗi
/// lần đọc tạo một QualityGate MỚI và evaluate chỉ được gọi 1
/// lần cho mỗi instance, nên bộ đếm trong bộ nhớ không bao giờ
/// tới 3 — chốt chống-khoá là MÃ CHẾT. Nay bộ đếm sống ở một
/// kho dùng chung tiêm vào cổng: bản app dùng kho bền
/// UserDefaults; test tiêm kho bộ nhớ để cô lập.
protocol QualityRejectCounterStore: AnyObject {
    func loadCount() -> Int
    func saveCount(_ value: Int)
}

/// Kho đếm trong bộ nhớ — cho test (harness) và nơi cần cô lập.
final class InMemoryQualityRejectCounter: QualityRejectCounterStore {
    private var value: Int
    init(_ initial: Int = 0) { value = initial }
    func loadCount() -> Int { value }
    func saveCount(_ newValue: Int) { value = newValue }
}

/// Kho đếm bền cho app: UserDefaults, khoá có phiên bản.
final class UserDefaultsQualityRejectCounter: QualityRejectCounterStore {
    static let shared = UserDefaultsQualityRejectCounter()
    static let key = "glkeeper.qualityGate.consecutiveRejects.v1"
    func loadCount() -> Int {
        UserDefaults.standard.integer(forKey: Self.key)
    }
    func saveCount(_ newValue: Int) {
        UserDefaults.standard.set(newValue, forKey: Self.key)
    }
}

/// Máy trạng thái cổng — phát hiện luôn chạy; cảnh báo/chặn là
/// hai quyết định riêng. Gương: QualityGate trong
/// capture_mirror.py (kiểm QG-*).
/// G4 — VAI TRÒ MỚI CỦA CHỐT CHỐNG-KHOÁ: bộ đếm lượt có-vấn-đề
/// LIÊN TIẾP nay bền qua các lượt đọc (kho tiêm ở trên). Khi
/// bộ đếm chạm maxConsecutiveRejects, cổng KHÔNG cho qua lặng
/// như fail-safe cũ và KHÔNG chặn cứng hơn: nó LEO THANG cảnh
/// báo (escalated = true — ScanView dùng chữ mạnh hơn, nhắc
/// chụp lại) rồi đặt bộ đếm về 0. Lý do đổi vai: ở chế độ chỉ
/// .warn, "cho qua lặng" sẽ nuốt mất tín hiệu duy nhất cổng có
/// (sự lặp lại của ảnh kém), còn chặn cứng thì chưa đủ tư cách
/// hiệu chuẩn (xem QualityThresholds). Lượt sạch (.pass) đặt
/// bộ đếm về 0 như cũ.
final class QualityGate {
    static var policyID: String {
        QualityThresholds.current().dataVersion
    }
    var thresholds: QualityThresholds
    private let counterStore: QualityRejectCounterStore
    private(set) var consecutiveRejects: Int

    init(thresholds: QualityThresholds = .current(),
         counterStore: QualityRejectCounterStore
            = UserDefaultsQualityRejectCounter.shared) {
        self.thresholds = thresholds
        self.counterStore = counterStore
        self.consecutiveRejects = counterStore.loadCount()
    }

    func evaluate(_ s: QualitySignals) -> QualityOutcome {
        var detected: [String] = []
        if s.blurVariance < thresholds.blurMin { detected.append("blur") }
        if s.glareFraction > thresholds.glareMax {
            detected.append("glare")
        }
        if s.localContrast < thresholds.contrastMin {
            detected.append("lowContrast")
        }
        if detected.isEmpty {
            counterStore.saveCount(0)
            consecutiveRejects = 0
            return QualityOutcome(detected: [], decision: .pass,
                                  failSafe: false, consecutiveRejects: 0)
        }
        let n = counterStore.loadCount() + 1
        if n >= thresholds.maxConsecutiveRejects {
            // LEO THANG (kế nhiệm fail-safe cũ — cùng vị trí
            // xét trước quyết định chặn như bản cũ): cảnh báo
            // mạnh hơn thay vì cho qua lặng; bộ đếm đặt lại để
            // không leo thang vô hạn trên cùng một chuỗi.
            counterStore.saveCount(0)
            consecutiveRejects = 0
            let decision: QualityDecision
                = thresholds.warnEnabled ? .warn : .pass
            return QualityOutcome(detected: detected, decision: decision,
                                  failSafe: false, consecutiveRejects: n,
                                  escalated: true)
        }
        counterStore.saveCount(n)
        consecutiveRejects = n
        let severe = detected.count >= 2
        let decision: QualityDecision
        if thresholds.blockEnabled && severe {
            decision = .block
        } else if thresholds.warnEnabled {
            decision = .warn
        } else {
            decision = .pass   // chế độ chỉ-phát-hiện
        }
        return QualityOutcome(detected: detected, decision: decision,
                              failSafe: false,
                              consecutiveRejects: n)
    }
}

/// Lưới độ sáng hạ mẫu của ảnh (hàng từ TRÊN xuống — không gian
/// ảnh; hộp Vision gốc-dưới được đổi khi lấy mẫu). Phần đo chất
/// lượng thuần trên lưới là gương-được; CGImage -> lưới là mã
/// thiết bị.
struct LuminanceGrid {
    var width: Int
    var height: Int
    var samples: [Double]       // 0..1, row-major từ trên
    /// G4: kích thước pixel của ẢNH GỐC trước hạ mẫu (0 = không
    /// rõ — lưới dựng tay trong test): hệ số hạ mẫu suy từ đây.
    var sourcePixelWidth: Int = 0
    var sourcePixelHeight: Int = 0

    /// Hệ số hạ mẫu: cạnh dài ảnh gốc / cạnh dài lưới, sàn 1.
    /// Đây là "kích thước/khổ tờ" mà blur thô phải chuẩn hoá
    /// theo — xem blurScaleExponent ở QualityThresholds.
    var downsampleFactor: Double {
        let src = max(sourcePixelWidth, sourcePixelHeight)
        let grid = max(width, height)
        guard src > 0, grid > 0 else { return 1 }
        return max(1, Double(src) / Double(grid))
    }

    /// TRAP-FIX A2-01 (rà soát vòng 2, 2026-11-13): chuẩn hoá
    /// một toạ độ hộp về miền an toàn [-1, 2] TRƯỚC mọi phép
    /// đổi Double->Int. Bản cũ đổi thẳng rồi mới kẹp bằng
    /// max/min — hộp hữu-hạn-khổng-lồ (dạng ca fuzz box-huge)
    /// hoặc NaN sẽ trap ngay trong Int(...), kẹp không kịp
    /// chạy. Hộp thật (Vision + ráp trang) sống quanh [0, 1]
    /// nên miền [-1, 2] không bao giờ chạm dữ liệu thật;
    /// toạ độ không hữu hạn -> 0.
    private func clampedCoord(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(2, max(-1, v))
    }

    func sampleRect(_ box: CGRect) -> [Double] {
        // Bất biến lưới (A2-01): producer fromImage dựng khớp,
        // nhưng chính hàm này phải tự vệ — subscript ở dưới
        // chỉ an toàn khi samples đủ width*height phần tử.
        guard samples.count == width * height else { return [] }
        // box: chuẩn hoá gốc-dưới -> vùng lưới gốc-trên.
        let bx0 = clampedCoord(Double(box.minX))
        let bx1 = clampedCoord(Double(box.maxX))
        let byTop = clampedCoord(Double(box.maxY))
        let byBot = clampedCoord(Double(box.minY))
        let x0 = max(0, Int(bx0 * Double(width)))
        let x1 = min(width, Int(ceil(bx1 * Double(width))))
        let yTop = max(0, Int((1 - byTop) * Double(height)))
        let yBot = min(height,
                       Int(ceil((1 - byBot) * Double(height))))
        if x1 <= x0 || yBot <= yTop { return [] }
        var out: [Double] = []
        for y in yTop..<yBot {
            for x in x0..<x1 {
                out.append(samples[y * width + x])
            }
        }
        return out
    }

    func laplacianVariance(_ box: CGRect) -> Double {
        // A2-01: cùng kỷ luật như sampleRect — bất biến lưới +
        // toạ độ qua clampedCoord trước khi đổi Int.
        guard samples.count == width * height else { return 0 }
        let bx0 = clampedCoord(Double(box.minX))
        let bx1 = clampedCoord(Double(box.maxX))
        let byTop = clampedCoord(Double(box.maxY))
        let byBot = clampedCoord(Double(box.minY))
        let x0 = max(1, Int(bx0 * Double(width)))
        let x1 = min(width - 1, Int(ceil(bx1 * Double(width))))
        let yTop = max(1, Int((1 - byTop) * Double(height)))
        let yBot = min(height - 1,
                       Int(ceil((1 - byBot) * Double(height))))
        if x1 <= x0 || yBot <= yTop { return 0 }
        var laps: [Double] = []
        for y in yTop..<yBot {
            for x in x0..<x1 {
                let c = samples[y * width + x]
                let l = samples[(y - 1) * width + x]
                    + samples[(y + 1) * width + x]
                    + samples[y * width + x - 1]
                    + samples[y * width + x + 1] - 4 * c
                laps.append(l)
            }
        }
        if laps.isEmpty { return 0 }
        let mean = laps.reduce(0, +) / Double(laps.count)
        return laps.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(laps.count)
    }

    /// G4: VÙNG TỜ trên lưới, suy từ chính lưới sáng theo
    /// ngưỡng Otsu, hai ưu tiên:
    ///   1. Mặt GIẤY (điểm SÁNG hơn ngưỡng): giấy là mảng sáng
    ///      liên tục của tờ; hộp bao của nó là hộp của chính tờ
    ///      (mực nằm trong đó tự nhiên). Dùng khi tỉ lệ giấy
    ///      trong [5%, 98%] và hộp >= 8x8 điểm lưới.
    ///   2. Mặt MỰC (điểm TỐI hơn ngưỡng): cho ảnh số/ảnh chụp
    ///      nền cũng trắng (giấy chiếm ~cả khung, ưu tiên 1
    ///      trượt): hộp bao chữ. Dùng khi tỉ lệ mực trong
    ///      [0.05%, 50%] và hộp >= 8x8.
    /// Cả hai đều nới lề 8% mỗi phía. Lùi về TOÀN KHUNG
    /// (fallback = true, khai rõ trong
    /// QualitySignals.regionFallback) khi lưới rỗng/hỏng bất
    /// biến, ngưỡng Otsu thoái hoá (<= 0 hoặc >= 255 — ảnh một
    /// màu), hoặc cả hai mặt đều ngoài miền hợp lệ. Đây là xấp
    /// xỉ an toàn nhất có được ở tầng lưới mà không cần thêm
    /// một lượt Vision, và nó loại nền/bàn khỏi phép đo — lỗi
    /// đo (a) đã kết tội ở bản cũ (đo toàn khung gồm cả phong
    /// cảnh ngoài tờ). Số kiểm chứng trên corpus ở
    /// g4/calibration/ (gương Python cùng thuật toán).
    func documentRegion() -> (x0: Int, y0: Int, x1: Int, y1: Int,
                              fallback: Bool) {
        let whole = (x0: 0, y0: 0, x1: width, y1: height, fallback: true)
        guard samples.count == width * height, width > 0, height > 0
        else { return whole }
        // Byte đã kẹp TRƯỚC khi đổi Double->Int (kỷ luật A2-01:
        // mẫu không hữu hạn tính là 0, không trap).
        func byteOf(_ v: Double) -> Int {
            v.isFinite ? min(255, max(0, Int((v * 255).rounded()))) : 0
        }
        var hist = [Int](repeating: 0, count: 256)
        for v in samples { hist[byteOf(v)] += 1 }
        let total = Double(samples.count)
        var sumAll = 0.0
        for i in 0..<256 { sumAll += Double(i) * Double(hist[i]) }
        // Otsu: cực đại phương sai GIỮA hai lớp sáng/tối.
        var sumB = 0.0, wB = 0.0, best = -1.0, threshold = 0
        for i in 0..<256 {
            wB += Double(hist[i])
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }
            sumB += Double(i) * Double(hist[i])
            let mB = sumB / wB
            let mF = (sumAll - sumB) / wF
            let between = wB * wF * (mB - mF) * (mB - mF)
            if between > best { best = between; threshold = i }
        }
        guard threshold > 0, threshold < 255 else { return whole }
        // Hộp bao [x0,x1) x [y0,y1) của một phía của ngưỡng
        // (bright = mặt giấy, !bright = mặt mực) + số điểm.
        // Hai phía bù nhau không hở: giấy là byte > ngưỡng,
        // mực là byte <= ngưỡng (ngưỡng Otsu là bin TRÊN CÙNG
        // của lớp tối — dùng < sẽ đánh rơi đúng bin đó).
        func boundingBox(bright: Bool)
            -> (x0: Int, y0: Int, x1: Int, y1: Int, count: Int) {
            var minX = width, minY = height, maxX = -1, maxY = -1
            var count = 0
            for y in 0..<height {
                for x in 0..<width {
                    let b = byteOf(samples[y * width + x])
                    if bright ? b > threshold : b <= threshold {
                        count += 1
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                    }
                }
            }
            if count == 0 { return (0, 0, 0, 0, 0) }
            return (minX, minY, maxX + 1, maxY + 1, count)
        }
        func expanded(_ b: (x0: Int, y0: Int, x1: Int, y1: Int,
                            count: Int))
            -> (x0: Int, y0: Int, x1: Int, y1: Int, fallback: Bool) {
            let boxW = b.x1 - b.x0, boxH = b.y1 - b.y0
            let mx = max(2, Int((0.08 * Double(boxW)).rounded()))
            let my = max(2, Int((0.08 * Double(boxH)).rounded()))
            return (max(0, b.x0 - mx), max(0, b.y0 - my),
                    min(width, b.x1 + mx), min(height, b.y1 + my),
                    false)
        }
        let paper = boundingBox(bright: true)
        let paperFraction = Double(paper.count) / total
        if paperFraction >= 0.05, paperFraction <= 0.98,
           paper.x1 - paper.x0 >= 8, paper.y1 - paper.y0 >= 8 {
            return expanded(paper)
        }
        let ink = boundingBox(bright: false)
        let inkFraction = Double(ink.count) / total
        if inkFraction >= 0.0005, inkFraction <= 0.50,
           ink.x1 - ink.x0 >= 8, ink.y1 - ink.y0 >= 8 {
            return expanded(ink)
        }
        return whole
    }

    /// Mẫu trong hộp lưới [x0,x1) x [y0,y1) (toạ độ lưới).
    private func gridSamples(x0: Int, y0: Int, x1: Int, y1: Int)
        -> [Double] {
        guard samples.count == width * height else { return [] }
        var out: [Double] = []
        for y in y0..<y1 {
            for x in x0..<x1 {
                out.append(samples[y * width + x])
            }
        }
        return out
    }

    /// Phương sai Laplacian trên phần trong (lùi 1px) của hộp
    /// lưới — cùng toán với laplacianVariance(_ box:) nhưng
    /// theo toạ độ lưới nguyên, không qua đổi hệ chuẩn hoá
    /// (đường hộp-Chữ-nhật của QualityMap giữ nguyên như cũ).
    private func laplacianVarianceInGrid(x0: Int, y0: Int,
                                         x1: Int, y1: Int) -> Double {
        guard samples.count == width * height,
              x1 - x0 >= 3, y1 - y0 >= 3 else { return 0 }
        var laps: [Double] = []
        for y in (y0 + 1)..<(y1 - 1) {
            for x in (x0 + 1)..<(x1 - 1) {
                let c = samples[y * width + x]
                let l = samples[(y - 1) * width + x]
                    + samples[(y + 1) * width + x]
                    + samples[y * width + x - 1]
                    + samples[y * width + x + 1] - 4 * c
                laps.append(l)
            }
        }
        if laps.isEmpty { return 0 }
        let mean = laps.reduce(0, +) / Double(laps.count)
        return laps.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(laps.count)
    }

    /// G4: tín hiệu cổng đo TRÊN VÙNG TỜ (documentRegion) thay
    /// vì toàn khung như bản cũ. Ba thay đổi so với bản cũ:
    /// (a) glare/contrast/blur đều tính trong vùng tờ — nền/bàn
    /// ngoài tờ không còn kéo số của tờ; (b) blur được CHUẨN
    /// HOÁ theo hệ số hạ mẫu: blur = blurThô x factor^k với
    /// k = blurScaleExponent của bộ ngưỡng (đo được ở phiên
    /// hiệu chuẩn 2026-11-15 — chữ hai mức sáng làm phương sai
    /// Laplacian gần như không đổi theo tỉ lệ hạ mẫu, k nhỏ);
    /// (c) localContrast thành tương phản cục bộ THẬT: trung
    /// bình độ lệch chuẩn của tối đa 8 dải ngang trong vùng
    /// (bản cũ là std toàn khung dù mang tên "local").
    func signals(thresholds: QualityThresholds = .current())
        -> QualitySignals {
        let region = documentRegion()
        let px = gridSamples(x0: region.x0, y0: region.y0,
                             x1: region.x1, y1: region.y1)
        let glare = px.isEmpty ? 0
            : Double(px.filter { $0 >= 0.97 }.count) / Double(px.count)
        let regionHeight = region.y1 - region.y0
        let bandCount = max(1, min(8, regionHeight))
        var bandSds: [Double] = []
        if regionHeight > 0 {
            for i in 0..<bandCount {
                let ya = region.y0 + i * regionHeight / bandCount
                let yb = region.y0 + (i + 1) * regionHeight / bandCount
                if yb <= ya { continue }
                let band = gridSamples(x0: region.x0, y0: ya,
                                       x1: region.x1, y1: yb)
                if band.isEmpty { continue }
                let mean = band.reduce(0, +) / Double(band.count)
                let sd = sqrt(band.reduce(0) {
                    $0 + ($1 - mean) * ($1 - mean)
                } / Double(band.count))
                bandSds.append(sd)
            }
        }
        let contrast = bandSds.isEmpty ? 0
            : bandSds.reduce(0, +) / Double(bandSds.count)
        let blurRaw = laplacianVarianceInGrid(x0: region.x0,
                                              y0: region.y0,
                                              x1: region.x1,
                                              y1: region.y1)
        let blur = blurRaw * pow(downsampleFactor,
                                 thresholds.blurScaleExponent)
        return QualitySignals(blurVariance: blur,
                              glareFraction: glare,
                              localContrast: contrast,
                              regionFallback: region.fallback)
    }

    /// Điểm vùng cho QualityMap: ánh xạ độ nét Laplacian sang
    /// 0..100. Hằng tham chiếu là CHỖ GIỮ HIỆU CHUẨN — đo lại
    /// ở Pha 2b trên ảnh thiết bị thật (MEASUREMENT-PROTOCOL).
    static let sharpnessReference = 400.0

    func qualityMapEntry(for box: CGRect,
                         thresholds: QualityThresholds)
        -> QualityMapEntry {
        let lap = laplacianVariance(box)
        let px = sampleRect(box)
        let glare = px.isEmpty ? 0
            : Double(px.filter { $0 >= 0.97 }.count) / Double(px.count)
        let mean = px.isEmpty ? 0 : px.reduce(0, +) / Double(px.count)
        let sd = px.isEmpty ? 0 : sqrt(px.reduce(0) {
            $0 + ($1 - mean) * ($1 - mean)
        } / Double(px.count))
        var defect: String? = nil
        if lap < thresholds.blurMin { defect = "blur" }
        else if glare > thresholds.glareMax { defect = "glare" }
        else if sd < thresholds.contrastMin { defect = "lowContrast" }
        let score = Int(min(100, max(0,
            lap / LuminanceGrid.sharpnessReference * 100)).rounded())
        return QualityMapEntry(
            box: DiagRect(x: Double(box.minX), y: Double(box.minY),
                          width: Double(box.width),
                          height: Double(box.height)),
            // PHA 4 (điểm nối, khuyết P4-D1): score vốn là Int ở
            // đây trong khi QualityMapEntry.score khai Double —
            // Swift không tự ép số -> lỗi biên dịch CI. Ép rõ
            // Double(...) giữ nguyên giá trị đã làm tròn.
            score: Double(score), suspectedDefect: defect)
    }

    /// Mã thiết bị: dựng lưới từ CGImage (hạ mẫu xám). Không
    /// gương — kiểm ở cổng CI + phiên đo Pha 2b.
    static func fromImage(_ image: CGImage, maxDimension: Int = 512)
        -> LuminanceGrid? {
        let scale = min(1.0, Double(maxDimension)
                        / Double(max(image.width, image.height)))
        let w = max(1, Int(Double(image.width) * scale))
        let h = max(1, Int(Double(image.height) * scale))
        var buf = [UInt8](repeating: 0, count: w * h)
        let cs = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w, space: cs,
            bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // CGContext vẽ gốc-dưới; samples cần hàng từ trên.
        var samples = [Double](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                samples[y * w + x] = Double(buf[(h - 1 - y) * w + x])
                    / 255.0
            }
        }
        // G4: ghi kích thước GỐC để downsampleFactor của lưới
        // suy được hệ số hạ mẫu thật (chuẩn hoá blur ở signals).
        return LuminanceGrid(width: w, height: h, samples: samples,
                             sourcePixelWidth: image.width,
                             sourcePixelHeight: image.height)
    }
}

// MARK: - Chọn ứng viên §3.6 (đo toàn vẹn cột tiền, thay yieldScore)

struct CandidateEvaluation {
    var e1Closed: Bool
    var e2Within2c: Bool
    var e3Closed: Bool
    var integrity: Double       // 0..1, đã trọng số QualityMap
    var hasSubtotal: Bool
    var hasTotal: Bool
    var hasTaxLine: Bool
    var hasDate: Bool
    var vendorResolved: Bool
    var itemsMissingAmount: Int
    var alnumChars: Int
    var isOriginal: Bool
}

enum CandidateScorer {
    /// Công thức §3.6 bản chốt — gương: score_candidate trong
    /// capture_mirror.py (kiểm SCORE-*).
    static func score(_ ev: CandidateEvaluation)
        -> (total: Double, components: [String: Double]) {
        let comp: [String: Double] = [
            "e1ExactClosure": ev.e1Closed ? 400 : 0,
            "e2Within2c": ev.e2Within2c ? 200 : 0,
            "e3ItemCount": ev.e3Closed ? 150 : 0,
            "moneyColumnIntegrity": 100 * ev.integrity,
            "hasSubtotal": ev.hasSubtotal ? 30 : 0,
            "hasTotal": ev.hasTotal ? 40 : 0,
            "hasTaxLine": ev.hasTaxLine ? 20 : 0,
            "hasDate": ev.hasDate ? 20 : 0,
            "vendorResolved": ev.vendorResolved ? 10 : 0,
            "itemsMissingAmountPenalty":
                -25 * Double(ev.itemsMissingAmount),
            "alnumTiebreak": 0.001 * Double(ev.alnumChars),
        ]
        return (comp.values.reduce(0, +), comp)
    }

    /// Hoà điểm -> bản gốc thắng; vẫn hoà -> chỉ số nhỏ hơn.
    static func pickWinner(_ evals: [CandidateEvaluation]) -> Int {
        let totals = evals.map { score($0).total }
        let best = totals.max()!
        let tied = totals.indices.filter { totals[$0] == best }
        for i in tied where evals[i].isOriginal { return i }
        return tied.min()!
    }

    /// Dải cột tiền: mode của mép phải các dòng có token tiền
    /// (bin 1%), dải [mode−12%, mode+2%] — cùng mô hình cột của
    /// F4 Pha 1.
    static func moneyColumnBand(_ lines: [AssembledLine])
        -> (lo: Double, hi: Double)? {
        var edges: [Double] = []
        for l in lines where !SafeMoney.tokens(in: l.text).isEmpty {
            // TRAP-FIX (khoá bin): chỉ giữ cạnh hữu hạn — cạnh
            // NaN/inf vào Int((e/0.01)...) ở vòng bin dưới là
            // trap; rỗng hết thì edges.isEmpty ở dưới trả nil.
            let e = Double(l.box.maxX)
            if e.isFinite { edges.append(e) }
        }
        if edges.isEmpty { return nil }
        var bins: [Int: [Double]] = [:]
        for e in edges {
            // TRAP-FIX (họ A, dạng hữu-hạn-khổng-lồ — site
            // song sinh của columnModel ở Parser, cùng ca fuzz
            // box-huge-maxx-moneyline): kiểm MIỀN khoá bin
            // trước khi đổi Double->Int (|khoá| < 2^63).
            let scaled = (e / 0.01).rounded(.toNearestOrEven)
            guard scaled.isFinite,
                  abs(scaled) < 9_223_372_036_854_775_808.0
            else { continue }
            bins[Int(scaled), default: []].append(e)
        }
        // Mọi cạnh đều ngoài miền -> không có bin nào: trả
        // nil thay vì ép mở max trên tập rỗng.
        if bins.isEmpty { return nil }
        let mode = bins.values.max(by: { $0.count < $1.count })!
        let m = mode.reduce(0, +) / Double(mode.count)
        return (m - 0.12, m + 0.02)
    }

    /// Ranh vùng tổng — cùng điều kiện phá vòng của F4
    /// (totals_boundary trong port_f4_mirror).
    static func totalsBoundary(_ lines: [AssembledLine]) -> Int {
        for (i, l) in lines.enumerated() {
            let u = l.text.uppercased()
            if u.hasPrefix("SUBTOTAL") || u.hasPrefix("TOTAL")
                || u.hasPrefix("SALES TAX") || u.hasPrefix("TAX")
                || u.contains("RETURN POLICY")
                || u.contains("MAX REFUND VALUE")
                || u.contains("SUGGESTED TIP")
                || u.contains("TIP GUIDE") {
                return i
            }
        }
        return lines.count
    }

    static func qualityAt(_ box: CGRect,
                          in map: [QualityMapEntry]) -> Int {
        var best = 100
        var bestIoU = 0.0
        for e in map {
            let r = CGRect(x: e.box.x, y: e.box.y,
                           width: e.box.width, height: e.box.height)
            let v = LineAssembly.iou(box, r)
            if v > bestIoU { bestIoU = v; best = Int(e.score) }
        }
        return best
    }

    /// Độ toàn vẹn cột tiền: trên các dòng vùng món CÓ token
    /// tiền — tỉ lệ có trọng số mà token tiền cuối hợp lệ
    /// SafeMoney và mép phải nằm trong dải cột. Trọng số dòng =
    /// 1 + (1 − điểm-vùng/100): dòng ở vùng xấu đếm nặng hơn
    /// (ràng buộc OPEN-F3-2). Gương: integrity() trong
    /// capture_mirror.py (kiểm INT-*).
    static func integrity(_ lines: [AssembledLine],
                          qualityMap: [QualityMapEntry] = []) -> Double {
        guard let band = moneyColumnBand(lines) else { return 0 }
        let boundary = totalsBoundary(lines)
        var num = 0.0, den = 0.0
        for l in lines[..<boundary] {
            let toks = SafeMoney.tokens(in: l.text)
            guard let last = toks.last else { continue }
            let ok = SafeMoney.parseCents(last.token,
                                          negative: last.negative) != nil
                && band.lo <= Double(l.box.maxX)
                && Double(l.box.maxX) <= band.hi
            var w = 1.0
            if !qualityMap.isEmpty {
                w = 1.0 + (1.0 - Double(qualityAt(l.box,
                                                  in: qualityMap)) / 100)
            }
            den += w
            if ok { num += w }
        }
        return den > 0 ? num / den : 0
    }
}

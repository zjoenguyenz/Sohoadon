import SwiftUI
import SwiftData
import UIKit

// MARK: - Phân loại Cá nhân / Business / Chưa rõ

/// Phân loại của hoá đơn và của thẻ. Lưu trong SwiftData dưới dạng rawValue (String)
/// để tránh phụ thuộc vào kiểu enum trong tầng lưu trữ.
enum Classification: String, CaseIterable {
    case personal
    case business
    case unknown

    var label: String {
        switch self {
        case .personal: return "CÁ NHÂN"
        case .business: return "BUSINESS"
        case .unknown:  return "CHƯA RÕ"
        }
    }

    var iconName: String {
        switch self {
        case .personal: return "person.fill"
        case .business: return "briefcase.fill"
        case .unknown:  return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .personal: return Theme.personalColor
        case .business: return Theme.businessColor
        case .unknown:  return Color.gray
        }
    }
}

// MARK: - Màu theo DESIGN-V2 (4 tín hiệu: màu + icon + chữ + badge đuôi thẻ)

enum Theme {
    /// Cá nhân — xanh dương #005EB8
    static let personalColor = Color(red: 0.0, green: 94.0 / 255.0, blue: 184.0 / 255.0)
    /// Business — cam đất #9A4A00
    static let businessColor = Color(red: 154.0 / 255.0, green: 74.0 / 255.0, blue: 0.0)
}

// MARK: - Danh mục khởi điểm (BLUEPRINT mục 5 — bám Schedule C cho business)

enum Categories {
    static let business: [String] = [
        "Vật Tư (Supplies)",
        "Hàng Hoá/Giá Vốn (Inventory/COGS)",
        "Thiết Bị (Equipment)",
        "Ăn Uống (Meals)",
        "Đi Lại (Travel)",
        "Xe & Xăng (Vehicle/Fuel)",
        "Văn Phòng (Office)",
        "Phần Mềm (Software)",
        "Điện Nước/Internet (Utilities)",
        "Khác (Other)"
    ]
    static let personal: [String] = [
        "Đi Chợ",
        "Nhà Cửa",
        "Y Tế",
        "Khác"
    ]
    static func list(for kind: Classification) -> [String] {
        switch kind {
        case .business: return business
        case .personal: return personal
        case .unknown:  return business + personal
        }
    }
    static func defaultValue(for kind: Classification) -> String {
        switch kind {
        case .business: return "Khác (Other)"
        case .personal: return "Khác"
        case .unknown:  return "Khác (Other)"
        }
    }
}

// MARK: - Trạng thái duyệt

enum ReceiptStatus: String {
    case needsReview
    case reviewed
}

// MARK: - Mô hình dữ liệu (SwiftData)
// Tiền lưu bằng CENT (Int) — chính xác tới từng cent, không dùng số thập phân lưu trữ.

@Model
final class Receipt {
    var vendor: String = ""
    var date: Date = Date()
    var subtotalCents: Int? = nil
    var taxCents: Int? = nil
    var totalCents: Int? = nil
    var cardLast4: String? = nil
    var cardBrand: String? = nil
    /// Classification.rawValue — phần phân loại RIÊNG của hoá đơn này (snapshot lúc xếp).
    /// Sửa thẻ về sau KHÔNG tự đổi giá trị này, trừ khi anh chọn "xếp lại hoá đơn cũ".
    var classificationRaw: String = Classification.unknown.rawValue
    /// Lý do gợi ý lúc phân loại, vd "Thẻ •• 2586 — đã đăng ký Business".
    var classificationReason: String = ""
    var category: String = ""
    /// Ghi chú mục đích business (sở thuế cần: mua để làm gì).
    var businessPurpose: String = ""
    /// Khoá chống trùng theo tiệm (Sam's = TC#). nil = chưa có khoá tin cậy.
    var dedupeKey: String? = nil
    /// Độ tin cậy OCR từng trường, 0.0–1.0 (0 = không có thông tin).
    var vendorConfidence: Double = 0
    var dateConfidence: Double = 0
    var totalConfidence: Double = 0
    /// Tên file ảnh gốc trong thư mục Documents/ReceiptImages của app.
    var imageFileName: String = ""
    var createdAt: Date = Date()
    /// ReceiptStatus.rawValue
    var statusRaw: String = ReceiptStatus.needsReview.rawValue
    /// Toàn văn OCR — phục vụ tìm kiếm full-text và kiểm tra lại khi cần.
    var ocrRawText: String = ""

    @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
    var items: [LineItem] = []

    init() {}

    var classification: Classification {
        get { Classification(rawValue: classificationRaw) ?? .unknown }
        set { classificationRaw = newValue.rawValue }
    }
    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .needsReview }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class LineItem {
    var name: String = ""
    var qty: Int = 1
    var unitPriceCents: Int? = nil
    var amountCents: Int? = nil
    /// Cờ thuế cuối dòng hoá đơn (Sam's: Y / T). Chỉ là dữ kiện in trên giấy, không tự suy thuế.
    var taxFlag: String? = nil
    var itemCode: String? = nil
    var sortIndex: Int = 0
    var receipt: Receipt? = nil

    init() {}
}

@Model
final class CardTail {
    /// Đúng 4 chữ số cuối. Không bao giờ lưu số thẻ đầy đủ.
    var last4: String = ""
    var brand: String = ""
    /// Classification.rawValue — chỉ dùng .personal / .business.
    var kindRaw: String = Classification.unknown.rawValue
    /// Thẻ ngưng dùng: giữ lại để hoá đơn cũ vẫn tra đúng, không xoá.
    var archived: Bool = false
    var createdAt: Date = Date()

    init() {}

    var kind: Classification {
        get { Classification(rawValue: kindRaw) ?? .unknown }
        set { kindRaw = newValue.rawValue }
    }
}

// MARK: - Gợi ý phân loại theo đuôi thẻ (gợi ý MẠNH, không phải phán quyết)

/// Trả về (loại gợi ý, câu lý do hiện cho anh thấy kèm nút Đổi).
/// Thẻ đã ngưng (archived) vẫn được tra — hoá đơn sót của thẻ cũ vẫn xếp đúng.
func suggestClassification(cardLast4: String?, cardBrand: String?, tails: [CardTail]) -> (Classification, String) {
    guard let last4 = cardLast4, !last4.isEmpty else {
        return (.unknown, "Không đọc được đuôi thẻ (tiền mặt hoặc dòng thẻ bị mờ) — anh chọn giúp")
    }
    // Ưu tiên thẻ đang dùng; không có thì tới thẻ đã ngưng.
    let active = tails.first { $0.last4 == last4 && !$0.archived }
    let archived = tails.first { $0.last4 == last4 && $0.archived }
    if let card = active ?? archived {
        let suffix = card.archived ? " (thẻ đã ngưng dùng)" : ""
        return (card.kind, "Thẻ •• \(last4) — đã đăng ký \(card.kind.label)\(suffix)")
    }
    let brandText = (cardBrand?.isEmpty == false) ? "\(cardBrand!) " : ""
    return (.unknown, "Thẻ \(brandText)•• \(last4) chưa đăng ký — anh chọn giúp")
}

// MARK: - Định dạng tiền

/// 21680 -> "$216.80"
func formatMoney(cents: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
}

func formatMoney(optionalCents cents: Int?) -> String {
    guard let cents = cents else { return "—" }
    return formatMoney(cents: cents)
}

/// "216.80" -> 21680 ; không đọc được -> nil
func dollarsTextToCents(_ text: String) -> Int? {
    let cleaned = text
        .replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespaces)
    guard !cleaned.isEmpty else { return nil }
    let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
    if parts.count == 1, let dollars = Int(parts[0]) {
        return dollars * 100
    }
    guard parts.count == 2, let dollars = Int(parts[0]) else { return nil }
    var frac = String(parts[1])
    if frac.isEmpty { frac = "00" }
    if frac.count == 1 { frac += "0" }
    if frac.count > 2 { frac = String(frac.prefix(2)) }
    guard let cents = Int(frac) else { return nil }
    return dollars * 100 + cents
}

/// 21680 -> "216.80" (để nạp vào ô sửa tiền)
func centsToDollarsText(_ cents: Int?) -> String {
    guard let cents = cents else { return "" }
    let sign = cents < 0 ? "-" : ""
    let absCents = abs(cents)
    return "\(sign)\(absCents / 100).\(String(format: "%02d", absCents % 100))"
}

// MARK: - Kho ảnh gốc (Documents/ReceiptImages — thư mục riêng của app)

/// Build 1: ảnh chỉ lưu trong thư mục của app (hiện trong Files → Trên iPhone → Sổ Hóa Đơn
/// nhờ UIFileSharingEnabled). KHÔNG dùng fileImporter chọn thư mục ngoài — trên máy anh
/// (iOS 27.2) đường đó tự huỷ im lặng khi chọn thư mục của chính app (Test 0 đã kiểm chứng).
enum ImageStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ReceiptImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func saveJPEG(_ image: UIImage, quality: CGFloat = 0.8) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return name
        } catch {
            return nil
        }
    }

    static func load(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(fileName: String) {
        guard !fileName.isEmpty else { return }
        let url = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

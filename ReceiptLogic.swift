import Foundation

// MARK: - G1: logic điều kiện THUẦN tách khỏi tầng giao diện
//
// Gói G1 (chương trình triệt để, LEADER-SYNTHESIS §3-G1): các
// hàm quyết định trước đây nằm trong ReceiptViews.swift (file
// SwiftUI) nên KHÔNG cổng kiểm chứng nào thực thi được — harness
// không biên dịch file view, kiểm tĩnh không chạy hành vi. Ba ca
// đã lọt ra máy anh vì đúng lỗ hổng này: L-2026-11-13-17 (nút Đọc
// lại chỉ bấm được 1 lần — điều kiện canReparse), L-2026-11-13-20
// (cờ mục đích không tắt được), ca "Thiếu ảnh gốc" (điều kiện
// receiptHasOriginalImage).
//
// File này CHỈ phụ thuộc Foundation: không SwiftUI, không
// SwiftData, không UIKit. ReceiptViews giữ các hàm bọc mỏng cùng
// tên cũ (receiptFlags / receiptHasOriginalImage / canReparse)
// để mọi điểm gọi trong app KHÔNG đổi; thân hàm thật nằm ở đây
// và được harness chạy bằng Swift thật ở chế độ `unittests`.
//
// KỶ LUẬT: tách NGUYÊN VĂN, không đổi hành vi — bảng đối chiếu
// trước/sau ở g1/BEHAVIOR-DIFF.md. Sửa logic ở đây từ nay phải
// qua cổng unittests trước khi giao.

// MARK: - Định dạng tiền (chuyển nguyên văn từ Models.swift)
//
// formatMoney ở đây vì receiptFlags cần nó để sinh chữ cờ, mà
// Models.swift (SwiftData/UIKit) không vào được harness. Cùng
// module app nên mọi điểm gọi cũ (HomeView / DesignSystem /
// ReceiptViews) không đổi một chữ.

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

// MARK: - Chữ cờ dùng chung

/// L-2026-11-13-20: chữ cờ "thiếu mục đích" dùng chung giữa hàm
/// sinh cờ và màn Chi Tiết — màn Chi Tiết nhận ra đúng cờ này để
/// gắn Ô NHẬP MỤC ĐÍCH ngay dưới cảnh báo (cờ tự phục vụ), thay
/// vì bắt anh tự tìm ô nhập ở mục Phân loại phía dưới.
let missingPurposeFlagText = "Thiếu mục đích business — sở thuế hay soi điểm này"

/// Chữ cờ thiếu ảnh gốc (IMGFIX) — hằng số để test khoá đúng
/// nguyên văn như missingPurposeFlagText.
let missingOriginalImageFlagText = "Thiếu ảnh gốc — cần gắn lại để đủ bằng chứng"

// MARK: - Đầu vào thuần cho bộ sinh cờ

/// Phân loại ở dạng thẻ thuần — ReceiptLogic không biết
/// Classification của Models.swift (file đó dính SwiftData);
/// tầng bọc ở ReceiptViews ánh xạ 1-1 sang thẻ này.
enum ReceiptKindTag: Equatable {
    case personal
    case business
    case unknown
}

/// Mọi dữ kiện receiptFlags cần, dạng giá trị thuần. Tầng bọc
/// trích từ Receipt (SwiftData) + kết quả kiểm file ảnh; bộ cờ
/// sinh ra chỉ phụ thuộc các trường này — test nạp trực tiếp
/// không cần SwiftData.
struct ReceiptFlagInput: Equatable {
    var subtotalCents: Int?
    /// amountCents của từng dòng món theo thứ tự bản ghi
    /// (nil = dòng không có tiền — tính 0 như bản gốc).
    var itemAmountCents: [Int?]
    var totalCents: Int?
    /// Đúng trường taxCents của bản ghi (KHÔNG phải
    /// taxTotalCents) — giữ nguyên văn lựa chọn của bản gốc.
    var taxCents: Int?
    var kind: ReceiptKindTag
    var businessPurpose: String
    var hasOriginalImage: Bool
}

// MARK: - Bộ logic thuần

enum ReceiptLogic {

    /// L-2026-11-13-17: Đọc lại là đường sửa số đứng (Điều 2
    /// B2) — còn văn bản thô đã lưu là còn bấm được; KHÔNG cổng
    /// tem bộ đọc, KHÔNG cổng trạng thái duyệt. Nguyên văn điều
    /// kiện cũ: `!receipt.ocrRawText.isEmpty` (không cắt trắng:
    /// chuỗi chỉ gồm ký tự xuống dòng vẫn tính là còn văn bản,
    /// đúng hành vi trước tách).
    static func canReparse(ocrRawText: String) -> Bool {
        !ocrRawText.isEmpty
    }

    /// IMGFIX: chỉ cần MỘT tên file trong danh sách gốc tải
    /// được là bằng chứng còn. Hàm nạp (ImageStore.load ở app /
    /// hàm giả ở test) do nơi gọi cấp — logic "contains" thuần
    /// nằm ở đây để kiểm được.
    static func hasLoadableOriginal(fileNames: [String],
                                    isLoadable: (String) -> Bool) -> Bool {
        fileNames.contains(where: isLoadable)
    }

    /// Bộ cờ "Cần kiểm lại" của một hoá đơn đã lưu — chuyển
    /// NGUYÊN VĂN từ receiptFlags trong ReceiptViews.swift,
    /// giữ đúng thứ tự cờ và đúng ngưỡng ±2 xu.
    static func flags(for input: ReceiptFlagInput) -> [String] {
        var flags: [String] = []
        if let subtotal = input.subtotalCents, !input.itemAmountCents.isEmpty {
            let sum = input.itemAmountCents.reduce(0) { $0 + ($1 ?? 0) }
            if abs(sum - subtotal) > 2 {
                flags.append("Tổng các món (\(formatMoney(cents: sum))) khác subtotal (\(formatMoney(cents: subtotal)))")
            }
        }
        if let subtotal = input.subtotalCents, let total = input.totalCents {
            let tax = input.taxCents ?? 0
            if abs(subtotal + tax - total) > 2 {
                flags.append("Subtotal + thuế khác tổng tiền")
            }
        }
        if input.totalCents == nil {
            flags.append("Thiếu tổng tiền")
        }
        if input.kind == .business && input.businessPurpose.trimmingCharacters(in: .whitespaces).isEmpty {
            flags.append(missingPurposeFlagText)
        }
        if input.kind == .unknown {
            flags.append("Chưa phân loại Cá nhân / Business")
        }
        // IMGFIX: ảnh gốc là bằng chứng BẮT BUỘC (trình
        // accountant) — tờ không còn file gốc nào tải được phải
        // kêu thành cờ trong khu "Cần kiểm lại", không được im
        // lặng như trước (bài học tờ Home Depot 2026-11-10: số
        // đã đúng hết mà ảnh gốc mất không ai hay).
        if !input.hasOriginalImage {
            flags.append(missingOriginalImageFlagText)
        }
        return flags
    }
}

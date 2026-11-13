import SwiftUI

// ============================================================
// DESIGN SYSTEM — UI-2026-11-13 (anh duyệt hướng thiết kế lại
// theo chuẩn các app top cùng dịch vụ: Veryfi / Expensify /
// QuickBooks / Dext).
//
// LUẬT CỦA FILE NÀY: chỉ chứa HẰNG SỐ TRÌNH BÀY + COMPONENT
// HIỂN THỊ THUẦN. Không logic nghiệp vụ, không đọc/ghi dữ
// liệu — mọi màn hình dùng chung token ở đây để giao diện là
// MỘT hệ thống, không phải từng màn tự chế một kiểu.
// ============================================================

enum DS {
    // MARK: Màu

    /// Màu thương hiệu — xanh ngọc lục bảo: tiền bạc, tăng
    /// trưởng, dùng cho hành động chính + điểm nhấn.
    static let brand = Color(red: 0.13, green: 0.75, blue: 0.45)
    /// Cảnh báo / chờ duyệt.
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.04)
    /// Lỗi / xoá.
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.30)

    /// Nền thẻ trên nền tối — trắng mờ 2 lớp (fill + viền).
    static let cardFill = Color.white.opacity(0.055)
    static let cardStroke = Color.white.opacity(0.09)

    // MARK: Khoảng cách & bo góc (thang 4)

    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24

    static let radiusCard: CGFloat = 16
    static let radiusTile: CGFloat = 12
    static let radiusThumb: CGFloat = 10
}

// MARK: - Thẻ bề mặt chuẩn

/// Nền thẻ thống nhất: fill mờ + viền tóc + bo 16. Áp cho
/// các khối nội dung tự dựng (ngoài List) ở Home/Chi tiết.
struct DSCard: ViewModifier {
    var radius: CGFloat = DS.radiusCard
    func body(content: Content) -> some View {
        content
            .background(DS.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func dsCard(radius: CGFloat = DS.radiusCard) -> some View {
        modifier(DSCard(radius: radius))
    }
}

// MARK: - Huy hiệu trạng thái (chấm + chữ, nền nhuộm mờ)

struct StatusChip: View {
    var text: String
    var color: Color
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.bold))
                .tracking(0.3)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

// MARK: - Monogram tiệm (vòng tròn chữ cái đầu, màu suy từ tên)

/// Ảnh đại diện cho tiệm khi dòng danh sách không tải được
/// ảnh hoá đơn: hai chữ cái đầu + màu nền xác định theo tên
/// (cùng tên -> cùng màu, ổn định giữa các lần mở app).
struct VendorMonogram: View {
    var vendor: String
    var size: CGFloat = 44

    private var initials: String {
        let words = vendor.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    private var hue: Double {
        var hash = 0
        for scalar in vendor.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        return Double(hash % 360) / 360.0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hue: hue, saturation: 0.45, brightness: 0.55))
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Nút hành động chính (Lưu / Quét) — full width, bo 14

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = DS.brand
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
    }
}

// MARK: - Số tiền chuẩn (căn phải, số đều cột, semibold)

struct MoneyAmount: View {
    var cents: Int?
    var font: Font = .body.weight(.semibold)

    var body: some View {
        Text(formatMoney(optionalCents: cents))
            .font(font)
            .monospacedDigit()
    }
}

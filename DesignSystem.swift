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

    /// Nền thẻ trên nền sâu (PASS 2 — mẫu anh duyệt 2026-11-13):
    /// thẻ là xanh-đen đặc #101C16 + viền #1D2F26, không còn
    /// trắng mờ của pass 1.
    static let cardFill = Color(red: 0.063, green: 0.110, blue: 0.086)
    static let cardStroke = Color(red: 0.114, green: 0.184, blue: 0.149)

    /// Nền màn hình sâu 2 đầu (DSBackground dựng từ 2 màu này
    /// + quầng sáng xanh ngọc ở góc trên-trái).
    static let screenTop = Color(red: 0.047, green: 0.090, blue: 0.070)
    static let screenBottom = Color(red: 0.024, green: 0.039, blue: 0.031)

    /// Gradient thẻ hero (Trang Chủ) + nút chính: xanh ngọc
    /// sáng -> xanh ngọc đậm, chéo trên-trái xuống dưới-phải.
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.070, green: 0.725, blue: 0.506),
                 Color(red: 0.039, green: 0.541, blue: 0.373),
                 Color(red: 0.024, green: 0.373, blue: 0.263)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Bảng màu ô icon theo mục chi (ổn định theo tên mục —
    /// cùng tên luôn cùng màu): cặp (đầu, cuối) cho gradient.
    static func categoryTileColors(_ name: String) -> [Color] {
        let palette: [[Color]] = [
            [Color(red: 1.00, green: 0.62, blue: 0.04), Color(red: 0.94, green: 0.49, blue: 0.00)],  // hổ phách
            [Color(red: 0.35, green: 0.71, blue: 1.00), Color(red: 0.10, green: 0.45, blue: 0.95)],  // xanh dương
            [Color(red: 0.38, green: 0.85, blue: 0.55), Color(red: 0.10, green: 0.62, blue: 0.33)],  // xanh lá
            [Color(red: 0.78, green: 0.55, blue: 1.00), Color(red: 0.55, green: 0.30, blue: 0.90)],  // tím
            [Color(red: 1.00, green: 0.45, blue: 0.50), Color(red: 0.90, green: 0.25, blue: 0.32)],  // đỏ hồng
            [Color(red: 0.30, green: 0.85, blue: 0.85), Color(red: 0.10, green: 0.60, blue: 0.65)],  // ngọc lam
        ]
        var hash = 0
        for scalar in name.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        return palette[hash % palette.count]
    }

    /// Biểu tượng SF Symbol theo tên mục (khớp từ khoá tiếng
    /// Việt + tiếng Anh trong ngoặc); lạ thì dùng thẻ giá.
    static func categoryIconName(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("ăn") || n.contains("meals") || n.contains("uống") { return "fork.knife" }
        if n.contains("đi lại") || n.contains("xe") || n.contains("transport") { return "car.fill" }
        if n.contains("nhà") || n.contains("thuê") || n.contains("rent") { return "house.fill" }
        if n.contains("tiện ích") || n.contains("điện") || n.contains("utilities") { return "bolt.fill" }
        if n.contains("mua sắm") || n.contains("shopping") { return "cart.fill" }
        if n.contains("sức khoẻ") || n.contains("sức khỏe") || n.contains("health") { return "cross.case.fill" }
        if n.contains("vật tư") || n.contains("supplies") { return "shippingbox.fill" }
        if n.contains("văn phòng") || n.contains("office") { return "paperclip" }
        if n.contains("khác") || n.contains("other") { return "square.grid.2x2.fill" }
        return "tag.fill"
    }

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

// MARK: - Nền màn hình sâu (PASS 2)

/// Nền chuẩn mọi màn chính: dải xanh-đen đứng + quầng sáng
/// xanh ngọc mờ ở góc trên-trái — tạo chiều sâu thay cho nền
/// đen phẳng của pass 1 (điểm anh chê "nhìn y chang cũ").
struct DSBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [DS.screenTop, DS.screenBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [DS.brand.opacity(0.20), Color.clear],
                           center: .topLeading, startRadius: 20, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Áp DSBackground làm nền (cho ScrollView / nội dung tự dựng).
    func dsScreenBackground() -> some View {
        background(DSBackground())
    }
    /// Áp cho List: giấu nền hệ thống rồi đặt DSBackground.
    func dsListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(DSBackground())
    }
}

// MARK: - Chấm tin cậy theo trường (PASS 2)

/// Chấm nhỏ cạnh giá trị: xanh = trường có số & không bị gắn
/// cờ; hổ phách = cần anh nhìn lại. Thuần hiển thị.
struct ConfidenceDot: View {
    var ok: Bool
    var body: some View {
        Circle()
            .fill(ok ? DS.brand : DS.warning)
            .frame(width: 8, height: 8)
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
            .background(
                LinearGradient(colors: [color, color.opacity(0.78)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(configuration.isPressed ? 0.75 : 1)
            )
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

import SwiftUI
import SwiftData

/// SỔ HOÁ ĐƠN — Build 1 (bản nền tảng).
/// Chuỗi build giữ nguyên bản đã kiểm chứng ở IPA Test 0:
/// unsigned IPA qua GitHub Actions (macos-15), bundle com.nje.sohoadon,
/// deployment target iOS 17.0, KHÔNG CloudKit, KHÔNG entitlements.
@main
struct SoHoaDonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Receipt.self, LineItem.self, CardTail.self])
    }
}

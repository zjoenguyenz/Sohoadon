import SwiftUI

/// Điểm vào của BIẾN THỂ BenchApp. File này chỉ được đưa vào target
/// của project.yml trong benchapp/ — target đó đặt cờ biên dịch
/// BENCH và KHÔNG đưa SoHoaDonApp.swift / ContentView.swift của app
/// chính vào, nên không có hai @main trong cùng một bản dựng.
/// App chính không biên dịch file này và hành vi của nó không đổi.
#if BENCH
@main
struct BenchApp: App {
    var body: some Scene {
        WindowGroup {
            BenchView()
        }
    }
}
#endif

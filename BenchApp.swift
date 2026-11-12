import SwiftUI

/// BenchShell — app ĐO của đội (không phải bản giao): chạy ĐƯỜNG
/// ĐỌC DUY NHẤT của app chính (ReceiptReader trong
/// ReadPipeline.swift + cùng tập module) trên ảnh đóng băng trong
/// bundle, xuất hồ sơ chẩn đoán v2 để đội chấm ngoại tuyến. Phục
/// vụ giao thức đo M-1..M-7 (Pha 2) và các phiên đo gộp Pha 2/3.
/// Luật 1.6: BenchShell KHÔNG có bộ đọc riêng — nó liên kết đúng
/// các file module của app chính (xem project.yml); file này chỉ
/// là điểm vào @main của target bench.
@main
struct SoHoaDonBenchApp: App {
    var body: some Scene {
        WindowGroup {
            BenchView()
        }
    }
}

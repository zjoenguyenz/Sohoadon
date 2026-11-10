import SwiftUI

/// BẢN TEST PIPELINE ENGINE (b) — WP4 bước 3, cô lập kiểu Test 0.
/// App này KHÔNG phải app chính: không SwiftData, không parser, không
/// đụng kho dữ liệu. Mục đích duy nhất: chạy RecognizeDocumentsRequest
/// (iOS 26) trên ảnh mẫu của anh, xuất văn bản thô để chấm thi đấu với
/// ứng viên (a) theo WP4-SPEC. Framework lạ chỉ chạm SAU thao tác chọn
/// ảnh của người dùng (TEAM.md lỗi #1) và mọi lỗi đều fail-open thành
/// dòng trạng thái đọc được, không crash.
@main
struct TestBApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

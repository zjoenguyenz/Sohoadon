import Foundation

// HARNESS SHIM — không phải code app.
//
// OCREngine.swift (file nguồn app, biên dịch NGUYÊN VĂN vào
// harness) gọi ReceiptReader.stageBreadcrumb tại 3 điểm
// (engine-perform-begin / -done / engine-convert-done —
// CI-FIX-7). ReceiptReader thật nằm trong ReadPipeline.swift,
// file đó kéo UIKit/VisionKit nên KHÔNG vào harness macOS.
//
// Shim này cung cấp đúng MỘT biểu tượng còn thiếu để engine
// biên dịch không sửa một chữ. Harness gán closure ghi mốc ra
// stdout — nhờ đó log CI cho thấy lượt đọc chết ở mốc nào nếu
// nó chết bên trong engine (đúng vai trò breadcrumb trên máy
// anh ở run #45/#46).
enum ReceiptReader {
    static var stageBreadcrumb: ((String) -> Void)? = nil
}

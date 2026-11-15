import Foundation

// HARNESS SHIM — không phải code app.
//
// TRẠNG THÁI TỪ G5 (2026-11-15): shim ReceiptReader ĐÃ HƯU.
// Trước G5 file này khai một `enum ReceiptReader` rỗng chỉ để
// OCREngine.swift (gọi ReceiptReader.stageBreadcrumb ở 3 điểm)
// biên dịch được trong harness, vì ReadPipeline.swift — nhà
// thật của ReceiptReader — bị kẹt ngoài harness do 3 điểm chạm
// UIKit. G5 bọc 3 điểm đó bằng #if canImport(UIKit) ngay trong
// ReadPipeline.swift và đưa file thật vào project-harness.yml:
// harness nay liên kết ReceiptReader THẬT của app, shim mà còn
// khai trùng tên sẽ là lỗi biên dịch (khai báo hai lần). File
// giữ lại (rỗng, chỉ còn ghi chú này) để đường dẫn trong
// project không đổi và lịch sử quyết định không mất.

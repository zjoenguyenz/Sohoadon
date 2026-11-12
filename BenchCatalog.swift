import Foundation

struct BenchConfigDefinition: Identifiable {
    var id: String
    var name: String
    var engine: String
    var variant: String
    var baseline: Bool?
    var summary: String

    var json: BenchJSONConfig {
        BenchJSONConfig(id: id, name: name, engine: engine,
                        variant: variant, baseline: baseline)
    }
}

struct BenchImageDefinition: Identifiable {
    var id: String
    var form: String
    var difficulty: String
    var origin: String
    var gtID: String
    var sourceFile: String?
    var resourceName: String?
    var resourceExtension: String = "jpg"
    var pages: Int?
    var statusNote: String

    var isAvailable: Bool { resourceName != nil }

    func json(widthPX: Int, heightPX: Int) -> BenchJSONImage {
        BenchJSONImage(id: id, form: form, difficulty: difficulty,
                       origin: origin, gtID: gtID, sourceFile: sourceFile,
                       pages: pages, widthPX: widthPX, heightPX: heightPX)
    }
}

enum BenchCatalog {
    static let appBuild = "benchapp-3"

    static let configs: [BenchConfigDefinition] = [
        BenchConfigDefinition(
            id: "A0", name: "A0 — OCRFIX đối chứng",
            engine: "vision-classic", variant: "ocrfix",
            baseline: true,
            summary: "Tái lập OCRFIX ở tầng điều phối: gốc + phái sinh cũ, chọn bằng yieldScore."),
        BenchConfigDefinition(
            id: "A1", name: "A1 — (a) đa pass + hợp nhất",
            engine: "merged-core", variant: "classic-multipass-merge",
            baseline: nil,
            summary: "Các pass cổ điển của p2-fix, hợp nhất hình học; không (b), không reconcile/ROI."),
        BenchConfigDefinition(
            id: "A2", name: "A2 — A1 + pass (b)",
            engine: "merged-core", variant: "classic-plus-document-merge",
            baseline: nil,
            summary: "Pass cổ điển + RecognizeDocumentsRequest của p2-fix, hợp nhất chung; không reconcile/ROI."),
        BenchConfigDefinition(
            id: "A3", name: "A3 — đường đầy đủ p2-fix",
            engine: "merged-core", variant: "full-v2",
            baseline: nil,
            summary: "Đa pass + (b) + chọn bằng reconcile + tối đa 2 vòng đọc lại theo vùng."),
    ]

    /// Toàn bộ danh mục theo BENCH-MANIFEST. Ca có file thật trong
    /// BenchImages/ mang resourceName (4 ca hạt giống + 18 ca synthetic
    /// D-01…D-18 + 11 ca thật L-R01…L-R11); mọi ca còn lại chỉ hiện THIẾU,
    /// không có resourceName và không bao giờ được đưa vào runs của JSON.
    static let images: [BenchImageDefinition] = [
        BenchImageDefinition(
            id: "N-001", form: "N", difficulty: "L0", origin: "real",
            gtID: "GT-SAMS-F",
            sourceFile: "sample-001-sams-club-app-screenshot.jpg",
            resourceName: "N-001", pages: nil,
            statusNote: "Sẵn sàng — ảnh app Sam's Club."),
        BenchImageDefinition(
            id: "N-002", form: "N", difficulty: "L4", origin: "real",
            gtID: "GT-SAMS-F",
            sourceFile: "sample-002-sams-downloaded-receipt.jpg",
            resourceName: "N-002", pages: nil,
            statusNote: "Sẵn sàng — file tải về, phân giải thấp."),
        BenchImageDefinition(
            id: "C-003", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-HD-003",
            sourceFile: "sample-003-homedepot-paper-crop.jpg",
            resourceName: "C-003", pages: nil,
            statusNote: "Sẵn sàng — bản crop trong repo; manifest ưu tiên ảnh gốc ở buổi chuẩn bị."),
        BenchImageDefinition(
            id: "S-0", form: "S", difficulty: "L0", origin: "real",
            gtID: "GT-SAMS-F",
            sourceFile: "sample-004-sams-paper-scan.jpg",
            resourceName: "S-0", pages: 1,
            statusNote: "Sẵn sàng — CA CỔNG DANH DỰ, bản giấy Sam's qua máy scan."),
        BenchImageDefinition(
            id: "S-1", form: "S", difficulty: "L1", origin: "real",
            gtID: "GT-HD-003", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — cần quét tờ Home Depot ở buổi chuẩn bị."),
        BenchImageDefinition(
            id: "S-2", form: "S", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — cần quét một tờ nhăn thật và đóng băng đáp án mới."),
        BenchImageDefinition(
            id: "C-002C", form: "C", difficulty: "L0", origin: "real",
            gtID: "GT-SAMS-F", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — cần chụp thường chính tờ Sam's giấy."),
        BenchImageDefinition(
            id: "L1-01", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — ca nhăn/cũ thật 1/3 từ kho của anh."),
        BenchImageDefinition(
            id: "L1-02", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — ca nhăn/cũ thật 2/3 từ kho của anh."),
        BenchImageDefinition(
            id: "L1-03", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — ca nhăn/cũ thật 3/3 từ kho của anh."),
        BenchImageDefinition(
            id: "L2-01", form: "C", difficulty: "L2", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — tờ nhiệt phai thật 1/2."),
        BenchImageDefinition(
            id: "L2-02", form: "C", difficulty: "L2", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — tờ nhiệt phai thật 2/2."),
        BenchImageDefinition(
            id: "L3-01", form: "C", difficulty: "L3", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — chụp lại L1-01 dưới sáng lệch, dùng chung đáp án khi đã đóng băng."),
        BenchImageDefinition(
            id: "L3-02", form: "C", difficulty: "L3", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — chụp lại L1-02 dưới sáng lệch, dùng chung đáp án khi đã đóng băng."),
        BenchImageDefinition(
            id: "L4-02", form: "N", difficulty: "L4", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — file tải về thật khác khi anh có."),
        BenchImageDefinition(
            id: "L5-01", form: "C", difficulty: "L5", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — tờ nhiều món nhất trong kho thật; cấm ghép giả."),
        BenchImageDefinition(
            id: "PDF-SAM", form: "N", difficulty: "L0", origin: "real",
            gtID: "GT-TBD", sourceFile: nil, resourceName: nil,
            pages: nil, statusNote: "THIẾU — PDF Sam's thật; BenchApp bản này chỉ đo ảnh."),
        // --- 18 ca suy biến kỹ thuật số (Lớp D, BENCH-MANIFEST §4) ---
        // Mã D-01…D-18 theo thứ tự buổi đo của ACCEPTANCE §4: gốc theo
        // thứ tự 001 → 002 → 003, trong mỗi gốc phép theo thứ tự kê của
        // synthetic-manifest.csv (BLUR · DOWNSCALE · LIGHT · TILT ·
        // WRINKLE · NOISE). File giữ NGUYÊN tên SYN-* của manifest đóng
        // băng (sha256 đối chiếu được trong synthetic-manifest.csv).
        // origin = synthetic: CHỈ THAM KHẢO theo ACCEPTANCE — vẽ đường
        // cong chịu đựng, KHÔNG tính cổng danh dự, không thay ca thật
        // để kết luận engine. Đáp án kế thừa nguyên vẹn hạt giống.
        BenchImageDefinition(
            id: "D-01", form: "N", difficulty: "L2", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-001-BLUR.jpg",
            resourceName: "SYN-001-BLUR", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-001-BLUR, mờ Gauss r=1.5 trên gốc 001, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-02", form: "N", difficulty: "L4", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-001-DOWNSCALE.jpg",
            resourceName: "SYN-001-DOWNSCALE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-001-DOWNSCALE, hạ mẫu ×0.5 rồi phóng lại trên gốc 001, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-03", form: "N", difficulty: "L3", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-001-LIGHT.jpg",
            resourceName: "SYN-001-LIGHT", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-001-LIGHT, lệch sáng gamma 0.62 + gradient trên gốc 001, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-04", form: "N", difficulty: "L1", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-001-TILT.jpg",
            resourceName: "SYN-001-TILT", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-001-TILT, keystone + xoay 3° trên gốc 001, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-05", form: "N", difficulty: "L1", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-001-WRINKLE.jpg",
            resourceName: "SYN-001-WRINKLE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-001-WRINKLE, nhăn mô phỏng (uốn sin + dải sáng) trên gốc 001, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-06", form: "N", difficulty: "L2", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-001-NOISE.jpg",
            resourceName: "SYN-001-NOISE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-001-NOISE, nhiễu Gauss σ=12 + JPEG q=20 trên gốc 001, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-07", form: "N", difficulty: "L2", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-002-BLUR.jpg",
            resourceName: "SYN-002-BLUR", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-002-BLUR, mờ Gauss r=1.5 trên gốc 002, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-08", form: "N", difficulty: "L4", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-002-DOWNSCALE.jpg",
            resourceName: "SYN-002-DOWNSCALE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-002-DOWNSCALE, hạ mẫu ×0.5 rồi phóng lại trên gốc 002, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-09", form: "N", difficulty: "L3", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-002-LIGHT.jpg",
            resourceName: "SYN-002-LIGHT", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-002-LIGHT, lệch sáng gamma 0.62 + gradient trên gốc 002, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-10", form: "N", difficulty: "L1", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-002-TILT.jpg",
            resourceName: "SYN-002-TILT", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-002-TILT, keystone + xoay 3° trên gốc 002, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-11", form: "N", difficulty: "L1", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-002-WRINKLE.jpg",
            resourceName: "SYN-002-WRINKLE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-002-WRINKLE, nhăn mô phỏng (uốn sin + dải sáng) trên gốc 002, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-12", form: "N", difficulty: "L2", origin: "synthetic",
            gtID: "GT-SAMS-F",
            sourceFile: "SYN-002-NOISE.jpg",
            resourceName: "SYN-002-NOISE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-002-NOISE, nhiễu Gauss σ=12 + JPEG q=20 trên gốc 002, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-13", form: "C", difficulty: "L2", origin: "synthetic",
            gtID: "GT-HD-003",
            sourceFile: "SYN-003-BLUR.jpg",
            resourceName: "SYN-003-BLUR", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-003-BLUR, mờ Gauss r=1.5 trên gốc 003, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-14", form: "C", difficulty: "L4", origin: "synthetic",
            gtID: "GT-HD-003",
            sourceFile: "SYN-003-DOWNSCALE.jpg",
            resourceName: "SYN-003-DOWNSCALE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-003-DOWNSCALE, hạ mẫu ×0.5 rồi phóng lại trên gốc 003, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-15", form: "C", difficulty: "L3", origin: "synthetic",
            gtID: "GT-HD-003",
            sourceFile: "SYN-003-LIGHT.jpg",
            resourceName: "SYN-003-LIGHT", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-003-LIGHT, lệch sáng gamma 0.62 + gradient trên gốc 003, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-16", form: "C", difficulty: "L1", origin: "synthetic",
            gtID: "GT-HD-003",
            sourceFile: "SYN-003-TILT.jpg",
            resourceName: "SYN-003-TILT", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-003-TILT, keystone + xoay 3° trên gốc 003, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-17", form: "C", difficulty: "L1", origin: "synthetic",
            gtID: "GT-HD-003",
            sourceFile: "SYN-003-WRINKLE.jpg",
            resourceName: "SYN-003-WRINKLE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-003-WRINKLE, nhăn mô phỏng (uốn sin + dải sáng) trên gốc 003, đáp án kế thừa hạt giống."),
        BenchImageDefinition(
            id: "D-18", form: "C", difficulty: "L2", origin: "synthetic",
            gtID: "GT-HD-003",
            sourceFile: "SYN-003-NOISE.jpg",
            resourceName: "SYN-003-NOISE", pages: nil,
            statusNote: "Sẵn sàng — SYNTHETIC tham khảo (không cổng danh dự): SYN-003-NOISE, nhiễu Gauss σ=12 + JPEG q=20 trên gốc 003, đáp án kế thừa hạt giống."),
        // --- 11 hoá đơn THẬT anh gửi 2026-11-11 (L-R01…L-R11) ---
        // ĐÃ ĐÓNG BĂNG ở gói LR-FREEZE: chép tay bằng crop phóng to +
        // kiểm số học khép 0 xu từng ca; đáp án GT-LR-01…09 + GT-LR-11 ở
        // bench-prep/lr-freeze/answers-lr.json (nạp qua --answers), L-R10
        // dùng lại GT-HD-003. Sổ: bench-prep/lr-freeze/LR-FREEZE-LEDGER.md.
        BenchImageDefinition(
            id: "L-R01", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-LR-01",
            sourceFile: "sample-005-costco-tulsa-photo.jpg",
            resourceName: "L-R01", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Costco Tulsa #1207 (2026-09-14), 20 dòng gồm 8 dòng INST SV âm; GT-LR-01 đóng băng, số học khép 0 xu."),
        BenchImageDefinition(
            id: "L-R02", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-LR-02",
            sourceFile: "sample-006-tjohnnys-seafood-may-photo.jpg",
            resourceName: "L-R02", pages: nil,
            statusNote: "Sẵn sàng — THẬT: T-Johnnys Seafood Coweta (2026-05-20), 2 dòng, món chính bán theo cân; GT-LR-02 đóng băng."),
        BenchImageDefinition(
            id: "L-R03", form: "C", difficulty: "L2", origin: "real",
            gtID: "GT-LR-03",
            sourceFile: "sample-007-walmart-broken-arrow-jun-photo.jpg",
            resourceName: "L-R03", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Walmart Broken Arrow (2026-06-24), phai nhiệt toàn tờ + bóng chéo; SUBTOTAL khép suy luận 2 đường, đuôi thẻ không đọc được (uncertain trong GT-LR-03)."),
        BenchImageDefinition(
            id: "L-R04", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-LR-04",
            sourceFile: "sample-008-walmart-broken-arrow-aug-photo.jpg",
            resourceName: "L-R04", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Walmart Broken Arrow (2026-08-12), nhăn nặng; dòng khuyen mãi '2 AT 1 FOR' có ngoại lệ đếm ITEMS SOLD đã ghi trong GT-LR-04."),
        BenchImageDefinition(
            id: "L-R05", form: "C", difficulty: "L3", origin: "real",
            gtID: "GT-LR-05",
            sourceFile: "sample-009-pan-asia-tulsa-aug03-photo.jpg",
            resourceName: "L-R05", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Pan-Asia Tulsa (2026-08-03); bóng/loá rửa mất chữ số 2 dòng tiền, 1 số (MINT) khép suy luận duy nhất; GT-LR-05 đóng băng."),
        BenchImageDefinition(
            id: "L-R06", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-LR-06",
            sourceFile: "sample-010-pan-asia-tulsa-aug12-1item-photo.jpg",
            resourceName: "L-R06", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Pan-Asia Tulsa (2026-08-12), 1 món, giấy nhăn + bóng tay; GT-LR-06 đóng băng."),
        BenchImageDefinition(
            id: "L-R07", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-LR-07",
            sourceFile: "sample-011-pan-asia-tulsa-aug12-17items-photo.jpg",
            resourceName: "L-R07", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Pan-Asia Tulsa (2026-08-12), 17 món, 4 dòng cân in TRƯỚC dòng nhãn — ca khó mẫu mực của lớp L1; GT-LR-07 đóng băng."),
        BenchImageDefinition(
            id: "L-R08", form: "C", difficulty: "L3", origin: "real",
            gtID: "GT-LR-08",
            sourceFile: "sample-012-tjohnnys-seafood-mar-photo.jpg",
            resourceName: "L-R08", pages: nil,
            statusNote: "Sẵn sàng — THẬT: T-Johnnys Seafood Coweta (2026-03-19), thuế 2 tầng; số Coweta bị bóng che, khép suy luận duy nhất; GT-LR-08 đóng băng."),
        BenchImageDefinition(
            id: "L-R09", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-LR-09",
            sourceFile: "sample-013-walmart-broken-arrow-apr-photo.jpg",
            resourceName: "L-R09", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Walmart Broken Arrow (2026-04-15); BẪY 'TOTAL DEBIT PURCHASE 92.24' gồm cash back 20.00 — total đúng 72.24 trong GT-LR-09; 1 dòng tiền khép suy luận."),
        BenchImageDefinition(
            id: "L-R10", form: "C", difficulty: "L1", origin: "real",
            gtID: "GT-HD-003",
            sourceFile: "sample-014-homedepot-paper-photo-fullres.jpg",
            resourceName: "L-R10", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Home Depot — CHÍNH tờ vật lý của Mẫu 003 nhưng là ẢNH GỐC nét đầy đủ (C-003 trong catalog là bản crop từ screenshot); cặp dạng CAMERA với C-003, dùng lại GT-HD-003, đọc trực tiếp khớp từng số."),
        BenchImageDefinition(
            id: "L-R11", form: "C", difficulty: "L0", origin: "real",
            gtID: "GT-LR-11",
            sourceFile: "sample-015-walmart-elm-pl-nov-photo.jpg",
            resourceName: "L-R11", pages: nil,
            statusNote: "Sẵn sàng — THẬT: Walmart 1770 S Elm Pl, Broken Arrow (2026-11-10), 1 món, tờ sạch phẳng; thẻ Visa đuôi 7674 chưa có trong registry — chỉ ghi trong GT-LR-11, không kết luận loại thẻ."),
    ]

    static var availableImages: [BenchImageDefinition] {
        images.filter(\.isAvailable)
    }
}

// TaxSettings.swift — Pha 2 (L-2026-11-21-47): cài đặt thuế phía app.
//
// Mẫu lưu = enum tĩnh trên UserDefaults như DriveSettings /
// MirrorSettings (không đổi SwiftData model). Bảng hiệu lực = hạt
// giống TaxTable.seed với các phần khu anh đã sửa trong Cài đặt đè
// lên (overrides lưu JSON theo id phần khu). Chỉ target app dùng —
// lõi TaxLanding chỉ nhận TaxLandingContext đã gói sẵn.

import Foundation

enum TaxSettings {
    private static let enabledKey = "glkeeper.tax.landingEnabled"
    private static let defaultAreaKey = "glkeeper.tax.defaultAreaID"
    private static let overridesKey = "glkeeper.tax.overridesJSON"

    static var landingEnabled: Bool {
        get {
            let d = UserDefaults.standard
            return d.object(forKey: enabledKey) == nil
                ? true
                : d.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var defaultAreaID: String {
        get {
            UserDefaults.standard.string(forKey: defaultAreaKey)
                ?? TaxTable.defaultSeedAreaID
        }
        set { UserDefaults.standard.set(newValue, forKey: defaultAreaKey) }
    }

    /// Các phần khu anh đã sửa trong Cài đặt (theo id).
    static var overrides: [String: TaxAreaPortion] {
        get {
            guard let data = UserDefaults.standard.data(forKey: overridesKey),
                  let decoded = try? JSONDecoder().decode(
                      [String: TaxAreaPortion].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: overridesKey)
            }
        }
    }

    static func setOverride(_ portion: TaxAreaPortion) {
        var current = overrides
        current[portion.id] = portion
        overrides = current
    }

    /// Bảng hiệu lực = hạt giống + overrides đè theo id.
    static var effectiveTable: TaxTable {
        let o = overrides
        guard !o.isEmpty else { return TaxTable.seed }
        var table = TaxTable.seed
        table.portions = table.portions.map { o[$0.id] ?? $0 }
        return table
    }
}

/// Gói ngữ cảnh hạ cánh cho một lần đọc (app gọi trước ReceiptReader.read).
enum TaxLandingContextBuilder {
    static func make() -> TaxLandingContext {
        TaxLandingContext(
            table: TaxSettings.effectiveTable,
            defaultAreaID: TaxSettings.defaultAreaID,
            profileHints: StoreProfiles.allHints(),
            enabled: TaxSettings.landingEnabled)
    }
}

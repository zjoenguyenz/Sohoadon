// StoreProfiles.swift — Pha 2 (L-2026-11-21-47): hồ sơ tiệm tự học.
//
// Mỗi tờ anh DUYỆT LƯU ở Kiểm Lại dạy cho hồ sơ của tiệm đó: ZIP gần
// nhất + loại hàng đã duyệt + số tờ. Lần đọc sau, tờ mờ của cùng tiệm
// được gợi ý ZIP/loại từ hồ sơ (cờ "theo tiệm" — chỉ gợi ý, không kết
// luận thay mặt hàng đọc được; luật của anh 2026-11-21 01:34 CST).
//
// Lưu ở Application Support/StoreProfiles.json — KHÔNG Documents
// (bài học vụ mất file 2026-11-20: Documents từng mất chọn lọc trong
// khi Application Support nguyên vẹn). Ghi nguyên tử tmp + rename
// như PendingDraftStore. Chỉ target app.

import Foundation

struct StoreProfile: Codable, Equatable {
    var key: String
    var zip: String? = nil
    var category: String? = nil       // TaxCategory.rawValue
    var approvedCount: Int = 0
    var lastSeenISO: String = ""
}

enum StoreProfiles {
    static let fileName = "StoreProfiles.json"

    static var fileURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(fileName)
    }

    static func load() -> [String: StoreProfile] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(
                  [String: StoreProfile].self, from: data)
        else { return [:] }
        return decoded
    }

    static func save(_ profiles: [String: StoreProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        let target = fileURL
        let tmp = target.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp)
            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(
                    target, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: target)
            }
        } catch {
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    /// Rút gọn cho TaxLandingContext (khoá khớp TaxLanding.profileKey).
    static func allHints() -> [String: TaxProfileHint] {
        load().mapValues { profile in
            TaxProfileHint(
                zip: profile.zip,
                category: profile.category.flatMap(TaxCategory.init(rawValue:)))
        }
    }

    /// Học từ một tờ vừa được duyệt lưu. Giá trị nil KHÔNG xoá giá trị
    /// đã học (tờ thiếu ZIP không được làm mất ZIP của tiệm).
    static func learn(key: String, zip: String?, category: TaxCategory?) {
        guard !key.isEmpty else { return }
        var profiles = load()
        var profile = profiles[key] ?? StoreProfile(key: key)
        if let zip { profile.zip = zip }
        if let category { profile.category = category.rawValue }
        profile.approvedCount += 1
        profile.lastSeenISO = ISO8601DateFormatter().string(from: Date())
        profiles[key] = profile
        save(profiles)
        DiagLog.log(.read, "THUẾ: hồ sơ tiệm \(key) — đã duyệt "
            + "\(profile.approvedCount) tờ"
            + (profile.zip.map { " · ZIP \($0)" } ?? "")
            + (profile.category.map { " · loại \($0)" } ?? ""))
    }
}

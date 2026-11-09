import SwiftUI
import LocalAuthentication
import CloudKit
import UIKit
import UniformTypeIdentifiers

/// IPA TEST SỐ 0 — không phải app thật.
/// Mục đích duy nhất: kiểm chứng trên iPhone thật của anh, sau khi ký bằng
/// chứng thư của anh, 3 việc: (1) app cài/mở được, (2) Face ID dùng được,
/// (3) iCloud (CloudKit) có chạy với cách ký này không.
struct ContentView: View {
    @State private var faceIDStatus = "Chưa kiểm tra"
    @State private var icloudStatus = "Chưa kiểm tra"
    @State private var icloudWriteStatus = "Chưa kiểm tra"
    @State private var filesStatus = "Chưa kiểm tra"
    @State private var showFolderPicker = false

    private let container = CKContainer(identifier: "iCloud.com.nje.sohoadon")

    var body: some View {
        NavigationStack {
            List {
                Section("Bài test số 0") {
                    Text("App tạm này chỉ để kiểm tra trước khi xây app thật: ký bằng chứng thư của anh có cài được không, Face ID có dùng được không, và iCloud có chạy với cách ký này không. Anh bấm 2 nút kiểm tra rồi chụp màn hình này gửi lại là đủ.")
                        .font(.callout)
                }
                Section("1. Face ID") {
                    Text(faceIDStatus)
                    Button("Kiểm tra Face ID") { checkFaceID() }
                }
                Section("2. iCloud") {
                    Text("Tài khoản: \(icloudStatus)")
                    Text("Ghi thử: \(icloudWriteStatus)")
                    Button("Kiểm tra iCloud") { checkICloud() }
                }
                Section("3. Thư mục trong app Files") {
                    Text(filesStatus)
                    Text("Đây là cách app thật sẽ tự lưu bản sao hoá đơn: anh chọn 1 thư mục trong app Files (nằm ở iCloud Drive hoặc Trên iPhone đều được), từ đó app tự ghi vào đó, không cần quyền iCloud riêng.")
                        .font(.callout)
                    Button("Chọn thư mục & ghi thử") { showFolderPicker = true }
                }
                Section("Máy của anh") {
                    Text("iOS: \(UIDevice.current.systemVersion)")
                    Text("Thiết bị: \(UIDevice.current.model)")
                    Text("Bundle: \(Bundle.main.bundleIdentifier ?? "?")")
                    Text("Bản: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                }
            }
            .navigationTitle("Sổ Hóa Đơn — Test 0")
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
                handleFolderPick(result)
            }
        }
    }

    private func handleFolderPick(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let e):
            filesStatus = "Chọn thư mục thất bại: \(e.localizedDescription)"
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let dir = url.appendingPathComponent("SoHoaDon-Test", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent("test.txt")
                let body = "Sổ Hóa Đơn ghi thử lúc \(Date())"
                try body.write(to: file, atomically: true, encoding: .utf8)
                let back = try String(contentsOf: file, encoding: .utf8)
                filesStatus = back == body
                    ? "GHI + ĐỌC LẠI THÀNH CÔNG ✓ tại: \(url.lastPathComponent)/SoHoaDon-Test/test.txt"
                    : "Ghi được nhưng đọc lại không khớp"
            } catch {
                filesStatus = "GHI THẤT BẠI — \(error.localizedDescription)"
            }
        }
    }

    private func checkFaceID() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            faceIDStatus = "Không dùng được: \(err?.localizedDescription ?? "không rõ")"
            return
        }
        let kind: String
        switch ctx.biometryType {
        case .faceID: kind = "Face ID"
        case .touchID: kind = "Touch ID"
        case .opticID: kind = "Optic ID"
        default: kind = "Sinh trắc học"
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Kiểm tra khoá app Sổ Hóa Đơn") { ok, error in
            DispatchQueue.main.async {
                faceIDStatus = ok ? "\(kind): MỞ KHOÁ THÀNH CÔNG ✓"
                                  : "\(kind): thất bại — \(error?.localizedDescription ?? "")"
            }
        }
    }

    private func checkICloud() {
        icloudStatus = "Đang kiểm tra..."
        icloudWriteStatus = "Đang kiểm tra..."
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available: icloudStatus = "Đã đăng nhập ✓"
                case .noAccount: icloudStatus = "Máy chưa đăng nhập iCloud"
                case .restricted: icloudStatus = "iCloud bị giới hạn trên máy này"
                case .couldNotDetermine: icloudStatus = "Không xác định được"
                case .temporarilyUnavailable: icloudStatus = "iCloud tạm thời không dùng được"
                @unknown default: icloudStatus = "Trạng thái lạ: \(status.rawValue)"
                }
                if let error { icloudStatus += " — Lỗi: \(error.localizedDescription)" }
            }
            guard status == .available else { return }
            // Ghi thử 1 record rồi xoá — đây là phép thử quyết định:
            // nếu entitlement/container không sống sót qua việc ký lại,
            // bước này sẽ báo lỗi và ta biết phải đi đường khác cho iCloud.
            let db = container.privateCloudDatabase
            let rec = CKRecord(recordType: "TestPing")
            rec["ts"] = Date() as CKRecordValue
            db.save(rec) { saved, saveError in
                if let saveError {
                    DispatchQueue.main.async {
                        icloudWriteStatus = "GHI THẤT BẠI — \(saveError.localizedDescription)"
                    }
                    return
                }
                guard let saved else { return }
                db.delete(withRecordID: saved.recordID) { _, _ in
                    DispatchQueue.main.async {
                        icloudWriteStatus = "GHI + ĐỌC + XOÁ THÀNH CÔNG ✓ (iCloud chạy được với cách ký này)"
                    }
                }
            }
        }
    }
}

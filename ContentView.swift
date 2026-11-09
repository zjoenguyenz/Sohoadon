import SwiftUI
import LocalAuthentication
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var faceIDStatus = "Chưa kiểm tra"
    @State private var filesStatus = "Chưa kiểm tra"
    @State private var showFolderPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section("Bài test số 0") {
                    Text("App tạm này chỉ để kiểm tra trước khi xây app thật: ký bằng chứng thư của anh có cài/mở được không, Face ID có dùng được không, và app có tự ghi được vào thư mục trong app Files không. Anh bấm 2 nút kiểm tra rồi chụp màn hình này gửi lại là đủ.")
                        .font(.callout)
                }
                Section("1. Face ID") {
                    Text(faceIDStatus)
                    Button("Kiểm tra Face ID") { checkFaceID() }
                }
                Section("2. iCloud / CloudKit") {
                    Text("ĐÃ LOẠI — bản test trước chết ngay khi chạm vào CloudKit dưới cách ký này (có log crash làm bằng chứng). App thật không dùng CloudKit: dữ liệu nằm trên máy và tự lưu bản sao vào thư mục anh chọn trong app Files — kiểm tra ở mục 3.")
                        .font(.callout)
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
}

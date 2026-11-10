import SwiftUI
import SwiftData
import LocalAuthentication

/// Gốc của app: cổng khoá Face ID (nếu bật) + khung 5 tab.
/// Khoá Face ID PHẢI fail-open: máy không có sinh trắc/mật mã, hoặc lỗi lạ
/// -> mở app bình thường kèm thông báo, KHÔNG bao giờ khoá cứng anh ở ngoài
/// và KHÔNG crash (bài học Test 0: đụng vào framework lạ lúc khởi động là chết app).
struct ContentView: View {
    @AppStorage("faceIDLockEnabled") private var lockEnabled = true
    @State private var unlocked = false
    @State private var lockNote: String? = nil
    @Environment(\.scenePhase) private var scenePhase
    /// WP3 bước 2: file anh mở bằng "Mở bằng Sổ Hóa Đơn" / Share Sheet
    /// (khai báo CFBundleDocumentTypes ở project.yml). URL chỉ được GIỮ
    /// ở đây — việc đọc file diễn ra đồng bộ trong ScanView như đường
    /// Files; app đang khoá Face ID thì URL chờ ở đây, mở khoá xong mới
    /// truyền xuống (không đọc file khi chưa qua cổng khoá).
    @State private var pendingImportURLs: [URL] = []

    var body: some View {
        Group {
            if !lockEnabled || unlocked {
                TabShellView(lockNote: lockNote, pendingImportURLs: $pendingImportURLs)
            } else {
                lockScreen
            }
        }
        .onOpenURL { url in
            pendingImportURLs.append(url)
        }
        .onAppear { authenticateIfNeeded() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && lockEnabled {
                unlocked = false
            }
            if newPhase == .active && lockEnabled && !unlocked {
                authenticateIfNeeded()
            }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Sổ Hóa Đơn đang khoá")
                .font(.title3.bold())
            if let lockNote {
                Text(lockNote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Mở khoá bằng Face ID / mật mã") { authenticateIfNeeded() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    private func authenticateIfNeeded() {
        guard lockEnabled, !unlocked else { return }
        let context = LAContext()
        var error: NSError?
        // .deviceOwnerAuthentication = Face ID, hỏng thì rơi về mật mã máy.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Không có sinh trắc lẫn mật mã -> fail-open, không khoá người dùng ở ngoài.
            lockNote = "Máy chưa đặt Face ID/mật mã nên app mở không khoá. Anh có thể tắt khoá hẳn trong Thẻ & Cài Đặt."
            unlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Mở khoá Sổ Hóa Đơn") { success, _ in
            DispatchQueue.main.async {
                if success {
                    unlocked = true
                    lockNote = nil
                } else {
                    lockNote = "Chưa mở được — anh bấm nút dưới để thử lại (hoặc dùng mật mã máy)."
                }
            }
        }
    }
}

// MARK: - Khung 5 tab (BLUEPRINT mục 5)

struct TabShellView: View {
    var lockNote: String? = nil
    /// WP3 bước 2: hàng chờ file mở-từ-ngoài, truyền thẳng xuống ScanView.
    @Binding var pendingImportURLs: [URL]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var seeded = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Trang Chủ", systemImage: "house.fill") }
                .tag(0)

            ReceiptListView()
                .tabItem { Label("Hoá Đơn", systemImage: "doc.text.fill") }
                .tag(1)

            ScanView(externalImportURLs: $pendingImportURLs)
                .tabItem { Label("CHỤP", systemImage: "camera.fill") }
                .tag(2)

            ReportsView()
                .tabItem { Label("Báo Cáo Thuế", systemImage: "chart.pie.fill") }
                .tag(3)

            CardsView()
                .tabItem { Label("Thẻ & Cài Đặt", systemImage: "creditcard.fill") }
                .tag(4)
        }
        .task { seedStarterCardIfNeeded() }
        // WP3 bước 2: có file mở-từ-ngoài đang chờ -> nhảy thẳng sang
        // tab CHỤP để ScanView hút vào hàng chờ và mở màn Kiểm Lại.
        .onChange(of: pendingImportURLs) { _, urls in
            if !urls.isEmpty { selectedTab = 2 }
        }
    }

    /// Nạp sẵn thẻ đã chốt với anh: Mastercard Debit •• 2586 = Business.
    /// Chỉ nạp khi danh sách thẻ đang TRỐNG và chưa từng nạp (cờ UserDefaults),
    /// để anh xoá/ngưng về sau không bị app tự nạp lại.
    private func seedStarterCardIfNeeded() {
        guard !seeded else { return }
        seeded = true
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didSeedStarterCard2586") else { return }
        let descriptor = FetchDescriptor<CardTail>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if existing.isEmpty {
            let card = CardTail()
            card.last4 = "2586"
            card.brand = "Mastercard Debit"
            card.kind = .business
            modelContext.insert(card)
            try? modelContext.save()
        }
        defaults.set(true, forKey: "didSeedStarterCard2586")
    }
}

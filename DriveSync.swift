import Foundation
import SwiftData
import UIKit
import AuthenticationServices
import CryptoKit
import Security

// MARK: - P2-2: Đồng bộ Google Drive (PHASE2-PLAN §2.3 / AMD-002)
//
// Lớp sao lưu NGOÀI MÁY của GL-Keeper — từ Gói 6 (Q1, anh
// quyết 2026-11-20) đây là đường sao lưu chính thay gương
// Files (bộ chọn thư mục chết trên bản cài ký lại — L-38;
// mã MirrorSync giữ nguyên, không đụng).
//
// Bố cục trên Drive GIỐNG HỆT lớp gương (§2.1 — một bố cục,
// hai đường vận chuyển; khôi phục đọc được từ cả hai nguồn):
//   GL-Keeper/
//     manifest.json            (MirrorManifest — DTO dùng chung)
//     receipts/<id>/receipt.json + original-1.jpg|pdf …
//     _deleted/<id>/…          (xoá = CHUYỂN vào đây, có dấu vết)
//
// Kỷ luật cứng của lớp này (kế thừa nguyên văn lớp gương):
// - Kho SwiftData trên máy là GỐC; Drive là lớp PHỤ — mọi lỗi
//   Drive chỉ GHI NHẬN vào trạng thái (hiện ở Thẻ & Cài Đặt)
//   + log chẩn đoán, KHÔNG bao giờ chặn hay làm hỏng luồng
//   lưu hoá đơn. Lỗi mạng -> trạng thái chờ, lượt sau tự bù.
// - KHÔNG đổi model SwiftData: trạng thái nằm ở UserDefaults,
//   token nằm ở KEYCHAIN (không UserDefaults, không file).
// - Quyền TỐI THIỂU: scope chỉ `drive.file` — app chỉ thấy
//   file do chính nó tạo trong thư mục GL-Keeper của nó.
// - Mỗi tờ là đơn vị đồng bộ (§2.3): file của tờ lên xong
//   mới cập nhật manifest; receipt.json của một tờ là dấu
//   chốt của tờ đó. Xung đột: bản mới thắng, bản thua được
//   GIỮ thành file receipt-conflict-<giờ>.json trong cùng
//   thư mục tờ — không ghi đè lặng lẽ ở bất kỳ đường nào.
// - JSON chỉ qua Codable (luật L-2026-11-16-24); riêng các
//   file dùng chung với lớp gương (manifest.json,
//   receipt.json) BẮT BUỘC qua cặp MirrorJSON (ghi chú N1
//   ở P2-1-DIFF: decoder mặc định đọc sai ngày tháng).
// - Token KHÔNG bao giờ rời máy ngoài tới Google; email tài
//   khoản chỉ hiện ở Cài đặt, không ghi log.

// MARK: Cấu hình OAuth — MỘT điểm duy nhất

enum DriveConfig {
    /// Client ID THẬT — đã điền 2026-11-20: OAuth client
    /// loại iOS do anh tạo trong Google Cloud project
    /// gl-keeper, gắn bundle com.nje.sohoadon (anh có mặt
    /// duyệt consent lần đầu — PHASE2-PLAN §2.3). Scheme
    /// trong project.yml (CFBundleURLTypes của target
    /// chính) là client ID này ĐẢO NGƯỢC THEO TỪNG THÀNH
    /// PHẦN — hai chỗ phải khớp nhau, xem callbackScheme
    /// ở dưới. Lớp chặn isConfigured ở dưới vẫn giữ làm
    /// van an toàn: nếu giá trị này bị thay bằng chuỗi
    /// chứa "PLACEHOLDER" thì nút đăng nhập chỉ ghi rõ
    /// trạng thái "chưa cấu hình" vào mục Drive + log,
    /// không mở trang Google (tránh màn hình lỗi khó hiểu).
    static let oauthClientID = "743860596620-rn97516fmivkoa2njklujbda55scsbv2.apps.googleusercontent.com"

    static var isConfigured: Bool {
        !oauthClientID.contains("PLACEHOLDER")
    }

    /// Scope tối thiểu theo §2.3 — chỉ drive.file, không hơn.
    static let scope = "https://www.googleapis.com/auth/drive.file"

    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let apiBase = "https://www.googleapis.com/drive/v3"
    static let uploadBase = "https://www.googleapis.com/upload/drive/v3"

    /// Tên thư mục gốc trên Drive (anh chốt 2026-11-17:
    /// giữ mặc định "GL-Keeper" — PHASE2-PLAN §4 mục 2).
    static let rootFolderName = "GL-Keeper"
    static let receiptsFolderName = "receipts"
    static let deletedFolderName = "_deleted"
    static let folderMIME = "application/vnd.google-apps.folder"

    /// Scheme callback = client ID đảo ngược theo từng thành
    /// phần cách nhau bởi dấu chấm (mẫu Google yêu cầu cho
    /// client iOS): "X.apps.googleusercontent.com" ->
    /// "com.googleusercontent.apps.X". project.yml khai
    /// đúng chuỗi này trong CFBundleURLTypes.
    static var callbackScheme: String {
        oauthClientID.split(separator: ".")
            .reversed().joined(separator: ".")
    }

    static var redirectURI: String { "\(callbackScheme):/oauth2redirect" }
}

// MARK: Keychain — nơi giữ token DUY NHẤT

/// Token OAuth (access + refresh) chỉ sống ở Keychain
/// (kSecClassGenericPassword). Không UserDefaults, không
/// file, không log. Xoá khi đăng xuất.
enum DriveKeychain {
    static let accessTokenAccount = "accessToken"
    static let refreshTokenAccount = "refreshToken"
    private static let service = "com.nje.sohoadon.googledrive"

    private static func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        let status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            // ThisDeviceOnly: refresh token (sống lâu)
            // KHÔNG theo bản sao lưu mã hoá sang máy khác
            // (kiểm duyệt vòng 1 ghế A, MINOR-2). Chưa có
            // bản phát hành nào đã lưu token nên đổi thẳng
            // được, không cần di trú.
            query[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}

// MARK: Trạng thái Drive (UserDefaults — không đổi model)

enum DriveSettings {
    private static let emailKey = "glkeeper.drive.email"
    private static let lastRunKey = "glkeeper.drive.lastRunAt"
    private static let lastSummaryKey = "glkeeper.drive.lastSummary"
    private static let lastErrorKey = "glkeeper.drive.lastError"
    private static let lastErrorAtKey = "glkeeper.drive.lastErrorAt"
    private static let tokenExpiryKey = "glkeeper.drive.tokenExpiry"
    private static let rootFolderIDKey = "glkeeper.drive.rootFolderID"
    private static let receiptsFolderIDKey = "glkeeper.drive.receiptsFolderID"
    private static let deletedFolderIDKey = "glkeeper.drive.deletedFolderID"

    /// Email tài khoản Google — CHỈ để hiện ở Cài đặt.
    /// Không ghi log, không rời máy.
    static var accountEmail: String? {
        get { UserDefaults.standard.string(forKey: emailKey) }
        set { UserDefaults.standard.set(newValue, forKey: emailKey) }
    }

    static var lastRunAt: Date? {
        get { UserDefaults.standard.object(forKey: lastRunKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastRunKey) }
    }

    static var lastSummary: String? {
        get { UserDefaults.standard.string(forKey: lastSummaryKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSummaryKey) }
    }

    static var lastError: String? {
        get { UserDefaults.standard.string(forKey: lastErrorKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastErrorKey) }
    }

    static var lastErrorAt: Date? {
        get { UserDefaults.standard.object(forKey: lastErrorAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastErrorAtKey) }
    }

    /// Mốc hết hạn của access token hiện tại (token thật nằm
    /// ở Keychain; mốc này chỉ để biết khi nào phải làm mới).
    static var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: tokenExpiryKey) }
    }

    /// Bộ nhớ đệm id thư mục trên Drive (3 thư mục khung của
    /// bố cục). Mất/hỏng thì engine tự tìm-tạo lại — đây chỉ
    /// là đệm giảm lượt gọi, không phải nguồn sự thật.
    static var rootFolderID: String? {
        get { UserDefaults.standard.string(forKey: rootFolderIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: rootFolderIDKey) }
    }

    static var receiptsFolderID: String? {
        get { UserDefaults.standard.string(forKey: receiptsFolderIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: receiptsFolderIDKey) }
    }

    static var deletedFolderID: String? {
        get { UserDefaults.standard.string(forKey: deletedFolderIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: deletedFolderIDKey) }
    }

    /// Phát thông báo đổi trạng thái TRÊN MAIN QUEUE — cùng
    /// bài học L1 của lớp gương (record* chạy ở hàng đợi nền,
    /// phía nhận sửa @State).
    static func postStatusChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: DriveSync.statusChangedNotification, object: nil)
        }
    }

    /// Ghi kết quả một lượt đồng bộ chạy xong (kể cả lượt có
    /// tờ lỗi lẻ — lỗi lẻ nằm ở lastError, lượt sau tự bù).
    static func recordPass(summary: String, error: String?) {
        lastRunAt = Date()
        lastSummary = summary
        lastError = error
        lastErrorAt = error == nil ? nil : Date()
        postStatusChanged()
    }

    /// Ghi lỗi CẤP LƯỢT (chưa đăng nhập / mất phiên / không
    /// gọi được Drive): lượt coi như chưa chạy — lastRunAt
    /// giữ nguyên mốc thành công gần nhất để UI nói thật.
    static func recordFailure(_ message: String) {
        lastError = message
        lastErrorAt = Date()
        postStatusChanged()
    }

    /// Dọn phần trạng thái gắn với phiên đăng nhập (đăng
    /// xuất / hết phiên): email + mốc token + đệm thư mục
    /// + LỖI ĐANG HIỆN (lỗi của phiên cũ không bám đỏ qua
    /// ranh giới phiên — kiểm duyệt vòng 1 ghế C, M2).
    /// Lịch sử lượt (lastRunAt/lastSummary) giữ nguyên —
    /// đó là sự thật đã xảy ra; giao diện chỉ hiện khi
    /// đang đăng nhập.
    static func clearSignInState() {
        accountEmail = nil
        tokenExpiry = nil
        lastError = nil
        lastErrorAt = nil
        rootFolderID = nil
        receiptsFolderID = nil
        deletedFolderID = nil
    }
}

// MARK: OAuth — đăng nhập Google (ASWebAuthenticationSession + PKCE)

/// Đáp ứng của endpoint token của Google. Chỉ qua Codable
/// (luật L-2026-11-16-24) — không JSONSerialization viết tay.
struct DriveTokenResponse: Codable {
    var accessToken: String
    var expiresIn: Int
    var refreshToken: String?
    var scope: String?
    var tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

/// Đáp ứng about.get của Drive API — lấy email hiển thị.
struct DriveAboutResponse: Codable {
    struct User: Codable {
        var emailAddress: String?
        var displayName: String?
    }
    var user: User?
}

enum DriveAuth {
    /// Đã đăng nhập = còn refresh token trong Keychain.
    static var isSignedIn: Bool {
        DriveKeychain.read(account: DriveKeychain.refreshTokenAccount) != nil
    }

    /// Phiên đăng nhập đang mở (giữ tĩnh tới callback — cùng
    /// kỷ luật coordinator của bộ chọn thư mục: delegate/
    /// session không có tham chiếu mạnh là chết lặng).
    private static var activeSession: ASWebAuthenticationSession?
    private static var activeContextProvider: DriveAuthPresentationContext?

    // MARK: Đăng nhập

    /// Mở phiên đăng nhập Google. true = đăng nhập xong
    /// (token đã ở Keychain), false = huỷ/lỗi/chưa cấu
    /// hình. Hàng đợi của completion: các đường qua
    /// callback của ASWebAuthenticationSession và bước đổi
    /// mã được dispatch về main; riêng các đường THOÁT SỚM
    /// (chưa cấu hình / đang có phiên mở / dựng URL hỏng /
    /// session.start() thất bại) gọi completion ĐỒNG BỘ
    /// trên luồng của người gọi — người gọi phải ở main
    /// (hiện tại duy nhất là nút bấm ở CardsView; kiểm
    /// duyệt vòng 1 ghế C, M4).
    static func signIn(completion: @escaping (Bool) -> Void) {
        guard DriveConfig.isConfigured else {
            // Chưa điền client ID thật: nói thẳng trạng thái
            // vào mục Drive + log, không mở trang Google lỗi.
            DiagLog.log(.drive,
                        "đăng nhập bị chặn: chưa cấu hình OAuth client ID (PLACEHOLDER)")
            DriveSettings.recordFailure(
                "Bản này chưa điền OAuth client ID — điền client ID thật trước khi test Drive (xem DriveConfig trong DriveSync.swift).")
            completion(false)
            return
        }
        guard activeSession == nil else {
            DiagLog.log(.drive,
                        "đăng nhập: đang có một phiên mở — bỏ qua lần gọi này")
            completion(false)
            return
        }
        let verifier = randomURLSafeString(length: 64)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomURLSafeString(length: 32)

        var components = URLComponents(string: DriveConfig.authEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: DriveConfig.oauthClientID),
            URLQueryItem(name: "redirect_uri", value: DriveConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: DriveConfig.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            // offline + consent: bảo đảm Google cấp refresh
            // token ngay lần đầu (không có refresh token thì
            // app không tự đồng bộ lâu dài được).
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authURL = components?.url else {
            DiagLog.log(.drive, "đăng nhập: dựng URL uỷ quyền thất bại")
            completion(false)
            return
        }
        let provider = DriveAuthPresentationContext()
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: DriveConfig.callbackScheme
        ) { callbackURL, error in
            activeSession = nil
            activeContextProvider = nil
            if let error {
                let nsError = error as NSError
                if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                   nsError.code == ASWebAuthenticationSessionError.Code
                       .canceledLogin.rawValue {
                    DiagLog.log(.drive,
                                "đăng nhập: anh đã huỷ ở màn hình Google")
                } else {
                    DiagLog.log(.drive,
                                "đăng nhập THẤT BẠI — \(nsError.domain) code=\(nsError.code)")
                }
                DispatchQueue.main.async { completion(false) }
                return
            }
            guard let callbackURL,
                  let items = URLComponents(
                      url: callbackURL, resolvingAgainstBaseURL: false)?
                      .queryItems,
                  items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value
            else {
                DiagLog.log(.drive,
                            "đăng nhập THẤT BẠI — callback thiếu code hoặc lệch state")
                DispatchQueue.main.async { completion(false) }
                return
            }
            exchangeCode(code, verifier: verifier) { success in
                DispatchQueue.main.async { completion(success) }
            }
        }
        session.presentationContextProvider = provider
        activeSession = session
        activeContextProvider = provider
        DiagLog.log(.drive, "đăng nhập: mở phiên uỷ quyền Google")
        if !session.start() {
            activeSession = nil
            activeContextProvider = nil
            DiagLog.log(.drive, "đăng nhập THẤT BẠI — phiên không khởi động được")
            completion(false)
        }
    }

    /// Đổi mã uỷ quyền lấy token; lưu Keychain + mốc hết hạn;
    /// lấy email hiển thị (best-effort, không ghi log email).
    private static func exchangeCode(
        _ code: String, verifier: String,
        completion: @escaping (Bool) -> Void
    ) {
        postTokenForm([
            ("client_id", DriveConfig.oauthClientID),
            ("code", code),
            ("code_verifier", verifier),
            ("grant_type", "authorization_code"),
            ("redirect_uri", DriveConfig.redirectURI),
        ]) { result in
            switch result {
            case .failure(let error):
                DiagLog.log(.drive,
                            "đăng nhập THẤT BẠI ở bước đổi mã — \(error.domain) code=\(error.code)")
                // Lý do phải hiện lên mục Drive như các
                // nhánh lỗi đăng nhập khác, không chỉ nằm
                // trong log (kiểm duyệt vòng 1 ghế A,
                // MINOR-7).
                DriveSettings.recordFailure(
                    "Đăng nhập Google thất bại ở bước đổi mã — anh thử đăng nhập lại giúp.")
                completion(false)
            case .success(let token):
                guard let refresh = token.refreshToken else {
                    DiagLog.log(.drive,
                                "đăng nhập THẤT BẠI — Google không cấp refresh token")
                    DriveSettings.recordFailure(
                        "Google không cấp quyền đồng bộ lâu dài cho lần đăng nhập này — anh thử đăng nhập lại giúp.")
                    completion(false)
                    return
                }
                store(token: token, refreshToken: refresh)
                DiagLog.log(.drive, "đăng nhập THÀNH CÔNG")
                DriveSettings.postStatusChanged()
                fetchAccountEmail()
                completion(true)
            }
        }
    }

    // MARK: Đăng xuất

    /// Xoá token khỏi Keychain + dọn trạng thái phiên +
    /// huỷ lượt đồng bộ đang chạy/đang chờ. (Thu hồi token
    /// phía Google là việc anh làm ở trang tài khoản Google
    /// nếu muốn — app không tự gọi thu hồi.)
    static func signOut() {
        DriveEngine.cancelCurrentPass()
        DriveKeychain.delete(account: DriveKeychain.accessTokenAccount)
        DriveKeychain.delete(account: DriveKeychain.refreshTokenAccount)
        DriveSettings.clearSignInState()
        DiagLog.log(.drive, "đăng xuất Google — đã xoá token khỏi Keychain")
        DriveSettings.postStatusChanged()
    }

    // MARK: Access token cho engine

    /// Đưa access token còn hạn; hết hạn thì làm mới bằng
    /// refresh token. sessionExpired = true khi Google báo
    /// refresh token chết (invalid_grant) — phiên bị xoá để
    /// UI về "Chưa đăng nhập"; lỗi mạng tạm thời KHÔNG xoá
    /// phiên (lượt sau tự thử lại).
    static func validAccessToken(
        completion: @escaping (_ token: String?, _ sessionExpired: Bool) -> Void
    ) {
        if let access = DriveKeychain.read(
               account: DriveKeychain.accessTokenAccount),
           let expiry = DriveSettings.tokenExpiry,
           expiry > Date().addingTimeInterval(120) {
            completion(access, false)
            return
        }
        guard let refresh = DriveKeychain.read(
            account: DriveKeychain.refreshTokenAccount) else {
            completion(nil, true)
            return
        }
        postTokenForm([
            ("client_id", DriveConfig.oauthClientID),
            ("refresh_token", refresh),
            ("grant_type", "refresh_token"),
        ]) { result in
            switch result {
            case .success(let token):
                // Google thường không cấp refresh token mới
                // ở lượt làm mới — giữ nguyên token cũ nếu
                // đáp ứng không kèm cái mới.
                store(token: token,
                      refreshToken: token.refreshToken ?? refresh)
                completion(token.accessToken, false)
            case .failure(let error):
                if error.domain == DriveHTTP.errorDomain,
                   error.code == 400 || error.code == 401 {
                    DriveKeychain.delete(
                        account: DriveKeychain.accessTokenAccount)
                    DriveKeychain.delete(
                        account: DriveKeychain.refreshTokenAccount)
                    DriveSettings.clearSignInState()
                    DiagLog.log(.drive,
                                "phiên đăng nhập Google đã hết hạn — đã xoá token, cần đăng nhập lại")
                    DriveSettings.postStatusChanged()
                    completion(nil, true)
                } else {
                    DiagLog.log(.drive,
                                "làm mới token THẤT BẠI (tạm thời) — \(error.domain) code=\(error.code)")
                    completion(nil, false)
                }
            }
        }
    }

    // MARK: Nội bộ

    private static func store(token: DriveTokenResponse,
                              refreshToken: String) {
        DriveKeychain.save(token.accessToken,
                           account: DriveKeychain.accessTokenAccount)
        DriveKeychain.save(refreshToken,
                           account: DriveKeychain.refreshTokenAccount)
        DriveSettings.tokenExpiry =
            Date().addingTimeInterval(TimeInterval(token.expiresIn))
    }

    /// Lấy email tài khoản qua about.get (cùng scope
    /// drive.file) để hiện ở Cài đặt. Best-effort: hỏng thì
    /// UI chỉ hiện "Đã đăng nhập". Email KHÔNG ghi log.
    private static func fetchAccountEmail() {
        guard let access = DriveKeychain.read(
            account: DriveKeychain.accessTokenAccount) else { return }
        var components = URLComponents(
            string: "\(DriveConfig.apiBase)/about")
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "user")
        ]
        guard let url = components?.url else { return }
        DriveHTTP.perform(token: access, method: "GET", url: url) { result in
            guard case .success(let data) = result,
                  let about = try? JSONDecoder().decode(
                      DriveAboutResponse.self, from: data),
                  let email = about.user?.emailAddress else { return }
            DriveSettings.accountEmail = email
            DriveSettings.postStatusChanged()
        }
    }

    /// POST form tới endpoint token. Lỗi HTTP -> NSError
    /// domain DriveHTTP.errorDomain, code = mã trạng thái.
    private static func postTokenForm(
        _ items: [(String, String)],
        completion: @escaping (Result<DriveTokenResponse, NSError>) -> Void
    ) {
        guard let url = URL(string: DriveConfig.tokenEndpoint) else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(items)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error as NSError))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data, (200..<300).contains(status) else {
                completion(.failure(NSError(
                    domain: DriveHTTP.errorDomain, code: status,
                    userInfo: nil)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(
                    DriveTokenResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error as NSError))
            }
        }.resume()
    }

    private static func formBody(_ items: [(String, String)]) -> Data {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-._~"))
        let parts = items.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }
        return Data(parts.joined(separator: "&").utf8)
    }

    private static func randomURLSafeString(length: Int) -> String {
        let charset = Array(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Neo trình diễn cho ASWebAuthenticationSession: cửa sổ
/// khoá của scene đang foreground (cùng thuật toán các
/// presenter UIKit thuần khác trong app).
final class DriveAuthPresentationContext: NSObject,
    ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first
        if let window = scene?.windows.first(where: { $0.isKeyWindow })
            ?? scene?.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}

// MARK: Drive REST — URLSession thuần, không thư viện ngoài

/// Một file/thư mục trên Drive (chỉ các trường engine cần).
struct DriveFileResource: Codable {
    var id: String
    var name: String
    var mimeType: String?
    /// Drive trả size dạng CHUỖI (và thư mục thì không có).
    var size: String?
    var parents: [String]?
    var trashed: Bool?

    var sizeBytes: Int? { size.flatMap { Int($0) } }
}

struct DriveFileListResponse: Codable {
    var files: [DriveFileResource]
    var nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case files, nextPageToken
    }

    /// Giải mã PHÒNG THỦ (kiểm duyệt vòng 1 ghế A,
    /// MINOR-3): khoá `files` THIẾU hoặc sai kiểu -> []
    /// thay vì làm hỏng cả đáp ứng — một đáp ứng liệt kê
    /// văng ở đây sẽ bị engine hiểu là liệt kê hỏng và
    /// dừng lượt oan.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        files = (try? container.decodeIfPresent(
            [DriveFileResource].self, forKey: .files)) ?? []
        nextPageToken = try? container.decodeIfPresent(
            String.self, forKey: .nextPageToken)
    }
}

/// Metadata khi tạo file/thư mục (gửi kèm multipart hoặc JSON).
struct DriveCreateMetadata: Codable {
    var name: String
    var mimeType: String?
    var parents: [String]?
}

enum DriveHTTP {
    /// Domain lỗi HTTP của lớp Drive: code = mã trạng thái.
    /// Log chỉ ghi domain+code này, không ghi thân đáp ứng.
    static let errorDomain = "DriveHTTP"

    /// Gửi một request đã gắn token. 2xx -> Data; còn lại ->
    /// NSError(domain: DriveHTTP, code: status). Lỗi mạng
    /// đi thẳng NSError gốc (NSURLErrorDomain + code).
    static func perform(
        token: String, method: String, url: URL,
        body: Data? = nil, contentType: String? = nil,
        completion: @escaping (Result<Data, NSError>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)",
                         forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error as NSError))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data, (200..<300).contains(status) else {
                completion(.failure(NSError(
                    domain: errorDomain, code: status, userInfo: nil)))
                return
            }
            completion(.success(data))
        }.resume()
    }
}

/// Các phép gọi Drive API mà engine dùng — mọi hàm đều
/// completion-based; engine tự đưa kết quả về hàng đợi lượt.
enum DriveAPI {
    private static let fieldsParam =
        "files(id,name,mimeType,size,parents,trashed),nextPageToken"

    /// Liệt kê TOÀN BỘ con trực tiếp của một thư mục (đi hết
    /// các trang). Chỉ file app tự tạo hiện ra (scope
    /// drive.file) — đúng phạm vi §2.3.
    static func listChildren(
        token: String, parentID: String,
        completion: @escaping (Result<[DriveFileResource], NSError>) -> Void
    ) {
        listChildrenPage(token: token, parentID: parentID,
                         pageToken: nil, accumulated: [],
                         completion: completion)
    }

    private static func listChildrenPage(
        token: String, parentID: String, pageToken: String?,
        accumulated: [DriveFileResource],
        completion: @escaping (Result<[DriveFileResource], NSError>) -> Void
    ) {
        var components = URLComponents(string: "\(DriveConfig.apiBase)/files")
        var items = [
            URLQueryItem(name: "q",
                         value: "'\(parentID)' in parents and trashed = false"),
            URLQueryItem(name: "fields", value: fieldsParam),
            URLQueryItem(name: "pageSize", value: "1000"),
            URLQueryItem(name: "spaces", value: "drive"),
        ]
        if let pageToken {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = items
        guard let url = components?.url else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "GET", url: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                do {
                    let page = try JSONDecoder().decode(
                        DriveFileListResponse.self, from: data)
                    let all = accumulated + page.files
                    if let next = page.nextPageToken {
                        listChildrenPage(token: token, parentID: parentID,
                                         pageToken: next, accumulated: all,
                                         completion: completion)
                    } else {
                        completion(.success(all))
                    }
                } catch {
                    completion(.failure(error as NSError))
                }
            }
        }
    }

    /// Đọc một file theo id (kiểm đệm thư mục còn sống).
    static func getFile(
        token: String, fileID: String,
        completion: @escaping (Result<DriveFileResource, NSError>) -> Void
    ) {
        var components = URLComponents(
            string: "\(DriveConfig.apiBase)/files/\(fileID)")
        components?.queryItems = [
            URLQueryItem(name: "fields",
                         value: "id,name,mimeType,size,parents,trashed")
        ]
        guard let url = components?.url else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "GET", url: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                do {
                    completion(.success(try JSONDecoder().decode(
                        DriveFileResource.self, from: data)))
                } catch {
                    completion(.failure(error as NSError))
                }
            }
        }
    }

    /// Tải nội dung một file (alt=media).
    static func download(
        token: String, fileID: String,
        completion: @escaping (Result<Data, NSError>) -> Void
    ) {
        var components = URLComponents(
            string: "\(DriveConfig.apiBase)/files/\(fileID)")
        components?.queryItems = [URLQueryItem(name: "alt", value: "media")]
        guard let url = components?.url else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "GET", url: url,
                          completion: completion)
    }

    /// Tạo thư mục con.
    static func createFolder(
        token: String, name: String, parentID: String,
        completion: @escaping (Result<DriveFileResource, NSError>) -> Void
    ) {
        let metadata = DriveCreateMetadata(
            name: name, mimeType: DriveConfig.folderMIME,
            parents: [parentID])
        guard let body = try? JSONEncoder().encode(metadata),
              let url = URL(string: "\(DriveConfig.apiBase)/files") else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "POST", url: url,
                          body: body, contentType: "application/json") { result in
            decodeResource(result, completion: completion)
        }
    }

    /// Tạo file mới kèm nội dung (multipart/related: phần
    /// metadata JSON + phần nội dung) trong một thư mục.
    static func createFile(
        token: String, name: String, parentID: String,
        data: Data, mimeType: String,
        completion: @escaping (Result<DriveFileResource, NSError>) -> Void
    ) {
        let metadata = DriveCreateMetadata(
            name: name, mimeType: mimeType, parents: [parentID])
        guard let metadataData = try? JSONEncoder().encode(metadata) else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        let boundary = "glkeeper-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        body.append(metadataData)
        body.append(Data("\r\n--\(boundary)\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--".utf8))
        guard let url = URL(
            string: "\(DriveConfig.uploadBase)/files?uploadType=multipart")
        else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(
            token: token, method: "POST", url: url, body: body,
            contentType: "multipart/related; boundary=\(boundary)") { result in
            decodeResource(result, completion: completion)
        }
    }

    /// Cập nhật nội dung một file đã có (uploadType=media).
    static func updateContent(
        token: String, fileID: String, data: Data, mimeType: String,
        completion: @escaping (Result<Data, NSError>) -> Void
    ) {
        guard let url = URL(
            string: "\(DriveConfig.uploadBase)/files/\(fileID)?uploadType=media")
        else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "PATCH", url: url,
                          body: data, contentType: mimeType,
                          completion: completion)
    }

    /// Chuyển một file/thư mục sang thư mục cha khác (dùng
    /// cho receipts <-> _deleted — chuyển, không xoá).
    static func move(
        token: String, fileID: String,
        addParent: String, removeParent: String,
        completion: @escaping (Result<Data, NSError>) -> Void
    ) {
        var components = URLComponents(
            string: "\(DriveConfig.apiBase)/files/\(fileID)")
        components?.queryItems = [
            URLQueryItem(name: "addParents", value: addParent),
            URLQueryItem(name: "removeParents", value: removeParent),
        ]
        guard let url = components?.url else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "PATCH", url: url,
                          body: Data("{}".utf8),
                          contentType: "application/json",
                          completion: completion)
    }

    /// Đưa một file vào thùng rác của Drive (trashed =
    /// true — khôi phục được, KHÔNG xoá vĩnh viễn). Dùng
    /// để dọn file bằng chứng thừa trong thư mục tờ, khớp
    /// bước dọn original-*/enhanced.* của lớp gương.
    static func trashFile(
        token: String, fileID: String,
        completion: @escaping (Result<Data, NSError>) -> Void
    ) {
        guard let url = URL(
            string: "\(DriveConfig.apiBase)/files/\(fileID)") else {
            completion(.failure(NSError(
                domain: "DriveSync", code: -1, userInfo: nil)))
            return
        }
        DriveHTTP.perform(token: token, method: "PATCH", url: url,
                          body: Data("{\"trashed\": true}".utf8),
                          contentType: "application/json",
                          completion: completion)
    }

    private static func decodeResource(
        _ result: Result<Data, NSError>,
        completion: @escaping (Result<DriveFileResource, NSError>) -> Void
    ) {
        switch result {
        case .failure(let error):
            completion(.failure(error))
        case .success(let data):
            do {
                completion(.success(try JSONDecoder().decode(
                    DriveFileResource.self, from: data)))
            } catch {
                completion(.failure(error as NSError))
            }
        }
    }

    /// MIME theo đuôi file bằng chứng (khớp họ file lớp
    /// gương sao: jpg/pdf là chính, thêm png/heic cho đủ).
    static func mimeType(forFileName name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
}

// MARK: Điểm kích hoạt Drive

enum DriveSync {
    static let statusChangedNotification =
        Notification.Name("glkeeper.drive.statusChanged")

    /// Điểm kích hoạt DUY NHẤT — gọi tại đúng 13 điểm lưu/
    /// xoá mà MirrorSync đang nối (cộng thêm nút "Đồng bộ
    /// ngay" ở Cài đặt). Chưa đăng nhập -> thoát ngay, không
    /// ghi lỗi (chưa đăng nhập không phải lỗi). Đọc sổ lỗi ở
    /// bước này cũng nuốt im: Drive là lớp phụ, lượt mở app
    /// sau tự bù.
    static func requestSync(using context: ModelContext) {
        guard DriveAuth.isSignedIn else { return }
        let receipts: [Receipt]
        do {
            receipts = try context.fetch(FetchDescriptor<Receipt>())
        } catch {
            return
        }
        let snapshots = receipts.map { MirrorReceiptSnapshot.make(from: $0) }
        DriveEngine.enqueue(snapshots: snapshots,
                            imageDirectory: ImageStore.directory)
    }
}

// MARK: Engine đồng bộ (hàng đợi serial riêng)

/// Trạng thái một lượt đồng bộ — chỉ chạm trên hàng đợi
/// lượt (mọi continuation đều được đưa về hàng đợi này).
final class DrivePassContext {
    let snapshots: [MirrorReceiptSnapshot]
    let imageDirectory: URL
    var token = ""
    var rootID = ""
    var receiptsID = ""
    var deletedID = ""
    var manifest = MirrorManifest(updatedAt: Date(), entries: [])
    var manifestByID: [String: MirrorManifestEntry] = [:]
    var manifestFileID: String?
    var receiptsByName: [String: DriveFileResource] = [:]
    var deletedByName: [String: DriveFileResource] = [:]
    var deletedLoaded = false
    /// Lượt bị dừng an toàn giữa chừng (liệt kê _deleted
    /// hỏng): không xoá, không ghi manifest, không ghi kết
    /// quả lượt — recordFailure đã ghi ở điểm dừng.
    var passAborted = false
    /// Thế hệ lượt lúc bắt đầu (đăng xuất làm tăng thế hệ
    /// ở DriveEngine -> lượt đang chạy tự dừng ở điểm kiểm
    /// tra gần nhất, không ghi thêm gì).
    var generation = 0
    var uploadedFiles = 0
    var failedReceipts = 0
    var failedDeletes = 0
    var missingOriginals = 0
    var movedToDeleted = 0
    var conflictCopies = 0

    init(snapshots: [MirrorReceiptSnapshot], imageDirectory: URL) {
        self.snapshots = snapshots
        self.imageDirectory = imageDirectory
    }
}

enum DriveEngine {
    /// Hàng đợi SERIAL của riêng lớp Drive: các lượt không
    /// bao giờ chạy chồng nhau. Kích hoạt trong lúc đang có
    /// lượt chạy thì GỘP: chỉ giữ bộ snapshot mới nhất, chạy
    /// thêm đúng một lượt nối tiếp khi lượt hiện tại xong
    /// (khác lớp gương ở điểm này vì mỗi lượt Drive tốn lượt
    /// gọi mạng — lựa chọn có chủ đích, ghi ở DRIVE-DIFF).
    static let queue = DispatchQueue(label: "glkeeper.drive.pass",
                                     qos: .utility)
    private static var running = false
    private static var pending:
        (snapshots: [MirrorReceiptSnapshot], imageDirectory: URL)?
    /// Thế hệ lượt: đăng xuất tăng số này TRÊN hàng đợi
    /// lượt -> lượt đang chạy (giữ thế hệ cũ trong ctx) tự
    /// dừng ở điểm kiểm tra gần nhất, không ghi thêm gì.
    private static var generation = 0

    static func enqueue(snapshots: [MirrorReceiptSnapshot],
                        imageDirectory: URL) {
        queue.async {
            if running {
                pending = (snapshots, imageDirectory)
                return
            }
            start(snapshots: snapshots, imageDirectory: imageDirectory)
        }
    }

    /// Huỷ lượt đang chạy + lượt đang chờ (anh đăng xuất
    /// giữa lượt — kiểm duyệt vòng 1 ghế A, MINOR-8): lượt
    /// đang chạy dừng ở điểm kiểm tra thế hệ gần nhất —
    /// không xoá, không ghi manifest, không ghi kết quả
    /// lượt. Tờ đang tải dở có thể hoàn tất nốt bằng token
    /// đã chụp (cùng tài khoản, cùng thư mục GL-Keeper —
    /// vô hại); từ tờ kế tiếp trở đi không chạy nữa.
    static func cancelCurrentPass() {
        queue.async {
            generation += 1
            pending = nil
        }
    }

    private static func start(snapshots: [MirrorReceiptSnapshot],
                              imageDirectory: URL) {
        running = true
        runPass(snapshots: snapshots, imageDirectory: imageDirectory) {
            running = false
            if let next = pending {
                pending = nil
                start(snapshots: next.snapshots,
                      imageDirectory: next.imageDirectory)
            }
        }
    }

    /// Đưa continuation về hàng đợi lượt — completion của
    /// URLSession chạy ở hàng đợi riêng của nó, mọi bước của
    /// engine phải quay về đây mới chạm được DrivePassContext.
    private static func hop(_ block: @escaping () -> Void) {
        queue.async(execute: block)
    }

    /// Lượt phải DỪNG NGAY và không ghi thêm gì (không
    /// xoá, không ghi manifest, không ghi kết quả lượt):
    /// hoặc bị dừng an toàn vì liệt kê _deleted hỏng
    /// (passAborted — recordFailure đã ghi ở điểm dừng),
    /// hoặc bị huỷ vì anh đăng xuất giữa lượt (thế hệ
    /// trong ctx đã cũ hơn thế hệ hiện tại của engine).
    private static func passStopped(_ ctx: DrivePassContext) -> Bool {
        ctx.passAborted || ctx.generation != generation
    }

    // MARK: Khung lượt

    private static func runPass(
        snapshots: [MirrorReceiptSnapshot], imageDirectory: URL,
        completion: @escaping () -> Void
    ) {
        let ctx = DrivePassContext(snapshots: snapshots,
                                   imageDirectory: imageDirectory)
        ctx.generation = generation
        DiagLog.log(.drive,
                    "lượt đồng bộ bắt đầu: \(snapshots.count) hoá đơn")
        DriveAuth.validAccessToken { token, sessionExpired in
            hop {
                // Đăng xuất trong lúc chờ token: lượt đã bị
                // huỷ — không ghi lỗi phiên, không chạy tiếp.
                guard ctx.generation == generation else {
                    completion()
                    return
                }
                guard let token else {
                    DriveSettings.recordFailure(sessionExpired
                        ? "Phiên đăng nhập Google đã hết hạn — anh đăng nhập lại trong Thẻ & Cài Đặt giúp."
                        : "Chưa gọi được Google Drive (mạng?) — app sẽ tự thử lại ở lượt sau.")
                    completion()
                    return
                }
                ctx.token = token
                resolveFolders(ctx: ctx) { ok in
                    guard ok else { completion(); return }
                    loadRemoteState(ctx: ctx) { stateOK in
                        // Trạng thái từ xa nạp không được
                        // (liệt kê hỏng) -> DỪNG lượt: chạy
                        // tiếp với chỉ mục rỗng sẽ tạo thư
                        // mục tờ TRÙNG trên Drive.
                        guard stateOK else { completion(); return }
                        processReceipts(ctx: ctx, index: 0) {
                            // Lượt bị dừng an toàn hoặc bị
                            // huỷ: không xoá, không ghi
                            // manifest, không ghi kết quả.
                            guard !passStopped(ctx) else {
                                completion()
                                return
                            }
                            processDeletions(ctx: ctx) {
                                uploadManifest(ctx: ctx) {
                                    completion()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Tìm-hoặc-tạo 3 thư mục khung (GL-Keeper / receipts /
    /// _deleted). Đệm id ở DriveSettings được kiểm sống bằng
    /// getFile trước khi tin; hỏng thì tìm theo tên, thiếu
    /// thì tạo. Lỗi cấp lượt -> recordFailure + dừng.
    private static func resolveFolders(
        ctx: DrivePassContext, completion: @escaping (Bool) -> Void
    ) {
        resolveOneFolder(ctx: ctx, name: DriveConfig.rootFolderName,
                         parentID: "root",
                         cachedID: DriveSettings.rootFolderID) { rootID in
            guard let rootID else {
                DriveSettings.recordFailure(
                    "Không mở được thư mục GL-Keeper trên Drive — app sẽ tự thử lại ở lượt sau.")
                completion(false)
                return
            }
            ctx.rootID = rootID
            DriveSettings.rootFolderID = rootID
            resolveOneFolder(ctx: ctx, name: DriveConfig.receiptsFolderName,
                             parentID: rootID,
                             cachedID: DriveSettings.receiptsFolderID) { receiptsID in
                guard let receiptsID else {
                    DriveSettings.recordFailure(
                        "Không mở được thư mục receipts trên Drive — app sẽ tự thử lại ở lượt sau.")
                    completion(false)
                    return
                }
                ctx.receiptsID = receiptsID
                DriveSettings.receiptsFolderID = receiptsID
                resolveOneFolder(ctx: ctx, name: DriveConfig.deletedFolderName,
                                 parentID: rootID,
                                 cachedID: DriveSettings.deletedFolderID) { deletedID in
                    guard let deletedID else {
                        DriveSettings.recordFailure(
                            "Không mở được thư mục _deleted trên Drive — app sẽ tự thử lại ở lượt sau.")
                        completion(false)
                        return
                    }
                    ctx.deletedID = deletedID
                    DriveSettings.deletedFolderID = deletedID
                    completion(true)
                }
            }
        }
    }

    private static func resolveOneFolder(
        ctx: DrivePassContext, name: String, parentID: String,
        cachedID: String?,
        completion: @escaping (String?) -> Void
    ) {
        func searchOrCreate() {
            DriveAPI.listChildren(token: ctx.token, parentID: parentID) { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "tìm thư mục \(name) THẤT BẠI — \(error.domain) code=\(error.code)")
                        completion(nil)
                    case .success(let children):
                        if let found = children.first(where: {
                            $0.name == name
                                && $0.mimeType == DriveConfig.folderMIME
                        }) {
                            completion(found.id)
                            return
                        }
                        DriveAPI.createFolder(token: ctx.token, name: name,
                                              parentID: parentID) { created in
                            hop {
                                switch created {
                                case .failure(let error):
                                    DiagLog.log(.drive,
                                                "tạo thư mục \(name) THẤT BẠI — \(error.domain) code=\(error.code)")
                                    completion(nil)
                                case .success(let folder):
                                    DiagLog.log(.drive,
                                                "đã tạo thư mục \(name) trên Drive")
                                    completion(folder.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        if let cachedID {
            DriveAPI.getFile(token: ctx.token, fileID: cachedID) { result in
                hop {
                    if case .success(let file) = result,
                       file.name == name,
                       file.mimeType == DriveConfig.folderMIME,
                       file.trashed != true {
                        completion(cachedID)
                    } else {
                        searchOrCreate()
                    }
                }
            }
        } else {
            searchOrCreate()
        }
    }

    /// Nạp trạng thái từ xa: manifest.json ở gốc GL-Keeper
    /// (đọc bằng MirrorJSON — ghi chú N1 của P2-1) + danh
    /// sách thư mục tờ trong receipts/. Manifest thiếu/đọc
    /// hỏng -> coi như trống: hướng an toàn như lớp gương
    /// (không phát hiện xoá, chỉ ghi mới/cập nhật).
    private static func loadRemoteState(
        ctx: DrivePassContext, completion: @escaping (Bool) -> Void
    ) {
        DriveAPI.listChildren(token: ctx.token, parentID: ctx.rootID) { result in
            hop {
                switch result {
                case .failure(let error):
                    DiagLog.log(.drive,
                                "liệt kê thư mục gốc THẤT BẠI — \(error.domain) code=\(error.code)")
                    DriveSettings.recordFailure(
                        "Chưa đọc được thư mục GL-Keeper trên Drive — app sẽ tự thử lại ở lượt sau.")
                    completion(false)
                    return
                case .success(let children):
                    loadReceiptsIndex(ctx: ctx) { indexOK in
                        guard indexOK else {
                            completion(false)
                            return
                        }
                        guard let manifestFile = children.first(
                            where: { $0.name == "manifest.json" })
                        else {
                            completion(true)
                            return
                        }
                        ctx.manifestFileID = manifestFile.id
                        DriveAPI.download(token: ctx.token,
                                          fileID: manifestFile.id) { downloaded in
                            hop {
                                switch downloaded {
                                case .failure(let error):
                                    // TẢI manifest hỏng (mạng)
                                    // KHÁC giải mã hỏng: manifest
                                    // là trạng thái nền của cả
                                    // lượt — coi như trống sẽ làm
                                    // tải lại toàn bộ bằng chứng
                                    // vô điều kiện + manifest ghi
                                    // cuối lượt làm mất các entry
                                    // deleted của lượt trước
                                    // (kiểm duyệt vòng 1 đợt 3
                                    // ghế B, LOGIC-2). DỪNG LƯỢT
                                    // như các bước nền khác
                                    // (liệt kê gốc/receipts).
                                    DiagLog.log(.drive,
                                                "tải manifest trên Drive THẤT BẠI — \(error.domain) code=\(error.code)")
                                    DriveSettings.recordFailure(
                                        "Chưa tải được manifest trên Drive — app sẽ tự thử lại ở lượt sau.")
                                    completion(false)
                                    return
                                case .success(let data):
                                    if let decoded = try? MirrorJSON.decoder()
                                        .decode(MirrorManifest.self, from: data) {
                                        ctx.manifest = decoded
                                        // Dựng từ điển bằng vòng lặp
                                        // last-wins như lớp gương
                                        // (MirrorSync.swift:593):
                                        // Dictionary(uniqueKeysWithValues:)
                                        // sẽ TRAP nếu manifest trên
                                        // Drive chứa id trùng — file
                                        // đó nằm ngoài tầm kiểm soát
                                        // tuyệt đối của app (kiểm
                                        // duyệt vòng 1, cả 3 ghế).
                                        var byID: [String: MirrorManifestEntry] = [:]
                                        for entry in decoded.entries {
                                            byID[entry.id] = entry
                                        }
                                        ctx.manifestByID = byID
                                    } else {
                                        // CHỈ giải mã hỏng mới coi
                                        // như trống (đúng thiết kế
                                        // §3 đã khai: hướng an
                                        // toàn như gương — không
                                        // phát hiện xoá; tìm thư
                                        // mục tờ dựa vào chỉ mục
                                        // sống, không dựa manifest).
                                        DiagLog.log(.drive,
                                                    "manifest trên Drive giải mã hỏng — lượt này coi như trống (hướng an toàn)")
                                    }
                                    completion(true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private static func loadReceiptsIndex(
        ctx: DrivePassContext, completion: @escaping (Bool) -> Void
    ) {
        DriveAPI.listChildren(token: ctx.token,
                              parentID: ctx.receiptsID) { result in
            hop {
                switch result {
                case .failure(let error):
                    // Chỉ mục thư mục tờ là trạng thái nền
                    // của cả lượt (quyết định tạo mới/dùng
                    // lại thư mục): hỏng thì DỪNG lượt như
                    // bước liệt kê gốc — chạy tiếp sẽ tạo
                    // thư mục tờ trùng trên Drive.
                    DiagLog.log(.drive,
                                "liệt kê thư mục receipts THẤT BẠI — \(error.domain) code=\(error.code)")
                    DriveSettings.recordFailure(
                        "Chưa đọc được thư mục receipts trên Drive — app sẽ tự thử lại ở lượt sau.")
                    completion(false)
                case .success(let children):
                    for child in children
                    where child.mimeType == DriveConfig.folderMIME {
                        ctx.receiptsByName[child.name] = child
                    }
                    completion(true)
                }
            }
        }
    }

    /// Nạp chỉ mục _deleted/ (lười, một lần mỗi lượt).
    /// Theo cùng kỷ luật DỪNG LƯỢT như hai bước liệt kê
    /// gốc/receipts: liệt kê hỏng -> ghi log + recordFailure
    /// + đánh dấu passAborted + báo false. Chạy tiếp với
    /// chỉ mục rỗng sẽ làm resolveReceiptFolder tạo thư
    /// mục tờ TRÙNG trong receipts/ trong khi bản cũ còn
    /// đậu ở _deleted/ (kiểm duyệt vòng 1, cả 3 ghế).
    private static func loadDeletedIndex(
        ctx: DrivePassContext, completion: @escaping (Bool) -> Void
    ) {
        if ctx.deletedLoaded {
            completion(true)
            return
        }
        DriveAPI.listChildren(token: ctx.token,
                              parentID: ctx.deletedID) { result in
            hop {
                switch result {
                case .failure(let error):
                    DiagLog.log(.drive,
                                "liệt kê thư mục _deleted THẤT BẠI — \(error.domain) code=\(error.code)")
                    DriveSettings.recordFailure(
                        "Chưa đọc được thư mục _deleted trên Drive — app sẽ tự thử lại ở lượt sau.")
                    ctx.passAborted = true
                    completion(false)
                case .success(let children):
                    ctx.deletedLoaded = true
                    for child in children
                    where child.mimeType == DriveConfig.folderMIME {
                        ctx.deletedByName[child.name] = child
                    }
                    completion(true)
                }
            }
        }
    }

    // MARK: Từng tờ

    private static func processReceipts(
        ctx: DrivePassContext, index: Int, completion: @escaping () -> Void
    ) {
        if index >= ctx.snapshots.count || passStopped(ctx) {
            completion()
            return
        }
        processOne(ctx: ctx, snapshot: ctx.snapshots[index]) {
            processReceipts(ctx: ctx, index: index + 1,
                            completion: completion)
        }
    }

    private static func processOne(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        completion: @escaping () -> Void
    ) {
        let hash = snapshot.contentHash()
        let previous = ctx.manifestByID[snapshot.folderID]
        let unchanged = previous?.status == "active"
            && previous?.contentHash == hash
        if unchanged {
            // Hash khớp manifest KHÔNG còn là lý do bỏ qua
            // mù (kiểm duyệt vòng 1 ghế B, LOGIC-1 — đúng
            // lỗi L2 lớp gương từng dính): thư mục/file của
            // tờ trên Drive có thể đã bị xoá ngoài app trong
            // khi manifest vẫn ghi khớp, và trước đây tờ bị
            // bỏ qua VĨNH VIỄN. Kiểm sự tồn tại + kích thước
            // bản Drive trước; đủ mới bỏ qua, thiếu/hụt thì
            // rơi xuống đường xử lý đầy đủ để tự chữa.
            verifyRemoteCopy(ctx: ctx, snapshot: snapshot) { intact in
                if intact {
                    completion()
                } else {
                    DiagLog.log(.drive,
                                "tờ \(snapshot.folderID): bản trên Drive thiếu/hụt dù hash khớp manifest — xử lý lại để tự chữa")
                    processOneFully(ctx: ctx, snapshot: snapshot,
                                    hash: hash, previous: previous,
                                    unchanged: true,
                                    completion: completion)
                }
            }
            return
        }
        processOneFully(ctx: ctx, snapshot: snapshot, hash: hash,
                        previous: previous, unchanged: false,
                        completion: completion)
    }

    /// Kiểm bản Drive của một tờ có hash khớp manifest:
    /// thư mục tờ còn trong chỉ mục receipts/ + receipt.json
    /// còn trong thư mục và đúng kích thước phong bì mã
    /// hoá tại máy + từng file bằng chứng còn đó và đúng
    /// kích thước đích (kỷ luật tự chữa của lớp gương:
    /// đích thiếu/lệch thì ghi lại). Kiểm không xong (liệt
    /// kê hỏng) -> coi như KHÔNG nguyên vẹn: đường xử lý
    /// đầy đủ sẽ liệt kê lại và báo lỗi lẻ nếu vẫn hỏng.
    private static func verifyRemoteCopy(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        completion: @escaping (Bool) -> Void
    ) {
        guard let folder = ctx.receiptsByName[snapshot.folderID] else {
            completion(false)
            return
        }
        DriveAPI.listChildren(token: ctx.token,
                              parentID: folder.id) { result in
            hop {
                switch result {
                case .failure:
                    completion(false)
                case .success(let children):
                    var filesByName: [String: DriveFileResource] = [:]
                    for child in children {
                        filesByName[child.name] = child
                    }
                    completion(remoteCopyIntact(
                        ctx: ctx, snapshot: snapshot,
                        filesByName: filesByName))
                }
            }
        }
    }

    private static func remoteCopyIntact(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        filesByName: [String: DriveFileResource]
    ) -> Bool {
        guard let remoteJSON = filesByName["receipt.json"] else {
            return false
        }
        // receipt.json là DẤU CHỐT của tờ: chỉ kiểm TỒN
        // TẠI là chưa đủ (kiểm duyệt vòng 1 mới ghế B,
        // LOGIC-1) — file bị sửa/hỏng TẠI CHỖ từ ngoài
        // app vẫn "còn đó" nhưng nội dung đã trôi, và tờ
        // sẽ bị bỏ qua vĩnh viễn. So thêm KÍCH THƯỚC với
        // phong bì mã hoá tại máy: MirrorJSON cho byte ổn
        // định với snapshot không đổi (khoá đã sắp xếp +
        // ngày ISO8601 bề rộng cố định) — đúng cơ chế
        // mirrorOne của lớp gương dùng cho chính file
        // này. Lệch kích thước (hoặc Drive không báo kích
        // thước, hoặc mã hoá tại máy hỏng) -> KHÔNG
        // nguyên vẹn: rơi xuống processOneFully, nơi
        // uploadReceiptJSON tải bản từ xa về so
        // contentHash để tự chữa. Chi phí không đổi:
        // dùng lại chính lượt liệt kê đã có của verify.
        guard let expectedJSONSize = localReceiptJSONSize(
                  ctx: ctx, snapshot: snapshot),
              remoteJSON.sizeBytes == expectedJSONSize else {
            return false
        }
        let fm = FileManager.default
        func evidenceIntact(sourceName: String,
                            mirrorName: String) -> Bool {
            guard let remote = filesByName[mirrorName] else {
                return false
            }
            // Nguồn trên máy đã mất: không còn kích thước để
            // so — sự tồn tại của bản Drive là mức kiểm tối
            // đa còn làm được (phong bì receipt.json đã ghi
            // missing trung thực từ lượt xử lý đầy đủ).
            guard let attributes = try? fm.attributesOfItem(
                      atPath: ctx.imageDirectory
                          .appendingPathComponent(sourceName).path),
                  let size = attributes[.size] as? Int else {
                return true
            }
            return remote.sizeBytes == size
        }
        for (index, sourceName)
        in snapshot.sourceOriginalFileNames.enumerated() {
            let ext = (sourceName as NSString).pathExtension
            let mirrorName = "original-\(index + 1)."
                + (ext.isEmpty ? "jpg" : ext)
            if !evidenceIntact(sourceName: sourceName,
                               mirrorName: mirrorName) {
                return false
            }
        }
        if let enhancedName = snapshot.enhancedImageFileName,
           !enhancedName.isEmpty {
            let ext = (enhancedName as NSString).pathExtension
            let mirrorName = "enhanced." + (ext.isEmpty ? "jpg" : ext)
            if !evidenceIntact(sourceName: enhancedName,
                               mirrorName: mirrorName) {
                return false
            }
        }
        return true
    }

    /// Kích thước (byte) của phong bì receipt.json nếu
    /// mã hoá snapshot tại máy NGAY LÚC NÀY: dựng refs
    /// bằng đúng cách uploadOneEvidence dựng (nguồn còn
    /// thì byteCount = kích thước thật, nguồn đã mất thì
    /// missing), gói vào MirrorReceiptFile và mã hoá
    /// bằng MirrorJSON — y hệt uploadReceiptJSON và
    /// mirrorOne của lớp gương. nil khi mã hoá hỏng.
    private static func localReceiptJSONSize(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot
    ) -> Int? {
        let fm = FileManager.default
        func localRef(sourceName: String,
                      mirrorName: String) -> MirrorOriginalRef {
            guard let attributes = try? fm.attributesOfItem(
                      atPath: ctx.imageDirectory
                          .appendingPathComponent(sourceName).path),
                  let size = attributes[.size] as? Int else {
                return MirrorOriginalRef(
                    mirrorFileName: mirrorName,
                    sourceFileName: sourceName,
                    byteCount: nil, missing: true)
            }
            return MirrorOriginalRef(
                mirrorFileName: mirrorName,
                sourceFileName: sourceName,
                byteCount: size, missing: false)
        }
        var originals: [MirrorOriginalRef] = []
        for (index, sourceName)
        in snapshot.sourceOriginalFileNames.enumerated() {
            let ext = (sourceName as NSString).pathExtension
            let mirrorName = "original-\(index + 1)."
                + (ext.isEmpty ? "jpg" : ext)
            originals.append(localRef(sourceName: sourceName,
                                      mirrorName: mirrorName))
        }
        var enhancedRef: MirrorOriginalRef? = nil
        if let enhancedName = snapshot.enhancedImageFileName,
           !enhancedName.isEmpty {
            let ext = (enhancedName as NSString).pathExtension
            let mirrorName = "enhanced." + (ext.isEmpty ? "jpg" : ext)
            enhancedRef = localRef(sourceName: enhancedName,
                                   mirrorName: mirrorName)
        }
        let envelope = MirrorReceiptFile(
            formatVersion: 1, mirroredAt: Date(),
            receipt: snapshot, originals: originals,
            enhanced: enhancedRef)
        return (try? MirrorJSON.encoder().encode(envelope))?.count
    }

    /// Đường xử lý ĐẦY ĐỦ của một tờ (nội dung đổi, hoặc
    /// bản Drive cần tự chữa): mở thư mục tờ, liệt kê, tải
    /// bằng chứng, dọn file thừa, chốt bằng receipt.json.
    private static func processOneFully(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        hash: String, previous: MirrorManifestEntry?,
        unchanged: Bool,
        completion: @escaping () -> Void
    ) {
        resolveReceiptFolder(ctx: ctx, snapshot: snapshot,
                             previous: previous) { folder in
            guard let folder else {
                if !passStopped(ctx) { ctx.failedReceipts += 1 }
                completion()
                return
            }
            DriveAPI.listChildren(token: ctx.token,
                                  parentID: folder.id) { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "liệt kê thư mục tờ \(snapshot.folderID) THẤT BẠI — \(error.domain) code=\(error.code)")
                        ctx.failedReceipts += 1
                        completion()
                    case .success(let children):
                        var filesByName: [String: DriveFileResource] = [:]
                        for child in children {
                            filesByName[child.name] = child
                        }
                        uploadOriginals(
                            ctx: ctx, snapshot: snapshot,
                            folderID: folder.id, filesByName: filesByName,
                            index: 0, originals: [],
                            enhanced: nil,
                            unchanged: unchanged) { originals, enhanced, ok in
                            guard ok else {
                                ctx.failedReceipts += 1
                                completion()
                                return
                            }
                            cleanupStaleEvidence(
                                ctx: ctx, snapshot: snapshot,
                                filesByName: filesByName)
                            uploadReceiptJSON(
                                ctx: ctx, snapshot: snapshot, hash: hash,
                                previous: previous, folderID: folder.id,
                                filesByName: filesByName,
                                originals: originals,
                                enhanced: enhanced) { ok in
                                if ok {
                                    ctx.manifestByID[snapshot.folderID] =
                                        MirrorManifestEntry(
                                            id: snapshot.folderID,
                                            stableID: snapshot.stableID,
                                            vendor: snapshot.vendor,
                                            date: snapshot.date,
                                            totalCents: snapshot.totalCents,
                                            contentHash: hash,
                                            updatedAt: Date(),
                                            status: "active",
                                            deletedAt: nil)
                                } else {
                                    ctx.failedReceipts += 1
                                }
                                completion()
                            }
                        }
                    }
                }
            }
        }
    }

    /// Thư mục của một tờ: có trong receipts/ thì dùng; từng
    /// bị xoá (đang ở _deleted/) thì CHUYỂN về receipts/;
    /// chưa có thì tạo mới. Mọi kết quả đều ghi vào chỉ mục
    /// của lượt để bước xoá dùng chung.
    private static func resolveReceiptFolder(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        previous: MirrorManifestEntry?,
        completion: @escaping (DriveFileResource?) -> Void
    ) {
        if let existing = ctx.receiptsByName[snapshot.folderID] {
            completion(existing)
            return
        }
        func createFresh() {
            DriveAPI.createFolder(token: ctx.token, name: snapshot.folderID,
                                  parentID: ctx.receiptsID) { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "tạo thư mục tờ \(snapshot.folderID) THẤT BẠI — \(error.domain) code=\(error.code)")
                        completion(nil)
                    case .success(let folder):
                        ctx.receiptsByName[snapshot.folderID] = folder
                        completion(folder)
                    }
                }
            }
        }
        if previous?.status == "deleted" {
            loadDeletedIndex(ctx: ctx) { indexOK in
                guard indexOK else {
                    // Lượt đã bị dừng an toàn ngay trong
                    // loadDeletedIndex (đã ghi log +
                    // recordFailure + passAborted): KHÔNG
                    // rơi xuống tạo thư mục mới.
                    completion(nil)
                    return
                }
                if let parked = ctx.deletedByName[snapshot.folderID] {
                    DriveAPI.move(token: ctx.token, fileID: parked.id,
                                  addParent: ctx.receiptsID,
                                  removeParent: ctx.deletedID) { result in
                        hop {
                            switch result {
                            case .failure(let error):
                                DiagLog.log(.drive,
                                            "chuyển tờ \(snapshot.folderID) về receipts THẤT BẠI — \(error.domain) code=\(error.code)")
                                completion(nil)
                            case .success:
                                ctx.deletedByName[snapshot.folderID] = nil
                                var moved = parked
                                moved.parents = [ctx.receiptsID]
                                ctx.receiptsByName[snapshot.folderID] = moved
                                completion(moved)
                            }
                        }
                    }
                } else {
                    createFresh()
                }
            }
        } else {
            createFresh()
        }
    }

    /// Tải lên các file bằng chứng của một tờ theo đúng tên
    /// lớp gương đặt (original-N.<đuôi>, enhanced.<đuôi>).
    /// Kỷ luật ghi như mirrorOne của lớp gương: tờ ĐÃ ĐỔI
    /// nội dung (unchanged = false) thì tải lại VÔ ĐIỀU
    /// KIỆN; tờ không đổi (đang tự chữa) thì chỉ tải khi
    /// file đích thiếu hoặc khác kích thước. File nguồn đã
    /// mất trên máy -> ghi nhận missing trung thực như gương.
    private static func uploadOriginals(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        folderID: String, filesByName: [String: DriveFileResource],
        index: Int, originals: [MirrorOriginalRef],
        enhanced: MirrorOriginalRef?,
        unchanged: Bool,
        completion: @escaping ([MirrorOriginalRef], MirrorOriginalRef?, Bool) -> Void
    ) {
        if index < snapshot.sourceOriginalFileNames.count {
            let sourceName = snapshot.sourceOriginalFileNames[index]
            let ext = (sourceName as NSString).pathExtension
            let mirrorName = "original-\(index + 1)."
                + (ext.isEmpty ? "jpg" : ext)
            uploadOneEvidence(
                ctx: ctx, sourceName: sourceName, mirrorName: mirrorName,
                folderID: folderID, filesByName: filesByName,
                unchanged: unchanged) { ref, ok in
                guard ok else {
                    completion(originals, enhanced, false)
                    return
                }
                if ref.missing { ctx.missingOriginals += 1 }
                uploadOriginals(
                    ctx: ctx, snapshot: snapshot, folderID: folderID,
                    filesByName: filesByName, index: index + 1,
                    originals: originals + [ref], enhanced: enhanced,
                    unchanged: unchanged,
                    completion: completion)
            }
            return
        }
        // Ảnh tăng nét — bằng chứng phái sinh, tải kèm khi có
        // (cùng luật với lớp gương).
        if let enhancedName = snapshot.enhancedImageFileName,
           !enhancedName.isEmpty {
            let ext = (enhancedName as NSString).pathExtension
            let mirrorName = "enhanced." + (ext.isEmpty ? "jpg" : ext)
            uploadOneEvidence(
                ctx: ctx, sourceName: enhancedName, mirrorName: mirrorName,
                folderID: folderID, filesByName: filesByName,
                unchanged: unchanged) { ref, ok in
                guard ok else {
                    completion(originals, enhanced, false)
                    return
                }
                completion(originals, ref, true)
            }
            return
        }
        completion(originals, enhanced, true)
    }

    private static func uploadOneEvidence(
        ctx: DrivePassContext, sourceName: String, mirrorName: String,
        folderID: String, filesByName: [String: DriveFileResource],
        unchanged: Bool,
        completion: @escaping (MirrorOriginalRef, Bool) -> Void
    ) {
        let fm = FileManager.default
        let source = ctx.imageDirectory.appendingPathComponent(sourceName)
        guard let attributes = try? fm.attributesOfItem(atPath: source.path),
              let size = attributes[.size] as? Int else {
            completion(MirrorOriginalRef(
                mirrorFileName: mirrorName, sourceFileName: sourceName,
                byteCount: nil, missing: true), true)
            return
        }
        let ref = MirrorOriginalRef(
            mirrorFileName: mirrorName, sourceFileName: sourceName,
            byteCount: size, missing: false)
        // Bỏ qua CHỈ khi tờ không đổi nội dung (unchanged)
        // VÀ bản Drive đã đúng kích thước — đối chiếu điều
        // kiện của lớp gương (!unchanged || targetSize !=
        // size thì ghi). Tờ đã đổi mà chỉ so kích thước thì
        // ảnh mới trùng số byte với ảnh cũ sẽ bị giữ lại
        // bản cũ lặng lẽ (kiểm duyệt vòng 1 ghế B, MINOR-2).
        if unchanged, let remote = filesByName[mirrorName],
           remote.sizeBytes == size {
            completion(ref, true)
            return
        }
        guard let data = try? Data(contentsOf: source) else {
            DiagLog.log(.drive,
                        "đọc file bằng chứng \(mirrorName) trên máy THẤT BẠI")
            completion(ref, false)
            return
        }
        let mime = DriveAPI.mimeType(forFileName: sourceName)
        if let remote = filesByName[mirrorName] {
            DriveAPI.updateContent(token: ctx.token, fileID: remote.id,
                                   data: data, mimeType: mime) { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "tải lại \(mirrorName) THẤT BẠI — \(error.domain) code=\(error.code)")
                        completion(ref, false)
                    case .success:
                        ctx.uploadedFiles += 1
                        completion(ref, true)
                    }
                }
            }
        } else {
            DriveAPI.createFile(token: ctx.token, name: mirrorName,
                                parentID: folderID, data: data,
                                mimeType: mime) { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "tải lên \(mirrorName) THẤT BẠI — \(error.domain) code=\(error.code)")
                        completion(ref, false)
                    case .success:
                        ctx.uploadedFiles += 1
                        completion(ref, true)
                    }
                }
            }
        }
    }

    /// Dọn file bằng chứng THỪA trong thư mục tờ trên
    /// Drive (original-*/enhanced.* không còn trong danh
    /// sách của snapshot — ví dụ danh sách rút ngắn sau lần
    /// quét lại): đưa vào thùng rác Drive, khớp bước dọn
    /// của lớp gương trong mirrorOne để bố cục hai đường
    /// không trôi dần (kiểm duyệt vòng 1 ghế B, MINOR-2).
    /// Dọn là việc phụ trợ: hỏng thì GHI LOG, không làm
    /// lỗi cả tờ (phong bì receipt.json mới là nguồn sự
    /// thật khi khôi phục).
    private static func cleanupStaleEvidence(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        filesByName: [String: DriveFileResource]
    ) {
        var keepNames = Set<String>()
        for (index, sourceName)
        in snapshot.sourceOriginalFileNames.enumerated() {
            let ext = (sourceName as NSString).pathExtension
            keepNames.insert("original-\(index + 1)."
                + (ext.isEmpty ? "jpg" : ext))
        }
        if let enhancedName = snapshot.enhancedImageFileName,
           !enhancedName.isEmpty {
            let ext = (enhancedName as NSString).pathExtension
            keepNames.insert("enhanced." + (ext.isEmpty ? "jpg" : ext))
        }
        for file in filesByName.values
        where (file.name.hasPrefix("original-")
                || file.name.hasPrefix("enhanced."))
            && !keepNames.contains(file.name) {
            DriveAPI.trashFile(token: ctx.token,
                               fileID: file.id) { result in
                if case .failure(let error) = result {
                    DiagLog.log(.drive,
                                "dọn file bằng chứng thừa \(file.name) THẤT BẠI — \(error.domain) code=\(error.code)")
                }
            }
        }
    }

    /// receipt.json là DẤU CHỐT của tờ (§2.3: file của tờ
    /// lên xong mới tính là đã đồng bộ). Trước khi ghi đè
    /// một receipt.json từ xa mà nội dung của nó KHÔNG khớp
    /// hash manifest đang giữ (bị sửa ngoài app, hoặc file
    /// mồ côi không có trong manifest): tải bản đó về và giữ
    /// thành receipt-conflict-<giờ>.json trong cùng thư mục
    /// — bản thua không bao giờ mất lặng (AMD-002 §5).
    private static func uploadReceiptJSON(
        ctx: DrivePassContext, snapshot: MirrorReceiptSnapshot,
        hash: String, previous: MirrorManifestEntry?,
        folderID: String, filesByName: [String: DriveFileResource],
        originals: [MirrorOriginalRef], enhanced: MirrorOriginalRef?,
        completion: @escaping (Bool) -> Void
    ) {
        let envelope = MirrorReceiptFile(
            formatVersion: 1, mirroredAt: Date(),
            receipt: snapshot, originals: originals, enhanced: enhanced)
        guard let data = try? MirrorJSON.encoder().encode(envelope) else {
            completion(false)
            return
        }
        guard let remote = filesByName["receipt.json"] else {
            DriveAPI.createFile(token: ctx.token, name: "receipt.json",
                                parentID: folderID, data: data,
                                mimeType: "application/json") { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "tải lên receipt.json tờ \(snapshot.folderID) THẤT BẠI — \(error.domain) code=\(error.code)")
                        completion(false)
                    case .success:
                        ctx.uploadedFiles += 1
                        completion(true)
                    }
                }
            }
            return
        }
        DriveAPI.download(token: ctx.token, fileID: remote.id) { result in
            hop {
                var remoteHash: String? = nil
                var remoteData: Data? = nil
                switch result {
                case .failure(let error):
                    // Không đọc được bản từ xa thì KHÔNG
                    // ghi đè mù (bản đó có thể đã trôi khỏi
                    // manifest và là bản thua phải giữ):
                    // lỗi lẻ một tờ, lượt sau thử lại.
                    DiagLog.log(.drive,
                                "đọc receipt.json từ xa tờ \(snapshot.folderID) THẤT BẠI — \(error.domain) code=\(error.code)")
                    completion(false)
                    return
                case .success(let downloaded):
                    remoteData = downloaded
                    if let decoded = try? MirrorJSON.decoder().decode(
                        MirrorReceiptFile.self, from: downloaded) {
                        remoteHash = decoded.receipt.contentHash()
                    }
                }
                if remoteHash == hash, remoteData?.count == data.count {
                    // Nội dung đã ở trên Drive (lượt trước ghi
                    // file xong nhưng chưa kịp cập nhật
                    // manifest) — tự chữa, không tải lại.
                    // Đường tắt CHỈ khi CẢ hash snapshot VÀ
                    // kích thước phong bì khớp (kiểm duyệt
                    // vòng 1 đợt 3 ghế B, LOGIC-1 — đúng
                    // chuẩn mirrorOne của lớp gương): hash
                    // chỉ phủ snapshot, không phủ refs bằng
                    // chứng của phong bì; refs trôi (file
                    // mất/xuất hiện lại cùng tên, snapshot
                    // không đổi) làm kích thước phong bì
                    // lệch — lệch thì đi tiếp đường ghi đè
                    // ở dưới để phong bì tự chữa, không kẹt
                    // ở verify mỗi lượt vô hạn.
                    completion(true)
                    return
                }
                func overwrite() {
                    DriveAPI.updateContent(
                        token: ctx.token, fileID: remote.id, data: data,
                        mimeType: "application/json") { updated in
                        hop {
                            switch updated {
                            case .failure(let error):
                                DiagLog.log(.drive,
                                            "ghi đè receipt.json tờ \(snapshot.folderID) THẤT BẠI — \(error.domain) code=\(error.code)")
                                completion(false)
                            case .success:
                                ctx.uploadedFiles += 1
                                completion(true)
                            }
                        }
                    }
                }
                // Giữ bản xung đột khi nội dung từ xa KHÔNG
                // chứng minh được là khớp manifest: hash lệch
                // manifest, HOẶC không giải mã được (không
                // chứng minh được là file của chính app).
                // Khớp manifest (bản cũ hợp lệ) hoặc đã khớp
                // bản mới (xử lý ở trên) thì ghi đè thẳng.
                let shouldPreserve = remoteData != nil
                    && (remoteHash == nil
                        || remoteHash != previous?.contentHash)
                if shouldPreserve, let drifted = remoteData {
                    // Nội dung từ xa đã trôi khỏi manifest:
                    // giữ bản thua thành file xung đột trước
                    // khi ghi đè.
                    let stamp = conflictStamp()
                    DriveAPI.createFile(
                        token: ctx.token,
                        name: "receipt-conflict-\(stamp).json",
                        parentID: folderID, data: drifted,
                        mimeType: "application/json") { created in
                        hop {
                            if case .success = created {
                                ctx.conflictCopies += 1
                                ctx.uploadedFiles += 1
                                DiagLog.log(.drive,
                                            "tờ \(snapshot.folderID): nội dung trên Drive khác manifest — đã giữ bản xung đột receipt-conflict-\(stamp).json")
                            } else {
                                // Giữ bản xung đột hỏng thì
                                // KHÔNG ghi đè — thà lỗi lẻ
                                // một tờ còn hơn mất bản thua.
                                DiagLog.log(.drive,
                                            "giữ bản xung đột tờ \(snapshot.folderID) THẤT BẠI — bỏ qua tờ này ở lượt này")
                                completion(false)
                                return
                            }
                            overwrite()
                        }
                    }
                } else {
                    overwrite()
                }
            }
        }
    }

    private static func conflictStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: Xoá (chuyển _deleted — có dấu vết)

    private static func processDeletions(
        ctx: DrivePassContext, completion: @escaping () -> Void
    ) {
        if passStopped(ctx) {
            completion()
            return
        }
        // Chốt danh sách id TRƯỚC (không vừa duyệt vừa ghi —
        // cùng bài học lớp gương).
        let currentIDs = Set(ctx.snapshots.map { $0.folderID })
        let vanishedIDs = ctx.manifestByID.values
            .filter { $0.status == "active" && !currentIDs.contains($0.id) }
            .map { $0.id }
            .sorted()
        processDeletion(ctx: ctx, ids: vanishedIDs, index: 0,
                        completion: completion)
    }

    private static func processDeletion(
        ctx: DrivePassContext, ids: [String], index: Int,
        completion: @escaping () -> Void
    ) {
        // Kiểm passStopped ở đầu MỖI tờ như processReceipts
        // (kiểm duyệt vòng 1 mới ghế B, MINOR-1): đăng
        // xuất giữa vòng xoá thì dừng ngay — không chuyển
        // thêm tờ nào sang _deleted bằng token đã chụp.
        // Mỗi lần chuyển là một đơn vị công việc mới,
        // không phải "tờ đang làm dở".
        if index >= ids.count || passStopped(ctx) {
            completion()
            return
        }
        let id = ids[index]
        func markDeleted() {
            guard var entry = ctx.manifestByID[id] else {
                processDeletion(ctx: ctx, ids: ids, index: index + 1,
                                completion: completion)
                return
            }
            entry.status = "deleted"
            entry.deletedAt = Date()
            ctx.manifestByID[id] = entry
            processDeletion(ctx: ctx, ids: ids, index: index + 1,
                            completion: completion)
        }
        guard let folder = ctx.receiptsByName[id] else {
            // Thư mục không thấy trên Drive (chưa từng lên
            // hoặc đã ở _deleted từ trước): chỉ đánh dấu.
            markDeleted()
            return
        }
        DriveAPI.move(token: ctx.token, fileID: folder.id,
                      addParent: ctx.deletedID,
                      removeParent: ctx.receiptsID) { result in
            hop {
                switch result {
                case .failure(let error):
                    // Chuyển hỏng: entry GIỮ "active" để lượt
                    // sau thử lại (cùng kỷ luật L3 của gương).
                    DiagLog.log(.drive,
                                "chuyển _deleted tờ \(id) THẤT BẠI — \(error.domain) code=\(error.code)")
                    ctx.failedDeletes += 1
                    processDeletion(ctx: ctx, ids: ids, index: index + 1,
                                    completion: completion)
                case .success:
                    ctx.movedToDeleted += 1
                    ctx.receiptsByName[id] = nil
                    markDeleted()
                }
            }
        }
    }

    // MARK: Manifest chốt lượt + ghi kết quả

    /// Manifest chỉ ghi SAU KHI file của mọi tờ đã lên xong
    /// (§2.3). Ghi manifest hỏng = lỗi cấp lượt (recordFailure)
    /// như lớp gương: các receipt.json đã lên sẽ tự khớp lại
    /// ở lượt sau nhờ bước so hash nội dung.
    private static func uploadManifest(
        ctx: DrivePassContext, completion: @escaping () -> Void
    ) {
        if passStopped(ctx) {
            completion()
            return
        }
        ctx.manifest.entries = ctx.manifestByID.values
            .sorted { $0.id < $1.id }
        ctx.manifest.updatedAt = Date()
        guard let data = try? MirrorJSON.encoder()
            .encode(ctx.manifest) else {
            finish(ctx: ctx)
            completion()
            return
        }
        func manifestWritten() {
            finish(ctx: ctx)
            completion()
        }
        if let manifestFileID = ctx.manifestFileID {
            DriveAPI.updateContent(token: ctx.token, fileID: manifestFileID,
                                   data: data,
                                   mimeType: "application/json") { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "ghi manifest THẤT BẠI — \(error.domain) code=\(error.code)")
                        DriveSettings.recordFailure(
                            "Đồng bộ dở dang: chưa ghi được manifest lên Drive — app sẽ tự thử lại ở lượt sau.")
                    case .success:
                        manifestWritten()
                        return
                    }
                    completion()
                }
            }
        } else {
            DriveAPI.createFile(token: ctx.token, name: "manifest.json",
                                parentID: ctx.rootID, data: data,
                                mimeType: "application/json") { result in
                hop {
                    switch result {
                    case .failure(let error):
                        DiagLog.log(.drive,
                                    "tạo manifest THẤT BẠI — \(error.domain) code=\(error.code)")
                        DriveSettings.recordFailure(
                            "Đồng bộ dở dang: chưa ghi được manifest lên Drive — app sẽ tự thử lại ở lượt sau.")
                    case .success(let created):
                        ctx.manifestFileID = created.id
                        manifestWritten()
                        return
                    }
                    completion()
                }
            }
        }
    }

    private static func finish(ctx: DrivePassContext) {
        var parts = ["\(ctx.snapshots.count) hoá đơn"]
        if ctx.uploadedFiles > 0 {
            parts.append("tải lên \(ctx.uploadedFiles) file")
        }
        if ctx.movedToDeleted > 0 {
            parts.append("\(ctx.movedToDeleted) tờ vào _deleted")
        }
        if ctx.conflictCopies > 0 {
            parts.append("giữ \(ctx.conflictCopies) bản xung đột")
        }
        var error: String? = nil
        if ctx.failedReceipts > 0 {
            error = "\(ctx.failedReceipts) tờ đồng bộ lỗi ở lượt này — app sẽ tự đồng bộ lại ở lượt sau."
        } else if ctx.failedDeletes > 0 {
            error = "\(ctx.failedDeletes) tờ chưa chuyển được sang _deleted ở lượt này — app sẽ tự thử lại ở lượt sau."
        } else if ctx.missingOriginals > 0 {
            error = "Thiếu \(ctx.missingOriginals) ảnh gốc trên máy nên bản Drive chưa đủ bằng chứng — ảnh gốc của các tờ đó đã mất trong kho máy."
        }
        let summary = parts.joined(separator: " · ")
        DiagLog.log(.drive, "lượt đồng bộ kết thúc: \(summary)")
        if let error {
            DiagLog.log(.drive, "lượt đồng bộ có lỗi lẻ: \(error)")
        }
        DriveSettings.recordPass(summary: summary, error: error)
    }
}

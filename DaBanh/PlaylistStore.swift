import Foundation

/// Playlist loading, mirroring the Android app's behaviour:
/// - On launch: show the disk cache immediately (if present and > 100
///   bytes), then fetch the remote playlist.
/// - A successful fetch replaces the list AND rewrites the cache.
/// - A failed fetch keeps the current list; with nothing loaded yet it
///   surfaces a retry message instead.
/// - Auto-refresh: every 15 minutes — a foreground timer plus a
///   refresh-on-foreground when the data is older than 15 minutes
///   (the Android app does the staleness check in onResume).
/// - First load only: open on the highest-priority league that has a live
///   match right now; fall back to Ngoại Hạng Anh (Android setData).
@MainActor
final class PlaylistStore: ObservableObject {

    static let playlistURL = URL(string: "https://thtt.pages.dev/tttt.m3u")!
    /// Backup mirror (owner's own GitHub repo, auto-refreshed every 2
    /// hours by a scheduled workflow). Used automatically whenever the
    /// primary source fails or returns something that is not a usable
    /// playlist — insurance against the primary link dying.
    static let backupPlaylistURL = URL(string: "https://raw.githubusercontent.com/zjoenguyenz/dabanh-playlist/main/tttt.m3u")!
    private static let autoRefreshInterval: TimeInterval = 15 * 60

    @Published private(set) var channels: [Channel] = []
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?
    @Published var selectedLeague: Int = League.england.rawValue

    private(set) var lastFetch: Date?
    private var loadedOnce = false
    private var fetching = false
    private var autoRefreshTask: Task<Void, Never>?

    private var cacheFileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("playlist.m3u")
    }

    var isStale: Bool {
        guard let lastFetch else { return true }
        return Date().timeIntervalSince(lastFetch) > Self.autoRefreshInterval
    }

    func channels(in league: League) -> [Channel] {
        channels.filter { $0.leagueRank == league.rawValue }
    }

    // MARK: - Lifecycle

    /// Called once from the root view's .task: cache first, remote second,
    /// then the 15-minute auto-refresh loop for as long as the app lives.
    func start() async {
        loadCache()
        await refresh()
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.autoRefreshInterval))
                guard let self else { return }
                if self.isStale { await self.refresh() }
            }
        }
    }

    /// Android onResume rule: coming back to the app with a list older
    /// than 15 minutes triggers a refresh.
    func refreshIfStale() async {
        if loadedOnce && isStale { await refresh() }
    }

    // MARK: - Loading

    private func loadCache() {
        let url = cacheFileURL
        guard let data = try? Data(contentsOf: url), data.count > 100,
              let text = String(data: data, encoding: .utf8) else { return }
        let parsed = M3UParser.parse(text)
        if !parsed.isEmpty { setData(parsed) }
    }

    func refresh() async {
        if fetching { return } // one fetch at a time, like Android
        fetching = true
        isLoading = true
        defer {
            fetching = false
            isLoading = false
        }
        do {
            let (data, parsed) = try await fetchPlaylist(from: Self.playlistURL)
            try? data.write(to: cacheFileURL, options: .atomic)
            setData(parsed)
        } catch {
            // Primary source failed: fall back to the mirror before
            // giving up, and say so on screen when the mirror saves us.
            do {
                let (data, parsed) = try await fetchPlaylist(from: Self.backupPlaylistURL)
                try? data.write(to: cacheFileURL, options: .atomic)
                setData(parsed)
                statusMessage = "Nguồn chính lỗi — đang dùng nguồn dự phòng."
            } catch {
                if !loadedOnce {
                    statusMessage = "Không tải được danh sách kênh. Kiểm tra mạng rồi thử lại."
                } else {
                    statusMessage = "Chưa làm mới được — đang dùng danh sách cũ."
                }
            }
        }
    }

    /// One playlist fetch + validation: the text must decode and parse
    /// to at least one channel, otherwise the source counts as failed
    /// (an error page or an empty file must never replace a good list).
    private func fetchPlaylist(from url: URL) async throws -> (Data, [Channel]) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // Same user agent the Android app sends; some CDNs expect it.
        request.setValue("Mozilla/5.0 (Linux; Android 14; TV)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        let parsed = M3UParser.parse(text)
        if parsed.isEmpty { throw URLError(.zeroByteResource) }
        return (data, parsed)
    }

    private func setData(_ parsed: [Channel]) {
        channels = LeagueClassifier.sorted(parsed)
        lastFetch = Date()
        if !loadedOnce {
            // First open: land on the highest-priority league with a live
            // match right now; fall back to Ngoại Hạng Anh.
            let now = Date()
            var pick = League.england.rawValue
            for league in League.allCases {
                let hasLive = channels.contains {
                    $0.leagueRank == league.rawValue && LeagueClassifier.bucket(of: $0, now: now) == 0
                }
                if hasLive { pick = league.rawValue; break }
            }
            selectedLeague = pick
        }
        loadedOnce = true
        statusMessage = nil
    }
}

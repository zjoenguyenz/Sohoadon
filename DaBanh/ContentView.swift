import SwiftUI

/// Root screen: header (title, count, manual refresh) + the five league
/// tabs. Dark navy gradient and warm amber accent, in the spirit of the
/// Android app's glass UI.
struct ContentView: View {
    @EnvironmentObject private var store: PlaylistStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedChannel: Channel?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.07, blue: 0.13),
                         Color(red: 0.09, green: 0.14, blue: 0.24)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if let message = store.statusMessage, !store.channels.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
                TabView(selection: $store.selectedLeague) {
                    ForEach(League.allCases) { league in
                        LeagueListView(league: league, onSelect: { selectedChannel = $0 })
                            .tabItem { Text(league.name) }
                            .tag(league.rawValue)
                    }
                }
                .tint(.orange)
            }

            if store.channels.isEmpty {
                loadingOverlay
            }
        }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.refreshIfStale() }
            }
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(channel: channel)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRỰC TIẾP BÓNG ĐÁ")
                    .font(.caption2)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Đá Banh")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            if store.isLoading {
                ProgressView().tint(.white)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Label("Làm mới", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            Text("\(store.channels.count) kênh")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            if store.isLoading {
                ProgressView().tint(.white)
            }
            Text(store.statusMessage ?? "Đang tải danh sách kênh…")
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if !store.isLoading {
                Button("Thử lại") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
    }
}

/// One league tab: its channels in the global sorted order, live first,
/// with pull-to-refresh.
private struct LeagueListView: View {
    @EnvironmentObject private var store: PlaylistStore
    let league: League
    let onSelect: (Channel) -> Void

    var body: some View {
        let channels = store.channels(in: league)
        List {
            if channels.isEmpty {
                Text("Chưa có kênh nào trong mục này.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(channels) { channel in
                Button {
                    onSelect(channel)
                } label: {
                    ChannelRow(channel: channel)
                }
                .listRowBackground(Color.white.opacity(0.08))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await store.refresh() }
    }
}

private struct ChannelRow: View {
    let channel: Channel

    private static let kickoffFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        f.dateFormat = "HH:mm dd/MM"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.logoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Text("⚽").font(.title2)
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(channel.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(channel.group)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let kickoff = channel.kickoff {
                        Text(Self.kickoffFormatter.string(from: kickoff))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    if LeagueClassifier.isLive(channel) {
                        Text("ĐANG ĐÁ")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                    }
                }
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

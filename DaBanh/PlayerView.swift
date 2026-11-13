import AVKit
import SwiftUI
import UIKit

/// Full-screen player: AVPlayerViewController with autoplay, plus an
/// AVRoutePickerView (AirPlay) button in the top bar. AVPlayer's external
/// playback is enabled so a picked AirPlay video route takes the stream.
struct PlayerView: View {
    let channel: Channel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text(channel.title)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    RoutePickerView()
                        .frame(width: 44, height: 44)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Đóng")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if let url = channel.streamURL {
                    AVPlayerView(url: url)
                } else {
                    Spacer()
                    Text("Kênh không có địa chỉ phát hợp lệ.")
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
    }
}

/// SwiftUI wrapper around AVPlayerViewController. Plays immediately on
/// appear and pauses/releases the player when the view goes away.
struct AVPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        player.allowsExternalPlayback = true
        controller.player = player
        context.coordinator.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.player?.pause()
        uiViewController.player = nil
    }

    final class Coordinator {
        var player: AVPlayer?
    }
}

/// SwiftUI wrapper around AVRoutePickerView, preferring video routes so
/// the car's AirPlay video destination (when the car offers one) appears.
struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        view.activeTintColor = .systemOrange
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

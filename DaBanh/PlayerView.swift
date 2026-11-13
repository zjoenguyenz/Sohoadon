import AVFoundation
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
        .onAppear {
            OrientationHelper.lock(.landscape, rotateTo: .landscapeRight)
        }
        .onDisappear {
            OrientationHelper.lock(.all, rotateTo: .portrait)
        }
    }
}

/// SwiftUI wrapper around AVPlayerViewController. Plays immediately on
/// appear and pauses/releases the player when the view goes away.
struct AVPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Playback audio session: required for Picture in Picture and for
        // the stream to keep playing when the app leaves the foreground.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
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

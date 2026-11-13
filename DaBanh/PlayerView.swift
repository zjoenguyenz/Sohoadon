import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Player page: presents the system AVPlayerViewController MODALLY in
/// true full screen (edge-to-edge, native transport controls, native PiP
/// and AirPlay affordances) instead of embedding it under app chrome —
/// the v1.1 embedded layout left a title bar and black margins, which the
/// owner flagged as "not really full screen".
///
/// The page itself only hosts a black background plus the presenter; the
/// orientation lock narrows the app to landscape while the page is up.
struct PlayerView: View {
    let channel: Channel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = channel.streamURL {
                FullScreenPlayerPresenter(url: url, title: channel.title) {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Text("Kênh không có địa chỉ phát hợp lệ.")
                        .foregroundStyle(.white)
                    Button("Đóng") { dismiss() }
                        .buttonStyle(.bordered)
                        .tint(.green)
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

/// Hosts a plain view controller whose only job is to present the system
/// player full-screen as soon as it appears. When the user closes the
/// player (its own X / swipe), the host becomes visible again and the
/// coordinator reports the close so SwiftUI can dismiss the cover.
struct FullScreenPlayerPresenter: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, title: title, onClose: onClose)
    }

    func makeUIViewController(context: Context) -> HostViewController {
        let host = HostViewController()
        host.view.backgroundColor = .black
        context.coordinator.host = host
        host.onDidAppear = { context.coordinator.hostDidAppear() }
        return host
    }

    func updateUIViewController(_ uiViewController: HostViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: HostViewController, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class HostViewController: UIViewController {
        var onDidAppear: (() -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onDidAppear?()
        }
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private let url: URL
        private let title: String
        private let onClose: () -> Void
        weak var host: HostViewController?
        private var playerController: AVPlayerViewController?
        private var didPresent = false
        private var closed = false

        init(url: URL, title: String, onClose: @escaping () -> Void) {
            self.url = url
            self.title = title
            self.onClose = onClose
        }

        func hostDidAppear() {
            if !didPresent {
                presentPlayer()
            } else if !closed {
                // The presented player was dismissed by the user:
                // hand control back to SwiftUI exactly once.
                closed = true
                teardownPlayer()
                onClose()
            }
        }

        private func presentPlayer() {
            guard let host else { return }
            didPresent = true

            // Audio session for background / PiP playback.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)

            let item = AVPlayerItem(url: url)
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = AVMetadataIdentifier.commonIdentifierTitle
            titleItem.value = title as NSString
            titleItem.extendedLanguageTag = "und"
            item.externalMetadata = [titleItem]

            let player = AVPlayer(playerItem: item)
            player.allowsExternalPlayback = true

            let controller = AVPlayerViewController()
            controller.player = player
            controller.delegate = self
            controller.modalPresentationStyle = .fullScreen
            controller.allowsPictureInPicturePlayback = true
            controller.canStartPictureInPictureAutomaticallyFromInline = true
            playerController = controller

            host.present(controller, animated: true) {
                player.play()
            }
        }

        private func teardownPlayer() {
            playerController?.player?.pause()
            playerController?.player = nil
            playerController = nil
        }

        func teardown() {
            if let controller = playerController, controller.presentingViewController != nil {
                controller.dismiss(animated: false)
            }
            teardownPlayer()
        }

        // MARK: AVPlayerViewControllerDelegate

        /// Coming back from PiP: re-present the player if it is not on
        /// screen, then tell the system the restore succeeded.
        func playerViewController(_ playerViewController: AVPlayerViewController,
                                  restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            if playerViewController.presentingViewController == nil, let host {
                host.present(playerViewController, animated: true) {
                    completionHandler(true)
                }
            } else {
                completionHandler(true)
            }
        }
    }
}

/// SwiftUI wrapper around AVRoutePickerView, preferring video routes so
/// the car's AirPlay video destination (when the car offers one) appears.
/// Used by the channel-list header.
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

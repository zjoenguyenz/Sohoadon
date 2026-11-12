// CarProbe -- based on Cafari Lite by rPlay AI (MIT, see LICENSE).
// Original: https://github.com/rplayai/cafari-lite
//
// Trimmed down from Cafari Lite's browser for the probe: one WKWebView
// loading the desktop YouTube page (the same evidence page as the owner's
// recordings of CarDash), inline playback, and navigation logging. The
// settings sheet, the parked/moving gate (CarGate) and the send-to-car
// handoff are deliberately NOT carried over -- the probe answers one
// question only.
//
// Each surface (phone test page / car window) gets its OWN WKWebView: a web
// view lives in one window at a time.

import UIKit
import WebKit

final class BrowserViewController: UIViewController, WKNavigationDelegate {
  enum Surface { case car, phoneTest }

  /// The evidence page: desktop YouTube, exactly as in the recordings
  /// (youtube.com/?app=desktop -> /results -> /watch).
  static let testPage = URL(string: "https://www.youtube.com/?app=desktop")!

  private let surface: Surface
  private var webView: WKWebView!

  init(surface: Surface) {
    self.surface = surface
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  private var tag: String { surface == .car ? "car web" : "phone web" }

  override func viewDidLoad() {
    super.viewDidLoad()
    ProbeLog.write("\(tag) viewDidLoad")
    view.backgroundColor = .black

    let configuration = WKWebViewConfiguration()
    // Play in place rather than handing off to the full-screen system
    // player, which on the car screen would put the video where we cannot
    // see it. (From Cafari Lite.)
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true

    webView = WKWebView(frame: .zero, configuration: configuration)
    // Desktop-style request, so YouTube serves the desktop page the
    // recordings show, not the mobile site Cafari Lite points at.
    webView.customUserAgent =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
      + "(KHTML, like Gecko) Version/17.4 Safari/605.1.15"
    webView.navigationDelegate = self
    webView.allowsBackForwardNavigationGestures = (surface == .phoneTest)
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)

    if surface == .phoneTest {
      let bar = makeToolbar()
      bar.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(bar)
      NSLayoutConstraint.activate([
        bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.topAnchor.constraint(equalTo: bar.bottomAnchor),
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    } else {
      NSLayoutConstraint.activate([
        webView.topAnchor.constraint(equalTo: view.topAnchor),
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    }

    ProbeLog.write("\(tag) loading \(Self.testPage.absoluteString)")
    webView.load(URLRequest(url: Self.testPage))
  }

  private func makeToolbar() -> UIView {
    let container = UIStackView()
    container.axis = .horizontal
    container.alignment = .center
    container.spacing = 18
    container.isLayoutMarginsRelativeArrangement = true
    container.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    container.backgroundColor = .secondarySystemBackground

    func button(_ systemName: String, _ action: Selector) -> UIButton {
      let b = UIButton(type: .system)
      b.setImage(UIImage(systemName: systemName), for: .normal)
      b.addTarget(self, action: action, for: .touchUpInside)
      return b
    }

    container.addArrangedSubview(button("chevron.backward", #selector(goBack)))
    container.addArrangedSubview(button("chevron.forward", #selector(goForward)))
    container.addArrangedSubview(button("arrow.clockwise", #selector(reloadPage)))
    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    container.addArrangedSubview(spacer)
    let close = UIButton(type: .system)
    close.setTitle("Close", for: .normal)
    close.addTarget(self, action: #selector(closePage), for: .touchUpInside)
    container.addArrangedSubview(close)
    return container
  }

  @objc private func goBack() { webView.goBack() }
  @objc private func goForward() { webView.goForward() }
  @objc private func reloadPage() { webView.reload() }
  @objc private func closePage() { dismiss(animated: true) }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    ProbeLog.write("\(tag) viewDidAppear view=\(view.bounds.size) web=\(webView.bounds.size)")
  }

  // MARK: WKNavigationDelegate -- every step lands in probe.log

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    ProbeLog.write("\(tag) didCommit \(webView.url?.absoluteString ?? "-")")
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    ProbeLog.write("\(tag) didFinish \(webView.url?.absoluteString ?? "-")")
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
               withError error: Error) {
    ProbeLog.write("ERROR \(tag) didFail: \(error.localizedDescription)")
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
               withError error: Error) {
    ProbeLog.write("ERROR \(tag) didFailProvisional: \(error.localizedDescription)")
  }
}

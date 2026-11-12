// CarProbe -- new for the probe (dashboard UI); the scene/browser code it
// sits on is based on Cafari Lite by rPlay AI (MIT, see LICENSE).
//
// The phone screen is the evidence surface: app name, big build string,
// probe purpose, live car-scene status, and the full event log -- all
// screenshot-able after a car test.

import UIKit

final class ProbePhoneViewController: UIViewController {
  private let statusLabel = UILabel()
  private let logView = UITextView()
  private var carConnected = false
  private var carConnectedAt: Date?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(red: 0.07, green: 0.11, blue: 0.22, alpha: 1)

    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    let title = UILabel()
    title.text = "CarProbe"
    title.font = .systemFont(ofSize: 34, weight: .bold)
    title.textColor = .white

    // Large build/version string, read from Info.plist at runtime. The
    // cloud build stamps the workflow run number in as the build number,
    // so a screenshot identifies the exact build that was tested.
    let version = UILabel()
    version.text = "Version \(short) - Build \(build)"
    version.font = .systemFont(ofSize: 26, weight: .semibold)
    version.textColor = .systemYellow
    version.numberOfLines = 0

    let purpose = UILabel()
    purpose.text = "PROBE: does an IPA signed with the owner's signing app carry the "
      + "CarPlay video+audio entitlements, and does iOS create the CarPlay window "
      + "scene on the car? Connect CarPlay, watch the status + log below, then "
      + "screenshot this screen."
    purpose.font = .preferredFont(forTextStyle: .body)
    purpose.textColor = .white
    purpose.numberOfLines = 0

    statusLabel.font = .systemFont(ofSize: 20, weight: .bold)
    statusLabel.numberOfLines = 0

    let testButton = UIButton(type: .system)
    testButton.setTitle("Open test page (desktop YouTube)", for: .normal)
    testButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
    testButton.backgroundColor = .systemBlue
    testButton.setTitleColor(.white, for: .normal)
    testButton.layer.cornerRadius = 10
    testButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    testButton.addTarget(self, action: #selector(openTestPage), for: .touchUpInside)

    logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    logView.textColor = .white
    logView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    logView.isEditable = false
    logView.layer.cornerRadius = 8

    let stack = UIStackView(arrangedSubviews: [title, version, purpose, statusLabel, testButton, logView])
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
    ])
    // The log takes whatever vertical space is left over.
    logView.setContentHuggingPriority(.defaultLow, for: .vertical)

    NotificationCenter.default.addObserver(
      self, selector: #selector(logUpdated), name: ProbeLog.updated, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(carStateChanged), name: ProbeLog.carConnected, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(carStateChanged), name: ProbeLog.carDisconnected, object: nil)

    updateStatus()
    refreshLog()
  }

  @objc private func openTestPage() {
    ProbeLog.write("phone UI: open test page button tapped")
    let browser = BrowserViewController(surface: .phoneTest)
    browser.modalPresentationStyle = .fullScreen
    present(browser, animated: true)
  }

  @objc private func carStateChanged(_ note: Notification) {
    if note.name == ProbeLog.carConnected {
      carConnected = true
      carConnectedAt = Date()
    } else {
      carConnected = false
      carConnectedAt = nil
    }
    updateStatus()
  }

  private func updateStatus() {
    if carConnected {
      let when = carConnectedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? ""
      statusLabel.text = "CAR SCENE: CONNECTED \(when)"
      statusLabel.textColor = .systemGreen
    } else {
      statusLabel.text = "CAR SCENE: NOT CONNECTED"
      statusLabel.textColor = .systemOrange
    }
  }

  @objc private func logUpdated() { refreshLog() }

  private func refreshLog() {
    logView.text = ProbeLog.snapshot.joined(separator: "\n")
    // Keep the newest events visible.
    let len = (logView.text as NSString).length
    if len > 0 {
      logView.scrollRangeToVisible(NSRange(location: len - 1, length: 1))
    }
  }
}

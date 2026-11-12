// CarProbe -- based on Cafari Lite by rPlay AI (MIT, see LICENSE).
// Original: https://github.com/rplayai/cafari-lite (Diagnostics.swift)
//
// Adapted for the probe in two ways:
//  1. PERSISTENT, APPEND-ONLY: Cafari Lite truncates its log on the first
//     write of every launch. The probe never truncates: every event is
//     appended to Documents/probe.log across launches, so the evidence of a
//     car test survives the app being closed and reopened.
//  2. MIRRORED ON SCREEN: every line is also kept in memory and broadcast
//     via Notification, so the phone screen shows the same events live.
//     The owner screenshots the phone screen after the car test -- that
//     screenshot is the evidence channel.

import Foundation

enum ProbeLog {
  /// Posted (on the main queue) after every new line, so the phone UI can
  /// refresh its log view and car-connection status.
  static let updated = Notification.Name("CarProbeLogUpdated")
  /// Posted when the car window scene connects.
  static let carConnected = Notification.Name("CarProbeCarConnected")
  /// Posted when the car window scene disconnects.
  static let carDisconnected = Notification.Name("CarProbeCarDisconnected")

  private static let fileURL: URL? = {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    return dir?.appendingPathComponent("probe.log")
  }()

  private static let queue = DispatchQueue(label: "carprobe.log")
  private static var lines: [String] = []
  private static var loadedHistory = false

  private static let stamp: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return f
  }()

  /// All lines for this launch plus the tail of the on-disk history,
  /// oldest first. Read by the phone screen.
  static var snapshot: [String] {
    queue.sync { lines }
  }

  static func write(_ message: String) {
    let line = "\(stamp.string(from: Date()))  \(message)"
    NSLog("CarProbe: %@", message)
    queue.async {
      loadHistoryLocked()
      lines.append(line)
      appendToFileLocked(line)
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: updated, object: nil)
      }
    }
  }

  // MARK: - private (call only on `queue`)

  private static func loadHistoryLocked() {
    guard !loadedHistory else { return }
    loadedHistory = true
    guard let url = fileURL,
          let text = try? String(contentsOf: url, encoding: .utf8) else { return }
    // Keep the on-screen history bounded: last 200 lines from disk.
    let past = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    lines = Array(past.suffix(200))
    if !past.isEmpty {
      lines.append("----- (above: previous launches) -----")
    }
  }

  private static func appendToFileLocked(_ line: String) {
    guard let url = fileURL else { return }
    let data = Data((line + "\n").utf8)
    if let handle = try? FileHandle(forWritingTo: url) {
      handle.seekToEndOfFile()
      handle.write(data)
      try? handle.close()
    } else {
      try? data.write(to: url, options: .atomic)
    }
  }
}

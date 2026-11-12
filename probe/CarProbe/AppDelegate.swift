// CarProbe -- based on Cafari Lite by rPlay AI (MIT, see LICENSE).
// Original: https://github.com/rplayai/cafari-lite
//
// The probe's job: log every scene iOS offers this app, with its session
// role, so a car test can prove whether the CarPlay window scene is ever
// created for a build signed the owner's way.

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    let bundle = Bundle.main.bundleIdentifier ?? "?"
    ProbeLog.write("=== app launched: CarProbe v\(short) (build \(build)), bundle \(bundle) ===")
    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // Two scenes: the phone's own window, and the car's. The car one arrives
    // only when iOS accepts the build's CarPlay entitlements -- without them
    // iOS never offers this role and the app is phone-only.
    ProbeLog.write("configurationForConnecting role=\(session.role.rawValue) persistentID=\(session.persistentIdentifier)")
    if session.role == carProbeCarPlayRole {
      ProbeLog.write("configurationForConnecting -> choosing 'CarPlay' configuration (CAR SCENE OFFERED)")
      return UISceneConfiguration(name: "CarPlay", sessionRole: session.role)
    }
    return UISceneConfiguration(name: "Phone", sessionRole: session.role)
  }

  func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {
    for session in sceneSessions {
      ProbeLog.write("didDiscardSceneSessions role=\(session.role.rawValue) persistentID=\(session.persistentIdentifier)")
    }
  }
}

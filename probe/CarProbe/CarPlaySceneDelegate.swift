// CarProbe -- based on Cafari Lite by rPlay AI (MIT, see LICENSE).
// Original: https://github.com/rplayai/cafari-lite
//
// The car window. A UIWindowScene on the head unit -- the plain window role,
// not a CarPlay template scene -- so anything UIKit can draw, including a
// web view, appears on the car screen.
//
// THIS FILE FIRING AT ALL IS THE PROBE RESULT: iOS only creates this scene
// when the build's signing carries the CarPlay video entitlement.

import UIKit

final class CarPlaySceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    ProbeLog.write("*** CAR scene willConnect role=\(session.role.rawValue) ***")
    guard let windowScene = scene as? UIWindowScene else {
      ProbeLog.write("ERROR car scene is NOT a UIWindowScene: \(type(of: scene))")
      return
    }
    let screen = windowScene.screen
    ProbeLog.write("car windowScene size=\(windowScene.coordinateSpace.bounds.size) "
      + "screen=\(screen.bounds.size) native=\(screen.nativeBounds.size) scale=\(screen.scale)")
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = BrowserViewController(surface: .car)
    window.makeKeyAndVisible()
    self.window = window
    ProbeLog.write("*** CAR window up size=\(window.bounds.size) -- CAR SCENE CONNECTED ***")
    NotificationCenter.default.post(name: ProbeLog.carConnected, object: nil)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    ProbeLog.write("car scene didBecomeActive")
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    ProbeLog.write("*** CAR scene didDisconnect -- CAR SCENE GONE ***")
    window = nil
    NotificationCenter.default.post(name: ProbeLog.carDisconnected, object: nil)
  }
}

// UIKit does not surface this scene role in Swift -- there is no
// UISceneSession.Role.carPlay -- so it is compared as the raw string, which
// is the same one the Info.plist scene manifest uses. (From Cafari Lite.)
let carProbeCarPlayRole = UISceneSession.Role(rawValue: "UIWindowSceneSessionRoleCarPlay")

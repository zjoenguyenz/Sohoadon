// CarProbe -- based on Cafari Lite by rPlay AI (MIT, see LICENSE).
// Original: https://github.com/rplayai/cafari-lite
//
// The phone window: the probe dashboard (version, purpose, car status,
// on-screen log, test-page button).

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    ProbeLog.write("phone scene willConnect role=\(session.role.rawValue)")
    guard let windowScene = scene as? UIWindowScene else {
      ProbeLog.write("ERROR phone scene is NOT a UIWindowScene: \(type(of: scene))")
      return
    }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = ProbePhoneViewController()
    window.makeKeyAndVisible()
    self.window = window
    ProbeLog.write("phone window up size=\(window.bounds.size) key=\(window.isKeyWindow)")
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    ProbeLog.write("phone scene didBecomeActive")
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    ProbeLog.write("phone scene willEnterForeground")
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    ProbeLog.write("phone scene didEnterBackground")
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    ProbeLog.write("phone scene didDisconnect")
    window = nil
  }
}

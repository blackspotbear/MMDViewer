import UIKit

extension Notification.Name {
    static let mmdViewerWillEnterForeground = Notification.Name("applicationWillEnterForeground")
    static let mmdViewerDidEnterBackground = Notification.Name("applicationDidEnterBackground")
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func sceneWillEnterForeground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .mmdViewerWillEnterForeground, object: nil)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .mmdViewerDidEnterBackground, object: nil)
    }
}

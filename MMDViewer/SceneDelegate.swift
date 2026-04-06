import UIKit

extension Notification.Name {
    static let mmdViewerWillEnterForeground = Notification.Name("applicationWillEnterForeground")
    static let mmdViewerDidEnterBackground = Notification.Name("applicationDidEnterBackground")
}

/// Scene lifecycle を UIKit から `ViewController` / `MMDView` へ橋渡しする最小 delegate。
/// 複雑な状態管理は持たず、再生状態同期に必要な通知だけを発火する。
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private func notifyForegroundTransition() {
        postLifecycleNotification(.mmdViewerWillEnterForeground)
    }

    private func notifyBackgroundTransition() {
        postLifecycleNotification(.mmdViewerDidEnterBackground)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        notifyForegroundTransition()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        notifyBackgroundTransition()
    }

    private func postLifecycleNotification(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}

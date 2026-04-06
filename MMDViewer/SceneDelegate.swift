import UIKit

extension Notification.Name {
    static let mmdViewerWillEnterForeground = Notification.Name("applicationWillEnterForeground")
    static let mmdViewerDidEnterBackground = Notification.Name("applicationDidEnterBackground")
}

/// Scene lifecycle を UIKit から `ViewController` / `MMDView` へ橋渡しする最小 delegate。
/// 複雑な状態管理は持たず、再生状態同期に必要な通知だけを発火する。
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func sceneWillEnterForeground(_ scene: UIScene) {
        handleLifecycleTransition(.mmdViewerWillEnterForeground)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        handleLifecycleTransition(.mmdViewerDidEnterBackground)
    }

    /// Scene lifecycle の各イベントを、アプリ固有の notification へ写像する。
    /// event ごとの処理が増えるまでは 1 箇所に寄せておき、ViewController 側の購読先を固定する。
    private func handleLifecycleTransition(_ name: Notification.Name) {
        postLifecycleNotification(name)
    }

    private func postLifecycleNotification(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}

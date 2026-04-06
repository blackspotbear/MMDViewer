import UIKit

extension Notification.Name {
    static let mmdViewerWillEnterForeground = Notification.Name("applicationWillEnterForeground")
    static let mmdViewerDidEnterBackground = Notification.Name("applicationDidEnterBackground")
}

private enum MMDViewerLifecycleTransition {
    case willEnterForeground
    case didEnterBackground

    var notificationName: Notification.Name {
        switch self {
        case .willEnterForeground:
            return .mmdViewerWillEnterForeground
        case .didEnterBackground:
            return .mmdViewerDidEnterBackground
        }
    }
}

/// Scene lifecycle を UIKit から `ViewController` / `MMDView` へ橋渡しする最小 delegate。
/// 複雑な状態管理は持たず、再生状態同期に必要な通知だけを発火する。
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func sceneWillEnterForeground(_ scene: UIScene) {
        handleLifecycleTransition(.willEnterForeground)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        handleLifecycleTransition(.didEnterBackground)
    }

    /// Scene lifecycle の各イベントを、アプリ固有の notification へ写像する。
    /// event ごとの処理が増えるまでは 1 箇所に寄せておき、ViewController 側の購読先を固定する。
    private func handleLifecycleTransition(_ transition: MMDViewerLifecycleTransition) {
        postLifecycleNotification(transition.notificationName)
    }

    private func postLifecycleNotification(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}

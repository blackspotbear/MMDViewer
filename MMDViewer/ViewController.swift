import UIKit

private enum PlaybackState {
    case playing
    case paused

    var isPlaying: Bool {
        switch self {
        case .playing:
            return true
        case .paused:
            return false
        }
    }

    var buttonTitle: String {
        switch self {
        case .playing:
            return "Pause"
        case .paused:
            return "Play"
        }
    }
}

/// 再生/停止 UI と `MMDView` の最低限の橋渡しを担当する controller。
/// 描画や入力の本体は `MMDView` 側へ寄せ、ここではアプリ外周の状態同期だけを見る。
class ViewController: UIViewController {
    @IBOutlet weak var mmdView: MMDView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var playPauseButton: UIBarButtonItem!

    private var currentPlaybackState: PlaybackState {
        return (mmdView?.pmxUpdater?.playing ?? true) ? .playing : .paused
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configurePlaybackUI()
    }

    private func configurePlaybackUI() {
        playPauseButton.accessibilityIdentifier = "playPauseButton"
        registerLifecycleNotifications()
        updatePlayPauseButtonTitle()
    }

    private func registerLifecycleNotifications() {
        registerLifecycleNotification(.mmdViewerWillEnterForeground, selector: #selector(ViewController.viewWillEnterForeground(_:)))
        registerLifecycleNotification(.mmdViewerDidEnterBackground, selector: #selector(ViewController.viewDidEnterBackground(_:)))
    }

    private func registerLifecycleNotification(_ name: Notification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func viewWillEnterForeground(_ notification: Notification?) {
        applyPlaybackState(.playing)
    }

    @objc func viewDidEnterBackground(_ notification: Notification?) {
        applyPlaybackState(.paused)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onPlayButtonPushed(_ sender: AnyObject) {
        togglePlaybackState()
    }

    /// scene ライフサイクル通知と toolbar 操作の両方から再生状態を揃える。
    private func applyPlaybackState(_ state: PlaybackState) {
        mmdView.pmxUpdater?.playing = state.isPlaying
        updatePlayPauseButtonTitle()
    }

    private func togglePlaybackState() {
        if mmdView.pmxUpdater != nil {
            applyPlaybackState(currentPlaybackState == .playing ? .paused : .playing)
        }
    }

    private func updatePlayPauseButtonTitle() {
        playPauseButton?.title = currentPlaybackState.buttonTitle
    }
}

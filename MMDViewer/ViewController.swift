import UIKit

/// 再生/停止 UI と `MMDView` の最低限の橋渡しを担当する controller。
/// 描画や入力の本体は `MMDView` 側へ寄せ、ここではアプリ外周の状態同期だけを見る。
class ViewController: UIViewController {
    @IBOutlet weak var mmdView: MMDView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var playPauseButton: UIBarButtonItem!

    private var isCurrentlyPlaying: Bool {
        return mmdView?.pmxUpdater?.playing ?? true
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.viewWillEnterForeground(_:)),
            name: .mmdViewerWillEnterForeground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.viewDidEnterBackground(_:)),
            name: .mmdViewerDidEnterBackground,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func viewWillEnterForeground(_ notification: Notification?) {
        setPlaybackState(isPlaying: true)
    }

    @objc func viewDidEnterBackground(_ notification: Notification?) {
        setPlaybackState(isPlaying: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onPlayButtonPushed(_ sender: AnyObject) {
        togglePlaybackState()
    }

    /// scene ライフサイクル通知と toolbar 操作の両方から再生状態を揃える。
    private func setPlaybackState(isPlaying: Bool) {
        mmdView.pmxUpdater?.playing = isPlaying
        updatePlayPauseButtonTitle()
    }

    private func togglePlaybackState() {
        if mmdView.pmxUpdater != nil {
            setPlaybackState(isPlaying: !isCurrentlyPlaying)
        }
    }

    private func updatePlayPauseButtonTitle() {
        playPauseButton?.title = isCurrentlyPlaying ? "Pause" : "Play"
    }
}

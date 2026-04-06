import UIKit

/// 再生/停止 UI と `MMDView` の最低限の橋渡しを担当する controller。
/// 描画や入力の本体は `MMDView` 側へ寄せ、ここではアプリ外周の状態同期だけを見る。
class ViewController: UIViewController {
    @IBOutlet weak var mmdView: MMDView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var playPauseButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        playPauseButton.accessibilityIdentifier = "playPauseButton"
        updatePlayPauseButtonTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerLifecycleNotifications()
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
        if let pmxUpdater = mmdView.pmxUpdater {
            setPlaybackState(isPlaying: !pmxUpdater.playing)
        }
    }

    /// scene ライフサイクル通知と toolbar 操作の両方から再生状態を揃える。
    private func setPlaybackState(isPlaying: Bool) {
        mmdView.pmxUpdater?.playing = isPlaying
        updatePlayPauseButtonTitle()
    }

    private func updatePlayPauseButtonTitle() {
        playPauseButton?.title = (mmdView?.pmxUpdater?.playing ?? true) ? "Pause" : "Play"
    }
}

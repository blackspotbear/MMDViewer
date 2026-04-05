import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var mmdView: MMDView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var playPauseButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        updatePlayPauseButtonTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.viewWillEnterForeground(_:)),
            name: NSNotification.Name(rawValue: "applicationWillEnterForeground"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.viewDidEnterBackground(_:)),
            name: NSNotification.Name(rawValue: "applicationDidEnterBackground"),
            object: nil
        )
    }

    @objc func viewWillEnterForeground(_ notification: Notification?) {
        mmdView.pmxUpdater?.playing = true
        updatePlayPauseButtonTitle()
    }

    @objc func viewDidEnterBackground(_ notification: Notification?) {
        mmdView.pmxUpdater?.playing = false
        updatePlayPauseButtonTitle()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onPlayButtonPushed(_ sender: AnyObject) {
        if let pmxUpdater = mmdView.pmxUpdater {
            pmxUpdater.playing = !pmxUpdater.playing
            updatePlayPauseButtonTitle()
        }
    }

    private func updatePlayPauseButtonTitle() {
        playPauseButton?.title = (mmdView?.pmxUpdater?.playing ?? true) ? "Pause" : "Play"
    }
}

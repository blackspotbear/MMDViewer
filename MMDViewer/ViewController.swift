import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var mmdView: MMDView!
    @IBOutlet weak var toolBar: UIToolbar!

    override func viewDidLoad() {
        super.viewDidLoad()
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

    func viewWillEnterForeground(_ notification: Notification?) {
        mmdView.pmxUpdater?.playing = true
    }

    func viewDidEnterBackground(_ notification: Notification?) {
        mmdView.pmxUpdater?.playing = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onPlayButtonPushed(_ sender: AnyObject) {
        if let pmxUpdater = mmdView.pmxUpdater {
            pmxUpdater.playing = !pmxUpdater.playing
            if let index = toolBar.items?.index(of: sender as! UIBarButtonItem) {
                let btnSystemItem = mmdView.pmxUpdater!.playing ? UIBarButtonSystemItem.pause : UIBarButtonSystemItem.play
                let btnItem = UIBarButtonItem(barButtonSystemItem: btnSystemItem, target: self, action: #selector(ViewController.onPlayButtonPushed(_:)))
                toolBar.items?.insert(btnItem, at: index)
                toolBar.items?.remove(at: index + 1)
            }
        }
    }
}

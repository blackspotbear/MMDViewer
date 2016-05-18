import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var mmdView: MMDView!
    @IBOutlet weak var toolBar: UIToolbar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bt = BulletTest()
        bt.doIt(10, withYou: 20)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onPlayButtonPushed(sender: AnyObject) {
        mmdView.playing = !mmdView.playing
        
        if let index = toolBar.items?.indexOf(sender as! UIBarButtonItem) {
            let btnSystemItem = mmdView.playing ? UIBarButtonSystemItem.Pause : UIBarButtonSystemItem.Play
            let btnItem = UIBarButtonItem(barButtonSystemItem: btnSystemItem, target: self, action: #selector(ViewController.onPlayButtonPushed(_:)))
            toolBar.items?.insert(btnItem, atIndex: index)
            toolBar.items?.removeAtIndex(index + 1)
        }
    }
}

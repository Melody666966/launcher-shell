import UIKit
import WebKit

final class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let wv = WKWebView(frame: view.bounds)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.scrollView.contentInsetAdjustmentBehavior = .never

        let url = Bundle.main.url(forResource: "launcher", withExtension: "html")!
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        view.addSubview(wv)
    }
    override var prefersStatusBarHidden: Bool { true }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = ViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

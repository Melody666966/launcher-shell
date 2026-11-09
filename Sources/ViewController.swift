import UIKit
import WebKit
import UniformTypeIdentifiers

final class ViewController: UIViewController, UIDocumentPickerDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.09, green: 0.16, blue: 0.30, alpha: 1)

        let htmlDst = docs.appendingPathComponent("launcher.html")
        if !FileManager.default.fileExists(atPath: htmlDst.path),
           let src = Bundle.main.url(forResource: "launcher", withExtension: "html") {
            try? FileManager.default.copyItem(at: src, to: htmlDst)
        }

        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = self
        view.addSubview(webView)
        reloadPage()

        let btn = UIButton(type: .system)
        btn.setTitle("选择游戏文件夹", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 14)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.frame = CGRect(x: view.bounds.width - 160, y: 48, width: 148, height: 36)
        btn.autoresizingMask = [.flexibleLeftMargin]
        btn.addTarget(self, action: #selector(pickFolder), for: .touchUpInside)
        view.addSubview(btn)
    }

    private func reloadPage() {
        webView.loadFileURL(docs.appendingPathComponent("launcher.html"), allowingReadAccessTo: docs)
    }

    private func hasGameFolder() -> Bool {
        let game = docs.appendingPathComponent("playgta5-offline")
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: game.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func applyState() {
        guard hasGameFolder() else { return }
        let js = """
        (function(){
          var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT),n;
          while(n=w.nextNode()){
            if(n.nodeValue.indexOf('尚未导入')>=0) n.nodeValue=n.nodeValue.replace(/尚未导入/g,'已导入');
            if(n.nodeValue.indexOf('无法启动')>=0) n.nodeValue=n.nodeValue.replace(/无法启动/g,'可以启动');
          }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyState()
    }

    @objc private func pickFolder() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let src = urls.first else { return }
        let got = src.startAccessingSecurityScopedResource()
        defer { if got { src.stopAccessingSecurityScopedResource() } }
        let dst = docs.appendingPathComponent(src.lastPathComponent)
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
        do {
            try fm.copyItem(at: src, to: dst)
            reloadPage()
            let ok = UIAlertController(title: "已导入",
                message: "\(src.lastPathComponent) 已放进启动器", preferredStyle: .alert)
            ok.addAction(UIAlertAction(title: "好", style: .default))
            present(ok, animated: true)
        } catch {
            let err = UIAlertController(title: "导入失败",
                message: error.localizedDescription, preferredStyle: .alert)
            err.addAction(UIAlertAction(title: "好", style: .default))
            present(err, animated: true)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
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

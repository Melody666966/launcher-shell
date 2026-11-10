import UIKit
import WebKit
import UniformTypeIdentifiers

final class GameScheme: NSObject, WKURLSchemeHandler {
    private let root: URL
    init(root: URL) { self.root = root }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { task.didFinish(); return }
        var p = url.path.removingPercentEncoding ?? "/"
        if p.isEmpty || p == "/" { p = "/launcher.html" }
        p = p.replacingOccurrences(of: "..", with: "")
        let file = root.appendingPathComponent(String(p.dropFirst()))
        guard var data = try? Data(contentsOf: file) else {
            let r = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: 0, textEncodingName: nil)
            task.didReceive(r); task.didFinish(); return
        }
        if p == "/launcher.html", let t = String(data: data, encoding: .utf8) {
            data = t.replacingOccurrences(of: "'self'", with: "*").data(using: .utf8) ?? data
        }
        let r = URLResponse(url: url, mimeType: mime(file.pathExtension),
                            expectedContentLength: data.count, textEncodingName: nil)
        task.didReceive(r); task.didReceive(data); task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func mime(_ e: String) -> String {
        switch e.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "wasm": return "application/wasm"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "txt": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}

final class ViewController: UIViewController, UIDocumentPickerDelegate, WKNavigationDelegate {
    private var webView: WKWebView!
    private var pickButton: UIButton!
    private var handler: GameScheme?
    private let gameFolderName = "playgta5-offline"
    private var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.09, green: 0.16, blue: 0.30, alpha: 1)

        let dst = docs.appendingPathComponent("launcher.html")
        if !FileManager.default.fileExists(atPath: dst.path),
           let src = Bundle.main.url(forResource: "launcher", withExtension: "html") {
            try? FileManager.default.copyItem(at: src, to: dst)
        }

        let h = GameScheme(root: docs)
        handler = h
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.setURLSchemeHandler(h, forURLScheme: "game")

        webView = WKWebView(frame: view.bounds, configuration: cfg)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = self
        view.addSubview(webView)

        let btn = UIButton(type: .system)
        btn.setTitle("选择游戏文件夹", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 14)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.frame = CGRect(x: view.bounds.width - 160, y: 48, width: 148, height: 36)
        btn.autoresizingMask = [.flexibleLeftMargin]
        btn.addTarget(self, action: #selector(pickFolder), for: .touchUpInside)
        btn.isHidden = true
        view.addSubview(btn)
        pickButton = btn

        webView.load(URLRequest(url: URL(string: "game://local/launcher.html")!))
    }

    private func gameFiles() -> [[String: Any]] {
        let folder = docs.appendingPathComponent(gameFolderName)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir),
              isDir.boolValue else { return [] }
        guard let e = FileManager.default.enumerator(at: folder,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]) else { return [] }
        var out: [[String: Any]] = []
        for case let u as URL in e {
            let rv = try? u.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard rv?.isRegularFile == true else { continue }
            let rel = gameFolderName + "/" + u.path.replacingOccurrences(of: folder.path + "/", with: "")
            out.append(["p": rel, "n": rv?.fileSize ?? 0])
        }
        return out
    }

    private func autoImport() {
        let list = gameFiles()
        guard !list.isEmpty else { pickButton.isHidden = false; return }
        pickButton.isHidden = true
        guard let j = try? JSONSerialization.data(withJSONObject: list),
              let s = String(data: j, encoding: .utf8) else { return }
        let js = """
        (function(){
          try{
            var list=\(s);
            resetEntries();
            list.forEach(function(x){
              addEntry(x.p, x.n, function(){
                var u='game://local/'+x.p.split('/').map(encodeURIComponent).join('/');
                return fetch(u).then(function(r){return r.blob()});
              });
            });
            render();
          }catch(e){console.log('autoImport: '+e)}
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { autoImport() }

    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError error: Error) {
        let a = UIAlertController(title: "页面加载失败", message: error.localizedDescription, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default))
        present(a, animated: true)
    }

    @objc private func pickFolder() {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        p.delegate = self
        p.allowsMultipleSelection = false
        present(p, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let src = urls.first else { return }
        let got = src.startAccessingSecurityScopedResource()
        defer { if got { src.stopAccessingSecurityScopedResource() } }
        let dst = docs.appendingPathComponent(gameFolderName)
        let fm = FileManager.default
        let inside = src.standardizedFileURL.path.hasPrefix(docs.standardizedFileURL.path + "/")
        do {
            if !inside {
                if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
                try fm.copyItem(at: src, to: dst)
            }
            webView.reload()
        } catch {
            let a = UIAlertController(title: "导入失败", message: error.localizedDescription, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default))
            present(a, animated: true)
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

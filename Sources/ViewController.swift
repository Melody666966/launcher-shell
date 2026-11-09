import UIKit
import WebKit
import UniformTypeIdentifiers

final class ViewController: UIViewController, UIDocumentPickerDelegate {
    private var webView: WKWebView!
    private var pickButton: UIButton!
    private var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private let gameFolderName = "playgta5-offline"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.09, green: 0.16, blue: 0.30, alpha: 1)

        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInsetAdjustmentBehavior = .never
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
        view.addSubview(btn)
        pickButton = btn

        openGameIfPresent()
    }

    private func gameEntry() -> URL? {
        let folder = docs.appendingPathComponent(gameFolderName)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir),
              isDir.boolValue else { return nil }
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? []
        if let index = items.first(where: { $0.lastPathComponent.lowercased() == "index.html" }) {
            return index
        }
        return items.first(where: {
            let e = $0.pathExtension.lowercased()
            return e == "html" || e == "htm"
        })
    }

    private func openGameIfPresent() {
        if let entry = gameEntry() {
            pickButton.isHidden = true
            webView.loadFileURL(entry, allowingReadAccessTo: docs)
        } else {
            pickButton.isHidden = false
            let dst = docs.appendingPathComponent("launcher.html")
            if !FileManager.default.fileExists(atPath: dst.path),
               let src = Bundle.main.url(forResource: "launcher", withExtension: "html") {
                try? FileManager.default.copyItem(at: src, to: dst)
            }
            webView.loadFileURL(dst, allowingReadAccessTo: docs)
        }
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

        let fm = FileManager.default
        let dst = docs.appendingPathComponent(gameFolderName)
        let alreadyInside = src.standardizedFileURL.path.hasPrefix(docs.standardizedFileURL.path + "/")
        do {
            if !alreadyInside {
                if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
                try fm.copyItem(at: src, to: dst)
            }
            openGameIfPresent()
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

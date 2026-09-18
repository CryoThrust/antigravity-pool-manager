import Cocoa
import WebKit

class DraggableWebView: WKWebView {
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // 顶部 54px 区域：除右侧按钮区域（宽约 260px）和左侧交通灯（75px）以外，全部响应窗口拖拽
        if frame.height - point.y <= 54 && point.x < (frame.width - 240) {
            window?.performDrag(with: event)
            return
        }
        super.mouseDown(with: event)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: DraggableWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureServerRunning()

        // 窗口配置
        let windowRect = NSRect(x: 0, y: 0, width: 1180, height: 840)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = NSSize(width: 980, height: 640)
        window.title = "Antigravity 账号池与配额控制台"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)

        // WebKit 配置
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "dragWindow")
        contentController.add(self, name: "openExternal")
        config.userContentController = contentController
        
        webView = DraggableWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.setValue(false, forKey: "drawsBackground")

        window.contentView?.addSubview(webView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupMenu()
        loadConsole()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "dragWindow" {
            if let currentEvent = NSApp.currentEvent {
                window.performDrag(with: currentEvent)
            }
        } else if message.name == "openExternal" {
            if let urlStr = message.body as? String, let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func findNodeExecutable() -> String {
        let home = NSHomeDirectory()
        let candidatePaths = [
            "\(home)/.nvm/versions/node/v22.23.2/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "\(home)/.nvm/versions/node/v20.18.0/bin/node",
            "\(home)/.nvm/versions/node/v18.20.4/bin/node",
            "\(home)/.volta/bin/node",
            "\(home)/.fnm/current/bin/node"
        ]
        for p in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }
        let nvmDir = "\(home)/.nvm/versions/node"
        if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for sub in subdirs.sorted().reversed() {
                let p = "\(nvmDir)/\(sub)/bin/node"
                if FileManager.default.isExecutableFile(atPath: p) {
                    return p
                }
            }
        }
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", "which node"]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "node"
    }

    func ensureServerRunning() {
        guard let url = URL(string: "http://localhost:3999/api/status") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5
        
        let semaphore = DispatchSemaphore(value: 0)
        var isUp = false
        
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                isUp = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 0.6)
        
        if !isUp {
            let scriptPath = "/Users/yohanes/antigravity-switcher/server.mjs"
            let nodePath = findNodeExecutable()
            let process = Process()
            if nodePath.hasPrefix("/") {
                process.executableURL = URL(fileURLWithPath: nodePath)
                process.arguments = [scriptPath]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["node", scriptPath]
            }
            process.currentDirectoryURL = URL(fileURLWithPath: "/Users/yohanes/antigravity-switcher")
            
            var env = ProcessInfo.processInfo.environment
            let home = NSHomeDirectory()
            let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            env["PATH"] = "\(home)/.nvm/versions/node/v22.23.2/bin:/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
            process.environment = env
            process.standardOutput = nil
            process.standardError = nil
            try? process.run()
            Thread.sleep(forTimeInterval: 1.2)
        }
    }

    func loadConsole() {
        if let url = URL(string: "http://localhost:3999") {
            webView.load(URLRequest(url: url))
        }
    }

    func setupMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Antigravity Manager", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 Antigravity Manager", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 Antigravity Manager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "视图")
        let reloadItem = NSMenuItem(title: "刷新", action: #selector(reloadPage), keyEquivalent: "r")
        reloadItem.target = self
        viewMenu.addItem(reloadItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        NSApp.mainMenu = mainMenu
    }

    @objc func reloadPage() {
        webView.reload()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "http" || url.scheme == "https" {
                if url.host != "localhost" && url.host != "127.0.0.1" {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // 服务启动中如果短暂连接失败，延迟 0.6 秒自动重试，彻底解决黑屏问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.loadConsole()
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let targetURL = navigationAction.request.url {
            NSWorkspace.shared.open(targetURL)
        }
        return nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

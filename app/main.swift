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

import QuartzCore

// ─── 全自动授权与会话凭据/API Key 提取控制器 ─────────────────────────────────
class WebAuthWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    var titleLabel: NSTextField!
    var statusLabel: NSTextField!
    var stepBadge: NSTextField!
    var spinner: NSProgressIndicator!

    var targetEmail: String?
    var isNewAccount: Bool = false
    var capturedWebCookie: Bool = false
    var capturedApiKey: Bool = false
    var pollTimer: Timer?
    var onCompletion: (() -> Void)?

    func start(email: String?, isNew: Bool, completion: @escaping () -> Void) {
        self.targetEmail = email
        self.isNewAccount = isNew
        self.capturedWebCookie = false
        self.capturedApiKey = false
        self.onCompletion = completion

        let rect = NSRect(x: 0, y: 0, width: 960, height: 740)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Google 账号全自动三合一授权助手"
        window.backgroundColor = NSColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)
        window.delegate = self

        let container = NSView(frame: rect)
        container.autoresizingMask = [.width, .height]
        window.contentView = container

        // 顶部状态栏 (高 64px)
        let headerView = NSView(frame: NSRect(x: 0, y: rect.height - 64, width: rect.width, height: 64))
        headerView.autoresizingMask = [.width, .minYMargin]
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(red: 0.09, green: 0.11, blue: 0.14, alpha: 1.0).cgColor

        let borderLine = CALayer()
        borderLine.frame = CGRect(x: 0, y: 0, width: rect.width, height: 1)
        borderLine.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        borderLine.autoresizingMask = [.layerWidthSizable]
        headerView.layer?.addSublayer(borderLine)

        stepBadge = NSTextField(labelWithString: isNew ? "STEP 1/3: 账号登录" : "STEP 1/2: 捕获反代")
        stepBadge.frame = NSRect(x: 18, y: 34, width: 140, height: 18)
        stepBadge.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        stepBadge.textColor = NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
        stepBadge.isBezeled = false
        stepBadge.drawsBackground = false
        stepBadge.isEditable = false
        headerView.addSubview(stepBadge)

        titleLabel = NSTextField(labelWithString: isNew ? "Google 账号全自动接入（GCP + Gemini 反代 + 1500 API）" : "正在为 \(email ?? "账号") 自动同步 Gemini 网页反代与 1500 API")
        titleLabel.frame = NSRect(x: 18, y: 12, width: rect.width - 90, height: 20)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.95, alpha: 1.0)
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        headerView.addSubview(titleLabel)

        statusLabel = NSTextField(labelWithString: isNew ? "请在下方登录 Google 账号并授权，系统将在后台自动完成反代及 API 绑定" : "正在加载 Gemini 页面并无感截获会话凭据...")
        statusLabel.frame = NSRect(x: 160, y: 34, width: rect.width - 240, height: 18)
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        statusLabel.isBezeled = false
        statusLabel.drawsBackground = false
        statusLabel.isEditable = false
        headerView.addSubview(statusLabel)

        spinner = NSProgressIndicator(frame: NSRect(x: rect.width - 46, y: 20, width: 24, height: 24))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.autoresizingMask = [.minXMargin]
        spinner.startAnimation(nil)
        headerView.addSubview(spinner)

        container.addSubview(headerView)

        // WebKit 配置与注入
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "onOAuthSuccess")
        contentController.add(self, name: "onApiKeyCaptured")

        let scriptSource = """
        (function() {
            function scanKey() {
                if (!location.hostname.includes('aistudio.google.com')) return;
                const text = document.body ? document.body.innerText : '';
                const m = text.match(/AIza[0-9A-Za-z-_]{35}/);
                if (m && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onApiKeyCaptured) {
                    window.webkit.messageHandlers.onApiKeyCaptured.postMessage(m[0]);
                    return true;
                }
                const btns = Array.from(document.querySelectorAll('button, a'));
                for (const b of btns) {
                    const t = (b.innerText || '').trim();
                    if (t.includes('Create API key') || t.includes('创建 API 密钥') || t.includes('Get API key') || t.includes('Create key in new project')) {
                        if (!window.__auto_clicked_create) {
                            window.__auto_clicked_create = true;
                            b.click();
                            break;
                        }
                    }
                }
                const tosBtn = Array.from(document.querySelectorAll('button, input[type=checkbox]')).find(el => {
                    const t = (el.innerText || el.value || '').toLowerCase();
                    return t.includes('agree') || t.includes('accept') || t.includes('get started') || t.includes('continue');
                });
                if (tosBtn && !window.__auto_tos) {
                    window.__auto_tos = true;
                    tosBtn.click();
                }
                return false;
            }
            setInterval(scanKey, 1200);
            scanKey();
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        config.userContentController = contentController

        let webRect = NSRect(x: 0, y: 0, width: rect.width, height: rect.height - 64)
        webView = WKWebView(frame: webRect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        container.addSubview(webView)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if isNew {
            fetchAndLoadOAuthUrl()
        } else {
            loadGeminiWebApp()
        }

        startCookiePolling()
    }

    func fetchAndLoadOAuthUrl() {
        guard let url = URL(string: "http://localhost:3999/api/auth-url") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["noOpen": true])
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let authUrlStr = json["authUrl"] as? String,
                  let authUrl = URL(string: authUrlStr) else { return }
            DispatchQueue.main.async {
                self.webView.load(URLRequest(url: authUrl))
            }
        }.resume()
    }

    func loadGeminiWebApp() {
        if let url = URL(string: "https://gemini.google.com/app") {
            self.webView.load(URLRequest(url: url))
        }
    }

    func startCookiePolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkCookies()
        }
    }

    func checkCookies() {
        guard !capturedWebCookie else { return }
        guard let currentUrl = webView.url?.absoluteString, currentUrl.contains("gemini.google.com") else { return }

        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self, !self.capturedWebCookie else { return }
            let googleCookies = cookies.filter { $0.domain.contains("google.com") }
            var hasPSID = false
            var cookieParts: [String] = []
            for c in googleCookies {
                if c.name == "__Secure-1PSID" && !c.value.isEmpty {
                    hasPSID = true
                }
                cookieParts.append("\(c.name)=\(c.value)")
            }

            if hasPSID {
                self.capturedWebCookie = true
                let fullCookieStr = cookieParts.joined(separator: "; ")
                let emailToBind = self.targetEmail ?? "active"

                DispatchQueue.main.async {
                    self.stepBadge.stringValue = self.isNewAccount ? "STEP 2/3: 反代就绪" : "STEP 1/2: 反代就绪"
                    self.stepBadge.textColor = NSColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1.0)
                    self.statusLabel.stringValue = "✅ Gemini 网页反代凭据捕获成功！正在自动同步至本地网关..."
                }

                self.postJSON(to: "http://localhost:3999/api/account/bind-web-auth", json: [
                    "email": emailToBind,
                    "cookie": fullCookieStr,
                    "isPro": true
                ]) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.statusLabel.stringValue = "✅ 网页反代已激活！正在前往 Google AI Studio 自动获取 1500 API Key..."
                        self.stepBadge.stringValue = self.isNewAccount ? "STEP 3/3: 提取 API" : "STEP 2/2: 提取 API"
                        if let studioUrl = URL(string: "https://aistudio.google.com/app/apikey") {
                            self.webView.load(URLRequest(url: studioUrl))
                        }
                    }
                }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "onOAuthSuccess" {
            if let body = message.body as? [String: Any], let email = body["email"] as? String {
                self.targetEmail = email
                DispatchQueue.main.async {
                    self.stepBadge.stringValue = "STEP 2/3: 捕获反代"
                    self.statusLabel.stringValue = "✅ Google 授权完成 (\(email))，正在前往 Gemini 自动捕获会话凭据..."
                    self.loadGeminiWebApp()
                }
            }
        } else if message.name == "onApiKeyCaptured" {
            guard !capturedApiKey, let key = message.body as? String, !key.isEmpty else { return }
            capturedApiKey = true
            pollTimer?.invalidate()
            pollTimer = nil

            let emailToBind = self.targetEmail ?? "active"
            DispatchQueue.main.async {
                self.stepBadge.stringValue = "全部就绪 ✓"
                self.stepBadge.textColor = NSColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1.0)
                let shortKey = key.count > 12 ? "\(key.prefix(8))..." : key
                self.statusLabel.stringValue = "🎉 1500 次/天 API Key [\(shortKey)] 捕获成功！正在激活..."
                self.spinner.stopAnimation(nil)
            }

            self.postJSON(to: "http://localhost:3999/api/account/bind-ai-key", json: [
                "email": emailToBind,
                "apiKey": key
            ]) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.statusLabel.stringValue = "🎉 官方 1500 API 与 Web 反代已全部全自动配置完成！正在返回控制台..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.window.close()
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkCookies()
    }

    func postJSON(to urlString: String, json: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: urlString) else { completion(false); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        URLSession.shared.dataTask(with: request) { _, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            completion(ok)
        }.resume()
    }

    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate()
        pollTimer = nil
        onCompletion?()
        onCompletion = nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: DraggableWebView!
    var webAuthWindowController: WebAuthWindowController?

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
        contentController.add(self, name: "startAutoAuth")
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
        } else if message.name == "startAutoAuth" {
            var targetEmail: String? = nil
            var mode = "sync"
            if let dict = message.body as? [String: Any] {
                targetEmail = dict["email"] as? String
                mode = dict["mode"] as? String ?? "sync"
            }
            let isNew = mode == "new"
            self.webAuthWindowController = WebAuthWindowController()
            self.webAuthWindowController?.start(email: targetEmail, isNew: isNew) { [weak self] in
                self?.webView.evaluateJavaScript("if (window.loadAccounts) loadAccounts(); if (window.loadStatus) loadStatus();", completionHandler: nil)
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
            var scriptPath = "/Users/yohanes/antigravity-switcher/server.mjs"
            if let bundleScript = Bundle.main.url(forResource: "server", withExtension: "mjs")?.path, FileManager.default.fileExists(atPath: bundleScript) {
                scriptPath = bundleScript
            }
            let nodePath = findNodeExecutable()
            let process = Process()
            if nodePath.hasPrefix("/") {
                process.executableURL = URL(fileURLWithPath: nodePath)
                process.arguments = [scriptPath]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["node", scriptPath]
            }
            process.currentDirectoryURL = URL(fileURLWithPath: (scriptPath as NSString).deletingLastPathComponent)
            
            var env = ProcessInfo.processInfo.environment
            let home = NSHomeDirectory()
            let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            env["PATH"] = "\(home)/.nvm/versions/node/v22.23.2/bin:/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
            process.environment = env
            process.standardOutput = nil
            process.standardError = nil
            try? process.run()
        }
    }

    func loadConsole() {
        // 1. 优先秒开 App Bundle 内置的 index.html（0 毫秒极速瞬启，绝对无黑屏）
        if let localHTML = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(localHTML, allowingReadAccessTo: localHTML.deletingLastPathComponent())
            return
        }
        // 2. 备用源码目录的 index.html
        let fallbackHTML = URL(fileURLWithPath: "/Users/yohanes/antigravity-switcher/index.html")
        if FileManager.default.fileExists(atPath: fallbackHTML.path) {
            webView.loadFileURL(fallbackHTML, allowingReadAccessTo: fallbackHTML.deletingLastPathComponent())
            return
        }
        // 3. 兜底 HTTP 方式
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

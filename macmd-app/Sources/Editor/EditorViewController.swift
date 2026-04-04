import AppKit
import WebKit

final class EditorViewController: NSViewController, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var isFluidMode = false
    private var lineNumbersVisible = false
    // Loaded from UserDefaults on init. nil = follow system.
    private var userSelectedTheme: String? = {
        let saved = UserDefaults.standard.string(forKey: "macmd.theme")
        return (saved == "auto" || saved == nil) ? nil : saved
    }()
    weak var document: MarkdownDocument?

    override func loadView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "macmd")
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        view = webView
        loadEditorHTML()
    }

    // MARK: - Zoom

    @objc func zoomIn(_ sender: Any?) {
        webView.pageZoom = min(webView.pageZoom + 0.1, 3.0)
    }

    @objc func zoomOut(_ sender: Any?) {
        webView.pageZoom = max(webView.pageZoom - 0.1, 0.5)
    }

    @objc func resetZoom(_ sender: Any?) {
        webView.pageZoom = 1.0
    }

    // MARK: - Theme

    @objc func setThemeLight(_ sender: Any?) {
        userSelectedTheme = "light"
        applyTheme("light")
    }

    @objc func setThemeDark(_ sender: Any?) {
        userSelectedTheme = "dark"
        applyTheme("dark")
    }

    @objc func setThemeSepia(_ sender: Any?) {
        userSelectedTheme = "sepia"
        applyTheme("sepia")
    }

    @objc func setThemeAuto(_ sender: Any?) {
        userSelectedTheme = nil
        let theme = systemTheme()
        applyTheme(theme)
    }

    private func applyTheme(_ theme: String) {
        webView.evaluateJavaScript("MacmdEditor.setTheme('\(theme)');")
    }

    private func systemTheme() -> String {
        let appearance = view.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? "dark" : "light"
    }

    // MARK: - Font Size

    @objc func increaseFontSize(_ sender: Any?) {
        webView.evaluateJavaScript("MacmdEditor.setFontSize(MacmdEditor.getFontSize() + 2);")
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        webView.evaluateJavaScript("MacmdEditor.setFontSize(MacmdEditor.getFontSize() - 2);")
    }

    // MARK: - Line Numbers

    @objc func toggleLineNumbers(_ sender: Any?) {
        lineNumbersVisible.toggle()
        let show = lineNumbersVisible ? "true" : "false"
        webView.evaluateJavaScript("MacmdEditor.showLineNumbers(\(show));")
        if let menuItem = sender as? NSMenuItem {
            menuItem.state = lineNumbersVisible ? .on : .off
        }
    }

    // MARK: - JS Bridge (for preferences)

    func evaluateJS(_ js: String) {
        webView.evaluateJavaScript(js)
    }

    // MARK: - Content

    func loadContent(_ content: String) {
        let escaped = escapeForJavaScript(content)
        let js = "MacmdEditor.setContent(\"\(escaped)\");"
        webView.evaluateJavaScript(js)
    }

    func toggleMode() {
        isFluidMode.toggle()
        let mode = isFluidMode ? "fluid" : "reading"
        webView.evaluateJavaScript("MacmdEditor.setMode('\(mode)');")
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "contentChanged":
                if let content = body["content"] as? String {
                    self.document?.content = content
                    self.document?.updateChangeCount(.changeDone)
                }
            case "ready":
                if let content = self.document?.content {
                    self.loadContent(content)
                }
                // Apply saved settings
                let theme = self.userSelectedTheme ?? self.systemTheme()
                self.applyTheme(theme)

                let fontSize = UserDefaults.standard.integer(forKey: "macmd.fontSize")
                if fontSize > 0 {
                    self.webView.evaluateJavaScript("MacmdEditor.setFontSize(\(fontSize));")
                }
                if UserDefaults.standard.bool(forKey: "macmd.lineNumbers") {
                    self.lineNumbersVisible = true
                    self.webView.evaluateJavaScript("MacmdEditor.showLineNumbers(true);")
                }
            default:
                break
            }
        }
    }

    // MARK: - Private

    private func escapeForJavaScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    private func loadEditorHTML() {
        guard let editorDir = Bundle.main.resourceURL?.appendingPathComponent("editor") else {
            return
        }

        let indexURL = editorDir.appendingPathComponent("index.html")

        // No @media rules — JS controls all colors via setTheme()
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    background: #ffffff;
                    color: #1e1e1e;
                }
                #editor {
                    width: 100%;
                    min-height: 100vh;
                }
                .cm-editor { min-height: 100vh; outline: none; }
            </style>
        </head>
        <body>
            <div id="editor"></div>
            <script src="editor.js"></script>
            <script>
                MacmdEditor.createEditor(
                    document.getElementById('editor'),
                    '',
                    'reading'
                );
                window.webkit.messageHandlers.macmd.postMessage({ action: 'ready' });
            </script>
        </body>
        </html>
        """

        try? html.write(to: indexURL, atomically: true, encoding: .utf8)
        webView.loadFileURL(indexURL, allowingReadAccessTo: editorDir)
    }
}

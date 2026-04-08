import AppKit
import WebKit

final class EditorViewController: NSViewController, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var isFluidMode = false
    private var shouldStartInEditMode = false
    private var lineNumbersVisible = false
    // Loaded from UserDefaults on init. nil = follow system.
    private var userSelectedTheme: String? = {
        let saved = UserDefaults.standard.string(forKey: "MadMac.theme")
        return (saved == "auto" || saved == nil) ? nil : saved
    }()
    weak var document: MarkdownDocument?

    override func loadView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "MadMac")
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        view = webView
        loadEditorHTML()
    }

    // MARK: - Zoom

    /// Current zoom level (1.0 = 100%). Drives the unified --md-zoom CSS variable
    /// in reading mode, scaling text, headings, code, Mermaid diagrams, and KaTeX
    /// math from a single source of truth.
    private var currentZoom: Double = {
        let saved = UserDefaults.standard.double(forKey: "MadMac.zoom")
        return saved > 0 ? saved : 1.0
    }()

    @objc func zoomIn(_ sender: Any?) {
        currentZoom = min(currentZoom + 0.1, 3.0)
        applyZoom()
    }

    @objc func zoomOut(_ sender: Any?) {
        currentZoom = max(currentZoom - 0.1, 0.5)
        applyZoom()
    }

    @objc func resetZoom(_ sender: Any?) {
        currentZoom = 1.0
        applyZoom()
    }

    private func applyZoom() {
        webView.evaluateJavaScript("MacmdEditor.setZoom(\(currentZoom));")
        UserDefaults.standard.set(currentZoom, forKey: "MadMac.zoom")
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

    // MARK: - Copy

    /// Cmd+Shift+C: copy selection as rich text (rendered HTML)
    @objc func copyAsRichText(_ sender: Any?) {
        webView.evaluateJavaScript("MacmdEditor.copySelectionAsRichText()") { result, _ in
            guard let html = result as? String, !html.isEmpty else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if let data = html.data(using: .utf8) {
                pasteboard.setData(data, forType: .html)
            }
            // Also set plain text version (stripped)
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            pasteboard.setString(stripped, forType: .string)
        }
    }

    func startInEditMode() {
        shouldStartInEditMode = true
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

                let fontSize = UserDefaults.standard.integer(forKey: "MadMac.fontSize")
                if fontSize > 0 {
                    self.webView.evaluateJavaScript("MacmdEditor.setFontSize(\(fontSize));")
                }
                if UserDefaults.standard.bool(forKey: "MadMac.lineNumbers") {
                    self.lineNumbersVisible = true
                    self.webView.evaluateJavaScript("MacmdEditor.showLineNumbers(true);")
                }
                // Apply persisted zoom level
                if self.currentZoom != 1.0 {
                    self.webView.evaluateJavaScript("MacmdEditor.setZoom(\(self.currentZoom));")
                }
                // New file → edit mode
                if self.shouldStartInEditMode {
                    self.shouldStartInEditMode = false
                    self.isFluidMode = true
                    self.webView.evaluateJavaScript("MacmdEditor.setMode('fluid');")
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
                window.webkit.messageHandlers.MadMac.postMessage({ action: 'ready' });
            </script>
        </body>
        </html>
        """

        try? html.write(to: indexURL, atomically: true, encoding: .utf8)
        webView.loadFileURL(indexURL, allowingReadAccessTo: editorDir)
    }
}

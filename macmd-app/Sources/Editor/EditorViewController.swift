import AppKit
import WebKit

final class EditorViewController: NSViewController, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var isFluidMode = false
    private var appearanceObservation: NSKeyValueObservation?
    weak var document: MarkdownDocument?

    override func loadView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "macmd")
        config.userContentController = userContentController
        // Allow file access for loading editor.js from the bundle
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        view = webView
        loadEditorHTML()
        observeAppearanceChanges()
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

    // MARK: - Theme

    private func observeAppearanceChanges() {
        appearanceObservation = NSApp.observe(
            \.effectiveAppearance,
            options: [.new, .initial]
        ) { [weak self] _, _ in
            self?.updateTheme()
        }
    }

    private func updateTheme() {
        let appearance = view.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = isDark ? "dark" : "light"
        webView.evaluateJavaScript("MacmdEditor.setTheme('\(theme)');")
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WKScriptMessageHandler delivers on the main thread, so we can
        // safely assume main actor isolation for accessing our properties.
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
                self.updateTheme()
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
        // WKWebView's loadHTMLString doesn't reliably load local <script src="...">
        // even with a file:// baseURL. Use loadFileURL with a real HTML file instead.
        guard let editorDir = Bundle.main.resourceURL?.appendingPathComponent("editor") else {
            return
        }

        let indexURL = editorDir.appendingPathComponent("index.html")

        // Write index.html to the editor directory if it doesn't exist
        // (or always overwrite to ensure it's current)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root { color-scheme: light dark; }
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                }
                #editor {
                    max-width: 720px;
                    margin: 0 auto;
                    padding: 24px 48px;
                    min-height: 100vh;
                }
                .cm-editor { height: 100vh; outline: none; }
                .cm-scroller { font-family: inherit; font-size: inherit; line-height: inherit; }
                .cm-content { font-family: inherit; padding: 24px 0; }
                .cm-line { padding: 0; }
                @media (prefers-color-scheme: dark) {
                    body { background: #1e1e1e; color: #d4d4d4; }
                }
                @media (prefers-color-scheme: light) {
                    body { background: #ffffff; color: #1e1e1e; }
                }
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

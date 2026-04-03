import AppKit
import WebKit

final class EditorViewController: NSViewController, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var isFluidMode = false
    weak var document: MarkdownDocument?

    override func loadView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "macmd")
        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        view = webView
        loadEditorHTML()
    }

    // MARK: - Content

    func loadContent(_ content: String) {
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
        let js = "MacmdEditor.setContent(\"\(escaped)\");"
        webView.evaluateJavaScript(js)
    }

    func currentContent() -> String {
        var result = ""
        let semaphore = DispatchSemaphore(value: 0)
        webView.evaluateJavaScript("MacmdEditor.getContent();") { value, _ in
            result = value as? String ?? ""
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    func toggleMode() {
        isFluidMode.toggle()
        let mode = isFluidMode ? "fluid" : "reading"
        webView.evaluateJavaScript("MacmdEditor.setMode('\(mode)');")
        document?.undoManager?.removeAllActions()
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "contentChanged":
            if let content = body["content"] as? String {
                document?.content = content
                document?.updateChangeCount(.changeDone)
            }
        case "ready":
            if let content = document?.content {
                loadContent(content)
            }
        default:
            break
        }
    }

    // MARK: - Private

    private func loadEditorHTML() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    margin: 0;
                    padding: 24px 48px;
                    font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    max-width: 720px;
                    margin: 0 auto;
                }
                .cm-editor {
                    height: 100vh;
                    outline: none;
                }
                .cm-scroller {
                    font-family: inherit;
                    font-size: inherit;
                    line-height: inherit;
                }
                .cm-content {
                    font-family: inherit;
                    padding: 24px 0;
                }
                .cm-line {
                    padding: 0;
                }
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
                const editor = MacmdEditor.createEditor(
                    document.getElementById('editor'),
                    '',
                    'reading'
                );
                window.webkit.messageHandlers.macmd.postMessage({ action: 'ready' });
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }
}

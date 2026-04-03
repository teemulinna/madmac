import AppKit
import UniformTypeIdentifiers

extension UTType {
    static var markdownText: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

final class MarkdownDocument: NSDocument {
    var content: String = ""
    private var editorViewController: EditorViewController?

    // MARK: - NSDocument

    override class var autosavesInPlace: Bool { true }

    override class var readableTypes: [String] {
        ["net.daringfireball.markdown", "public.plain-text"]
    }

    override class var writableTypes: [String] {
        ["net.daringfireball.markdown"]
    }

    override func makeWindowControllers() {
        let viewController = EditorViewController()
        viewController.document = self

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.center()
        window.setFrameAutosaveName("MarkdownEditor")
        window.minSize = NSSize(width: 400, height: 300)

        let windowController = NSWindowController(window: window)
        addWindowController(windowController)

        editorViewController = viewController
        viewController.loadContent(content)
    }

    // MARK: - Reading

    override func read(from data: Data, ofType typeName: String) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "com.macmd.error",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "File is not valid UTF-8"]
            )
        }
        content = text
        editorViewController?.loadContent(content)
    }

    // MARK: - Writing

    override func data(ofType typeName: String) throws -> Data {
        if let viewController = editorViewController {
            content = viewController.currentContent()
        }
        guard let data = content.data(using: .utf8) else {
            throw NSError(
                domain: "com.macmd.error",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode as UTF-8"]
            )
        }
        return data
    }

    // MARK: - Mode Toggle

    @objc func toggleMode(_ sender: Any?) {
        editorViewController?.toggleMode()
    }
}

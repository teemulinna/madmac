import AppKit
import UniformTypeIdentifiers

extension UTType {
    static var markdownText: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

@objc(MarkdownDocument)
final class MarkdownDocument: NSDocument {
    var content: String = ""
    private var editorViewController: EditorViewController?

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
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.minSize = NSSize(width: 400, height: 300)
        window.title = displayName
        // Restore saved position for this file
        let saveName = fileURL?.lastPathComponent ?? "macmd-untitled"
        window.setFrameAutosaveName(saveName)

        // Validate: if window is too small or off-screen, reset to default
        let frame = window.frame
        if frame.width < 500 || frame.height < 400 {
            window.setContentSize(NSSize(width: 1000, height: 700))
            window.center()
        } else if let screen = NSScreen.main, !screen.visibleFrame.intersects(frame) {
            window.center()
        }

        let windowController = NSWindowController(window: window)
        addWindowController(windowController)

        editorViewController = viewController

        // New file (no content) → open in edit mode
        // Existing file → open in reading mode (default)
        if content.isEmpty {
            viewController.startInEditMode()
        }
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "com.macmd.error",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "File is not valid UTF-8 encoded."]
            )
        }
        content = text
        editorViewController?.loadContent(content)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = content.data(using: .utf8) else {
            throw NSError(
                domain: "com.macmd.error",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode as UTF-8"]
            )
        }
        return data
    }

    @objc func toggleMode(_ sender: Any?) {
        editorViewController?.toggleMode()
    }
}

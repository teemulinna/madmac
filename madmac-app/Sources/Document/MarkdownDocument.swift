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

        let workspaceWC = WorkspaceWindowController(editorViewController: viewController)
        guard let window = workspaceWC.window else { return }

        window.title = displayName

        // Restore saved position for this file
        let saveName = fileURL?.lastPathComponent ?? "madmac-untitled"
        window.setFrameAutosaveName(saveName)

        // Validate: if window is too small or off-screen, reset to default
        let frame = window.frame
        if frame.width < 600 || frame.height < 400 {
            window.setContentSize(NSSize(width: 1000, height: 700))
            window.center()
        } else if let screen = NSScreen.main, !screen.visibleFrame.intersects(frame) {
            window.center()
        }

        addWindowController(workspaceWC)
        editorViewController = viewController

        // Register in sidebar's open files list
        let fileName = fileURL?.lastPathComponent ?? "Untitled"
        let fileURL = fileURL ?? URL(fileURLWithPath: "/dev/null")
        workspaceWC.sidebarViewController.addOpenFile(name: fileName, url: fileURL)

        // New file (no content) → open in edit mode
        // Existing file → open in reading mode (default)
        if content.isEmpty {
            viewController.startInEditMode()
        }
    }

    override func close() {
        // Remove from sidebar's open files list
        if let url = fileURL {
            for wc in windowControllers {
                if let workspaceWC = wc as? WorkspaceWindowController {
                    workspaceWC.sidebarViewController.removeOpenFile(url: url)
                }
            }
        }
        super.close()
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "com.madmac.error",
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
                domain: "com.madmac.error",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode as UTF-8"]
            )
        }
        return data
    }

    @objc func toggleMode(_ sender: Any?) {
        editorViewController?.toggleMode()
    }

    @objc func exportPDF(_ sender: Any?) {
        guard let window = windowControllers.first?.window else { return }
        PrintController.showExportSheet(for: self, from: window)
    }
}

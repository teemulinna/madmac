import AppKit

/// Handles Cmd+P: converts current markdown to PDF via Typst and opens in Preview.
enum PrintController {

    /// Available presets (loaded from Resources/presets/).
    static var presets: [String] {
        guard let presetsDir = Bundle.main.resourceURL?.appendingPathComponent("presets") else {
            return []
        }
        let files = try? FileManager.default.contentsOfDirectory(
            at: presetsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )
        return (files ?? [])
            .filter { $0.pathExtension == "typ" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Export the given markdown content to PDF using a preset.
    /// - Parameters:
    ///   - markdown: Raw markdown string
    ///   - preset: Preset name (e.g., "agion", "minimal"). Defaults to "minimal".
    ///   - title: Document title (used for filename)
    ///   - completion: Called with the PDF URL on success, or nil on failure.
    static func exportToPDF(
        markdown: String,
        preset: String = "minimal",
        title: String = "document",
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = generatePDF(markdown: markdown, preset: preset, title: title)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Synchronous PDF generation (runs on background thread).
    private static func generatePDF(markdown: String, preset: String, title: String) -> URL? {
        // 1. Convert markdown → typst markup
        let typstBody = MarkdownToTypst.convert(markdown)

        // 2. Load preset template
        let presetContent: String
        if let presetURL = Bundle.main.resourceURL?
            .appendingPathComponent("presets")
            .appendingPathComponent("\(preset).typ") {
            presetContent = (try? String(contentsOf: presetURL, encoding: .utf8)) ?? ""
        } else {
            presetContent = ""
        }

        // 3. Compose full Typst document
        let fullTypst = """
        \(presetContent)

        // --- Document content ---

        \(typstBody)
        """

        // 4. Write to temp file
        let tmpDir = FileManager.default.temporaryDirectory
        let typFile = tmpDir.appendingPathComponent("\(title).typ")
        let pdfFile = tmpDir.appendingPathComponent("\(title).pdf")

        do {
            try fullTypst.write(to: typFile, atomically: true, encoding: .utf8)
        } catch {
            NSLog("macmd: Failed to write .typ file: \(error)")
            return nil
        }

        // 5. Compile with typst
        let typstBinary = ProcessInfo.processInfo.environment["TYPST_BINARY"] ?? "/opt/homebrew/bin/typst"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: typstBinary)
        process.arguments = ["compile", typFile.path, pdfFile.path]

        // Pass font paths if set
        var env = ProcessInfo.processInfo.environment
        if env["TYPST_FONT_PATHS"] == nil {
            // Include system fonts
            env["TYPST_FONT_PATHS"] = "/System/Library/Fonts:/Library/Fonts"
        }
        process.environment = env

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("macmd: Failed to run typst: \(error)")
            return nil
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "unknown error"
            NSLog("macmd: typst compile failed: \(errorMsg)")
            return nil
        }

        guard FileManager.default.fileExists(atPath: pdfFile.path) else {
            NSLog("macmd: PDF file not created")
            return nil
        }

        return pdfFile
    }

    /// Show the PDF in Preview.app.
    static func openInPreview(_ pdfURL: URL) {
        NSWorkspace.shared.open(pdfURL)
    }

    /// Show a preset picker sheet, then export.
    static func showExportSheet(for document: MarkdownDocument, from window: NSWindow) {
        let presetList = presets
        guard !presetList.isEmpty else {
            // No presets found — export with defaults
            exportAndOpen(document: document, preset: "minimal")
            return
        }

        if presetList.count == 1 {
            // Single preset — skip picker
            exportAndOpen(document: document, preset: presetList[0])
            return
        }

        // Multiple presets — show picker
        let alert = NSAlert()
        alert.messageText = "Export to PDF"
        alert.informativeText = "Choose a style preset:"
        alert.alertStyle = .informational

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        for name in presetList {
            popup.addItem(withTitle: name.capitalized)
            popup.lastItem?.representedObject = name
        }
        alert.accessoryView = popup

        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let selectedPreset = popup.selectedItem?.representedObject as? String ?? "minimal"
            exportAndOpen(document: document, preset: selectedPreset)
        }
    }

    private static func exportAndOpen(document: MarkdownDocument, preset: String) {
        let title = document.fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        exportToPDF(markdown: document.content, preset: preset, title: title) { pdfURL in
            if let url = pdfURL {
                openInPreview(url)
            } else {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not generate PDF. Make sure typst is installed (brew install typst)."
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}

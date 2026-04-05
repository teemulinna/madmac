import AppKit

@main
struct MadMacApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Ensure NSDocumentController is initialized for document-based app
        _ = NSDocumentController.shared
        app.run()
    }
}

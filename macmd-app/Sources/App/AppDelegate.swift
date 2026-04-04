import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private var preferencesWindow: NSWindow?

    @objc func showPreferences(_ sender: Any?) {
        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let prefsVC = PreferencesViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = prefsVC
        window.title = "macmd Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        preferencesWindow = window
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About macmd", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit macmd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        fileMenu.addItem(.separator())

        let recentMenuItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent")
        recentMenu.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        recentMenuItem.submenu = recentMenu
        fileMenu.addItem(recentMenuItem)

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let copyMdItem = NSMenuItem(title: "Copy as Markdown", action: #selector(EditorViewController.copyAsMarkdown(_:)), keyEquivalent: "C")
        copyMdItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(copyMdItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let toggleModeItem = NSMenuItem(title: "Toggle Edit Mode", action: #selector(MarkdownDocument.toggleMode(_:)), keyEquivalent: "e")
        toggleModeItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(toggleModeItem)
        viewMenu.addItem(.separator())

        // Theme submenu
        let themeMenuItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "Theme")
        themeMenu.addItem(withTitle: "Auto (System)", action: #selector(EditorViewController.setThemeAuto(_:)), keyEquivalent: "")
        themeMenu.addItem(.separator())
        themeMenu.addItem(withTitle: "Light", action: #selector(EditorViewController.setThemeLight(_:)), keyEquivalent: "")
        themeMenu.addItem(withTitle: "Dark", action: #selector(EditorViewController.setThemeDark(_:)), keyEquivalent: "")
        themeMenu.addItem(withTitle: "Sunburn", action: #selector(EditorViewController.setThemeSepia(_:)), keyEquivalent: "")
        themeMenuItem.submenu = themeMenu
        viewMenu.addItem(themeMenuItem)

        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(EditorViewController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(EditorViewController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(EditorViewController.resetZoom(_:)), keyEquivalent: "0")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Increase Font Size", action: #selector(EditorViewController.increaseFontSize(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Decrease Font Size", action: #selector(EditorViewController.decreaseFontSize(_:)), keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Show Line Numbers", action: #selector(EditorViewController.toggleLineNumbers(_:)), keyEquivalent: "l")

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }
}

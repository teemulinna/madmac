import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        checkForUpdates()
    }

    private func checkForUpdates(userInitiated: Bool = false) {
        guard let url = URL(string: "https://api.github.com/repos/teemulinna/madmac/releases/latest") else { return }
        let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
            .trimmingCharacters(in: CharacterSet(charactersIn: "v "))

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlUrl = json["html_url"] as? String else {
                if userInitiated {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Update Check Failed"
                        alert.informativeText = "Could not reach GitHub to check for updates."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
                return
            }

            let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            NSLog("MadMac: update check — current=\(current) latest=\(latest)")

            let comparison = latest.compare(current, options: .numeric)
            if comparison == .orderedDescending {
                DispatchQueue.main.async {
                    self.presentUpdateAlert(latest: latest, current: current, releaseURL: htmlUrl)
                }
            } else if userInitiated {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date"
                    alert.informativeText = "MadMac \(current) is the latest version."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            }
        }.resume()
    }

    @objc func checkForUpdatesMenuItem(_ sender: Any?) {
        checkForUpdates(userInitiated: true)
    }

    /// Whether MadMac was installed via Homebrew Cask.
    /// Detected by checking if the bundle lives under a Caskroom directory.
    private var isInstalledViaBrew: Bool {
        Bundle.main.bundlePath.contains("/Caskroom/")
    }

    private func presentUpdateAlert(latest: String, current: String, releaseURL: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "MadMac \(latest) is available (you have \(current))."
        alert.alertStyle = .informational

        if isInstalledViaBrew {
            alert.addButton(withTitle: "Update Now")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                runBrewUpgradeAndRelaunch()
            }
        } else {
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: releaseURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Run `brew upgrade --cask madmac` in Terminal.app, then relaunch.
    /// Brew can't replace a running app bundle, so we quit first.
    /// The Terminal command quits MadMac, runs brew, then relaunches it.
    private func runBrewUpgradeAndRelaunch() {
        let script = """
        tell application "Terminal"
            activate
            do script "osascript -e 'tell application \\"MadMac\\" to quit' && sleep 1 && brew upgrade --cask madmac && open -a MadMac"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                NSLog("MadMac: AppleScript error: \(error)")
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to browse markdown files"
        panel.prompt = "Open Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Find the frontmost WorkspaceWindowController and set its sidebar root
        guard let window = NSApp.mainWindow,
              let workspaceWC = window.windowController as? WorkspaceWindowController else { return }
        workspaceWC.sidebarViewController.setFileBrowserRoot(url)
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
        window.title = "MadMac Settings"
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
        appMenu.addItem(withTitle: "About MadMac", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdatesMenuItem(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MadMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        let openFolderItem = NSMenuItem(title: "Open Folder…", action: #selector(openFolder(_:)), keyEquivalent: "O")
        openFolderItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(openFolderItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Export PDF…", action: #selector(MarkdownDocument.exportPDF(_:)), keyEquivalent: "p")
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
        let copyRichItem = NSMenuItem(title: "Copy as Rich Text", action: #selector(EditorViewController.copyAsRichText(_:)), keyEquivalent: "C")
        copyRichItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(copyRichItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let toggleSidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "b")
        toggleSidebarItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(toggleSidebarItem)
        viewMenu.addItem(.separator())

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
        // Cmd+= for Zoom In (the standard — accessible without Shift)
        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(EditorViewController.zoomIn(_:)), keyEquivalent: "=")
        zoomInItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomInItem)
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

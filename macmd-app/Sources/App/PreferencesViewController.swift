import AppKit

final class PreferencesViewController: NSViewController {

    private let themePopup = NSPopUpButton()
    private let fontSizeStepper = NSStepper()
    private let fontSizeLabel = NSTextField(labelWithString: "14")
    private let lineNumbersCheckbox = NSButton(checkboxWithTitle: "Show line numbers", target: nil, action: nil)
    private let spellCheckCheckbox = NSButton(checkboxWithTitle: "Spell check", target: nil, action: nil)

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 320))
        view = container

        // Title
        let titleLabel = NSTextField(labelWithString: "macmd Settings")
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Theme
        let themeLabel = NSTextField(labelWithString: "Theme:")
        themeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(themeLabel)

        themePopup.addItems(withTitles: ["Auto (System)", "Light", "Dark", "Sunburn"])
        themePopup.translatesAutoresizingMaskIntoConstraints = false
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        // Restore saved preference
        let savedTheme = UserDefaults.standard.string(forKey: "macmd.theme") ?? "auto"
        switch savedTheme {
        case "light": themePopup.selectItem(withTitle: "Light")
        case "dark": themePopup.selectItem(withTitle: "Dark")
        case "sepia": themePopup.selectItem(withTitle: "Sunburn")
        default: themePopup.selectItem(withTitle: "Auto (System)")
        }
        container.addSubview(themePopup)

        // Font size
        let fontLabel = NSTextField(labelWithString: "Font size:")
        fontLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fontLabel)

        let savedSize = UserDefaults.standard.integer(forKey: "macmd.fontSize")
        let fontSize = savedSize > 0 ? savedSize : 14

        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        fontSizeLabel.stringValue = "\(fontSize) px"
        fontSizeLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        container.addSubview(fontSizeLabel)

        fontSizeStepper.minValue = 10
        fontSizeStepper.maxValue = 32
        fontSizeStepper.integerValue = fontSize
        fontSizeStepper.increment = 1
        fontSizeStepper.translatesAutoresizingMaskIntoConstraints = false
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(fontSizeChanged(_:))
        container.addSubview(fontSizeStepper)

        // Line numbers
        lineNumbersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        lineNumbersCheckbox.state = UserDefaults.standard.bool(forKey: "macmd.lineNumbers") ? .on : .off
        lineNumbersCheckbox.target = self
        lineNumbersCheckbox.action = #selector(lineNumbersChanged(_:))
        container.addSubview(lineNumbersCheckbox)

        // Spell check
        spellCheckCheckbox.translatesAutoresizingMaskIntoConstraints = false
        spellCheckCheckbox.state = UserDefaults.standard.bool(forKey: "macmd.spellCheck") ? .on : .off
        spellCheckCheckbox.target = self
        spellCheckCheckbox.action = #selector(spellCheckChanged(_:))
        container.addSubview(spellCheckCheckbox)

        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),

            themeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            themeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            themeLabel.widthAnchor.constraint(equalToConstant: 100),

            themePopup.centerYAnchor.constraint(equalTo: themeLabel.centerYAnchor),
            themePopup.leadingAnchor.constraint(equalTo: themeLabel.trailingAnchor, constant: 8),
            themePopup.widthAnchor.constraint(equalToConstant: 200),

            fontLabel.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 20),
            fontLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            fontLabel.widthAnchor.constraint(equalToConstant: 100),

            fontSizeLabel.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontSizeLabel.leadingAnchor.constraint(equalTo: fontLabel.trailingAnchor, constant: 8),

            fontSizeStepper.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontSizeStepper.leadingAnchor.constraint(equalTo: fontSizeLabel.trailingAnchor, constant: 8),

            lineNumbersCheckbox.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: 24),
            lineNumbersCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),

            spellCheckCheckbox.topAnchor.constraint(equalTo: lineNumbersCheckbox.bottomAnchor, constant: 12),
            spellCheckCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
        ])
    }

    // MARK: - Actions

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        let theme: String
        switch sender.titleOfSelectedItem {
        case "Light": theme = "light"
        case "Dark": theme = "dark"
        case "Sunburn": theme = "sepia"
        default: theme = "auto"
        }
        UserDefaults.standard.set(theme, forKey: "macmd.theme")
        applyToAllEditors("setThemeFromPrefs", value: theme)
    }

    @objc private func fontSizeChanged(_ sender: NSStepper) {
        let size = sender.integerValue
        fontSizeLabel.stringValue = "\(size) px"
        UserDefaults.standard.set(size, forKey: "macmd.fontSize")
        applyToAllEditors("setFontSize", value: "\(size)")
    }

    @objc private func lineNumbersChanged(_ sender: NSButton) {
        let show = sender.state == .on
        UserDefaults.standard.set(show, forKey: "macmd.lineNumbers")
        applyToAllEditors("showLineNumbers", value: show ? "true" : "false")
    }

    @objc private func spellCheckChanged(_ sender: NSButton) {
        let on = sender.state == .on
        UserDefaults.standard.set(on, forKey: "macmd.spellCheck")
        // Spell check is handled at WKWebView level, not JS
    }

    /// Apply a JS call to all open editor windows
    private func applyToAllEditors(_ method: String, value: String) {
        for document in NSDocumentController.shared.documents {
            guard let mdDoc = document as? MarkdownDocument else { continue }
            for wc in mdDoc.windowControllers {
                guard let vc = wc.contentViewController as? EditorViewController else { continue }
                if method == "setThemeFromPrefs" {
                    // Special: "auto" means follow system
                    if value == "auto" {
                        vc.setThemeAuto(nil)
                    } else {
                        switch value {
                        case "light": vc.setThemeLight(nil)
                        case "dark": vc.setThemeDark(nil)
                        case "sepia": vc.setThemeSepia(nil)
                        default: break
                        }
                    }
                } else {
                    vc.evaluateJS("MacmdEditor.\(method)(\(value));")
                }
            }
        }
    }
}

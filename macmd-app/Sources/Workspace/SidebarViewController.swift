import AppKit

// MARK: - Data Model

/// Represents a section header in the sidebar (e.g., "Open Files").
final class SidebarSection: NSObject {
    let title: String
    let icon: NSImage?
    var children: [Any] = []  // SidebarItem or SidebarFolder

    init(title: String, icon: NSImage? = nil) {
        self.title = title
        self.icon = icon
    }
}

/// Represents a folder in the file browser tree.
final class SidebarFolder: NSObject {
    let name: String
    let url: URL
    var children: [Any] = []  // SidebarItem or SidebarFolder

    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

/// Represents a file entry.
final class SidebarItem: NSObject {
    let name: String
    let url: URL

    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

// MARK: - SidebarViewController

@objc(SidebarViewController)
final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    private var outlineView: NSOutlineView!
    private let openFilesSection = SidebarSection(
        title: "Open Files",
        icon: NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
    )
    private let recentFilesSection = SidebarSection(
        title: "Recent",
        icon: NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
    )
    private let fileBrowserSection = SidebarSection(
        title: "Files",
        icon: NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
    )
    private var fileWatcher: FileWatcher?

    private var sections: [SidebarSection] {
        [openFilesSection, recentFilesSection, fileBrowserSection]
    }

    // MARK: - Public API

    func refreshRecentFiles() {
        let recentURLs = NSDocumentController.shared.recentDocumentURLs
        let openURLs = Set(openFilesSection.children.compactMap { ($0 as? SidebarItem)?.url })
        recentFilesSection.children = recentURLs
            .filter { !openURLs.contains($0) }  // Exclude already-open files
            .prefix(10)
            .map { SidebarItem(name: $0.lastPathComponent, url: $0) }
        outlineView?.reloadData()
        outlineView?.expandItem(recentFilesSection)
    }

    func addOpenFile(name: String, url: URL) {
        guard !openFilesSection.children.contains(where: { ($0 as? SidebarItem)?.url == url }) else { return }
        openFilesSection.children.append(SidebarItem(name: name, url: url))
        outlineView?.reloadData()
        outlineView?.expandItem(openFilesSection)
        refreshRecentFiles()

        if fileWatcher == nil {
            let parentDir = url.deletingLastPathComponent()
            setFileBrowserRoot(parentDir)
        }
    }

    func removeOpenFile(url: URL) {
        openFilesSection.children.removeAll { ($0 as? SidebarItem)?.url == url }
        outlineView?.reloadData()
    }

    func setFileBrowserRoot(_ directory: URL) {
        fileWatcher?.stop()
        fileWatcher = FileWatcher(directory: directory)
        fileWatcher?.onChange = { [weak self] in
            self?.refreshFileBrowser()
        }
        fileWatcher?.start()
        refreshFileBrowser()
        UserDefaults.standard.set(directory.path, forKey: "macmd.fileBrowserRoot")
    }

    private func refreshFileBrowser() {
        guard let watcher = fileWatcher else { return }
        fileBrowserSection.children = buildFileTree(at: watcher.directory)
        outlineView?.reloadData()
        outlineView?.expandItem(fileBrowserSection)
    }

    /// Build a hierarchical file tree from a directory.
    private func buildFileTree(at directory: URL) -> [Any] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var folders: [SidebarFolder] = []
        var files: [SidebarItem] = []

        for url in contents.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                let folder = SidebarFolder(name: url.lastPathComponent, url: url)
                folder.children = buildFileTree(at: url)
                // Only include folders that contain markdown files (directly or nested)
                if !folder.children.isEmpty {
                    folders.append(folder)
                }
            } else {
                let ext = url.pathExtension.lowercased()
                if ext == "md" || ext == "markdown" || ext == "mdown" || ext == "mkd" {
                    files.append(SidebarItem(name: url.lastPathComponent, url: url))
                }
            }
        }

        return folders + files
    }

    // MARK: - Lifecycle

    override func loadView() {
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 16
        outlineView.rowSizeStyle = .medium
        outlineView.style = .sourceList
        outlineView.floatsGroupRows = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        outlineView.dataSource = self
        outlineView.delegate = self

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = true
        scrollView.autoresizingMask = [.width, .height]

        view = scrollView

        // Deferred reload: data may have been set before outlineView existed
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.outlineView.reloadData()
            self.outlineView.expandItem(nil, expandChildren: true)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshRecentFiles()
        outlineView?.reloadData()
        outlineView?.expandItem(nil, expandChildren: true)
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return sections.count }
        if let section = item as? SidebarSection { return section.children.count }
        if let folder = item as? SidebarFolder { return folder.children.count }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return sections[index] }
        if let section = item as? SidebarSection { return section.children[index] }
        if let folder = item as? SidebarFolder { return folder.children[index] }
        return NSNull()
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is SidebarSection || item is SidebarFolder
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let section = item as? SidebarSection {
            return makeSectionCell(section, in: outlineView)
        }
        if let folder = item as? SidebarFolder {
            return makeFolderCell(folder, in: outlineView)
        }
        if let fileItem = item as? SidebarItem {
            return makeFileCell(fileItem, in: outlineView)
        }
        return nil
    }

    private func makeSectionCell(_ section: SidebarSection, in outlineView: NSOutlineView) -> NSTableCellView {
        let cellID = NSUserInterfaceItemIdentifier("SectionCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = section.title.uppercased()
        cell.textField?.font = .systemFont(ofSize: 11, weight: .bold)
        cell.textField?.textColor = .tertiaryLabelColor
        return cell
    }

    private func makeFolderCell(_ folder: SidebarFolder, in outlineView: NSOutlineView) -> NSTableCellView {
        let cellID = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.imageView?.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        cell.imageView?.contentTintColor = .secondaryLabelColor
        cell.textField?.stringValue = folder.name
        cell.textField?.font = .systemFont(ofSize: 13)
        cell.textField?.textColor = .labelColor
        return cell
    }

    private func makeFileCell(_ fileItem: SidebarItem, in outlineView: NSOutlineView) -> NSTableCellView {
        let cellID = NSUserInterfaceItemIdentifier("FileCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.imageView?.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        cell.imageView?.contentTintColor = .secondaryLabelColor
        cell.textField?.stringValue = fileItem.name
        cell.textField?.font = .systemFont(ofSize: 13)
        cell.textField?.textColor = .labelColor
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is SidebarSection
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is SidebarItem
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0 else { return }
        guard let item = outlineView.item(atRow: selectedRow) as? SidebarItem else { return }

        NSDocumentController.shared.openDocument(
            withContentsOf: item.url,
            display: true,
            completionHandler: { _, _, _ in }
        )
    }
}

import AppKit

@objc(WorkspaceWindowController)
final class WorkspaceWindowController: NSWindowController {

    let splitViewController = NSSplitViewController()
    private(set) var sidebarViewController: SidebarViewController
    private(set) var editorViewController: EditorViewController

    init(editorViewController editor: EditorViewController) {
        self.sidebarViewController = SidebarViewController()
        self.editorViewController = editor

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        // Titlebar integration: sidebar extends under titlebar (like Finder/Xcode)
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified

        // Add an empty toolbar so the title area integrates properly
        let toolbar = NSToolbar(identifier: "macmd.toolbar")
        toolbar.displayMode = .iconOnly
        // toolbar.showsBaselineSeparator — deprecated in macOS 15
        window.toolbar = toolbar

        // Sidebar: collapsible panel on the left
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 450

        // Editor: main content area on the right
        let editorItem = NSSplitViewItem(viewController: editor)
        editorItem.minimumThickness = 300

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(editorItem)

        window.contentViewController = splitViewController
        window.minSize = NSSize(width: 650, height: 450)

        // Native tabs: documents open as tabs in the same window
        window.tabbingMode = .preferred
        window.tabbingIdentifier = NSWindow.TabbingIdentifier("com.macmd.workspace")
    }

    required init?(coder: NSCoder) {
        self.sidebarViewController = SidebarViewController()
        self.editorViewController = EditorViewController()
        super.init(coder: coder)
    }
}

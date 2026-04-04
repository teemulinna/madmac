import AppKit

// MARK: - Workspace Tests

/// RED tests for WP-2: NSSplitViewController skeleton.
/// These verify the new workspace architecture:
///   NSWindow → WorkspaceWindowController → NSSplitViewController
///     ├─ SidebarViewController (left)
///     └─ EditorViewController (right)

func testWorkspaceWindowControllerClassExists() {
    section("WorkspaceWindowController")

    let cls: AnyClass? = NSClassFromString("WorkspaceWindowController")
    assert(cls != nil, "WorkspaceWindowController class is resolvable by name")
}

func testWorkspaceWindowControllerIsNSWindowController() {
    let cls: AnyClass? = NSClassFromString("WorkspaceWindowController")
    if let cls = cls {
        assert(cls is NSWindowController.Type, "WorkspaceWindowController is an NSWindowController subclass")
    } else {
        assert(false, "WorkspaceWindowController is an NSWindowController subclass — class not found")
    }
}

func testWorkspaceContainsSplitViewController() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as? NSSplitViewController
    assert(splitVC != nil, "WorkspaceWindowController.contentViewController is NSSplitViewController")
}

func testSplitViewHasTwoItems() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as! NSSplitViewController
    assertEqual(splitVC.splitViewItems.count, 2, "NSSplitViewController has exactly 2 items (sidebar + editor)")
}

func testSplitViewFirstItemIsSidebar() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as! NSSplitViewController
    let firstItem = splitVC.splitViewItems[0]
    assert(firstItem.viewController is SidebarViewController, "First split view item is SidebarViewController")
}

func testSplitViewSecondItemIsEditor() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as! NSSplitViewController
    let secondItem = splitVC.splitViewItems[1]
    assert(secondItem.viewController is EditorViewController, "Second split view item is EditorViewController")
}

func testSidebarItemIsSidebarType() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as! NSSplitViewController
    let sidebarItem = splitVC.splitViewItems[0]
    // NSSplitViewItem created with sidebarWithViewController has behavior = .sidebar
    assertEqual(sidebarItem.behavior, .sidebar, "Sidebar item has .sidebar behavior")
}

func testSidebarMinimumThickness() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as! NSSplitViewController
    let sidebarItem = splitVC.splitViewItems[0]
    assert(sidebarItem.minimumThickness >= 200, "Sidebar minimum thickness >= 200px")
}

func testSidebarMaximumThickness() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let splitVC = wc.contentViewController as! NSSplitViewController
    let sidebarItem = splitVC.splitViewItems[0]
    assert(sidebarItem.maximumThickness <= 450, "Sidebar maximum thickness <= 450px")
}

func testWindowHasResizableStyle() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    assert(wc.window!.styleMask.contains(.resizable), "Window has .resizable style mask")
}

func testWindowMinSize() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let minSize = wc.window!.minSize
    assert(minSize.width >= 600, "Window minimum width >= 600")
    assert(minSize.height >= 400, "Window minimum height >= 400")
}

// MARK: - SidebarViewController Tests

func testSidebarViewControllerClassExists() {
    section("SidebarViewController")

    let cls: AnyClass? = NSClassFromString("SidebarViewController")
    assert(cls != nil, "SidebarViewController class is resolvable by name")
}

func testSidebarViewControllerCreatesView() {
    let vc = SidebarViewController()
    _ = vc.view  // trigger loadView
    assert(vc.isViewLoaded, "SidebarViewController creates a view on access")
}

// MARK: - Native Tabs Tests (WP-3)

func testWindowTabbingModeIsPreferred() {
    section("Native Tabs (WP-3)")

    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    assertEqual(wc.window!.tabbingMode, .preferred, "Window tabbingMode is .preferred")
}

func testWindowHasTabbingIdentifier() {
    let editor = EditorViewController()
    let wc = WorkspaceWindowController(editorViewController: editor)
    let identifier = wc.window!.tabbingIdentifier
    assert(!identifier.isEmpty, "Window has a non-empty tabbingIdentifier")
}

// MARK: - Open Files Sidebar Tests (WP-4)

func testSidebarHasOutlineView() {
    section("Open Files Sidebar (WP-4)")

    let vc = SidebarViewController()
    _ = vc.view  // trigger loadView
    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    assert(outlineView != nil, "SidebarViewController contains NSOutlineView")
}

func testSidebarOutlineViewHasDataSource() {
    let vc = SidebarViewController()
    _ = vc.view
    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    assert(outlineView?.dataSource != nil, "NSOutlineView has a dataSource")
}

func testSidebarOutlineViewHasDelegate() {
    let vc = SidebarViewController()
    _ = vc.view
    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    assert(outlineView?.delegate != nil, "NSOutlineView has a delegate")
}

func testSidebarHasOpenFilesSection() {
    let vc = SidebarViewController()
    _ = vc.view
    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    // Root-level items should include "Open Files" section
    let rootCount = outlineView?.dataSource?.outlineView?(outlineView!, numberOfChildrenOfItem: nil) ?? 0
    assert(rootCount >= 1, "Sidebar has at least 1 root section (Open Files)")
}

func testSidebarTracksOpenDocument() {
    let vc = SidebarViewController()
    _ = vc.view

    // Simulate adding a document
    vc.addOpenFile(name: "test.md", url: URL(fileURLWithPath: "/tmp/test.md"))

    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    let sectionItem = outlineView?.dataSource?.outlineView?(outlineView!, child: 0, ofItem: nil)
    let childCount = outlineView?.dataSource?.outlineView?(outlineView!, numberOfChildrenOfItem: sectionItem) ?? 0
    assert(childCount == 1, "Open Files section has 1 child after adding a file")
}

func testSidebarRemovesClosedDocument() {
    let vc = SidebarViewController()
    _ = vc.view

    let url = URL(fileURLWithPath: "/tmp/test.md")
    vc.addOpenFile(name: "test.md", url: url)
    vc.removeOpenFile(url: url)

    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    let sectionItem = outlineView?.dataSource?.outlineView?(outlineView!, child: 0, ofItem: nil)
    let childCount = outlineView?.dataSource?.outlineView?(outlineView!, numberOfChildrenOfItem: sectionItem) ?? 0
    assert(childCount == 0, "Open Files section has 0 children after removing the file")
}

// MARK: - File Browser Tests (WP-5)

func testFileWatcherInit() {
    section("File Browser (WP-5)")

    let watcher = FileWatcher(directory: URL(fileURLWithPath: "/tmp"))
    assert(watcher.directory.path == "/tmp", "FileWatcher initializes with correct directory")
}

func testFileWatcherListsMarkdownFiles() {
    // Create temp dir with .md and .txt files
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("macmd-test-\(ProcessInfo.processInfo.globallyUniqueString)")
    try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: tmpDir.appendingPathComponent("test.md").path, contents: nil)
    FileManager.default.createFile(atPath: tmpDir.appendingPathComponent("readme.markdown").path, contents: nil)
    FileManager.default.createFile(atPath: tmpDir.appendingPathComponent("image.png").path, contents: nil)
    FileManager.default.createFile(atPath: tmpDir.appendingPathComponent(".hidden.md").path, contents: nil)

    let watcher = FileWatcher(directory: tmpDir)
    let files = watcher.markdownFiles()
    let names = files.map { $0.lastPathComponent }.sorted()

    assert(names.contains("test.md"), "Lists .md files")
    assert(names.contains("readme.markdown"), "Lists .markdown files")
    assert(!names.contains("image.png"), "Excludes .png files")
    assert(!names.contains(".hidden.md"), "Excludes hidden files")

    // Cleanup
    try? FileManager.default.removeItem(at: tmpDir)
}

func testSidebarHasFileBrowserSection() {
    let vc = SidebarViewController()
    _ = vc.view
    let scrollView = vc.view as? NSScrollView
    let outlineView = scrollView?.documentView as? NSOutlineView
    let rootCount = outlineView?.dataSource?.outlineView?(outlineView!, numberOfChildrenOfItem: nil) ?? 0
    // Should have 2 sections: "Open Files" and "Files"
    assert(rootCount == 3, "Sidebar has 3 root sections (Open Files + Recent + Files)")
}

// MARK: - Run Workspace Tests

func runWorkspaceTests() {
    print("\n===========================================")
    print("macmd Workspace Tests (WP-2 + WP-3)")
    print("===========================================")

    // WorkspaceWindowController
    testWorkspaceWindowControllerClassExists()
    testWorkspaceWindowControllerIsNSWindowController()
    testWorkspaceContainsSplitViewController()
    testSplitViewHasTwoItems()
    testSplitViewFirstItemIsSidebar()
    testSplitViewSecondItemIsEditor()
    testSidebarItemIsSidebarType()
    testSidebarMinimumThickness()
    testSidebarMaximumThickness()
    testWindowHasResizableStyle()
    testWindowMinSize()

    // SidebarViewController
    testSidebarViewControllerClassExists()
    testSidebarViewControllerCreatesView()

    // Native Tabs (WP-3)
    testWindowTabbingModeIsPreferred()
    testWindowHasTabbingIdentifier()

    // Open Files Sidebar (WP-4)
    testSidebarHasOutlineView()
    testSidebarOutlineViewHasDataSource()
    testSidebarOutlineViewHasDelegate()
    testSidebarHasOpenFilesSection()
    testSidebarTracksOpenDocument()
    testSidebarRemovesClosedDocument()

    // File Browser (WP-5)
    testFileWatcherInit()
    testFileWatcherListsMarkdownFiles()
    testSidebarHasFileBrowserSection()
}

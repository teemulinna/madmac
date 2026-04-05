import Foundation

/// Watches a directory for file changes using FSEvents and provides
/// a list of markdown files.
final class FileWatcher {
    let directory: URL
    private var stream: FSEventStreamRef?
    var onChange: (() -> Void)?

    init(directory: URL) {
        self.directory = directory
    }

    /// Returns all markdown files in the watched directory (non-recursive, non-hidden).
    func markdownFiles() -> [URL] {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return (contents ?? []).filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "md" || ext == "markdown" || ext == "mdown" || ext == "mkd"
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Start watching the directory for changes.
    func start() {
        guard stream == nil else { return }

        let paths = [directory.path] as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async {
                watcher.onChange?()
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // 1 second latency
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    /// Stop watching.
    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}

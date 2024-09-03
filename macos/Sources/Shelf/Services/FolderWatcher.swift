import Foundation

/// Watches a folder and reports files that appear in it. Used by Rules for Downloads, Desktop
/// and any folder the user adds.
final class FolderWatcher {
    typealias Handler = ([URL]) -> Void

    let folder: URL
    private let handler: Handler
    private let queue = DispatchQueue(label: "com.shelfapp.Shelf.FolderWatcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<URL> = []

    init(folder: URL, handler: @escaping Handler) {
        self.folder = folder
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        guard source == nil else { return }
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        known = Set(contents())
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: queue)
        source.setEventHandler { [weak self] in self?.folderChanged() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func folderChanged() {
        let current = Set(contents())
        let added = current.subtracting(known)
            .filter { !isStillDownloading($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        known = current
        guard !added.isEmpty else { return }
        DispatchQueue.main.async { [handler] in handler(added) }
    }

    private func contents() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    /// Safari and iCloud write partial files first; wait for the final name.
    private func isStillDownloading(_ url: URL) -> Bool {
        ["download", "crdownload", "part", "icloud"].contains(url.pathExtension.lowercased())
    }
}

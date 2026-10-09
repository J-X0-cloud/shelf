import Foundation

/// The Dock stack is a folder of symbolic links the user drags to the Dock once. Shelf keeps it
/// mirroring the active Space. `DockStackPlan` works out the link names; `DockStackFolder`
/// writes them, only touching links that changed so Finder doesn't flicker.
public struct DockStackPlan: Equatable, Sendable {
    public struct Link: Equatable, Sendable {
        public var name: String
        public var destination: URL
    }

    public private(set) var links: [Link]

    /// Links for every file item (web links can't live in a Dock stack). Name clashes get a
    /// short prefix from the item ID, e.g. "1A2B Brief.pdf".
    public init(items: [ShelfItem]) {
        var used = Set<String>()
        var links: [Link] = []
        for item in items where item.url.isFileURL {
            var name = item.url.lastPathComponent
            if name.isEmpty { continue }
            if used.contains(name.lowercased()) {
                name = "\(item.id.uuidString.prefix(4)) \(name)"
            }
            guard used.insert(name.lowercased()).inserted else { continue }
            links.append(Link(name: name, destination: item.url))
        }
        self.links = links
    }
}

public final class DockStackFolder {
    public let folder: URL
    private let fileManager: FileManager

    public init(folder: URL, fileManager: FileManager = .default) {
        self.folder = folder
        self.fileManager = fileManager
    }

    /// Makes the folder match the plan: stale links are removed, missing or retargeted links are
    /// (re)created, and anything that isn't a symbolic link is left alone.
    public func apply(_ plan: DockStackPlan) throws {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let wanted = Dictionary(plan.links.map { ($0.name, $0.destination) }, uniquingKeysWith: { first, _ in first })

        for name in try fileManager.contentsOfDirectory(atPath: folder.path) {
            let path = folder.appendingPathComponent(name).path
            guard let target = try? fileManager.destinationOfSymbolicLink(atPath: path) else { continue }
            if let destination = wanted[name], destination.path == target { continue }
            try fileManager.removeItem(atPath: path)
        }

        for link in plan.links {
            let path = folder.appendingPathComponent(link.name).path
            if (try? fileManager.destinationOfSymbolicLink(atPath: path)) == link.destination.path { continue }
            try fileManager.createSymbolicLink(atPath: path, withDestinationPath: link.destination.path)
        }
    }

    /// The links currently in the folder, name → destination path.
    public func currentLinks() -> [String: String] {
        let names = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
        var links: [String: String] = [:]
        for name in names {
            if let target = try? fileManager.destinationOfSymbolicLink(atPath: folder.appendingPathComponent(name).path) {
                links[name] = target
            }
        }
        return links
    }
}

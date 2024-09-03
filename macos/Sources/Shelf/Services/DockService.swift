import AppKit
import ApplicationServices
import OSLog

/// Everything Shelf needs from the Dock, Finder and accessibility APIs, behind a protocol so the
/// store can be tested without touching the real system.
protocol DockServicing {
    /// Whether Shelf has Accessibility permission (needed for global shortcuts).
    var isAccessibilityTrusted: Bool { get }
    /// Shows the system prompt that sends the user to Privacy & Security → Accessibility.
    func requestAccessibilityAccess()
    /// Rebuilds the Dock stack folder so it mirrors the current Space's shelves.
    func syncDockStack(with items: [ShelfItem]) throws
    func open(_ item: ShelfItem)
    func revealInFinder(_ items: [ShelfItem])
    func icon(for item: ShelfItem) -> NSImage
    /// Whether the frontmost app is in full screen, in which case shelves slide out of sight.
    var isFrontmostAppFullScreen: Bool { get }
}

/// Production implementation backed by NSWorkspace and the Accessibility API.
final class WorkspaceDockService: DockServicing {
    private let workspace: NSWorkspace
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.shelfapp.Shelf", category: "Dock")

    /// The folder the user drags to the Dock once. Shelf keeps its contents in sync.
    let stackFolder: URL

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        stackFolder = support.appendingPathComponent("Shelf/Dock Stack", isDirectory: true)
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func syncDockStack(with items: [ShelfItem]) throws {
        try fileManager.createDirectory(at: stackFolder, withIntermediateDirectories: true)

        let existing = try fileManager.contentsOfDirectory(at: stackFolder, includingPropertiesForKeys: nil)
        for link in existing {
            try fileManager.removeItem(at: link)
        }

        var usedNames = Set<String>()
        for item in items where item.url.isFileURL {
            var name = item.url.lastPathComponent
            if usedNames.contains(name) { name = "\(item.id.uuidString.prefix(4)) \(name)" }
            usedNames.insert(name)
            try fileManager.createSymbolicLink(at: stackFolder.appendingPathComponent(name), withDestinationURL: item.url)
        }
        logger.debug("Dock stack synced with \(items.count) items")
    }

    func open(_ item: ShelfItem) {
        workspace.open(item.url)
    }

    func revealInFinder(_ items: [ShelfItem]) {
        workspace.activateFileViewerSelecting(items.filter { $0.url.isFileURL }.map(\.url))
    }

    func icon(for item: ShelfItem) -> NSImage {
        switch item.kind {
        case .link:
            NSImage(systemSymbolName: "link", accessibilityDescription: item.name) ?? NSImage()
        case .file, .folder, .app:
            workspace.icon(forFile: item.url.path)
        }
    }

    var isFrontmostAppFullScreen: Bool {
        guard isAccessibilityTrusted, let app = workspace.frontmostApplication else { return false }
        let element = AXUIElementCreateApplication(app.processIdentifier)

        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window
        else { return false }

        var fullScreen: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            "AXFullScreen" as CFString,
            &fullScreen
        )
        return result == .success && (fullScreen as? Bool) == true
    }
}

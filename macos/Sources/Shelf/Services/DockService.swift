import AppKit
import ApplicationServices
import OSLog
import ShelfKit

/// Everything Shelf needs from the Dock, Finder and accessibility APIs, behind a protocol so the
/// store can be tested without touching the real system. The Dock stack and opening items come
/// from ShelfKit's `WorkspaceServicing`; the rest is AppKit-only.
protocol DockServicing: WorkspaceServicing {
    /// Whether Shelf has Accessibility permission (needed for global shortcuts).
    var isAccessibilityTrusted: Bool { get }
    /// Shows the system prompt that sends the user to Privacy & Security → Accessibility.
    func requestAccessibilityAccess()
    func revealInFinder(_ items: [ShelfItem])
    func icon(for item: ShelfItem) -> NSImage
    /// Whether the frontmost app is in full screen, in which case shelves slide out of sight.
    var isFrontmostAppFullScreen: Bool { get }
}

/// Production implementation backed by NSWorkspace and the Accessibility API.
final class WorkspaceDockService: DockServicing {
    private let workspace: NSWorkspace
    private let logger = Logger(subsystem: "com.shelfapp.Shelf", category: "Dock")

    /// The folder the user drags to the Dock once. Shelf keeps its contents in sync.
    let stack: DockStackFolder

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        stack = DockStackFolder(
            folder: support.appendingPathComponent("Shelf/Dock Stack", isDirectory: true),
            fileManager: fileManager
        )
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func syncDockStack(with items: [ShelfItem]) throws {
        let plan = DockStackPlan(items: items)
        try stack.apply(plan)
        logger.debug("Dock stack synced with \(plan.links.count) links")
    }

    func open(_ item: ShelfItem) {
        withResolvedURL(for: item) { _ = workspace.open($0) }
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
              let window,
              CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return false }

        var fullScreen: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window as! AXUIElement, // swiftlint:disable:this force_cast (type checked above)
            "AXFullScreen" as CFString,
            &fullScreen
        )
        return result == .success && (fullScreen as? Bool) == true
    }

    /// Resolves the item's security-scoped bookmark (so it follows a moved file) and keeps access
    /// open for as long as `body` runs.
    private func withResolvedURL(for item: ShelfItem, _ body: (URL) -> Void) {
        guard item.url.isFileURL, let bookmark = item.bookmark else {
            body(item.url)
            return
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            body(item.url)
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        body(url)
    }
}

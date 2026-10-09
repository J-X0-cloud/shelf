import AppKit
import Combine
import ShelfKit
import SwiftUI

/// Hosts each shelf of the active Space in its own non-activating floating panel.
@MainActor
final class ShelfPanelController {
    private static let panelSize = NSSize(width: 380, height: 260)
    private static let margin: CGFloat = 24

    private let store: ShelfStore
    private var panels: [Shelf.ID: NSPanel] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(store: ShelfStore) {
        self.store = store

        // Rebuild when the Space changes or a shelf is added to or removed from it.
        store.$library
            .map { $0.activeSpace.shelves.map(\.id) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.showActiveSpace() }
            .store(in: &cancellables)

        store.$shelvesHidden
            .removeDuplicates()
            .sink { [weak self] hidden in self?.setHidden(hidden) }
            .store(in: &cancellables)
    }

    func showActiveSpace() {
        let shelves = store.activeSpace.shelves
        let visibleIDs = Set(shelves.map(\.id))

        for (id, panel) in panels where !visibleIDs.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
        }

        for (index, shelf) in shelves.enumerated() where panels[shelf.id] == nil {
            let panel = makePanel(for: shelf, index: index)
            panels[shelf.id] = panel
            if !store.shelvesHidden { panel.orderFrontRegardless() }
        }
    }

    func closeAll() {
        panels.values.forEach { $0.close() }
        panels.removeAll()
    }

    private func setHidden(_ hidden: Bool) {
        for panel in panels.values {
            if hidden {
                panel.orderOut(nil)
            } else {
                panel.orderFrontRegardless()
            }
        }
    }

    private func makePanel(for shelf: Shelf, index: Int) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: true
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        _ = panel.setFrameAutosaveName("Shelf-\(shelf.id.uuidString)")
        panel.contentView = NSHostingView(rootView: ShelfPanel(shelfID: shelf.id).environmentObject(store))

        // A remembered frame (which also remembers the display) wins; otherwise place the panel
        // by its pinned edge on the main display.
        if !panel.setFrameUsingName("Shelf-\(shelf.id.uuidString)"), let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(origin(for: shelf.placement, index: index, in: screen))
        }
        return panel
    }

    private func origin(for placement: Shelf.Placement, index: Int, in screen: NSRect) -> NSPoint {
        let size = Self.panelSize
        let margin = Self.margin
        let step = CGFloat(index) * (size.height + 16)
        switch placement {
        case .floating, .leading:
            return NSPoint(x: screen.minX + margin, y: screen.maxY - margin - size.height - step)
        case .trailing:
            return NSPoint(x: screen.maxX - margin - size.width, y: screen.maxY - margin - size.height - step)
        case .top:
            return NSPoint(x: screen.midX - size.width / 2 + CGFloat(index) * (size.width + 16), y: screen.maxY - margin - size.height)
        case .bottom:
            return NSPoint(x: screen.midX - size.width / 2 + CGFloat(index) * (size.width + 16), y: screen.minY + margin)
        }
    }
}

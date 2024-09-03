import AppKit
import Combine
import SwiftUI

/// Hosts each shelf of the active Space in its own non-activating floating panel.
@MainActor
final class ShelfPanelController {
    private let store: ShelfStore
    private var panels: [Shelf.ID: NSPanel] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(store: ShelfStore) {
        self.store = store

        store.$layout
            .map(\.activeSpaceID)
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
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
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
        panel.contentView = NSHostingView(rootView: ShelfPanel(shelfID: shelf.id).environmentObject(store))

        if let screen = NSScreen.main?.visibleFrame {
            let origin = NSPoint(x: screen.minX + 24, y: screen.maxY - 24 - CGFloat(index + 1) * 280)
            panel.setFrameOrigin(origin)
        }
        return panel
    }
}

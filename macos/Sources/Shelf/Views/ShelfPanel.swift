import AppKit
import SwiftUI

/// A glass shelf: header with colour dot and count, then a grid of items. Accepts dropped files and links.
struct ShelfPanel: View {
    let shelfID: Shelf.ID
    @EnvironmentObject private var store: ShelfStore
    @State private var isTargeted = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var shelf: Shelf? {
        guard let location = store.layout.location(ofShelf: shelfID) else { return nil }
        return store.layout.spaces[location.space].shelves[location.shelf]
    }

    var body: some View {
        if let shelf {
            VStack(alignment: .leading, spacing: 12) {
                header(for: shelf)
                if shelf.items.isEmpty {
                    Text("Drop files, folders, apps or links here")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                        ForEach(shelf.items) { item in
                            ItemTile(item: item)
                                .onTapGesture(count: 2) { store.markOpened(item, onShelf: shelf.id) }
                                .draggable(item.url)
                                .contextMenu {
                                    Button("Remove from Shelf", role: .destructive) {
                                        store.removeItem(item.id, fromShelf: shelf.id)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isTargeted ? Color(hex: shelf.colorHex) : .white.opacity(0.6), lineWidth: isTargeted ? 2 : 1)
            }
            .dropDestination(for: URL.self) { urls, _ in
                store.add(urls, toShelf: shelf.id) > 0
            } isTargeted: { isTargeted = $0 }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(shelf.name) shelf, \(shelf.items.count) items")
        }
    }

    private func header(for shelf: Shelf) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: shelf.colorHex))
                .frame(width: 9, height: 9)
                .padding(3)
                .background(Circle().fill(Color(hex: shelf.colorHex).opacity(0.22)))
            Text(shelf.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text("\(shelf.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .background(Capsule().fill(.primary.opacity(0.07)))
            Spacer()
        }
    }
}

struct ItemTile: View {
    let item: ShelfItem

    var body: some View {
        VStack(spacing: 6) {
            icon
                .frame(width: 44, height: 44)
            Text(item.name)
                .font(.system(size: 10.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 76)
        }
        .help(item.url.isFileURL ? item.url.path : item.url.absoluteString)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.kind {
        case .link:
            Image(systemName: "link")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
        case .file, .folder, .app:
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

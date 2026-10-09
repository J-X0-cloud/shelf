import AppKit
import ShelfKit
import SwiftUI

/// A glass shelf: header with colour dot and count, then a grid of items. Accepts dropped files
/// and links; tiles dragged from another shelf in the Space move rather than duplicate.
struct ShelfPanel: View {
    let shelfID: Shelf.ID
    @EnvironmentObject private var store: ShelfStore
    @State private var isTargeted = false
    @State private var gridWidth: CGFloat = 352

    private static let columnCount = 4
    private static let spacing: CGFloat = 12
    private static let tileHeight: CGFloat = 70

    private let columns = Array(repeating: GridItem(.flexible(), spacing: ShelfPanel.spacing), count: ShelfPanel.columnCount)

    private var metrics: ShelfGridMetrics {
        let tileWidth = (gridWidth - Self.spacing * CGFloat(Self.columnCount - 1)) / CGFloat(Self.columnCount)
        return ShelfGridMetrics(
            columns: Self.columnCount,
            tileWidth: Double(max(tileWidth, 1)),
            tileHeight: Double(Self.tileHeight),
            spacing: Double(Self.spacing)
        )
    }

    var body: some View {
        if let shelf = store.shelf(id: shelfID) {
            VStack(alignment: .leading, spacing: 12) {
                ShelfHeader(shelf: shelf)
                if shelf.items.isEmpty {
                    Text("Drop files, folders, apps or links here")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .dropDestination(for: URL.self) { urls, _ in
                            drop(urls, onto: shelf, at: nil)
                        } isTargeted: { isTargeted = $0 }
                } else {
                    grid(for: shelf)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color(hex: shelf.colorHex) : Color.white.opacity(0.6),
                        lineWidth: isTargeted ? 2 : 1
                    )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(shelf.name) shelf, \(shelf.itemCountDescription)")
        }
    }

    private func grid(for shelf: Shelf) -> some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: Self.spacing) {
            ForEach(shelf.sortedItems) { item in
                ItemTile(item: item)
                    .frame(height: Self.tileHeight)
                    .onTapGesture(count: 2) { store.open(item, onShelf: shelf.id) }
                    .draggable(item.url)
                    .contextMenu {
                        Button("Open") { store.open(item, onShelf: shelf.id) }
                        if item.url.isFileURL {
                            Button("Show in Finder") { store.revealInFinder([item]) }
                        }
                        Divider()
                        Button("Remove from Shelf", role: .destructive) {
                            store.removeItem(item.id, fromShelf: shelf.id)
                        }
                    }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: GridWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(GridWidthKey.self) { gridWidth = $0 }
        .dropDestination(for: URL.self) { urls, location in
            // Positions only make sense when the shelf shows items in the order they're stored.
            let index = shelf.sortOrder == .manual
                ? metrics.insertionIndex(x: Double(location.x), y: Double(location.y), itemCount: shelf.items.count)
                : nil
            return drop(urls, onto: shelf, at: index)
        } isTargeted: { isTargeted = $0 }
    }

    /// Unwraps dropped `.webloc` / `.url` bookmark files into links, then lets the store decide
    /// between moving and adding. Holding ⌥ copies, as in Finder.
    private func drop(_ urls: [URL], onto shelf: Shelf, at index: Int?) -> Bool {
        var payload = DropPayload()
        for url in urls {
            if url.isFileURL,
               ["webloc", "url"].contains(url.pathExtension.lowercased()),
               let data = try? Data(contentsOf: url),
               let link = DropPayload.bookmarkTarget(fileName: url.lastPathComponent, contents: data) {
                payload.append(link)
            } else {
                payload.append(url)
            }
        }
        let copying = NSEvent.modifierFlags.contains(.option)
        return store.drop(payload, onShelf: shelf.id, at: index, copying: copying)
    }
}

private struct GridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 352

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Colour dot, name and count, with the shelf's options behind the ••• button.
private struct ShelfHeader: View {
    let shelf: Shelf
    @EnvironmentObject private var store: ShelfStore

    var body: some View {
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
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            Spacer()
            Menu {
                Picker("Sort By", selection: binding(\.sortOrder)) {
                    Text("Manual").tag(Shelf.SortOrder.manual)
                    Text("Name").tag(Shelf.SortOrder.name)
                    Text("Date Added").tag(Shelf.SortOrder.dateAdded)
                    Text("Last Used").tag(Shelf.SortOrder.lastUsed)
                    Text("Kind").tag(Shelf.SortOrder.kind)
                }
                Picker("Position", selection: binding(\.placement)) {
                    Text("Floating").tag(Shelf.Placement.floating)
                    Text("Left Edge").tag(Shelf.Placement.leading)
                    Text("Right Edge").tag(Shelf.Placement.trailing)
                    Text("Top Edge").tag(Shelf.Placement.top)
                    Text("Bottom Edge").tag(Shelf.Placement.bottom)
                }
                Toggle("Auto-hide at Edge", isOn: binding(\.autoHide))
                    .disabled(!shelf.placement.isPinned)
                Divider()
                Button("Delete Shelf", role: .destructive) { store.deleteShelf(shelf.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Shelf options")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Shelf, Value>) -> Binding<Value> {
        Binding(
            get: { shelf[keyPath: keyPath] },
            set: { newValue in store.updateShelf(shelf.id) { $0[keyPath: keyPath] = newValue } }
        )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint("Double-click to open")
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

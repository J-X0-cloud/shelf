import AppKit
import SwiftUI

/// The menu-bar popover: search, Spaces with ⌘1–9, quick actions and Settings.
struct SpacesMenu: View {
    @EnvironmentObject private var store: ShelfStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            searchField

            if store.searchText.isEmpty {
                sectionLabel("Spaces")
                ForEach(Array(store.spaces.enumerated()), id: \.element.id) { index, space in
                    SpaceRow(space: space, shortcut: index < 9 ? "⌘\(index + 1)" : nil, isActive: space.id == store.activeSpace.id)
                        .onTapGesture { store.switchToSpace(id: space.id) }
                }
            } else {
                searchResults
            }

            Divider().padding(.vertical, 4)

            MenuRow(title: "New shelf", shortcut: "⌥⌘N") {
                store.addShelf(named: "New shelf", colorHex: store.activeSpace.colorHex)
            }
            MenuRow(title: "Stash selection", shortcut: "⇧⌘S") {
                store.stash(FinderSelection.current())
            }
            MenuRow(title: store.shelvesHidden ? "Show all shelves" : "Hide all shelves", shortcut: "⌥⌘H") {
                store.toggleShelvesHidden()
            }
            if store.canUndoAutomaticMove, let move = store.lastAutomaticMove {
                MenuRow(title: "Undo “\(move.item.name)”", shortcut: "⌘Z") {
                    store.undoLastAutomaticMove()
                }
            }

            Divider().padding(.vertical, 4)

            settingsRow
        }
        .padding(8)
        .frame(width: 300)
        .background(hiddenShortcuts)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search shelves and files", text: $store.searchText)
                .textFieldStyle(.plain)
            Text("⌘K").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.06)))
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = store.searchResults
        if results.isEmpty {
            Text("No matches").font(.callout).foregroundStyle(.secondary).padding(8)
        } else {
            ForEach(results) { result in
                MenuRow(title: result.item.name, detail: "\(result.shelf.name) · \(result.space.name)") {
                    store.markOpened(result.item, onShelf: result.shelf.id)
                }
            }
        }
    }

    @ViewBuilder
    private var settingsRow: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                MenuRowLabel(title: "Settings…", shortcut: "⌘,")
            }
            .buttonStyle(.plain)
        } else {
            MenuRow(title: "Settings…", shortcut: "⌘,") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    /// Invisible buttons that give ⌘1–9 a keyboard shortcut while the popover is open.
    private var hiddenShortcuts: some View {
        ZStack {
            ForEach(1 ... 9, id: \.self) { index in
                Button("") { store.switchToSpace(shortcut: index) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}

private struct SpaceRow: View {
    let space: Space
    let shortcut: String?
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: space.colorHex))
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(space.name).font(.system(size: 13, weight: .semibold))
                Text(space.shelfCountDescription).font(.caption).opacity(0.75)
            }
            Spacer()
            if let shortcut {
                Text(shortcut).font(.caption).opacity(0.75)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background(RoundedRectangle(cornerRadius: 7).fill(isActive ? Color.accentColor : .clear))
        .contentShape(Rectangle())
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

private struct MenuRow: View {
    let title: String
    var detail: String?
    var shortcut: String?
    let action: () -> Void

    init(title: String, detail: String? = nil, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            MenuRowLabel(title: title, detail: detail, shortcut: shortcut)
        }
        .buttonStyle(.plain)
    }
}

private struct MenuRowLabel: View {
    let title: String
    var detail: String?
    var shortcut: String?

    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).lineLimit(1)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let shortcut {
                Text(shortcut).font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? Color.primary.opacity(0.08) : .clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

/// Reads the current Finder selection through Apple Events.
enum FinderSelection {
    static func current() -> [URL] {
        let source = """
        tell application "Finder"
            set output to ""
            repeat with anItem in (get selection)
                set output to output & POSIX path of (anItem as alias) & linefeed
            end repeat
            return output
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else { return [] }
        return result
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
    }
}

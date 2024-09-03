import SwiftUI

/// Settings → Rules: plain-language rules, each with its own switch, plus an editor with a live preview.
struct RulesSettings: View {
    @EnvironmentObject private var store: ShelfStore
    @State private var isAddingRule = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rules").font(.title2.weight(.bold))
                    Text("Shelf watches the folders you choose and files new items onto the right shelf.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isAddingRule = true
                } label: {
                    Label("Add rule", systemImage: "plus")
                }
            }

            Toggle(isOn: Binding(
                get: { store.layout.runsRulesAutomatically },
                set: { store.setRunsRulesAutomatically($0) }
            )) {
                Text("Run rules automatically").fontWeight(.medium)
            }
            .toggleStyle(.switch)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.background))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.rules) { rule in
                        RuleRow(rule: rule)
                    }
                }
            }

            Text("Rules run on this Mac only. Nothing is uploaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $isAddingRule) {
            RuleEditor { store.addRule($0) }
        }
    }
}

private struct RuleRow: View {
    let rule: Rule
    @EnvironmentObject private var store: ShelfStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { store.setRule(rule.id, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Chip { Text("When a file in ") + Text(rule.source.displayName).bold() }
                    Chip { Text(rule.condition.displayText) }
                }
                HStack(spacing: 6) {
                    Text("→ put it on")
                    Text(store.shelfName(id: rule.destinationShelfID) ?? "a deleted shelf")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if let space = store.spaceName(id: rule.spaceID) {
                        Text("in \(space)")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background))
        .contextMenu {
            Button("Delete Rule", role: .destructive) { store.deleteRule(rule.id) }
        }
    }
}

private struct Chip<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
    }
}

/// Builds a rule and shows what it would catch before it's saved.
struct RuleEditor: View {
    enum SourceChoice: String, CaseIterable, Identifiable {
        case downloads = "Downloads"
        case desktop = "Desktop"
        case anyShelf = "Any shelf"

        var id: String { rawValue }

        var source: Rule.Source {
            switch self {
            case .downloads: .downloads
            case .desktop: .desktop
            case .anyShelf: .anyShelf
            }
        }
    }

    enum ConditionChoice: String, CaseIterable, Identifiable {
        case fileExtension = "Name ends with"
        case nameContains = "Name contains"
        case screenshot = "Is a screenshot"
        case untouched = "Untouched for"

        var id: String { rawValue }
    }

    let onSave: (Rule) -> Void

    @EnvironmentObject private var store: ShelfStore
    @Environment(\.dismiss) private var dismiss

    @State private var source = SourceChoice.downloads
    @State private var conditionChoice = ConditionChoice.fileExtension
    @State private var text = "pdf"
    @State private var days = 30
    @State private var shelfID: Shelf.ID?
    @State private var appliesToActiveSpaceOnly = true

    private struct ShelfChoice: Identifiable {
        let space: Space
        let shelf: Shelf
        var id: Shelf.ID { shelf.id }
    }

    private var allShelves: [ShelfChoice] {
        store.spaces.flatMap { space in space.shelves.map { ShelfChoice(space: space, shelf: $0) } }
    }

    private var condition: Rule.Condition {
        switch conditionChoice {
        case .fileExtension: .extensionIs(text)
        case .nameContains: .nameContains(text)
        case .screenshot: .isScreenshot
        case .untouched: .untouched(days: days)
        }
    }

    private var draft: Rule? {
        guard let shelfID else { return nil }
        return Rule(
            source: source.source,
            condition: condition,
            destinationShelfID: shelfID,
            spaceID: appliesToActiveSpaceOnly ? store.activeSpace.id : nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New rule").font(.title3.weight(.bold))
            Form {
                Picker("When a file in", selection: $source) {
                    ForEach(SourceChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Condition", selection: $conditionChoice) {
                    ForEach(ConditionChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                switch conditionChoice {
                case .fileExtension, .nameContains:
                    TextField("Text", text: $text)
                case .untouched:
                    Stepper("\(days) days", value: $days, in: 1 ... 365)
                case .screenshot:
                    EmptyView()
                }
                Picker("Put it on", selection: $shelfID) {
                    Text("Choose a shelf").tag(Shelf.ID?.none)
                    ForEach(allShelves) { entry in
                        Text("\(entry.shelf.name) — \(entry.space.name)").tag(Shelf.ID?.some(entry.shelf.id))
                    }
                }
                Toggle("Only in \(store.activeSpace.name)", isOn: $appliesToActiveSpaceOnly)
            }

            if let draft {
                let matches = store.preview(draft)
                Text(matches.isEmpty ? "Nothing matches right now." : "Would catch \(matches.count) file\(matches.count == 1 ? "" : "s"): \(matches.prefix(3).map(\.fileName).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add Rule") {
                    if let draft { onSave(draft) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft == nil)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

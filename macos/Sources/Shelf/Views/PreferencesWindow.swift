import AppKit
import ServiceManagement
import ShelfKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings window. Each pane is a tab; Rules is the one people spend the most time in.
struct PreferencesWindow: View {
    private enum Pane: String, CaseIterable, Identifiable {
        case general = "General"
        case spaces = "Spaces"
        case rules = "Rules"
        case license = "License"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .spaces: "square.grid.2x2"
            case .rules: "wand.and.stars"
            case .license: "key"
            }
        }
    }

    @AppStorage("preferences.selectedPane") private var selection = Pane.rules.rawValue

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Pane.allCases) { pane in
                paneView(pane)
                    .tabItem { Label(pane.rawValue, systemImage: pane.symbol) }
                    .tag(pane.rawValue)
            }
        }
        .frame(width: 620, height: 480)
    }

    @ViewBuilder
    private func paneView(_ pane: Pane) -> some View {
        switch pane {
        case .general: GeneralSettings()
        case .spaces: SpacesSettings()
        case .rules: RulesSettings()
        case .license: LicenseSettings()
        }
    }
}

private extension UTType {
    /// `.shelfspace` layout files. Declared as JSON-conforming so Finder previews them as text.
    static let shelfspace = UTType(filenameExtension: LayoutCoder.fileExtension, conformingTo: .json) ?? .json
}

struct GeneralSettings: View {
    @EnvironmentObject private var store: ShelfStore
    @EnvironmentObject private var updates: UpdateController
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch Shelf at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: setLaunchAtLogin
                ))
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.automaticallyChecksForUpdates = $0 }
                ))
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
            Section("Layout") {
                HStack {
                    Button("Export Layout…", action: exportLayout)
                    Button("Import Layout…", action: importLayout)
                    Button("Add Spaces from Template…", action: importTemplate)
                }
                Text("A .shelfspace file holds your Spaces, shelves and Rules. Files themselves are never included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = message ?? store.lastError {
                    HStack {
                        Text(message).font(.caption).foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") {
                            self.message = nil
                            store.clearError()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            message = "Couldn't change the login item: \(error.localizedDescription)"
        }
    }

    private func exportLayout() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "My Layout.\(LayoutCoder.fileExtension)"
        panel.allowedContentTypes = [.shelfspace]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportLayout(to: url)
            message = nil
        } catch {
            message = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func importLayout() {
        guard let url = chooseLayoutFile() else { return }
        do {
            try store.importLayout(from: url)
            message = nil
        } catch {
            message = (error as? LayoutError)?.description ?? "That file isn't a Shelf layout."
        }
    }

    private func importTemplate() {
        guard let url = chooseLayoutFile() else { return }
        do {
            try store.importSpaces(from: url)
            message = nil
        } catch {
            message = (error as? LayoutError)?.description ?? "That file isn't a Shelf layout."
        }
    }

    private func chooseLayoutFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.shelfspace, .json]
        return panel.runModal() == .OK ? panel.url : nil
    }
}

struct SpacesSettings: View {
    @EnvironmentObject private var store: ShelfStore
    @State private var newName = ""
    @State private var renaming: Space.ID?
    @State private var draftName = ""

    var body: some View {
        Form {
            Section("Spaces") {
                List {
                    ForEach(store.spaces) { space in
                        row(for: space)
                    }
                    .onMove { store.moveSpaces(fromOffsets: $0, toOffset: $1) }
                }
                .frame(minHeight: 180)
                Text("Drag to reorder. The first nine Spaces switch with ⌘1–9.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    TextField("New Space name", text: $newName)
                        .onSubmit(addSpace)
                    Button("Add Space", action: addSpace)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func row(for space: Space) -> some View {
        HStack {
            Circle().fill(Color(hex: space.colorHex)).frame(width: 10, height: 10)
            if renaming == space.id {
                TextField("Name", text: $draftName)
                    .onSubmit {
                        store.renameSpace(space.id, to: draftName)
                        renaming = nil
                    }
            } else {
                Text(space.name)
            }
            Spacer()
            Text(space.shelfCountDescription).foregroundStyle(.secondary)
            if let shortcut = store.library.shortcutLabel(forSpace: space.id) {
                Text(shortcut).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button("Rename…") {
                draftName = space.name
                renaming = space.id
            }
            Button("Delete Space", role: .destructive) { store.deleteSpace(space.id) }
                .disabled(store.spaces.count == 1)
        }
    }

    private func addSpace() {
        guard store.addSpace(named: newName) != nil else { return }
        newName = ""
    }
}

struct LicenseSettings: View {
    @EnvironmentObject private var license: LicenseClient
    @State private var draftKey = ""
    @State private var recoveryEmail = ""

    var body: some View {
        Form {
            Section("License") {
                switch license.state {
                case let .active(key, details):
                    LabeledContent("Key", value: key.masked)
                    if let details {
                        LabeledContent("License", value: details.tier.displayName)
                        LabeledContent("Activations", value: details.seatsDescription)
                    }
                    Button("Deactivate on This Mac", role: .destructive) {
                        Task { await license.deactivate() }
                    }
                case .working:
                    ProgressView().controlSize(.small)
                case .unlicensed, .failed:
                    TextField("License key", text: $draftKey)
                        .font(.body.monospaced())
                        .onSubmit(activate)
                    if case let .failed(message) = license.state {
                        Text(message).font(.caption).foregroundStyle(.red)
                    }
                    Button("Activate", action: activate)
                        .disabled(LicenseKey(draftKey) == nil)
                    Link("Buy Shelf — $19", destination: LicenseClient.baseURL.appendingPathComponent("pricing"))
                }
            }
            Section("Lost your key?") {
                HStack {
                    TextField("Purchase email", text: $recoveryEmail)
                    Button("Send Keys") {
                        Task { await license.recover(email: recoveryEmail) }
                    }
                    .disabled(recoveryEmail.isEmpty)
                }
                Text(license.recoveryMessage ?? "We'll email every key bought with that address.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func activate() {
        let key = draftKey
        Task { await license.activate(key) }
    }
}

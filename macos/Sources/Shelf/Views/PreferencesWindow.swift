import AppKit
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

struct GeneralSettings: View {
    @EnvironmentObject private var store: ShelfStore
    @EnvironmentObject private var updates: UpdateController
    @AppStorage("general.launchAtLogin") private var launchAtLogin = true
    @State private var exportError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch Shelf at login", isOn: $launchAtLogin)
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
                }
                Text("A .shelfspace file holds your Spaces, shelves and Rules. Files themselves are never included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let exportError {
                    Text(exportError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportLayout() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "My Layout.shelfspace"
        panel.allowedContentTypes = [UTType(filenameExtension: "shelfspace") ?? .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportLayout(to: url)
            exportError = nil
        } catch {
            exportError = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func importLayout() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "shelfspace") ?? .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.importLayout(from: url)
            exportError = nil
        } catch {
            exportError = "That file isn't a Shelf layout."
        }
    }
}

struct SpacesSettings: View {
    @EnvironmentObject private var store: ShelfStore
    @State private var newName = ""

    var body: some View {
        Form {
            Section("Spaces") {
                ForEach(Array(store.spaces.enumerated()), id: \.element.id) { index, space in
                    HStack {
                        Circle().fill(Color(hex: space.colorHex)).frame(width: 10, height: 10)
                        Text(space.name)
                        Spacer()
                        Text(space.shelfCountDescription).foregroundStyle(.secondary)
                        if index < 9 {
                            Text("⌘\(index + 1)").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                HStack {
                    TextField("New Space name", text: $newName)
                    Button("Add Space") {
                        let colour = ShelfPalette.choices[store.spaces.count % ShelfPalette.choices.count]
                        store.addSpace(named: newName, colorHex: colour)
                        newName = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct LicenseSettings: View {
    @AppStorage("license.key") private var licenseKey = ""
    @State private var draftKey = ""

    var body: some View {
        Form {
            Section("License") {
                if licenseKey.isEmpty {
                    TextField("License key", text: $draftKey)
                        .font(.body.monospaced())
                    Button("Activate") { licenseKey = draftKey.trimmingCharacters(in: .whitespaces).uppercased() }
                        .disabled(draftKey.count < 8)
                    Link("Buy Shelf — $19", destination: URL(string: "https://shelfapp.com/pricing")!)
                } else {
                    LabeledContent("Key", value: licenseKey)
                    Button("Deactivate on This Mac", role: .destructive) { licenseKey = "" }
                }
            }
            Section("Lost your key?") {
                Text("Enter your purchase email at shelfapp.com/support and we'll resend it right away.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

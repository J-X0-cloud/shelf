import AppKit
import SwiftUI

@main
struct ShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SpacesMenu()
                .environmentObject(appDelegate.store)
        } label: {
            Image(systemName: "tray.2.fill")
                .accessibilityLabel("Shelf")
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesWindow()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.updates)
        }
    }
}

/// Owns the long-lived objects and the AppKit side of the lifecycle: no Dock icon,
/// floating shelf panels, folder watchers for Rules, and Sparkle updates.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ShelfStore.live()
    let updates = UpdateController()
    private var panels: ShelfPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panels = ShelfPanelController(store: store)
        panels?.showActiveSpace()
        store.startWatching()
        updates.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopWatching()
        panels?.closeAll()
    }
}

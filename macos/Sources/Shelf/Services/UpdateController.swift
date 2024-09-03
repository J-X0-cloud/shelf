import Foundation
import Sparkle

/// Wraps Sparkle. Update checks send only the app version, and can be turned off in General.
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let feedURL = "https://shelfapp.com/appcast.xml"

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    func start() {
        _ = controller
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        UpdateController.feedURL
    }
}

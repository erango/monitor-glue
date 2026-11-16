import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed is `appcast.xml` attached to the latest GitHub release,
/// and every update must carry an EdDSA signature matching `SUPublicEDKey` in Info.plist, so
/// nobody but the release key's owner can push an update to users.
///
/// Sparkle asks the user on the second launch whether to check automatically; nothing is
/// checked before they answer, and no system profile is sent.
final class Updater: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = Updater()

    /// Version string of an update found by a background check and not yet looked at. Drives
    /// the red dot on the menu-bar icon and the "Update to …" item at the top of the menu.
    @Published private(set) var availableVersion: String?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

    func start() { _ = controller }

    /// Whether Sparkle checks on its own schedule. Sparkle asks on the second launch; this is
    /// the way to change the answer later, so "you can turn it off" is actually true.
    var automaticallyChecks: Bool {
        get {
            #if DEBUG
            // The preview harness runs an unbundled binary, where starting Sparkle only shows
            // an error alert.
            if DebugPreview.requested != nil { return true }
            #endif
            return controller.updater.automaticallyChecksForUpdates
        }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    // Gentle reminders. A menu-bar app has no Dock icon or main window, so an update alert
    // that pops up on its own appears behind whatever the user is doing, at a random moment.
    // Instead, an update found by a background check marks the menu-bar icon with a red dot
    // and adds an item to the menu; Sparkle shows its window when the user picks that item.
    // Right after launch the user is already looking at the app, so Sparkle shows it then.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                              andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        if handleShowingUpdate {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            availableVersion = update.displayVersionString
        }
    }

    /// The user has seen the update (installed it, skipped it, or asked to be reminded later):
    /// drop the dot. A later background check brings it back if the update is still pending.
    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }

    #if DEBUG
    func _setPreviewAvailable(_ version: String?) { availableVersion = version }
    #endif
}

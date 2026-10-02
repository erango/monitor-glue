import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed is `appcast.xml` attached to the latest GitHub release,
/// and every update must carry an EdDSA signature matching `SUPublicEDKey` in Info.plist, so
/// nobody but the release key's owner can push an update to users.
///
/// Sparkle asks the user on the second launch whether to check automatically; nothing is
/// checked before they answer, and no system profile is sent.
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    static let shared = Updater()

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

    func start() { _ = controller }

    /// Whether Sparkle checks on its own schedule. Sparkle asks on the second launch; this is
    /// the way to change the answer later, so "you can turn it off" is actually true.
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    // A menu-bar app has no Dock icon or main window, so a scheduled update alert could appear
    // behind whatever the user is working in. Opting into "gentle reminders" and bringing the
    // app forward when Sparkle shows an update keeps the alert visible without stealing focus
    // at a random moment for checks the user didn't start.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        if handleShowingUpdate { NSApp.activate(ignoringOtherApps: true) }
    }
}

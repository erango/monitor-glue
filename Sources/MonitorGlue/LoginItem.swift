import Foundation
import ServiceManagement

/// Wraps the "launch at login" state via `SMAppService.mainApp` (macOS 13+).
/// Registering adds Monitor Glue to the user's Login Items; unregistering removes it.
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isEnabled: Bool = LoginItem.registered()

    /// True when the app is registered to launch at login — including `.requiresApproval`
    /// (registered but awaiting the user's approval in System Settings). Treating that as
    /// "on" keeps the checkbox consistent with macOS, which already nags to run at startup.
    private static func registered() -> Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: return false
        }
    }

    func refresh() {
        let enabled = LoginItem.registered()
        if enabled != isEnabled { isEnabled = enabled }
    }

    /// Turn launch-at-login on or off. No-op if already in the requested state.
    func setEnabled(_ on: Bool) {
        let alreadyOn = LoginItem.registered()
        do {
            if on, !alreadyOn {
                try SMAppService.mainApp.register()
            } else if !on, alreadyOn {
                // Unregisters whether the item is .enabled or pending .requiresApproval.
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MonitorGlue: failed to \(on ? "enable" : "disable") launch at login: \(error)")
        }
        refresh()
    }
}

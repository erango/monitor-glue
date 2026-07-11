import Foundation
import ServiceManagement

/// Wraps the "launch at login" state via `SMAppService.mainApp` (macOS 13+).
/// Registering adds Monitor Glue to the user's Login Items; unregistering removes it.
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isEnabled: Bool = SMAppService.mainApp.status == .enabled

    func refresh() {
        let enabled = SMAppService.mainApp.status == .enabled
        if enabled != isEnabled { isEnabled = enabled }
    }

    /// Turn launch-at-login on or off. No-op if already in the requested state.
    func setEnabled(_ on: Bool) {
        do {
            let status = SMAppService.mainApp.status
            if on, status != .enabled {
                try SMAppService.mainApp.register()
            } else if !on, status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MonitorGlue: failed to \(on ? "enable" : "disable") launch at login: \(error)")
        }
        refresh()
    }
}

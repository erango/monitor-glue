import AppKit
import ApplicationServices
import Combine

/// Tracks Accessibility (TCC) trust, which is required to read and move other apps' windows.
final class Permissions: ObservableObject {
    static let shared = Permissions()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private var timer: Timer?

    /// Force a trust value for the gated UI preview harness only.
    func _setPreviewTrusted(_ value: Bool) { isTrusted = value }

    /// Re-check trust state (no prompt).
    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
    }

    /// Request trust — shows the system prompt the first time and opens System Settings.
    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        isTrusted = trusted
        if !trusted { openSettings() }
        startPolling()
    }

    /// Open the Accessibility pane directly.
    func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Poll until granted (the app can't observe TCC changes directly).
    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            self.refresh()
            if self.isTrusted { t.invalidate() }
        }
    }
}

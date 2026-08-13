import SwiftUI
import AppKit

@main
struct MonitorGlueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @StateObject private var permissions = Permissions.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(model)
                .environmentObject(permissions)
        } label: {
            Image(nsImage: AppGlyph.menuBarTemplate())
        }
        .menuBarExtraStyle(.window)

        Window("Monitor Glue", id: "manager") {
            ManagementView()
                .environmentObject(model)
                .environmentObject(permissions)
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 548)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // No Dock icon.
        if DebugPreview.requested != nil {
            DebugPreview.runIfRequested()   // Gated harness — skip live watchers/polling.
            return
        }
        AppModel.shared.start()
        if !Permissions.shared.isTrusted {
            OnboardingController.shared.show()
        }
    }
}

/// Coordinates the watcher, capturer, and restorer; exposes status to the UI.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var currentSetKey: String = ""
    @Published var rememberedCount: Int = 0
    @Published var statusText: String = "Starting…"

    // Richer status surfaced in the menu-bar dropdown.
    @Published var connectedExternalDisplays: Int = 0
    @Published var currentSetLabel: String = ""
    @Published var currentSetWindowCount: Int = 0
    @Published var totalWindowsRemembered: Int = 0

    var isTracking: Bool { connectedExternalDisplays > 0 && Permissions.shared.isTrusted }

    private let watcher = DisplayWatcher()
    private var pollTimer: Timer?

    func start() {
        Permissions.shared.refresh()
        if !Permissions.shared.isTrusted { Permissions.shared.startPolling() }

        watcher.onChange = { [weak self] key in
            self?.handleSetChange(key)
        }
        watcher.start()
        currentSetKey = watcher.currentKey
        LayoutCapturer.shared.currentSetKey = currentSetKey
        LayoutCapturer.shared.start()

        // Poll as a safety net for missed display-reconfiguration events (sleep/wake, dock
        // swaps). Cheap: it only reads the display list and compares the monitor-set key.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.watcher.poll()
        }

        // Restore on launch if we already know this set.
        if !currentSetKey.isEmpty { restoreWithRetries(currentSetKey) }
        refreshStatus()
    }

    private func handleSetChange(_ key: String) {
        currentSetKey = key
        LayoutCapturer.shared.currentSetKey = key
        let known = !key.isEmpty && LayoutStore.shared.record(for: key) != nil
        NSLog("MonitorGlue: monitor set changed → '\(key.isEmpty ? "built-in only" : key)' known=\(known)")
        if known { restoreWithRetries(key) }
        refreshStatus()
    }

    /// Restore several times after a display connects — macOS keeps reshuffling windows for a
    /// second or two, so a single pass can be undone. Each pass is idempotent.
    private func restoreWithRetries(_ key: String) {
        // Don't let a half-migrated snapshot overwrite the saved layout while restoring.
        LayoutCapturer.shared.suppressCapture(for: 16.0)
        // Spread the passes out: macOS keeps reshuffling for a moment, and apps that were
        // still launching have no windows to place yet. Passes are idempotent — a window
        // already in position is left alone.
        for delay in [0.8, 2.0, 3.5, 6.0, 10.0, 15.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard self.currentSetKey == key else { return }   // display changed again
                LayoutRestorer.restore(setKey: key)
            }
        }
    }

    func restoreNow() {
        guard !currentSetKey.isEmpty else { return }
        LayoutRestorer.restore(setKey: currentSetKey)
    }

    func refreshStatus() {
        let sets = LayoutStore.shared.allSets()
        rememberedCount = sets.count
        totalWindowsRemembered = sets.reduce(0) { $0 + $1.windows.count }

        let externals = DisplayInfo.externalDisplays()
        connectedExternalDisplays = externals.count

        if let record = LayoutStore.shared.record(for: currentSetKey) {
            currentSetLabel = record.label
            currentSetWindowCount = record.windows.count
        } else {
            currentSetLabel = externals.map { $0.localizedName }.sorted().joined(separator: " + ")
            currentSetWindowCount = 0
        }

        if !Permissions.shared.isTrusted {
            statusText = "Accessibility access needed"
        } else if connectedExternalDisplays == 0 {
            statusText = "Built-in display only — idle"
        } else {
            statusText = "Tracking · \(connectedExternalDisplays) display\(connectedExternalDisplays == 1 ? "" : "s") connected"
        }
    }
}

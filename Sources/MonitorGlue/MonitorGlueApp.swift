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

        // Restore on launch if we already know this set.
        if !currentSetKey.isEmpty { LayoutRestorer.restore(setKey: currentSetKey) }
        refreshStatus()
    }

    private func handleSetChange(_ key: String) {
        currentSetKey = key
        LayoutCapturer.shared.currentSetKey = key
        if !key.isEmpty, LayoutStore.shared.record(for: key) != nil {
            // Let apps/windows settle after the display comes online, then restore.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                LayoutRestorer.restore(setKey: key)
            }
        }
        refreshStatus()
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

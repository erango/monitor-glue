import SwiftUI
import AppKit

@main
struct MonitorGlueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @StateObject private var permissions = Permissions.shared

    var body: some Scene {
        MenuBarExtra("Monitor Glue", systemImage: "display") {
            MenuBarContent()
                .environmentObject(model)
                .environmentObject(permissions)
        }
        .menuBarExtraStyle(.window)

        Window("Monitor Glue", id: "manager") {
            ManagementView()
                .environmentObject(model)
                .environmentObject(permissions)
                .frame(minWidth: 640, minHeight: 460)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // No Dock icon.
        AppModel.shared.start()
    }
}

/// Coordinates the watcher, capturer, and restorer; exposes status to the UI.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var currentSetKey: String = ""
    @Published var rememberedCount: Int = 0
    @Published var statusText: String = "Starting…"

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
        rememberedCount = LayoutStore.shared.allSets().count
        if !Permissions.shared.isTrusted {
            statusText = "Accessibility access needed"
        } else if currentSetKey.isEmpty {
            statusText = "Built-in display only — idle"
        } else {
            statusText = "Tracking \(rememberedCount) monitor set\(rememberedCount == 1 ? "" : "s")"
        }
    }
}

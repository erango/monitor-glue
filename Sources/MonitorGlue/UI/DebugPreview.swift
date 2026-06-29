import SwiftUI
import AppKit

/// Gated screenshot/preview harness. Activated only when launched with the env var
/// `MG_PREVIEW=manager` (or `=onboarding`). No effect in normal use.
enum DebugPreview {
    static var requested: String? { ProcessInfo.processInfo.environment["MG_PREVIEW"] }

    static func runIfRequested() {
        guard let what = requested else { return }
        seedSampleData()
        if what == "menu" { Permissions.shared._setPreviewTrusted(true) }
        AppModel.shared.currentSetKey = "UUID-DELL|UUID-LG"
        AppModel.shared.refreshStatus()
        // Sample status counts (no live displays in the harness).
        AppModel.shared.connectedExternalDisplays = 2
        AppModel.shared.currentSetLabel = "Dell U2720Q + LG HDR 4K"
        AppModel.shared.currentSetWindowCount = 5
        if what == "manager" { showManager() }
        if what == "menu" { showMenu() }
    }

    private static func seedSampleData() {
        func win(_ bundle: String, _ name: String, _ uuid: String, _ title: String,
                 _ idx: Int, _ x: Double, _ y: Double, _ w: Double, _ h: Double) -> WindowLayout {
            WindowLayout(appBundleID: bundle, appName: name, displayUUID: uuid,
                         windowTitle: title, windowIndex: idx,
                         x: x, y: y, width: w, height: h, updatedAt: Date(timeIntervalSince1970: 1_780_000_000))
        }
        let u1 = "UUID-DELL", u2 = "UUID-LG"
        let setA = MonitorSetRecord(
            key: "\(u1)|\(u2)",
            displays: [
                DisplayInfoRecord(uuid: u1, localizedName: "Dell U2720Q", widthPx: 3840, heightPx: 2160),
                DisplayInfoRecord(uuid: u2, localizedName: "LG HDR 4K", widthPx: 3840, heightPx: 2160),
            ],
            lastSeen: Date(timeIntervalSince1970: 1_780_000_000),
            windows: [
                win("com.apple.Safari", "Safari", u1, "Apple — Start Page", 0, 40, 64, 1280, 900),
                win("com.apple.Safari", "Safari", u1, "GitHub", 1, 1340, 64, 1180, 900),
                win("com.apple.dt.Xcode", "Xcode", u2, "MonitorGlue.xcodeproj", 0, 0, 0, 1920, 1200),
                win("com.tinyspeck.slackmacgap", "Slack", u2, "Bizzabo", 0, 1920, 100, 1400, 1000),
                win("com.apple.mail", "Mail", u1, "Inbox", 0, 200, 1000, 1100, 760),
            ]
        )
        let setB = MonitorSetRecord(
            key: "UUID-HOME",
            displays: [DisplayInfoRecord(uuid: "UUID-HOME", localizedName: "Studio Display", widthPx: 5120, heightPx: 2880)],
            lastSeen: Date(timeIntervalSince1970: 1_779_000_000),
            windows: [
                win("com.figma.Desktop", "Figma", "UUID-HOME", "Monitor Glue UI", 0, 100, 120, 2400, 1500),
                win("com.googlecode.iterm2", "iTerm", "UUID-HOME", "zsh", 0, 2600, 120, 1200, 900),
                win("com.apple.Terminal", "Terminal", "UUID-HOME", "swift build", 0, 2600, 1100, 1200, 700),
            ]
        )
        LayoutStore.shared.injectForPreview(LayoutStoreData(monitorSets: [setA.key: setA, setB.key: setB]))
    }

    private static func showManager() {
        let view = ManagementView()
            .environmentObject(AppModel.shared)
            .environmentObject(Permissions.shared)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.setContentSize(NSSize(width: 760, height: 548))
        win.title = "Monitor Glue"
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        objc_setAssociatedObject(NSApp, "mg_preview_win", win, .OBJC_ASSOCIATION_RETAIN)
    }

    private static func showMenu() {
        let view = MenuBarContent()
            .environmentObject(AppModel.shared)
            .environmentObject(Permissions.shared)
            .background(.regularMaterial)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.title = "Monitor Glue Menu"
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        objc_setAssociatedObject(NSApp, "mg_preview_win", win, .OBJC_ASSOCIATION_RETAIN)
    }
}

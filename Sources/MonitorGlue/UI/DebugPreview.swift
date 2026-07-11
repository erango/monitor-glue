import SwiftUI
import AppKit

/// Gated screenshot/preview harness. Activated only when launched with the env var
/// `MG_PREVIEW=manager` (or `=onboarding`). No effect in normal use.
enum DebugPreview {
    static var requested: String? { ProcessInfo.processInfo.environment["MG_PREVIEW"] }

    @MainActor static func runIfRequested() {
        guard let what = requested else { return }
        if what == "glyph" { dumpMenuBarGlyph(); return }
        if what == "diag" { diag(); return }
        if what == "testmove" { testMove(); return }
        if what == "testlogin" {
            var out = "before status enabled=\(LoginItem.shared.isEnabled)\n"
            LoginItem.shared.setEnabled(true)
            out += "after register enabled=\(LoginItem.shared.isEnabled)\n"
            LoginItem.shared.setEnabled(false)
            out += "after unregister enabled=\(LoginItem.shared.isEnabled)\n"
            write(out); NSApp.terminate(nil); return
        }
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
        objc_setAssociatedObject(NSApplication.shared, "mg_preview_win", win, .OBJC_ASSOCIATION_RETAIN)
    }

    /// Render the menu-bar template glyph onto a white tile at menu-bar scale, then exit.
    /// Print AX trust, displays, and filtered/mapped windows, then exit. Writes to MG_DIAG_OUT.
    @MainActor private static func diag() {
        var out = "trusted=\(AXIsProcessTrusted())\n"
        for d in DisplayInfo.liveDisplays() {
            out += "DISPLAY \(d.isBuiltin ? "[builtin]" : "[external]") \(d.localizedName) uuid=\(d.uuid.prefix(8)) bounds=\(d.bounds)\n"
        }
        let displays = DisplayInfo.liveDisplays()
        for w in WindowManager.currentWindows() {
            let disp = WindowManager.display(for: w, in: displays)
            let rel = disp.map { CGPoint(x: w.frame.origin.x - $0.bounds.origin.x, y: w.frame.origin.y - $0.bounds.origin.y) }
            out += "WIN \(w.appName) | '\(w.title.prefix(30))' idx=\(w.index) frame=\(w.frame) -> disp=\(disp?.localizedName ?? "none") rel=\(rel.map{"(\(Int($0.x)),\(Int($0.y)))"} ?? "-")\n"
        }
        let path = ProcessInfo.processInfo.environment["MG_DIAG_OUT"] ?? "/tmp/mg_diag.txt"
        try? out.write(toFile: path, atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    /// Verify AX write: nudge the first external window by (150,150), read it back, restore.
    @MainActor private static func testMove() {
        let displays = DisplayInfo.liveDisplays()
        var out = "trusted=\(AXIsProcessTrusted())\n"
        guard let w = WindowManager.currentWindows().first(where: {
            WindowManager.display(for: $0, in: displays).map { !$0.isBuiltin } ?? false
        }) else { out += "no external window found\n"; write(out); NSApp.terminate(nil); return }

        let before = w.frame
        let nudged = CGRect(x: before.origin.x + 150, y: before.origin.y + 150,
                            width: before.width, height: before.height)
        let ok = WindowManager.setFrame(w.element, nudged)
        let after = WindowManager.frame(of: w.element) ?? .zero
        out += "target=\(w.appName) '\(w.title.prefix(24))'\n"
        out += "setFrame returned=\(ok)\nbefore=\(before)\nafter =\(after)\nmoved=\(after.origin != before.origin)\n"
        _ = WindowManager.setFrame(w.element, before)   // put it back
        write(out); NSApp.terminate(nil)
    }

    private static func write(_ s: String) {
        let path = ProcessInfo.processInfo.environment["MG_DIAG_OUT"] ?? "/tmp/mg_diag.txt"
        try? s.write(toFile: path, atomically: true, encoding: .utf8)
    }

    @MainActor private static func dumpMenuBarGlyph() {
        let tmpl = AppGlyph.menuBarTemplate()
        let tileH = 44.0, tileW = 60.0
        let tile = NSImage(size: NSSize(width: tileW, height: tileH))
        tile.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: tileW, height: tileH).fill()
        // Template draws in black via the current fill color.
        NSColor.black.set()
        let g = 18.0
        tmpl.draw(in: NSRect(x: (tileW-g)/2, y: (tileH-g)/2, width: g, height: g),
                  from: .zero, operation: .sourceOver, fraction: 1.0)
        tile.unlockFocus()
        if let tiff = tile.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let path = ProcessInfo.processInfo.environment["MG_GLYPH_OUT"] ?? "/tmp/mg_glyph.png"
            try? png.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
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
        objc_setAssociatedObject(NSApplication.shared, "mg_preview_win", win, .OBJC_ASSOCIATION_RETAIN)
    }
}

import SwiftUI
import AppKit
import ServiceManagement

/// Gated screenshot/preview harness. Activated only when launched with the env var
/// `MG_PREVIEW=manager` (or `=onboarding`). No effect in normal use.
enum DebugPreview {
    static var requested: String? { ProcessInfo.processInfo.environment["MG_PREVIEW"] }

    @MainActor static func runIfRequested() {
        guard let what = requested else { return }
        if what == "glyph" { dumpMenuBarGlyph(); return }
        if what == "diag" { diag(); return }
        if what == "testmove" { testMove(); return }
        if what == "e2e" { e2e(); return }
        if what == "simulate" { simulateReconnect(); return }
        if what == "scatter" { scatter(); return }
        if what == "testpoll" {
            // A fresh watcher starts with an empty key, so poll() must notice the currently
            // connected external display and report it — the same path that recovers a
            // reconfiguration event the app never received.
            let w = DisplayWatcher()
            var fired: String? = nil
            w.onChange = { fired = $0 }
            w.poll()
            let expected = DisplayInfo.monitorSetKey(for: DisplayInfo.liveDisplays())
            write("expected=\(expected)\npollFired=\(fired ?? "nil")\nmatch=\(fired == expected)\n")
            NSApp.terminate(nil); return
        }
        if what == "testrestore" {
            let key = DisplayInfo.monitorSetKey(for: DisplayInfo.liveDisplays())
            var out = "trusted=\(AXIsProcessTrusted())\ncurrentSetKey=\(key)\n"
            out += "record found=\(LayoutStore.shared.record(for: key) != nil)\n"
            if let rec = LayoutStore.shared.record(for: key) {
                out += "saved windows=\(rec.windows.count)\n"
                let live = WindowManager.currentWindows()
                for l in rec.windows {
                    let cands = live.filter { $0.appBundleID == l.appBundleID }
                    out += "  layout \(l.appName) idx=\(l.windowIndex) '\(l.windowTitle.prefix(24))' -> liveCandidates=\(cands.count)\n"
                }
            }
            let moved = LayoutRestorer.restore(setKey: key)
            out += "restore moved=\(moved)\n"
            write(out); NSApp.terminate(nil); return
        }
        if what == "loginstatus" {
            let s = SMAppService.mainApp.status
            let name: String
            switch s {
            case .enabled: name = "enabled"
            case .requiresApproval: name = "requiresApproval"
            case .notRegistered: name = "notRegistered"
            case .notFound: name = "notFound"
            @unknown default: name = "unknown(\(s.rawValue))"
            }
            write("status=\(name) raw=\(s.rawValue)\n"); NSApp.terminate(nil); return
        }
        if what == "loginoff" {
            do { try SMAppService.mainApp.unregister(); write("unregistered ok\n") }
            catch { write("unregister error: \(error)\n") }
            NSApp.terminate(nil); return
        }
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

    /// Mimic what macOS leaves behind after a reconnect, WITHOUT capturing: most saved windows
    /// shoved onto the built-in display, one left on the external. Used to test what the app
    /// does when it is launched into that state (quit → connect monitor → open).
    @MainActor private static func scatter() {
        let displays = DisplayInfo.liveDisplays()
        guard let builtin = displays.first(where: { $0.isBuiltin }) else {
            write("no built-in display\n"); NSApp.terminate(nil); return
        }
        let key = DisplayInfo.monitorSetKey(for: displays)
        guard let rec = LayoutStore.shared.record(for: key) else {
            write("no record for current set\n"); NSApp.terminate(nil); return
        }
        var out = "scattering \(rec.windows.count) saved window(s) of '\(rec.label)'\n"
        let live = WindowManager.currentWindows()
        for (n, l) in rec.windows.enumerated() {
            let cands = live.filter { $0.appBundleID == l.appBundleID }
            guard let w = cands.first(where: { $0.index == l.windowIndex }) ?? cands.first else { continue }
            if n == 0 {
                out += "  leaving \(l.appName) idx=\(l.windowIndex) on the external display\n"
                continue
            }
            let squeezed = CGRect(x: builtin.bounds.origin.x + CGFloat(30 * n),
                                  y: builtin.bounds.origin.y + CGFloat(30 * n) + 40,
                                  width: 900, height: 600)
            _ = WindowManager.setFrame(w.element, squeezed)
            out += "  moved \(l.appName) idx=\(l.windowIndex) to built-in \(fmt(squeezed))\n"
        }
        write(out); NSApp.terminate(nil)
    }

    /// Reproduce the real complaint without unplugging: shove every window that belongs on the
    /// external display onto the built-in (shrunk, like macOS does on disconnect), then restore
    /// and report per-window whether it matched and whether position/size came back exactly.
    @MainActor private static func simulateReconnect() {
        let displays = DisplayInfo.liveDisplays()
        guard let builtin = displays.first(where: { $0.isBuiltin }),
              let ext = displays.first(where: { !$0.isBuiltin }) else {
            write("need both a built-in and an external display\n"); NSApp.terminate(nil); return
        }
        let key = DisplayInfo.monitorSetKey(for: displays)
        LayoutCapturer.shared.capture(force: true)   // snapshot the good layout first
        guard let rec = LayoutStore.shared.record(for: key) else {
            write("no record for current set\n"); NSApp.terminate(nil); return
        }
        var out = "set=\(rec.label) saved=\(rec.windows.count)\n"

        // 1. Simulate the disconnect reshuffle: everything to the built-in, shrunk.
        for (n, l) in rec.windows.enumerated() {
            let live = WindowManager.currentWindows().filter { $0.appBundleID == l.appBundleID }
            guard let w = live.first(where: { $0.index == l.windowIndex }) ?? live.first else { continue }
            let squeezed = CGRect(x: builtin.bounds.origin.x + CGFloat(20 * n),
                                  y: builtin.bounds.origin.y + CGFloat(20 * n) + 40,
                                  width: 900, height: 600)
            _ = WindowManager.setFrame(w.element, squeezed)
        }
        out += "-- after simulated disconnect --\n"
        for w in WindowManager.currentWindows() where rec.windows.contains(where: { $0.appBundleID == w.appBundleID }) {
            out += "   \(w.appName) idx=\(w.index) '\(w.title.prefix(20))' \(fmt(w.frame))\n"
        }

        // 2. Restore.
        let moved = LayoutRestorer.restore(setKey: key)
        out += "-- restore moved=\(moved) --\n"

        // 3. Grade every saved layout.
        let after = WindowManager.currentWindows()
        var okCount = 0
        for l in rec.windows {
            let expected = CGRect(x: ext.bounds.origin.x + l.x, y: ext.bounds.origin.y + l.y,
                                  width: l.width, height: l.height)
            let hit = after.first { $0.appBundleID == l.appBundleID && $0.frame.equalish(expected) }
            let anyOfApp = after.filter { $0.appBundleID == l.appBundleID }
            if hit != nil { okCount += 1 }
            out += "  \(hit != nil ? "OK  " : "FAIL") \(l.appName) idx=\(l.windowIndex) '\(l.windowTitle.prefix(18))'\n"
            out += "       expected \(fmt(expected))\n"
            for c in anyOfApp {
                out += "       actual   idx=\(c.index) \(fmt(c.frame)) posOK=\(abs(c.frame.origin.x-expected.origin.x)<3 && abs(c.frame.origin.y-expected.origin.y)<3) sizeOK=\(abs(c.frame.width-expected.width)<3 && abs(c.frame.height-expected.height)<3)\n"
            }
        }
        out += "RESULT \(okCount)/\(rec.windows.count) restored exactly\n"
        write(out); NSApp.terminate(nil)
    }

    private static func fmt(_ r: CGRect) -> String {
        "(\(Int(r.origin.x)),\(Int(r.origin.y)) \(Int(r.width))x\(Int(r.height)))"
    }

    /// Full round-trip check that BOTH size and position are captured and restored:
    /// set a distinctive frame on an external window → capture → move+resize it away →
    /// restore → compare the restored frame against the captured one.
    @MainActor private static func e2e() {
        var out = "trusted=\(AXIsProcessTrusted())\n"
        let displays = DisplayInfo.liveDisplays()
        guard let ext = displays.first(where: { !$0.isBuiltin }),
              let builtin = displays.first(where: { $0.isBuiltin }) else {
            out += "need both a built-in and an external display\n"; write(out); NSApp.terminate(nil); return
        }
        guard let w = WindowManager.currentWindows().first(where: {
            WindowManager.display(for: $0, in: displays).map { !$0.isBuiltin } ?? false
        }) else { out += "no window on the external display\n"; write(out); NSApp.terminate(nil); return }

        let original = w.frame
        // 1. Distinctive frame — deliberately WIDER than the built-in display, which is what
        //    triggered the clamping bug (a 2560-wide window came back as 1998).
        let distinctive = CGRect(x: ext.bounds.origin.x, y: ext.bounds.origin.y + 30,
                                width: ext.bounds.width, height: ext.bounds.height - 30)
        _ = WindowManager.setFrame(w.element, distinctive)
        let placed = WindowManager.frame(of: w.element) ?? .zero
        out += "target=\(w.appName) '\(w.title.prefix(24))'\n1 placed=\(placed)\n"

        // 2. Capture it.
        LayoutCapturer.shared.capture(force: true)
        let key = DisplayInfo.monitorSetKey(for: displays)
        let saved = LayoutStore.shared.record(for: key)?.windows.first {
            $0.appBundleID == w.appBundleID && $0.windowIndex == w.index
        }
        out += "2 saved rel=(\(Int(saved?.x ?? -1)),\(Int(saved?.y ?? -1))) size=\(Int(saved?.width ?? -1))x\(Int(saved?.height ?? -1))\n"

        // 3. Move + resize away, onto the small built-in display (what macOS does on disconnect).
        _ = WindowManager.setFrame(w.element, CGRect(x: builtin.bounds.origin.x + 60,
                                                     y: builtin.bounds.origin.y + 80,
                                                     width: 700, height: 500))
        out += "3 disturbed=\(WindowManager.frame(of: w.element) ?? .zero)\n"

        // 4. Restore and compare.
        let moved = LayoutRestorer.restore(setKey: key)
        let after = WindowManager.frame(of: w.element) ?? .zero
        out += "4 restored=\(after) moved=\(moved)\n"
        let posOK = abs(after.origin.x - placed.origin.x) < 3 && abs(after.origin.y - placed.origin.y) < 3
        let sizeOK = abs(after.width - placed.width) < 3 && abs(after.height - placed.height) < 3
        out += "positionRestored=\(posOK)\nsizeRestored=\(sizeOK)\n"

        _ = WindowManager.setFrame(w.element, original)   // put it back
        write(out); NSApp.terminate(nil)
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

extension CGRect {
    /// Tolerant frame comparison (AX rounds and some apps snap by a pixel or two).
    func equalish(_ o: CGRect, tol: CGFloat = 3) -> Bool {
        abs(origin.x - o.origin.x) < tol && abs(origin.y - o.origin.y) < tol &&
        abs(width - o.width) < tol && abs(height - o.height) < tol
    }
}

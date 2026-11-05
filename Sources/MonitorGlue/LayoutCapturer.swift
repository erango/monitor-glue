import AppKit

/// Continuously snapshots the positions of windows and persists the freshest layout for the
/// connected combination of displays.
final class LayoutCapturer {
    static let shared = LayoutCapturer()

    private var timer: Timer?
    private let interval: TimeInterval = 4.0
    private var lastSnapshotHash: Int = 0
    private var lastWrite: Date = .distantPast

    /// The monitor-set key currently being tracked (set by the app on display changes).
    var currentSetKey: String = ""

    /// Capture is paused until this time. Right after a display connects, macOS has usually
    /// not finished moving windows back, so a snapshot then would replace a good saved layout
    /// with a half-migrated one. The app pauses capture while restore runs.
    private var suppressedUntil: Date = .distantPast

    func suppressCapture(for seconds: TimeInterval) {
        suppressedUntil = Date().addingTimeInterval(seconds)
    }

    /// Clear any suppression immediately.
    func resumeCapture() {
        suppressedUntil = .distantPast
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.capture()
        }
        capture()
    }

    func stop() { timer?.invalidate(); timer = nil }

    /// Apps that just launched, and until when to leave their windows out of snapshots. A
    /// launching app opens its windows wherever macOS puts them; recording that before the app's
    /// saved places have been applied would overwrite them.
    private var heldApps: [String: Date] = [:]

    func hold(app bundleID: String, for seconds: TimeInterval) {
        heldApps[bundleID] = Date().addingTimeInterval(seconds)
    }

    func release(app bundleID: String) {
        heldApps[bundleID] = nil
    }

    /// Take one snapshot now. Cheap no-op if nothing changed.
    /// `force` bypasses the post-connect pause and the unhandled-display-change check (used by tests).
    func capture(force: Bool = false) {
        guard AXIsProcessTrusted() else { return }
        guard force || Date() >= suppressedUntil else { return }
        let displays = DisplayInfo.liveDisplays()
        let managed = DisplayInfo.managedDisplays(displays)
        guard !managed.isEmpty else { return }

        let setKey = DisplayInfo.monitorSetKey(for: displays)
        guard !setKey.isEmpty else { return }
        // The displays changed and the app has not handled it yet. Right after a monitor
        // connects every window is still piled on the laptop screen; a snapshot now would save
        // that pile as the monitor's layout before restore gets the chance to undo it.
        guard force || setKey == currentSetKey else { return }

        let now = Date()
        heldApps = heldApps.filter { $0.value > now }
        let live = WindowManager.currentWindows().filter { heldApps[$0.appBundleID] == nil }
        var layouts: [WindowLayout] = []

        // Every window on every display belongs to this layout, the laptop screen included:
        // a window kept on the laptop while a monitor is connected has a place too, and that
        // is where it should reopen. Each combination of displays still keeps its own layout,
        // so this never touches what is remembered for the laptop on its own.
        for win in live {
            guard let disp = WindowManager.display(for: win, in: displays) else { continue }
            // Store the position RELATIVE to the display's origin, so restore works even when
            // the display comes back at a different arrangement origin next session.
            layouts.append(WindowLayout(
                appBundleID: win.appBundleID,
                appName: win.appName,
                displayUUID: disp.uuid,
                windowTitle: win.title,
                windowIndex: win.index,
                x: win.frame.origin.x - disp.bounds.origin.x,
                y: win.frame.origin.y - disp.bounds.origin.y,
                width: win.frame.size.width, height: win.frame.size.height,
                updatedAt: now
            ))
        }

        guard !layouts.isEmpty else { return }

        // Diff: skip the write if the layout is unchanged (ignore timestamps).
        let hash = layouts.map { "\($0.appBundleID)\($0.windowIndex)\($0.displayUUID)\($0.x)\($0.y)\($0.width)\($0.height)" }
            .joined().hashValue
        // Skip unchanged snapshots, but still write about once a day: the write refreshes each
        // window's "last seen" time, which is what keeps a window that simply never moves from
        // being mistaken for a closed one by the 30-day cleanup.
        guard hash != lastSnapshotHash || Date().timeIntervalSince(lastWrite) > 24 * 60 * 60 else { return }
        lastSnapshotHash = hash
        lastWrite = Date()

        LayoutStore.shared.upsert(
            setKey: setKey,
            displays: DisplayInfo.records(for: displays),
            windows: layouts
        )
        Log.write("captured \(layouts.count) window(s) for \(managed.map { $0.localizedName }.joined(separator: " + "))")
    }
}

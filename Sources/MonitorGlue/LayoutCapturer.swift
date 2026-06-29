import AppKit

/// Continuously snapshots the positions of windows on external displays and persists
/// the freshest layout per monitor-set. Built-in-display windows are ignored.
final class LayoutCapturer {
    static let shared = LayoutCapturer()

    private var timer: Timer?
    private let interval: TimeInterval = 4.0
    private var lastSnapshotHash: Int = 0

    /// The monitor-set key currently being tracked (set by the app on display changes).
    var currentSetKey: String = ""

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.capture()
        }
        capture()
    }

    func stop() { timer?.invalidate(); timer = nil }

    /// Take one snapshot now. Cheap no-op if nothing changed or no external display.
    func capture() {
        guard AXIsProcessTrusted() else { return }
        let displays = DisplayInfo.liveDisplays()
        let externals = displays.filter { !$0.isBuiltin }
        guard !externals.isEmpty else { return }

        let setKey = DisplayInfo.monitorSetKey(for: displays)
        guard !setKey.isEmpty else { return }
        currentSetKey = setKey

        let live = WindowManager.currentWindows()
        var layouts: [WindowLayout] = []
        let now = Date()

        for win in live {
            // Only remember windows that live on an external display.
            guard let disp = WindowManager.display(for: win, in: displays), !disp.isBuiltin else { continue }
            layouts.append(WindowLayout(
                appBundleID: win.appBundleID,
                appName: win.appName,
                displayUUID: disp.uuid,
                windowTitle: win.title,
                windowIndex: win.index,
                x: win.frame.origin.x, y: win.frame.origin.y,
                width: win.frame.size.width, height: win.frame.size.height,
                updatedAt: now
            ))
        }

        guard !layouts.isEmpty else { return }

        // Diff: skip the write if the layout is unchanged (ignore timestamps).
        let hash = layouts.map { "\($0.appBundleID)\($0.windowIndex)\($0.x)\($0.y)\($0.width)\($0.height)" }
            .joined().hashValue
        guard hash != lastSnapshotHash else { return }
        lastSnapshotHash = hash

        LayoutStore.shared.upsert(
            setKey: setKey,
            displays: DisplayInfo.records(for: displays),
            windows: layouts
        )
    }
}

import AppKit
import CoreGraphics

/// Single source of truth for "the set of connected external monitors changed".
/// Coalesces the noisy `CGDisplayReconfigurationCallBack` (fires repeatedly per change)
/// and `NSApplication.didChangeScreenParametersNotification` into one debounced event.
final class DisplayWatcher {
    /// Called on the main thread with the new external-monitor-set key (may be "").
    var onChange: ((String) -> Void)?

    /// Called when the same displays are still connected but their geometry changed — opening
    /// the lid (the built-in display appears, shifting the external's origin), a resolution
    /// change, or a monitor waking up. The set key is unchanged in those cases, since it only
    /// covers which external displays are attached, so `onChange` would not fire.
    var onGeometryChange: (() -> Void)?

    private(set) var currentKey: String = ""
    private var currentGeometry: String = ""
    private var debounce: DispatchWorkItem?
    private var registered = false

    func start() {
        let displays = DisplayInfo.liveDisplays()
        currentKey = DisplayInfo.monitorSetKey(for: displays)
        currentGeometry = Self.geometrySignature(displays)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParamsChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
            // Re-evaluate on any reconfiguration except the "begin" phase (nothing has changed
            // yet at that point). Filtering to add/remove missed real reconnects — e.g. a
            // display coming back after sleep reports only mode/enable flags. It's debounced
            // and the key comparison makes extra evaluations free.
            guard !flags.contains(.beginConfigurationFlag) else { return }
            guard let userInfo else { return }
            let watcher = Unmanaged<DisplayWatcher>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { watcher.scheduleReevaluate() }
        }
        if CGDisplayRegisterReconfigurationCallback(callback, ctx) == .success {
            registered = true
        }
    }

    @objc private func screenParamsChanged() { scheduleReevaluate() }

    /// Safety net: re-check the connected displays even if no notification arrived.
    /// Long-running sessions (sleep/wake, dock swaps) can miss reconfiguration callbacks
    /// entirely; polling makes a missed connect self-healing. No-op when nothing changed.
    func poll() { reevaluate() }

    private func scheduleReevaluate() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reevaluate() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func reevaluate() {
        let displays = DisplayInfo.liveDisplays()
        let key = DisplayInfo.monitorSetKey(for: displays)
        let geometry = Self.geometrySignature(displays)

        if key != currentKey {
            currentKey = key
            currentGeometry = geometry
            onChange?(key)
            return
        }
        if geometry != currentGeometry {
            currentGeometry = geometry
            onGeometryChange?()
        }
    }

    /// Every display's identity and frame — changes when the lid opens, a display wakes, or a
    /// resolution changes, even though the set of attached external displays is the same.
    private static func geometrySignature(_ displays: [LiveDisplay]) -> String {
        displays
            .map { "\($0.uuid):\(Int($0.bounds.origin.x)),\(Int($0.bounds.origin.y)),\(Int($0.bounds.width)),\(Int($0.bounds.height))" }
            .sorted()
            .joined(separator: "|")
    }
}

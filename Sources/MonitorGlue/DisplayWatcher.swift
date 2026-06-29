import AppKit
import CoreGraphics

/// Single source of truth for "the set of connected external monitors changed".
/// Coalesces the noisy `CGDisplayReconfigurationCallBack` (fires repeatedly per change)
/// and `NSApplication.didChangeScreenParametersNotification` into one debounced event.
final class DisplayWatcher {
    /// Called on the main thread with the new external-monitor-set key (may be "").
    var onChange: ((String) -> Void)?

    private(set) var currentKey: String = ""
    private var debounce: DispatchWorkItem?
    private var registered = false

    func start() {
        currentKey = DisplayInfo.monitorSetKey(for: DisplayInfo.liveDisplays())

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParamsChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
            // Ignore begin-configuration churn; act on the settling flags.
            guard flags.contains(.addFlag) || flags.contains(.removeFlag)
                    || flags.contains(.enabledFlag) || flags.contains(.disabledFlag) else { return }
            guard let userInfo else { return }
            let watcher = Unmanaged<DisplayWatcher>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { watcher.scheduleReevaluate() }
        }
        if CGDisplayRegisterReconfigurationCallback(callback, ctx) == .success {
            registered = true
        }
    }

    @objc private func screenParamsChanged() { scheduleReevaluate() }

    private func scheduleReevaluate() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reevaluate() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func reevaluate() {
        let key = DisplayInfo.monitorSetKey(for: DisplayInfo.liveDisplays())
        guard key != currentKey else { return }
        currentKey = key
        onChange?(key)
    }
}

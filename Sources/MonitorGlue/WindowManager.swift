import AppKit
import ApplicationServices

/// A live window read from the Accessibility API.
struct LiveWindow {
    var element: AXUIElement
    var appBundleID: String
    var appName: String
    var pid: pid_t
    var title: String
    var index: Int          // Index within the app's window list.
    var frame: CGRect       // AX global coords (top-left origin).
}

/// Reads and repositions other applications' windows via the Accessibility API.
/// All coordinates are AX global (top-left origin), matching `CGDisplayBounds`.
enum WindowManager {

    // MARK: Enumeration

    static func currentWindows() -> [LiveWindow] {
        guard AXIsProcessTrusted() else { return [] }
        var result: [LiveWindow] = []
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.processIdentifier != ownPID,
                  let bundleID = app.bundleIdentifier else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = copyValue(appElement, kAXWindowsAttribute) as? [AXUIElement] else { continue }

            for (idx, win) in windows.enumerated() {
                guard let frame = frame(of: win) else { continue }
                let title = (copyValue(win, kAXTitleAttribute) as? String) ?? ""
                result.append(LiveWindow(
                    element: win,
                    appBundleID: bundleID,
                    appName: app.localizedName ?? bundleID,
                    pid: app.processIdentifier,
                    title: title,
                    index: idx,
                    frame: frame
                ))
            }
        }
        return result
    }

    // MARK: Frame read/write

    static func frame(of window: AXUIElement) -> CGRect? {
        guard let posValue = copyValue(window, kAXPositionAttribute),
              let sizeValue = copyValue(window, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    /// Move + resize a window. Position first, then size (some apps clamp size to current screen).
    @discardableResult
    static func setFrame(_ window: AXUIElement, _ frame: CGRect) -> Bool {
        var point = frame.origin
        var size = frame.size
        guard let posValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
        let r1 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        let r2 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        // Re-assert position after resize, in case the resize nudged it.
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        return r1 == .success && r2 == .success
    }

    // MARK: Display mapping

    /// Which live display a window sits on, by its center point. nil if off all displays.
    static func display(for window: LiveWindow, in displays: [LiveDisplay]) -> LiveDisplay? {
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        return displays.first { $0.bounds.contains(center) }
    }

    // MARK: Helpers

    private static func copyValue(_ element: AXUIElement, _ attr: String) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        return err == .success ? value : nil
    }
}

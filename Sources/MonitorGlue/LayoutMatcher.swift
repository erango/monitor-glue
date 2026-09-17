import AppKit

/// Works out which open window belongs to which saved layout.
///
/// Both restoring and forgetting need the same answer, and they must agree: if capture decides
/// a saved entry belongs to a window the user parked on the built-in screen, restore has to
/// reach the same conclusion, or one undoes the other.
enum LayoutMatcher {

    /// - Returns: index into `layouts` → the open window it refers to.
    static func match(_ layouts: [WindowLayout], to live: [LiveWindow]) -> [Int: LiveWindow] {
        var assignment: [Int: LiveWindow] = [:]
        var used = Set<UInt>()

        func token(_ w: LiveWindow) -> UInt { UInt(bitPattern: ObjectIdentifier(w.element).hashValue) }
        func claim(_ i: Int, _ w: LiveWindow) { assignment[i] = w; used.insert(token(w)) }
        func available(_ bundleID: String) -> [LiveWindow] {
            live.filter { $0.appBundleID == bundleID && !used.contains(token($0)) }
        }

        // Strongest signal first, across all layouts, so an early weak guess cannot steal the
        // window a later layout identifies exactly.
        for (i, layout) in layouts.enumerated() where assignment[i] == nil {
            guard !layout.windowTitle.isEmpty else { continue }
            if let w = available(layout.appBundleID).first(where: { $0.title == layout.windowTitle }) {
                claim(i, w)
            }
        }
        for (i, layout) in layouts.enumerated() where assignment[i] == nil {
            if let w = available(layout.appBundleID).first(where: { $0.index == layout.windowIndex }) {
                claim(i, w)
            }
        }
        // Last resort: only when there is nothing to get wrong — exactly one unmatched saved
        // window for the app and exactly one unmatched open window. Guessing beyond that is how
        // a window the user deliberately moved to the laptop got dragged back to the monitor.
        for (i, layout) in layouts.enumerated() where assignment[i] == nil {
            let candidates = available(layout.appBundleID)
            let unmatchedForApp = layouts.enumerated()
                .filter { $0.element.appBundleID == layout.appBundleID && assignment[$0.offset] == nil }
            if candidates.count == 1, unmatchedForApp.count == 1 {
                claim(i, candidates[0])
            }
        }
        return assignment
    }

    /// How a layout was matched, for the log.
    static func reason(_ layout: WindowLayout, _ window: LiveWindow) -> String {
        if !layout.windowTitle.isEmpty, window.title == layout.windowTitle { return "title" }
        if window.index == layout.windowIndex { return "index" }
        return "only-window"
    }
}

import AppKit

/// Repositions windows to their saved frames when a known monitor set reconnects.
/// Matching is best-effort: bundle ID is required, then exact title, then window index.
enum LayoutRestorer {

    /// Last logged outcome and how many identical ones followed it. Retries now run several
    /// times a second, and an unchanged failure repeated 25 times is noise, not information.
    private static var lastSignature = ""
    private static var suppressedRepeats = 0

    /// Layouts already placed during the current restore cycle. Retries keep running while some
    /// other window is still missing (its app may yet reopen), and without this they would keep
    /// re-applying the saved frame to windows that are already done - overriding the user every
    /// few seconds when they resize one.
    private static var placedThisCycle = Set<String>()

    /// Start a new restore cycle for a display change; forget what was placed in the last one.
    static func beginCycle() {
        placedThisCycle.removeAll()
    }

    /// Result of one restore pass. `missing` counts saved windows that had no open window to
    /// place — the signal that the layout on screen is not yet the saved one, so the caller
    /// should keep retrying and must not let capture overwrite the saved layout.
    struct Outcome {
        var placed: Int = 0
        /// Saved windows with no open window to place - nothing can be done until the app
        /// reopens, so this keeps the retries running.
        var missing: Int = 0
        /// Matched windows that are not yet sitting at their saved frame. While this is above
        /// zero we are still actively placing, and capture must not record the half-done state.
        var pendingPlacements: Int = 0
        var isComplete: Bool { missing == 0 && pendingPlacements == 0 }
    }

    /// - Parameter enforce: re-apply saved frames even to windows already placed in this cycle.
    ///   True only for the first seconds after a display change, while macOS is still shuffling
    ///   windows; afterwards a placed window is left alone so resizing it actually sticks.
    @discardableResult
    static func restore(setKey: String, enforce: Bool = true) -> Outcome {
        guard AXIsProcessTrusted() else {
            Log.write("restore skipped — no Accessibility access")
            return Outcome()
        }
        guard let record = LayoutStore.shared.record(for: setKey) else {
            Log.write("restore skipped — no saved layout for set '\(setKey)'")
            return Outcome()
        }

        let displays = DisplayInfo.liveDisplays()
        let live = WindowManager.currentWindows()
        let liveByBundle = Dictionary(grouping: live, by: { $0.appBundleID })
        // Only restore to displays that are actually present now, keyed by UUID.
        let displaysByUUID = Dictionary(uniqueKeysWithValues: displays.map { ($0.uuid, $0) })

        // Assign saved layouts to live windows in passes, strongest signal first. A greedy
        // per-layout search would let an early layout's weak fallback steal the very window a
        // later layout matches by title, leaving that one unrestored.
        let restorable = record.windows.filter { displaysByUUID[$0.displayUUID] != nil }
        var assignment: [Int: LiveWindow] = [:]      // layout offset → window
        var usedElements = Set<UInt>()

        func token(_ w: LiveWindow) -> UInt { UInt(bitPattern: ObjectIdentifier(w.element).hashValue) }
        func claim(_ i: Int, _ w: LiveWindow) {
            assignment[i] = w
            usedElements.insert(token(w))
        }
        func available(_ bundleID: String) -> [LiveWindow] {
            (liveByBundle[bundleID] ?? []).filter { !usedElements.contains(token($0)) }
        }

        var matchedBy: [Int: String] = [:]

        // Pass 1: exact, non-empty title match.
        for (i, layout) in restorable.enumerated() where assignment[i] == nil {
            guard !layout.windowTitle.isEmpty else { continue }
            if let w = available(layout.appBundleID).first(where: { $0.title == layout.windowTitle }) {
                claim(i, w); matchedBy[i] = "title"
            }
        }
        // Pass 2: same window index within the app.
        for (i, layout) in restorable.enumerated() where assignment[i] == nil {
            if let w = available(layout.appBundleID).first(where: { $0.index == layout.windowIndex }) {
                claim(i, w); matchedBy[i] = "index"
            }
        }
        // Pass 3: any remaining window of that app.
        for (i, layout) in restorable.enumerated() where assignment[i] == nil {
            if let w = available(layout.appBundleID).first { claim(i, w); matchedBy[i] = "fallback" }
        }

        // Retry passes are usually no-ops; log those as one line so real events stay visible.
        var details: [String] = []
        var alreadyInPlace = 0
        var moved = 0
        var pendingPlacements = 0
        for (i, layout) in restorable.enumerated() {
            guard let disp = displaysByUUID[layout.displayUUID] else { continue }
            // Saved coords are relative to the display origin → map to its current position.
            let target = CGRect(x: disp.bounds.origin.x + layout.x,
                                y: disp.bounds.origin.y + layout.y,
                                width: layout.width, height: layout.height)
            guard let win = assignment[i] else {
                details.append("  MISS \(layout.appName) idx=\(layout.windowIndex) '\(layout.windowTitle.prefix(28))' — no open window to place")
                continue
            }
            // Already done earlier in this cycle: leave it alone, so the user can resize it
            // while we are still waiting for some other app to reopen.
            if !enforce, placedThisCycle.contains(layout.id) {
                moved += 1
                alreadyInPlace += 1
                continue
            }
            if win.frame.matches(target) {
                moved += 1
                alreadyInPlace += 1
                placedThisCycle.insert(layout.id)
                continue
            }
            let ok = WindowManager.setFrame(win.element, target)
            let actual = WindowManager.frame(of: win.element) ?? .zero
            if ok { moved += 1; placedThisCycle.insert(layout.id) } else { pendingPlacements += 1 }
            details.append("  \(ok ? "OK  " : "BAD ") \(layout.appName) idx=\(layout.windowIndex) via=\(matchedBy[i] ?? "?") '\(win.title.prefix(24))' want=\(str(target)) got=\(str(actual))")
        }

        let missing = restorable.count - assignment.count

        // Collapse a run of identical attempts into one line plus a count.
        let signature = "\(setKey)|\(assignment.count)|\(moved)|\(missing)|\(details.count)"
        if signature == lastSignature, missing > 0 {
            suppressedRepeats += 1
            return Outcome(placed: moved, missing: missing, pendingPlacements: pendingPlacements)
        }
        if suppressedRepeats > 0 {
            Log.write("  (\(suppressedRepeats) further identical attempt(s))")
            suppressedRepeats = 0
        }
        lastSignature = signature

        if details.isEmpty {
            Log.write("restore '\(record.label)': nothing to do — \(alreadyInPlace)/\(restorable.count) already in place")
        } else {
            Log.write("restore '\(record.label)': \(record.windows.count) saved, \(restorable.count) on present displays, \(assignment.count) matched, \(alreadyInPlace) already in place; AX reported \(live.count) window(s) across \(liveByBundle.count) app(s)")
            details.forEach { Log.write($0) }
            Log.write("restore done: \(moved)/\(restorable.count) placed\(missing > 0 ? ", \(missing) still missing" : "")")
        }
        return Outcome(placed: moved, missing: missing, pendingPlacements: pendingPlacements)
    }

    private static func str(_ r: CGRect) -> String {
        "(\(Int(r.origin.x)),\(Int(r.origin.y)) \(Int(r.width))x\(Int(r.height)))"
    }

}

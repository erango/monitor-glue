import AppKit

/// Repositions windows to their saved frames when a known monitor set reconnects.
/// Matching is best-effort: bundle ID is required, then exact title, then window index.
enum LayoutRestorer {

    @discardableResult
    static func restore(setKey: String) -> Int {
        guard AXIsProcessTrusted() else { return 0 }
        guard let record = LayoutStore.shared.record(for: setKey) else { return 0 }

        let displays = DisplayInfo.liveDisplays()
        let liveByBundle = Dictionary(grouping: WindowManager.currentWindows(), by: { $0.appBundleID })
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

        // Pass 1: exact, non-empty title match.
        for (i, layout) in restorable.enumerated() where assignment[i] == nil {
            guard !layout.windowTitle.isEmpty else { continue }
            if let w = available(layout.appBundleID).first(where: { $0.title == layout.windowTitle }) {
                claim(i, w)
            }
        }
        // Pass 2: same window index within the app.
        for (i, layout) in restorable.enumerated() where assignment[i] == nil {
            if let w = available(layout.appBundleID).first(where: { $0.index == layout.windowIndex }) {
                claim(i, w)
            }
        }
        // Pass 3: any remaining window of that app.
        for (i, layout) in restorable.enumerated() where assignment[i] == nil {
            if let w = available(layout.appBundleID).first { claim(i, w) }
        }

        var moved = 0
        for (i, layout) in restorable.enumerated() {
            guard let win = assignment[i], let disp = displaysByUUID[layout.displayUUID] else { continue }
            // Saved coords are relative to the display origin → map to its current position.
            let target = CGRect(x: disp.bounds.origin.x + layout.x,
                                y: disp.bounds.origin.y + layout.y,
                                width: layout.width, height: layout.height)
            // Already in place (a retry pass) — nothing to do.
            if win.frame.matches(target) { moved += 1; continue }
            if WindowManager.setFrame(win.element, target) { moved += 1 }
        }
        let unmatched = restorable.count - assignment.count
        if unmatched > 0 {
            NSLog("MonitorGlue: \(unmatched) saved window(s) had no matching open window yet")
        }
        NSLog("MonitorGlue: restore for '\(record.label)' — moved \(moved)/\(record.windows.count) saved window(s)")
        return moved
    }

}

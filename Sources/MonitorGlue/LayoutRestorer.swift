import AppKit

/// Repositions windows to their saved frames when a known monitor set reconnects.
/// Matching is best-effort: bundle ID is required, then exact title, then window index.
enum LayoutRestorer {

    @discardableResult
    static func restore(setKey: String) -> Int {
        guard AXIsProcessTrusted() else {
            Log.write("restore skipped — no Accessibility access")
            return 0
        }
        guard let record = LayoutStore.shared.record(for: setKey) else {
            Log.write("restore skipped — no saved layout for set '\(setKey)'")
            return 0
        }

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
            if win.frame.matches(target) {
                moved += 1
                alreadyInPlace += 1
                continue
            }
            let ok = WindowManager.setFrame(win.element, target)
            let actual = WindowManager.frame(of: win.element) ?? .zero
            if ok { moved += 1 }
            details.append("  \(ok ? "OK  " : "BAD ") \(layout.appName) idx=\(layout.windowIndex) via=\(matchedBy[i] ?? "?") '\(win.title.prefix(24))' want=\(str(target)) got=\(str(actual))")
        }

        if details.isEmpty {
            Log.write("restore '\(record.label)': nothing to do — \(alreadyInPlace)/\(restorable.count) already in place")
        } else {
            Log.write("restore '\(record.label)': \(record.windows.count) saved, \(restorable.count) on present displays, \(assignment.count) matched, \(alreadyInPlace) already in place")
            details.forEach { Log.write($0) }
            Log.write("restore done: \(moved)/\(restorable.count) placed")
        }
        return moved
    }

    private static func str(_ r: CGRect) -> String {
        "(\(Int(r.origin.x)),\(Int(r.origin.y)) \(Int(r.width))x\(Int(r.height)))"
    }

}

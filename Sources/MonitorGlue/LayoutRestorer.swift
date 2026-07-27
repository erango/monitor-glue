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

        var moved = 0
        var usedElements = Set<UInt>()  // Avoid moving the same window twice.

        for layout in record.windows {
            guard let disp = displaysByUUID[layout.displayUUID] else { continue }
            guard let candidates = liveByBundle[layout.appBundleID], !candidates.isEmpty else { continue }

            let match = bestMatch(for: layout, in: candidates, used: usedElements)
            guard let win = match else { continue }

            let token = UInt(bitPattern: ObjectIdentifier(win.element).hashValue)
            if usedElements.contains(token) { continue }

            // Saved coords are relative to the display origin → map to its current position.
            let target = CGRect(x: disp.bounds.origin.x + layout.x,
                                y: disp.bounds.origin.y + layout.y,
                                width: layout.width, height: layout.height)
            if WindowManager.setFrame(win.element, target) {
                usedElements.insert(token)
                moved += 1
            }
        }
        NSLog("MonitorGlue: restore for '\(record.label)' — moved \(moved)/\(record.windows.count) saved window(s)")
        return moved
    }

    private static func bestMatch(for layout: WindowLayout,
                                  in candidates: [LiveWindow],
                                  used: Set<UInt>) -> LiveWindow? {
        func free(_ w: LiveWindow) -> Bool {
            !used.contains(UInt(bitPattern: ObjectIdentifier(w.element).hashValue))
        }
        // 1. Exact title.
        if !layout.windowTitle.isEmpty,
           let m = candidates.first(where: { $0.title == layout.windowTitle && free($0) }) {
            return m
        }
        // 2. Window index.
        if let m = candidates.first(where: { $0.index == layout.windowIndex && free($0) }) {
            return m
        }
        // 3. Any free window of the app.
        return candidates.first(where: free)
    }
}

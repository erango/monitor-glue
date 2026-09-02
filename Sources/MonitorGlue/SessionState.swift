import CoreGraphics

/// Login-session facts that decide whether it is even possible to place windows.
enum SessionState {
    /// True while the screen is locked. The Accessibility API reports no windows at all in
    /// that state, so a restore attempted now places nothing — it is not a failure, just too
    /// early. Connecting a monitor at the lock screen is the common way into this.
    static var isScreenLocked: Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        if let locked = info["CGSSessionScreenIsLocked"] as? Bool { return locked }
        if let locked = info["CGSSessionScreenIsLocked"] as? Int { return locked == 1 }
        return false
    }
}

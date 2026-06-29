import AppKit
import CoreGraphics

/// A live, currently-connected display.
struct LiveDisplay {
    var displayID: CGDirectDisplayID
    var uuid: String
    var isBuiltin: Bool
    var localizedName: String
    var bounds: CGRect            // Global CG coords (top-left origin), in points.
    var widthPx: Int
    var heightPx: Int
}

enum DisplayInfo {
    /// Enumerate all online displays with stable UUIDs.
    static func liveDisplays() -> [LiveDisplay] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }

        let screensByNumber: [CGDirectDisplayID: NSScreen] = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
                guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                else { return nil }
                return (CGDirectDisplayID(truncating: n), screen)
            }
        )

        return ids.compactMap { id in
            guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
            let uuid = CFUUIDCreateString(nil, cfUUID) as String? ?? "\(id)"
            let bounds = CGDisplayBounds(id)
            let screen = screensByNumber[id]
            let name = screen?.localizedName ?? (CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)")
            return LiveDisplay(
                displayID: id,
                uuid: uuid,
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                localizedName: name,
                bounds: bounds,
                widthPx: Int(CGDisplayPixelsWide(id)),
                heightPx: Int(CGDisplayPixelsHigh(id))
            )
        }
    }

    /// External (non-builtin) displays only — those macOS mishandles on reconnect.
    static func externalDisplays() -> [LiveDisplay] {
        liveDisplays().filter { !$0.isBuiltin }
    }

    /// Stable key for the current set of external monitors: sorted UUIDs joined.
    /// Empty string when only the built-in display is present.
    static func monitorSetKey(for displays: [LiveDisplay]) -> String {
        displays.filter { !$0.isBuiltin }
            .map { $0.uuid }
            .sorted()
            .joined(separator: "|")
    }

    static func records(for displays: [LiveDisplay]) -> [DisplayInfoRecord] {
        displays.filter { !$0.isBuiltin }.map {
            DisplayInfoRecord(uuid: $0.uuid, localizedName: $0.localizedName,
                              widthPx: $0.widthPx, heightPx: $0.heightPx)
        }
    }
}

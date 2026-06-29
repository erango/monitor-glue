import Foundation

// MARK: - Persisted models

/// One physical display, keyed by its stable UUID.
struct DisplayInfoRecord: Codable, Hashable {
    var uuid: String
    var localizedName: String
    var widthPx: Int
    var heightPx: Int
}

/// A remembered window's saved frame on a specific external display.
struct WindowLayout: Codable, Hashable, Identifiable {
    var id: String { "\(appBundleID)#\(displayUUID)#\(windowIndex)#\(windowTitle)" }

    var appBundleID: String
    var appName: String
    var displayUUID: String
    var windowTitle: String
    var windowIndex: Int
    // Frame in AX global (top-left origin) coordinates.
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var updatedAt: Date

    var frame: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set { x = newValue.origin.x; y = newValue.origin.y; width = newValue.size.width; height = newValue.size.height }
    }
}

/// All remembered windows for one unique set of connected external monitors.
struct MonitorSetRecord: Codable, Identifiable {
    var id: String { key }
    /// Sorted, joined display UUIDs — the persistence key.
    var key: String
    var displays: [DisplayInfoRecord]
    var lastSeen: Date
    var windows: [WindowLayout]

    /// Human label like "DELL U2720Q + LG HDR 4K".
    var label: String {
        displays.map { $0.localizedName }.sorted().joined(separator: " + ")
    }
}

/// Top-level persisted document.
struct LayoutStoreData: Codable {
    var monitorSets: [String: MonitorSetRecord] = [:]
}

// MARK: - Store

/// Loads/saves the layout document to Application Support with atomic writes.
final class LayoutStore {
    static let shared = LayoutStore()

    private let queue = DispatchQueue(label: "com.erango.monitorglue.store")
    private(set) var data: LayoutStoreData

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("MonitorGlue", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("layouts.json")
        self.data = LayoutStore.load(from: fileURL)
    }

    private static func load(from url: URL) -> LayoutStoreData {
        guard let raw = try? Data(contentsOf: url) else { return LayoutStoreData() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(LayoutStoreData.self, from: raw)) ?? LayoutStoreData()
    }

    func save() {
        queue.sync {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let raw = try? encoder.encode(data) else { return }
            try? raw.write(to: fileURL, options: .atomic)
        }
    }

    /// Upsert a monitor set's metadata and merge in freshly captured windows.
    func upsert(setKey: String, displays: [DisplayInfoRecord], windows: [WindowLayout]) {
        queue.sync {
            var record = data.monitorSets[setKey]
                ?? MonitorSetRecord(key: setKey, displays: displays, lastSeen: Date(), windows: [])
            record.displays = displays
            record.lastSeen = Date()
            // Replace the full window snapshot for this set (latest layout wins).
            record.windows = windows
            data.monitorSets[setKey] = record
        }
        save()
    }

    func record(for setKey: String) -> MonitorSetRecord? {
        queue.sync { data.monitorSets[setKey] }
    }

    /// Load in-memory records without persisting — used by the gated UI preview harness.
    func injectForPreview(_ injected: LayoutStoreData) {
        queue.sync { data = injected }
    }

    func allSets() -> [MonitorSetRecord] {
        queue.sync { Array(data.monitorSets.values).sorted { $0.lastSeen > $1.lastSeen } }
    }

    func deleteAll() {
        queue.sync { data.monitorSets.removeAll() }
        save()
    }

    func deleteSet(key: String) {
        queue.sync { data.monitorSets[key] = nil }
        save()
    }

    func deleteWindow(setKey: String, windowID: String) {
        queue.sync {
            guard var record = data.monitorSets[setKey] else { return }
            record.windows.removeAll { $0.id == windowID }
            data.monitorSets[setKey] = record
        }
        save()
    }

    func deleteApp(setKey: String, bundleID: String) {
        queue.sync {
            guard var record = data.monitorSets[setKey] else { return }
            record.windows.removeAll { $0.appBundleID == bundleID }
            data.monitorSets[setKey] = record
        }
        save()
    }
}

import AppKit

/// "Report a Bug…": opens a GitHub issue prefilled with the environment details that
/// matter for this app, and reveals the log in Finder so it can be dragged into the issue.
///
/// The log is deliberately not pasted into the issue body. It lists window titles (chat
/// names, document and tab titles), so the reporter should look it over before it goes
/// public — and it would not fit in a URL anyway.
enum BugReport {
    private static let repository = "erango/monitor-glue"

    static func open() {
        var components = URLComponents(string: "https://github.com/\(repository)/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "labels", value: "bug"),
            URLQueryItem(name: "body", value: body()),
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
        NSWorkspace.shared.activateFileViewerSelecting([Log.fileURL])
    }

    #if DEBUG
    /// Development harness: the issue URL without opening it.
    static func previewURL() -> URL? {
        var components = URLComponents(string: "https://github.com/\(repository)/issues/new")!
        components.queryItems = [URLQueryItem(name: "labels", value: "bug"), URLQueryItem(name: "body", value: body())]
        return components.url
    }
    #endif

    private static func body() -> String {
        """
        **What happened?**


        **What did you expect instead?**


        **Steps to reproduce** (e.g. unplugged at home, plugged in at the office, woke from sleep…)


        **Log**
        Please attach `monitor-glue.log` — Finder just opened it for you, drag it into this box.
        It lists window titles, so skim it and remove anything private first.

        **Environment** (filled in by the app)
        \(environment())
        """
    }

    private static func environment() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let displays = DisplayInfo.liveDisplays().map {
            "\($0.localizedName) \($0.widthPx)×\($0.heightPx)\($0.isBuiltin ? " (built-in)" : "")"
        }
        let sets = LayoutStore.shared.allSets()
        return """
        - Monitor Glue \(version) (\(build))
        - macOS \(ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: "Version ", with: ""))
        - Mac: \(hardwareModel())
        - Displays: \(displays.joined(separator: ", "))
        - Accessibility granted: \(Permissions.shared.isTrusted ? "yes" : "no")
        - Remembered: \(sets.count) monitor set(s), \(sets.reduce(0) { $0 + $1.windows.count }) window(s)
        """
    }

    private static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}

import SwiftUI

struct ManagementView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: Permissions

    @State private var sets: [MonitorSetRecord] = []
    @State private var expandedSets: Set<String> = []
    @State private var expandedApps: Set<String> = []   // "setKey#bundleID"
    @State private var confirmDeleteAll = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if sets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sets) { set in
                            SetCard(set: set,
                                    expandedSets: $expandedSets,
                                    expandedApps: $expandedApps,
                                    onChange: reload)
                        }
                    }
                    .padding(14)
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .onAppear(perform: firstLoad)
        .frame(minWidth: 720, minHeight: 520)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remembered Monitors").font(.system(size: 15, weight: .semibold))
                Text(permissions.isTrusted ? "Accessibility access granted"
                                           : "Accessibility access needed")
                    .font(.system(size: 11))
                    .foregroundStyle(permissions.isTrusted ? Theme.green : Theme.orange)
            }
            Spacer()
            if !permissions.isTrusted {
                Button("Grant Access…") { permissions.requestAccess() }
                    .buttonStyle(.borderedProminent)
            }
            if !sets.isEmpty {
                Button(role: .destructive) {
                    confirmDeleteAll = true
                } label: {
                    HStack(spacing: 5) {
                        MGIcon.trash.frame(width: 13, height: 13)
                        Text("Delete All…")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .confirmationDialog("Delete all remembered layouts?",
                            isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                LayoutStore.shared.deleteAll(); reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This forgets every monitor set and window position. This can't be undone.")
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            MonitorGlyph(lineWidth: 1.5)
                .foregroundStyle(.tertiary)
                .frame(width: 46, height: 46)
            Text("Nothing remembered yet").font(.system(size: 15, weight: .semibold))
            Text("Connect an external monitor and arrange your app windows. Monitor Glue will remember their positions automatically.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func firstLoad() {
        reload()
        if let first = sets.first {
            expandedSets.insert(first.key)
            if let firstApp = SetCard.appsGrouped(first).first {
                expandedApps.insert("\(first.key)#\(firstApp.bundleID)")
            }
        }
    }

    private func reload() {
        sets = LayoutStore.shared.allSets()
        model.refreshStatus()
    }
}

// MARK: - Set card

private struct SetCard: View {
    let set: MonitorSetRecord
    @Binding var expandedSets: Set<String>
    @Binding var expandedApps: Set<String>
    let onChange: () -> Void

    static func appsGrouped(_ set: MonitorSetRecord)
        -> [(bundleID: String, name: String, windows: [WindowLayout])] {
        Dictionary(grouping: set.windows, by: { $0.appBundleID })
            .map { (bundleID, wins) in
                (bundleID, wins.first?.appName ?? bundleID, wins.sorted { $0.windowIndex < $1.windowIndex })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var isOpen: Bool { expandedSets.contains(set.key) }
    private var apps: [(bundleID: String, name: String, windows: [WindowLayout])] {
        Self.appsGrouped(set)
    }

    var body: some View {
        VStack(spacing: 0) {
            setHeader
            if isOpen {
                Divider()
                ForEach(apps, id: \.bundleID) { app in
                    appSection(app)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Theme.hairline.opacity(0.6)))
        .shadow(color: .black.opacity(0.07), radius: 2.5, y: 1)
    }

    private var setHeader: some View {
        Button {
            toggle(&expandedSets, set.key)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.controlFill)
                    .frame(width: 32, height: 32)
                    .overlay(MonitorGlyph(showPin: false)
                        .foregroundStyle(.secondary)
                        .frame(width: 17, height: 17))
                VStack(alignment: .leading, spacing: 2) {
                    Text(set.label.isEmpty ? "Unknown displays" : set.label)
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(metaLine).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(apps.count) app\(apps.count == 1 ? "" : "s") · \(set.windows.count) window\(set.windows.count == 1 ? "" : "s")")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                DeleteButton(icon: MGIcon.trash, help: "Forget this entire monitor set") {
                    LayoutStore.shared.deleteSet(key: set.key); onChange()
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var metaLine: String {
        let res = set.displays.map { "\($0.widthPx) × \($0.heightPx)" }.joined(separator: "  ·  ")
        return "\(res)  ·  Last seen \(set.lastSeen.formatted(date: .abbreviated, time: .shortened))"
    }

    private func appSection(_ app: (bundleID: String, name: String, windows: [WindowLayout]))
        -> some View {
        let appKey = "\(set.key)#\(app.bundleID)"
        let open = expandedApps.contains(appKey)
        return VStack(spacing: 0) {
            Button {
                toggle(&expandedApps, appKey)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                    AppIconTile(bundleID: app.bundleID, appName: app.name, size: 22)
                    Text(app.name).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(app.windows.count)").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    DeleteButton(icon: MGIcon.trash, help: "Forget this app on this monitor set") {
                        LayoutStore.shared.deleteApp(setKey: set.key, bundleID: app.bundleID); onChange()
                    }
                }
                .padding(.leading, 40).padding(.trailing, 13).padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                ForEach(app.windows) { win in windowRow(win) }
            }
        }
    }

    private func windowRow(_ win: WindowLayout) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "macwindow").foregroundStyle(.secondary)
            Text(win.windowTitle.isEmpty ? "Window \(win.windowIndex + 1)" : win.windowTitle)
                .font(.system(size: 12.5)).lineLimit(1)
            Spacer()
            Text(verbatim: "\(Int(win.x)), \(Int(win.y))  ·  \(Int(win.width))×\(Int(win.height))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            DeleteButton(icon: MGIcon.xCircle, help: "Forget this window") {
                LayoutStore.shared.deleteWindow(setKey: set.key, windowID: win.id); onChange()
            }
        }
        .padding(.leading, 72).padding(.trailing, 13).padding(.vertical, 5)
    }

    private func toggle(_ set: inout Set<String>, _ key: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if set.contains(key) { set.remove(key) } else { set.insert(key) }
        }
    }
}

/// Tertiary→red delete affordance used at every level of the tree.
private struct DeleteButton: View {
    let icon: SVGIcon
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 14, height: 14)
                .foregroundStyle(hovering ? Theme.red : Color.secondary.opacity(0.6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

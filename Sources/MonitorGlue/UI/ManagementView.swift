import SwiftUI

struct ManagementView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: Permissions

    @State private var sets: [MonitorSetRecord] = []
    @State private var confirmDeleteAll = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if sets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sets) { monitorSet in
                        MonitorSetSection(monitorSet: monitorSet, onChange: reload)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear(perform: reload)
        .frame(minWidth: 640, minHeight: 460)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remembered Monitors").font(.title2.weight(.semibold))
                Text(permissions.isTrusted ? "Accessibility access granted"
                                           : "Accessibility access needed")
                    .font(.caption)
                    .foregroundStyle(permissions.isTrusted ? Color.secondary : Color.orange)
            }
            Spacer()
            if !permissions.isTrusted {
                Button("Grant Access…") { permissions.requestAccess() }
            }
            Button(role: .destructive) {
                confirmDeleteAll = true
            } label: {
                Label("Delete All", systemImage: "trash")
            }
            .disabled(sets.isEmpty)
        }
        .padding()
        .confirmationDialog("Delete all remembered layouts?",
                            isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                LayoutStore.shared.deleteAll(); reload()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nothing remembered yet").font(.headline)
            Text("Connect an external monitor and arrange your app windows.\nMonitor Glue will remember their positions automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() {
        sets = LayoutStore.shared.allSets()
        model.refreshStatus()
    }
}

private struct MonitorSetSection: View {
    let monitorSet: MonitorSetRecord
    let onChange: () -> Void

    private var byApp: [(bundleID: String, name: String, windows: [WindowLayout])] {
        let groups = Dictionary(grouping: monitorSet.windows, by: { $0.appBundleID })
        return groups.map { (bundleID, wins) in
            (bundleID, wins.first?.appName ?? bundleID, wins.sorted { $0.windowIndex < $1.windowIndex })
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Section {
            ForEach(byApp, id: \.bundleID) { app in
                DisclosureGroup {
                    ForEach(app.windows) { win in
                        windowRow(win)
                    }
                } label: {
                    HStack {
                        Label(app.name, systemImage: "app.dashed")
                        Spacer()
                        Text("\(app.windows.count)").foregroundStyle(.secondary)
                        Button {
                            LayoutStore.shared.deleteApp(setKey: monitorSet.key, bundleID: app.bundleID); onChange()
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("Forget this app on this monitor set")
                    }
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(monitorSet.label.isEmpty ? "Unknown displays" : monitorSet.label)
                        .font(.headline)
                    Text("\(resolutions) · last seen \(monitorSet.lastSeen.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    LayoutStore.shared.deleteSet(key: monitorSet.key); onChange()
                } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Forget this entire monitor set")
            }
        }
    }

    private var resolutions: String {
        monitorSet.displays.map { "\($0.widthPx)×\($0.heightPx)" }.joined(separator: ", ")
    }

    private func windowRow(_ win: WindowLayout) -> some View {
        HStack {
            Image(systemName: "macwindow").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(win.windowTitle.isEmpty ? "Window \(win.windowIndex + 1)" : win.windowTitle)
                    .lineLimit(1)
                Text("x \(Int(win.x)), y \(Int(win.y)) · \(Int(win.width))×\(Int(win.height))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                LayoutStore.shared.deleteWindow(setKey: monitorSet.key, windowID: win.id); onChange()
            } label: { Image(systemName: "xmark.circle") }
            .buttonStyle(.borderless)
            .help("Forget this window")
        }
        .padding(.leading, 16)
    }
}

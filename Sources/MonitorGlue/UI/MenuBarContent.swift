import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: Permissions
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.tint)
                Text("Monitor Glue").font(.headline)
            }

            Divider()

            if !permissions.isTrusted {
                permissionWarning
            } else {
                Label(model.statusText, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Divider()

            Button {
                model.restoreNow()
            } label: {
                Label("Restore windows now", systemImage: "arrow.uturn.backward")
            }
            .disabled(!permissions.isTrusted || model.currentSetKey.isEmpty)

            Button {
                openWindow(id: "manager")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Manager…", systemImage: "rectangle.stack")
            }

            Divider()

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Monitor Glue", systemImage: "power")
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear { model.refreshStatus() }
    }

    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout.weight(.semibold))
            Text("Monitor Glue needs Accessibility access to read and move app windows.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant access…") {
                permissions.requestAccess()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

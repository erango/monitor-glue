import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: Permissions
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()

            if permissions.isTrusted {
                statusBlock
            } else {
                permissionWarning
            }

            Divider()

            MenuRow(title: "Restore windows now", icon: MGIcon.restore,
                    shortcut: "⌘R", disabled: !canRestore) {
                model.restoreNow()
            }
            MenuRow(title: "Open Manager…", icon: MGIcon.manager) {
                openWindow(id: "manager")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            MenuRow(title: "Quit Monitor Glue", icon: MGIcon.power, shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }

            Divider()
            footer
        }
        .padding(12)
        .frame(width: 320)
        .onAppear { model.refreshStatus() }
    }

    private var canRestore: Bool {
        permissions.isTrusted && !model.currentSetKey.isEmpty
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            MonitorGlyph()
                .foregroundStyle(Theme.accent)
                .frame(width: 17, height: 17)
            Text("Monitor Glue").font(.system(size: 14.5, weight: .semibold))
        }
    }

    // MARK: Status

    private var statusBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.connectedExternalDisplays > 0
                     ? "Tracking · \(model.connectedExternalDisplays) display\(model.connectedExternalDisplays == 1 ? "" : "s") connected"
                     : "Idle · built-in display only")
                    .font(.system(size: 13, weight: .semibold))
                if model.connectedExternalDisplays > 0, !model.currentSetLabel.isEmpty {
                    Text("\(model.currentSetLabel) · \(model.currentSetWindowCount) window\(model.currentSetWindowCount == 1 ? "" : "s")")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Text("\(model.rememberedCount) monitor set\(model.rememberedCount == 1 ? "" : "s") · \(model.totalWindowsRemembered) window\(model.totalWindowsRemembered == 1 ? "" : "s") remembered")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.orange)
                Text("Accessibility access required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.orange)
            }
            Text("Monitor Glue needs Accessibility access to read and move app windows.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant access…") { permissions.requestAccess() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.orange.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.orange.opacity(0.34)))
        )
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                Text("Made with ")
                Text("♥").foregroundStyle(Theme.coral)
                Text(" by ")
                Link("@erango", destination: URL(string: "https://github.com/erango")!)
                    .foregroundStyle(Theme.accent)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://ko-fi.com/erango")!) {
                HStack(spacing: 7) {
                    MGIcon.kofiCup.frame(width: 17, height: 16)
                    Text("Buy me a coffee").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.kofi))
                .shadow(color: Theme.kofi.opacity(0.4), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Full-width menu row with accent hover highlight and an optional trailing shortcut.
private struct MenuRow: View {
    let title: String
    let icon: SVGIcon
    var shortcut: String? = nil
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                icon.frame(width: 14, height: 14).frame(width: 17)
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 8)
                if let shortcut {
                    Text(shortcut).font(.system(size: 11)).opacity(0.55)
                }
            }
            .foregroundStyle(disabled ? AnyShapeStyle(.tertiary)
                             : (hovering ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)))
            .padding(.vertical, 6).padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering && !disabled ? Theme.accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering = $0 && !disabled }
    }
}

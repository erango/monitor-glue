import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: Permissions
    @StateObject private var loginItem = LoginItem.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Native menus keep their items flush against each other and reserve the breathing
        // room for the separators, so rows sit in zero-spacing stacks and each divider
        // carries its own small margin.
        VStack(alignment: .leading, spacing: 0) {
            header
            separator

            if permissions.isTrusted {
                statusBlock
            } else {
                permissionWarning
            }

            separator

            VStack(alignment: .leading, spacing: 0) {
                MenuRow(title: "Restore windows now", icon: MGIcon.restore,
                        shortcut: "⌘R", disabled: !canRestore,
                        action: choose { model.restoreNow() })
                MenuRow(title: "Open Manager…", icon: MGIcon.manager,
                        action: choose {
                            openWindow(id: "manager")
                            NSApp.activate(ignoringOtherApps: true)
                        })
            }

            separator

            launchAtLoginRow

            separator

            MenuRow(title: "Quit Monitor Glue", icon: MGIcon.power, shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }

            separator
            footer
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(width: 320)
        .onAppear {
            model.refreshStatus()
            loginItem.refresh()
            if ProcessInfo.processInfo.environment["MG_LOG_WINDOWS"] != nil {
                let classes = NSApp.windows
                    .filter { $0.isVisible }
                    .map { "\(type(of: $0)) visible=\($0.isVisible) key=\($0.isKeyWindow) level=\($0.level.rawValue)" }
                Log.write("menu opened; visible windows: \(classes.joined(separator: " || "))")
            }
        }
    }

    /// Menu separator: a hairline with the small symmetric margin AppKit uses.
    private var separator: some View {
        Divider().padding(.vertical, 5)
    }

    /// A checkable item, the way AppKit menus do it: an ordinary highlightable row with a
    /// leading checkmark when on (rather than an embedded checkbox control, which cannot
    /// highlight on hover and reads as a form field inside a menu).
    private var launchAtLoginRow: some View {
        MenuRow(title: "Launch at login", icon: nil,
                checked: loginItem.isEnabled,
                action: choose { loginItem.setEnabled(!loginItem.isEnabled) })
    }

    private var canRestore: Bool {
        permissions.isTrusted && !model.currentSetKey.isEmpty
    }

    /// Choosing an item in a real menu closes it. `MenuBarExtra`'s window style is a plain
    /// panel rather than an `NSMenu`, so it stays open until dismissed explicitly.
    private func closeMenu() {
        dismiss()   // documented path; a no-op in some macOS versions for this scene type
        for window in NSApp.windows where window.isVisible
            && String(describing: type(of: window)).contains("MenuBarExtraWindow") {
            window.close()
        }
    }

    /// Run a menu item's action, then close the menu, the way an AppKit menu behaves.
    private func choose(_ action: @escaping () -> Void) -> () -> Void {
        {
            action()
            closeMenu()
        }
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
            Button("Grant access…", action: choose { permissions.requestAccess() })
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
                HoverLink(url: URL(string: "https://github.com/erango")!, onOpen: closeMenu) { hovering in
                    Text("@erango")
                        .foregroundStyle(Theme.accent)
                        .underline(hovering)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)

            HoverLink(url: URL(string: "https://ko-fi.com/erango")!, onOpen: closeMenu) { hovering in
                HStack(spacing: 7) {
                    MGIcon.kofiCup.frame(width: 17, height: 16)
                    Text("Buy me a coffee").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6).padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.kofi)
                        .brightness(hovering ? 0.07 : 0)
                )
                .shadow(color: Theme.kofi.opacity(hovering ? 0.55 : 0.4),
                        radius: hovering ? 6 : 4, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A link that exposes its hover state to its label. SwiftUI's `Link` reports no hover, which
/// is why the Ko-fi button felt dead; a plain `Button` with `onHover` behaves like the rows.
///
/// Deliberately does not touch `NSCursor`: push/pop leaks a stuck pointing-hand cursor
/// system-wide if the popover closes while the pointer is still inside, and AppKit menus
/// don't change the cursor anyway.
private struct HoverLink<Label: View>: View {
    let url: URL
    var onOpen: () -> Void = {}
    @ViewBuilder let label: (Bool) -> Label

    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
            onOpen()
        } label: {
            label(hovering)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// Full-width menu row with accent hover highlight and an optional trailing shortcut.
private struct MenuRow: View {
    let title: String
    /// Leading glyph. `nil` for checkable items, which use the checkmark slot instead.
    let icon: SVGIcon?
    var shortcut: String? = nil
    var disabled: Bool = false
    /// When non-nil the row is checkable and shows a checkmark in the leading slot when true.
    var checked: Bool? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                leading.frame(width: 17)
                Text(title).font(.system(size: 13))
                Spacer(minLength: 8)
                if let shortcut {
                    Text(shortcut).font(.system(size: 11)).opacity(0.55)
                }
            }
            .foregroundStyle(disabled ? AnyShapeStyle(.tertiary)
                             : (hovering ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)))
            // ~22pt tall, matching an AppKit menu item.
            .padding(.vertical, 4).padding(.horizontal, 8)
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

    @ViewBuilder
    private var leading: some View {
        if let icon {
            icon.frame(width: 14, height: 14)
        } else if let checked {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .opacity(checked ? 1 : 0)
        }
    }
}

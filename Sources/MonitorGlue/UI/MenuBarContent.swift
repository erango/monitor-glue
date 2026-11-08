import SwiftUI

/// The menu-bar menu. Rendered with `.menuBarExtraStyle(.menu)`, so SwiftUI builds a real
/// `NSMenu` from these views: system font, spacing, highlight, submenus, checkmarks and
/// keyboard shortcuts all come from AppKit, and it looks like every other menu-bar menu.
/// That only works with menu-shaped content - buttons, toggles, pickers, text and dividers.
struct MenuBarContent: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: Permissions
    @ObservedObject private var loginItem = LoginItem.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage(MenuBarIconStyle.defaultsKey) private var iconStyle = MenuBarIconStyle.default

    var body: some View {
        status

        Divider()

        Button {
            model.restoreNow()
        } label: {
            Label("Restore Windows Now", systemImage: "arrow.counterclockwise")
        }
        .keyboardShortcut("r")
        .disabled(!canRestore)

        Button {
            openWindow(id: "manager")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Open Manager…", systemImage: "list.bullet.rectangle")
        }
        .keyboardShortcut(",")

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }))
        Toggle("Check for Updates Automatically", isOn: Binding(
            get: { Updater.shared.automaticallyChecks },
            set: { Updater.shared.automaticallyChecks = $0 }))
        Picker("Menu Bar Icon", selection: $iconStyle) {
            ForEach(MenuBarIconStyle.allCases) { style in
                Label {
                    Text(style.title)
                } icon: {
                    Image(nsImage: AppGlyph.menuBarTemplate(style))
                }
                .tag(style)
            }
        }
        .pickerStyle(.menu)

        Divider()

        Button {
            Updater.shared.checkForUpdates()
        } label: {
            Label("Check for Updates…", systemImage: "arrow.down.circle")
        }
        Button {
            BugReport.open()
        } label: {
            Label("Report a Bug…", systemImage: "ladybug")
        }
        Button {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/erango")!)
        } label: {
            Label("Buy Me a Coffee…", systemImage: "cup.and.saucer")
        }
        Button("About Monitor Glue") { showAbout() }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit Monitor Glue", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    private var canRestore: Bool {
        permissions.isTrusted && !model.currentSetKey.isEmpty
    }

    // MARK: Status

    /// Status lines at the top, as disabled items - the same way other menu-bar apps show
    /// state ("Running", "Connected to …").
    @ViewBuilder
    private var status: some View {
        if permissions.isTrusted {
            Label {
                Text(model.connectedExternalDisplays > 0
                     ? "Tracking \(model.connectedExternalDisplays) display\(model.connectedExternalDisplays == 1 ? "" : "s")"
                     : "Tracking the built-in display")
            } icon: {
                Image(nsImage: Self.statusDot(.systemGreen))
            }
            if !model.currentSetLabel.isEmpty {
                Text("\(model.currentSetLabel) · \(model.currentSetWindowCount) window\(model.currentSetWindowCount == 1 ? "" : "s")")
            }
        } else {
            Label {
                Text("Accessibility access needed")
            } icon: {
                Image(nsImage: Self.statusDot(.systemOrange))
            }
            Button("Grant Access…") { permissions.requestAccess() }
        }
    }

    /// A small coloured dot. Not a template image, so the menu keeps its colour.
    private static func statusDot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: About

    private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Made with ♥ by ",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        credits.append(NSAttributedString(
            string: "@erango",
            attributes: [.font: NSFont.systemFont(ofSize: 11),
                         .link: URL(string: "https://github.com/erango")!]))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered,
                             range: NSRange(location: 0, length: credits.length))
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

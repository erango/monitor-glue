import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var permissions = Permissions.shared
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            BrandSquircle(size: 74)
                .padding(.top, 8)

            Text("Welcome to Monitor Glue")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)

            Text("Monitor Glue keeps your windows glued to the right monitor — and puts them back when you reconnect a display it recognizes.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380)

            permissionCallout

            Text("Monitor Glue never reads window contents — only their size and position.")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)

            Button {
                permissions.requestAccess()
            } label: {
                Text("Open Accessibility Settings…")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.vertical, 4).padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("I'll do this later") { onDismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.accent)

            footer
        }
        .padding(28)
        .frame(width: 540)
        .onChange(of: permissions.isTrusted) { _, trusted in
            if trusted { onDismiss() }
        }
    }

    private var permissionCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "accessibility")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("One permission: Accessibility")
                    .font(.system(size: 13.5, weight: .semibold))
                Text("It lets Monitor Glue read and move other apps' windows — the only thing it needs to restore your layout.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.controlFill))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("**How it works ·** Arrange your windows once. Reconnect a monitor it knows, and they snap back automatically.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        }
    }
}

/// Hosts the onboarding view in a standalone window so it can appear at launch
/// (no SwiftUI scene / openWindow plumbing needed for an accessory app).
final class OnboardingController {
    static let shared = OnboardingController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(onDismiss: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.title = "Welcome to Monitor Glue"
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

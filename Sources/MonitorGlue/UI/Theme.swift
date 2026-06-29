import SwiftUI
import AppKit

/// Shared visual language from the design handoff. Prefer system-semantic colors so
/// light/dark adapt automatically; brand colors are fixed.
enum Theme {
    // Brand
    static let accent = Color.accentColor
    static let brandTop = Color(red: 0x3a/255, green: 0x8b/255, blue: 0xff/255)
    static let brandBottom = Color(red: 0x14/255, green: 0x57/255, blue: 0xd8/255)
    static let coral = Color(red: 0xFF/255, green: 0x5A/255, blue: 0x5F/255)
    static let kofi = Color(red: 0x29/255, green: 0xAB/255, blue: 0xE0/255)

    // Status (system-semantic)
    static let green = Color(nsColor: .systemGreen)
    static let orange = Color(nsColor: .systemOrange)
    static let red = Color(nsColor: .systemRed)

    // Fills / hairlines
    static let controlFill = Color(nsColor: .quaternaryLabelColor).opacity(0.6)
    static let hairline = Color(nsColor: .separatorColor)

    /// Deterministic accent color for an app's monogram-tile fallback (when no icon).
    static func monogramColor(for bundleID: String) -> Color {
        let palette: [Color] = [
            Color(red: 0x2E/255, green: 0x86/255, blue: 0xFF/255),
            Color(red: 0x4E/255, green: 0x7C/255, blue: 0xC4/255),
            Color(red: 0x97/255, green: 0x47/255, blue: 0xFF/255),
            Color(red: 0x5B/255, green: 0x2C/255, blue: 0x5E/255),
            Color(red: 0x1F/255, green: 0x8B/255, blue: 0xEA/255),
            Color(red: 0x3A/255, green: 0x3F/255, blue: 0x49/255),
        ]
        let h = abs(bundleID.hashValue)
        return palette[h % palette.count]
    }
}

/// App + menu-bar glyph rendering.
enum AppGlyph {
    /// Monochrome template image for the menu-bar item: a display with a pin badge.
    static func menuBarTemplate() -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let display = NSImage(systemSymbolName: "display", accessibilityDescription: "display")?
                .withSymbolConfiguration(cfg) {
                display.draw(in: NSRect(x: 0, y: 1, width: 16, height: 14))
            }
            let pinCfg = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            if let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "pinned")?
                .withSymbolConfiguration(pinCfg) {
                pin.draw(in: NSRect(x: 11, y: 8, width: 8, height: 8))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Brand app-icon squircle used in onboarding and the menu header — a white display+pin
/// glyph on the brand-blue gradient.
struct BrandSquircle: View {
    var size: CGFloat = 74
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Theme.brandTop, Theme.brandBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "display")
                .font(.system(size: size * 0.42, weight: .regular))
                .foregroundStyle(.white)
            Image(systemName: "pin.fill")
                .font(.system(size: size * 0.20, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: size * 0.20, y: -size * 0.05)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.brandBottom.opacity(0.45), radius: size * 0.12, y: size * 0.05)
    }
}

/// App icon for a running app by bundle ID; falls back to a colored monogram tile.
struct AppIconTile: View {
    let bundleID: String
    let appName: String
    var size: CGFloat = 22

    var body: some View {
        if let icon = Self.icon(for: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(Theme.monogramColor(for: bundleID))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(appName.first ?? "?").uppercased())
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }

    private static func icon(for bundleID: String) -> NSImage? {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) else { return nil }
        return app.icon
    }
}

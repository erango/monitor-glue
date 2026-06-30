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

/// The Monitor Glue brand mark: a monitor on a stand with a location-pin centered in the
/// screen. Stroked outline in the current foreground color (matches the design handoff SVG,
/// viewBox 0 0 24 24). `showPin` off → a plain monitor (used for management list tiles).
struct MonitorGlyph: View {
    var showPin: Bool = true
    var lineWidth: CGFloat = 1.7   // in the 24-unit design space

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 24
            ZStack {
                Path { p in
                    // Screen.
                    p.addRoundedRect(in: CGRect(x: 2.6 * s, y: 3.4 * s, width: 18.8 * s, height: 13 * s),
                                     cornerSize: CGSize(width: 2.3 * s, height: 2.3 * s))
                    // Stand base + neck.
                    p.move(to: CGPoint(x: 9 * s, y: 20.4 * s)); p.addLine(to: CGPoint(x: 15 * s, y: 20.4 * s))
                    p.move(to: CGPoint(x: 12 * s, y: 16.4 * s)); p.addLine(to: CGPoint(x: 12 * s, y: 20.4 * s))
                    // Pin stem.
                    if showPin { p.move(to: CGPoint(x: 12 * s, y: 10.9 * s)); p.addLine(to: CGPoint(x: 12 * s, y: 14 * s)) }
                }
                .stroke(style: StrokeStyle(lineWidth: lineWidth * s, lineCap: .round, lineJoin: .round))

                // Pin head.
                if showPin {
                    Circle()
                        .frame(width: 4.6 * s, height: 4.6 * s)
                        .position(x: 12 * s, y: 8.6 * s)
                }
            }
        }
    }
}

/// App + menu-bar glyph rendering.
enum AppGlyph {
    /// Monochrome template image for the menu-bar item (the brand monitor+pin mark).
    @MainActor static func menuBarTemplate() -> NSImage {
        let renderer = ImageRenderer(
            content: MonitorGlyph(lineWidth: 1.9)
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .padding(.horizontal, 1)
        )
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        return image
    }
}

/// Brand app-icon squircle (onboarding + header) — the white brand mark on the brand gradient.
struct BrandSquircle: View {
    var size: CGFloat = 74
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Theme.brandTop, Theme.brandBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            MonitorGlyph(lineWidth: 1.7)
                .foregroundStyle(.white)
                .frame(width: size * 0.52, height: size * 0.52)
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

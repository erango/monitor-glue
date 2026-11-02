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

/// The glyphs a user can pick for the menu-bar item. The bottle is the brand mark; the
/// monitor was the original one, kept for anyone who has grown used to it. A monitor alone
/// got lost among the display utilities many people also keep in their menu bar.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case bottle, pinnedWindow, monitor

    static let defaultsKey = "menuBarIcon"
    static let `default` = MenuBarIconStyle.bottle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottle: return "Glue bottle"
        case .pinnedWindow: return "Pinned window"
        case .monitor: return "Monitor"
        }
    }
}

/// Glue bottle beside a drop: the Monitor Glue brand mark (viewBox 0 0 24 24).
struct BottleGlyph: View {
    var lineWidth: CGFloat = 1.8

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 24
            ZStack {
                Path { p in
                    p.addPath(SVGPathParser.path("M5.8 10.6 7.2 7.6h4.4l1.4 3", scale: s))     // shoulder
                    p.addRoundedRect(in: CGRect(x: 3.9 * s, y: 10.6 * s, width: 11 * s, height: 10.6 * s),
                                     cornerSize: CGSize(width: 2.4 * s, height: 2.4 * s))   // body
                    p.addPath(SVGPathParser.path("M8.1 7.6 8.8 3.1H10l.7 4.5", scale: s))      // nozzle
                    p.addPath(SVGPathParser.path("M7 15.6h4.8", scale: s))                     // label
                }
                .stroke(style: StrokeStyle(lineWidth: lineWidth * s, lineCap: .round, lineJoin: .round))

                SVGPathParser.path("M20.4 10.4c0 1.2-.9 2.1-2 2.1s-2-.9-2-2.1c0-1.5 2-3.6 2-3.6s2 2.1 2 3.6Z", scale: s)
                    .fill()                                                                    // drop
            }
        }
    }
}

/// A window held in place by a push pin (viewBox 0 0 24 24).
struct PinnedWindowGlyph: View {
    var lineWidth: CGFloat = 1.8

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 24
            Path { p in
                p.addRoundedRect(in: CGRect(x: 2.8 * s, y: 7.5 * s, width: 15.4 * s, height: 12.5 * s),
                                 cornerSize: CGSize(width: 2 * s, height: 2 * s))
                p.addPath(SVGPathParser.path("M2.8 10.8h15.4", scale: s))
                // The pin, tilted 40° about its point of contact.
                var pin = Path()
                pin.addRoundedRect(in: CGRect(x: 15.8 * s, y: 1.2 * s, width: 4.4 * s, height: 2 * s),
                                   cornerSize: CGSize(width: 0.8 * s, height: 0.8 * s))
                pin.addPath(SVGPathParser.path("M16.6 3.2 16 6.6h4l-.6-3.4", scale: s))
                pin.addPath(SVGPathParser.path("M18 6.6v4", scale: s))
                let pivot = CGPoint(x: 18 * s, y: 6 * s)
                let tilt = CGAffineTransform(translationX: pivot.x, y: pivot.y)
                    .rotated(by: 40 * .pi / 180)
                    .translatedBy(x: -pivot.x, y: -pivot.y)
                p.addPath(pin, transform: tilt)
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth * s, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Whichever glyph the user picked for the menu bar, in the current foreground color.
struct MenuBarGlyph: View {
    let style: MenuBarIconStyle
    var lineWidth: CGFloat = 1.8

    var body: some View {
        switch style {
        case .bottle: BottleGlyph(lineWidth: lineWidth)
        case .pinnedWindow: PinnedWindowGlyph(lineWidth: lineWidth)
        case .monitor: MonitorGlyph(lineWidth: lineWidth)
        }
    }
}

/// App + menu-bar glyph rendering.
enum AppGlyph {
    /// Monochrome template image for the menu-bar item.
    @MainActor static func menuBarTemplate(_ style: MenuBarIconStyle = .default) -> NSImage {
        let renderer = ImageRenderer(
            content: MenuBarGlyph(style: style, lineWidth: 1.9)
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

/// Brand app-icon squircle (onboarding) — the white brand mark on the brand gradient.
struct BrandSquircle: View {
    var size: CGFloat = 74
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Theme.brandTop, Theme.brandBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            BottleGlyph(lineWidth: 1.7)
                .foregroundStyle(.white)
                .frame(width: size * 0.56, height: size * 0.56)
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

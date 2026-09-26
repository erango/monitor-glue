// Renders the Monitor Glue explainer animation (docs/demo.gif) to a looping GIF.
// Layout is authored on a 960x540 canvas and rendered at SCALE.
//
//   swiftc -O -o /tmp/make_demo Scripts/make_demo.swift && /tmp/make_demo docs/demo.gif
//
// A second argument (a directory) also writes key frames as PNGs for review.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let W: CGFloat = 960, H: CGFloat = 540
let SCALE: CGFloat = 4.0 / 3.0            // 1280x720 output
let FPS: Double = 20
let DURATION: Double = 9.0

// MARK: palette
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let bg = rgb(0xF4F6FA)
let bezel = rgb(0x2A2D34)
let desktop = rgb(0xDFE6F2)
let screenOff = rgb(0x3B3F48)
let ink = rgb(0x22252B)
let muted = rgb(0x6B7280)
let accent = rgb(0x0A6CF5)

// MARK: geometry
let laptopScreen = CGRect(x: 70, y: 208, width: 300, height: 190)
let laptopInner = laptopScreen.insetBy(dx: 8, dy: 8)
let monitorScreen = CGRect(x: 446, y: 70, width: 450, height: 285)
let monitorInner = monitorScreen.insetBy(dx: 10, dy: 10)
let menuBarH: CGFloat = 13

struct Win {
    let color: NSColor
    let kind: Int            // 0 browser, 1 terminal, 2 chat, 3 notes
    let home: CGRect         // arranged position
    let pile: CGRect         // where macOS dumps it
    let delay: Double        // stagger
}

let wins: [Win] = [
    Win(color: rgb(0x3A86FF), kind: 0,
        home: CGRect(x: monitorInner.minX + 8, y: monitorInner.minY + menuBarH + 8, width: 272, height: 238),
        pile: CGRect(x: laptopInner.minX + 30, y: laptopInner.minY + menuBarH + 8, width: 190, height: 140),
        delay: 0.00),
    Win(color: rgb(0x23262D), kind: 1,
        home: CGRect(x: monitorInner.minX + 290, y: monitorInner.minY + menuBarH + 8, width: 132, height: 128),
        pile: CGRect(x: laptopInner.minX + 70, y: laptopInner.minY + menuBarH + 22, width: 150, height: 110),
        delay: 0.08),
    Win(color: rgb(0x7B5CFA), kind: 2,
        home: CGRect(x: monitorInner.minX + 290, y: monitorInner.minY + menuBarH + 146, width: 132, height: 100),
        pile: CGRect(x: laptopInner.minX + 108, y: laptopInner.minY + menuBarH + 40, width: 140, height: 104),
        delay: 0.16),
]
// Stays on the laptop the whole time (Monitor Glue leaves the built-in screen alone).
let notes = Win(color: rgb(0xFFC23D), kind: 3,
                home: CGRect(x: laptopInner.minX + 12, y: laptopInner.minY + menuBarH + 14, width: 96, height: 74),
                pile: CGRect(x: laptopInner.minX + 12, y: laptopInner.minY + menuBarH + 14, width: 96, height: 74),
                delay: 0)

// MARK: timeline (seconds)
let tUnplug = 1.6, tUnplugEnd = 2.0
let tPileStart = 2.1, tPileEnd = 3.0
let tPlug = 4.1, tPlugEnd = 4.5
let tPulse = 4.55, tPulseEnd = 5.05
let tBackStart = 5.1, tBackEnd = 6.2

let captions: [(Double, Double, String)] = [
    (0.0, 1.55, "Your windows, just where you want them"),
    (1.55, 4.05, "Unplug the monitor… and macOS piles everything onto the laptop"),
    (4.05, 6.3, "Plug it back in — Monitor Glue remembers"),
    (6.3, 9.0, "Every window back on its monitor, same place, same size"),
]

// MARK: helpers
func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
func progress(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
func ease(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func lerp(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * CGFloat(p) }
func lerp(_ a: CGRect, _ b: CGRect, _ p: Double) -> CGRect {
    CGRect(x: lerp(a.minX, b.minX, p), y: lerp(a.minY, b.minY, p),
           width: lerp(a.width, b.width, p), height: lerp(a.height, b.height, p))
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func drawWindow(_ w: Win, _ r: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 8
    shadow.shadowOffset = NSSize(width: 0, height: -3)
    shadow.set()
    w.color.setFill()
    rounded(r, 6).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Title bar + traffic lights.
    let bar = CGRect(x: r.minX, y: r.minY, width: r.width, height: min(12, r.height * 0.14))
    NSGraphicsContext.saveGraphicsState()
    rounded(r, 6).addClip()
    NSColor.white.withAlphaComponent(w.kind == 1 ? 0.10 : 0.22).setFill()
    bar.fill()
    NSGraphicsContext.restoreGraphicsState()
    let dot = max(2.2, bar.height * 0.26)
    for (i, c) in [rgb(0xFF5F57), rgb(0xFEBC2E), rgb(0x28C840)].enumerated() {
        c.setFill()
        NSBezierPath(ovalIn: CGRect(x: r.minX + 6 + CGFloat(i) * (dot * 2 + 3), y: bar.midY - dot,
                                    width: dot * 2, height: dot * 2)).fill()
    }

    // Suggestive content, scaled to the window.
    let content = CGRect(x: r.minX + 8, y: bar.maxY + 7, width: r.width - 16, height: r.height - bar.height - 14)
    guard content.height > 6 else { return }
    let lineH = max(3, min(6, content.height / 12))
    let gap = lineH * 1.9
    switch w.kind {
    case 1: // terminal: green prompt lines
        var y = content.minY
        var i = 0
        while y + lineH < content.maxY {
            rgb(0x3DDC84, 0.85).setFill()
            rounded(CGRect(x: content.minX, y: y, width: lineH * 1.4, height: lineH), lineH / 2).fill()
            NSColor.white.withAlphaComponent(0.55).setFill()
            let len = content.width * [0.7, 0.45, 0.6, 0.35, 0.55][i % 5]
            rounded(CGRect(x: content.minX + lineH * 2.2, y: y, width: len - lineH * 2.2, height: lineH), lineH / 2).fill()
            y += gap; i += 1
        }
    case 2: // chat: alternating bubbles
        var y = content.minY
        var i = 0
        while y + lineH * 2.4 < content.maxY {
            let mine = i % 2 == 1
            let bw = content.width * (mine ? 0.55 : 0.7)
            NSColor.white.withAlphaComponent(mine ? 0.9 : 0.35).setFill()
            rounded(CGRect(x: mine ? content.maxX - bw : content.minX, y: y, width: bw, height: lineH * 2.2),
                    lineH).fill()
            y += lineH * 3.2; i += 1
        }
    default: // browser / notes: header block + text lines
        NSColor.white.withAlphaComponent(0.85).setFill()
        rounded(CGRect(x: content.minX, y: content.minY, width: content.width * 0.55, height: lineH * 1.6), 2).fill()
        var y = content.minY + lineH * 3.4
        var i = 0
        while y + lineH < content.maxY {
            NSColor.white.withAlphaComponent(0.5).setFill()
            let len = content.width * [0.95, 0.88, 0.92, 0.6, 0.9, 0.78][i % 6]
            rounded(CGRect(x: content.minX, y: y, width: len, height: lineH), lineH / 2).fill()
            y += gap; i += 1
        }
    }
}

// The app's brand mark: monitor on a stand with a location pin, in a 24-unit box.
func drawGlyph(center c: CGPoint, size s: CGFloat, color: NSColor) {
    let k = s / 24, o = CGPoint(x: c.x - s / 2, y: c.y - s / 2)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * k, y: o.y + y * k) }
    color.setStroke(); color.setFill()
    let screen = NSBezierPath(roundedRect: CGRect(x: o.x + 2.6 * k, y: o.y + 3.4 * k, width: 18.8 * k, height: 13 * k),
                              xRadius: 2.3 * k, yRadius: 2.3 * k)
    screen.lineWidth = 1.8 * k; screen.stroke()
    let stand = NSBezierPath(); stand.lineWidth = 1.8 * k; stand.lineCapStyle = .round
    stand.move(to: p(9, 20.4)); stand.line(to: p(15, 20.4))
    stand.move(to: p(12, 16.4)); stand.line(to: p(12, 20.4))
    stand.move(to: p(12, 10.9)); stand.line(to: p(12, 14))
    stand.stroke()
    NSBezierPath(ovalIn: CGRect(x: o.x + (12 - 2.3) * k, y: o.y + (8.6 - 2.3) * k, width: 4.6 * k, height: 4.6 * k)).fill()
}

func drawText(_ s: String, at y: CGFloat, alpha: CGFloat) {
    guard alpha > 0.01 else { return }
    let style = NSMutableParagraphStyle(); style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: ink.withAlphaComponent(alpha),
        .paragraphStyle: style,
    ]
    (s as NSString).draw(in: CGRect(x: 30, y: y, width: W - 60, height: 36), withAttributes: attrs)
}

// MARK: frame
func drawFrame(_ t: Double) {
    bg.setFill(); CGRect(x: 0, y: 0, width: W, height: H).fill()

    // Connection state 0 (unplugged) … 1 (plugged).
    let plug = t < tPlug ? 1 - ease(progress(t, tUnplug, tUnplugEnd)) : ease(progress(t, tPlug, tPlugEnd))

    // Cable: laptop right side → monitor foot, with a gap that opens when unplugged.
    let a = CGPoint(x: 400, y: 404), b = CGPoint(x: 671, y: 416)
    let cable = NSBezierPath()
    cable.move(to: a)
    cable.curve(to: b, controlPoint1: CGPoint(x: 470, y: 470), controlPoint2: CGPoint(x: 600, y: 470))
    cable.lineWidth = 4; cable.lineCapStyle = .round
    let gap = CGFloat(1 - plug) * 34
    if gap < 1 {
        rgb(0x9AA3B2).setStroke(); cable.stroke()
    } else {
        // Draw the two halves with a visible break in the middle.
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 535 - gap / 2, height: H)).addClip()
        rgb(0x9AA3B2).setStroke(); cable.stroke()
        rgb(0x6B7280).setFill()
        rounded(CGRect(x: 535 - gap / 2 - 10, y: 450, width: 12, height: 14), 3).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: CGRect(x: 535 + gap / 2, y: 0, width: W, height: H)).addClip()
        rgb(0x9AA3B2).setStroke(); cable.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    // Monitor: stand, bezel, screen that powers down when unplugged.
    bezel.setFill()
    rounded(CGRect(x: 661, y: 355, width: 20, height: 56), 4).fill()
    rounded(CGRect(x: 606, y: 408, width: 130, height: 10), 5).fill()
    rounded(monitorScreen, 12).fill()
    screenOff.blended(withFraction: CGFloat(plug), of: desktop)!.setFill()
    rounded(monitorInner, 5).fill()
    rgb(0xFFFFFF, 0.55 * CGFloat(plug)).setFill()
    CGRect(x: monitorInner.minX, y: monitorInner.minY, width: monitorInner.width, height: menuBarH).fill()

    // Laptop: base, bezel, screen with a menu bar carrying the Monitor Glue icon.
    bezel.setFill()
    let base = NSBezierPath()
    base.move(to: CGPoint(x: 52, y: 398)); base.line(to: CGPoint(x: 388, y: 398))
    base.line(to: CGPoint(x: 404, y: 412)); base.line(to: CGPoint(x: 36, y: 412)); base.close(); base.fill()
    rounded(laptopScreen, 10).fill()
    desktop.setFill(); rounded(laptopInner, 4).fill()
    rgb(0xFFFFFF, 0.55).setFill()
    CGRect(x: laptopInner.minX, y: laptopInner.minY, width: laptopInner.width, height: menuBarH).fill()

    // Menu-bar icon pulses when Monitor Glue kicks in.
    let iconC = CGPoint(x: laptopInner.maxX - 14, y: laptopInner.minY + menuBarH / 2)
    let pulse = progress(t, tPulse, tPulseEnd)
    if pulse > 0 && pulse < 1 {
        accent.withAlphaComponent(CGFloat(0.35 * (1 - pulse))).setFill()
        let rr = CGFloat(8 + 26 * pulse)
        NSBezierPath(ovalIn: CGRect(x: iconC.x - rr, y: iconC.y - rr, width: rr * 2, height: rr * 2)).fill()
    }
    let active = t >= tPulse && t < tBackEnd + 0.4
    drawGlyph(center: iconC, size: 12.5, color: active ? accent : ink)

    // Windows.
    drawWindow(notes, notes.home)
    for w in wins {
        let toPile = ease(progress(t, tPileStart + w.delay, tPileEnd + w.delay))
        let back = ease(progress(t, tBackStart + w.delay, tBackEnd + w.delay))
        let r: CGRect
        if t < tBackStart { r = lerp(w.home, w.pile, toPile) } else { r = lerp(w.pile, w.home, back) }
        drawWindow(w, r)
    }

    // Caption with a quick crossfade.
    for (a, b, text) in captions {
        let fade = 0.22
        let alpha = min(progress(t, a, a + fade), 1 - progress(t, b - fade, b))
        drawText(text, at: 478, alpha: CGFloat(a == 0 && t < fade ? 1 : alpha))
    }

    // Small wordmark.
    drawGlyph(center: CGPoint(x: 38, y: 34), size: 22, color: accent)
    ("Monitor Glue" as NSString).draw(at: CGPoint(x: 56, y: 22), withAttributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: ink,
    ])
}

// MARK: render
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "demo.gif")
let pw = Int(W * SCALE), ph = Int(H * SCALE)
let total = Int(DURATION * FPS)

var frames: [(CGImage, Double)] = []
var lastData: Data? = nil
for i in 0..<total {
    let t = Double(i) / FPS
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = g.cgContext
    cg.translateBy(x: 0, y: CGFloat(ph)); cg.scaleBy(x: SCALE, y: -SCALE)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    drawFrame(t)
    NSGraphicsContext.current = nil
    let data = rep.tiffRepresentation
    // Merge runs of identical frames into one longer frame — keeps the file small.
    if let d = data, d == lastData, !frames.isEmpty {
        frames[frames.count - 1].1 += 1 / FPS
    } else {
        frames.append((rep.cgImage!, 1 / FPS))
        lastData = data
    }
}

let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (img, delay) in frames {
    CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
    ]] as CFDictionary)
}
CGImageDestinationFinalize(dest)
print("wrote \(out.path): \(pw)x\(ph), \(total) frames → \(frames.count) after merging identical frames")

// Key frames as PNGs, for review.
if CommandLine.arguments.count > 2 {
    let dir = URL(fileURLWithPath: CommandLine.arguments[2])
    for (name, t) in [("1-arranged", 1.0), ("2-unplugged", 2.5), ("3-piled", 3.6), ("4-pulse", 4.75), ("4b-restoring", 5.5), ("5-restored", 7.5)] {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let g = NSGraphicsContext(bitmapImageRep: rep)!
        let cg = g.cgContext
        cg.translateBy(x: 0, y: CGFloat(ph)); cg.scaleBy(x: SCALE, y: -SCALE)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        drawFrame(t)
        NSGraphicsContext.current = nil
        try! rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

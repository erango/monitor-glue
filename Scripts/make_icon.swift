// Renders the Monitor Glue app icon (brand-blue squircle + white display+pin glyph)
// to a 1024×1024 PNG. Run via Scripts/make_icon.sh.
import AppKit

let size = 1024.0
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

// Squircle background with brand gradient.
let inset = size * 0.06
let rect = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let bg = NSBezierPath(roundedRect: rect, xRadius: size * 0.21, yRadius: size * 0.21)
bg.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0x3a/255.0, green: 0x8b/255.0, blue: 0xff/255.0, alpha: 1),
    NSColor(srgbRed: 0x14/255.0, green: 0x57/255.0, blue: 0xd8/255.0, alpha: 1),
])!
gradient.draw(in: rect, angle: -60)

// Brand mark: monitor on a stand with a centered location-pin (design SVG, viewBox 24).
// AppKit is y-up, the SVG is y-down — map with cy = oy + (24 - y) * scale.
let glyph = size * 0.52
let scale = glyph / 24.0
let ox = (size - glyph) / 2.0
let oy = (size - glyph) / 2.0
func pt(_ x: Double, _ y: Double) -> NSPoint { NSPoint(x: ox + x*scale, y: oy + (24 - y)*scale) }

NSColor.white.setStroke()
NSColor.white.setFill()
let lw = 1.7 * scale

// Screen.
let screen = NSBezierPath(roundedRect:
    NSRect(x: ox + 2.6*scale, y: oy + (24 - 16.4)*scale, width: 18.8*scale, height: 13*scale),
    xRadius: 2.3*scale, yRadius: 2.3*scale)
screen.lineWidth = lw
screen.stroke()

// Stand base + neck.
let stand = NSBezierPath()
stand.lineWidth = lw
stand.lineCapStyle = .round
stand.move(to: pt(9, 20.4));  stand.line(to: pt(15, 20.4))
stand.move(to: pt(12, 16.4)); stand.line(to: pt(12, 20.4))
// Pin stem.
stand.move(to: pt(12, 10.9)); stand.line(to: pt(12, 14))
stand.stroke()

// Pin head.
let r = 2.3 * scale
let head = NSBezierPath(ovalIn: NSRect(x: ox + 12*scale - r, y: oy + (24 - 8.6)*scale - r,
                                       width: 2*r, height: 2*r))
head.fill()

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

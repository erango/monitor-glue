// Renders the Monitor Glue app icon (brand-blue squircle + white glue-bottle glyph)
// to a 1024×1024 PNG. Run via Scripts/make_icon.sh.
import AppKit

/// The brand mark: a glue bottle beside a drop, in the design's 24-unit, y-down space.
/// `p` maps a design point into the drawing; `k` is the design-unit size.
func drawBottle(_ p: (CGFloat, CGFloat) -> NSPoint, k: CGFloat, lineWidth: CGFloat, color: NSColor) {
    color.setStroke(); color.setFill()
    func stroke(_ path: NSBezierPath) {
        path.lineWidth = lineWidth * k; path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.stroke()
    }
    // Shoulder.
    let shoulder = NSBezierPath()
    shoulder.move(to: p(5.8, 10.6)); shoulder.line(to: p(7.2, 7.6)); shoulder.line(to: p(11.6, 7.6)); shoulder.line(to: p(13, 10.6))
    stroke(shoulder)
    // Body: a rounded rect, drawn through the mapping so it works flipped or not.
    let body = NSBezierPath()
    let (x0, y0, x1, y1, r): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (3.9, 10.6, 14.9, 21.2, 2.4)
    let c: CGFloat = 0.5523 * r
    body.move(to: p(x0 + r, y0)); body.line(to: p(x1 - r, y0))
    body.curve(to: p(x1, y0 + r), controlPoint1: p(x1 - r + c, y0), controlPoint2: p(x1, y0 + r - c))
    body.line(to: p(x1, y1 - r))
    body.curve(to: p(x1 - r, y1), controlPoint1: p(x1, y1 - r + c), controlPoint2: p(x1 - r + c, y1))
    body.line(to: p(x0 + r, y1))
    body.curve(to: p(x0, y1 - r), controlPoint1: p(x0 + r - c, y1), controlPoint2: p(x0, y1 - r + c))
    body.line(to: p(x0, y0 + r))
    body.curve(to: p(x0 + r, y0), controlPoint1: p(x0, y0 + r - c), controlPoint2: p(x0 + r - c, y0))
    body.close()
    stroke(body)
    // Nozzle and label.
    let detail = NSBezierPath()
    detail.move(to: p(8.1, 7.6)); detail.line(to: p(8.8, 3.1)); detail.line(to: p(10, 3.1)); detail.line(to: p(10.7, 7.6))
    detail.move(to: p(7, 15.6)); detail.line(to: p(11.8, 15.6))
    stroke(detail)
    // Drop.
    let drop = NSBezierPath()
    drop.move(to: p(20.4, 10.4))
    drop.curve(to: p(18.4, 12.5), controlPoint1: p(20.4, 11.6), controlPoint2: p(19.5, 12.5))
    drop.curve(to: p(16.4, 10.4), controlPoint1: p(17.3, 12.5), controlPoint2: p(16.4, 11.6))
    drop.curve(to: p(18.4, 6.8), controlPoint1: p(16.4, 8.9), controlPoint2: p(18.4, 6.8))
    drop.curve(to: p(20.4, 10.4), controlPoint1: p(18.4, 6.8), controlPoint2: p(20.4, 8.9))
    drop.close()
    drop.fill()
}

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

// Brand mark (design SVG, viewBox 24). AppKit is y-up, the SVG is y-down.
let glyph = size * 0.56
let scale = glyph / 24.0
let ox = (size - glyph) / 2.0
let oy = (size - glyph) / 2.0
drawBottle({ x, y in NSPoint(x: ox + x * scale, y: oy + (24 - y) * scale) },
           k: scale, lineWidth: 1.7, color: .white)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

// Renders the Monitor Glue app icon (brand-blue squircle + white display+pin glyph)
// to a 1024×1024 PNG. Run via Scripts/make_icon.sh.
import AppKit

let size = 1024.0
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let copy = image.copy() as! NSImage
    copy.lockFocus()
    color.set()
    NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    return copy
}

let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

// Squircle background with brand gradient.
let inset = size * 0.06
let rect = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.21, yRadius: size * 0.21)
path.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0x3a/255.0, green: 0x8b/255.0, blue: 0xff/255.0, alpha: 1),
    NSColor(srgbRed: 0x14/255.0, green: 0x57/255.0, blue: 0xd8/255.0, alpha: 1),
])!
gradient.draw(in: rect, angle: -60)

// White display glyph, centered.
let symCfg = NSImage.SymbolConfiguration(pointSize: size * 0.40, weight: .regular)
if let display = NSImage(systemSymbolName: "display", accessibilityDescription: nil)?
    .withSymbolConfiguration(symCfg) {
    let white = tinted(display, .white)
    let w = size * 0.46, h = w * (display.size.height / display.size.width)
    white.draw(in: NSRect(x: (size - w)/2, y: (size - h)/2, width: w, height: h))
}

// White pin badge, upper-right of the glyph.
let pinCfg = NSImage.SymbolConfiguration(pointSize: size * 0.18, weight: .bold)
if let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(pinCfg) {
    let white = tinted(pin, .white)
    let w = size * 0.20, h = w * (pin.size.height / pin.size.width)
    white.draw(in: NSRect(x: size * 0.58, y: size * 0.54, width: w, height: h))
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

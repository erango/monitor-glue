import SwiftUI

/// Minimal SVG `d` path-data parser → SwiftUI `Path`, supporting the command subset used by
/// the design handoff icons (M m L l H h V v C c S s A a Z). Circular/elliptical arcs are
/// sampled into line segments so direction conventions never bite us.
enum SVGPathParser {
    static func path(_ d: String, scale s: CGFloat) -> Path {
        var path = Path()
        var i = d.startIndex
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var cmd: Character = " "
        var lastCtrl: CGPoint? = nil

        func skipSep() {
            while i < d.endIndex, d[i] == " " || d[i] == "," || d[i] == "\n" || d[i] == "\t" { i = d.index(after: i) }
        }
        func peekIsCommand() -> Bool {
            i < d.endIndex && "MmLlHhVvCcSsAaZz".contains(d[i])
        }
        func num() -> CGFloat {
            skipSep()
            var str = ""
            if i < d.endIndex, d[i] == "-" || d[i] == "+" { str.append(d[i]); i = d.index(after: i) }
            var dot = false
            while i < d.endIndex {
                let c = d[i]
                if c.isNumber { str.append(c); i = d.index(after: i) }
                else if c == ".", !dot { dot = true; str.append(c); i = d.index(after: i) }
                else { break }
            }
            return CGFloat(Double(str) ?? 0)
        }
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

        func arc(to end: CGPoint, r: CGFloat, large: Bool, sweep: Bool) {
            let p0 = cur, p1 = end
            let dx = p1.x - p0.x, dy = p1.y - p0.y
            let dist = hypot(dx, dy)
            guard dist > 0.0001 else { return }
            let rr = max(r, dist / 2)
            let h = (rr * rr - dist * dist / 4).squareRoot()
            let mx = (p0.x + p1.x) / 2, my = (p0.y + p1.y) / 2
            let ux = -dy / dist, uy = dx / dist
            let sign: CGFloat = (large == sweep) ? -1 : 1
            let cx = mx + sign * h * ux, cy = my + sign * h * uy
            var a0 = atan2(p0.y - cy, p0.x - cx)
            var a1 = atan2(p1.y - cy, p1.x - cx)
            if sweep { if a1 < a0 { a1 += 2 * .pi } } else { if a1 > a0 { a1 -= 2 * .pi } }
            let steps = max(6, Int(abs(a1 - a0) / (.pi / 24)))
            for k in 1...steps {
                let t = a0 + (a1 - a0) * CGFloat(k) / CGFloat(steps)
                path.addLine(to: CGPoint(x: cx + rr * cos(t), y: cy + rr * sin(t)))
            }
        }

        while i < d.endIndex {
            skipSep()
            if i >= d.endIndex { break }
            if peekIsCommand() { cmd = d[i]; i = d.index(after: i) }
            let rel = cmd.isLowercase
            switch Character(cmd.lowercased()) {
            case "m":
                let x = num(), y = num()
                cur = rel ? CGPoint(x: cur.x + x * s, y: cur.y + y * s) : pt(x, y)
                path.move(to: cur); start = cur; cmd = rel ? "l" : "L"
            case "l":
                let x = num(), y = num()
                cur = rel ? CGPoint(x: cur.x + x * s, y: cur.y + y * s) : pt(x, y)
                path.addLine(to: cur); lastCtrl = nil
            case "h":
                let x = num(); cur = rel ? CGPoint(x: cur.x + x * s, y: cur.y) : CGPoint(x: x * s, y: cur.y)
                path.addLine(to: cur); lastCtrl = nil
            case "v":
                let y = num(); cur = rel ? CGPoint(x: cur.x, y: cur.y + y * s) : CGPoint(x: cur.x, y: y * s)
                path.addLine(to: cur); lastCtrl = nil
            case "c":
                let c1 = pointMaybeRel(num(), num(), rel, cur, s)
                let c2 = pointMaybeRel(num(), num(), rel, cur, s)
                let e = pointMaybeRel(num(), num(), rel, cur, s)
                path.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "s":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = pointMaybeRel(num(), num(), rel, cur, s)
                let e = pointMaybeRel(num(), num(), rel, cur, s)
                path.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "a":
                let rx = num(); _ = num(); _ = num()         // rx, ry(==rx), x-rotation
                let large = num() != 0, sweep = num() != 0
                let e = pointMaybeRel(num(), num(), rel, cur, s)
                arc(to: e, r: rx * s, large: large, sweep: sweep); cur = e; lastCtrl = nil
            case "z":
                path.closeSubpath(); cur = start; lastCtrl = nil
            default:
                i = d.index(after: i)   // skip unknown
            }
        }
        return path
    }

    private static func pointMaybeRel(_ x: CGFloat, _ y: CGFloat, _ rel: Bool, _ cur: CGPoint, _ s: CGFloat) -> CGPoint {
        rel ? CGPoint(x: cur.x + x * s, y: cur.y + y * s) : CGPoint(x: x * s, y: y * s)
    }
}

/// One drawing element of an icon.
struct SVGElement {
    enum Style { case strokeCurrent(CGFloat, Bool), fillCurrent, stroke(Color, CGFloat, Bool, Double), fill(Color) }
    let d: String
    let style: Style
}

/// Renders a list of SVG elements scaled into the available square, inheriting the current
/// foreground color for `*Current` styles.
struct SVGIcon: View {
    let viewBox: CGFloat
    let elements: [SVGElement]

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / viewBox
            ZStack {
                ForEach(Array(elements.enumerated()), id: \.offset) { _, e in
                    element(e, s)
                }
            }
        }
    }

    @ViewBuilder
    private func element(_ e: SVGElement, _ s: CGFloat) -> some View {
        let p = SVGPathParser.path(e.d, scale: s)
        switch e.style {
        case .strokeCurrent(let w, let round):
            p.stroke(style: StrokeStyle(lineWidth: w * s, lineCap: round ? .round : .butt, lineJoin: round ? .round : .miter))
        case .fillCurrent:
            p.fill()
        case .stroke(let c, let w, let round, let op):
            p.stroke(c.opacity(op), style: StrokeStyle(lineWidth: w * s, lineCap: round ? .round : .butt, lineJoin: round ? .round : .miter))
        case .fill(let c):
            p.fill(c)
        }
    }
}

// MARK: - The handoff's menu/footer icons

enum MGIcon {
    /// Restore: undo-style arrow (chevron + semicircular return).
    static var restore: SVGIcon {
        SVGIcon(viewBox: 16, elements: [
            .init(d: "M5.5 4 2.4 7.1 5.5 10.2", style: .strokeCurrent(1.4, true)),
            .init(d: "M2.7 7.1H9.6a3.6 3.6 0 0 1 0 7.2H6.2", style: .strokeCurrent(1.4, true)),
        ])
    }
    /// Open Manager: a window/screen with a top bar.
    static var manager: SVGIcon {
        SVGIcon(viewBox: 16, elements: [
            .init(d: "M2.4 5.6h11.2a1.5 1.5 0 0 1 1.5 1.5v4.4a1.5 1.5 0 0 1-1.5 1.5H2.4a1.5 1.5 0 0 1-1.5-1.5V7.1a1.5 1.5 0 0 1 1.5-1.5Z", style: .strokeCurrent(1.3, false)),
            .init(d: "M4.6 3.6h6.8", style: .strokeCurrent(1.3, true)),
        ])
    }
    /// Quit: power symbol.
    static var power: SVGIcon {
        SVGIcon(viewBox: 16, elements: [
            .init(d: "M8 2.4v5.2", style: .strokeCurrent(1.5, true)),
            .init(d: "M4.9 4.5a4.6 4.6 0 1 0 6.2 0", style: .strokeCurrent(1.5, true)),
        ])
    }
    /// Ko-fi coffee cup with steam + coral heart (fixed colors, white on the blue pill).
    static var kofiCup: SVGIcon {
        SVGIcon(viewBox: 24, elements: [
            .init(d: "M5 9h11v4.5a4.5 4.5 0 0 1-4.5 4.5h-2A4.5 4.5 0 0 1 5 13.5V9Z", style: .fill(.white)),
            .init(d: "M16 10.2h1.6a2.4 2.4 0 0 1 0 4.8H16", style: .stroke(.white, 1.5, false, 1)),
            .init(d: "M4 20.4h13", style: .stroke(.white, 1.6, true, 1)),
            .init(d: "M8.6 6.6c0-1 .8-1.3.8-2.3", style: .stroke(.white, 1.4, true, 0.85)),
            .init(d: "M11.9 6.6c0-1 .8-1.3.8-2.3", style: .stroke(.white, 1.4, true, 0.85)),
            .init(d: "M9.1 11.1c.5-.7 1.6-.5 1.6.4 0 .9-1.6 1.9-1.6 1.9s-1.6-1-1.6-1.9c0-.9 1.1-1.1 1.6-.4Z",
                  style: .fill(Theme.coral)),
        ])
    }
    /// Trash (delete set / delete app).
    static var trash: SVGIcon {
        SVGIcon(viewBox: 16, elements: [
            .init(d: "M3 4.4h10M6.4 4.4V3.1a1 1 0 0 1 1-1h1.2a1 1 0 0 1 1 1v1.3M4.3 4.4l.55 8.1a1 1 0 0 0 1 .93h4.3a1 1 0 0 0 1-.93l.55-8.1",
                  style: .strokeCurrent(1.3, true)),
        ])
    }
    /// X-in-circle (forget a single window).
    static var xCircle: SVGIcon {
        SVGIcon(viewBox: 16, elements: [
            .init(d: "M14.4 8a6.4 6.4 0 1 0-12.8 0a6.4 6.4 0 1 0 12.8 0Z", style: .strokeCurrent(1.3, false)),
            .init(d: "M6 6l4 4M10 6l-4 4", style: .strokeCurrent(1.3, true)),
        ])
    }
}

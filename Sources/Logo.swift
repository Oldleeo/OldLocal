import AppKit

enum OldLocalLogo {
    static func draw(in context: CGContext, size: CGFloat, tile: Bool) {
        context.saveGState()
        context.scaleBy(x: size / 1024, y: size / 1024)
        if tile {
            let background = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
            NSGradient(starting: NSColor(calibratedWhite: 0.965, alpha: 1), ending: .white)!.draw(in: background, angle: 90)
            NSColor(calibratedWhite: 0.9, alpha: 0.75).setStroke()
            background.lineWidth = 3
            background.stroke()
        }
        context.translateBy(x: 512, y: 512)
        context.rotate(by: .pi / 4)
        let shape = NSBezierPath()
        shape.move(to: NSPoint(x: -165, y: 150))
        shape.curve(to: NSPoint(x: 0, y: 72), controlPoint1: NSPoint(x: -82, y: 150), controlPoint2: NSPoint(x: -75, y: 72))
        shape.curve(to: NSPoint(x: 165, y: 150), controlPoint1: NSPoint(x: 75, y: 72), controlPoint2: NSPoint(x: 82, y: 150))
        shape.curve(to: NSPoint(x: 315, y: 0), controlPoint1: NSPoint(x: 248, y: 150), controlPoint2: NSPoint(x: 315, y: 83))
        shape.curve(to: NSPoint(x: 165, y: -150), controlPoint1: NSPoint(x: 315, y: -83), controlPoint2: NSPoint(x: 248, y: -150))
        shape.curve(to: NSPoint(x: 0, y: -72), controlPoint1: NSPoint(x: 82, y: -150), controlPoint2: NSPoint(x: 75, y: -72))
        shape.curve(to: NSPoint(x: -165, y: -150), controlPoint1: NSPoint(x: -75, y: -72), controlPoint2: NSPoint(x: -82, y: -150))
        shape.curve(to: NSPoint(x: -315, y: 0), controlPoint1: NSPoint(x: -248, y: -150), controlPoint2: NSPoint(x: -315, y: -83))
        shape.curve(to: NSPoint(x: -165, y: 150), controlPoint1: NSPoint(x: -315, y: 83), controlPoint2: NSPoint(x: -248, y: 150))
        shape.close()
        NSColor(red: 0.065, green: 0.075, blue: 0.09, alpha: 1).setFill()
        shape.fill()
        NSColor(red: 0.04, green: 0.28, blue: 1, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 102, y: -63, width: 126, height: 126)).fill()
        context.restoreGState()
    }

    static func image(size: CGFloat, tile: Bool) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: context, size: size, tile: tile)
            return true
        }
    }
}

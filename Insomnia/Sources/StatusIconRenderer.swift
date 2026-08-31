import AppKit

enum MenuIcon: Equatable {
    case vampire(isAwake: Bool)
    case systemSymbol(String)
}

enum StatusIconRenderer {
    static func image(for icon: MenuIcon) -> NSImage? {
        switch icon {
        case let .systemSymbol(name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case let .vampire(isAwake):
            return vampireImage(isAwake: isAwake)
        }
    }

    private static func vampireImage(isAwake: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let coffin = NSBezierPath()
            coffin.move(to: NSPoint(x: 6.1, y: 1.75))
            coffin.line(to: NSPoint(x: 11.9, y: 1.75))
            coffin.line(to: NSPoint(x: 14.4, y: 12))
            coffin.line(to: NSPoint(x: 12.25, y: 16.25))
            coffin.line(to: NSPoint(x: 5.75, y: 16.25))
            coffin.line(to: NSPoint(x: 3.6, y: 12))
            coffin.close()
            coffin.lineJoinStyle = .round

            NSColor.black.set()
            if isAwake {
                coffin.fill()
            } else {
                coffin.lineWidth = 1.35
                coffin.stroke()
            }

            let outerMoon = NSBezierPath(ovalIn: NSRect(x: 5.9, y: 6.3, width: 6.6, height: 7.4))
            let innerCutout = NSBezierPath(ovalIn: NSRect(x: 8.2, y: 7, width: 4.9, height: 6.2))

            if let context = NSGraphicsContext.current {
                context.saveGraphicsState()
                if isAwake {
                    context.compositingOperation = .destinationOut
                    outerMoon.fill()
                    context.compositingOperation = .sourceOver
                    NSColor.black.set()
                    innerCutout.fill()
                } else {
                    outerMoon.fill()
                    context.compositingOperation = .destinationOut
                    innerCutout.fill()
                }
                context.restoreGraphicsState()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

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
            NSColor.black.set()
            if isAwake {
                batPath().fill()
            } else {
                let outerMoon = NSBezierPath(ovalIn: NSRect(x: 2.1, y: 3.2, width: 8.8, height: 11.6))
                let innerCutout = NSBezierPath(ovalIn: NSRect(x: 5.1, y: 5, width: 7.2, height: 9.2))

                outerMoon.fill()
                if let context = NSGraphicsContext.current {
                    context.saveGraphicsState()
                    context.compositingOperation = .destinationOut
                    innerCutout.fill()
                    context.restoreGraphicsState()
                }

                NSColor.black.set()
                starPath(center: NSPoint(x: 13.4, y: 13), radius: 1.35).fill()
                starPath(center: NSPoint(x: 15, y: 7.5), radius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func batPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 9, y: 3.2))
        path.curve(
            to: NSPoint(x: 6.8, y: 7.4),
            controlPoint1: NSPoint(x: 8.6, y: 5.2),
            controlPoint2: NSPoint(x: 7.8, y: 6.7)
        )
        path.curve(
            to: NSPoint(x: 3.6, y: 7.1),
            controlPoint1: NSPoint(x: 5.7, y: 6.5),
            controlPoint2: NSPoint(x: 4.6, y: 6.5)
        )
        path.curve(
            to: NSPoint(x: 1.4, y: 10.4),
            controlPoint1: NSPoint(x: 3.4, y: 8.5),
            controlPoint2: NSPoint(x: 2.7, y: 9.5)
        )
        path.curve(
            to: NSPoint(x: 6.1, y: 11.1),
            controlPoint1: NSPoint(x: 3.1, y: 13),
            controlPoint2: NSPoint(x: 4.8, y: 12.1)
        )
        path.curve(
            to: NSPoint(x: 8, y: 12.5),
            controlPoint1: NSPoint(x: 6.7, y: 11.9),
            controlPoint2: NSPoint(x: 7.3, y: 12.4)
        )
        path.line(to: NSPoint(x: 7.7, y: 14.4))
        path.line(to: NSPoint(x: 9, y: 13.4))
        path.line(to: NSPoint(x: 10.3, y: 14.4))
        path.line(to: NSPoint(x: 10, y: 12.5))
        path.curve(
            to: NSPoint(x: 11.9, y: 11.1),
            controlPoint1: NSPoint(x: 10.7, y: 12.4),
            controlPoint2: NSPoint(x: 11.3, y: 11.9)
        )
        path.curve(
            to: NSPoint(x: 16.6, y: 10.4),
            controlPoint1: NSPoint(x: 13.2, y: 12.1),
            controlPoint2: NSPoint(x: 14.9, y: 13)
        )
        path.curve(
            to: NSPoint(x: 14.4, y: 7.1),
            controlPoint1: NSPoint(x: 15.3, y: 9.5),
            controlPoint2: NSPoint(x: 14.6, y: 8.5)
        )
        path.curve(
            to: NSPoint(x: 11.2, y: 7.4),
            controlPoint1: NSPoint(x: 13.4, y: 6.5),
            controlPoint2: NSPoint(x: 12.3, y: 6.5)
        )
        path.curve(
            to: NSPoint(x: 9, y: 3.2),
            controlPoint1: NSPoint(x: 10.2, y: 6.7),
            controlPoint2: NSPoint(x: 9.4, y: 5.2)
        )
        path.close()
        return path
    }

    private static func starPath(center: NSPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x, y: center.y + radius))
        path.line(to: NSPoint(x: center.x + radius * 0.32, y: center.y + radius * 0.32))
        path.line(to: NSPoint(x: center.x + radius, y: center.y))
        path.line(to: NSPoint(x: center.x + radius * 0.32, y: center.y - radius * 0.32))
        path.line(to: NSPoint(x: center.x, y: center.y - radius))
        path.line(to: NSPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.32))
        path.line(to: NSPoint(x: center.x - radius, y: center.y))
        path.line(to: NSPoint(x: center.x - radius * 0.32, y: center.y + radius * 0.32))
        path.close()
        return path
    }
}

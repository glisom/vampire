import AppKit
import XCTest
@testable import Insomnia

@MainActor
final class StatusIconRendererTests: XCTestCase {
    func testVampireIconsUseTemplateCanvasWithoutClipping() throws {
        for isAwake in [false, true] {
            let image = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: isAwake)))

            XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
            XCTAssertTrue(image.isTemplate)

            let bitmap = try render(image)
            let bounds = try XCTUnwrap(occupiedBounds(in: bitmap))
            XCTAssertGreaterThan(bounds.minX, 0)
            XCTAssertGreaterThan(bounds.minY, 0)
            XCTAssertLessThan(bounds.maxX, CGFloat(bitmap.pixelsWide - 1))
            XCTAssertLessThan(bounds.maxY, CGFloat(bitmap.pixelsHigh - 1))
        }
    }

    func testAwakeCoffinHasHighShouldersAndTaperedFoot() throws {
        let image = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: true)))
        let bitmap = try render(image)

        let shoulderWidth = occupiedWidth(atPointY: 12.5, in: bitmap)
        let footWidth = occupiedWidth(atPointY: 3, in: bitmap)

        XCTAssertGreaterThanOrEqual(shoulderWidth, footWidth + 8)
    }

    func testAwakeAndSleepingIconsHaveDistinctPixels() throws {
        let sleeping = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: false)))
        let awake = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: true)))

        XCTAssertNotEqual(try render(sleeping).tiffRepresentation, try render(awake).tiffRepresentation)
    }

    func testAwakeCrescentDoesNotCutASecondRightHandSliver() throws {
        let image = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: true)))
        let bitmap = try render(image)

        XCTAssertGreaterThan(alpha(atPointX: 13, pointY: 10, in: bitmap), 0.9)
    }

    func testSleepingCrescentDoesNotDrawASecondRightHandSliver() throws {
        let image = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: false)))
        let bitmap = try render(image)

        XCTAssertLessThan(alpha(atPointX: 13, pointY: 10, in: bitmap), 0.5)
    }

    func testSleepingCrescentHasACleanOpenRightEdge() throws {
        let image = try XCTUnwrap(StatusIconRenderer.image(for: .vampire(isAwake: false)))
        let bitmap = try render(image)

        for pointY: CGFloat in [9, 10, 11] {
            XCTAssertLessThan(alpha(atPointX: 12.25, pointY: pointY, in: bitmap), 0.05)
        }
    }

    private func render(_ image: NSImage) throws -> NSBitmapImageRep {
        let scale = 2
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(image.size.width) * scale,
                pixelsHigh: Int(image.size.height) * scale,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        bitmap.size = image.size

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.current?.flushGraphics()
        return bitmap
    }

    private func occupiedBounds(in bitmap: NSBitmapImageRep) -> NSRect? {
        var points: [NSPoint] = []
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where alpha(atX: x, y: y, in: bitmap) > 0.05 {
                points.append(NSPoint(x: x, y: y))
            }
        }
        guard let first = points.first else { return nil }
        return points.dropFirst().reduce(NSRect(x: first.x, y: first.y, width: 0, height: 0)) {
            $0.union(NSRect(x: $1.x, y: $1.y, width: 0, height: 0))
        }
    }

    private func occupiedWidth(atPointY pointY: CGFloat, in bitmap: NSBitmapImageRep) -> Int {
        let scale = CGFloat(bitmap.pixelsHigh) / 18
        let y = max(0, bitmap.pixelsHigh - 1 - Int(pointY * scale))
        let occupiedX = (0..<bitmap.pixelsWide).filter { alpha(atX: $0, y: y, in: bitmap) > 0.05 }
        guard let first = occupiedX.first, let last = occupiedX.last else { return 0 }
        return last - first + 1
    }

    private func alpha(atX x: Int, y: Int, in bitmap: NSBitmapImageRep) -> CGFloat {
        bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }

    private func alpha(atPointX pointX: CGFloat, pointY: CGFloat, in bitmap: NSBitmapImageRep) -> CGFloat {
        let scaleX = CGFloat(bitmap.pixelsWide) / 18
        let scaleY = CGFloat(bitmap.pixelsHigh) / 18
        let x = min(bitmap.pixelsWide - 1, Int(pointX * scaleX))
        let y = max(0, bitmap.pixelsHigh - 1 - Int(pointY * scaleY))
        return alpha(atX: x, y: y, in: bitmap)
    }
}

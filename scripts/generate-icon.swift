import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = AffineTransform(scale: CGFloat(size) / 1024)
        (transform as NSAffineTransform).concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 210, yRadius: 210)
        NSGradient(starting: NSColor(red: 0.11, green: 0.20, blue: 0.30, alpha: 1),
                   ending: NSColor(red: 0.03, green: 0.07, blue: 0.14, alpha: 1))!.draw(in: background, angle: -65)
        let screen = NSBezierPath(roundedRect: NSRect(x: 195, y: 330, width: 634, height: 440), xRadius: 40, yRadius: 40)
        NSColor(red: 0.82, green: 0.92, blue: 1, alpha: 1).setStroke(); screen.lineWidth = 35; screen.stroke()
        let stand = NSBezierPath(); stand.move(to: NSPoint(x: 512, y: 330)); stand.line(to: NSPoint(x: 512, y: 230))
        stand.move(to: NSPoint(x: 385, y: 225)); stand.line(to: NSPoint(x: 639, y: 225)); stand.lineWidth = 35; stand.lineCapStyle = .round; stand.stroke()
        NSColor(red: 0.26, green: 0.90, blue: 0.76, alpha: 1).setStroke()
        let arrows = NSBezierPath(); arrows.lineWidth = 38; arrows.lineCapStyle = .round; arrows.lineJoinStyle = .round
        arrows.move(to: NSPoint(x: 330, y: 615)); arrows.line(to: NSPoint(x: 690, y: 615))
        arrows.move(to: NSPoint(x: 615, y: 685)); arrows.line(to: NSPoint(x: 690, y: 615)); arrows.line(to: NSPoint(x: 615, y: 545))
        arrows.move(to: NSPoint(x: 694, y: 475)); arrows.line(to: NSPoint(x: 334, y: 475))
        arrows.move(to: NSPoint(x: 409, y: 545)); arrows.line(to: NSPoint(x: 334, y: 475)); arrows.line(to: NSPoint(x: 409, y: 405)); arrows.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}

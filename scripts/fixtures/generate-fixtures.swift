import AppKit
import Foundation

func makeSolidColorPNG(size: NSSize, color: NSColor, text: String, path: String) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "fixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate bitmap"])
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    color.setFill()
    NSRect(origin: .zero, size: size).fill()

    let fontSize = size.width * 0.5
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    let str = text as NSString
    let strSize = str.size(withAttributes: attrs)
    let point = NSPoint(
        x: (size.width - strSize.width) / 2,
        y: (size.height - strSize.height) / 2
    )
    str.draw(at: point, withAttributes: attrs)

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "fixtures", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    try data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path)")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let fixturesDir = scriptURL.deletingLastPathComponent().path

try makeSolidColorPNG(
    size: NSSize(width: 128, height: 128),
    color: NSColor.systemRed,
    text: "T",
    path: "\(fixturesDir)/test-symbol.png"
)
try makeSolidColorPNG(
    size: NSSize(width: 256, height: 256),
    color: NSColor.systemBlue,
    text: "BG",
    path: "\(fixturesDir)/test-background.png"
)

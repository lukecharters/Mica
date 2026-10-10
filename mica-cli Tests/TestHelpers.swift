import Foundation
import AppKit
import ArgumentParser

/// Convenience wrapper for `GenerateCommand.parse(_:)`.
func parseCommand(_ args: [String]) throws -> GenerateCommand {
    try GenerateCommand.parse(args)
}

/// Writes a 1×1 PNG to a unique temporary URL and returns the URL.
/// Each call produces a fresh unique path so tests stay parallel-safe.
func makeTempImageFile(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1,
        pixelsHigh: 1,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 4,
        bitsPerPixel: 32
    )!
    bitmap.setColor(.white, atX: 0, y: 0)
    let png = bitmap.representation(using: .png, properties: [:])!
    let url = URL.temporaryDirectory.appending(path: "cli-test-\(UUID().uuidString).png")
    try png.write(to: url)
    return url
}

/// Writes a 64×64 PNG to a unique temporary URL: an opaque square inset by
/// `inset` of each side, or filling the canvas at an inset of 0. An inset of
/// 0.1 is where the macOS icon grid puts an app icon's chiclet.
func makeTempImageFile(inset: Double) throws -> URL {
    let size = 64
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: size * 4,
        bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: size, height: size)
        .insetBy(dx: Double(size) * inset, dy: Double(size) * inset)
        .fill()
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    let url = URL.temporaryDirectory.appending(path: "cli-test-\(UUID().uuidString).png")
    try png.write(to: url)
    return url
}

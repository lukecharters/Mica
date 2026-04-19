import Foundation
import AppKit
import ArgumentParser
@testable import sfIconGen_CLI

/// Convenience wrapper for `IconGeneratorCommand.parse(_:)`.
func parseCommand(_ args: [String]) throws -> IconGeneratorCommand {
    try IconGeneratorCommand.parse(args)
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

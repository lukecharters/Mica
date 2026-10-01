// ForegroundShadowStyleTests.swift
//
// A foreground's shadow comes from its own `shadowStyle`, never from the icon
// background's. Rendered with the background hidden, so the symbol and its shadow
// are the only ink, and compared with a ±1 channel tolerance because ImageRenderer
// output is not byte-deterministic.

import Testing
import AppKit
import SwiftUI
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct ForegroundShadowStyleTests {

    private func iconSymbolOnly(_ style: DropShadowStyle, background: DropShadowStyle = .macOS27) -> IconSettings {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "folder.fill"
        settings.icon.foreground.shadowStyle = style
        settings.icon.background.shadowStyle = background
        settings.icon.background.isHidden = true
        return settings
    }

    private func badgeSymbolOnly(_ style: DropShadowStyle) -> IconSettings {
        var settings = IconSettings()
        settings.icon.foreground.isHidden = true
        settings.icon.background.isHidden = true
        settings.badge.foreground.symbolName = "plus"
        settings.badge.foreground.isHidden = false
        settings.badge.foreground.shadowStyle = style
        settings.badge.background.isHidden = true
        return settings
    }

    @Test("the symbol shadow ignores the background's style",
          arguments: [DropShadowStyle.off, .macOS15, .macOS26])
    func symbolShadowIgnoresBackgroundStyle(_ background: DropShadowStyle) throws {
        let baseline = try render(iconSymbolOnly(.macOS15, background: .macOS27))
        let other = try render(iconSymbolOnly(.macOS15, background: background))
        #expect(try maxChannelDelta(baseline, other) <= 1)
    }

    @Test("each icon foreground style draws a different shadow")
    func iconStylesDiffer() throws {
        let renders = try DropShadowStyle.allCases.map { try render(iconSymbolOnly($0)) }
        for i in renders.indices {
            for j in renders.indices where j > i {
                #expect(try maxChannelDelta(renders[i], renders[j]) > 1,
                        "\(DropShadowStyle.allCases[i]) and \(DropShadowStyle.allCases[j]) rendered alike")
            }
        }
    }

    @Test("a badge foreground style of .off removes its shadow")
    func badgeOffRemovesShadow() throws {
        let on = try render(badgeSymbolOnly(.macOS27))
        let off = try render(badgeSymbolOnly(.off))
        #expect(try maxChannelDelta(on, off) > 1)
    }

    private func render(_ settings: IconSettings) throws -> Data {
        let displaySize: CGFloat = 256
        let view = IconContentView(settings: settings, displaySize: displaySize)
            .frame(width: displaySize, height: displaySize)
        let renderer = ImageRenderer(content: view)
        renderer.isOpaque = false
        let image = try #require(renderer.nsImage)
        return try #require(image.tiffRepresentation)
    }

    private func maxChannelDelta(_ a: Data, _ b: Data) throws -> Int {
        let repA = try #require(NSBitmapImageRep(data: a))
        let repB = try #require(NSBitmapImageRep(data: b))
        try #require(repA.pixelsWide == repB.pixelsWide && repA.pixelsHigh == repB.pixelsHigh)
        try #require(repA.bytesPerRow == repB.bytesPerRow && repA.samplesPerPixel == repB.samplesPerPixel)
        let bytesA = try #require(repA.bitmapData)
        let bytesB = try #require(repB.bitmapData)
        let rowBytes = repA.pixelsWide * repA.samplesPerPixel
        var maxDelta = 0
        for row in 0..<repA.pixelsHigh {
            let offset = row * repA.bytesPerRow
            for i in 0..<rowBytes {
                maxDelta = max(maxDelta, abs(Int(bytesA[offset + i]) - Int(bytesB[offset + i])))
            }
        }
        return maxDelta
    }
}

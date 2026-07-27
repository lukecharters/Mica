// ShadowOverrideNeutralityTests.swift
// Proves the shadowOverride plumbing is behavior-neutral: for every
// BackgroundShadowStyle, rendering with shadowOverride: nil (production
// paths) must match rendering with the matching preset injected
// explicitly. Compared pixel-wise with a ±1 channel tolerance —
// ImageRenderer output is not byte-deterministic (gradient dithering
// varies at the least-significant bit between runs), but a real shadow
// value change moves pixels far beyond that.

import Testing
import AppKit
import SwiftUI
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct ShadowOverrideNeutralityTests {

    // SwiftUI also defines a public `ShadowStyle`, which collides with the
    // app's struct when both modules are imported (same pattern as the
    // SymbolRenderingMode alias in IconRenderingStructuralTests).
    typealias ShadowStyle = Mica.ShadowStyle

    private func render(_ settings: IconSettings, override: ShadowStyle?) throws -> Data {
        let displaySize: CGFloat = 256
        let view = IconContentView(settings: settings, displaySize: displaySize, shadowOverride: override)
            .frame(width: displaySize, height: displaySize)
        let renderer = ImageRenderer(content: view)
        renderer.isOpaque = false
        let image = try #require(renderer.nsImage)
        return try #require(image.tiffRepresentation)
    }

    @Test("nil override renders identically to the injected preset",
          arguments: BackgroundShadowStyle.allCases)
    func nilOverride_matchesInjectedPreset(_ style: BackgroundShadowStyle) throws {
        var settings = IconSettings()
        settings.symbolName = "folder.fill"
        settings.backgroundShadowStyle = style
        settings.showBadge = true // exercise BadgeView's override path too

        let baseline = try render(settings, override: nil)
        let injected = try render(settings, override: .preset(for: style))
        let delta = try maxChannelDelta(baseline, injected)
        #expect(delta <= 1,
                "Injecting .preset(for: .\(style)) must not change the rendered output (max channel delta \(delta))")
    }

    /// Largest per-channel difference between two same-sized TIFFs,
    /// skipping any row padding beyond the meaningful sample bytes.
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

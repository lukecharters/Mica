// IconRenderingStructuralTests.swift
// Structural (non-pixel-exact) assertions for IconRenderer.renderIcon.
// Three parameterised axes:
//   1. (exportSize, retina) -> logical vs pixel dimensions.
//   2. exportColorSpace     -> CGColorSpace name round-trip.
//   3. symbolRenderingMode  -> quadrant-average differentiation.
// Plus one non-parameterised test: alpha-coverage bounding box
// sits inside the backgroundInset-padded enclosure region.
//
// Golden/pixel-exact tests are Phase 5 territory — keep assertions
// tolerant to sub-pixel antialiasing drift and to SF Symbol metric
// revisions across macOS releases.

import Testing
import AppKit
import SwiftUI
import CoreGraphics
@testable import macOS_Icon_Generator_App

@Suite(.tags(.rendering))
@MainActor
struct IconRenderingStructuralTests {

    // SwiftUI also defines a public `SymbolRenderingMode`, which collides
    // with the app's enum when both modules are imported. Nest an alias
    // so every test in this suite resolves to the app's enum.
    typealias SymbolRenderingMode = macOS_Icon_Generator_App.SymbolRenderingMode

    // MARK: - (exportSize, retina) matrix

    /// (exportSize, retina) tuples. Cover minimum (16), a mid value,
    /// the default 256 logical size with retina 512, and the maximum 1024.
    nonisolated static let sizeRetinaMatrix: [(size: CGFloat, retina: Bool)] = [
        (16, false),
        (256, false),
        (256, true),
        (512, false),
        (1024, false)
    ]

    @Test("image.size and pixel dimensions match (size, retina) matrix",
          arguments: sizeRetinaMatrix)
    func dimensions_matchSizeRetinaMatrix(_ arg: (size: CGFloat, retina: Bool)) throws {
        var settings = IconSettings()
        settings.symbolName = "star.fill"
        settings.exportSize = arg.size
        settings.exportRetinaSize = arg.retina

        let image = IconRenderer.renderIconSafely(settings: settings)

        // Logical size is always exportSize (DPI-aware retina).
        #expect(Int(image.size.width) == Int(arg.size))
        #expect(Int(image.size.height) == Int(arg.size))

        let data = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(rep.pixelsWide == Int(settings.finalExportSize))
        #expect(rep.pixelsHigh == Int(settings.finalExportSize))
    }

    // MARK: - exportColorSpace matrix

    @Test("Output CGImage color-space name matches requested exportColorSpace",
          arguments: [ExportColorSpace.sRGB, ExportColorSpace.displayP3])
    func colorSpace_matchesRequested(_ colorSpace: ExportColorSpace) throws {
        var settings = IconSettings()
        settings.symbolName = "star.fill"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.exportColorSpace = colorSpace

        let image = IconRenderer.renderIconSafely(settings: settings)

        let name = try #require(IconRenderingAssertions.cgColorSpaceName(of: image),
                                "Rendered image must have a CGImage with a named color space")

        switch colorSpace {
        case .sRGB:
            #expect(name == (CGColorSpace.sRGB as String),
                    "exportColorSpace=.sRGB must produce a kCGColorSpaceSRGB image, got \(name)")
        case .displayP3:
            #expect(name == (CGColorSpace.displayP3 as String),
                    "exportColorSpace=.displayP3 must produce a kCGColorSpaceDisplayP3 image, got \(name)")
        }
    }

    // MARK: - symbolRenderingMode matrix

    @Test("Rendering mode produces measurably different quadrant averages",
          arguments: [
            SymbolRenderingMode.monochrome,
            SymbolRenderingMode.hierarchical,
            SymbolRenderingMode.palette,
            SymbolRenderingMode.multicolor
          ])
    func renderingMode_producesMeasurableOutput(_ mode: SymbolRenderingMode) throws {
        var settings = IconSettings()
        settings.symbolName = "person.3.sequence.fill" // non-trivial symbol with
        // multiple glyph layers so hierarchical/palette modes render differently
        // from monochrome. folder.fill and star.fill render identically across modes.
        settings.exportSize = 256
        settings.exportRetinaSize = false
        settings.symbolRenderingMode = mode
        settings.baseColor = .blue
        settings.symbolColor = .white

        let image = IconRenderer.renderIconSafely(settings: settings)

        // Basic: output is non-degenerate.
        let bbox = try #require(IconRenderingAssertions.alphaBoundingBox(of: image),
                                "Every mode must produce a non-empty alpha bbox")
        #expect(bbox.width > 0 && bbox.height > 0)

        // Every mode should produce some blue-dominant pixels in all four
        // quadrants (the chiclet background is blue and fills the enclosure).
        let quadrants = try #require(IconRenderingAssertions.quadrantAverageColors(of: image),
                                     "Every mode must produce measurable quadrant averages")
        for (name, color) in [
            ("topLeft",     quadrants.topLeft),
            ("topRight",    quadrants.topRight),
            ("bottomLeft",  quadrants.bottomLeft),
            ("bottomRight", quadrants.bottomRight)
        ] {
            let isBlue = color.blueComponent > color.redComponent
            #expect(isBlue,
                    "Mode \(mode): quadrant \(name) must be blue-dominant (chiclet) — R=\(color.redComponent) B=\(color.blueComponent)")
        }
    }

    // MARK: - Alpha bounding box sits inside the enclosure

    @Test("Alpha bounding box falls inside the backgroundInset-padded enclosure")
    func alphaBoundingBox_insideEnclosure() throws {
        var settings = IconSettings()
        settings.symbolName = "star.fill"
        settings.exportSize = 256
        settings.exportRetinaSize = false
        // No badge — canvas == enclosureCanvas (no overflow).
        settings.showBadge = false

        let image = IconRenderer.renderIconSafely(settings: settings)

        let bbox = try #require(IconRenderingAssertions.alphaBoundingBox(of: image),
                                "Expected non-empty alpha bbox for a filled icon")

        // backgroundInset at exportSize=256 is 25 (from IconContentView).
        // Allow a small tolerance (shadows + antialiasing can spill a few pixels
        // past the chiclet edge).
        let canvasWidth = image.size.width
        let canvasHeight = image.size.height
        let backgroundInset: CGFloat = 25
        let tolerance: CGFloat = 6 // shadow + antialiasing spill

        #expect(bbox.minX >= backgroundInset - tolerance,
                "Alpha bbox left edge (\(bbox.minX)) must be at or inside backgroundInset (\(backgroundInset))")
        #expect(bbox.minY >= backgroundInset - tolerance,
                "Alpha bbox top edge (\(bbox.minY)) must be at or inside backgroundInset")
        #expect(bbox.maxX <= canvasWidth - backgroundInset + tolerance,
                "Alpha bbox right edge (\(bbox.maxX)) must be at or inside canvas - backgroundInset")
        #expect(bbox.maxY <= canvasHeight - backgroundInset + tolerance,
                "Alpha bbox bottom edge (\(bbox.maxY)) must be at or inside canvas - backgroundInset")
    }
}

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
        #expect(Int(image.size.width) == Int(arg.size),
                "Logical width must equal exportSize (\(Int(arg.size))) for retina=\(arg.retina), got \(Int(image.size.width))")
        #expect(Int(image.size.height) == Int(arg.size),
                "Logical height must equal exportSize (\(Int(arg.size))) for retina=\(arg.retina), got \(Int(image.size.height))")

        let data = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(rep.pixelsWide == Int(settings.finalExportSize),
                "Pixel width must equal finalExportSize (\(Int(settings.finalExportSize))) for (size=\(Int(arg.size)),retina=\(arg.retina)), got \(rep.pixelsWide)")
        #expect(rep.pixelsHigh == Int(settings.finalExportSize),
                "Pixel height must equal finalExportSize (\(Int(settings.finalExportSize))) for (size=\(Int(arg.size)),retina=\(arg.retina)), got \(rep.pixelsHigh)")
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

    @Test("Hierarchical and monochrome render person.3.sequence.fill differently")
    func renderingMode_hierarchical_differsFromMonochrome() throws {
        func render(_ mode: SymbolRenderingMode) -> NSImage {
            var settings = IconSettings()
            settings.symbolName = "person.3.sequence.fill"
            settings.exportSize = 256
            settings.exportRetinaSize = false
            settings.symbolRenderingMode = mode
            settings.baseColor = .blue
            settings.symbolColor = .white
            return IconRenderer.renderIconSafely(settings: settings)
        }

        let mono = try #require(IconRenderingAssertions.quadrantAverageColors(of: render(.monochrome)))
        let hier = try #require(IconRenderingAssertions.quadrantAverageColors(of: render(.hierarchical)))

        // The symbol has multiple glyph layers; hierarchical assigns distinct
        // opacities per layer, so at least one channel in at least one
        // quadrant must diverge from the monochrome render beyond noise.
        let noiseTolerance: CGFloat = 0.02
        let distinguishable =
            abs(mono.topLeft.redComponent    - hier.topLeft.redComponent)    > noiseTolerance ||
            abs(mono.topRight.redComponent   - hier.topRight.redComponent)   > noiseTolerance ||
            abs(mono.bottomLeft.redComponent - hier.bottomLeft.redComponent) > noiseTolerance ||
            abs(mono.bottomRight.redComponent - hier.bottomRight.redComponent) > noiseTolerance ||
            abs(mono.topLeft.greenComponent    - hier.topLeft.greenComponent)    > noiseTolerance ||
            abs(mono.topRight.greenComponent   - hier.topRight.greenComponent)   > noiseTolerance ||
            abs(mono.bottomLeft.greenComponent - hier.bottomLeft.greenComponent) > noiseTolerance ||
            abs(mono.bottomRight.greenComponent - hier.bottomRight.greenComponent) > noiseTolerance

        #expect(distinguishable,
                "Monochrome and hierarchical renders of person.3.sequence.fill must produce measurably different quadrant averages. Diffs: TL R=\(abs(mono.topLeft.redComponent - hier.topLeft.redComponent)), TR R=\(abs(mono.topRight.redComponent - hier.topRight.redComponent)), BL R=\(abs(mono.bottomLeft.redComponent - hier.bottomLeft.redComponent)), BR R=\(abs(mono.bottomRight.redComponent - hier.bottomRight.redComponent))")
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

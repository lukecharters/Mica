import AppKit
import SwiftUI
import Testing
@testable import Mica

@Suite(.tags(.rendering))
@MainActor
struct BadgeSymbolFitTests {

    private static func calibration(_ entries: [String: Double], weight: String = "medium") -> SymbolCalibration {
        SymbolCalibration(symbols: entries.mapValues {
            SymbolCalibrationEntry(multiplier: $0, xOffset: 0, yOffset: 0, weight: weight, status: "calibrated")
        })
    }

    private static func resolve(
        _ name: String, multiplier: Double, context: SymbolSizingContext
    ) -> ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: name, calibration: calibration([name: multiplier]), context: context)
    }

    /// Farthest opaque pixel from the centre of a SwiftUI render drawn as `BadgeView`
    /// draws its glyph, in badge radii.
    private static func renderedReach(_ name: String, sizing: ResolvedSymbolSizing, diameter: CGFloat = 200) throws -> Double {
        let view = Image(systemName: name)
            .font(.system(size: diameter * sizing.multiplier, weight: sizing.weight))
            .foregroundColor(.black)
            .symbolRenderingMode(.monochrome)
            .frame(width: 2 * diameter, height: 2 * diameter)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let cg = try #require(renderer.cgImage)
        let w = cg.width, h = cg.height
        let ctx = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let buf = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: w * h * 4)
        var farthest = 0.0
        for y in 0..<h {
            for x in 0..<w where buf[(y * w + x) * 4 + 3] > 127 {
                let dx = Double(x) + 0.5 - Double(w) / 2, dy = Double(y) + 0.5 - Double(h) / 2
                farthest = max(farthest, (dx * dx + dy * dy).squareRoot())
            }
        }
        return farthest / (Double(diameter) / 2)
    }

    // MARK: - The compression curve

    @Test(.tags(.unit))
    func reachBelowTheKneeIsUnchanged() {
        for reach in [0.1, 0.5, 0.7, SymbolSizingService.badgeKnee] {
            #expect(SymbolSizingService.compressedReach(reach) == reach)
        }
    }

    @Test(.tags(.unit))
    func reachAboveTheKneeIsCompressedBelowTheLimit() {
        var previous = SymbolSizingService.badgeKnee
        for reach in stride(from: SymbolSizingService.badgeKnee + 0.01, through: 2.0, by: 0.01) {
            let compressed = SymbolSizingService.compressedReach(reach)
            #expect(compressed < reach)
            #expect(compressed > previous)
            #expect(compressed < SymbolSizingService.badgeLimit)
            previous = compressed
        }
    }

    // MARK: - Resolving for a badge

    @Test func iconContextIsTheDefault() {
        let calibration = Self.calibration(["rectangle.fill": 0.7])
        let implicit = SymbolSizingService.resolve(for: "rectangle.fill", calibration: calibration)
        let explicit = SymbolSizingService.resolve(for: "rectangle.fill", calibration: calibration, context: .icon)
        #expect(implicit.multiplier == explicit.multiplier)
        #expect(implicit.multiplier == 0.7)
    }

    @Test func aRoundGlyphKeepsItsSize() throws {
        let icon = Self.resolve("circle.fill", multiplier: 0.6, context: .icon)
        let badge = Self.resolve("circle.fill", multiplier: 0.6, context: .badge())
        try #require(Self.renderedReach("circle.fill", sizing: icon) < SymbolSizingService.badgeKnee)
        #expect(badge.multiplier == icon.multiplier)
    }

    @Test func aWideGlyphShrinksInsideTheLimit() throws {
        let icon = Self.resolve("rectangle.fill", multiplier: 0.7, context: .icon)
        let badge = Self.resolve("rectangle.fill", multiplier: 0.7, context: .badge())
        try #require(Self.renderedReach("rectangle.fill", sizing: icon) > SymbolSizingService.badgeLimit)
        #expect(badge.multiplier < icon.multiplier)
        #expect(badge.weight == icon.weight)
    }

    /// The measurement centres the glyph on its typographic frame; this is what says
    /// SwiftUI places it there too, so the limit holds on the drawn badge.
    @Test(arguments: ["rectangle.fill", "rectangle.stack.and.person.fill",
                      "textformat.characters.arrow.left.and.right", "hammer", "tv.and.mediabox.fill"])
    func theDrawnGlyphStaysInsideTheLimit(_ name: String) throws {
        let badge = Self.resolve(name, multiplier: 0.7, context: .badge())
        let snapping = 2 / 100.0  // SwiftUI places the glyph on whole points, up to ~0.75pt from the measured centre
        let reach = try Self.renderedReach(name, sizing: badge)
        #expect(reach <= SymbolSizingService.badgeLimit + snapping, "\(name) reaches \(reach)")
    }

    @Test func aHeavierOverrideShrinksTheGlyphFurther() {
        let light = Self.resolve("rectangle.fill", multiplier: 0.7, context: .badge(weight: .ultraLight))
        let heavy = Self.resolve("rectangle.fill", multiplier: 0.7, context: .badge(weight: .black))
        #expect(heavy.multiplier < light.multiplier)
    }
}

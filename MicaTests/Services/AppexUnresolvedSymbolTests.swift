// AppexUnresolvedSymbolTests.swift
// How System mode tells a symbol name IconServices could not resolve from one it could.
//
// For an unresolvable ISSymbolName, IconServices draws the generic extension icon
// rather than failing. The fast tests cover the pixel comparison; the slow ones
// (Full.xctestplan) render through the real appex.

import Testing
import AppKit
@testable import Mica

@Suite(.tags(.unit))
struct AppexPixelMatchTests {

    private func buffer(pixels: Int, value: UInt8 = 100) -> [UInt8] {
        [UInt8](repeating: value, count: pixels * 4)
    }

    private func changing(_ base: [UInt8], pixels: Int, by delta: UInt8) -> [UInt8] {
        var copy = base
        for pixel in 0..<pixels { copy[pixel * 4] &+= delta }
        return copy
    }

    @Test("Identical buffers match")
    func identical() {
        #expect(AppexReferenceService.pixelsMatch(buffer(pixels: 1000), buffer(pixels: 1000)))
    }

    @Test("A difference of 8 in a channel does not count as a differing pixel")
    func smallDifferenceIgnored() {
        let base = buffer(pixels: 1000)
        #expect(AppexReferenceService.pixelsMatch(base, changing(base, pixels: 1000, by: 8)))
    }

    @Test("Under 0.5% of pixels differing still matches; 0.5% or more does not",
          arguments: [(4, true), (5, false), (500, false)])
    func threshold(differing: Int, matches: Bool) {
        let base = buffer(pixels: 1000)
        #expect(AppexReferenceService.pixelsMatch(base, changing(base, pixels: differing, by: 9)) == matches)
    }

    @Test("Buffers of different sizes, or empty ones, never match")
    func mismatchedSizes() {
        #expect(!AppexReferenceService.pixelsMatch(buffer(pixels: 10), buffer(pixels: 11)))
        #expect(!AppexReferenceService.pixelsMatch([], []))
    }
}

@Suite(.tags(.rendering, .slow),
       .enabled(if: TestFilters.runSlowTests, "Slow test — run via Full.xctestplan (RUN_SLOW_TESTS=1)"))
struct AppexUnresolvedSymbolTests {

    private func render(_ name: String, size: CGFloat, scale: Int, space: ExportColorSpace,
                        enclosure: AppexPlistColor = .defaultEnclosure) throws -> NSImage {
        try AppexReferenceService.renderForExport(
            symbolName: name,
            enclosureColor: enclosure,
            symbolColor: .defaultSymbol,
            pointSize: size,
            scaleFactor: scale,
            colorSpace: space
        )
    }

    @Test("A nonsense name is recognised as unresolved, and a real one is not",
          arguments: [(CGFloat(64), 1, ExportColorSpace.sRGB), (512, 2, .displayP3)])
    func recognised(size: CGFloat, scale: Int, space: ExportColorSpace) throws {
        let bogus = try render("zz.not.a.symbol", size: size, scale: scale, space: space)
        let real = try render("circle", size: size, scale: scale, space: space)
        #expect(AppexReferenceService.isUnresolvedSymbolRender(bogus, pointSize: size, scaleFactor: scale, colorSpace: space))
        #expect(!AppexReferenceService.isUnresolvedSymbolRender(real, pointSize: size, scaleFactor: scale, colorSpace: space))
    }

    @Test("The stand-in does not depend on the enclosure colour")
    func colourIndependent() throws {
        let red = try AppexPlistColor(validating: "red", role: .enclosure)
        let bogus = try render("zz.not.a.symbol", size: 128, scale: 1, space: .sRGB, enclosure: red)
        #expect(AppexReferenceService.isUnresolvedSymbolRender(bogus, pointSize: 128, scaleFactor: 1, colorSpace: .sRGB))
    }
}

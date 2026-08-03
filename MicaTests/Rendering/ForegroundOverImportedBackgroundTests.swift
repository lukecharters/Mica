// ForegroundOverImportedBackgroundTests.swift
// An imported background hides its group's foreground as a *default*, not as a
// render-level veto — so switching the foreground back on draws both layers.
// This is the assertion that could not have been written before phase 3: the
// render used to gate the foreground on `background.source != .image`, and no
// setting could reach past it.
//
// Strategy: render with the foreground hidden, then visible, and compare the
// drawn area over the chiclet. A visible foreground can only add ink, never
// remove it, so "more is drawn" is the whole claim and it is robust to symbol
// metrics and antialiasing. The artwork is a solid fill and the symbol colour
// contrasts with it, so the difference is real coverage rather than a tie.

import Testing
import AppKit
@testable import Mica

@Suite("Foreground over an imported background", .tags(.rendering))
@MainActor
struct ForegroundOverImportedBackgroundTests {

    /// Ink over the chiclet, as a fraction of the chiclet's area. Counts pixels
    /// differing from the artwork's flat colour, so it measures the *foreground*
    /// rather than the background it sits on.
    private func foregroundInkFraction(_ image: NSImage,
                                       canvas: CGFloat,
                                       artwork: NSColor) -> Double {
        let inset = (canvas - PreviewHitTester.enclosureSize(displaySize: canvas)) / 2
        let rect = CGRect(x: inset, y: inset,
                          width: canvas - 2 * inset, height: canvas - 2 * inset)
        return IconRenderingAssertions.fractionDiffering(in: image, rect: rect, from: artwork)
    }

    @Test("The icon foreground draws over an imported background once switched back on")
    func iconForeground_drawsOverImportedBackground() throws {
        let artwork = NSColor.white
        var settings = IconSettings()
        settings.export.size = 512
        settings.export.isRetina = false
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.foreground.color = .init(resolving: .black)
        settings.icon.foreground.drawsShadow = false
        settings.icon.applyBackgroundImage(
            try ImportedImage.testFixture(width: 64, height: 64, fill: artwork))
        settings.icon.background.compensatesForPadding = false

        // The import hid it (phase 2's seam).
        #expect(settings.icon.foreground.isHidden == true)
        let canvas = settings.export.pixelSize
        let hidden = foregroundInkFraction(
            IconRenderer.renderIconSafely(settings: settings), canvas: canvas, artwork: artwork)

        settings.icon.foreground.isHidden = false
        let visible = foregroundInkFraction(
            IconRenderer.renderIconSafely(settings: settings), canvas: canvas, artwork: artwork)

        #expect(visible > hidden + 0.02,
                "Revealing the foreground added \(visible - hidden) of the chiclet; the imported background is still suppressing it")
    }

    @Test("The badge symbol draws over an imported badge background once switched back on")
    func badgeForeground_drawsOverImportedBackground() throws {
        let artwork = NSColor.white
        var settings = IconSettings()
        settings.export.size = 512
        settings.export.isRetina = false
        // Leave the badge as the only thing on the canvas, so the measurement is
        // entirely about the badge's two layers.
        settings.icon.isHidden = true
        settings.badge.isVisible = true
        settings.badge.scale = 1.0
        settings.badge.foreground.symbolName = "plus"
        settings.badge.foreground.color = .init(resolving: .black)
        settings.badge.foreground.drawsShadow = false
        settings.badge.applyBackgroundImage(
            try ImportedImage.testFixture(width: 64, height: 64, fill: artwork))
        settings.badge.background.compensatesForPadding = false

        #expect(settings.badge.foreground.isHidden == true)
        let canvas = settings.export.pixelSize
        let full = CGRect(x: 0, y: 0, width: canvas, height: canvas)

        let hidden = IconRenderingAssertions.fractionDiffering(
            in: IconRenderer.renderIconSafely(settings: settings), rect: full, from: artwork)

        settings.badge.foreground.isHidden = false
        let visible = IconRenderingAssertions.fractionDiffering(
            in: IconRenderer.renderIconSafely(settings: settings), rect: full, from: artwork)

        #expect(visible > hidden,
                "Revealing the badge symbol changed nothing (\(hidden) → \(visible)); the imported badge background is still suppressing it")
    }

    // MARK: - Hit testing must agree with the render

    @Test("Clicking the icon foreground over an imported background selects it once visible")
    func iconForegroundIsClickable_overImportedBackground() throws {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.fill"
        settings.icon.applyBackgroundImage(try ImportedImage.testFixture())

        let display: CGFloat = 512
        let centre = CGPoint(x: display / 2, y: display / 2)

        // Hidden: the click falls through to the background, exactly as before.
        #expect(PreviewHitTester.target(at: centre, settings: settings, displaySize: display)
                    == .iconBackground)

        settings.icon.foreground.isHidden = false
        #expect(PreviewHitTester.target(at: centre, settings: settings, displaySize: display)
                    == .iconForeground)
    }

    @Test("Clicking the badge symbol over imported badge artwork selects it once visible")
    func badgeForegroundIsClickable_overImportedBackground() throws {
        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.foreground.symbolName = "plus"
        settings.badge.applyBackgroundImage(try ImportedImage.testFixture())

        let display: CGFloat = 512
        let centre = CGPoint(x: display / 2, y: display / 2)
        let enclosure = PreviewHitTester.enclosureSize(displaySize: display)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
        let badgeCentre = CGPoint(x: centre.x + offset.width, y: centre.y + offset.height)

        // Hidden: the whole footprint is the background, as it was when a drawn
        // imported background suppressed the glyph outright.
        #expect(PreviewHitTester.target(at: badgeCentre, settings: settings, displaySize: display)
                    == .badgeBackground)

        settings.badge.foreground.isHidden = false
        #expect(PreviewHitTester.target(at: badgeCentre, settings: settings, displaySize: display)
                    == .badgeForeground)
    }

    @Test("A System-mode badge stays one layer")
    func systemBadgeRemainsASingleLayer() throws {
        // The other squircle case, and it must *not* split: symbol and enclosure are
        // baked into one appex image, so there is no glyph to pick.
        var settings = IconSettings()
        settings.badge.isVisible = true
        settings.badge.mode = .system

        let display: CGFloat = 512
        let centre = CGPoint(x: display / 2, y: display / 2)
        let enclosure = PreviewHitTester.enclosureSize(displaySize: display)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
        let badgeCentre = CGPoint(x: centre.x + offset.width, y: centre.y + offset.height)

        #expect(PreviewHitTester.target(at: badgeCentre, settings: settings, displaySize: display)
                    == .badgeBackground)
    }
}

// PreviewHitTesterTests.swift
// Geometry tests for canvas click-to-select. Expected badge centres and radii are
// computed through BadgeGeometry rather than hard-coded, so these tests pin the
// hit regions to the same source of truth the renderer uses. Symbol sizing is
// injected so results don't depend on shipped calibration data.

import Testing
import CoreGraphics
@testable import Mica

@Suite(.tags(.unit))
struct PreviewHitTesterTests {

    // MARK: - Fixtures

    /// 256pt canvas → 206pt enclosure (256 − 2×25).
    private static let displaySize: CGFloat = 256

    /// Half the symbol box sits either side of centre; multiplier 0.5 keeps the
    /// arithmetic obvious (206 × 0.5 = 103pt box).
    private static let sizing = ResolvedSymbolSizing(
        multiplier: 0.5,
        xOffset: 0,
        yOffset: 0,
        weight: .regular,
        source: .familyCalibration
    )

    private static func enclosure(_ displaySize: CGFloat = displaySize) -> CGFloat {
        PreviewHitTester.enclosureSize(displaySize: displaySize)
    }

    private static func canvasCentre(_ settings: IconSettings, _ displaySize: CGFloat = displaySize) -> CGPoint {
        let side = IconContentView.totalCanvasSize(for: settings, displaySize: displaySize)
        return CGPoint(x: side / 2, y: side / 2)
    }

    /// Badge centre and radius in canvas coordinates, straight from BadgeGeometry.
    private static func badgeCircle(_ settings: IconSettings, _ displaySize: CGFloat = displaySize) -> (centre: CGPoint, radius: CGFloat) {
        let enclosure = enclosure(displaySize)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
        let centre = canvasCentre(settings, displaySize)
        return (
            CGPoint(x: centre.x + offset.width, y: centre.y + offset.height),
            BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: settings.badgeScale) / 2
        )
    }

    private static func hit(_ point: CGPoint, _ settings: IconSettings, _ displaySize: CGFloat = displaySize) -> PreviewHitTarget? {
        PreviewHitTester.target(at: point, settings: settings, displaySize: displaySize, symbolSizing: sizing)
    }

    /// Icon with a visible badge, both badge layers on.
    private static func settingsWithBadge() -> IconSettings {
        var s = IconSettings()
        s.showBadge = true
        s.badgePosition = .bottomRight
        return s
    }

    // MARK: - Badge: glyph vs ring

    @Test("Badge centre hits the badge foreground")
    func badgeCentre_isForeground() {
        let s = Self.settingsWithBadge()
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeForeground)
    }

    @Test("Just inside the badge edge hits the badge background")
    func badgeRing_isBackground() {
        let s = Self.settingsWithBadge()
        let (centre, radius) = Self.badgeCircle(s)
        let point = CGPoint(x: centre.x + radius * 0.9, y: centre.y)
        #expect(Self.hit(point, s) == .badgeBackground)
    }

    @Test("The glyph/ring boundary is badgeInnerHitRatio of the radius")
    func badgeInnerRatio_boundary() {
        let s = Self.settingsWithBadge()
        let (centre, radius) = Self.badgeCircle(s)
        let boundary = radius * PreviewHitTester.badgeInnerHitRatio

        let inside = CGPoint(x: centre.x + boundary - 0.5, y: centre.y)
        let outside = CGPoint(x: centre.x + boundary + 0.5, y: centre.y)
        #expect(Self.hit(inside, s) == .badgeForeground)
        #expect(Self.hit(outside, s) == .badgeBackground)
    }

    @Test("Hidden badge foreground makes the whole badge background")
    func badgeForegroundHidden_centreIsBackground() {
        var s = Self.settingsWithBadge()
        s.badgeForegroundHidden = true
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeBackground)
    }

    @Test("Hidden badge background makes the ring select the glyph")
    func badgeBackgroundHidden_ringIsForeground() {
        var s = Self.settingsWithBadge()
        s.badgeBackgroundHidden = true
        let (centre, radius) = Self.badgeCircle(s)
        let point = CGPoint(x: centre.x + radius * 0.9, y: centre.y)
        #expect(Self.hit(point, s) == .badgeForeground)
    }

    @Test("A visible imported badge background suppresses the glyph target")
    func badgeImportedBackground_centreIsBackground() throws {
        var s = Self.settingsWithBadge()
        s.badgeUseImportedBackground = true
        s.badgeImportedBackground = try ImportedImage.testFixture()
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeBackground)
    }

    @Test("The imported-background flag alone does not suppress the glyph")
    func badgeImportedFlagWithoutImage_centreStaysForeground() {
        var s = Self.settingsWithBadge()
        s.badgeUseImportedBackground = true // no image chosen yet
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeForeground)
    }

    // MARK: - Badge: position, offset, scale

    @Test("Badge hit region follows badgePosition", arguments: BadgePosition.allCases)
    func badgePosition_movesHitRegion(position: BadgePosition) {
        var s = Self.settingsWithBadge()
        s.badgePosition = position
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeForeground)
    }

    @Test("Badge hit region follows the manual offset")
    func badgeManualOffset_movesHitRegion() {
        var s = Self.settingsWithBadge()
        s.badgeManualOffsetX = 0.3
        s.badgeManualOffsetY = -0.2

        // The offset badge is hit at its new centre...
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeForeground)

        // ...and no longer at the un-offset anchor.
        var unoffset = s
        unoffset.badgeManualOffsetX = 0
        unoffset.badgeManualOffsetY = 0
        let oldCentre = Self.badgeCircle(unoffset).centre
        #expect(Self.hit(oldCentre, s) != .badgeForeground)
    }

    @Test("Badge still resolves when a large scale overflows the canvas")
    func badgeLargeScale_stillResolves() {
        var s = Self.settingsWithBadge()
        s.badgeScale = 2.0
        let canvas = IconContentView.totalCanvasSize(for: s, displaySize: Self.displaySize)
        #expect(canvas > Self.displaySize) // overflow actually happened
        #expect(Self.hit(Self.badgeCircle(s).centre, s) == .badgeForeground)
    }

    @Test("A hidden badge lets clicks fall through to the icon")
    func badgeHidden_fallsThroughToIcon() {
        var withBadge = Self.settingsWithBadge()
        let badgeCentre = Self.badgeCircle(withBadge).centre
        withBadge.showBadge = false
        // The badge sat over the chiclet's bottom-right corner region.
        let target = Self.hit(badgeCentre, withBadge)
        #expect(target != .badgeForeground)
        #expect(target != .badgeBackground)
    }

    // MARK: - Icon foreground

    @Test("Canvas centre hits the icon foreground")
    func iconCentre_isForeground() {
        let s = IconSettings()
        #expect(Self.hit(Self.canvasCentre(s), s) == .iconForeground)
    }

    @Test("Just outside the symbol box hits the icon background")
    func outsideSymbolBox_isBackground() {
        let s = IconSettings()
        let centre = Self.canvasCentre(s)
        let half = Self.enclosure() * Self.sizing.multiplier * s.manualSymbolScale / 2
        #expect(Self.hit(CGPoint(x: centre.x + half - 0.5, y: centre.y), s) == .iconForeground)
        #expect(Self.hit(CGPoint(x: centre.x + half + 0.5, y: centre.y), s) == .iconBackground)
    }

    @Test("manualSymbolScale grows the foreground hit box")
    func manualSymbolScale_growsHitBox() {
        var s = IconSettings()
        let centre = Self.canvasCentre(s)
        let halfAtDefault = Self.enclosure() * Self.sizing.multiplier * s.manualSymbolScale / 2
        let justOutside = CGPoint(x: centre.x + halfAtDefault + 2, y: centre.y)
        #expect(Self.hit(justOutside, s) == .iconBackground)

        s.manualSymbolScale *= 1.5
        #expect(Self.hit(justOutside, s) == .iconForeground)
    }

    @Test("Symbol offsets shift the foreground hit box")
    func symbolOffsets_shiftHitBox() {
        let s = IconSettings()
        let offsetSizing = ResolvedSymbolSizing(
            multiplier: 0.5, xOffset: 0.2, yOffset: 0, weight: .regular, source: .familyCalibration
        )
        let centre = Self.canvasCentre(s)
        let half = Self.enclosure() * 0.5 / 2
        // Beyond the un-shifted box's right edge, but inside once shifted right.
        let point = CGPoint(x: centre.x + half + 2, y: centre.y)

        #expect(PreviewHitTester.target(at: point, settings: s, displaySize: Self.displaySize,
                                       symbolSizing: offsetSizing) == .iconForeground)
        #expect(Self.hit(point, s) == .iconBackground)
    }

    @Test("Hidden icon foreground falls through to the background")
    func iconForegroundHidden_isBackground() {
        var s = IconSettings()
        s.iconForegroundHidden = true
        #expect(Self.hit(Self.canvasCentre(s), s) == .iconBackground)
    }

    @Test("An imported background replaces the foreground target")
    func importedBackground_centreIsBackground() throws {
        var s = IconSettings()
        s.backgroundMode = .importedImage
        s.importedBackground = try ImportedImage.testFixture()
        // Mirrors IconContentView, which skips the foreground entirely here.
        #expect(Self.hit(Self.canvasCentre(s), s) == .iconBackground)
    }

    @Test("A custom foreground image is hit across its 0.85-enclosure box")
    func customImageForeground_hitBox() throws {
        var s = IconSettings()
        s.iconSource = .customImage
        s.importedImage = try ImportedImage.testFixture()
        let centre = Self.canvasCentre(s)
        let half = Self.enclosure() * 0.85 * s.importedImageScale / 2

        #expect(Self.hit(centre, s) == .iconForeground)
        #expect(Self.hit(CGPoint(x: centre.x + half - 0.5, y: centre.y), s) == .iconForeground)
        #expect(Self.hit(CGPoint(x: centre.x + half + 0.5, y: centre.y), s) == .iconBackground)
    }

    @Test("A custom foreground with no image chosen is not hittable")
    func customImageWithoutImage_isBackground() {
        var s = IconSettings()
        s.iconSource = .customImage
        #expect(Self.hit(Self.canvasCentre(s), s) == .iconBackground)
    }

    // MARK: - Chiclet edges

    @Test("The canvas margin outside the chiclet hits nothing")
    func canvasMargin_isNil() {
        let s = IconSettings()
        // Top-left canvas corner is outside the inset chiclet.
        #expect(Self.hit(CGPoint(x: 2, y: 2), s) == nil)
    }

    @Test("The chiclet's rounded corner is outside the hit region")
    func chicletCorner_isNil() {
        var s = IconSettings()
        s.cornerRadiusStyle = .macOS26
        let centre = Self.canvasCentre(s)
        let half = Self.enclosure() / 2
        // Exact corner of the bounding square, well outside a 54pt corner arc.
        let corner = CGPoint(x: centre.x - half + 1, y: centre.y - half + 1)
        #expect(Self.hit(corner, s) == nil)
    }

    @Test("A point inside the chiclet edge, clear of the corners, hits the background")
    func chicletEdge_isBackground() {
        let s = IconSettings()
        let centre = Self.canvasCentre(s)
        let half = Self.enclosure() / 2
        // Mid-height on the left edge: no corner rounding in play.
        #expect(Self.hit(CGPoint(x: centre.x - half + 1, y: centre.y), s) == .iconBackground)
    }

    @Test("Hidden icon background makes chiclet clicks a no-op, symbol clicks still work")
    func iconBackgroundHidden_chicletIsNil() {
        var s = IconSettings()
        s.iconBackgroundHidden = true
        let centre = Self.canvasCentre(s)
        let half = Self.enclosure() / 2

        #expect(Self.hit(CGPoint(x: centre.x - half + 1, y: centre.y), s) == nil)
        #expect(Self.hit(centre, s) == .iconForeground)
    }

    // MARK: - System-mode preview

    @Test("System preview resolves badge glyph, ring, chiclet and outside")
    func systemTarget_regions() {
        let s = Self.settingsWithBadge()
        let iconSize = Self.displaySize
        let enclosure = PreviewHitTester.enclosureSize(displaySize: iconSize)
        let centre = CGPoint(x: iconSize / 2, y: iconSize / 2)
        let offset = BadgeGeometry.offset(for: s, enclosureSize: enclosure)
        let badgeCentre = CGPoint(x: centre.x + offset.width, y: centre.y + offset.height)
        let radius = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: s.badgeScale) / 2

        func systemHit(_ point: CGPoint) -> PreviewHitTarget? {
            PreviewHitTester.systemTarget(at: point, settings: s, iconSize: iconSize)
        }

        #expect(systemHit(badgeCentre) == .badgeForeground)
        #expect(systemHit(CGPoint(x: badgeCentre.x + radius * 0.9, y: badgeCentre.y)) == .badgeBackground)
        #expect(systemHit(centre) == .iconBackground)
        #expect(systemHit(CGPoint(x: 2, y: 2)) == nil)
    }

    @Test("System preview enclosure matches the appex pane's 1 − 50/256 ratio")
    func systemTarget_enclosureRatio() {
        // Pins PreviewHitTester against AppexPreviewPane's inlined derivation.
        let iconSize: CGFloat = 512
        #expect(PreviewHitTester.enclosureSize(displaySize: iconSize) == iconSize * (1 - 50.0 / 256.0))
    }

    // MARK: - PreviewSelection mapping

    @Test("Group + tab maps to the layer the preview should outline")
    func previewSelection_fromGroupAndTab() {
        #expect(PreviewSelection.from(group: .icon, tab: .foreground, isSystem: false) == .iconForeground)
        #expect(PreviewSelection.from(group: .icon, tab: .background, isSystem: false) == .iconBackground)
        #expect(PreviewSelection.from(group: .badge, tab: .foreground, isSystem: false) == .badgeForeground)
        #expect(PreviewSelection.from(group: .badge, tab: .background, isSystem: false) == .badgeBackground)
        // The badge's Layout tab edits the badge as a whole.
        #expect(PreviewSelection.from(group: .badge, tab: .layout, isSystem: false) == .badge)
    }

    @Test("System mode outlines the whole group regardless of tab", arguments: LayerTab.allCases)
    func previewSelection_systemIsWholeGroup(tab: LayerTab) {
        #expect(PreviewSelection.from(group: .icon, tab: tab, isSystem: true) == .icon)
        #expect(PreviewSelection.from(group: .badge, tab: tab, isSystem: true) == .badge)
    }

    // MARK: - Selection outline geometry

    private static func shape(_ selection: PreviewSelection, _ settings: IconSettings) -> PreviewSelectionShape? {
        PreviewHitTester.selectionShape(
            for: selection,
            settings: settings,
            displaySize: displaySize,
            symbolSizing: sizing,
            badgeSymbolSizing: sizing
        )
    }

    @Test("Icon background outlines the chiclet at the enclosure and corner radius")
    func selectionShape_iconBackground() throws {
        var s = IconSettings()
        s.cornerRadiusStyle = .macOS26
        let centre = Self.canvasCentre(s)
        let enclosure = Self.enclosure()

        guard case .roundedRect(let rect, let cornerRadius)? = Self.shape(.iconBackground, s) else {
            Issue.record("Expected a rounded rect for the icon background")
            return
        }
        #expect(rect.width == enclosure)
        #expect(rect.height == enclosure)
        #expect(rect.midX == centre.x)
        #expect(rect.midY == centre.y)
        #expect(cornerRadius == 54 * (Self.displaySize / 256))
    }

    @Test("System-mode icon outlines the same chiclet as the icon background")
    func selectionShape_iconWholeMatchesBackground() {
        let s = IconSettings()
        #expect(Self.shape(.icon, s) == Self.shape(.iconBackground, s))
    }

    @Test("Icon foreground outlines the symbol box")
    func selectionShape_iconForeground() throws {
        let s = IconSettings()
        let expectedSide = Self.enclosure() * Self.sizing.multiplier * s.manualSymbolScale

        guard case .roundedRect(let rect, _)? = Self.shape(.iconForeground, s) else {
            Issue.record("Expected a rounded rect for the icon foreground")
            return
        }
        // Tolerance, not equality: the side is derived through a chain of
        // CGFloat/Double multiplications that can land a ulp apart.
        #expect(abs(rect.width - expectedSide) < 0.001)
        #expect(abs(rect.midX - Self.canvasCentre(s).x) < 0.001)
    }

    @Test("Badge and badge background outline the full badge circle")
    func selectionShape_badgeCircle() throws {
        let s = Self.settingsWithBadge()
        let (expectedCentre, expectedRadius) = Self.badgeCircle(s)

        for selection in [PreviewSelection.badge, .badgeBackground] {
            guard case .circle(let centre, let radius)? = Self.shape(selection, s) else {
                Issue.record("Expected a circle for \(selection)")
                return
            }
            #expect(radius == expectedRadius)
            #expect(abs(centre.x - expectedCentre.x) < 0.001)
            #expect(abs(centre.y - expectedCentre.y) < 0.001)
        }
    }

    @Test("Badge foreground outlines the glyph box, not the click circle")
    func selectionShape_badgeForegroundIsGlyphBox() throws {
        let s = Self.settingsWithBadge()
        let (badgeCentre, radius) = Self.badgeCircle(s)
        let expectedSide = radius * 2 * Self.sizing.multiplier * s.badgeSymbolScale

        guard case .roundedRect(let rect, _)? = Self.shape(.badgeForeground, s) else {
            Issue.record("Expected a rounded rect for the badge foreground")
            return
        }
        #expect(abs(rect.width - expectedSide) < 0.001)
        #expect(abs(rect.midX - badgeCentre.x) < 0.001)
        #expect(abs(rect.midY - badgeCentre.y) < 0.001)
    }

    @Test("Nothing drawn means nothing outlined")
    func selectionShape_nilWhenNothingDrawn() throws {
        var noBadge = IconSettings()
        noBadge.showBadge = false
        #expect(Self.shape(.badge, noBadge) == nil)
        #expect(Self.shape(.badgeForeground, noBadge) == nil)
        #expect(Self.shape(.badgeBackground, noBadge) == nil)

        // An imported background replaces the icon's foreground.
        var importedBg = IconSettings()
        importedBg.backgroundMode = .importedImage
        importedBg.importedBackground = try ImportedImage.testFixture()
        #expect(Self.shape(.iconForeground, importedBg) == nil)

        // A System-mode badge has no separate glyph to box.
        var systemBadge = Self.settingsWithBadge()
        systemBadge.badgeIconSource = .system
        #expect(Self.shape(.badgeForeground, systemBadge) == nil)
    }

    @Test("A hidden layer still outlines, so the user can see what they're editing")
    func selectionShape_hiddenLayerStillOutlines() {
        var s = IconSettings()
        s.iconBackgroundHidden = true
        s.iconForegroundHidden = true
        #expect(Self.shape(.iconBackground, s) != nil)
        #expect(Self.shape(.iconForeground, s) != nil)
    }

    // MARK: - Target mapping

    @Test("Targets map to the right group and tab")
    func targetMapping() {
        #expect(PreviewHitTarget.iconForeground.group == .icon)
        #expect(PreviewHitTarget.iconForeground.tab == .foreground)
        #expect(PreviewHitTarget.iconBackground.group == .icon)
        #expect(PreviewHitTarget.iconBackground.tab == .background)
        #expect(PreviewHitTarget.badgeForeground.group == .badge)
        #expect(PreviewHitTarget.badgeForeground.tab == .foreground)
        #expect(PreviewHitTarget.badgeBackground.group == .badge)
        #expect(PreviewHitTarget.badgeBackground.tab == .background)
    }

    @Test("Every target's tab is available for its group")
    func targetTabsAreAvailable() {
        for target in [PreviewHitTarget.iconForeground, .iconBackground, .badgeForeground, .badgeBackground] {
            let tabs = LayerTab.availableTabs(for: target.group, isSystem: false)
            #expect(tabs.contains(target.tab))
        }
    }
}

// PreviewDropTests.swift
//
// Item B4: what a canvas drop accepts, and which layer it lands on. Since
// 2026-10-11 also the layer-aware routing (advanced controls on), the sidebar
// rows as drop targets, and what the preview outlines during a drag.
//
// Only the two decidable halves are tested here — the declared type list and
// the routing — because they are the two that can be wrong *quietly*. A drag
// carrying image data that is never offered to the view looks exactly like a
// drag the sender refused to start, and a drop that always lands on the icon
// looks exactly like a drop that landed nowhere. `PreviewDrop.load` is not
// tested: it is `NSItemProvider` plumbing whose failure is a visible drop that
// does nothing, and a fake provider would only assert that the mock behaves like
// the mock.
//
// Badge geometry comes from `BadgeGeometry` via the same route
// `PreviewHitTesterTests` uses, so these cannot drift from the render.

import Testing
import CoreGraphics
import UniformTypeIdentifiers
@testable import Mica

@Suite(.tags(.unit))
struct PreviewDropTests {

    // MARK: - Fixtures

    /// 256pt canvas → 206pt enclosure (256 − 2×25).
    private static let displaySize: CGFloat = 256

    private static func settingsWithBadge() -> IconSettings {
        var s = IconSettings()
        s.badge.isVisible = true
        s.badge.position = .bottomRight
        return s
    }

    /// Badge centre in canvas coordinates, straight from `BadgeGeometry`.
    private static func badgeCentre(_ settings: IconSettings) -> CGPoint {
        let enclosure = PreviewHitTester.enclosureSize(displaySize: displaySize)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
        return CGPoint(x: displaySize / 2 + offset.width, y: displaySize / 2 + offset.height)
    }

    /// Simple mode by default, which is the routing every test written before
    /// 2026-10-11 describes.
    private static func target(_ point: CGPoint, _ settings: IconSettings,
                               advanced: Bool = false) -> PreviewHitTarget {
        PreviewDrop.target(at: point, settings: settings, displaySize: displaySize,
                           advancedControlsEnabled: advanced)
    }

    private static var canvasCentre: CGPoint {
        CGPoint(x: displaySize / 2, y: displaySize / 2)
    }

    /// A point on the badge outside the glyph's inner hit region but inside the
    /// circle: 90% of the way to the rim.
    private static func badgeRing(_ settings: IconSettings) -> CGPoint {
        let enclosure = PreviewHitTester.enclosureSize(displaySize: displaySize)
        let radius = BadgeGeometry.diameter(enclosureSize: enclosure, badgeScale: settings.badge.scale) / 2
        let centre = badgeCentre(settings)
        return CGPoint(x: centre.x, y: centre.y + radius * 0.9)
    }

    // MARK: - Declared types
    //
    // The list is the whole of item B4's first gap: a type the view does not
    // declare is a drag the importer is never offered, however well it could
    // have read the bytes.

    @Test("A drag carrying only image data is offered to the canvas",
          arguments: [UTType.png, .tiff, .jpeg, .heic, .gif, .bmp, .webP, .svg])
    func allDropTypes_coverImageData(_ type: UTType) {
        // A type the view does not declare is a drag the importer never sees.
        #expect(ImageImportService.allDropTypes.contains { type.conforms(to: $0) },
                "\(type.identifier) must conform to a declared drop type")
    }

    @Test("File URLs are still declared, so a Finder drag keeps its filename path")
    func allDropTypes_stillCoverFileURLs() {
        #expect(ImageImportService.allDropTypes.contains(.fileURL))
    }

    @Test("A remote URL is deliberately not accepted")
    func allDropTypes_excludeRemoteURLs() {
        // Safari's image drags carry a network URL too. Fetching one is a
        // sandboxed request with its own failure and progress story — explicitly
        // out of scope for B4, and pinned so it is not added by reflex.
        #expect(!ImageImportService.allDropTypes.contains(.url))
    }

    // MARK: - Choosing a representation

    @Test("The first image-conforming identifier is chosen")
    func imageTypeIdentifier_picksTheImageType() {
        let chosen = PreviewDrop.imageTypeIdentifier(
            among: ["public.url", "public.utf8-plain-text", "public.png"]
        )
        #expect(chosen == "public.png")
    }

    @Test("A concrete type is chosen, never the abstract supertype")
    func imageTypeIdentifier_prefersWhatTheSenderRegistered() {
        // `loadFileRepresentation` wants an identifier the sender actually
        // registered; asking it for `public.image` is not guaranteed to resolve.
        let chosen = PreviewDrop.imageTypeIdentifier(among: ["public.tiff", "public.png"])
        #expect(chosen == "public.tiff")
    }

    @Test("A provider with nothing image-shaped yields no identifier")
    func imageTypeIdentifier_rejectsNonImages() {
        #expect(PreviewDrop.imageTypeIdentifier(among: ["public.utf8-plain-text"]) == nil)
        #expect(PreviewDrop.imageTypeIdentifier(among: ["public.file-url"]) == nil)
        #expect(PreviewDrop.imageTypeIdentifier(among: []) == nil)
    }

    @Test("An identifier no UTType knows is skipped, not assumed")
    func imageTypeIdentifier_skipsPrivateTypes() {
        let chosen = PreviewDrop.imageTypeIdentifier(
            among: ["com.example.some-private-drag-type", "public.jpeg"]
        )
        #expect(chosen == "public.jpeg")
    }

    // MARK: - Routing

    @Test("A drop on the badge lands on the badge")
    func target_onBadge_isBadgeBackground() {
        let s = Self.settingsWithBadge()
        #expect(Self.target(Self.badgeCentre(s), s) == .badgeBackground)
    }

    @Test("In simple mode, a drop on the badge glyph lands on the badge background")
    func target_onBadgeGlyph_isStillBackground() {
        // The badge centre is the *foreground*'s hit region — clicking it selects
        // the glyph. A drop is narrowed to the group's background regardless,
        // because that is the only layer an arbitrary image can fill, and it is
        // what Edit ▸ Paste as Badge Background does with the same image.
        let s = Self.settingsWithBadge()
        #expect(PreviewHitTester.target(at: Self.badgeCentre(s), settings: s,
                                        displaySize: Self.displaySize) == .badgeForeground)
        #expect(Self.target(Self.badgeCentre(s), s) == .badgeBackground)
    }

    @Test("A drop on the chiclet lands on the icon")
    func target_onIcon_isIconBackground() {
        let s = Self.settingsWithBadge()
        let centre = CGPoint(x: Self.displaySize / 2, y: Self.displaySize / 2)
        #expect(Self.target(centre, s) == .iconBackground)
    }

    @Test("A drop on the canvas margin still lands on the icon")
    func target_onNothing_fallsBackToIcon() {
        // The top-left pixel is outside the chiclet entirely, so the hit tester
        // returns nil. Every drop landed on the icon background before B4, and one
        // that misses everything still does — the habit survives the change.
        let s = Self.settingsWithBadge()
        #expect(PreviewHitTester.target(at: .zero, settings: s,
                                        displaySize: Self.displaySize) == nil)
        #expect(Self.target(.zero, s) == .iconBackground)
    }

    @Test("With the badge hidden, a drop where it would be lands on the icon")
    func target_hiddenBadge_isIcon() {
        var s = Self.settingsWithBadge()
        let point = Self.badgeCentre(s)
        s.badge.isVisible = false
        #expect(Self.target(point, s) == .iconBackground)
    }

    // MARK: - Routing with the advanced controls on

    @Test("A drop on the badge glyph lands on the badge foreground")
    func advanced_onBadgeGlyph_isBadgeForeground() {
        let s = Self.settingsWithBadge()
        #expect(Self.target(Self.badgeCentre(s), s, advanced: true) == .badgeForeground)
    }

    @Test("A drop on the badge outside its glyph lands on the badge background")
    func advanced_onBadgeRing_isBadgeBackground() {
        let s = Self.settingsWithBadge()
        let point = Self.badgeRing(s)
        #expect(PreviewHitTester.target(at: point, settings: s,
                                        displaySize: Self.displaySize) == .badgeBackground)
        #expect(Self.target(point, s, advanced: true) == .badgeBackground)
    }

    @Test("A drop on the icon glyph lands on the icon foreground")
    func advanced_onIconGlyph_isIconForeground() {
        let s = IconSettings()
        #expect(PreviewHitTester.target(at: Self.canvasCentre, settings: s,
                                        displaySize: Self.displaySize) == .iconForeground)
        #expect(Self.target(Self.canvasCentre, s, advanced: true) == .iconForeground)
    }

    @Test("A hidden icon foreground is skipped, and the drop lands on the background")
    func advanced_hiddenIconForeground_isIconBackground() {
        var s = IconSettings()
        s.icon.foreground.isHidden = true
        #expect(Self.target(Self.canvasCentre, s, advanced: true) == .iconBackground)
    }

    @Test("A drop on the canvas margin still lands on the icon background")
    func advanced_onNothing_fallsBackToIcon() {
        #expect(Self.target(.zero, Self.settingsWithBadge(), advanced: true) == .iconBackground)
    }

    @Test("Every canvas route agrees with the hit tester wherever it hits something")
    func advanced_agreesWithHitTester() {
        // The routing is not allowed a second answer to "which layer is under the
        // pointer" — a sweep across the canvas holds it to that.
        let s = Self.settingsWithBadge()
        for x in stride(from: 0, through: Self.displaySize, by: 8) {
            for y in stride(from: 0, through: Self.displaySize, by: 8) {
                let point = CGPoint(x: x, y: y)
                let hit = PreviewHitTester.target(at: point, settings: s, displaySize: Self.displaySize)
                #expect(Self.target(point, s, advanced: true) == (hit ?? .iconBackground))
            }
        }
    }

    // MARK: - Sidebar rows

    private static func rowTarget(_ row: LayerSidebarRow, _ settings: IconSettings,
                                  advanced: Bool = true) -> PreviewHitTarget? {
        PreviewDrop.target(for: row, settings: settings, advancedControlsEnabled: advanced)
    }

    @Test("A layer row takes the drop onto its own layer",
          arguments: [
            (LayerSidebarRow.layer(.icon, .foreground), PreviewHitTarget.iconForeground),
            (.layer(.icon, .background), .iconBackground),
            (.layer(.badge, .foreground), .badgeForeground),
            (.layer(.badge, .background), .badgeBackground),
          ])
    func row_layer_isThatLayer(_ row: LayerSidebarRow, _ expected: PreviewHitTarget) {
        #expect(Self.rowTarget(row, Self.settingsWithBadge()) == expected)
    }

    @Test("A group row takes the drop onto the group's background")
    func row_group_isBackground() {
        let s = Self.settingsWithBadge()
        #expect(Self.rowTarget(.group(.icon), s) == .iconBackground)
        #expect(Self.rowTarget(.group(.badge), s) == .badgeBackground)
    }

    @Test("The badge's Layout row takes the drop onto the badge background")
    func row_layout_isBadgeBackground() {
        #expect(Self.rowTarget(.layer(.badge, .layout), Self.settingsWithBadge()) == .badgeBackground)
    }

    @Test("In simple mode a row only ever reaches a background")
    func row_simpleMode_isBackground() {
        // Layer rows are not shown in simple mode, but the rule must not depend on
        // that: a foreground route would replace a layer the simple pane hides.
        let s = Self.settingsWithBadge()
        #expect(Self.rowTarget(.layer(.icon, .foreground), s, advanced: false) == .iconBackground)
        #expect(Self.rowTarget(.layer(.badge, .foreground), s, advanced: false) == .badgeBackground)
    }

    @Test("A row whose layer is hidden refuses the drop")
    func row_hiddenLayer_refuses() {
        var s = Self.settingsWithBadge()
        s.icon.foreground.isHidden = true
        s.badge.background.isHidden = true
        #expect(Self.rowTarget(.layer(.icon, .foreground), s) == nil)
        #expect(Self.rowTarget(.layer(.badge, .background), s) == nil)
        #expect(Self.rowTarget(.group(.badge), s) == nil)
        // The other layers are unaffected.
        #expect(Self.rowTarget(.layer(.icon, .background), s) == .iconBackground)
        #expect(Self.rowTarget(.layer(.badge, .foreground), s) == .badgeForeground)
    }

    @Test("A hidden badge refuses a drop on any of its rows")
    func row_hiddenBadge_refuses() {
        let s = IconSettings()  // the badge starts hidden
        #expect(Self.rowTarget(.group(.badge), s) == nil)
        #expect(Self.rowTarget(.layer(.badge, .foreground), s) == nil)
        #expect(Self.rowTarget(.layer(.badge, .layout), s) == nil)
    }

    @Test("A System-mode icon refuses the drop, as its canvas does")
    func row_systemIcon_refuses() {
        var s = IconSettings()
        s.icon.mode = .system
        #expect(Self.rowTarget(.group(.icon), s) == nil)
    }

    @Test("A System-mode badge takes the drop onto its background, as the canvas does")
    func row_systemBadge_isBackground() {
        var s = Self.settingsWithBadge()
        s.badge.foreground.source = .system
        #expect(Self.target(Self.badgeCentre(s), s, advanced: true) == .badgeBackground)
        #expect(Self.rowTarget(.group(.badge), s) == .badgeBackground)
    }

    // MARK: - The outline during a drag

    @Test("A drag outlines the layer it would land on")
    func outline_namesTheTargetLayer() {
        let s = Self.settingsWithBadge()
        #expect(PreviewDrop.outline(for: .iconForeground, settings: s, advancedControlsEnabled: true) == .iconForeground)
        #expect(PreviewDrop.outline(for: .badgeBackground, settings: s, advancedControlsEnabled: true) == .badgeBackground)
    }

    @Test("In simple mode a drag outlines nothing")
    func outline_simpleMode_isNil() {
        let s = Self.settingsWithBadge()
        #expect(PreviewDrop.outline(for: .iconBackground, settings: s, advancedControlsEnabled: false) == nil)
    }

    @Test("A drag over a System-mode badge outlines the badge as a whole")
    func outline_systemBadge_isWholeBadge() {
        var s = Self.settingsWithBadge()
        s.badge.foreground.source = .system
        #expect(PreviewDrop.outline(for: .badgeBackground, settings: s, advancedControlsEnabled: true) == .badge)
    }

    // MARK: - Applying

    @Test("Routing to the badge imports as the badge background")
    func apply_toBadge_setsBadgeBackground() throws {
        var s = Self.settingsWithBadge()
        let image = try ImportedImage.testFixture(sourceName: "Dropped.png")

        PreviewDrop.apply(image, to: .badgeBackground, in: &s)

        #expect(s.badge.background.source == .image)
        #expect(s.badge.background.image?.sourceName == "Dropped.png")
        // The import default reaches the *other* layer, which is the whole reason
        // this routes through `applyBackgroundImage` rather than writing the spec.
        #expect(s.badge.foreground.isHidden)
        // …and the icon is untouched, which is the bug B4 fixes: every drop used
        // to land here whatever it was aimed at.
        #expect(s.icon.background.source != .image)
    }

    @Test("Routing to the icon imports as the icon background")
    func apply_toIcon_setsIconBackground() throws {
        var s = Self.settingsWithBadge()
        let image = try ImportedImage.iconFixture()

        PreviewDrop.apply(image, to: .iconBackground, in: &s)

        #expect(s.icon.background.source == .image)
        #expect(s.icon.background.image?.id == image.id)
        #expect(s.icon.foreground.isHidden)
        #expect(s.icon.background.cornerRadiusStyle == .off)
        #expect(s.badge.background.source != .image)
    }

    @Test("The import defaults are the caller's, not this type's")
    func apply_honoursSuppliedDefaults() throws {
        var s = Self.settingsWithBadge()
        let keepEverything = ImportDefaults(hidesForeground: false, turnsOffCornerRadius: false)

        PreviewDrop.apply(try ImportedImage.testFixture(), to: .iconBackground,
                          in: &s, defaults: keepEverything)

        #expect(!s.icon.foreground.isHidden)
        #expect(s.icon.background.cornerRadiusStyle != .off)
    }

    @Test("Routing to a foreground imports as that foreground and touches nothing else")
    func apply_toForeground_setsForeground() throws {
        var s = Self.settingsWithBadge()
        let image = try ImportedImage.testFixture(sourceName: "Glyph.png")

        PreviewDrop.apply(image, to: .badgeForeground, in: &s)

        #expect(s.badge.foreground.source == .image)
        #expect(s.badge.foreground.image?.sourceName == "Glyph.png")
        // A foreground import makes none of a background import's guesses.
        #expect(s.badge.background.source != .image)
        #expect(!s.badge.foreground.isHidden)
        #expect(s.icon.foreground.source != .image)
    }
}

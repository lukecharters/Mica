// PreviewDropTests.swift
//
// Item B4: what a canvas drop accepts, and which layer it lands on.
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

    private static func target(_ point: CGPoint, _ settings: IconSettings) -> PreviewHitTarget {
        PreviewDrop.target(at: point, settings: settings, displaySize: displaySize)
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

    @Test("A drop on the badge glyph still lands on the badge background")
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
        let image = try ImportedImage.testFixture(sourceName: "Dropped.png")

        PreviewDrop.apply(image, to: .iconBackground, in: &s)

        #expect(s.icon.background.source == .image)
        #expect(s.icon.background.image?.sourceName == "Dropped.png")
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
}

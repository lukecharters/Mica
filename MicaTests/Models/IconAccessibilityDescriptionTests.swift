// IconAccessibilityDescriptionTests.swift
//
// What VoiceOver is told about the canvas. C1 of `docs/plans/mac-conventions.md`.
//
// The assertions are on *content* rather than on exact sentences wherever the
// wording is not itself the point — a description that has to be re-approved
// word by word stops being edited, and the thing worth protecting is that each
// state is mentioned at all. The exceptions are marked.
import AppKit
import Testing
@testable import Mica

@Suite("Icon accessibility description")
struct IconAccessibilityDescriptionTests {

    // MARK: - The default icon

    @Test("The default icon names its background colour and its symbol")
    func defaultIconIsDescribed() {
        let value = IconAccessibilityDescription.value(for: IconSettings())
        #expect(value.contains("blue"))
        #expect(value.contains("command"))
        #expect(value.contains("white"))
    }

    @Test("An icon with no badge says so, rather than staying silent")
    func noBadgeIsStated() {
        #expect(IconAccessibilityDescription.value(for: IconSettings()).contains("No badge"))
    }

    // MARK: - Hidden things are said to be hidden

    /// The state a VoiceOver user most needs told, and the one a description
    /// built by listing what is drawn would omit entirely.
    @Test("A hidden icon group is announced as hidden")
    func hiddenIconIsAnnounced() {
        var settings = IconSettings()
        settings.icon.isHidden = true
        #expect(IconAccessibilityDescription.value(for: settings).contains("Icon hidden"))
    }

    @Test("A hidden background is announced, and the symbol still is")
    func hiddenBackgroundIsAnnounced() {
        var settings = IconSettings()
        settings.icon.background.isHidden = true
        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("No background"))
        #expect(value.contains("command"))
    }

    @Test("A hidden foreground leaves the background described on its own")
    func hiddenForegroundLeavesTheBackground() {
        var settings = IconSettings()
        settings.icon.foreground.isHidden = true
        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("blue"))
        #expect(!value.contains("command"))
    }

    // MARK: - The badge

    @Test("A visible badge names its corner and its symbol")
    func visibleBadgeIsDescribed() {
        var settings = IconSettings()
        settings.badge.foreground.isHidden = false
        settings.badge.foreground.symbolName = "plus.circle"
        settings.badge.position = .topLeft

        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("top left"))
        #expect(value.contains("plus circle"))
    }

    /// An imported badge background hides the foreground as a default, so this is
    /// the state a drop onto the badge leaves behind — not an edge case.
    @Test("A badge visible only through its background is still announced")
    func badgeWithHiddenForegroundIsStillAnnounced() {
        var settings = IconSettings()
        settings.badge.background.isHidden = false
        #expect(settings.badge.foreground.isHidden)

        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("Badge at bottom right"))
        #expect(!value.contains("No badge"))
    }

    // MARK: - Symbol names

    /// A speech synthesiser runs "star.circle.fill" together as one word. The
    /// dots become spaces so the components are read.
    @Test("Dotted symbol names are spaced out so they can be spoken")
    func symbolNamesAreSpacedForSpeech() {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "star.circle.fill"
        #expect(IconAccessibilityDescription.value(for: settings).contains("star circle fill"))
    }

    @Test("An empty symbol name does not produce a gap in the sentence")
    func emptySymbolNameIsNamed() {
        var settings = IconSettings()
        settings.icon.foreground.symbolName = "   "
        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("unnamed"))
        #expect(!value.contains("the  symbol"))
    }

    // MARK: - Colours

    /// `MicaColorValue` records where a colour came from, and this reads that
    /// rather than matching values — the distinction CLAUDE.md keeps under
    /// *A stored colour carries its provenance*. A custom pick has no name to
    /// speak, and reading four decimals of extended sRGB aloud describes nothing.
    @Test("A custom colour is described as custom, not as four decimals")
    func customColorIsDescribedAsCustom() throws {
        var settings = IconSettings()
        settings.icon.background.usesGradient = false
        settings.icon.background.color = try MicaColorValue(strictlyParsing: "#123456")

        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("a custom color"))
        #expect(!value.contains("0.0"))
    }

    @Test("A token colour is spoken by its display name")
    func tokenColorUsesItsDisplayName() {
        var settings = IconSettings()
        settings.icon.background.usesGradient = false
        settings.icon.background.color = .mint
        #expect(IconAccessibilityDescription.value(for: settings).contains("mint"))
    }

    @Test("A custom gradient names both of its colours")
    func customGradientNamesBothColors() {
        var settings = IconSettings()
        settings.icon.background.usesCustomGradient = true
        settings.icon.background.gradientStartColor = .red
        settings.icon.background.gradientEndColor = .yellow

        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("red"))
        #expect(value.contains("yellow"))
    }

    /// Each rendering style reads a *different* colour property. Naming the
    /// monochrome one under a palette would describe a colour the render never
    /// uses — the same trap the configuration format's rendering-style gate
    /// exists for.
    @Test("Each rendering style is described by the colour it actually renders")
    func renderingStyleDecidesWhichColorIsNamed() {
        var settings = IconSettings()
        settings.icon.foreground.color = .white
        settings.icon.foreground.hierarchicalColor = .orange
        settings.icon.foreground.palettePrimaryColor = .pink

        settings.icon.foreground.renderingStyle = .monochrome
        var value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("white"))
        #expect(!value.contains("orange"))

        settings.icon.foreground.renderingStyle = .hierarchical
        value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("orange"))

        settings.icon.foreground.renderingStyle = .palette
        value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("pink"))
        #expect(value.contains("palette"))

        settings.icon.foreground.renderingStyle = .multicolor
        value = IconAccessibilityDescription.value(for: settings)
        #expect(!value.contains("white"))
        #expect(!value.contains("orange"))
    }

    // MARK: - Imported artwork

    @Test("An imported background is named by its file")
    func importedBackgroundIsNamedByItsFile() throws {
        var settings = IconSettings()
        settings.icon.background.source = .image
        settings.icon.background.image = try .testFixture(sourceName: "artwork.png")
        #expect(IconAccessibilityDescription.value(for: settings).contains("artwork.png"))
    }

    /// A pasted image has no filename, and inventing one would be a lie. The
    /// sentence has to survive its absence without a dangling comma.
    @Test("An import with no name is still described")
    func unnamedImportIsStillDescribed() throws {
        var settings = IconSettings()
        settings.icon.background.source = .image
        settings.icon.background.image = try .testFixture(sourceName: "")

        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("An imported background"))
        #expect(!value.contains(", named"))
        #expect(!value.contains(",."))
    }

    // MARK: - System mode

    /// The appex pipeline's two colours live on the view model, not in
    /// `IconSettings`, so the description names the symbol and stops rather than
    /// reading colours that pipeline never uses.
    @Test("A System-mode icon is described as system-rendered")
    func systemModeIsDescribedAsSuch() {
        var settings = IconSettings()
        settings.icon.mode = .system
        settings.icon.foreground.symbolName = "folder.fill"

        let value = IconAccessibilityDescription.value(for: settings)
        #expect(value.contains("System-rendered"))
        #expect(value.contains("folder fill"))
    }

    // MARK: - The badge drag handle

    @Test("The handle reports its corner, and no offset when there is none")
    func handleReportsItsCorner() {
        var settings = IconSettings()
        settings.badge.position = .bottomLeft
        #expect(IconAccessibilityDescription.badgeHandleValue(for: settings) == "bottom left")
    }

    /// Exact wording, because this one is a sentence a person hears rather than a
    /// fragment: the numbers and their units are the content.
    @Test("The handle reports a manual offset in the sliders' percent units")
    func handleReportsItsOffset() {
        var settings = IconSettings()
        settings.badge.position = .topRight
        settings.badge.offsetX = -0.12
        settings.badge.offsetY = 0.05

        #expect(
            IconAccessibilityDescription.badgeHandleValue(for: settings)
                == "top right, offset -12% horizontally and 5% vertically"
        )
    }

    /// `Int(0.29 * 100)` is 28 — the product is 28.999999999999996. The sliders
    /// step by 0.01, which is exactly the size of value that lands on the wrong
    /// side of a truncation, and both readouts round for this reason.
    @Test("The percent readout rounds rather than truncating")
    func percentRoundsRatherThanTruncating() {
        var settings = IconSettings()
        settings.badge.offsetX = 0.29
        #expect(IconAccessibilityDescription.badgeHandleValue(for: settings).contains("29%"))
        #expect(!IconAccessibilityDescription.badgeHandleValue(for: settings).contains("28%"))
    }

    /// The hint is the only place the arrow keys are named — nothing on screen
    /// says so, the handle being invisible.
    @Test("The handle's hint names the arrow keys")
    func handleHintNamesTheArrowKeys() {
        #expect(IconAccessibilityDescription.badgeHandleHint.lowercased().contains("arrow"))
    }

    // MARK: - Shape

    /// Not cosmetic: VoiceOver runs sentences together without terminators, and
    /// a value that reads "…in white No badge" is one sentence describing
    /// something that does not exist.
    @Test("Every state produces terminated, non-empty sentences")
    func everyStateProducesASentence() {
        var cases: [IconSettings] = [IconSettings()]

        var hidden = IconSettings(); hidden.icon.isHidden = true
        var system = IconSettings(); system.icon.mode = .system
        var badged = IconSettings(); badged.badge.foreground.isHidden = false
        var bare = IconSettings()
        bare.icon.background.isHidden = true
        bare.icon.foreground.isHidden = true
        cases.append(contentsOf: [hidden, system, badged, bare])

        for settings in cases {
            let value = IconAccessibilityDescription.value(for: settings)
            #expect(value.hasSuffix("."))
            #expect(!value.contains(".."))
            #expect(!value.isEmpty)
        }
    }
}

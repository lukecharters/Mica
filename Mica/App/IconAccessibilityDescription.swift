// App/IconAccessibilityDescription.swift
//
// What VoiceOver is told about the preview canvas — the app's central object,
// which had no label, no value and no custom actions until item C1 of
// `docs/plans/mac-conventions.md`. A sighted user reads the icon; a VoiceOver
// user was told nothing whatever had been generated.
//
// Pure functions over `IconSettings` rather than anything a view holds, for two
// reasons. The obvious one is that a string built from a struct is testable and
// a modifier applied inside a `body` is not. The less obvious one is that both
// previews need the same sentence: `ScaledIconPreview` in Mica mode and
// `AppexPreviewPane` in System mode draw the same icon by different pipelines,
// and describing it twice is how the two descriptions drift.
//
// It lives in `App/` because the CLI has no canvas to describe — see the table
// in CLAUDE.md ▸ *Adding a file: which list does it join?*, which is what keeps
// it out of the two `membershipExceptions` lists.
import Foundation

/// Spoken descriptions of the rendered icon and of the badge's drag handle.
///
/// Every string here is an accessibility *label*, *value* or *hint* — never a
/// tooltip. C1's rule is that a `.help()` may accompany one of these and must
/// never stand in for it, because VoiceOver reads a tooltip only in some
/// contexts and a control described that way looks described until it isn't.
enum IconAccessibilityDescription {

    // MARK: - The canvas

    /// The preview's accessibility label. Constant — what *changes* is the value.
    static let previewLabel = "Icon preview"

    /// A sentence describing what has been generated: the icon, then the badge.
    ///
    /// Written to be heard rather than read, so it names the things a user chose
    /// (a colour, a symbol, a corner) and not the things Mica derived from them
    /// (a corner-radius style, a shadow preset, a rendering mode's internals).
    /// Anything hidden is said to be hidden rather than silently dropped, since
    /// "there is nothing there" is exactly the state a VoiceOver user cannot see.
    static func value(for settings: IconSettings) -> String {
        [iconPhrase(for: settings), badgePhrase(for: settings)]
            .map { $0 + "." }
            .joined(separator: " ")
    }

    // MARK: - The badge drag handle

    /// The badge drag handle's label. The handle is a `Circle().fill(.clear)` with
    /// a `DragGesture`, so without this it is not an accessibility element at all —
    /// the review's second finding under *Accessibility*.
    static let badgeHandleLabel = "Badge position"

    /// Where the badge currently sits: its anchor corner, plus any manual offset.
    ///
    /// The offset is reported in the same percent units the inspector's two
    /// sliders show, so what VoiceOver says and what the sliders read cannot
    /// disagree. Interpolated into a `String` rather than a `Text`, which would
    /// group the digits — see CLAUDE.md ▸ `Text("\(anInt)")` *is a
    /// `LocalizedStringKey`*.
    static func badgeHandleValue(for settings: IconSettings) -> String {
        let corner = settings.badge.position.rawValue.lowercased()
        let x = percent(settings.badge.offsetX)
        let y = percent(settings.badge.offsetY)
        guard x != 0 || y != 0 else { return corner }
        return "\(corner), offset \(x)% horizontally and \(y)% vertically"
    }

    /// How to move it without a mouse. Names the arrow keys because nothing on
    /// screen does: the handle is invisible and the drag is the only affordance.
    static let badgeHandleHint = "Use the arrow keys to move the badge."

    // MARK: - The icon

    private static func iconPhrase(for settings: IconSettings) -> String {
        guard !settings.icon.isHidden else { return "Icon hidden" }

        guard settings.icon.mode == .mica else {
            // The appex pipeline renders symbol and enclosure as one image, and
            // its two colours live on the view model rather than in `IconSettings`
            // — so the honest description names the symbol and stops.
            return "System-rendered icon of the \(spoken(symbol: settings.icon.foreground.symbolName)) symbol"
        }

        let background = iconBackgroundPhrase(for: settings)
        guard let foreground = foregroundPhrase(for: settings.icon.foreground) else {
            return background
        }
        return "\(background), showing \(foreground)"
    }

    private static func iconBackgroundPhrase(for settings: IconSettings) -> String {
        let background = settings.icon.background
        guard !background.isHidden else { return "No background" }

        switch background.source {
        case .color:
            if background.usesCustomGradient {
                return "A \(name(background.gradientStartColor)) to "
                    + "\(name(background.gradientEndColor)) gradient background"
            }
            return background.usesGradient
                ? "A \(name(background.color)) gradient background"
                : "A \(name(background.color)) background"
        case .preRendered:
            return "A pre-rendered \(background.preRenderedColorName.lowercased()) background"
        case .image:
            return "An imported background\(sourceSuffix(background.image))"
        }
    }

    // MARK: - The badge

    private static func badgePhrase(for settings: IconSettings) -> String {
        guard settings.badge.isVisible else { return "No badge" }

        let corner = settings.badge.position.rawValue.lowercased()
        guard let foreground = foregroundPhrase(for: settings.badge.foreground) else {
            // Reachable: an imported or coloured badge background with its
            // foreground hidden is what an image import leaves behind.
            return "Badge at \(corner)"
        }
        return "Badge at \(corner) showing \(foreground)"
    }

    // MARK: - Shared between the two groups

    /// `ForegroundSpec` is shared by the icon and the badge, so this is too —
    /// which is the point of that sharing. Returns nil when the layer draws
    /// nothing, leaving the caller to decide how a bare background reads.
    private static func foregroundPhrase(for foreground: ForegroundSpec) -> String? {
        guard !foreground.isHidden else { return nil }

        switch foreground.source {
        case .symbol:
            return "the \(spoken(symbol: foreground.symbolName)) symbol \(symbolColorPhrase(for: foreground))"
        case .image:
            return "an imported image\(sourceSuffix(foreground.image))"
        case .system:
            return "the system \(spoken(symbol: foreground.symbolName)) symbol"
        }
    }

    /// How the symbol is coloured, in the terms the inspector offers.
    ///
    /// Each rendering style reads a *different* colour property, so naming the
    /// wrong one would describe a colour the render never uses — the same trap
    /// the configuration format's rendering-style gate exists for.
    private static func symbolColorPhrase(for foreground: ForegroundSpec) -> String {
        switch foreground.renderingStyle {
        case .monochrome:
            return "in \(name(foreground.color))"
        case .hierarchical:
            return "in hierarchical \(name(foreground.hierarchicalColor))"
        case .palette:
            return "in a \(name(foreground.palettePrimaryColor)), "
                + "\(name(foreground.paletteSecondaryColor)) and "
                + "\(name(foreground.paletteTertiaryColor)) palette"
        case .multicolor:
            return "in its own colors"
        }
    }

    // MARK: - Wording helpers

    /// A colour's spoken name.
    ///
    /// A token gets `ColorTokenTable`'s derived display name, lowercased to sit
    /// inside a sentence; anything else is "a custom colour", because a
    /// components source is a point in extended sRGB and reading four decimals
    /// aloud describes nothing. This is exactly the difference `MicaColorValue`
    /// records — see CLAUDE.md ▸ *A stored colour carries its provenance* — so it
    /// is read here rather than guessed at by matching values.
    private static func name(_ value: MicaColorValue) -> String {
        guard let token = value.tokenName,
              let display = ColorTokenTable.token(named: token)?.displayName else {
            return "a custom color"
        }
        return display.lowercased()
    }

    /// SF Symbol names are dot-separated identifiers, and a speech synthesiser
    /// runs them together — "star.circle.fill" comes out as one word. Spaces let
    /// it read the components.
    private static func spoken(symbol name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "unnamed" }
        return trimmed.replacingOccurrences(of: ".", with: " ")
    }

    /// ", named foo.png" when the import carries a filename, and nothing when it
    /// does not — a pasted image has no name and inventing one would be a lie.
    private static func sourceSuffix(_ image: ImportedImage?) -> String {
        guard let name = image?.sourceName, !name.isEmpty else { return "" }
        return ", named \(name)"
    }

    /// The offset in the percent units the inspector's two sliders read in.
    ///
    /// Rounded, not truncated. `Int(0.29 * 100)` is **28** — the product is
    /// 28.999999999999996 and `Int` throws the tail away — which is how a 29%
    /// offset comes to be reported as 28%. `BadgeGroupLayoutSection`'s readouts
    /// had that bug and were fixed alongside this, so the spoken value and the
    /// slider now agree by construction rather than by both being close.
    private static func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }
}

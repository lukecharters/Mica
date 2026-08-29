// Views/Controls/ColorPickerWithDropdown.swift
import SwiftUI

/// A preset dropdown that names the colour, with a colour well beside it for a
/// custom one.
///
/// **Which control shows is read from the model, not guessed from the value.**
/// Until 2026-08-02 the flag was view-local `@State` that reset to `false`
/// whenever the section was recreated — a selection change through `.id`, a tab
/// switch, a mode switch — so `onAppear` re-derived it by asking "does this colour
/// equal a preset?". That could not tell *the* system blue from a picked blue that
/// happened to match, and it showed a preset dropdown for colours no preset could
/// name. `MicaColorValue` carries provenance, so the question is now just
/// `value.tokenName`.
///
/// **The dropdown never goes away, and "Custom" is one of its values** — the shape
/// SF Symbols uses. Until 2026-08-29 a custom colour *replaced* the menu with a
/// bare `ColorPicker` plus a **Use Preset** link, so the row stopped saying what
/// the colour was, and getting back to a preset meant finding a button that
/// existed in only one of the two states. The menu now always reads the answer —
/// a token's name, or "Custom" — and the well appears next to it exactly when the
/// value is a custom one. That also retires the last view state here
/// (`forcesPresetPicker`, the transient "show me the list again"): with the list
/// always on screen there is nothing left for it to say.
extension ColorToken {
    /// `displayName` is derived from the token name so that no second list of
    /// colour names can drift out of step with `ColorTokenTable` — which means
    /// the string catalog has to be keyed on the derived string. "Gray" → "Grey"
    /// is the only entry that earns its place today.
    var localizedDisplayName: String { displayName.localizedFromCatalog }
}

struct ColorPickerWithDropdown: View {
    /// A `LocalizedStringKey` rather than a `String`, because `Text(aString)` is
    /// the *verbatim* overload and would skip the string catalog outright — which
    /// is how "Symbol Color" stayed American in every en-GB build while the
    /// literals one level up looked correctly localizable.
    let label: LocalizedStringKey
    @Binding var value: MicaColorValue
    /// The swatches offered. Defaults to the presentable tokens; System mode
    /// passes the appex-native subset instead.
    var presets: [ColorToken] = ColorTokenTable.presentable
    /// Whether the colour well offers an opacity slider.
    ///
    /// `false` for a System-mode *background*, because the OS ignores an
    /// enclosure's alpha (§1.1 of the colour-resolution plan) and
    /// `AppexPlistColor` refuses one rather than render something the user did not
    /// ask for. Hiding the slider is the same rule enforced a step earlier, where
    /// it reads as a control that was never offered rather than an error.
    var supportsOpacity: Bool = true

    /// Whether `value` names one of the offered presets. A token that is *not*
    /// offered — `primary` arriving from a configuration, say — reads as Custom and
    /// gets the well, and survives as a token for as long as the user leaves it
    /// alone.
    private var isPreset: Bool {
        guard let name = value.tokenName else { return false }
        return presets.contains { $0.name == name }
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Picker(selection: presetBinding) {
                    // Sorted here rather than taken in `ColorTokenTable`'s order,
                    // which is alphabetical by the *source* display name: "Gray"
                    // sorts before "Green" and "Grey" after it, so an en-GB build
                    // would show one token a place out of order.
                    ForEach(presets.sorted { $0.localizedDisplayName < $1.localizedDisplayName }) { token in
                        Text(verbatim: token.localizedDisplayName).tag(Optional(token.name))
                    }
                    Divider()
                    Text("Custom").tag(Optional(Self.customTag))
                } label: {
                    // Hidden rather than absent: `.labelsHidden()` still publishes
                    // the title to accessibility, so the menu reads back as the row
                    // it belongs to without a second label to double it up.
                    Text(label)
                }
                .labelsHidden()

                if !isPreset {
                    ColorPicker(selection: $value.asColor, supportsOpacity: supportsOpacity) {
                        Text("Custom")
                    }
                    .labelsHidden()
                }
            }
        } label: {
            HStack(spacing: 12) {
                swatch
                Text(label)
            }
        }
    }

    private var swatch: some View {
        Circle()
            .stroke(.secondary.opacity(0.5), lineWidth: 1.0)
            .fill(value.resolved)
            .frame(width: 12, height: 12)
    }

    /// Not a real token name, so it cannot collide with one.
    private static let customTag = "\u{0}custom"

    /// Selecting a preset writes its **token**, so the choice survives an
    /// appearance change and an OS update. Selecting "Custom" converts the value
    /// to components then and there — the user has said this is a custom colour,
    /// and leaving it a token would make the well's first edit look like a
    /// conversion that had already happened.
    ///
    /// The getter answers `customTag` rather than `nil` for a custom colour, which
    /// is what puts "Custom" in the menu's title instead of leaving it blank. The
    /// setter's no-op guard is what stops that reading back as a *choice*: without
    /// it, an unoffered token showing as Custom could be flattened to components by
    /// a re-selection the user experienced as changing nothing.
    private var presetBinding: Binding<String?> {
        Binding(
            get: { isPreset ? value.tokenName : Self.customTag },
            set: { selection in
                guard let selection, selection != (isPreset ? value.tokenName : Self.customTag)
                else { return }
                if selection == Self.customTag {
                    value = .components(ColorParser.ExtendedComponents.resolving(value.resolved))
                } else {
                    value = .token(selection)
                }
            }
        )
    }
}

#Preview("Preset") {
    @Previewable @State var value: MicaColorValue = .blue
    Form {
        ColorPickerWithDropdown(label: "Color", value: $value)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

#Preview("Custom") {
    @Previewable @State var value: MicaColorValue = .components(
        .srgb(r: 0.2, g: 0.6, b: 0.9, a: 1)
    )
    Form {
        ColorPickerWithDropdown(label: "Color", value: $value)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

#Preview("A token with no swatch") {
    @Previewable @State var value: MicaColorValue = .token("primary")
    Form {
        ColorPickerWithDropdown(label: "Color", value: $value)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

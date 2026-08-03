// Views/Controls/MicaColorValueBinding.swift
import SwiftUI

extension Binding where Value == MicaColorValue {
    /// A `Binding<Color>` for AppKit-shaped controls — `ColorPicker` and anything
    /// else that only speaks `Color`.
    ///
    /// Reading resolves; **writing always stores components, never a token.** A
    /// colour well is not one of the places provenance comes from — those are a CLI
    /// token, a JSON token and the preset dropdown — so a wheel pick is a custom
    /// colour whatever it happens to equal.
    ///
    /// It went through `MicaColorValue(resolving:)` until 2026-08-03, which matched
    /// the pick against the whole token table by value. Drag a slider onto system
    /// blue and the value became `.token("blue")`, `ColorPickerWithDropdown`'s
    /// `isPreset` flipped, and the `ColorPicker` was *replaced* by the preset menu
    /// mid-drag — leaving the shared `NSColorPanel` open with no well behind it, so
    /// the colour froze and could not be moved off that token. Pure white and pure
    /// black are a slider's end stops, so this was easy to hit by accident.
    /// `init(resolving:)` keeps that matching for its real job: giving `#0088FF`
    /// from a configuration a canonical spelling.
    ///
    /// **The equality guard is load-bearing**, and doubly so now. SwiftUI hands a
    /// colour well's binding a value back on re-render, and without the guard that
    /// write would convert a token the user never touched into frozen components —
    /// `label`, which shows in the well because no swatch names it, is the case that
    /// bites. The comparison is on components at the stored precision rather than on
    /// `Color`, because the panel can hand back the same colour in a different
    /// colour space, which `!=` reads as an edit.
    var asColor: Binding<Color> {
        Binding<Color>(
            get: { wrappedValue.resolved },
            set: { newColor in
                let picked = ColorParser.ExtendedComponents
                    .resolving(newColor)
                    .rounded(to: MicaColorValue.precision)
                let current = ColorParser.ExtendedComponents
                    .resolving(wrappedValue.resolved)
                    .rounded(to: MicaColorValue.precision)
                guard picked != current else { return }
                wrappedValue = .components(picked)
            }
        )
    }
}

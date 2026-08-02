// Views/Controls/MicaColorValueBinding.swift
import SwiftUI

extension Binding where Value == MicaColorValue {
    /// A `Binding<Color>` for AppKit-shaped controls — `ColorPicker` and anything
    /// else that only speaks `Color`.
    ///
    /// Reading resolves; writing captures with `MicaColorValue(resolving:)`, so a
    /// picked colour that happens to match a token still comes back as that token.
    ///
    /// **The equality guard is load-bearing.** SwiftUI hands a colour well's
    /// binding an equal value on re-render, and without the guard that write would
    /// convert a token the user never touched into frozen components — the exact
    /// provenance loss this type exists to prevent, arriving through a code path
    /// nobody would think to look at.
    var asColor: Binding<Color> {
        Binding<Color>(
            get: { wrappedValue.resolved },
            set: { newColor in
                guard newColor != wrappedValue.resolved else { return }
                wrappedValue = MicaColorValue(resolving: newColor)
            }
        )
    }
}

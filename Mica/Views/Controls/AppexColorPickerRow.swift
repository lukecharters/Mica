// Views/Controls/AppexColorPickerRow.swift
import SwiftUI

/// Wraps `ColorPickerWithDropdown` for the Apple Reference (`.appex`) pipeline.
/// Presents Apple's named system colours as presets plus a "Custom…" option that
/// exposes a full `ColorPicker`. The chosen value is stored as an ``AppexColor``,
/// which resolves to either a named token or an `"r,g,b,a"` plist string.
///
/// The bridge to `MicaColorValue` is exact rather than approximate: `AppexColor`'s
/// preset/custom pair *is* provenance, in a bespoke shape, so a named preset maps
/// to a token and a custom colour maps to whatever `MicaColorValue` it already
/// holds. It used to match a preset back by comparing swatch colours, which is the
/// by-value inference this pass exists to remove — and which silently discarded
/// the custom colour behind a preset.
struct AppexColorPickerRow: View {
    let label: String
    @Binding var selection: AppexColor
    /// Which plist key this row feeds. It decides whether opacity is offered at
    /// all: the OS honours a symbol's alpha and discards an enclosure's, so an
    /// opacity slider on the background would promise something that cannot
    /// happen — and `AppexPlistColor` would refuse the value it produced.
    var role: AppexPlistColor.Role = .symbol

    var body: some View {
        ColorPickerWithDropdown(
            label: label,
            value: colorValueBinding,
            presets: ColorTokenTable.appexNative,
            supportsOpacity: role.honoursAlpha
        )
    }

    private var colorValueBinding: Binding<MicaColorValue> {
        Binding(
            get: {
                selection.isCustom ? selection.customColor : .token(selection.preset.rawValue)
            },
            set: { newValue in
                // Only an appex-native token can stay a preset — the pipeline
                // accepts no other name, and anything else has to be resolved to
                // components (§4.4 of docs/plans/colour-resolution.md).
                if let name = newValue.tokenName,
                   let preset = AppexNamedColor(rawValue: name) {
                    selection.preset = preset
                    selection.isCustom = false
                } else {
                    selection.customColor = newValue
                    selection.isCustom = true
                }
            }
        )
    }
}

#Preview("Preset") {
    @Previewable @State var color: AppexColor = .blue
    Form {
        AppexColorPickerRow(label: "Symbol Color", selection: $color)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

#Preview("Custom") {
    @Previewable @State var color: AppexColor = .custom(
        .components(.srgb(r: 1, g: 0.0902, b: 0.2118, a: 1))
    )
    Form {
        AppexColorPickerRow(label: "Symbol Color", selection: $color)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

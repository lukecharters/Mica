// Views/Controls/AppexColorPickerRow.swift
import SwiftUI

/// Wraps `ColorPickerWithDropdown` for the Apple Reference (`.appex`) pipeline.
/// Presents Apple's named system colours as presets plus a "Custom…" option that
/// exposes a full `ColorPicker`. The chosen value is stored as an ``AppexColor``,
/// which resolves to either a named token or an `"r,g,b,a"` plist string.
struct AppexColorPickerRow: View {
    let label: String
    @Binding var selection: AppexColor

    /// Preset swatches, one per named appex token.
    private let presets: [(name: String, color: Color)] =
        AppexEnclosureColor.allCases.map { (name: $0.displayName, color: $0.previewColor) }

    var body: some View {
        ColorPickerWithDropdown(
            label: label,
            color: colorBinding,
            useCustom: useCustomBinding,
            colorOptions: presets
        )
    }

    /// Bridges the picker's `Color` to the `AppexColor`. In custom mode every
    /// change updates the custom colour; in preset mode a selection is matched
    /// back to its named token by swatch colour.
    private var colorBinding: Binding<Color> {
        Binding(
            get: { selection.displayColor },
            set: { newColor in
                if selection.isCustom {
                    selection.customColor = newColor
                } else if let match = AppexEnclosureColor.allCases.first(where: { $0.previewColor == newColor }) {
                    selection.preset = match
                } else {
                    selection.customColor = newColor
                }
            }
        )
    }

    /// Bridges the preset/custom toggle. Entering custom mode seeds the custom
    /// colour from the current preset so the picker opens on the visible colour.
    private var useCustomBinding: Binding<Bool> {
        Binding(
            get: { selection.isCustom },
            set: { newValue in
                if newValue && !selection.isCustom {
                    selection.customColor = selection.preset.previewColor
                }
                selection.isCustom = newValue
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
    @Previewable @State var color: AppexColor = .custom(Color(.sRGB, red: 1, green: 0.0902, blue: 0.2118, opacity: 1))
    Form {
        AppexColorPickerRow(label: "Symbol Color", selection: $color)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

// Views/Inspector/Simple/SimpleAppearanceSection.swift
import SwiftUI

/// Appearance section for the simple pane — the un-tabbed Mica-mode inspector
/// shown when "Show Advanced Controls" is off. Matches System mode's Symbol
/// Color / Background Color pair, plus the two shadows Mica renders itself.
///
/// The labels spell out which layer they belong to because both layers share one
/// section here; the advanced panes keep a plain "Shadow" inside their own tab,
/// where there is nothing to confuse it with.
///
/// Group-agnostic: the caller supplies the bindings, so the icon and badge share
/// one implementation. `backgroundShadow` is a `Bool` for both — the icon's
/// multi-style `BackgroundShadowStyle` is mapped to on/off at the call site,
/// which is what the advanced-off shadow toggle has always done.
struct SimpleAppearanceSection: View {
    @Binding var symbolColor: Color
    @Binding var symbolShadow: Bool
    @Binding var backgroundColor: Color
    @Binding var backgroundShadow: Bool
    let colorOptions: [(name: String, color: Color)]

    @State private var useCustomSymbolColor = false
    @State private var useCustomBackgroundColor = false

    var body: some View {
        ColorPickerWithDropdown(
            label: "Symbol Color",
            color: $symbolColor,
            useCustom: $useCustomSymbolColor,
            colorOptions: colorOptions
        )

        Toggle("Symbol Shadow", systemImage: "app.shadow", isOn: $symbolShadow)

        ColorPickerWithDropdown(
            label: "Background Color",
            color: $backgroundColor,
            useCustom: $useCustomBackgroundColor,
            colorOptions: colorOptions
        )

        Toggle("Background Shadow", systemImage: "app.shadow", isOn: $backgroundShadow)
    }
}

#Preview {
    @Previewable @State var symbolColor: Color = .white
    @Previewable @State var symbolShadow = true
    @Previewable @State var backgroundColor: Color = .blue
    @Previewable @State var backgroundShadow = true
    Form {
        Section("Appearance") {
            SimpleAppearanceSection(
                symbolColor: $symbolColor,
                symbolShadow: $symbolShadow,
                backgroundColor: $backgroundColor,
                backgroundShadow: $backgroundShadow,
                colorOptions: OptionsCatalog.colorOptions
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

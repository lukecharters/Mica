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
/// one implementation. Both shadows are a `Bool` here: every `DropShadowStyle` is
/// mapped to on/off at the call site, the same mapping `ShadowStyleControl` uses.
struct SimpleAppearanceSection: View {
    @Binding var symbolColor: MicaColorValue
    @Binding var symbolShadow: Bool
    @Binding var backgroundColor: MicaColorValue
    @Binding var backgroundShadow: Bool


    var body: some View {
        ColorPickerWithDropdown(
            label: "Symbol Color",
            value: $symbolColor
        )

        Toggle("Symbol Shadow", systemImage: "app.shadow", isOn: $symbolShadow)

        ColorPickerWithDropdown(
            label: "Background Color",
            value: $backgroundColor
        )

        Toggle("Background Shadow", systemImage: "app.shadow", isOn: $backgroundShadow)
    }
}

#Preview {
    @Previewable @State var symbolColor: MicaColorValue = .white
    @Previewable @State var symbolShadow = true
    @Previewable @State var backgroundColor: MicaColorValue = .blue
    @Previewable @State var backgroundShadow = true
    Form {
        Section("Appearance") {
            SimpleAppearanceSection(
                symbolColor: $symbolColor,
                symbolShadow: $symbolShadow,
                backgroundColor: $backgroundColor,
                backgroundShadow: $backgroundShadow
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

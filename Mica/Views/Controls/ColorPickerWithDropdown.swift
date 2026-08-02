// Views/Controls/ColorPickerWithDropdown.swift
import SwiftUI

/// A preset dropdown that swaps to a full colour well for a custom colour.
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
/// One piece of view state survives, and it is not provenance: `forcesPresetPicker`
/// is the transient "show me the list instead" that the **Use Preset** button sets.
/// It clears the moment the value changes, so it cannot disagree with the model for
/// longer than one interaction.
struct ColorPickerWithDropdown: View {
    let label: String
    @Binding var value: MicaColorValue
    /// The swatches offered. Defaults to the presentable tokens; System mode
    /// passes the appex-native subset instead.
    var presets: [ColorToken] = ColorTokenTable.presentable

    @State private var forcesPresetPicker = false

    /// Whether `value` names one of the offered presets. A token that is *not*
    /// offered — `label` arriving from a configuration, say — shows the well, and
    /// survives as a token for as long as the user leaves it alone.
    private var isPreset: Bool {
        guard let name = value.tokenName else { return false }
        return presets.contains { $0.name == name }
    }

    private var showsCustomPicker: Bool { !isPreset && !forcesPresetPicker }

    var body: some View {
        content
            .onChange(of: value) { _, _ in forcesPresetPicker = false }
    }

    @ViewBuilder
    private var content: some View {
        if showsCustomPicker {
            ColorPicker(selection: $value.asColor) {
                HStack(spacing: 12) {
                    swatch
                    Text(label)
                }
            }
            Button("Use Preset", systemImage: "arrow.clockwise") {
                forcesPresetPicker = true
            }
            .buttonStyle(.link)
        } else {
            Picker(
                selection: presetBinding,
                label: HStack(spacing: 12) {
                    swatch
                    Text(label)
                }
            ) {
                ForEach(presets) { token in
                    Text(token.displayName).tag(Optional(token.name))
                }
                Divider()
                Text("Custom…").tag(Optional(Self.customTag))
            }
            .pickerStyle(.menu)
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
    /// appearance change and an OS update. Selecting "Custom…" converts the value
    /// to components then and there — the user has said this is a custom colour,
    /// and leaving it a token would make the well's first edit look like a
    /// conversion that had already happened.
    private var presetBinding: Binding<String?> {
        Binding(
            get: { isPreset ? value.tokenName : nil },
            set: { selection in
                guard let selection else { return }
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
    @Previewable @State var value: MicaColorValue = .token("label")
    Form {
        ColorPickerWithDropdown(label: "Color", value: $value)
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

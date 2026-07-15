// Views/Controls/ColorPickerWithDropdown.swift
import SwiftUI

struct ColorPickerWithDropdown: View {
    let label: String
    @Binding var color: Color
    @Binding var useCustom: Bool
    let colorOptions: [(name: String, color: Color)]

    var body: some View {
        content
            .onAppear {
                // Callers keep `useCustom` as view-local @State, which resets to
                // false whenever the section view is recreated (selection change
                // via .id, tab switch, mode switch). Re-derive it from the model:
                // a color that isn't any preset must show the custom picker, not
                // an unselected preset dropdown.
                if !useCustom, !colorOptions.contains(where: { $0.color == color }) {
                    useCustom = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if useCustom {
            ColorPicker(selection: $color) {
                HStack(spacing: 12) {
                    Circle()
                        .stroke(.secondary.opacity(0.5), lineWidth: 1.0)
                        .fill(color)
                        .frame(width: 12, height: 12)

                    Text(label)
                }
            }
            Button("Use Preset", systemImage: "arrow.clockwise") {
                useCustom = false
            }
            .buttonStyle(.link)
        } else {
            let selectedColorOption = colorOptions.first { $0.color == color }
            Picker(
                selection: Binding<Int?>(
                    get: { colorOptions.firstIndex { $0.color == color } },
                    set: { newValue in
                        if let index = newValue, index >= 0 {
                            color = colorOptions[index].color
                        } else if newValue == -1 {
                            useCustom = true
                        }
                    }
                ),
                label: HStack(spacing: 12) {
                    Circle()
                        .stroke(.secondary.opacity(0.5), lineWidth: 1.0)
                        .fill(selectedColorOption?.color ?? color)
                        .frame(width: 12, height: 12)
                    Text(label)
                }
            ) {
                ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, option in
                    Text(option.name).tag(Optional(index))
                }
                Divider()
                Text("Custom…").tag(Optional(-1))
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview("Preset") {
    @Previewable @State var color: Color = .blue
    @Previewable @State var useCustom = false
    Form {
        ColorPickerWithDropdown(
            label: "Color",
            color: $color,
            useCustom: $useCustom,
            colorOptions: OptionsCatalog.colorOptions
        )
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

#Preview("Custom") {
    @Previewable @State var color: Color = .orange
    @Previewable @State var useCustom = true
    Form {
        ColorPickerWithDropdown(
            label: "Color",
            color: $color,
            useCustom: $useCustom,
            colorOptions: OptionsCatalog.colorOptions
        )
    }
    .formStyle(.grouped)
    .frame(width: 320)
}

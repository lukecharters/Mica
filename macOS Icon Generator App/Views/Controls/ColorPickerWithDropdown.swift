// Views/Controls/ColorPickerWithDropdown.swift
import SwiftUI

struct ColorPickerWithDropdown: View {
    let label: String
    @Binding var color: Color
    @Binding var useCustom: Bool
    let colorOptions: [(name: String, color: Color)]

    var body: some View {
        if useCustom {
            ColorPicker(selection: $color) {
                HStack(spacing: 12) {
                    Circle()
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

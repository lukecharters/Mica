// Views/Controls/LayoutSettingsSection.swift
import SwiftUI

struct LayoutSettingsSection: View {
    @Binding var layoutSettings: LayoutSettings

    var body: some View {
        Section(header: Text("Layout Settings")) {
            VStack(alignment: .leading) {
                Text("Icon Size: \(Int(layoutSettings.iconSize))")
                Slider(value: $layoutSettings.iconSize, in: 128...512, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Corner Radius: \(Int(layoutSettings.cornerRadius))")
                Slider(value: $layoutSettings.cornerRadius, in: 10...100, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Background Inset: \(Int(layoutSettings.backgroundInset))")
                Slider(value: $layoutSettings.backgroundInset, in: 0...50, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Symbol Size: \(Int(layoutSettings.symbolSize))")
                Slider(value: $layoutSettings.symbolSize, in: 50...200, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Symbol Frame Size: \(Int(layoutSettings.symbolFrameSize))")
                Slider(value: $layoutSettings.symbolFrameSize, in: 100...300, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Shadow Radius: \(layoutSettings.shadowRadius, specifier: "%.1f")")
                Slider(value: $layoutSettings.shadowRadius, in: 0...10, step: 0.1)
            }

            VStack(alignment: .leading) {
                Text("Shadow Offset: \(layoutSettings.shadowOffset, specifier: "%.1f")")
                Slider(value: $layoutSettings.shadowOffset, in: 0...10, step: 0.1)
            }

            VStack(alignment: .leading) {
                Text("Vertical Alignment Offset: \(layoutSettings.verticalAlignmentOffset, specifier: "%.1f")")
                Slider(value: $layoutSettings.verticalAlignmentOffset, in: -10...10, step: 0.1)
            }

            Picker("Symbol Weight", selection: $layoutSettings.symbolWeight) {
                Text("Ultra Light").tag(Font.Weight.ultraLight)
                Text("Thin").tag(Font.Weight.thin)
                Text("Light").tag(Font.Weight.light)
                Text("Regular").tag(Font.Weight.regular)
                Text("Medium").tag(Font.Weight.medium)
                Text("Semibold").tag(Font.Weight.semibold)
                Text("Bold").tag(Font.Weight.bold)
                Text("Heavy").tag(Font.Weight.heavy)
                Text("Black").tag(Font.Weight.black)
            }
        }
    }
}

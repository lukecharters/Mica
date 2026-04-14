// Views/Sidebar/IconLayoutSection.swift
import SwiftUI

struct IconLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        HStack {
            Text("Scale")
            Spacer()
            Text("\(Int(iconSettings.manualSymbolScale * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(value: $iconSettings.manualSymbolScale,
               in: IconSettings.manualSymbolScaleRange,
               step: 0.05)
    }
}

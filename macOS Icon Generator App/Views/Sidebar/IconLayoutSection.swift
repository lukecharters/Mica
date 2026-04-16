// Views/Sidebar/IconLayoutSection.swift
import SwiftUI

struct IconLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        switch iconSettings.iconSource {
        case .sfSymbol:
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

        case .customImage:
            ImageImportLayoutControls(
                paddingCompensation: .constant(false),
                imageScale: $iconSettings.importedImageScale,
                showPaddingCompensation: false
            )

        case .appleReference:
            EmptyView() // Layout hidden in Apple Ref mode by SidebarView
        }
    }
}

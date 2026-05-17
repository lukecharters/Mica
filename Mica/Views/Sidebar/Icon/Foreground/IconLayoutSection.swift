// Views/Sidebar/IconLayoutSection.swift
import SwiftUI

struct IconLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        switch iconSettings.iconSource {
        case .sfSymbol:
            HStack {

                //                Spacer()
                
            
            Slider(value: $iconSettings.manualSymbolScale,
                   in: IconSettings.manualSymbolScaleRange,
                   step: 0.05) {
                Text("Scale")
                Text("\(Int(iconSettings.manualSymbolScale * 100))%")
                    .foregroundStyle(.secondary)
                //                .monospacedDigit()
            }
            }
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

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Layout") {
            IconLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

// Views/Controls/ExportOptionsSection.swift
import SwiftUI

struct ExportOptionsSection: View {
    @Binding var iconSettings: IconSettings
    @Binding var showExportDialog: Bool
    let sizeOptions: [(label: String, size: CGFloat)]

    var body: some View {
        Section(header: Text("Export Options")) {
            Picker("Size", selection: Binding(
                get: { sizeOptions.firstIndex { $0.size == iconSettings.exportSize } ?? 1 },
                set: { newValue in iconSettings.exportSize = sizeOptions[newValue].size }
            )) {
                ForEach(0..<sizeOptions.count, id: \.self) { index in
                    Text(sizeOptions[index].label)
                }
            }

            Toggle("2× Resolution for Retina", isOn: $iconSettings.exportRetinaSize)

            Picker("Color Space", selection: $iconSettings.exportColorSpace) {
                ForEach(ExportColorSpace.allCases) { colorSpace in
                    Text(colorSpace.rawValue).tag(colorSpace)
                }
            }
            .help("sRGB: Standard color space for web and most displays\nDisplay P3: Wider color gamut for modern Apple displays")

            Button("Export Icon...") { showExportDialog = true }
                .padding(.top, 5)
        }
    }
}

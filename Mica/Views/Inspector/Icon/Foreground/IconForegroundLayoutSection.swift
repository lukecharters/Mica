// Views/Inspector/Icon/Foreground/IconForegroundLayoutSection.swift
import SwiftUI

struct IconForegroundLayoutSection: View {
    @Binding var iconSettings: IconSettings
    /// So a drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit

    var body: some View {
        switch iconSettings.icon.foreground.source {
        case .symbol:
            HStack {

                //                Spacer()
                
            
            Slider(value: $iconSettings.icon.foreground.symbolScale,
                   in: ForegroundSpec.symbolScaleRange,
                   step: 0.05) {
                Text("Symbol Scale")
                Text(verbatim: "\(Int((iconSettings.icon.foreground.symbolScale * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                //                .monospacedDigit()
            } onEditingChanged: { continuousEdit.sliderEditing($0) }
            .help("The symbol\u{2019}s size within the icon. Mica picks a per-symbol default from its calibration data; this scales that.")
            }
        case .image:
            ImageImportLayoutControls(
                paddingCompensation: .constant(false),
                imageScale: $iconSettings.icon.foreground.imageScale,
                showPaddingCompensation: false
            )

        case .system:
            EmptyView() // Layout hidden in Apple Ref mode by SidebarView
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Layout") {
            IconForegroundLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

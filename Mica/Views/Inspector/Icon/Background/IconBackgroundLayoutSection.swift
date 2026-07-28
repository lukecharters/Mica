// Views/Inspector/Icon/Background/IconBackgroundLayoutSection.swift
import SwiftUI

struct IconBackgroundLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        switch iconSettings.icon.background.source {
        case .color:
            EmptyView()

            
        case .image:
            ImageImportLayoutControls(
                paddingCompensation: $iconSettings.icon.background.compensatesForPadding,
                imageScale: $iconSettings.icon.background.imageScale
            )

        case .preRendered:
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var settings: IconSettings = {
        var s = IconSettings()
        s.icon.background.source = .image
        return s
    }()
    Form {
        Section("Layout") {
            IconBackgroundLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

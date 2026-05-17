// Views/Sidebar/BackgroundLayoutSection.swift
import SwiftUI

struct BackgroundLayoutSection: View {
    @Binding var iconSettings: IconSettings

    var body: some View {
        switch iconSettings.backgroundMode {
        case .custom:
            EmptyView()

            
        case .importedImage:
            ImageImportLayoutControls(
                paddingCompensation: $iconSettings.importedBackgroundPaddingCompensation,
                imageScale: $iconSettings.importedBackgroundScale
            )

        case .preRendered:
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var settings: IconSettings = {
        var s = IconSettings()
        s.backgroundMode = .importedImage
        return s
    }()
    Form {
        Section("Layout") {
            BackgroundLayoutSection(iconSettings: $settings)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

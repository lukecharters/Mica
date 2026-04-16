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

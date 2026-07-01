// Views/Sidebar/InspectorPanel.swift
import SwiftUI

/// Right panel: shows either the selected layer's controls or the export controls.
/// The tab is owned by the parent (ContentView) so the window toolbar can drive it.
struct InspectorPanel: View {
    @Binding var iconSettings: IconSettings
    @Binding var appexEnclosureColor: AppexColor
    @Binding var appexSymbolColor: AppexColor
    @Binding var badgeAppexEnclosureColor: AppexColor
    @Binding var badgeAppexSymbolColor: AppexColor
    @Binding var showExportDialog: Bool
    let selection: LayerSelection
    let tab: InspectorTab
    let colorOptions: [(name: String, color: Color)]
    let appexHasImage: Bool

    var body: some View {
        Group {
            switch tab {
            case .controls:
                LayerControls(
                    selection: selection,
                    iconSettings: $iconSettings,
                    appexEnclosureColor: $appexEnclosureColor,
                    appexSymbolColor: $appexSymbolColor,
                    badgeAppexEnclosureColor: $badgeAppexEnclosureColor,
                    badgeAppexSymbolColor: $badgeAppexSymbolColor,
                    colorOptions: colorOptions
                )
            case .export:
                ExportSettingsSidebar(
                    iconSettings: $iconSettings,
                    showExportDialog: $showExportDialog,
                    generationMode: iconSettings.iconGenerationMode,
                    appexHasImage: appexHasImage
                )
            }
        }
        // Fixed width so the inspector never resizes when its content changes
        // (Controls vs Export tab, or Custom vs System generation mode).
        .frame(width: 380)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Tab

enum InspectorTab: Hashable, CaseIterable, Identifiable {
    case controls
    case export

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .controls: "paintbrush"
        case .export: "square.and.arrow.up"
        }
    }

    var label: String {
        switch self {
        case .controls: "Layer Controls"
        case .export: "Export"
        }
    }
}

// Views/Inspector/InspectorPanel.swift
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
    let group: IconLayerGroup
    @Binding var iconTab: LayerTab
    @Binding var badgeTab: LayerTab
    let tab: InspectorTab
    let canExport: Bool

    var body: some View {
        // Hosted by a native `.inspector` in `ContentView`, which owns the
        // trailing column's material, width, and resize.
        Group {
            switch tab {
            case .controls:
                InspectorControls(
                    group: group,
                    iconTab: $iconTab,
                    badgeTab: $badgeTab,
                    iconSettings: $iconSettings,
                    appexEnclosureColor: $appexEnclosureColor,
                    appexSymbolColor: $appexSymbolColor,
                    badgeAppexEnclosureColor: $badgeAppexEnclosureColor,
                    badgeAppexSymbolColor: $badgeAppexSymbolColor
                )
            case .export:
                ExportSettingsSection(
                    iconSettings: $iconSettings,
                    showExportDialog: $showExportDialog,
                    generationMode: iconSettings.icon.mode,
                    canExport: canExport
                )
            }
        }
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
        case .export: "document"
        }
    }

    var label: String {
        switch self {
        case .controls: "Layer Controls"
        case .export: "Export"
        }
    }
}

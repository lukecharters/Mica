// Views/Inspector/Simple/SimpleSourceSection.swift
import SwiftUI

/// Source section for the simple pane — the un-tabbed Mica-mode inspector shown
/// when "Show Advanced Controls" is off. Matches System mode's Source pane:
/// visibility for the whole group, then the symbol that drives it.
///
/// Group-agnostic: the caller supplies the bindings, so the icon and badge share
/// one implementation.
struct SimpleSourceSection: View {
    /// Which group this pane is editing. Only the visibility toggle's spoken name
    /// needs it — the simple pane edits a group as one thing, so "Icon visible"
    /// and "Badge visible" are what VoiceOver should hear where the row itself
    /// says "Visible" either way.
    let group: IconLayerGroup
    /// Group visibility. The caller builds this from
    /// `IconSettings.setGroupVisible(_:for:)` so switching it on also clears any
    /// per-layer hidden flag the advanced controls left behind.
    @Binding var isVisible: Bool
    @Binding var symbolName: String
    var symbolHelp: String? = nil

    var body: some View {
        LayerVisibleToggle(layerName: group.label, isHidden: Binding(
            get: { !isVisible },
            set: { isVisible = !$0 }
        ))
        SymbolNameField(symbolName: $symbolName, help: symbolHelp)
    }
}

#Preview {
    @Previewable @State var visible = true
    @Previewable @State var symbol = "star.fill"
    Form {
        Section("Source") {
            SimpleSourceSection(group: .icon, isVisible: $visible, symbolName: $symbol)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

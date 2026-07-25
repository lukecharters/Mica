// Views/Controls/LayerTabPicker.swift
import SwiftUI

/// Segmented tab bar for the layers within a group — Foreground / Background for
/// the icon, plus Layout for the badge. Sits directly beneath `GroupModePicker`
/// at the top of the inspector and uses the same full-width segmented control
/// (the Pages/Keynote inspector pattern).
///
/// Only shown in Mica mode: `LayerTab.availableTabs(for:isSystem:)` is empty in
/// System mode, where the group renders as a single appex image with no
/// separately editable layers.
struct LayerTabPicker: View {
    let group: IconLayerGroup
    @Binding var selection: LayerTab

    var body: some View {
        FillingSegmentedPicker(
            segments: LayerTab.availableTabs(for: group, isSystem: false).map { ($0.label, $0) },
            selection: $selection,
            accessibilityLabel: "Layer"
        )
    }
}

#Preview("Icon") {
    @Previewable @State var tab: LayerTab = .foreground
    LayerTabPicker(group: .icon, selection: $tab)
        .frame(width: 340)
        .padding()
}

#Preview("Badge") {
    @Previewable @State var tab: LayerTab = .layout
    LayerTabPicker(group: .badge, selection: $tab)
        .frame(width: 340)
        .padding()
}

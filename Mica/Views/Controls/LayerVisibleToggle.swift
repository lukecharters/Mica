// Views/Controls/LayerVisibleToggle.swift
import SwiftUI

/// "Visible" row shown at the top of a layer's Source section. The model stores
/// *hidden* flags (`iconForegroundHidden` and friends); this inverts them so the
/// control reads positively, matching the sidebar's eye toggles which show
/// whether a layer is visible.
///
/// Per-layer visibility lives here because the sidebar only has group rows now —
/// the group eye still hides or shows a whole group at once (`iconHidden` /
/// `badgeHidden`), and these toggles reach the individual layers.
struct LayerVisibleToggle: View {
    @Binding var isHidden: Bool

    var body: some View {
        Toggle("Visible", systemImage: isHidden ? "eye.slash" : "eye", isOn: isVisible)
    }

    private var isVisible: Binding<Bool> {
        Binding(
            get: { !isHidden },
            set: { isHidden = !$0 }
        )
    }
}

#Preview {
    @Previewable @State var hidden = false
    Form {
        Section("Source") {
            LayerVisibleToggle(isHidden: $hidden)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

// Views/Controls/LayerVisibleToggle.swift
import SwiftUI

/// "Visible" row shown at the top of a layer's Source section. The model stores
/// *hidden* flags (`iconForegroundHidden` and friends); this inverts them so the
/// control reads positively, matching the sidebar's eye toggles which show
/// whether a layer is visible.
///
/// The sidebar's layer rows carry an eye over the *same* flag, so a layer has two
/// controls and no single owner. That is deliberate — the sidebar answers "what is
/// hidden?" for all four layers at once, this answers it for the layer being
/// edited — and it works only because both write through
/// `icon.foreground.isHidden` and friends rather than mirroring the state.
struct LayerVisibleToggle: View {
    /// What this toggle shows and hides — "Icon Foreground", "Badge Background",
    /// or a whole group in the simple and System panes.
    ///
    /// Required rather than defaulted, because the whole point is that six of
    /// these appear across the inspector and the row's own title is "Visible" on
    /// every one of them. VoiceOver read all six identically; review finding 8
    /// filed that against the sidebar's two eyes, and the inspector had four more.
    let layerName: String
    @Binding var isHidden: Bool

    var body: some View {
        Toggle("Visible", systemImage: isHidden ? "eye.slash" : "eye", isOn: isVisible)
            .accessibilityLabel("\(layerName) visible")
            // The tooltip says what a click will *do*, which the label cannot —
            // and it is an addition to the label, never a substitute for it. C1's
            // rule: never let a `.help()` be the only thing describing a control.
            .help(isHidden ? "Show the \(layerName.lowercased())" : "Hide the \(layerName.lowercased())")
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
            LayerVisibleToggle(layerName: "Icon Foreground", isHidden: $hidden)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

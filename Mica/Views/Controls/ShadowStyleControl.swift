// Views/Controls/ShadowStyleControl.swift
//
// The "Shadow" row for any layer with a `DropShadowStyle`: every style with advanced
// controls on, a plain on/off toggle with them off, where "on" is the layer's default style.
import SwiftUI

struct ShadowStyleControl: View {
    @Binding var style: DropShadowStyle
    let defaultStyle: DropShadowStyle

    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    var body: some View {
        if advancedControlsEnabled {
            Picker("Shadow", systemImage: "app.shadow", selection: $style) {
                ForEach(DropShadowStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
        } else {
            Toggle("Shadow", systemImage: "app.shadow", isOn: $style.isOn(defaultStyle: defaultStyle))
        }
    }
}

extension Binding where Value == DropShadowStyle {
    /// The style as on/off, the simple pane's view of it: "on" is `defaultStyle`.
    func isOn(defaultStyle: DropShadowStyle) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue != .off },
            set: { wrappedValue = $0 ? defaultStyle : .off }
        )
    }
}

#Preview {
    @Previewable @State var style: DropShadowStyle = .macOS27
    Form {
        ShadowStyleControl(style: $style, defaultStyle: .macOS27)
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

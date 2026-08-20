// Views/Controls/ExportOptionsAccessory.swift
//
// The save panel's accessory view: size, 2x and colour space, beside the
// filename they apply to.
//
// The same three controls as the inspector's Export pane and the same wording,
// deliberately — they are the same settings, and this is the second place to
// reach them rather than a second set. The difference is what a change *means*:
// here it applies to one file, and `ExportPanelOptions` explains why.
//
// **Reuse the inspector's exact literals.** `Localizable.xcstrings` is a spelling
// override list keyed on the source string, so "Color Space" resolves to
// "Colour Space" in the seven English variants and "Color Space:" would silently
// resolve to itself.
import SwiftUI

struct ExportOptionsAccessory: View {
    @ObservedObject var model: ExportPanelModel

    var body: some View {
        Form {
            Picker("Size", selection: $model.options.spec.size) {
                // `verbatim:` matters — see `ExportPanelOptions.pixelDescription`.
                ForEach(model.options.sizeChoices, id: \.self) { size in
                    Text(verbatim: "\(Int(size))pt").tag(size)
                }
            }

            Toggle("2x (Retina)", isOn: $model.options.spec.isRetina)
            Spacer()
            Picker("Color Space", selection: $model.options.spec.colorSpace) {
                ForEach(ExportColorSpace.allCases) { colorSpace in
                    Text(colorSpace.displayName).tag(colorSpace)
                }
            }

            // The pixel dimensions, interpolated as a `Text` so the prose around
            // them stays a `LocalizedStringKey` while the digits stay ungrouped.
            LabeledContent {
                Text("Exports at \(Text(verbatim: model.options.pixelDescription))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                EmptyView()
            }

            overrideFootnote
        }
        // Wide enough for the longest label the seven English variants produce
        // ("Colour Space") beside its menu. A `Form` that does not fit its frame
        // spills *leftwards* out of the accessory rather than compressing, which
        // reads as a clipped label with empty space beside it — measured at 340.
        .frame(width: 420)
        .padding(.vertical, 6)
    }

    /// Shown once the panel's settings differ from the window's.
    ///
    /// Kept in the layout at all times and faded, rather than inserted: an
    /// accessory view that grows resizes the whole save panel under the pointer,
    /// and the first click on the Size menu is exactly when that would happen.
    @ViewBuilder
    private var overrideFootnote: some View {
        let overridden = model.options.isOverridden
        LabeledContent {
            HStack(spacing: 8) {
                Text("This export only \u{2014} the window\u{2019}s settings are unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset") { model.options.reset() }
                    .buttonStyle(.link)
            }
            .opacity(overridden ? 1 : 0)
            .allowsHitTesting(overridden)
            .accessibilityHidden(!overridden)
        } label: {
            EmptyView()
        }
    }
}

#Preview("Export options accessory") {
    ExportOptionsAccessory(model: ExportPanelModel(options: ExportPanelOptions(seed: ExportSpec())))
}

#Preview("Overridden") {
    let model = ExportPanelModel(options: ExportPanelOptions(seed: ExportSpec()))
    model.options.spec.isRetina = true
    return ExportOptionsAccessory(model: model)
}

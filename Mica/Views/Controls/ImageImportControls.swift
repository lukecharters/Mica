// Views/Controls/ImageImportControls.swift — Reusable image import UI for icon and badge
import SwiftUI
import UniformTypeIdentifiers

/// Source controls for an imported image: thumbnail preview + "Choose File" picker.
/// Layout controls (padding compensation, scale) live in `ImageImportLayoutControls`.
struct ImageImportControls: View {
    @Binding var importedImage: ImportedImage?
    /// Called after a successful import. Use to react to `imported.isAppIcon`
    /// (e.g., toggle padding compensation).
    var onImport: (ImportedImage) -> Void = { _ in }

    var body: some View {
        // Thumbnail preview
        if let img = importedImage, let nsImg = img.nsImage {
            HStack {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading) {
                    Text(img.sourceName).lineLimit(1)
                    Text(img.isAppIcon ? "App Icon" : "Image")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Spacer()
                Button("Clear", systemImage: "xmark.circle") {
                    importedImage = nil
                }
                .buttonStyle(.borderless)
            }
        }

        // Import button
        Button("Choose File…") { showFilePicker() }
    }

    private func showFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.message = "Choose a file to import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try ImageImportService.importFromURL(url)
            importedImage = imported
            onImport(imported)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// Layout controls for an imported image: optional padding compensation + scale slider.
/// Source controls (thumbnail + import button) live in `ImageImportControls`.
struct ImageImportLayoutControls: View {
    @Binding var paddingCompensation: Bool
    @Binding var imageScale: Double
    var showPaddingCompensation: Bool = true

    var body: some View {
        if showPaddingCompensation {
            Toggle("Icon Padding", isOn: Binding(
                get: { !paddingCompensation },
                set: { paddingCompensation = !$0 }
            ))
            .help("Keep existing macOS icon padding and shadow. Turn off to scale up and fill the frame.")
        }

        Slider(value: $imageScale,
               in: IconSettings.importedImageScaleRange,
               step: 0.05){
            Text("Image Scale")
            Text("\(Int(imageScale * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview("Image Import") {
    @Previewable @State var imported: ImportedImage? = nil
    Form {
        Section("Source") {
            ImageImportControls(importedImage: $imported)
        }
    }
    .formStyle(.grouped)
    .frame(width: 360)
}

#Preview("Image Layout") {
    @Previewable @State var paddingCompensation = false
    @Previewable @State var imageScale = 1.0
    Form {
        Section("Layout") {
            ImageImportLayoutControls(
                paddingCompensation: $paddingCompensation,
                imageScale: $imageScale
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 360)
}

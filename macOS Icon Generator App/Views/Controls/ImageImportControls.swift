// Views/Controls/ImageImportControls.swift — Reusable image import UI for icon and badge
import SwiftUI
import UniformTypeIdentifiers

struct ImageImportControls: View {
    @Binding var importedImage: ImportedImage?
    @Binding var paddingCompensation: Bool
    @Binding var imageScale: Double
    var showPaddingCompensation: Bool = true
    var onImport: () -> Void

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

        // Padding compensation
        if showPaddingCompensation {
            Toggle("Icon Padding", isOn: Binding(
                
                get: { !paddingCompensation },
                set: { paddingCompensation = !$0 }
            ))
                .help("Keep existing macOS icon padding and shadow. Turn off to scale up and fill the chiclet.")
        }

        // Image scale slider
        HStack {
            Text("Image Scale")
            Spacer()
            Text("\(Int(imageScale * 100))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        Slider(value: $imageScale,
               in: IconSettings.importedImageScaleRange,
               step: 0.05)
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
            if imported.isAppIcon {
                paddingCompensation = true
            }
            onImport()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

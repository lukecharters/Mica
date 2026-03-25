// Views/Controls/ImageImportControls.swift — Reusable image import UI for icon and badge
import SwiftUI
import UniformTypeIdentifiers

struct ImageImportControls: View {
    @Binding var importedImage: ImportedImage?
    @Binding var paddingCompensation: Bool
    @Binding var imageScale: Double
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

        // Import buttons
        HStack {
            Button("Choose Image…") { showImagePicker() }
            Button("Choose App…") { showAppPicker() }
        }

        // Padding compensation (only for app icons)
        if importedImage?.isAppIcon == true {
            Toggle("Compensate for icon padding", isOn: $paddingCompensation)
                .help("Scale up to fill the chiclet, compensating for existing macOS icon padding and shadow")
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

    private func showImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageImportService.supportedImageTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image to import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            importedImage = try ImageImportService.importFromURL(url)
            onImport()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func showAppPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageImportService.supportedBundleTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.message = "Choose an app or extension to extract its icon"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            importedImage = try ImageImportService.importFromURL(url)
            paddingCompensation = true
            onImport()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

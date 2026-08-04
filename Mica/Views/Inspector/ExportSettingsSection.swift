// Views/Inspector/ExportSettingsSection.swift
import SwiftUI

struct ExportSettingsSection: View {
    @Binding var iconSettings: IconSettings
    @Binding var showExportDialog: Bool
    var generationMode: GenerationMode = .mica
    /// Whether an export would produce the icon the preview is showing. Decided by
    /// `IconViewModel.canExport`, which the File menu's Export as PNG… also reads —
    /// this button and that menu item must never disagree about it.
    var canExport: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Export Size Section
            InspectorSection(title: "Export Size") {
                VStack(alignment: .leading, spacing: 8) {
                    // Same list Settings ▸ Export offers, so the two pickers cannot
                    // drift into showing different sizes.
                    Picker("Size", selection: $iconSettings.export.size) {
                        ForEach(ExportPreferences.sizeChoices, id: \.self) { size in
                            // `verbatim:` matters. A plain `Text("\(Int(size))pt")`
                            // is a `LocalizedStringKey`, whose Int interpolation
                            // applies locale grouping — 1024 renders as "1,024pt".
                            Text(verbatim: "\(Int(size))pt").tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Toggle("2x (Retina)", isOn: $iconSettings.export.isRetina)
                        .font(.subheadline)

                    Text(retinaSizeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if generationMode == .system {
                        Text("Preview always renders at 512pt @2x.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
                .padding(.vertical, 8)

            // MARK: - Color Space Section
            InspectorSection(title: "Color Space") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Color Space", selection: $iconSettings.export.colorSpace) {
                        ForEach(ExportColorSpace.allCases) { colorSpace in
                            Text(colorSpace.displayName).tag(colorSpace)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Text(colorSpaceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // MARK: - Export Button
            Button(action: { showExportDialog = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            // No shortcut here. It carried Cmd-E, which only worked while this tab was
            // on screen; the equivalent lives in the File menu at Cmd-Shift-E, where
            // it works from anywhere. Adding one back would put the same action on two
            // shortcuts, one of them conditionally dead.
            .disabled(!canExport)
        }
        .padding()
    }

    private var retinaSizeDescription: String {
        let baseSize = Int(iconSettings.export.size)
        if iconSettings.export.isRetina {
            return "Exports at \(baseSize * 2)×\(baseSize * 2)px"
        } else {
            return "Exports at \(baseSize)×\(baseSize)px"
        }
    }

    private var colorSpaceDescription: String {
        switch iconSettings.export.colorSpace {
        case .sRGB:
            return "Standard color space for web and most displays."
        case .displayP3:
            return "Wider color gamut for modern Apple displays."
        }
    }
}

// MARK: - Sidebar Section Helper

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            content
        }
    }
}

#Preview("Export Sidebar") {
    @Previewable @State var settings = IconSettings()
    @Previewable @State var showExportDialog = false
    ExportSettingsSection(
        iconSettings: $settings,
        showExportDialog: $showExportDialog
    )
    .frame(height: 500)
}

#Preview("Sidebar Section") {
    InspectorSection(title: "Export Size") {
        Text("Section contents")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
//    .frame(width: 330)
}

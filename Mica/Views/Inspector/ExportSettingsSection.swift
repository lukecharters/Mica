// Views/Inspector/ExportSettingsSection.swift
import SwiftUI

struct ExportSettingsSection: View {
    @Binding var iconSettings: IconSettings
    @Binding var showExportDialog: Bool
    var generationMode: GenerationMode = .mica
    var appexHasImage: Bool = false
    var badgeAppexHasImage: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Export Size Section
            InspectorSection(title: "Export Size") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Size", selection: $iconSettings.exportSize) {
                        Text("16pt").tag(CGFloat(16))
                        Text("32pt").tag(CGFloat(32))
                        Text("64pt").tag(CGFloat(64))
                        Text("128pt").tag(CGFloat(128))
                        Text("256pt").tag(CGFloat(256))
                        Text("512pt").tag(CGFloat(512))
                        Text("1024pt").tag(CGFloat(1024))
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Toggle("2x (Retina)", isOn: $iconSettings.exportRetinaSize)
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
                    Picker("Color Space", selection: $iconSettings.exportColorSpace) {
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
            .keyboardShortcut("e", modifiers: .command)
            .disabled(waitingOnIconAppex || waitingOnBadgeAppex)
        }
        .padding()
    }

    /// System-mode layers export their appex-rendered image; block export until
    /// every active System-mode layer (icon AND badge) has one, otherwise the
    /// export would silently omit the pending layer.
    private var waitingOnIconAppex: Bool {
        generationMode == .system && !appexHasImage
    }

    private var waitingOnBadgeAppex: Bool {
        iconSettings.showBadge
            && iconSettings.badgeIconSource == .system
            && !badgeAppexHasImage
    }

    private var retinaSizeDescription: String {
        let baseSize = Int(iconSettings.exportSize)
        if iconSettings.exportRetinaSize {
            return "Exports at \(baseSize * 2)×\(baseSize * 2)px"
        } else {
            return "Exports at \(baseSize)×\(baseSize)px"
        }
    }

    private var colorSpaceDescription: String {
        switch iconSettings.exportColorSpace {
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

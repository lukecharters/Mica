// Views/Toolbar/ExportToolbarContent.swift
import SwiftUI

struct ExportToolbarContent: View {
    @Binding var iconSettings: IconSettings
    @Binding var showExportDialog: Bool

    @State private var showExportOptions = false
    @State private var sliderValue: Double = 256.0
    @State private var textFieldValue: String = "256"
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { showExportOptions.toggle() }) {
                Label("Export Options", systemImage: "slider.horizontal.3")
            }
            .popover(isPresented: $showExportOptions) {
                exportOptionsPopover
            }

            Button(action: { showExportDialog = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: .command)
        }
        .onAppear {
            sliderValue = Double(iconSettings.exportSize)
            textFieldValue = "\(Int(iconSettings.exportSize))"
        }
    }

    // MARK: - Export Options Popover

    private var exportOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Options")
                .font(.headline)

            Divider()

            // Size Control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Size", text: $textFieldValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit {
                            validateAndApplyTextInput()
                        }

                    Text("px")
                        .foregroundColor(.secondary)
                }

                if showValidationError {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .transition(.opacity)
                        .task(id: showValidationError) {
                            if showValidationError {
                                try? await Task.sleep(for: .seconds(3))
                                showValidationError = false
                            }
                        }
                }

                Slider(
                    value: $sliderValue,
                    in: Double(IconSettings.minExportSize)...Double(IconSettings.maxExportSize)
                )
                .frame(width: 200)
                .onChange(of: sliderValue) { _, newValue in
                    iconSettings.exportSize = CGFloat(newValue)
                    textFieldValue = "\(Int(newValue))"
                }
            }

            Divider()

            Toggle("2x Resolution for Retina", isOn: $iconSettings.exportRetinaSize)

            Picker("Color Space", selection: $iconSettings.exportColorSpace) {
                ForEach(ExportColorSpace.allCases) { colorSpace in
                    Text(colorSpace.rawValue).tag(colorSpace)
                }
            }
            .pickerStyle(.menu)
            .help("sRGB: Standard color space for web and most displays\nDisplay P3: Wider color gamut for modern Apple displays")
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Validation

    private func validateAndApplyTextInput() {
        guard let doubleValue = Double(textFieldValue) else {
            textFieldValue = "\(Int(sliderValue))"
            showValidationError = true
            validationMessage = "Please enter a valid number."
            return
        }

        let flooredValue = floor(doubleValue)
        let clampedValue = min(max(flooredValue, IconSettings.minExportSize), IconSettings.maxExportSize)

        var messages: [String] = []

        if flooredValue != doubleValue {
            messages.append("Only whole numbers accepted. Rounded down to \(Int(clampedValue)).")
        }

        if clampedValue != flooredValue {
            messages.append("Size must be between \(Int(IconSettings.minExportSize)) and \(Int(IconSettings.maxExportSize)). Set to \(Int(clampedValue)).")
        }

        sliderValue = clampedValue
        textFieldValue = "\(Int(clampedValue))"
        iconSettings.exportSize = CGFloat(clampedValue)

        if !messages.isEmpty {
            showValidationError = true
            validationMessage = messages.joined(separator: " ")
        } else {
            showValidationError = false
        }
    }
}

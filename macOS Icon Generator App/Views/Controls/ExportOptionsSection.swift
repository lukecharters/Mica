// Views/Controls/ExportOptionsSection.swift
import SwiftUI

struct ExportOptionsSection: View {
    @Binding var iconSettings: IconSettings
    @Binding var showExportDialog: Bool
    
    @State private var sliderValue: Double = 256.0
    @State private var textFieldValue: String = "256"
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    var body: some View {
        Section(header: Text("Export Options")) {
            // Size Slider Control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Size")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(sliderValue))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $sliderValue,
                    in: Double(IconSettings.minExportSize)...Double(IconSettings.maxExportSize),
                    step: 1.0
                ) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("\(Int(IconSettings.minExportSize))")
                } maximumValueLabel: {
                    Text("\(Int(IconSettings.maxExportSize))")
                }
                .onChange(of: sliderValue) { _, newValue in
                    iconSettings.exportSize = CGFloat(newValue)
                    textFieldValue = "\(Int(newValue))"
                }
                .onAppear {
                    sliderValue = Double(iconSettings.exportSize)
                    textFieldValue = "\(Int(iconSettings.exportSize))"
                }
                
                // Text Field for precise input
                HStack {
                    TextField("Size", text: $textFieldValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit {
                            validateAndApplyTextInput()
                        }
                    
                    Text("pixels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Validation message
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
            }

            Toggle("2× Resolution for Retina", isOn: $iconSettings.exportRetinaSize)

            Picker("Color Space", selection: $iconSettings.exportColorSpace) {
                ForEach(ExportColorSpace.allCases) { colorSpace in
                    Text(colorSpace.rawValue).tag(colorSpace)
                }
            }
            .help("sRGB: Standard color space for web and most displays\nDisplay P3: Wider color gamut for modern Apple displays")

            Button("Export Icon...") { showExportDialog = true }
                .padding(.top, 5)
        }
    }
    
    // Validation function for text field input
    private func validateAndApplyTextInput() {
        guard let doubleValue = Double(textFieldValue) else {
            // Non-numeric input
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

// Views/Sidebar/IconSourceSection.swift
import SwiftUI

struct IconSourceSection: View {
    @Binding var iconSettings: IconSettings
    @Binding var generationMode: GenerationMode

    @State private var showSymbolNameHelp = false

    /// Unified source selection that maps to both iconSource and generationMode
    private enum SourceType: String, CaseIterable, Identifiable {
        case sfSymbol = "SF Symbol"
        case imported = "Imported"
        case appleReference = "Apple Ref"
        var id: String { rawValue }
    }

    private var sourceType: Binding<SourceType> {
        Binding(
            get: {
                if generationMode == .appleReference { return .appleReference }
                switch iconSettings.iconSource {
                case .sfSymbol: return .sfSymbol
                case .customImage: return .imported
                case .appleReference: return .appleReference
                }
            },
            set: { newValue in
                switch newValue {
                case .sfSymbol:
                    generationMode = .swiftUI
                    iconSettings.iconSource = .sfSymbol
                case .imported:
                    generationMode = .swiftUI
                    iconSettings.iconSource = .customImage
                case .appleReference:
                    generationMode = .appleReference
                }
            }
        )
    }

    var body: some View {
        Picker("Source", selection: sourceType) {
            ForEach(SourceType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        switch sourceType.wrappedValue {
        case .sfSymbol:
            HStack(spacing: 8) {
                TextField("Symbol", text: $iconSettings.symbolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: { showSymbolNameHelp.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showSymbolNameHelp) {
                    Text("Enter the name of any SF Symbol. \nDownload Apple's SF Symbols app to see a list of all available symbols.")
                        .padding()
                        .multilineTextAlignment(.leading)
                }
            }

        case .imported:
            ImageImportControls(importedImage: $iconSettings.importedImage)

        case .appleReference:
            HStack(spacing: 8) {
                TextField("Symbol", text: $iconSettings.symbolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: { showSymbolNameHelp.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showSymbolNameHelp) {
                    Text("Enter the name of any SF Symbol. \nDownload Apple's SF Symbols app to see a list of all available symbols.")
                        .padding()
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

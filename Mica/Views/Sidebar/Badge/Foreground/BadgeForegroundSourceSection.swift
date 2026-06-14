// Views/Sidebar/BadgeSourceSection.swift
import SwiftUI

struct BadgeSourceSection: View {
    @Binding var iconSettings: IconSettings
    let isSystem: Bool

    @State private var showSymbolPicker = false

    /// Source selection within Custom mode (SF Symbol vs Imported image).
    private enum SourceType: String, CaseIterable, Identifiable {
        case sfSymbol = "SF Symbol"
        case imported = "Imported"
        var id: String { rawValue }
    }

    private var sourceType: Binding<SourceType> {
        Binding(
            get: {
                switch iconSettings.badgeIconSource {
                case .sfSymbol: return .sfSymbol
                case .customImage: return .imported
                case .appleReference: return .sfSymbol
                }
            },
            set: { newValue in
                switch newValue {
                case .sfSymbol:
                    iconSettings.badgeIconSource = .sfSymbol
                case .imported:
                    iconSettings.badgeIconSource = .customImage
                }
            }
        )
    }

    var body: some View {
        if isSystem {
            symbolField
        } else {
            Picker("Source", selection: sourceType) {
                ForEach(SourceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch sourceType.wrappedValue {
            case .sfSymbol:
                symbolField

            case .imported:
                ImageImportControls(importedImage: $iconSettings.badgeImportedImage)
            }
        }
    }

    /// SF Symbol name field with a button that opens the full symbol browser.
    private var symbolField: some View {
        HStack(spacing: 8) {
            TextField("Symbol", text: $iconSettings.badgeSymbolName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .help("Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)")
            Button(action: { showSymbolPicker = true }) {
                Image(systemName: "square.grid.2x2.fill")
            }
            .help("Browse SF Symbols")
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $iconSettings.badgeSymbolName)
        }
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            BadgeSourceSection(iconSettings: $settings, isSystem: false)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

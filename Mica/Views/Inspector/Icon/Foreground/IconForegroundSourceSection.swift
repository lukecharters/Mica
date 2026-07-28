// Views/Inspector/Icon/Foreground/IconForegroundSourceSection.swift
import SwiftUI

struct IconForegroundSourceSection: View {
    @Binding var iconSettings: IconSettings
    let isSystem: Bool

    /// Source selection within Custom mode (SF Symbol vs Imported image).
    private enum SourceType: String, CaseIterable, Identifiable {
        case sfSymbol = "SF Symbol"
        case imported = "Imported"
        var id: String { rawValue }
    }

    private var sourceType: Binding<SourceType> {
        Binding(
            get: {
                switch iconSettings.iconSource {
                case .sfSymbol: return .sfSymbol
                case .customImage: return .imported
                case .system: return .sfSymbol
                }
            },
            set: { newValue in
                switch newValue {
                case .sfSymbol:
                    iconSettings.iconSource = .sfSymbol
                case .imported:
                    iconSettings.iconSource = .customImage
                }
            }
        )
    }

    var body: some View {
        if isSystem {
            // System mode renders the icon as one appex image, so visibility is
            // all-or-nothing for the group rather than per layer.
            LayerVisibleToggle(isHidden: $iconSettings.iconHidden)
            symbolField
        } else {
            LayerVisibleToggle(isHidden: $iconSettings.iconForegroundHidden)

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
                ImageImportControls(
                    importedImage: $iconSettings.importedImage,
                    onImport: { iconSettings.applyImportedIconForeground($0) }
                )
            }
        }
    }

    private var symbolField: some View {
        SymbolNameField(symbolName: $iconSettings.symbolName)
    }
}

#Preview {
    @Previewable @State var settings = IconSettings()
    Form {
        Section("Source") {
            IconForegroundSourceSection(iconSettings: $settings, isSystem: false)
        }
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

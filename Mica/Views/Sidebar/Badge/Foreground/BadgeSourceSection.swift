// Views/Sidebar/BadgeSourceSection.swift
import SwiftUI

struct BadgeSourceSection: View {
    @Binding var iconSettings: IconSettings
    let isSystem: Bool

    @State private var showSymbolNameHelp = false

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
            HStack(spacing: 8) {
                TextField("Symbol", text: $iconSettings.badgeSymbolName)
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
                TextField("Symbol", text: $iconSettings.badgeSymbolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .help("Enter an SF Symbol name for the badge (e.g., 1.circle.fill, plus, checkmark)")

            case .imported:
                ImageImportControls(importedImage: $iconSettings.badgeImportedImage)
            }
        }
    }
}

// Views/Sidebar/IconBadgePicker.swift
import SwiftUI

/// Two-segment grouping for the sidebar: Icon (Symbol + Background) vs Badge (Badge Symbol + Badge Background).
enum IconOrBadge: Int, CaseIterable, Identifiable {
    case icon = 0
    case badge = 1

    var id: Int { rawValue }

    var systemImageName: String {
        switch self {
        case .icon: "checkmark.app.fill"
        case .badge: "app.badge.checkmark"
        }
    }

    var label: String {
        switch self {
        case .icon: "Icon"
        case .badge: "Badge"
        }
    }
}

/// Custom 2-segment picker matching the SF Symbols inspector style.
/// Uses an HStack of Buttons (not `.pickerStyle(.segmented)`) because macOS NSSegmentedControl
/// does not reliably fill available width — HStack + .frame(maxWidth: .infinity) does.
struct IconBadgePicker: View {
    @Binding var selection: IconOrBadge

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IconOrBadge.allCases) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = segment
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: segment.systemImageName)
                            .font(.system(size: 28))
                            .symbolRenderingMode(.monochrome)
                            .frame(width: 36, height: 28)
                        Text(segment.label)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selection == segment
                                  ? Color.accentColor.opacity(0.8)
                                  : Color.clear)
                    )
                    .foregroundStyle(selection == segment ? Color.white : .secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

#Preview {
    @Previewable @State var selection: IconOrBadge = .icon
    IconBadgePicker(selection: $selection)
        .frame(width: 300)
        .padding()
}

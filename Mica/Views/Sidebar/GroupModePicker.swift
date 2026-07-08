// Views/Sidebar/GroupModePicker.swift
import SwiftUI

/// Two-state segmented control: Custom vs System for a single group. Shown at the
/// top of a group's inspector (Icon / Badge) so the user can switch that group
/// between custom SwiftUI rendering and Apple's system reference.
///
/// Mirrors the full-width capsule-segment styling of `IconModePicker` and reuses
/// its `IconModeSegment` for the per-segment icon + label.
struct GroupModePicker: View {
    @Binding var isSystem: Bool
    
    private var selection: IconModeSegment {
        isSystem ? .system : .custom
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Generation Mode").font(.headline)
            HStack(spacing: 0) {
                ForEach(IconModeSegment.allCases) { segment in
                    Button {
//                        withAnimation() {
                            isSystem = (segment == .system)
//                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: segment.systemImageName)
                                .symbolRenderingMode(.monochrome)
                            Text(segment.label)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection == segment
                                      ? Color.accentColor
                                      : Color.primary.opacity(0.1))
                        )
                        .foregroundStyle(selection == segment ? Color.white : .primary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
//        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    @Previewable @State var isSystem = false
    GroupModePicker(isSystem: $isSystem)
        .frame(width: 340)
        .padding()
}

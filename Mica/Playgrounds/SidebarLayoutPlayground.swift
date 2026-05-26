// SidebarLayoutPlayground.swift
// Compare sidebar layout approaches for two-level hierarchy (Symbol/Background grouping)
// Access: File > Sidebar Layout Playground

import SwiftUI

// MARK: - Mock Controls (shared across all approaches)

/// Simulates the controls that would appear in each section
private struct MockSourceControls: View {
    @Binding var symbolName: String
    var body: some View {
        Picker("Source", selection: .constant(0)) {
            Text("SF Symbol").tag(0)
            Text("Imported").tag(1)
            Text("Apple Ref").tag(2)
        }
        .pickerStyle(.segmented)
        HStack {
            Text("Symbol")
            Spacer()
            TextField("Symbol name", text: $symbolName)
                .frame(width: 140)
        }
    }
}

private struct MockLayoutControls: View {
    @Binding var scale: Double
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    var body: some View {
        HStack {
            Text("Scale")
            Spacer()
            Slider(value: $scale, in: 0.1...2.0)
                .frame(width: 140)
        }
        HStack {
            Text("Offset X")
            Spacer()
            Slider(value: $offsetX, in: -50...50)
                .frame(width: 140)
        }
        HStack {
            Text("Offset Y")
            Spacer()
            Slider(value: $offsetY, in: -50...50)
                .frame(width: 140)
        }
    }
}

private struct MockAppearanceControls: View {
    @Binding var color: Color
    @Binding var weight: Int
    @Binding var shadowEnabled: Bool
    var body: some View {
        ColorPicker("Color", selection: $color)
        Picker("Weight", selection: $weight) {
            Text("Light").tag(0)
            Text("Regular").tag(1)
            Text("Bold").tag(2)
        }
        HStack {
            Text("Shadow")
            Spacer()
            Toggle("Shadow", isOn: $shadowEnabled)
                .labelsHidden()
        }
    }
}

private struct MockBgSourceControls: View {
    var body: some View {
        Picker("Type", selection: .constant(0)) {
            Text("Standard").tag(0)
            Text("Glass").tag(1)
            Text("Imported").tag(2)
        }
        .pickerStyle(.segmented)
    }
}

private struct MockBgAppearanceControls: View {
    @Binding var bgColor: Color
    @Binding var cornerRadius: Double
    var body: some View {
        ColorPicker("Color", selection: $bgColor)
        HStack {
            Text("Corner Radius")
            Spacer()
            Slider(value: $cornerRadius, in: 0...80)
                .frame(width: 140)
        }
    }
}

//// MARK: - Option A: Single Form with Styled Group Headers
//
//private struct OptionAView: View {
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//
//    @State private var symbolSourceExpanded = true
//    @State private var symbolLayoutExpanded = true
//    @State private var symbolAppearanceExpanded = true
//    @State private var bgSourceExpanded = true
//    @State private var bgLayoutExpanded = false
//    @State private var bgAppearanceExpanded = true
//
//    var body: some View {
//        Form {
//            // Group header — not a collapsible Section, just a visual divider
//            Section {
//                Label("Symbol", systemImage: "star.fill")
//                    .font(.headline)
//            }
//
//            Section("Source", isExpanded: $symbolSourceExpanded) {
//                MockSourceControls(symbolName: $symbolName)
//            }
//            Section("Layout", isExpanded: $symbolLayoutExpanded) {
//                MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//            }
//            Section("Appearance", isExpanded: $symbolAppearanceExpanded) {
//                MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//            }
//
//            // Second group header
//            Section {
//                Label("Background", systemImage: "square.fill")
//                    .font(.headline)
//            }
//
//            Section("Source", isExpanded: $bgSourceExpanded) {
//                MockBgSourceControls()
//            }
//            Section("Layout", isExpanded: $bgLayoutExpanded) {
//                MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//            }
//            Section("Appearance", isExpanded: $bgAppearanceExpanded) {
//                MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//            }
//        }
//        .formStyle(GroupedFormStyle())
//    }
//}
//
//// MARK: - Option B: ScrollView + GroupBox
//
//private struct OptionBView: View {
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//
//    @State private var symbolSourceExpanded = true
//    @State private var symbolLayoutExpanded = true
//    @State private var symbolAppearanceExpanded = true
//    @State private var bgSourceExpanded = true
//    @State private var bgLayoutExpanded = false
//    @State private var bgAppearanceExpanded = true
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 12) {
//                GroupBox {
//                    VStack(alignment: .leading, spacing: 8) {
//                        DisclosureGroup("Source", isExpanded: $symbolSourceExpanded) {
//                            VStack(alignment: .leading, spacing: 6) {
//                                MockSourceControls(symbolName: $symbolName)
//                            }
//                            .padding(.top, 4)
//                        }
//                        Divider()
//                        DisclosureGroup("Layout", isExpanded: $symbolLayoutExpanded) {
//                            VStack(alignment: .leading, spacing: 6) {
//                                MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//                            }
//                            .padding(.top, 4)
//                        }
//                        Divider()
//                        DisclosureGroup("Appearance", isExpanded: $symbolAppearanceExpanded) {
//                            VStack(alignment: .leading, spacing: 6) {
//                                MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//                            }
//                            .padding(.top, 4)
//                        }
//                    }
//                } label: {
//                    Label("Symbol", systemImage: "star.fill")
//                        .font(.headline)
//                }
//
//                GroupBox {
//                    VStack(alignment: .leading, spacing: 8) {
//                        DisclosureGroup("Source", isExpanded: $bgSourceExpanded) {
//                            VStack(alignment: .leading, spacing: 6) {
//                                MockBgSourceControls()
//                            }
//                            .padding(.top, 4)
//                        }
//                        Divider()
//                        DisclosureGroup("Layout", isExpanded: $bgLayoutExpanded) {
//                            VStack(alignment: .leading, spacing: 6) {
//                                MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//                            }
//                            .padding(.top, 4)
//                        }
//                        Divider()
//                        DisclosureGroup("Appearance", isExpanded: $bgAppearanceExpanded) {
//                            VStack(alignment: .leading, spacing: 6) {
//                                MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//                            }
//                            .padding(.top, 4)
//                        }
//                    }
//                } label: {
//                    Label("Background", systemImage: "square.fill")
//                        .font(.headline)
//                }
//            }
//            .padding()
//        }
//    }
//}
//
// MARK: - Option C: ScrollView with Two Forms (.fixedSize)
//
//private struct OptionCView: View {
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//
//    @State private var symbolSourceExpanded = true
//    @State private var symbolLayoutExpanded = true
//    @State private var symbolAppearanceExpanded = true
//    @State private var bgSourceExpanded = true
//    @State private var bgLayoutExpanded = false
//    @State private var bgAppearanceExpanded = true
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 0) {
//                // Symbol group header
//                HStack {
//                    Label("Symbol", systemImage: "star.fill")
//                        .font(.headline)
//                    Spacer()
//                }
//                .padding(.horizontal, 20)
//                .padding(.top, 12)
//                .padding(.bottom, 4)
//
//                Form {
//                    Section("Source", isExpanded: $symbolSourceExpanded) {
//                        MockSourceControls(symbolName: $symbolName)
//                    }
//                    Section("Layout", isExpanded: $symbolLayoutExpanded) {
//                        MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//                    }
//                    Section("Appearance", isExpanded: $symbolAppearanceExpanded) {
//                        MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//                    }
//                }
//                .formStyle(GroupedFormStyle())
//                .fixedSize(horizontal: false, vertical: true)
//
//                // Background group header
//                HStack {
//                    Label("Background", systemImage: "square.fill")
//                        .font(.headline)
//                    Spacer()
//                }
//                .padding(.horizontal, 20)
//                .padding(.top, 12)
//                .padding(.bottom, 4)
//
//                Form {
//                    Section("Source", isExpanded: $bgSourceExpanded) {
//                        MockBgSourceControls()
//                    }
//                    Section("Layout", isExpanded: $bgLayoutExpanded) {
//                        MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//                    }
//                    Section("Appearance", isExpanded: $bgAppearanceExpanded) {
//                        MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//                    }
//                }
//                .formStyle(GroupedFormStyle())
//                .fixedSize(horizontal: false, vertical: true)
//            }
//        }
//    }
//}

//// MARK: - Option D: NavigationSplitView (system two-column)
//
///// Selectable group items for the sidebar list
//private enum SidebarGroup: String, CaseIterable, Identifiable {
//    case symbol = "Symbol"
//    case background = "Background"
//
//    var id: String { rawValue }
//
//    var icon: String {
//        switch self {
//        case .symbol: "star.fill"
//        case .background: "square.fill"
//        }
//    }
//}
//
//private struct OptionDView: View {
//    @State private var selectedGroup: SidebarGroup? = .symbol
//
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//
//    @State private var sourceExpanded = true
//    @State private var layoutExpanded = true
//    @State private var appearanceExpanded = true
//
//    var body: some View {
//        NavigationSplitView {
//            List(SidebarGroup.allCases, selection: $selectedGroup) { group in
//                Label(group.rawValue, systemImage: group.icon)
//            }
//            .navigationSplitViewColumnWidth(min: 120, ideal: 140, max: 180)
//        } detail: {
//            if let group = selectedGroup {
//                Form {
//                    Section("Source", isExpanded: $sourceExpanded) {
//                        switch group {
//                        case .symbol:
//                            MockSourceControls(symbolName: $symbolName)
//                        case .background:
//                            MockBgSourceControls()
//                        }
//                    }
//                    Section("Layout", isExpanded: $layoutExpanded) {
//                        switch group {
//                        case .symbol:
//                            MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//                        case .background:
//                            MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//                        }
//                    }
//                    Section("Appearance", isExpanded: $appearanceExpanded) {
//                        switch group {
//                        case .symbol:
//                            MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//                        case .background:
//                            MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//                        }
//                    }
//                }
//                .formStyle(GroupedFormStyle())
//            } else {
//                Text("Select a group")
//                    .foregroundStyle(.secondary)
//            }
//        }
//    }
//}
//
//// MARK: - Option E: Custom HStack Split (manual two-column)
//
//private struct OptionEView: View {
//    @State private var selectedGroup: SidebarGroup = .symbol
//
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//
//    @State private var sourceExpanded = true
//    @State private var layoutExpanded = true
//    @State private var appearanceExpanded = true
//
//    var body: some View {
//        HStack(spacing: 0) {
//            // Left: group list
//            VStack(spacing: 0) {
//                ForEach(SidebarGroup.allCases) { group in
//                    Button {
//                        selectedGroup = group
//                    } label: {
//                        HStack {
//                            Label(group.rawValue, systemImage: group.icon)
//                            Spacer()
//                        }
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 8)
//                        .background(selectedGroup == group ? Color.accentColor.opacity(0.15) : Color.clear)
//                        .contentShape(Rectangle())
//                    }
//                    .buttonStyle(.plain)
//                }
//                Spacer()
//            }
//            .frame(width: 140)
//            .background(Color(nsColor: .controlBackgroundColor))
//
//            Divider()
//
//            // Right: detail sections for selected group
//            Form {
//                Section("Source", isExpanded: $sourceExpanded) {
//                    switch selectedGroup {
//                    case .symbol:
//                        MockSourceControls(symbolName: $symbolName)
//                    case .background:
//                        MockBgSourceControls()
//                    }
//                }
//                Section("Layout", isExpanded: $layoutExpanded) {
//                    switch selectedGroup {
//                    case .symbol:
//                        MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//                    case .background:
//                        MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//                    }
//                }
//                Section("Appearance", isExpanded: $appearanceExpanded) {
//                    switch selectedGroup {
//                    case .symbol:
//                        MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//                    case .background:
//                        MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//                    }
//                }
//            }
//            .formStyle(GroupedFormStyle())
//        }
//    }
//}
//
// MARK: - Option F: SF Symbols-style Icon Segment Picker + Flat Sections

///// The segments for the icon picker bar — mirrors SF Symbols' top segmented control
//private enum IconSegment: Int, CaseIterable, Identifiable {
//    case symbol = 0
//    case background = 1
//
//    var id: Int { rawValue }
//
//    var icon: String {
//        switch self {
//        case .symbol: "star.square.on.square"
//        case .background: "square.fill"
//        }
//    }
//
//    var label: String {
//        switch self {
//        case .symbol: "Symbol"
//        case .background: "Background"
//        }
//    }
//}
//
///// Custom icon-only segmented picker matching SF Symbols' style
//private struct IconSegmentPicker: View {
//    @Binding var selection: IconSegment
//
//    var body: some View {
//        HStack(spacing: 0) {
//            ForEach(IconSegment.allCases) { segment in
//                Button {
//                    withAnimation(.easeInOut(duration: 0.15)) {
//                        selection = segment
//                    }
//                } label: {
//                    VStack(spacing: 4) {
//                        Image(systemName: segment.icon)
//                            .font(.system(size: 20))
//                            .frame(width: 44, height: 32)
//                        Text(segment.label)
//                            .font(.caption2)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 6)
//                    .background(
//                        RoundedRectangle(cornerRadius: 6)
//                            .fill(selection == segment
//                                  ? Color.accentColor.opacity(0.12)
//                                  : Color.clear)
//                    )
//                    .foregroundStyle(selection == segment ? Color.accentColor : .secondary)
//                }
//                .buttonStyle(.plain)
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 4)
//    }
//}
//
//private struct OptionFView: View {
//    @State private var selectedSegment: IconSegment = .symbol
//
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // SF Symbols-style icon segment picker
//            IconSegmentPicker(selection: $selectedSegment)
//
//            Divider()
//                .padding(.top, 4)
//
//            // Flat sections — no collapsing, just grouped like SF Symbols / Icon Composer
//            Form {
//                switch selectedSegment {
//                case .symbol:
//                    symbolSections
//                case .background:
//                    backgroundSections
//                }
//            }
//            .formStyle(GroupedFormStyle())
//            .id(selectedSegment) // Reset scroll position on segment change
//        }
//    }
//
//    @ViewBuilder
//    private var symbolSections: some View {
//        Section("Source") {
//            MockSourceControls(symbolName: $symbolName)
//        }
//        Section("Layout") {
//            MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//        }
//        Section("Appearance") {
//            MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//        }
//    }
//
//    @ViewBuilder
//    private var backgroundSections: some View {
//        Section("Source") {
//            MockBgSourceControls()
//        }
//        Section("Layout") {
//            MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//        }
//        Section("Appearance") {
//            MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//        }
//    }
//}
//
//// MARK: - Option G: SF Symbols-style with All Four Segments (no outer tabs)
//
///// All four segments — eliminates the outer Icon/Badge TabView entirely
//private enum FullSegment: Int, CaseIterable, Identifiable {
//    case symbol = 0
////    case background = 1
//    case badgeSymbol = 2
////    case badgeBackground = 3
//
//    var id: Int { rawValue }
//
//    var icon: String {
//        switch self {
//        case .symbol: "checkmark.app.fill"
////        case .background: "custom.icon.background"
//        case .badgeSymbol: "custom.badge.symbol"
////        case .badgeBackground: "app.badge.checkmark"
//        }
//    }
//
//    var label: String {
//        switch self {
//        case .symbol: "Icon"
////        case .background: "Icon\nBackground"
//        case .badgeSymbol: "Badge"
////        case .badgeBackground: "Badge\nBackground"
//        }
//    }
//}
//
///// Applies `.symbolColorRenderingMode(.gradient)` on macOS 26+ (new API in Tahoe),
///// no-op on earlier versions.
//private extension View {
//    @ViewBuilder
//    func symbolGradientIfAvailable() -> some View {
//        if #available(macOS 26.0, *) {
//            self.symbolColorRenderingMode(.gradient)
//        } else {
//            self
//        }
//    }
//}
//
//private struct FullSegmentPicker: View {
//    @Binding var selection: FullSegment
//
//    /// Resolves custom asset-catalog symbols via `Image(_:)` and system symbols via `Image(systemName:)`.
//    /// On macOS, `Image(systemName:)` can fail to find custom symbols even though Apple's docs say
//    /// it should search the asset catalog — `Image(_:)` is the reliable path for `custom.*` names.
//    @ViewBuilder
//    private func symbolImage(_ name: String) -> some View {
//        if name.hasPrefix("custom.") {
//            Image(name)
//        } else {
//            Image(systemName: name)
//        }
//    }
//
//    var body: some View {
//        HStack(spacing: 0) {
//            ForEach(FullSegment.allCases) { segment in
//                Button {
//                    withAnimation(.easeInOut(duration: 0.15)) {
//                        selection = segment
//                    }
//                } label: {
//                    VStack(spacing: 4) {
//                        symbolImage(segment.icon)
//                            .font(.system(size: 34))
//                            .symbolRenderingMode(selection == segment ? .hierarchical : .hierarchical )
//                            .symbolGradientIfAvailable()
//                            .frame(width: 36, height: 28)
//                        Text(segment.label)
//                            .font(.caption2)
//                            .lineLimit(2)
//                            .minimumScaleFactor(0.8)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 6)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(selection == segment
//                                  ? Color.accentColor.opacity(0.12)
//                                  : Color.clear)
//                    )
////                    .foregroundStyle(selection == segment ? Color.accentColor : .secondary)
//                }
//                .buttonStyle(.bordered)
//            }
//        }
//        .padding(.horizontal, 8)
//        .padding(.vertical, 4)
//    }
//}
//
//
//private struct OptionGView: View {
//    @State private var selectedSegment: FullSegment = .symbol
//
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//    @State private var showBadge = false
//    @AppStorage("sidebar.iconSource.expanded") private var iconSourceExpanded = true
//    @AppStorage("sidebar.iconLayout.expanded") private var iconLayoutExpanded = true
//    @AppStorage("sidebar.iconAppearance.expanded") private var iconAppearanceExpanded = true
//    @AppStorage("sidebar.backgroundSource.expanded") private var backgroundSourceExpanded = true
//    @AppStorage("sidebar.backgroundAppearance.expanded") private var backgroundAppearanceExpanded = true
//    @AppStorage("sidebar.backgroundLayout.expanded") private var backgroundLayoutExpanded = true
//    @AppStorage("sidebar.badgeSource.expanded") private var badgeSourceExpanded = true
//    @AppStorage("sidebar.badgeLayout.expanded") private var badgeLayoutExpanded = true
//    @AppStorage("sidebar.badgeAppearance.expanded") private var badgeAppearanceExpanded = true
//    @AppStorage("sidebar.badgeBackground.expanded") private var badgeBackgroundSourceExpanded = true
//    @AppStorage("sidebar.badgeAppearance.expanded") private var badgeBackgroundAppearanceExpanded = true
//
//    var body: some View {
//        
//        VStack(spacing: 0) {
//            FullSegmentPicker(selection: $selectedSegment)
//
//            Divider()
//                .padding(.top, 4)
//
//            Form {
//                switch selectedSegment {
//                case .symbol:
//                    Section("Source", isExpanded: $iconSourceExpanded)  {
//                        MockSourceControls(symbolName: $symbolName)
//                    }
//                    Section("Layout", isExpanded: $iconLayoutExpanded) {
//                        MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//                    }
//                    Section("Appearance", isExpanded: $iconAppearanceExpanded) {
//                        MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//                    }
//
////                case .background:
//                    Section("Source", isExpanded: $backgroundSourceExpanded) {
//                        MockBgSourceControls()
//                    }
//                    Section("Layout", isExpanded: $backgroundLayoutExpanded) {
//                        MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//                    }
//                    Section("Appearance", isExpanded: $backgroundAppearanceExpanded ) {
//                        MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//                    }
//
//                case .badgeSymbol:
//                    Section {
//                        HStack {
//                            Text("Show Badge")
//                            Spacer()
//                            Toggle("Show Badge", isOn: $showBadge)
//                                .labelsHidden()
//                        }
//                    }
//                    Section("Source", isExpanded: $badgeSourceExpanded) {
//                        MockSourceControls(symbolName: .constant("plus.circle"))
//                    }
//                    Section("Layout", isExpanded: $badgeLayoutExpanded) {
//                        MockLayoutControls(scale: .constant(0.5), offsetX: .constant(0), offsetY: .constant(0))
//                    }
//                    Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
//                        MockAppearanceControls(color: .constant(.red), weight: .constant(1), shadowEnabled: .constant(false))
//                    }
//
////                case .badgeBackground:
//                    Section("Source", isExpanded: $badgeBackgroundSourceExpanded) {
//                        MockBgSourceControls()
//                    }
//                    Section("Appearance", isExpanded: $badgeBackgroundAppearanceExpanded) {
//                        MockBgAppearanceControls(bgColor: .constant(.red), cornerRadius: .constant(50))
//                    }
//                }
//            }
//            .formStyle(GroupedFormStyle())
//            .id(selectedSegment)
//        }
//    }
//}

// MARK: - Option H: Plain Segmented Picker (all 4 groups, no tabs)

//private struct OptionHView: View {
//    @State private var selectedGroup = 0
//
//    @State private var symbolName = "star.fill"
//    @State private var scale = 1.0
//    @State private var offsetX = 0.0
//    @State private var offsetY = 0.0
//    @State private var color = Color.blue
//    @State private var weight = 1
//    @State private var shadowEnabled = true
//    @State private var bgColor = Color.white
//    @State private var cornerRadius = 40.0
//    @State private var showBadge = false
//
//    var body: some View {
//        VStack(spacing: 0) {
//            Picker("", selection: $selectedGroup) {
//                Label("Symbol", systemImage: "star.square.on.square").tag(0)
//                Label("Background", systemImage: "square.fill").tag(1)
//                Label("Badge", systemImage: "seal").tag(2)
//                Label("Badge BG", systemImage: "seal.fill").tag(3)
//            }
//            .frame(minWidth: 100, idealWidth: 200, maxWidth: .infinity)
//            .labelStyle(IconOnlyLabelStyle())
//            .pickerStyle(.palette)
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//
//            Form {
//                switch selectedGroup {
//                case 0:
//                    Section("Source") {
//                        MockSourceControls(symbolName: $symbolName)
//                    }
//                    Section("Layout") {
//                        MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
//                    }
//                    Section("Appearance") {
//                        MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
//                    }
//
//                case 1:
//                    Section("Source") {
//                        MockBgSourceControls()
//                    }
//                    Section("Layout") {
//                        MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
//                    }
//                    Section("Appearance") {
//                        MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
//                    }
//
//                case 2:
//                    Section {
//                        HStack {
//                            Text("Show Badge")
//                            Spacer()
//                            Toggle("Show Badge", isOn: $showBadge)
//                                .labelsHidden()
//                        }
//                    }
//                    Section("Source") {
//                        MockSourceControls(symbolName: .constant("plus.circle"))
//                    }
//                    Section("Layout") {
//                        MockLayoutControls(scale: .constant(0.5), offsetX: .constant(0), offsetY: .constant(0))
//                    }
//                    Section("Appearance") {
//                        MockAppearanceControls(color: .constant(.red), weight: .constant(1), shadowEnabled: .constant(false))
//                    }
//
//                case 3:
//                    Section("Source") {
//                        MockBgSourceControls()
//                    }
//                    Section("Appearance") {
//                        MockBgAppearanceControls(bgColor: .constant(.red), cornerRadius: .constant(50))
//                    }
//
//                default:
//                    EmptyView()
//                }
//            }
//            .formStyle(GroupedFormStyle())
//            .id(selectedGroup)
//        }
//    }
//}

// MARK: - Option I: 2-Segment Custom Picker + ScrollView with Stacked Forms

// IconBadgePicker / IconOrBadge originally lived in Views/Sidebar/IconBadgeSwitch.swift.
// That file was removed when the production sidebar moved to the LayerSidebar
// hierarchy; keeping these locally so this playground continues to build.
private enum IconOrBadge: Int, CaseIterable, Identifiable {
    case icon = 0
    case badge = 1
    var id: Int { rawValue }
    var systemImageName: String { self == .icon ? "app.fill" : "app.badge" }
    var label: String { self == .icon ? "Icon" : "Badge" }
}

private struct IconBadgePicker: View {
    @Binding var selection: IconOrBadge

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IconOrBadge.allCases) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = segment }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: segment.systemImageName)
                            .font(.system(size: 28))
                            .foregroundStyle(selection == segment ? Color.white : .secondary)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 36, height: 28)
                        Text(segment.label)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selection == segment ? Color.accentColor : Color.primary.opacity(0.1))
                    )
                    .foregroundStyle(selection == segment ? Color.white : .primary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}

private struct OptionIView: View {
    @State private var selectedSegment: IconOrBadge = .icon

    // Icon state
    @State private var symbolName = "star.fill"
    @State private var scale = 1.0
    @State private var offsetX = 0.0
    @State private var offsetY = 0.0
    @State private var color = Color.blue
    @State private var weight = 1
    @State private var shadowEnabled = true
    @State private var bgColor = Color.white
    @State private var cornerRadius = 40.0

    // Badge state
    @State private var showBadge = false
    @State private var badgeSymbolName = "plus.circle"
    @State private var badgeScale = 0.5
    @State private var badgeColor = Color.red
    @State private var badgeBgColor = Color.red
    @State private var badgeCornerRadius = 50.0

    @AppStorage("sidebar.iconSource.expanded") private var iconSourceExpanded = true
    @AppStorage("sidebar.iconLayout.expanded") private var iconLayoutExpanded = true
    @AppStorage("sidebar.iconAppearance.expanded") private var iconAppearanceExpanded = true
    @AppStorage("sidebar.backgroundSource.expanded") private var backgroundSourceExpanded = true
    @AppStorage("sidebar.backgroundAppearance.expanded") private var backgroundAppearanceExpanded = true
    @AppStorage("sidebar.backgroundLayout.expanded") private var backgroundLayoutExpanded = true
    @AppStorage("sidebar.badgeSource.expanded") private var badgeSourceExpanded = true
    @AppStorage("sidebar.badgeLayout.expanded") private var badgeLayoutExpanded = true
    @AppStorage("sidebar.badgeAppearance.expanded") private var badgeAppearanceExpanded = true
    @AppStorage("sidebar.badgeBackgroundSource.expanded") private var badgeBackgroundSourceExpanded = true
    @AppStorage("sidebar.badgeBackgroundAppearance.expanded") private var badgeBackgroundAppearanceExpanded = true
    
//    @State private var iconSourceExpanded = true
//    @State private var iconLayoutExpanded = true
//    @State private var iconAppearanceExpanded = true
//    @State private var backgroundSourceExpanded = true
//    @State private var backgroundAppearanceExpanded = true
//    @State private var backgroundLayoutExpanded = true
//    @State private var badgeSourceExpanded = true
//    @State private var badgeLayoutExpanded = true
//    @State private var badgeAppearanceExpanded = true
//    @State private var badgeBackgroundSourceExpanded = true
//    @State private var badgeBackgroundAppearanceExpanded = true
    
    
    var body: some View {
        VStack(spacing: 0) {
            IconBadgePicker(selection: $selectedSegment)

            Divider()
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 0) {
                    switch selectedSegment {
                    case .icon:
                        iconContent
                    case .badge:
                        badgeContent
                    }
                }
            }
            .id(selectedSegment) // Reset scroll position on switch
        }
    }

    // MARK: - Icon content (Symbol form + Background form stacked)

    @ViewBuilder
    
    private var iconContent: some View {
        groupHeader("Symbol", icon: "checkmark.app")
        Form {
            Section("Source", isExpanded: $iconSourceExpanded) {
                MockSourceControls(symbolName: $symbolName)
            }
            Section("Layout", isExpanded: $iconLayoutExpanded) {
                MockLayoutControls(scale: $scale, offsetX: $offsetX, offsetY: $offsetY)
            }
            Section("Appearance", isExpanded: $iconAppearanceExpanded) {
                MockAppearanceControls(color: $color, weight: $weight, shadowEnabled: $shadowEnabled)
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)
        
        Divider()
            .padding(.top, 4)

        groupHeader("Background", icon: "checkmark.app.fill")
        Form {
            Section("Source", isExpanded: $backgroundSourceExpanded) {
                MockBgSourceControls()
            }
            Section("Layout", isExpanded: $backgroundLayoutExpanded) {
                MockLayoutControls(scale: .constant(1.0), offsetX: .constant(0), offsetY: .constant(0))
            }
            Section("Appearance", isExpanded: $backgroundAppearanceExpanded ) {
                MockBgAppearanceControls(bgColor: $bgColor, cornerRadius: $cornerRadius)
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)
    }

    
    // MARK: - Badge content (Badge Symbol form + Badge Background form stacked)

    @ViewBuilder
    private var badgeContent: some View {
        // Show Badge toggle row above the forms
        Form {
            Section {
                HStack {
                    Text("Show Badge")
                    Spacer()
                    Toggle("Show Badge", isOn: $showBadge)
                        .labelsHidden()
                }
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)

        groupHeader("Symbol", icon: "checkmark.circle")
        Form {
            Section("Source", isExpanded: $badgeSourceExpanded) {
                MockSourceControls(symbolName: $badgeSymbolName)
            }
            Section("Layout", isExpanded: $badgeLayoutExpanded) {
                MockLayoutControls(scale: $badgeScale, offsetX: .constant(0), offsetY: .constant(0))
            }
            Section("Appearance", isExpanded: $badgeAppearanceExpanded) {
                MockAppearanceControls(color: $badgeColor, weight: .constant(1), shadowEnabled: .constant(false))
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)
        
        Divider()
            .padding(.top, 4)
        
        groupHeader("Background", icon: "checkmark.circle.fill")
        Form {
            Section("Source", isExpanded: $badgeBackgroundSourceExpanded) {
                MockBgSourceControls()
            }
            Section("Appearance", isExpanded: $badgeBackgroundAppearanceExpanded) {
                MockBgAppearanceControls(bgColor: $badgeBgColor, cornerRadius: $badgeCornerRadius)
            }
        }
        .formStyle(GroupedFormStyle())
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Shared

    private func groupHeader(_ title: String, icon: String) -> some View {
        HStack {
            Text(title)
                .font(.title3)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Comparison View

struct SidebarLayoutPlayground: View {
    @State private var selectedApproach = 8 // Default to Option I

    var body: some View {
        VStack(spacing: 0) {
            Picker("Approach", selection: $selectedApproach) {
                Text("A").tag(0)
                Text("B").tag(1)
                Text("C").tag(2)
                Text("D").tag(3)
                Text("E").tag(4)
                Text("F").tag(5)
                Text("G").tag(6)
                Text("H").tag(7)
                Text("I").tag(8)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            switch selectedApproach {
//            case 0: OptionAView()
//            case 1: OptionBView()
//            case 2: OptionCView()
//            case 3: OptionDView()
//            case 4: OptionEView()
//            case 5: OptionFView()
//            case 6: OptionGView()
//            case 7: OptionHView()
            case 8: OptionIView()
            default: OptionIView()
            }
        }
        .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity,
               minHeight: 500, idealHeight: 700, maxHeight: .infinity)
    }
}

//#Preview("Sidebar Layout Comparison") {
//    SidebarLayoutPlayground()
//        .frame(width: 500, height: 700)
//}
//
//#Preview("A: Styled Headers") {
//    OptionAView()
//        .frame(width: 300, height: 650)
//}
//
//#Preview("B: GroupBox") {
//    OptionBView()
//        .frame(width: 300, height: 650)
//}
//
//#Preview("C: Two Forms") {
//    OptionCView()
//        .frame(width: 300, height: 650)
//}
//
//#Preview("D: NavigationSplitView") {
//    OptionDView()
//        .frame(width: 450, height: 650)
//}
//
//#Preview("E: HStack Split") {
//    OptionEView()
//        .frame(width: 450, height: 650)
//}
//
//#Preview("F: SF Symbols Segments") {
//    OptionFView()
//        .frame(width: 300, height: 650)
//}

//#Preview("G: All-in-One Segments") {
//    OptionGView()
//        .frame(width: 320, height: 650)
//}

//#Preview("H: Plain Segmented Picker") {
//    OptionHView()
//        .frame(width: 300, height: 650)
//}

#Preview("I: Icon/Badge + Stacked Forms") {
    OptionIView()
        .frame(width: 350, height: 900)
}

//
//  AlignmentTestsGrid2.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 4/9/2025.
//

import SwiftUI

// MARK: - Reuse existing structures from AlignmentTestsGrid.swift
// SizePreferenceKey, AdaptiveSymbolSize, AdaptiveFontSize remain the same

// Re-declare SizePreferenceKey here so this playground file is self-contained
struct SizePreferenceKey2: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// Simple adaptive size modifier (duplicated from original for playground isolation)
struct AdaptiveSymbolSize2: ViewModifier {
    let targetSize: CGFloat
    let maxFrame: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: targetSize, weight: .regular))
            .minimumScaleFactor(maxFrame / targetSize)
            .frame(width: maxFrame, height: maxFrame)
    }
}

// Conditional debug border modifier
struct ConditionalDebugBorder: ViewModifier {
    let showBorder: Bool
    
    func body(content: Content) -> some View {
        content
            .border(showBorder ? .red : .clear, width: showBorder ? 1 : 0 )
    }
}

// MARK: - Solution Component that accepts both symbol and solution type
struct IconSolutionView: View {
    let symbolName: String
    let solutionType: SolutionType
    let showGrid: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.blue.gradient)
                //.shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            
            
            Group { // icon solution content
                switch solutionType {
                case .fixedSize:
                    FixedSizeIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .basicResizable:
                    BasicResizableIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .fontBased:
                    FontBasedIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .colorClearOverlay:
                    ColorClearOverlayIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
//                case .withOffset:
//                    WithOffsetIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .minimumScaleFactor:
                    MinimumScaleFactorIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .viewThatFits:
                    ViewThatFitsIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .preferenceKey:
                    PreferenceKeyIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .twoPassRendering:
                    TwoPassRenderingIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                case .customModifier:
                    CustomModifierIcon(symbolName: symbolName, showDebugBorders: showDebugBorders)
                }
            }
            // SVG Grid Overlay from Asset Catalog
            if showGrid {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }}
            .frame(width: 103, height: 103)
        }
    }


// MARK: - Solution Types
enum SolutionType: String, CaseIterable {
    case fixedSize = "Fixed Font Size"
    case fontBased = "Conditional Font Size"
    case basicResizable = "Scaled Resizable"
    case colorClearOverlay = "Clear Overlay"
    //case withOffset = "With Offset"
    case minimumScaleFactor = "Min Scale Factor"
    case viewThatFits = "ViewThatFits"
    case preferenceKey = "PreferenceKey"
    case twoPassRendering = "Two-Pass Render"
    case customModifier = "Custom Modifier"
}

// MARK: - Individual Icon Components (extracted from original solutions)
struct FixedSizeIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 55, weight: .regular))
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
                    .frame(width: 103, height: 103, alignment: .center)
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}


struct BasicResizableIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 83, height: 83)
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}

struct FontBasedIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var fontSizeMultiplier: CGFloat {
        switch symbolName {
        case let name where name.contains("square"),
             let name where name.contains("circle"),
             let name where name.contains("gear"):
            return 1.3
        case let name where name.contains("square"):
            return 1.2
        case let name where name.contains("bell"),
            let name where name.contains("folder"),
            let name where name.contains("badge"):
            return 1.0
        default:
            return 1.15
        }
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 60 * fontSizeMultiplier, weight: .regular))
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}

struct ColorClearOverlayIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Color.clear
            .frame(width: 83, height: 83)
            .overlay(
                Group {
                    if isAssetImage {
                        Image(symbolName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: symbolName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.white)
                            //.shadow(radius: 1, x: 0, y: 1.25)
                    }
                }
                .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
            )
    }
}

//struct WithOffsetIcon: View {
//    let symbolName: String
//    let showDebugBorders: Bool
//    
//    var isAssetImage: Bool {
//        symbolName.hasPrefix("CFBundle-")
//    }
//    
//    var body: some View {
//        Color.clear
//            .frame(width: 83, height: 83)
//            .overlay(
//                Group {
//                    if isAssetImage {
//                        Image(symbolName)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .offset(x: 2)
//                    } else {
//                        Image(systemName: symbolName)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .foregroundColor(.white)
//                            //.shadow(radius: 1, x: 0, y: 1.25)
//                            .offset(x: 2)
//                    }
//                }
//                .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
//            )
//    }
//}

struct MinimumScaleFactorIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 55, weight: .regular))
                    .minimumScaleFactor(0.5)
                    .frame(width: 82, height: 82)
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}

struct ViewThatFitsIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                ViewThatFits {
                    Image(systemName: symbolName)
                        .font(.system(size: 65, weight: .regular))
                        .frame(maxWidth: 82, maxHeight: 82)
                        .foregroundColor(.white)
                        //.shadow(radius: 1, x: 0, y: 1.25)
                    
                    Image(systemName: symbolName)
                        .font(.system(size: 60, weight: .regular))
                        .frame(maxWidth: 82, maxHeight: 82)
                        .foregroundColor(.white)
                        //.shadow(radius: 1, x: 0, y: 1.25)
                    
                    Image(systemName: symbolName)
                        .font(.system(size: 55, weight: .regular))
                        .frame(maxWidth: 82, maxHeight: 82)
                        .foregroundColor(.white)
                        //.shadow(radius: 1, x: 0, y: 1.25)
                }
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}

struct PreferenceKeyIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    @State private var fontSize: CGFloat = 63
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: fontSize, weight: .regular))
                    //.imageScale(.large)
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: SizePreferenceKey2.self, value: geometry.size)
                        }
                    )
                    .onPreferenceChange(SizePreferenceKey2.self) { size in
                        if size.width > 85 || size.height > 85 {
                            let scaleFactor = min(85 / size.width, 85 / size.height)
                            fontSize = fontSize * scaleFactor
                        }
                    }
                    .frame(maxWidth: 85, maxHeight: 85)
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}

struct TwoPassRenderingIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    @State private var idealFontSize: CGFloat = 67.5
    @State private var measuredSize: CGSize = .zero
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var calculatedFontSize: CGFloat {
        if measuredSize.width > 82 || measuredSize.height > 82 {
            let scaleFactor = min(82 / max(measuredSize.width, 1),
                                 82 / max(measuredSize.height, 1))
            return idealFontSize * scaleFactor * 0.95
        }
        return idealFontSize
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                ZStack {
                    // Invisible measuring pass
                    Image(systemName: symbolName)
                        .font(.system(size: idealFontSize, weight: .regular))
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        measuredSize = geometry.size
                                    }
                            }
                        )
                        .opacity(0)
                    
                    // Visible render
                    Image(systemName: symbolName)
                        .font(.system(size: calculatedFontSize, weight: .regular))
                        .foregroundColor(.white)
                        //.shadow(radius: 1, x: 0, y: 1.25)
                        .frame(width: 83, height: 83)
                }
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}

struct CustomModifierIcon: View {
    let symbolName: String
    let showDebugBorders: Bool
    
    var isAssetImage: Bool {
        symbolName.hasPrefix("CFBundle-")
    }
    
    var body: some View {
        Group {
            if isAssetImage {
                Image(symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: symbolName)
                    .modifier(AdaptiveSymbolSize2(targetSize: 63, maxFrame: 82))
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
            }
        }
        .modifier(ConditionalDebugBorder(showBorder: showDebugBorders))
    }
}


// MARK: - Main Grid View (Version 2)
struct AllSolutionsGridV2: View {
    let testSymbols = [
        "CFBundle-person.crop.circle.badge.plus",
        "square.fill",
        "square.and.arrow.up",
        "square.and.arrow.up.trianglebadge.exclamationmark",
        "folder.fill.badge.plus",
        "doc.text.magnifyingglass",
        "gearshape.fill",
        "bell.and.waves.left.and.right.fill",
        "person.crop.circle",
        "person.crop.circle.badge.plus",
        "phone.fill",
        "phone.fill.badge.checkmark"
    ]
    
    @State private var selectedSolution: SolutionType = .preferenceKey
    @State private var showGridOverlay: Bool = true
    @State private var showDebugBorders: Bool = false
    
    let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 15)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Text("SF Symbol Alignment Solutions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Controls
                HStack(spacing: 16) {
                    Picker("Alignment Solution", selection: $selectedSolution) {
                        ForEach(SolutionType.allCases, id: \.self) { solution in
                            Text(solution.rawValue).tag(solution)
                                .scaledToFit()
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 260)
                    
                    VStack(spacing: 8) {
                        Toggle(isOn: $showGridOverlay) {
                            Text("Grid Overlay")
                        }
                        .toggleStyle(.switch)
                        
                        Toggle(isOn: $showDebugBorders) {
                            Text("Debug Borders")
                        }
                        .toggleStyle(.switch)
                    }
                }
                
                Text("Currently showing: \(selectedSolution.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Scrollable Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(testSymbols, id: \.self) { symbol in
                        VStack(spacing: 6) {
                            IconSolutionView(symbolName: symbol, solutionType: selectedSolution, showGrid: showGridOverlay, showDebugBorders: showDebugBorders)
                            
                            Text(symbol)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(height: 20)
                        }
                    }
                }
                .padding()
            }
            
            // Description
            VStack(spacing: 8) {
                Text(solutionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var solutionDescription: String {
        switch selectedSolution {
        case .fixedSize:
            return "Uses .font() with fixed size"
        case .basicResizable:
            return "Uses .font() with fixed size and .aspectRatio(contentMode: .fit)"
        case .fontBased:
            return "Applies dynamic font size multipliers based on symbol characteristics"
        case .colorClearOverlay:
            return "Uses Color.clear container with .overlay() for precise control"
//        case .withOffset:
//            return "Adds manual offset adjustments for visual centering"
        case .minimumScaleFactor:
            return "Uses .minimumScaleFactor() to automatically scale down oversized symbols"
        case .viewThatFits:
            return "iOS 16+ ViewThatFits with multiple size fallbacks"
        case .preferenceKey:
            return "Measures symbol size and adjusts font dynamically using PreferenceKey"
        case .twoPassRendering:
            return "Invisible measurement pass followed by calculated visible render"
        case .customModifier:
            return "Reusable ViewModifier combining font sizing with scale factor"

        }
    }
}

// MARK: - Preview
struct GridViewV2: View {
    var body: some View {
        AllSolutionsGridV2()
            .frame(minWidth: 400, minHeight: 900)
    }
}

#Preview {
    GridViewV2()
}

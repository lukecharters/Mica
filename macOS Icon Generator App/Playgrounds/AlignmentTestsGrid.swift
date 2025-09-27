//
//  SizePreferenceKey.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 2/9/2025.
//

import SwiftUI

// MARK: - PreferenceKey for Solution
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Custom ViewModifiers
struct AdaptiveSymbolSize: ViewModifier {
    let targetSize: CGFloat
    let maxFrame: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: targetSize, weight: .regular))
            .minimumScaleFactor(maxFrame / targetSize)
            .frame(width: maxFrame, height: maxFrame)
    }
}

struct AdaptiveFontSize: ViewModifier {
    let symbolName: String
    let targetSize: CGFloat
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    
    @State private var fontSize: CGFloat
    @State private var hasAdjusted = false
    
    init(symbolName: String, targetSize: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat) {
        self.symbolName = symbolName
        self.targetSize = targetSize
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self._fontSize = State(initialValue: targetSize)
    }
    
    func body(content: Content) -> some View {
        Image(systemName: symbolName)
            .font(.system(size: fontSize, weight: .regular))
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: geometry.size) { oldValue, newValue in
                            if !hasAdjusted && (newValue.width > maxWidth || newValue.height > maxHeight) {
                                let scaleFactor = min(maxWidth / newValue.width, maxHeight / newValue.height)
                                fontSize *= scaleFactor * 0.95
                                hasAdjusted = true
                            }
                        }
                }
            )
    }
}

// Conditional debug border modifier
struct ConditionalDebugBorder1: ViewModifier {
    let showBorder: Bool
    
    func body(content: Content) -> some View {
        content
            .border(showBorder ? .red : .clear, width: 1)
    }
}

// MARK: - Individual Solution Views
struct CFBundleIcon_Original: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack {
            
            Image("CFBundle-\(symbolName)")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
            

        }
    }
}

struct Solution1_BasicResizable: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            
            Image(systemName: symbolName)
                .font(.system(size: 60, weight: .regular))
                .frame(width: 82.5, height: 82.5) // 80% of 103
                .foregroundColor(.white)
                //.shadow(radius: 1, x: 0, y: 1.25)
                .aspectRatio(contentMode: .fit)
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct Solution2_FontBased: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var Solution2_iconSize: CGFloat = 103
    
//    var fontSizeMultiplier: CGFloat {
//        switch symbolName {
//        case let name where name.contains("square"),
//             let name where name.contains("circle"),
//             let name where name.contains("gearshape"):
//            return 1.3
//        case let name where name.contains("folder"):
//            return 1.0
//        default:
//            return 1.15
//        }
//    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: Solution2_iconSize, height: Solution2_iconSize)
            
            
            Image(systemName: symbolName)
                .font(.system(size: Solution2_iconSize * 0.55, weight: .regular))
                .foregroundColor(.white)
                //.shadow(radius: 1, x: 0, y: 1.25)
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct Solution3_ColorClearOverlay: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            

            
            Color.clear
                .frame(width: 82.5, height: 82.5)
                .overlay(
                    Image(systemName: symbolName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        //.imageScale(.small)
                        //.shadow(radius: 1, x: 0, y: 1.25)
                        .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
                )
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

//struct Solution4_WithOffset: View {
//    let symbolName: String
//    let showGridOverlay: Bool
//    let showDebugBorders: Bool
//    
//    var body: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: 23, style: .continuous)
//                .fill(.blue.gradient)
//                .shadow(radius: 1, x: 0, y: 1.25)
//                .frame(width: 103, height: 103)
//            
//            
//            
//            Color.clear
//                .frame(width: 82.5, height: 82.5)
//                .overlay(
//                    Image(systemName: symbolName)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .foregroundColor(.white)
//                        .shadow(radius: 1, x: 0, y: 1.25)
//                        .offset(x: 2)
//                        .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
//                )
//            // SVG Grid Overlay from Asset Catalog
//            if showGridOverlay {
//                Image("App Icon Template SVG")
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .opacity(0.3)
//                    .frame(width: 103, height: 103)
//                    .allowsHitTesting(false)
//            }
//        }
//    }
//}

struct Solution5_MinimumScaleFactor: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            
            Image(systemName: symbolName)
                .font(.system(size: 67.5, weight: .regular))
                .minimumScaleFactor(0.5)
                .frame(width: 82.5, height: 82.5)
                .foregroundColor(.white)
                //.shadow(radius: 1, x: 0, y: 1.25)
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
        
    }
}

struct Solution6_ViewThatFits: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            

            
            ViewThatFits {
                Image(systemName: symbolName)
                    .font(.system(size: 67.5, weight: .regular))
                    .frame(maxWidth: 82.5, maxHeight: 82.5)
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
                    .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
                
                Image(systemName: symbolName)
                    .font(.system(size: 60, weight: .regular))
                    .frame(maxWidth: 82.5, maxHeight: 82.5)
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
                    .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
                
                Image(systemName: symbolName)
                    .font(.system(size: 50, weight: .regular))
                    .frame(maxWidth: 82.5, maxHeight: 82.5)
                    .foregroundColor(.white)
                    //.shadow(radius: 1, x: 0, y: 1.25)
                    .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            }
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct Solution7_PreferenceKey: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    @State private var symbolSize: CGSize = .zero
    @State private var fontSize: CGFloat = 67.5
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            

            
            Image(systemName: symbolName)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(.white)
                //.shadow(radius: 1, x: 0, y: 1.25)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: geometry.size)
                    }
                )
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    if size.width > 82.5 || size.height > 82.5 {
                        let scaleFactor = min(82.5 / size.width, 82.5 / size.height)
                        fontSize = fontSize * scaleFactor
                    }
                }
                .frame(maxWidth: 82.5, maxHeight: 82.5)
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct Solution8_TwoPassRendering: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    @State private var idealFontSize: CGFloat = 67.5
    @State private var measuredSize: CGSize = .zero
    
    var calculatedFontSize: CGFloat {
        if measuredSize.width > 82.5 || measuredSize.height > 82.5 {
            let scaleFactor = min(82.5 / max(measuredSize.width, 1), 
                                 82.5 / max(measuredSize.height, 1))
            return idealFontSize * scaleFactor * 0.95
        }
        return idealFontSize
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            

            
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
                .frame(width: 82.5, height: 82.5)
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct Solution9_CustomModifier: View {
    let symbolName: String
    let showGridOverlay: Bool
    let showDebugBorders: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 1, x: 0, y: 1.25)
                .frame(width: 103, height: 103)
            
            Image(systemName: symbolName)
                .modifier(AdaptiveSymbolSize(targetSize: 63, maxFrame: 78))
                .foregroundColor(.white)
                //.shadow(radius: 1, x: 0, y: 1.25)
                .modifier(ConditionalDebugBorder1(showBorder: showDebugBorders))
            
            // SVG Grid Overlay from Asset Catalog
            if showGridOverlay {
                Image("App Icon Template SVG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
                    .frame(width: 103, height: 103)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Main Grid View
struct AllSolutionsGrid: View {
    let testSymbols = ["folder.fill.badge.plus", "square.fill", "gearshape.fill", "person.crop.circle.badge.plus", "bell.and.waves.left.and.right.fill"]
    @State private var selectedSymbol = "folder.fill.badge.plus"
    @State private var showGridOverlay: Bool = true
    @State private var showDebugBorders: Bool = false
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 20)
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            VStack(spacing: 10) {
                Text("SF Symbol Sizing Solutions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Symbol Picker
                Picker("", selection: $selectedSymbol) {
                    ForEach(testSymbols, id: \.self) { symbol in
                        Text(symbol).tag(symbol)
                        .scaledToFit()
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 600)
                
                // Controls
                HStack(spacing: 16) {
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
            .padding()
            
            // Scrollable Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    
                    
                    VStack(spacing: 8) {
                    CFBundleIcon_Original(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Original Appex Icon")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("CFBundleIcon")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    
                    // Solution 1
                    VStack(spacing: 8) {
                        Solution1_BasicResizable(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Basic Resizable")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(".resizable().aspectRatio")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 2
                    VStack(spacing: 8) {
                        Solution2_FontBased(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Font with Multiplier")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Dynamic font sizing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 3
                    VStack(spacing: 8) {
                        Solution3_ColorClearOverlay(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Clear Overlay")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Color.clear container")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 4
//                    VStack(spacing: 8) {
//                        Solution4_WithOffset(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
//                        Text("With Offset")
//                            .font(.caption)
//                            .fontWeight(.medium)
//                        Text("Manual x: 2 offset")
//                            .font(.caption2)
//                            .foregroundColor(.secondary)
//                    }
                    
                    // Solution 5
                    VStack(spacing: 8) {
                        Solution5_MinimumScaleFactor(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Min Scale Factor")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(".minimumScaleFactor(0.5)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 6
                    VStack(spacing: 8) {
                        Solution6_ViewThatFits(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("ViewThatFits")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("iOS 16+ adaptive")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 7
                    VStack(spacing: 8) {
                        Solution7_PreferenceKey(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("PreferenceKey")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Measure & adjust")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 8
                    VStack(spacing: 8) {
                        Solution8_TwoPassRendering(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Two-Pass Render")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Invisible measure first")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Solution 9
                    VStack(spacing: 8) {
                        Solution9_CustomModifier(symbolName: selectedSymbol, showGridOverlay: showGridOverlay, showDebugBorders: showDebugBorders)
                        Text("Custom Modifier")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Reusable modifier")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Preview
struct GridView: View {
    var body: some View {
        AllSolutionsGrid()
            .frame(minWidth: 400, minHeight: 700)
    }
}

#Preview {
    GridView()
}

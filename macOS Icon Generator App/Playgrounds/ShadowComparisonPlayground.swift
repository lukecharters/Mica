// ShadowComparisonPlayground.swift
// Compare drop shadow settings against Apple reference icons from Assets.xcassets

import SwiftUI

struct ShadowComparisonPlayground: View {
    // MARK: - Reference image catalog

    /// Each entry maps a reference asset name to its corresponding SF Symbol name
    private static let referenceImages: [(assetName: String, symbolName: String, label: String)] = [
        ("CFBundle-bell.and.waves.left.and.right.fill", "bell.and.waves.left.and.right.fill", "bell.and.waves…"),
        ("CFBundle-doc.text.magnifyingglass", "doc.text.magnifyingglass", "doc.text.mag…"),
        ("CFBundle-folder.fill.badge.plus", "folder.fill.badge.plus", "folder.fill.badge.plus"),
        ("CFBundle-gearshape.fill", "gearshape.fill", "gearshape.fill"),
        ("CFBundle-person.crop.circle", "person.crop.circle", "person.crop.circle"),
        ("CFBundle-person.crop.circle.badge.plus", "person.crop.circle.badge.plus", "person…badge.plus"),
        ("CFBundle-phone.fill", "phone.fill", "phone.fill"),
        ("CFBundle-phone.fill.badge.checkmark", "phone.fill.badge.checkmark", "phone…checkmark"),
        ("CFBundle-square.and.arrow.up", "square.and.arrow.up", "square.and.arrow.up"),
        ("CFBundle-square.and.arrow.up.trianglebadge.exclamationmark", "square.and.arrow.up.trianglebadge.exclamationmark", "square…triangle"),
        ("CFBundle-square.fill", "square.fill", "square.fill"),
        ("folder.fill.badge.plus.sequoia", "folder.fill.badge.plus", "folder (sequoia)"),
        ("gearshape.fill.sequoia", "gearshape.fill", "gearshape (sequoia)"),
        ("icon.sequoia", "square", "icon (sequoia)"),
        ("CFBundle-externaldrive.fill", "externaldrive.fill", "externaldrive.fill")
    ]

    // MARK: - State

    @State private var selectedIndex: Int = 0

    // Background shadow
    @State private var bgShadowEnabled: Bool = true
    @State private var bgShadowRadius: CGFloat = 4
    @State private var bgShadowOffsetY: CGFloat = 2.5
    @State private var bgShadowOpacity: CGFloat = 0.35

    // Symbol shadow
    @State private var symShadowEnabled: Bool = true
    @State private var symShadowRadius: CGFloat = 2
    @State private var symShadowOffsetY: CGFloat = 2.5
    @State private var symShadowOpacity: CGFloat = 0.23

    // Badge background shadow
    @State private var badgeBgShadowEnabled: Bool = true
    @State private var badgeBgShadowRadiusMul: CGFloat = 0.03
    @State private var badgeBgShadowOffsetMul: CGFloat = 0.02
    @State private var badgeBgShadowOpacity: CGFloat = 0.31

    // Badge symbol shadow
    @State private var badgeSymShadowEnabled: Bool = true
    @State private var badgeSymShadowRadiusMul: CGFloat = 0.02
    @State private var badgeSymShadowOffsetMul: CGFloat = 0.025
    @State private var badgeSymShadowOpacity: CGFloat = 0.15

    // Badge toggle
    @State private var showBadge: Bool = true

    // Comparison controls
    @State private var splitPosition: CGFloat = 0.5
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomBase: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var showWiper: Bool = true
    @State private var overlayOpacity: Double = 0.5
    @State private var comparisonMode: ComparisonMode = .split

    private let renderSize: CGFloat = 256

    enum ComparisonMode: String, CaseIterable {
        case split = "Split"
        case overlay = "Overlay"
        case sideBySide = "Side by Side"
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            controlsSidebar
                .frame(width: 280)
            Divider()
            comparisonArea
        }
    }

    // MARK: - Controls Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Reference picker
                referencePickerSection

                Divider()

                // Comparison mode
                comparisonModeSection

                Divider()

                // Badge toggle
                Toggle("Show Badge", isOn: $showBadge)
                    .font(.headline)

                Divider()

                // Background shadow
                shadowSection(
                    title: "Background Shadow",
                    enabled: $bgShadowEnabled,
                    radius: $bgShadowRadius,
                    radiusRange: 0...12,
                    offsetY: $bgShadowOffsetY,
                    offsetRange: 0...8,
                    opacity: $bgShadowOpacity
                )

                Divider()

                // Symbol shadow
                shadowSection(
                    title: "Symbol Shadow",
                    enabled: $symShadowEnabled,
                    radius: $symShadowRadius,
                    radiusRange: 0...12,
                    offsetY: $symShadowOffsetY,
                    offsetRange: 0...8,
                    opacity: $symShadowOpacity
                )

                Divider()

                // Badge background shadow
                badgeShadowSection(
                    title: "Badge BG Shadow",
                    enabled: $badgeBgShadowEnabled,
                    radiusMul: $badgeBgShadowRadiusMul,
                    offsetMul: $badgeBgShadowOffsetMul,
                    opacity: $badgeBgShadowOpacity
                )

                Divider()

                // Badge symbol shadow
                badgeShadowSection(
                    title: "Badge Symbol Shadow",
                    enabled: $badgeSymShadowEnabled,
                    radiusMul: $badgeSymShadowRadiusMul,
                    offsetMul: $badgeSymShadowOffsetMul,
                    opacity: $badgeSymShadowOpacity
                )

                Divider()

                // Reset button
                Button("Reset All to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)

                // Zoom info
                Text("Zoom: \(zoomScale, specifier: "%.1f")x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Scroll to zoom, drag to pan")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }

    private var referencePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reference Image")
                .font(.headline)
            ForEach(Array(Self.referenceImages.enumerated()), id: \.offset) { index, ref in
                Button {
                    selectedIndex = index
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: ref.symbolName)
                            .frame(width: 18)
                        Text(ref.label)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(selectedIndex == index ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var comparisonModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Comparison Mode")
                .font(.headline)
            Picker("", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if comparisonMode == .split {
                Toggle("Show Wiper", isOn: $showWiper)
                    .font(.caption)
            }
            if comparisonMode == .overlay {
                LabeledSlider(label: "Overlay Opacity", value: $overlayOpacity, range: 0...1, format: "%.2f")
            }
        }
    }

    // MARK: - Shadow control sections

    private func shadowSection(
        title: String,
        enabled: Binding<Bool>,
        radius: Binding<CGFloat>,
        radiusRange: ClosedRange<CGFloat>,
        offsetY: Binding<CGFloat>,
        offsetRange: ClosedRange<CGFloat>,
        opacity: Binding<CGFloat>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: enabled)
                .font(.headline)
            Group {
                LabeledSlider(label: "Radius", value: radius, range: radiusRange, format: "%.1f")
                LabeledSlider(label: "Offset Y", value: offsetY, range: offsetRange, format: "%.1f")
                LabeledSlider(label: "Opacity", value: opacity, range: 0...1, format: "%.2f")
            }
            .disabled(!enabled.wrappedValue)
            .opacity(enabled.wrappedValue ? 1 : 0.4)
        }
    }

    private func badgeShadowSection(
        title: String,
        enabled: Binding<Bool>,
        radiusMul: Binding<CGFloat>,
        offsetMul: Binding<CGFloat>,
        opacity: Binding<CGFloat>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: enabled)
                .font(.headline)
            Group {
                LabeledSlider(label: "Radius ×", value: radiusMul, range: 0...0.1, format: "%.3f")
                LabeledSlider(label: "Offset ×", value: offsetMul, range: 0...0.1, format: "%.3f")
                LabeledSlider(label: "Opacity", value: opacity, range: 0...1, format: "%.2f")
            }
            .disabled(!enabled.wrappedValue)
            .opacity(enabled.wrappedValue ? 1 : 0.4)
        }
    }

    // MARK: - Comparison Area

    private var comparisonArea: some View {
        GeometryReader { geo in
            ZStack {
                Color.white

                switch comparisonMode {
                case .split:
                    splitComparisonView(containerWidth: geo.size.width)
                case .overlay:
                    overlayComparisonView()
                case .sideBySide:
                    sideBySideComparisonView(availableSize: geo.size)
                }
            }
            .clipped()
            .gesture(magnifyGesture)
            .gesture(panGesture)
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoomScale = 1.0
                    zoomBase = 1.0
                    panOffset = .zero
                }
            }
        }
    }

    // MARK: - Split comparison (wiper)

    private func splitComparisonView(containerWidth: CGFloat) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let splitX = width * splitPosition
            ZStack(alignment: .leading) {
                // Left half: reference, in a clipped container
                referenceImageView
                    .frame(width: renderSize, height: renderSize)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .frame(width: width, height: height)
                    .frame(width: splitX, height: height, alignment: .leading)
                    .clipped()

                // Right half: our render, in a clipped container offset to the right
                customRenderView
                    .frame(width: renderSize, height: renderSize)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .frame(width: width, height: height)
                    .frame(width: width - splitX, height: height, alignment: .trailing)
                    .clipped()
                    .offset(x: splitX)

                // Wiper line + labels
                if showWiper {
                    wiperOverlay(width: width, height: height)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        splitPosition = min(max(value.location.x / max(width, 1), 0), 1)
                    }
            )
        }
    }

    private func wiperOverlay(width: CGFloat, height: CGFloat) -> some View {
        let xPos = width * splitPosition
        return ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: height)
                .position(x: xPos, y: height / 2)
                .shadow(color: .black.opacity(0.5), radius: 2)

            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 3)
                .position(x: xPos, y: height / 2)

            Text("Reference")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                .position(x: 60, y: 20)

            Text("Ours")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                .position(x: width - 40, y: 20)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Overlay comparison

    private func overlayComparisonView() -> some View {
        ZStack {
            referenceImageView
                .frame(width: renderSize, height: renderSize)
                .scaleEffect(zoomScale)
                .offset(panOffset)

            customRenderView
                .frame(width: renderSize, height: renderSize)
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .opacity(overlayOpacity)
        }
    }

    // MARK: - Side by side

    private func sideBySideComparisonView(availableSize: CGSize) -> some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Reference")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                referenceImageView
                    .frame(width: renderSize, height: renderSize)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
            }
            VStack(spacing: 4) {
                Text("Ours")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                customRenderView
                    .frame(width: renderSize, height: renderSize)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
            }
        }
    }

    // MARK: - Rendered views

    private var referenceImageView: some View {
        Image(currentReference.assetName)
            .resizable()
            .interpolation(.none) // Crisp pixels when zoomed
            .aspectRatio(contentMode: .fit)
    }

    private var customRenderView: some View {
        ShadowTunableIconView(
            symbolName: currentReference.symbolName,
            displaySize: renderSize,
            showBadge: showBadge,
            bgShadowEnabled: bgShadowEnabled,
            bgShadowRadius: bgShadowRadius,
            bgShadowOffsetY: bgShadowOffsetY,
            bgShadowOpacity: bgShadowOpacity,
            symShadowEnabled: symShadowEnabled,
            symShadowRadius: symShadowRadius,
            symShadowOffsetY: symShadowOffsetY,
            symShadowOpacity: symShadowOpacity,
            badgeBgShadowEnabled: badgeBgShadowEnabled,
            badgeBgShadowRadiusMul: badgeBgShadowRadiusMul,
            badgeBgShadowOffsetMul: badgeBgShadowOffsetMul,
            badgeBgShadowOpacity: badgeBgShadowOpacity,
            badgeSymShadowEnabled: badgeSymShadowEnabled,
            badgeSymShadowRadiusMul: badgeSymShadowRadiusMul,
            badgeSymShadowOffsetMul: badgeSymShadowOffsetMul,
            badgeSymShadowOpacity: badgeSymShadowOpacity
        )
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = max(0.5, min(zoomBase * value.magnification, 20))
            }
            .onEnded { value in
                zoomBase = max(0.5, min(zoomBase * value.magnification, 20))
                zoomScale = zoomBase
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if comparisonMode != .split {
                    panOffset = CGSize(
                        width: dragStart.width + value.translation.width,
                        height: dragStart.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                dragStart = panOffset
            }
    }

    // MARK: - Helpers

    private var currentReference: (assetName: String, symbolName: String, label: String) {
        Self.referenceImages[selectedIndex]
    }

    private func resetToDefaults() {
        bgShadowEnabled = true
        bgShadowRadius = 4
        bgShadowOffsetY = 2.5
        bgShadowOpacity = 0.35

        symShadowEnabled = true
        symShadowRadius = 2
        symShadowOffsetY = 2.5
        symShadowOpacity = 0.23

        badgeBgShadowEnabled = true
        badgeBgShadowRadiusMul = 0.03
        badgeBgShadowOffsetMul = 0.02
        badgeBgShadowOpacity = 0.31

        badgeSymShadowEnabled = true
        badgeSymShadowRadiusMul = 0.02
        badgeSymShadowOffsetMul = 0.025
        badgeSymShadowOpacity = 0.15
    }
}

// MARK: - Tunable icon view (mirrors IconContentView but with adjustable shadow params)

private struct ShadowTunableIconView: View {
    let symbolName: String
    let displaySize: CGFloat
    let showBadge: Bool

    // Background shadow params (base 256pt values)
    let bgShadowEnabled: Bool
    let bgShadowRadius: CGFloat
    let bgShadowOffsetY: CGFloat
    let bgShadowOpacity: CGFloat

    // Symbol shadow params (base 256pt values)
    let symShadowEnabled: Bool
    let symShadowRadius: CGFloat
    let symShadowOffsetY: CGFloat
    let symShadowOpacity: CGFloat

    // Badge BG shadow params (multipliers of badgeSize)
    let badgeBgShadowEnabled: Bool
    let badgeBgShadowRadiusMul: CGFloat
    let badgeBgShadowOffsetMul: CGFloat
    let badgeBgShadowOpacity: CGFloat

    // Badge symbol shadow params (multipliers of badgeSize)
    let badgeSymShadowEnabled: Bool
    let badgeSymShadowRadiusMul: CGFloat
    let badgeSymShadowOffsetMul: CGFloat
    let badgeSymShadowOpacity: CGFloat

    // Layout constants matching IconContentView
    private let baseSize: CGFloat = 256
    private let baseCornerRadius: CGFloat = 54  // macOS 26 style
    private let baseBackgroundInset: CGFloat = 25
    private let baseBadgeSize: CGFloat = 80
    private let baseBadgeOffset: CGFloat = 4

    private var scaleFactor: CGFloat { displaySize / baseSize }
    private var cornerRadius: CGFloat { baseCornerRadius * scaleFactor }
    private var backgroundInset: CGFloat { baseBackgroundInset * scaleFactor }
    private var enclosureSize: CGFloat { displaySize - (2 * backgroundInset) }
    private var badgeSize: CGFloat { baseBadgeSize * scaleFactor }
    private var badgeOffset: CGFloat { baseBadgeOffset * scaleFactor }

    private var resolvedSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: symbolName)
    }

    private var symbolSize: CGFloat {
        enclosureSize * resolvedSizing.multiplier
    }

    /// The badge symbol name extracted from the main symbol, or a default
    private var badgeSymbolName: String {
        guard let range = symbolName.range(of: ".badge.") else { return "gearshape.fill" }
        return String(symbolName[range.upperBound...])
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.gray.gradient)
                .shadow(
                    color: bgShadowEnabled ? Color.black.opacity(bgShadowOpacity) : .clear,
                    radius: bgShadowEnabled ? bgShadowRadius * scaleFactor : 0,
                    y: bgShadowEnabled ? bgShadowOffsetY * scaleFactor : 0
                )
                .padding(backgroundInset)

            // Symbol
            Image(systemName: symbolName)
                .font(.system(size: symbolSize, weight: resolvedSizing.weight))
                .foregroundColor(.white)
                .symbolRenderingMode(.monochrome)
                .offset(
                    x: enclosureSize * resolvedSizing.xOffset,
                    y: enclosureSize * resolvedSizing.yOffset
                )
                .frame(width: displaySize, height: displaySize)
                .padding(-backgroundInset)
                .shadow(
                    color: symShadowEnabled ? Color.black.opacity(symShadowOpacity) : .clear,
                    radius: symShadowEnabled ? symShadowRadius * scaleFactor : 0,
                    y: symShadowEnabled ? symShadowOffsetY * scaleFactor : 0
                )

            // Badge
            if showBadge {
                ShadowTunableBadgeView(
                    symbolName: badgeSymbolName,
                    badgeSize: badgeSize,
                    bgShadowEnabled: badgeBgShadowEnabled,
                    bgShadowRadiusMul: badgeBgShadowRadiusMul,
                    bgShadowOffsetMul: badgeBgShadowOffsetMul,
                    bgShadowOpacity: badgeBgShadowOpacity,
                    symShadowEnabled: badgeSymShadowEnabled,
                    symShadowRadiusMul: badgeSymShadowRadiusMul,
                    symShadowOffsetMul: badgeSymShadowOffsetMul,
                    symShadowOpacity: badgeSymShadowOpacity
                )
                .offset(badgeOffsetForBottomRight)
            }
        }
        .frame(width: displaySize, height: displaySize)
    }

    private var badgeOffsetForBottomRight: CGSize {
        let iconRadius = displaySize / 2
        let badgeRadius = badgeSize / 2
        let dist = iconRadius - badgeRadius - badgeOffset
        return CGSize(width: dist, height: dist)
    }
}

// MARK: - Tunable badge view

private struct ShadowTunableBadgeView: View {
    let symbolName: String
    let badgeSize: CGFloat

    let bgShadowEnabled: Bool
    let bgShadowRadiusMul: CGFloat
    let bgShadowOffsetMul: CGFloat
    let bgShadowOpacity: CGFloat

    let symShadowEnabled: Bool
    let symShadowRadiusMul: CGFloat
    let symShadowOffsetMul: CGFloat
    let symShadowOpacity: CGFloat

    private var resolvedSizing: ResolvedSymbolSizing {
        SymbolSizingService.resolve(for: symbolName)
    }

    private var badgeSymbolSize: CGFloat {
        badgeSize * resolvedSizing.multiplier
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.gradient)
                .shadow(
                    color: bgShadowEnabled ? Color.black.opacity(bgShadowOpacity) : .clear,
                    radius: bgShadowEnabled ? badgeSize * bgShadowRadiusMul : 0,
                    y: bgShadowEnabled ? badgeSize * bgShadowOffsetMul : 0
                )

            Image(systemName: symbolName)
                .font(.system(size: badgeSymbolSize, weight: resolvedSizing.weight))
                .foregroundColor(.white)
                .symbolRenderingMode(.monochrome)
                .shadow(
                    color: symShadowEnabled ? Color.black.opacity(symShadowOpacity) : .clear,
                    radius: symShadowEnabled ? badgeSize * symShadowRadiusMul : 0,
                    y: symShadowEnabled ? badgeSize * symShadowOffsetMul : 0
                )
        }
        .frame(width: badgeSize, height: badgeSize)
    }
}

// MARK: - Labeled slider helper

private struct LabeledSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: format, Double(value)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}

extension LabeledSlider {
    init(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) {
        self.label = label
        self._value = Binding(
            get: { CGFloat(value.wrappedValue) },
            set: { value.wrappedValue = Double($0) }
        )
        self.range = CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        self.format = format
    }
}

// MARK: - Preview

#Preview {
    ShadowComparisonPlayground()
        .frame(width: 1200, height: 800)
}

// IconComparisonPlayground.swift
// Compare the real render pipeline (IconContentView) against imported
// screenshots of reference icons — built to calibrate macOS 27's new
// icon/symbol shadows and badge geometry. Replaces the old
// ShadowComparisonPlayground, whose hand-copied mirror view had drifted
// from the production constants.

import SwiftUI
import UniformTypeIdentifiers

struct IconComparisonPlayground: View {
    // MARK: - State

    @State private var settings: IconSettings = {
        var s = IconSettings()
        s.useCustomColors = true
        s.enableBackgroundGradient = false
        s.badgeUseCustomColors = true
        s.badgeEnableBackgroundGradient = false
        s.showBadge = true
        return s
    }()

    @State private var renderSize: CGFloat = 256

    // Tunable shadow override — drives the real IconContentView/BadgeView.
    @State private var shadow: ShadowStyle = .macOS26
    // Background shadow has no per-settings enable flag (only the style enum),
    // so the on/off toggle is playground-local. The other three toggles bind
    // to the real gates in IconSettings.
    @State private var bgShadowEnabled: Bool = true

    // Reference screenshot + alignment transform (applied inside its cell,
    // independent of the shared zoom/pan).
    @State private var referenceImage: NSImage? = nil
    @State private var referenceName: String = ""
    @State private var refScale: CGFloat = 1.0
    @State private var refOffsetX: CGFloat = 0
    @State private var refOffsetY: CGFloat = 0

    // Comparison controls
    @State private var comparisonMode: ComparisonMode = .split
    @State private var splitPosition: CGFloat = 0.5
    @State private var showWiper: Bool = true
    @State private var overlayOpacity: Double = 0.5
    @State private var canvasBackground: CanvasBackground = .white
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomBase: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var dragTarget: DragTarget = .canvas
    @State private var isDropTargeted: Bool = false

    // Sheets
    @State private var showSymbolPicker = false
    @State private var showBadgeSymbolPicker = false

    enum ComparisonMode: String, CaseIterable {
        case split = "Split"
        case overlay = "Overlay"
        case difference = "Difference"
        case sideBySide = "Side by Side"
    }

    enum CanvasBackground: String, CaseIterable {
        case white = "White"
        case gray = "Gray"
        case black = "Black"

        var color: Color {
            switch self {
            case .white: return .white
            case .gray: return Color(white: 0.5)
            case .black: return .black
            }
        }
    }

    enum DragTarget: String, CaseIterable {
        case canvas = "Canvas"
        case reference = "Reference"
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            controlsSidebar
                .frame(width: 320)
            Divider()
            comparisonArea
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $settings.symbolName)
        }
        .sheet(isPresented: $showBadgeSymbolPicker) {
            SymbolPickerView(selectedSymbol: $settings.badgeSymbolName)
        }
    }

    // MARK: - Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                renderSection
                Divider()
                iconSection
                Divider()
                badgeSection
                Divider()
                shadowControls
                Divider()
                referenceSection
                Divider()
                comparisonSection
            }
            .padding()
        }
    }

    private var renderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Render")
                .font(.headline)
            LabeledSlider(label: "Size (pt)", value: $renderSize, range: 64...1024, format: "%.0f")
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.headline)
            HStack {
                Image(systemName: settings.symbolName)
                    .frame(width: 20)
                Text(settings.symbolName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") { showSymbolPicker = true }
                    .controlSize(.small)
            }
            ColorPicker("Background", selection: $settings.customPrimaryColor)
            Toggle("Background Gradient", isOn: $settings.enableBackgroundGradient)
            if settings.enableBackgroundGradient {
                ColorPicker("Gradient End", selection: $settings.customSecondaryColor)
            }
            ColorPicker("Symbol", selection: $settings.symbolColor)
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Badge", isOn: $settings.showBadge)
                .font(.headline)
            if settings.showBadge {
                HStack {
                    Image(systemName: settings.badgeSymbolName)
                        .frame(width: 20)
                    Text(settings.badgeSymbolName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") { showBadgeSymbolPicker = true }
                        .controlSize(.small)
                }
                ColorPicker("Background", selection: $settings.badgeCustomPrimaryColor)
                ColorPicker("Symbol", selection: $settings.badgeSymbolColor)
                Picker("Position", selection: $settings.badgePosition) {
                    ForEach(BadgePosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                LabeledSlider(label: "Scale", value: $settings.badgeScale, range: 0.5...2.0, format: "%.3f")
                LabeledSlider(label: "Offset X", value: $settings.badgeManualOffsetX, range: -0.2...0.2, format: "%.4f")
                LabeledSlider(label: "Offset Y", value: $settings.badgeManualOffsetY, range: -0.2...0.2, format: "%.4f")
                derivedRatiosReadout
            }
        }
    }

    /// Effective badge geometry ratios implied by the tuned scale/offset —
    /// the candidate values for a future macOS 27 `BadgeGeometry` variant.
    private var derivedRatiosReadout: some View {
        // offset(for:enclosureSize: 1) yields the signed effective anchor
        // ratios directly (anchor ± manual offset, per position).
        let anchor = BadgeGeometry.offset(for: settings, enclosureSize: 1)
        let diameter = BadgeGeometry.diameterRatio * settings.badgeScale
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Derived ratios")
                    .font(.caption.bold())
                Spacer()
                Button("Copy") { copyToPasteboard(derivedRatiosText) }
                    .controlSize(.mini)
            }
            Group {
                Text("diameter \(diameter, specifier: "%.4f") (\(diameter * 208, specifier: "%.1f")/208)")
                Text("anchorX \(abs(anchor.width), specifier: "%.4f") (\(abs(anchor.width) * 208, specifier: "%.1f")/208)")
                Text("anchorY \(abs(anchor.height), specifier: "%.4f") (\(abs(anchor.height) * 208, specifier: "%.1f")/208)")
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }

    private var derivedRatiosText: String {
        let anchor = BadgeGeometry.offset(for: settings, enclosureSize: 1)
        let diameter = BadgeGeometry.diameterRatio * settings.badgeScale
        return String(
            format: """
            diameterRatio = %.4f (%.1f/208)
            anchorXRatio = %.4f (%.1f/208)
            anchorYRatio = %.4f (%.1f/208)
            """,
            diameter, diameter * 208,
            abs(anchor.width), abs(anchor.width) * 208,
            abs(anchor.height), abs(anchor.height) * 208
        )
    }

    // MARK: - Shadow controls

    private var shadowControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Shadows")
                    .font(.headline)
                Spacer()
                Button("Copy Values") { copyToPasteboard(shadowValuesText) }
                    .controlSize(.small)
            }
            HStack {
                Button("Load macOS 26") { shadow = .macOS26 }
                Button("Load Sequoia") { shadow = .sequoia }
            }
            .controlSize(.small)

            canvasShadowSection(
                title: "Background Shadow",
                enabled: $bgShadowEnabled,
                shadow: $shadow.background
            )
            canvasShadowSection(
                title: "Symbol Shadow",
                enabled: $settings.enableSymbolShadow,
                shadow: $shadow.symbol
            )
            badgeShadowSection(
                title: "Badge BG Shadow",
                enabled: $settings.badgeEnableBackgroundShadow,
                shadow: $shadow.badgeBackground
            )
            badgeShadowSection(
                title: "Badge Symbol Shadow",
                enabled: $settings.badgeEnableSymbolShadow,
                shadow: $shadow.badgeSymbol
            )
        }
    }

    private func canvasShadowSection(
        title: String,
        enabled: Binding<Bool>,
        shadow: Binding<ShadowStyle.CanvasShadow>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: enabled)
                .font(.subheadline.bold())
            Group {
                LabeledSlider(label: "Radius", value: shadow.radius, range: 0...12, format: "%.2f")
                LabeledSlider(label: "Offset Y", value: shadow.offsetY, range: 0...8, format: "%.2f")
                LabeledSlider(label: "Opacity", value: shadow.opacity, range: 0...1, format: "%.2f")
            }
            .disabled(!enabled.wrappedValue)
            .opacity(enabled.wrappedValue ? 1 : 0.4)
        }
    }

    private func badgeShadowSection(
        title: String,
        enabled: Binding<Bool>,
        shadow: Binding<ShadowStyle.BadgeShadow>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: enabled)
                .font(.subheadline.bold())
            Group {
                LabeledSlider(label: "Radius ×", value: shadow.radiusMultiplier, range: 0...0.1, format: "%.3f")
                LabeledSlider(label: "Offset ×", value: shadow.offsetYMultiplier, range: 0...0.1, format: "%.3f")
                LabeledSlider(label: "Opacity", value: shadow.opacity, range: 0...1, format: "%.2f")
            }
            .disabled(!enabled.wrappedValue)
            .opacity(enabled.wrappedValue ? 1 : 0.4)
        }
    }

    /// Paste-ready ShadowStyle initializer — the artifact a future
    /// `.macOS27` preset gets built from.
    private var shadowValuesText: String {
        String(
            format: """
            ShadowStyle(
                background: CanvasShadow(radius: %.2f, offsetY: %.2f, opacity: %.2f),
                symbol: CanvasShadow(radius: %.2f, offsetY: %.2f, opacity: %.2f),
                badgeBackground: BadgeShadow(radiusMultiplier: %.3f, offsetYMultiplier: %.3f, opacity: %.2f),
                badgeSymbol: BadgeShadow(radiusMultiplier: %.3f, offsetYMultiplier: %.3f, opacity: %.2f)
            )
            """,
            shadow.background.radius, shadow.background.offsetY, shadow.background.opacity,
            shadow.symbol.radius, shadow.symbol.offsetY, shadow.symbol.opacity,
            shadow.badgeBackground.radiusMultiplier, shadow.badgeBackground.offsetYMultiplier, shadow.badgeBackground.opacity,
            shadow.badgeSymbol.radiusMultiplier, shadow.badgeSymbol.offsetYMultiplier, shadow.badgeSymbol.opacity
        )
    }

    // MARK: - Reference section

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reference Screenshot")
                .font(.headline)
            if let image = referenceImage {
                HStack {
                    Text(referenceName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Clear") { clearReference() }
                        .controlSize(.small)
                }
                Text("\(pixelSize(of: image).width, specifier: "%.0f") × \(pixelSize(of: image).height, specifier: "%.0f") px")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                LabeledSlider(label: "Scale", value: $refScale, range: 0.5...2.0, format: "%.4f")
                LabeledSlider(label: "Offset X", value: $refOffsetX, range: -renderSize / 2...renderSize / 2, format: "%.1f")
                LabeledSlider(label: "Offset Y", value: $refOffsetY, range: -renderSize / 2...renderSize / 2, format: "%.1f")
                Picker("Drag moves", selection: $dragTarget) {
                    ForEach(DragTarget.allCases, id: \.self) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                Button("Reset Alignment") {
                    refScale = 1.0
                    refOffsetX = 0
                    refOffsetY = 0
                }
                .controlSize(.small)
            } else {
                Text("Drop an image on the comparison area, or…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Import…") { importReferenceFromPanel() }
                .controlSize(.small)
        }
    }

    // MARK: - Comparison section

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparison")
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
            Picker("Canvas", selection: $canvasBackground) {
                ForEach(CanvasBackground.allCases, id: \.self) { background in
                    Text(background.rawValue).tag(background)
                }
            }
            .pickerStyle(.segmented)

            Text("Zoom: \(zoomScale, specifier: "%.1f")x")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Pinch to zoom, drag to pan, double-click to reset")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Comparison area

    private var comparisonArea: some View {
        GeometryReader { geo in
            ZStack {
                canvasBackground.color

                switch comparisonMode {
                case .split:
                    splitComparisonView
                case .overlay:
                    overlayComparisonView
                case .difference:
                    differenceComparisonView
                case .sideBySide:
                    sideBySideComparisonView
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
                    dragStart = .zero
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(4)
            }
        }
    }

    // MARK: - Split comparison (wiper)

    private var splitComparisonView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let splitX = width * splitPosition
            ZStack(alignment: .leading) {
                // Left half: reference, in a clipped container
                referenceView
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .frame(width: width, height: height)
                    .frame(width: splitX, height: height, alignment: .leading)
                    .clipped()

                // Right half: our render, in a clipped container offset to the right
                ourRenderView
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .frame(width: width, height: height)
                    .frame(width: width - splitX, height: height, alignment: .trailing)
                    .clipped()
                    .offset(x: splitX)

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

    // MARK: - Overlay / difference / side by side

    private var overlayComparisonView: some View {
        ZStack {
            referenceView
            ourRenderView
                .opacity(overlayOpacity)
        }
        .scaleEffect(zoomScale)
        .offset(panOffset)
    }

    private var differenceComparisonView: some View {
        ZStack {
            referenceView
            ourRenderView
                .blendMode(.difference)
        }
        .compositingGroup()
        .scaleEffect(zoomScale)
        .offset(panOffset)
    }

    private var sideBySideComparisonView: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Reference")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                referenceView
            }
            VStack(spacing: 4) {
                Text("Ours")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ourRenderView
            }
        }
        .scaleEffect(zoomScale)
        .offset(panOffset)
    }

    // MARK: - Rendered views

    /// The REAL render pipeline. The canvas can exceed renderSize when the
    /// badge overhangs the chiclet; framing at the full canvas first and then
    /// re-centering in a renderSize cell keeps the chiclet aligned with the
    /// reference while letting the badge overflow draw.
    private var ourRenderView: some View {
        let canvas = IconContentView.totalCanvasSize(for: settings, displaySize: renderSize)
        return IconContentView(settings: settings, displaySize: renderSize, shadowOverride: effectiveShadow)
            .frame(width: canvas, height: canvas)
            .frame(width: renderSize, height: renderSize)
    }

    private var effectiveShadow: ShadowStyle {
        var style = shadow
        if !bgShadowEnabled {
            style.background = .none
        }
        return style
    }

    private var referenceView: some View {
        Group {
            if let image = referenceImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: renderSize, height: renderSize)
                    .scaleEffect(refScale)
                    .offset(x: refOffsetX, y: refOffsetY)
            } else {
                // Fixed gray, not .secondary: the canvas colour is explicit
                // (white/gray/black) regardless of appearance, and semantic
                // colours go white-on-white in dark mode.
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(white: 0.55), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .overlay {
                        Text("Drop a screenshot here")
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.55))
                    }
            }
        }
        .frame(width: renderSize, height: renderSize)
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
                guard comparisonMode != .split else { return } // wiper owns the drag
                if dragTarget == .reference, referenceImage != nil {
                    // Dividing by zoom keeps drag speed 1:1 with the cursor.
                    refOffsetX = dragStart.width + value.translation.width / zoomScale
                    refOffsetY = dragStart.height + value.translation.height / zoomScale
                } else {
                    panOffset = CGSize(
                        width: dragStart.width + value.translation.width,
                        height: dragStart.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if dragTarget == .reference, referenceImage != nil {
                    dragStart = CGSize(width: refOffsetX, height: refOffsetY)
                } else {
                    dragStart = panOffset
                }
            }
    }

    // MARK: - Reference import

    /// Loads via NSImage(contentsOf:) — deliberately NOT ImageImportService,
    /// which squares and downsamples to 1024px and would corrupt a
    /// pixel-accurate comparison.
    private func loadReference(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        referenceImage = image
        referenceName = url.lastPathComponent
        refScale = 1.0
        refOffsetX = 0
        refOffsetY = 0
        dragStart = panOffset
    }

    private func importReferenceFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            loadReference(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(
            where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        ) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                loadReference(from: url)
            }
        }
        return true
    }

    private func clearReference() {
        referenceImage = nil
        referenceName = ""
        refScale = 1.0
        refOffsetX = 0
        refOffsetY = 0
    }

    // MARK: - Helpers

    private func pixelSize(of image: NSImage) -> CGSize {
        let rep = image.representations.max {
            $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh
        }
        guard let rep, rep.pixelsWide > 0 else { return image.size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
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
    IconComparisonPlayground()
        .frame(width: 1400, height: 900)
}

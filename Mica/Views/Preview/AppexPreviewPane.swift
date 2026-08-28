// Views/Preview/AppexPreviewPane.swift
import SwiftUI

struct AppexPreviewPane: View {
    @ObservedObject var viewModel: IconViewModel
    var appexService: AppexReferenceService

    /// Display zoom, owned by `ContentView` and driven by the toolbar's `ZoomMenu`.
    @Binding var zoomLevel: Double
    /// Preview-only override of the icon's display point size (MDM portal sizes,
    /// etc.); `nil` follows the export size. Owned by `ContentView`, driven by the
    /// toolbar's `PreviewSizeMenu`.
    @Binding var previewPointSize: CGFloat?
    /// Click-to-select, as in `ScaledIconPreview`. The icon is a single appex image
    /// here, so clicking it reports the background layer and the owner collapses
    /// that to the Icon group; a Mica-composited badge still resolves its layers.
    var onSelect: ((PreviewHitTarget) -> Void)? = nil
    /// Reports where the pointer is, as in `ScaledIconPreview` — on every sample,
    /// because the owner needs the motion and not only the answer, and `.away` on
    /// exit because leaving skips the outlines' hold.
    var onPointer: ((PreviewPointer) -> Void)? = nil
    /// The layer the inspector is editing, outlined in the preview.
    var selection: PreviewSelection? = nil
    /// The layer under the pointer, outlined at the hover weight. In System mode the
    /// icon is one layer, so this is usually the group as a whole.
    var hovered: PreviewSelection? = nil
    /// Whether the pointer is in a tracked area at all — the owner's answer.
    var pointerIsInside: Bool = false
    /// Bumped by the owner on a canvas click and on pointer motion, so the outlines
    /// come back after they have faded.
    var outlineWake: Int = 0
    /// Builds the drag-out payload, or nil to disable dragging the icon out. See
    /// `DraggableIcon`; the owner supplies it because the System-mode payload needs
    /// the appex export parameters.
    var makeDragPayload: (() -> DraggableIcon)? = nil
    /// The right-click menu's commands, as in `ScaledIconPreview` — this pane is
    /// the canvas in System mode, so it carries the same menu.
    var contextActions: PreviewContextActions = .unavailable

    /// Where the pointer last was, in this pane's icon coordinates. See the note
    /// on `ScaledIconPreview.hoverPoint`: `.contextMenu` reports no location.
    @State private var hoverPoint: CGPoint? = nil

    var body: some View {
        previewContent
        .task(id: viewModel.appexGenerationKey) {
            // Debounce: cancel and restart on every change; 400ms wait before firing.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.generateAppexIcon(service: appexService)
        }
        .task(id: viewModel.badgeAppexGenerationKey) {
            guard viewModel.iconSettings.badge.isVisible,
                  viewModel.iconSettings.badge.foreground.source == .system else {
                return
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.generateBadgeAppexIcon(service: appexService)
        }
    }

    private var previewContent: some View {
        // The `GeometryReader` centres the icon, and it belongs outside the
        // `ScrollView` — see the long note on `ContentView.previewPane`, which is this
        // pane's Mica-mode twin and carries the macOS 27 measurement. The border is
        // attached after the frame so it keeps hugging the pane rather than the
        // icon, which is what it did before the stretch stopped working.
        GeometryReader { viewport in
            ScrollView([.horizontal, .vertical]) {
                iconContent
                    .frame(
                        minWidth: viewport.size.width,
                        minHeight: viewport.size.height,
                        alignment: .center
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }
        }
        // `minWidth: 0` is load-bearing — see the long note on
        // `ContentView.previewPane`, which is this pane's Mica-mode twin. Without it
        // a live window drag loops SwiftUI's `SplitViewChildController` against
        // AppKit's constraints pass and macOS 27 terminates the app.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    @ViewBuilder
    private var iconContent: some View {
        let size = (previewPointSize ?? viewModel.iconSettings.export.size) * zoomLevel
        if viewModel.appexIsGenerating {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Generating…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        } else if let image = viewModel.appexRenderedImage {
            ZStack {
                // Hiding the icon group hides the appex render, same as hiding both
                // layers does in Mica mode. Without this gate the sidebar's group
                // eye and the Visible toggle would appear to do nothing here.
                if !viewModel.iconSettings.icon.isHidden {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: size, height: size)
                } else {
                    Color.clear
                        .frame(width: size, height: size)
                }

                if viewModel.iconSettings.badge.isVisible {
                    let enclosureSize = size * (1 - 50.0 / 256.0)
                    let badgeSize = BadgeGeometry.diameter(
                        enclosureSize: enclosureSize,
                        badgeScale: viewModel.iconSettings.badge.scale
                    )
                    let badgeOffset = BadgeGeometry.offset(
                        for: viewModel.iconSettings,
                        enclosureSize: enclosureSize
                    )
                    if viewModel.iconSettings.badge.foreground.source == .system,
                       viewModel.badgeAppexRenderedImage == nil {
                        // Preview-only stand-in; BadgeView draws nothing until the
                        // badge's appex image exists.
                        BadgeAppexStatusView(
                            badgeSize: badgeSize,
                            error: viewModel.badgeAppexError
                        )
                        .offset(badgeOffset)
                    } else {
                        BadgeView(
                            settings: viewModel.iconSettings,
                            badgeSize: badgeSize,
                            badgeAppexImage: viewModel.badgeAppexRenderedImage
                        )
                        .offset(badgeOffset)
                    }
                }
            }
            // The badge is offset rather than laid out, so it doesn't grow this
            // frame — any part of it hanging outside the image isn't clickable.
            .frame(width: size, height: size)
            // The same sentence `ScaledIconPreview` speaks, from the same
            // function: this pane draws the same icon by a different pipeline,
            // and describing it twice is how the two descriptions drift.
            // `IconAccessibilityDescription` reads `icon.mode`, so it already
            // knows to say "system-rendered" here.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IconAccessibilityDescription.previewLabel)
            .accessibilityValue(IconAccessibilityDescription.value(for: viewModel.iconSettings))
            .overlay {
                PreviewOutlineOverlay(
                    settings: viewModel.iconSettings,
                    displaySize: size,
                    selected: selection,
                    hovered: hovered,
                    pointerIsInside: pointerIsInside,
                    wake: outlineWake
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let target = PreviewHitTester.systemTarget(
                    at: location,
                    settings: viewModel.iconSettings,
                    iconSize: size
                ) else { return }
                onSelect?(target)
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    hoverPoint = point
                    // `systemTarget`, not `target`: the appex image is one flat layer,
                    // so there is no icon foreground to hover. There is no badge drag
                    // overlay in this pane either, so nothing to suppress.
                    let target = PreviewHitTester.systemTarget(
                        at: point,
                        settings: viewModel.iconSettings,
                        iconSize: size
                    )
                    onPointer?(.over(target.map { .layer($0.group, $0.tab) }))
                case .ended:
                    hoverPoint = nil
                    onPointer?(.away)
                }
            }
            // `isSystem: true`, which is what makes the icon here read as one
            // layer — and why the background rows are absent over it: the appex
            // pipeline takes a symbol and two colours, so a pasted background
            // would change nothing. A Mica-composited badge still resolves
            // normally, and its rows still appear.
            .contextMenu {
                IconContextMenuContent(
                    settings: $viewModel.iconSettings,
                    items: IconContextMenu.canvasItems(
                        for: IconContextMenu.group(
                            at: hoverPoint,
                            settings: viewModel.iconSettings,
                            displaySize: size,
                            isSystem: true
                        ),
                        settings: viewModel.iconSettings,
                        canExport: contextActions.canExport
                    ),
                    actions: contextActions
                )
            }
            // Applied to the whole composite here, unlike `ScaledIconPreview` which
            // applies it to the icon layer alone. There is no badge drag overlay in
            // System mode, so nothing competes for the gesture and there is no reason
            // to exclude the badge from the draggable region.
            .iconDragOut(makeDragPayload)
        } else if let error = viewModel.appexError {
            ContentUnavailableView(
                "Generation Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .frame(width: 512, height: 512)
        } else {
            ContentUnavailableView(
                "No Preview",
                systemImage: "app.dashed",
                description: Text("Enter a symbol name to generate")
            )
            .frame(width: 512, height: 512)
        }
    }

}

#Preview {
    @Previewable @State var zoomLevel: Double = 1.0
    @Previewable @State var previewPointSize: CGFloat? = nil
    AppexPreviewPane(
        viewModel: IconViewModel(),
        appexService: AppexReferenceService(),
        zoomLevel: $zoomLevel,
        previewPointSize: $previewPointSize
    )
    .frame(width: 600, height: 600)
}

// Views/Preview/ScaledIconPreview.swift
//
// The interactive preview: the render view plus the badge drag overlay,
// click-to-select hit testing and drag-and-drop import. Split out of
// ContentView.swift on 2026-07-28 — NOTES.md had to write "ScaledIconPreview
// (in ContentView.swift)" to help anyone find it.
//
// The pure render view it wraps is IconContentView; per NOTES.md, gestures and
// interactive state belong here and never there.
import SwiftUI
import UniformTypeIdentifiers

// Preview component that scales based on export size
struct ScaledIconPreview: View {
    @Binding var settings: IconSettings
    let displaySize: CGFloat
    var badgeAppexImage: NSImage? = nil
    var badgeAppexError: String? = nil
    /// Click-to-select: reports which layer the click landed on so the owner can
    /// point the inspector at it. See `PreviewHitTester`.
    var onSelect: ((PreviewHitTarget) -> Void)? = nil
    /// The layer the inspector is editing, outlined in the preview. nil draws nothing.
    var selection: PreviewSelection? = nil
    /// Bumped on each canvas click so re-clicking the selected layer re-shows the
    /// outline after it has faded.
    var selectionPulse: Int = 0
    /// Builds the drag-out payload, or nil to disable dragging the icon out. The
    /// owner supplies it because the payload needs the export document, which for a
    /// System-mode layer means view-model state this view never sees. See
    /// `DraggableIcon`.
    var makeDragPayload: (() -> DraggableIcon)? = nil
    /// What the right-click menu's Copy Icon / Export as PNG… / Paste rows do, and
    /// whether the first two are offered. Supplied by the owner for the same
    /// reason `makeDragPayload` is — they need the export document and the
    /// pasteboard, which are view-model state this view never sees.
    var contextActions: PreviewContextActions = .unavailable

    /// So a badge drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit
    /// Where a failed drop goes. From the environment rather than a parameter
    /// because it is not this view's decision how a failure is shown — see
    /// `UserMessage`.
    @Environment(\.reportUserMessage) private var reportUserMessage

    @State private var dragStart: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var isHoveringBadge: Bool = false
    /// The single cursor this view currently has on NSCursor's stack, if any.
    @State private var pushedCursor: NSCursor? = nil
    /// Where the pointer last was, in canvas coordinates.
    ///
    /// **`.contextMenu` reports no location**, so this is the only way a
    /// right-click can know whether it landed on the badge — and it is exact
    /// rather than an approximation: the pointer has to be over the thing to
    /// right-click it, and a secondary click does not move it. nil until the
    /// pointer has ever entered the canvas, which `IconContextMenu.group` reads as
    /// the icon.
    ///
    /// The alternative — a second `.contextMenu` on the badge drag overlay — would
    /// have needed no location and was rejected: the overlay is a plain circle of
    /// the badge diameter, where `PreviewHitTester` knows about imported artwork
    /// drawn past it and the System-mode squircle. That is a second answer to
    /// "what is under the pointer", which this item is specifically not allowed to
    /// grow.
    @State private var hoverPoint: CGPoint? = nil

    /// Enclosure size at the current display scale
    private var enclosureSize: CGFloat {
        displaySize - 2 * (25 * displaySize / 256) // backgroundInset * scaleFactor
    }

    var body: some View {
        ZStack {
            // The drag-out source is this layer, not the composite, and that placement
            // is the whole trick: the badge drag overlay is a sibling *above* it in the
            // ZStack, so a press on the badge hits the overlay and moves the badge,
            // while a press anywhere else hits this and drags a PNG out. No gesture
            // arbitration is involved, which is what keeps it clear of the problem
            // recorded below — a parent-level `.draggable` would compete with the
            // overlay's `DragGesture` exactly as `.onTapGesture` did.
            //
            // The modifier is applied here, at the call site, so `IconContentView`
            // itself stays a pure render view per NOTES.md.
            IconContentView(settings: settings, displaySize: displaySize, badgeAppexImage: badgeAppexImage)
                .iconDragOut(makeDragPayload)
                // The app's central object, and not an accessibility element at
                // all until item C1 — a VoiceOver user was told nothing about
                // what had been generated. `children: .ignore` because the render
                // is a stack of shapes and images with nothing individually worth
                // hearing; the sentence describes the whole of it.
                //
                // Declared here rather than in `IconContentView`, which stays a
                // pure render view — and because the same sentence has to reach
                // `AppexPreviewPane`, which does not use that view at all.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(IconAccessibilityDescription.previewLabel)
                .accessibilityValue(IconAccessibilityDescription.value(for: settings))

            // Preview-only spinner/error where the System-mode badge will render.
            // BadgeView itself draws nothing until the appex image exists, so this
            // stand-in never reaches exports.
            if settings.badge.isVisible,
               settings.badge.foreground.source == .system,
               badgeAppexImage == nil {
                BadgeAppexStatusView(
                    badgeSize: BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badge.scale),
                    error: badgeAppexError
                )
                .offset(BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize))
                .allowsHitTesting(false)
            }

            // Selection outline sits above the icon but below the badge overlay so
            // it never intercepts a drag.
            if let selection,
               let shape = PreviewHitTester.selectionShape(
                   for: selection,
                   settings: settings,
                   displaySize: displaySize
               ) {
                SelectionOutline(
                    shape: shape,
                    displaySize: displaySize,
                    selection: selection,
                    pulse: selectionPulse
                )
            }

            // Draggable badge overlay
            if settings.badge.isVisible {
                badgeDragOverlay
            }
        }
        .frame(width: displaySize, height: displaySize, alignment: .center)
        // A drag space that does *not* move with the badge. See `badgeDragOverlay`.
        .coordinateSpace(.named(Self.dragSpace))
        // Attached after the frame so the tap location is in canvas coordinates,
        // which is what PreviewHitTester expects.
        //
        // simultaneousGesture, not .onTapGesture: the badge overlay is a child with
        // its own DragGesture, and a child's gesture normally wins arbitration
        // against the parent's. Recognizing simultaneously keeps a click on the
        // badge from being swallowed. The two still can't fight — a tap needs the
        // pointer to stay put, so a real drag fails the tap, and a stationary click
        // never reaches the drag's 2pt minimum.
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .local)
                .onEnded { value in
                    guard let target = PreviewHitTester.target(
                        at: value.location,
                        settings: settings,
                        displaySize: displaySize
                    ) else { return }
                    onSelect?(target)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isDropTargeted ? 2 : 1)
        )
        // Attached after `.frame`, like the tap gesture and the drop, so the
        // location arrives in the same `displaySize` square canvas coordinates
        // `PreviewHitTester` expects.
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point): hoverPoint = point
            case .ended: hoverPoint = nil
            }
        }
        .contextMenu {
            IconContextMenuContent(
                settings: $settings,
                items: IconContextMenu.canvasItems(
                    for: contextGroup,
                    settings: settings,
                    canExport: contextActions.canExport
                ),
                actions: contextActions
            )
        }
        // Attached after `.frame`, so `location` arrives in the same `displaySize`
        // square canvas coordinates the tap gesture above works in — which is what
        // `PreviewHitTester` expects. Verified on screen 2026-08-05 by dropping on
        // the badge and watching the badge change; a *global*-space location would
        // land off-canvas and route everything back to the icon, which is exactly
        // what not fixing B4 looks like. The types come from `ImageImportService`
        // rather than a list spelled here, so there is one place to widen.
        .onDrop(of: ImageImportService.allDropTypes, isTargeted: $isDropTargeted) { providers, location in
            handleDrop(providers: providers, at: location)
        }
        .onChange(of: settings.badge.offsetX) { _, newValue in
            // Only track external offset changes (sliders, reset). Re-seeding on the
            // drag's own writes compounds the offset: DragGesture.translation is
            // cumulative from gesture start, so the baseline must stay fixed mid-drag.
            if !isDragging {
                dragStart = CGSize(width: newValue, height: settings.badge.offsetY)
            }
        }
        .onChange(of: settings.badge.offsetY) { _, newValue in
            if !isDragging {
                dragStart = CGSize(width: settings.badge.offsetX, height: newValue)
            }
        }
    }

    /// Which group the right-click menu is about. `isSystem: false` because this
    /// view only draws a Mica-mode icon — `AppexPreviewPane` is the canvas in
    /// System mode, and it asks the same question with the other answer.
    private var contextGroup: IconLayerGroup {
        IconContextMenu.group(
            at: hoverPoint,
            settings: settings,
            displaySize: displaySize,
            isSystem: false
        )
    }

    /// Canvas-fixed space the badge drag is measured in.
    ///
    /// The drag must NOT be measured in the overlay's own `.local` space: the
    /// overlay is `.offset` by the very value the drag writes, so the space the
    /// pointer is measured in moves with it. That makes each frame's translation
    /// `Δpointer − Δoffset`, i.e. `t(n+1) = Δpointer − t(n)` — an oscillation that
    /// reads as a badge lagging the cursor and juddering back and forth.
    private static let dragSpace = "badgeDrag"

    /// Transparent circle at the badge position that captures drag gestures.
    /// Diameter matches the rendered badge, so the hover/drag region doesn't
    /// extend past the visible badge.
    private var badgeDragOverlay: some View {
        let badgeDiameter = BadgeGeometry.diameter(enclosureSize: enclosureSize, badgeScale: settings.badge.scale)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosureSize)

        return Circle()
            .fill(Color.clear)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .contentShape(Circle())
            .onHover { hovering in
                isHoveringBadge = hovering
                // Mid-drag the closed hand stays put even when the pointer
                // outruns the moving circle; onEnded restores the right cursor.
                if !isDragging {
                    setPushedCursor(hovering ? .openHand : nil)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.dragSpace))
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStart = CGSize(
                                width: settings.badge.offsetX,
                                height: settings.badge.offsetY
                            )
                            setPushedCursor(.closedHand)
                            // One undo for the whole drag, back to where it started.
                            // Named explicitly because the drag writes both offsets, so
                            // the change diff can only report a generic bulk edit.
                            continuousEdit.begin("Move Badge")
                        }
                        let normalizedDX = value.translation.width / enclosureSize
                        let normalizedDY = value.translation.height / enclosureSize
                        // Clamp to what the badge can actually use, not the raw
                        // badgeOffsetRange: BadgeGeometry keeps the badge inside
                        // the canvas, so writing an offset past that limit would
                        // bank up dead travel the user has to unwind before the
                        // badge moves back.
                        let range = BadgeGeometry.manualOffsetRange(for: settings, enclosureSize: enclosureSize)
                        settings.badge.offsetX = min(max(dragStart.width + normalizedDX, range.x.lowerBound), range.x.upperBound)
                        settings.badge.offsetY = min(max(dragStart.height + normalizedDY, range.y.lowerBound), range.y.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                        setPushedCursor(isHoveringBadge ? .openHand : nil)
                        dragStart = CGSize(
                            width: settings.badge.offsetX,
                            height: settings.badge.offsetY
                        )
                        continuousEdit.end()
                    }
            )
            // A `Circle().fill(.clear)` carrying a `DragGesture` is invisible to
            // VoiceOver, which is what made direct badge placement mouse-only.
            // Naming it makes the affordance audible; the hint names the arrow
            // keys, which are the only way to *use* it without a pointer and are
            // handled by `BadgeNudge` on the focused canvas rather than here —
            // this view is never the first responder.
            .accessibilityElement()
            .accessibilityLabel(IconAccessibilityDescription.badgeHandleLabel)
            .accessibilityValue(IconAccessibilityDescription.badgeHandleValue(for: settings))
            .accessibilityHint(IconAccessibilityDescription.badgeHandleHint)
            .onDisappear {
                // Badge hidden (or preview unmounted) while hovered/dragging —
                // don't leave our cursor on the global stack.
                isHoveringBadge = false
                isDragging = false
                setPushedCursor(nil)
            }
            .offset(offset)
    }

    /// Replaces whatever cursor this view previously pushed with `cursor`
    /// (nil = pop back to the default). Funneling every cursor change through
    /// here keeps NSCursor's global push/pop stack balanced regardless of the
    /// hover/drag/disappear event order.
    private func setPushedCursor(_ cursor: NSCursor?) {
        guard pushedCursor !== cursor else { return }
        if pushedCursor != nil { NSCursor.pop() }
        cursor?.push()
        pushedCursor = cursor
    }

    // MARK: - Drag and Drop

    /// - Returns: whether the drop was *accepted* — whether anything here can
    ///   read it. That is the only question `.onDrop` is asking, and it has to be
    ///   answered now: the import is asynchronous, so success is not known yet.
    ///   This used to `return true` unconditionally, telling the system a drop
    ///   had landed even when nothing could read it, and then `print()`ing the
    ///   failure where no user would see it. Now an unreadable drag is refused by
    ///   the system's own snap-back, and one we can read but fail to import
    ///   surfaces as an alert (B3).
    private func handleDrop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        guard let provider = providers.first(where: PreviewDrop.canRead) else { return false }

        // Resolved now, from the geometry as it was when the drop landed — not
        // inside the task below, which resumes after an arbitrary delay while a
        // file promise is fulfilled and could route by a badge that has moved.
        let target = PreviewDrop.target(at: location, settings: settings, displaySize: displaySize)
        let itemCount = providers.count

        Task { @MainActor in
            do {
                let imported = try await PreviewDrop.load(provider)
                // Padding compensation on (fill the frame) and shadow off come from
                // the background's own `apply`. The other two import defaults —
                // foreground hidden, corner radius off — are preferences, hence
                // `.fromPreferences()`.
                //
                // Deliberately does *not* call `onSelect`: that would point the
                // inspector at the changed layer and force the panel open, and a
                // drop is a content action rather than a navigation one. The
                // artwork appearing is the feedback.
                PreviewDrop.apply(imported, to: target, in: &settings, defaults: .fromPreferences())
                if itemCount > 1 {
                    reportUserMessage.report(
                        .onlyFirstDroppedItemUsed(count: itemCount, name: imported.sourceName)
                    )
                }
            } catch {
                reportUserMessage.report(.imageImportFailed(error))
            }
        }
        return true
    }
}

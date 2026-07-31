// Views/Preview/ScaledIconPreview.swift
//
// The interactive preview: the render view plus the badge drag overlay,
// click-to-select hit testing and drag-and-drop import. Split out of
// ContentView.swift on 2026-07-28 — CLAUDE.md had to write "ScaledIconPreview
// (in ContentView.swift)" to help anyone find it.
//
// The pure render view it wraps is IconContentView; per CLAUDE.md, gestures and
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

    /// So a badge drag is one undo step rather than one per frame.
    @Environment(\.continuousEdit) private var continuousEdit

    @State private var dragStart: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var isHoveringBadge: Bool = false
    /// The single cursor this view currently has on NSCursor's stack, if any.
    @State private var pushedCursor: NSCursor? = nil

    /// Enclosure size at the current display scale
    private var enclosureSize: CGFloat {
        displaySize - 2 * (25 * displaySize / 256) // backgroundInset * scaleFactor
    }

    var body: some View {
        ZStack {
            IconContentView(settings: settings, displaySize: displaySize, badgeAppexImage: badgeAppexImage)

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
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
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

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let urlData = data as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil)
                    else { return }
                    Task { @MainActor in
                        do {
                            let imported = try ImageImportService.importFromURL(url)
                            // Dropped files → icon background, padding compensation on
                            // (fill the frame) and shadow off by default.
                            settings.icon.background.apply(imported)
                        } catch {
                            print("Drop import failed: \(error.localizedDescription)")
                        }
                    }
                }
                return // Only process first item
            }
        }
    }
}

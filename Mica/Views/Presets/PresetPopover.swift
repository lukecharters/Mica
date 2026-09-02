// Views/Presets/PresetPopover.swift
import SwiftUI

/// A toolbar button that opens one scope's presets in a popover.
///
/// Each button is its own view so that it owns its popover's `isPresented` — a
/// `ToolbarContent` cannot hold state — and so that each popover has its own host.
/// A SwiftUI view gets one presentation of each kind; two `.popover`s on one view
/// would silently disable the first.
struct PresetsToolbarButton: View {
    let scope: PresetScope
    let iconSettings: IconSettings
    let onApply: (MicaPreset) -> Void
    let onSave: (PresetScope) -> Void
    let onDelete: (MicaPreset) -> Void
    /// Called when the popover opens, so the library is re-read at the moment a stale
    /// list would first be seen.
    let onPresetsAppear: () -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(scope.libraryTitle, systemImage: scope.toolbarSymbolName)
        }
        .help(scope.libraryTitle)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            PresetPopover(
                scope: scope,
                iconSettings: iconSettings,
                onApply: onApply,
                onSave: onSave,
                onDelete: onDelete
            )
            .onAppear(perform: onPresetsAppear)
        }
    }
}

/// One scope's presets: a title row with the `+`, the grid, and a footer that opens
/// the Presets window. The iWork insert popovers are the model — Shapes, Charts, Add a
/// Slide — down to the worded footer button that leads to the Content Hub.
///
/// **A click applies and leaves the popover up.** The iWork popovers dismiss on the
/// pick because inserting is one-shot; comparing three presets is not. Nothing here
/// dismisses on apply, and nothing should be added that does.
///
/// **Width and columns are fixed.** `PresetGridMetrics.width(forColumns:)` for
/// `columnCount` columns plus the scroller inset each side, so the popover states its
/// size rather than reflowing as it opens. The grid scrolls past `maxGridHeight`, about four rows,
/// so a long user library never runs the popover off the bottom of a small display.
///
/// The overlay scroller is kept in from the bezel and to the right of the tiles — the
/// Shapes popover's layout. How is a measured thing; see the scroll view in `body`.
struct PresetPopover: View {
    let scope: PresetScope
    let iconSettings: IconSettings
    let onApply: (MicaPreset) -> Void
    let onSave: (PresetScope) -> Void
    let onDelete: (MicaPreset) -> Void

    static let columnCount = 3
    static let maxGridHeight: CGFloat = 520

    /// The padded grid plus the scroller inset on each side — the scroll view's content
    /// plus its safe area, exactly. See the scroll view below for why that has to be exact.
    static var width: CGFloat {
        PresetGridMetrics.width(forColumns: columnCount) + 2 * PresetGridMetrics.scrollerInset
    }

    private let library = PresetLibrary.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var gridHeight: CGFloat = 0

    private var rows: [ResolvedPreset] {
        library.resolved.filter { $0.scope == scope }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(scope.libraryTitle)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                PresetSaveButton(scope: scope, iconSettings: iconSettings, onSave: onSave)
            }
            .padding(.horizontal, PresetGridMetrics.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ScrollView {
                PresetGrid(
                    rows: rows,
                    columns: PresetGridMetrics.fixedColumns(Self.columnCount),
                    onApply: onApply,
                    onDelete: onDelete
                )
                .frame(width: PresetGridMetrics.gridWidth(forColumns: Self.columnCount))
                .padding(.horizontal, PresetGridMetrics.horizontalPadding)
                .padding(.vertical, 8)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { gridHeight = $0 }
            }
            // **The scroll view's geometry in a popover, measured in the AX tree.** Its
            // `NSScrollView` is the larger of its frame and its content plus safe areas,
            // centred; its content is laid out from that area's leading edge and is
            // *not* inset by the safe area; its overlay scroller is inset by the trailing
            // safe area. So: the grid is pinned to `gridWidth` (a fixed-column
            // `LazyVGrid` asks for more), the content is padded symmetrically so the
            // tiles start where the heading does, the safe-area padding is what moves the
            // scroller in from the bezel, and `Self.width` is content plus both safe
            // areas so nothing overflows and nothing is centred off by half the excess.
            // Padding around the scroll view and `contentMargins(for: .scrollIndicators)`
            // were both measured widening the area past the frame instead.
            .safeAreaPadding(.horizontal, PresetGridMetrics.scrollerInset)
            // A `ScrollView` takes all the height it is offered; sized to its content
            // up to the cap instead, so a short list does not leave a blank well.
            .frame(height: min(gridHeight, Self.maxGridHeight))

            Button {
                dismiss()
                openWindow(id: PresetsWindow.id)
            } label: {
                Text("Show All Presets…")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.horizontal, PresetGridMetrics.horizontalPadding)
            .padding(.vertical, 12)
        }
        .frame(width: Self.width)
    }
}

#Preview {
    PresetPopover(
        scope: .icon,
        iconSettings: IconSettings(),
        onApply: { _ in },
        onSave: { _ in },
        onDelete: { _ in }
    )
}

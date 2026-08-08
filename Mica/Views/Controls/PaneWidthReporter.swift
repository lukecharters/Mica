// Views/Controls/PaneWidthReporter.swift
//
// The one thing that writes a pane width back. Item C5 of
// the Mac-conventions plan.
//
// `NavigationSplitView` and `.inspector` own their dividers and report nothing
// about them — there is no "the user resized this column" callback, and the
// `ideal:` they take is a proposal rather than a binding. So the pane's width is
// observed the only way it is available: from a `GeometryReader` behind the pane's
// own content.
//
// **`.background`, not `.overlay`.** A background is laid out to the content's
// size and takes no space or hits of its own; an overlay of a `GeometryReader`
// would sit over the pane and swallow clicks meant for it.

import SwiftUI

extension View {

    /// Persist this view's width as `pane`'s, whenever the user changes it.
    ///
    /// Attach to a split-view column's **content**, inside the column-width
    /// modifier, so the width observed is the width the column was given. See
    /// `PaneWidthPreferences` for why the two have to be the same number.
    func reportsPaneWidth(_ pane: PaneWidthPreferences.Pane) -> some View {
        modifier(PaneWidthReporter(pane: pane))
    }
}

private struct PaneWidthReporter: ViewModifier {
    let pane: PaneWidthPreferences.Pane

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                // `initial: false` on purpose. The first report is the width the
                // window opened at — which came *from* the preference — so acting
                // on it would be a write-back of a value that was just read, and
                // the tolerance would swallow it anyway. Only a change is a resize.
                Color.clear
                    .onChange(of: proxy.size.width, initial: false) { _, width in
                        PaneWidthPreferences.persist(observed: width, for: pane)
                    }
            }
            .accessibilityHidden(true)
        }
    }
}

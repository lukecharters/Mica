// PreviewZoomTests.swift
// The preview zoom ladder and the two steps along it — item B1 of
// the Mac-conventions plan, which added View ▸ Zoom In / Zoom Out.
//
// The load-bearing assertions are the off-ladder ones. `zoomLevel` is a plain
// `Double`, not an index, and `ContentView` already stores `0` as its Fit sentinel:
// an implementation that looked the current value up in `levels` would return nil
// for anything not on the ladder, which the menu reads as "disable both commands".
// Every on-ladder test below would still pass.

import Testing
import Foundation
@testable import Mica

@Suite("Preview zoom")
struct PreviewZoomTests {

    // MARK: - The ladder itself

    @Test("The levels ascend, with no duplicates")
    func levels_ascendUniquely() {
        // Both steps are "the first level greater than" / "the last level less
        // than", so an unsorted array would silently skip rungs.
        #expect(PreviewZoom.levels == PreviewZoom.levels.sorted())
        #expect(Set(PreviewZoom.levels).count == PreviewZoom.levels.count)
    }

    @Test("Actual Size is a rung, not a value beside the ladder")
    func actualSize_isOnTheLadder() {
        // Otherwise ⌘0 would land somewhere Zoom In and Zoom Out cannot step from,
        // and the toolbar's ZoomMenu would show no checkmark after using it.
        #expect(PreviewZoom.levels.contains(PreviewZoom.actualSize))
    }

    // MARK: - Stepping between rungs

    @Test("Zoom In moves to the next rung up")
    func zoomIn_takesTheNextRung() {
        for (index, level) in PreviewZoom.levels.enumerated().dropLast() {
            #expect(PreviewZoom.zoomedIn(from: level) == PreviewZoom.levels[index + 1])
        }
    }

    @Test("Zoom Out moves to the next rung down")
    func zoomOut_takesThePreviousRung() {
        for (index, level) in PreviewZoom.levels.enumerated().dropFirst() {
            #expect(PreviewZoom.zoomedOut(from: level) == PreviewZoom.levels[index - 1])
        }
    }

    @Test("Each end has no step past it")
    func theEnds_haveNoStep() {
        // This is what disables the menu items rather than letting them clamp
        // silently to the level already showing.
        #expect(PreviewZoom.zoomedIn(from: PreviewZoom.levels.last!) == nil)
        #expect(PreviewZoom.zoomedOut(from: PreviewZoom.levels.first!) == nil)
    }

    @Test("Stepping in and back out returns to the same rung")
    func inThenOut_isTheIdentity() {
        for level in PreviewZoom.levels.dropLast() {
            let up = PreviewZoom.zoomedIn(from: level)
            #expect(up.flatMap(PreviewZoom.zoomedOut(from:)) == level)
        }
    }

    // MARK: - Values that are not on the ladder

    @Test("The Fit sentinel steps up onto the ladder and has nowhere down")
    func fitSentinel_stepsOntoTheLadder() {
        // `ContentView` stores 0 for Fit. It is below every rung, so Zoom In takes
        // the lowest and Zoom Out is correctly unavailable — the behaviour an
        // index-based lookup would get wrong in both directions.
        #expect(PreviewZoom.zoomedIn(from: 0) == PreviewZoom.levels.first)
        #expect(PreviewZoom.zoomedOut(from: 0) == nil)
    }

    @Test("A value between two rungs steps to the rung either side",
          arguments: [(1.2, 1.5, 1.0), (0.3, 0.5, 0.25), (5.0, 8.0, 4.0)])
    func betweenRungs_stepsToEitherSide(_ from: Double, _ up: Double, _ down: Double) {
        #expect(PreviewZoom.zoomedIn(from: from) == up)
        #expect(PreviewZoom.zoomedOut(from: from) == down)
    }

    @Test("A value past the top of the ladder steps back down onto it")
    func aboveTheLadder_stepsBackDown() {
        #expect(PreviewZoom.zoomedIn(from: 16) == nil)
        #expect(PreviewZoom.zoomedOut(from: 16) == PreviewZoom.levels.last)
    }

    @Test("A negative zoom is treated as below the ladder, not as an error")
    func negativeZoom_isBelowTheLadder() {
        // Nothing writes one today; the point is that the step functions are total,
        // so a future control cannot make both menu items go quiet.
        #expect(PreviewZoom.zoomedIn(from: -1) == PreviewZoom.levels.first)
        #expect(PreviewZoom.zoomedOut(from: -1) == nil)
    }

    // MARK: - The continuous range, for pinch and ⌘-scroll

    @Test("The bounds are the ladder's own ends, not a second copy of them")
    func bounds_areTheLadderEnds() {
        // The whole reason `minimum`/`maximum` are computed rather than declared. If
        // someone adds a 16× rung, a pinch has to be able to reach it; this is the
        // assertion that fails if the two ever drift apart.
        #expect(PreviewZoom.minimum == PreviewZoom.levels.first)
        #expect(PreviewZoom.maximum == PreviewZoom.levels.last)
    }

    @Test("A scale inside the range is returned untouched",
          arguments: [0.25, 0.4, 1.0, 1.37, 4.9, 8.0])
    func clamped_passesThroughInRangeValues(_ zoom: Double) {
        // Off-ladder values are the intended output of a continuous gesture, so this
        // must not round to a rung. 1.37 staying 1.37 is the point.
        #expect(PreviewZoom.clamped(zoom) == zoom)
    }

    @Test("A scale past either end is pulled back to that end",
          arguments: [(12.0, 8.0), (8.001, 8.0), (0.1, 0.25), (0.0, 0.25), (-3.0, 0.25)])
    func clamped_pullsBackToTheEnds(_ zoom: Double, _ expected: Double) {
        #expect(PreviewZoom.clamped(zoom) == expected)
    }

    @Test("A clamped value is always a legal starting point for the step functions")
    func clamped_isAlwaysSteppable() {
        // The two surfaces have to agree: after any gesture, ⌘+ and ⌘− must still
        // behave. At the ends exactly one of them is unavailable, and in between both
        // work — which is the same contract the on-ladder tests above assert.
        for raw in [-5.0, 0.0, 0.3, 1.37, 6.5, 100.0] {
            let zoom = PreviewZoom.clamped(raw)
            #expect(zoom >= PreviewZoom.minimum)
            #expect(zoom <= PreviewZoom.maximum)
            let canStep = (PreviewZoom.zoomedIn(from: zoom) != nil)
                || (PreviewZoom.zoomedOut(from: zoom) != nil)
            #expect(canStep, "clamped \(raw) → \(zoom) left both zoom commands disabled")
        }
    }

    @Test("A non-finite scale falls back to Actual Size rather than sizing a frame with it")
    func clamped_rejectsNonFinite() {
        // `min`/`max` propagate NaN, and SwiftUI resolves a NaN frame to a zero-sized
        // view — the icon would vanish with nothing logged. No gesture produces one
        // today; this is the guard, so the assertion is what stops it being removed
        // as dead code.
        #expect(PreviewZoom.clamped(.nan) == PreviewZoom.actualSize)
        #expect(PreviewZoom.clamped(.infinity) == PreviewZoom.actualSize)
        #expect(PreviewZoom.clamped(-.infinity) == PreviewZoom.actualSize)
    }

    // MARK: - Anchoring the zoom under the pointer

    /// A 553pt pane, the width measured in the running app with both side panes open.
    private let pane: CGFloat = 553

    @Test("A point under the pointer stays under it while the icon exceeds the viewport")
    func anchoredOffset_holdsThePointUnderThePointer() {
        // The icon is larger than the pane, so there is no centring padding either side
        // and the transform is a plain scale. Anchor 100pt in, zoom by 1.5: the content
        // point at 100 moves to 150, so the offset must become 50 to put it back.
        let offset = PreviewZoom.anchoredOffset(
            offset: 0, anchor: 100, viewportExtent: pane, iconExtent: 1024, factor: 1.5
        )
        #expect(offset == 50)
        // …and the invariant that says it, stated directly.
        let contentPointAfter = 100 * 1.5
        #expect(contentPointAfter - offset == 100)
    }

    @Test("It composes: two zooms from an already-scrolled position still hold the point")
    func anchoredOffset_composesFromAScrolledPosition() {
        var offset: CGFloat = 0
        let anchor: CGFloat = 220
        var icon: CGFloat = 1024
        // The content position of the anchored point, tracked independently.
        var point = offset + anchor
        for factor in [1.155, 1.155, 0.8] {
            offset = PreviewZoom.anchoredOffset(
                offset: offset, anchor: anchor, viewportExtent: pane, iconExtent: icon, factor: factor
            )
            point *= factor
            icon *= factor
            #expect(abs((point - offset) - anchor) < 0.001,
                    "the anchored point drifted off the pointer")
        }
    }

    @Test("Crossing the fits-the-pane boundary keeps the right feature under the pointer")
    func anchoredOffset_accountsForTheCentringPadding() {
        // **This is the case that shipped wrong**, measured at ~25pt of drift on screen.
        // At 512 the icon is smaller than the 553pt pane, so it is centred with 20.5pt
        // either side; at 512 × 1.21 = 620 it is larger and has none. So content
        // positions do *not* all scale by the factor across this step.
        //
        // The discriminating assertion has to name a point on the **icon**, because the
        // naive formula is perfectly self-consistent about *content* positions — it holds
        // a content point and thereby moves the artwork under the pointer.
        let icon: CGFloat = 512
        let factor = 1.21
        let paddingBefore = (pane - icon) / 2          // 20.5
        let feature: CGFloat = 379.5                    // somewhere on the icon
        let anchor = paddingBefore + feature            // the pointer sits on it: 400

        let offset = PreviewZoom.anchoredOffset(
            offset: 0, anchor: anchor, viewportExtent: pane, iconExtent: icon, factor: factor
        )
        // After the zoom there is no padding, so the feature's content position is just
        // its icon position scaled.
        #expect(abs((feature * factor - offset) - anchor) < 0.001,
                "the feature under the pointer should not have moved")

        // The naive formula, for contrast: it drifts by the padding it ignored.
        let naive = max(0, anchor * factor - anchor)
        #expect(abs((feature * factor - naive) - anchor) > 20,
                "the naive formula should visibly move the feature")
    }

    @Test("An icon smaller than the viewport on both sides of the zoom never scrolls")
    func anchoredOffset_staysAtZeroWhileTheIconFits() {
        // 200 → 240 in a 553pt pane: centred throughout, so the scrollable range is
        // empty and the answer must be zero whatever the pointer did.
        #expect(PreviewZoom.anchoredOffset(
            offset: 0, anchor: 300, viewportExtent: pane, iconExtent: 200, factor: 1.2
        ) == 0)
    }

    @Test("The result never goes below the leading edge")
    func anchoredOffset_hasAFloorOfZero() {
        // Zooming 1024 → 512 in a 553pt pane ends up fitting, so there is nothing to
        // scroll; and even where it does not fit, holding a point this close to the
        // leading edge would need a negative offset. Either way the floor applies and
        // the point slides, which beats scrolling past the content.
        #expect(PreviewZoom.anchoredOffset(
            offset: 0, anchor: 10, viewportExtent: pane, iconExtent: 1024, factor: 0.5
        ) == 0)
    }

    @Test("A non-finite or non-positive factor cannot corrupt the offset")
    func anchoredOffset_rejectsNonsenseFactors() {
        for factor in [Double.nan, .infinity, 0, -2] {
            let offset = PreviewZoom.anchoredOffset(
                offset: 120, anchor: 100, viewportExtent: pane, iconExtent: 1024, factor: factor
            )
            #expect(offset == 120, "a bad factor should leave the offset alone, got \(offset)")
        }
    }

    @Test("Scrolling up and back down by the same amount is the identity")
    func exponentialFactors_areSymmetric() {
        // Why `PreviewScrollZoomMonitor` uses `exp(delta × k)` rather than
        // `1 + delta × k`: the additive form drifts, because ×1.1 then ×0.9 is ×0.99.
        // Modelled here rather than reaching into the monitor, which needs a window.
        let k = 0.004
        for delta in [1.0, 12.0, 40.0] {
            let roundTrip = exp(delta * k) * exp(-delta * k)
            #expect(abs(roundTrip - 1.0) < 1e-12)
        }
    }
}

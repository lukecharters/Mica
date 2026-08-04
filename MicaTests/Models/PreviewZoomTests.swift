// PreviewZoomTests.swift
// The preview zoom ladder and the two steps along it — item B1 of
// docs/plans/mac-conventions.md, which added View ▸ Zoom In / Zoom Out.
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
}

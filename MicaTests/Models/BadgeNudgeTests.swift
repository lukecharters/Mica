// BadgeNudgeTests.swift
//
// Arrow-key badge movement — the keyboard equivalent of the canvas drag. C1 of
// `docs/plans/mac-conventions.md`.
//
// These test the *decision*, which is the only part a test can reach: the
// `.onMoveCommand` that delivers a direction lives in `ContentView.body`, and
// the reason `BadgeNudge` is a pure function at all is so that direction →
// offset can be pinned without a window. Same shape as `SymbolPickerKeyTests`.
import SwiftUI
import Testing
@testable import Mica

@Suite("Badge arrow-key nudge")
struct BadgeNudgeTests {

    /// A badge that is visible and sitting exactly on its anchor.
    private func visibleBadge() -> IconSettings {
        var settings = IconSettings()
        settings.badge.foreground.isHidden = false
        return settings
    }

    // MARK: - Direction

    @Test("Left and right move X; up and down move Y")
    func directionsMoveTheRightAxis() {
        var settings = visibleBadge()

        #expect(BadgeNudge.apply(.right, to: &settings))
        #expect(settings.badge.offsetX == BadgeNudge.step)
        #expect(settings.badge.offsetY == 0)

        #expect(BadgeNudge.apply(.down, to: &settings))
        #expect(settings.badge.offsetX == BadgeNudge.step)
        #expect(settings.badge.offsetY == BadgeNudge.step)

        #expect(BadgeNudge.apply(.left, to: &settings))
        #expect(settings.badge.offsetX == 0)

        #expect(BadgeNudge.apply(.up, to: &settings))
        #expect(settings.badge.offsetY == 0)
    }

    /// The canvas's y grows downward, so Up is negative. Getting this backwards
    /// would still move the badge, and would still pass a test that only checked
    /// "the value changed".
    @Test("Up is negative y, matching the stored offset's own direction")
    func upIsNegativeY() {
        var settings = visibleBadge()
        BadgeNudge.apply(.up, to: &settings)
        #expect(settings.badge.offsetY < 0)

        var down = visibleBadge()
        BadgeNudge.apply(.down, to: &down)
        #expect(down.badge.offsetY > 0)
    }

    // MARK: - The step

    /// The nudge and the inspector's sliders have to move the badge the same
    /// distance, or "nudge, then drag the slider" jumps.
    @Test("One press is one slider step")
    func stepMatchesTheSliders() {
        #expect(BadgeNudge.step == 0.01)
    }

    /// Twenty presses of 0.01 is 0.2, not 0.19999999999999998. The offset is
    /// shown as a rounded percentage, so drift is invisible until it crosses a
    /// half — and `IconSettings` is `Equatable`, so it also decides whether undo
    /// sees an edit at all.
    ///
    /// Measured **inward**, deliberately. At the default badge scale the outward
    /// range is only ~6.4% wide — the shadow allowance takes the rest of the
    /// distance to the canvas edge — so twenty presses to the right stop at the
    /// clamp and would test that instead. Inward there is ~79% of room.
    @Test("Repeated presses do not accumulate floating-point drift")
    func repeatedPressesDoNotDrift() {
        var settings = visibleBadge()
        for _ in 0..<20 { BadgeNudge.apply(.left, to: &settings) }
        #expect(settings.badge.offsetX == -0.2)

        for _ in 0..<20 { BadgeNudge.apply(.right, to: &settings) }
        #expect(settings.badge.offsetX == 0)
    }

    /// The number the test above sidesteps, pinned rather than left as a surprise:
    /// a default badge sits close enough to the corner that it can only be nudged
    /// a few percent further out before `BadgeGeometry`'s clamp stops it. That is
    /// the canvas staying exactly the size that was requested, and it is why the
    /// inspector's sliders can read 0% while the badge sits inward.
    @Test("A default badge has only a few percent of outward travel")
    func defaultBadgeHasLittleOutwardTravel() {
        let range = BadgeGeometry.manualOffsetRange(
            for: visibleBadge(),
            enclosureSize: BadgeNudge.referenceEnclosureSize
        )
        #expect(range.x.upperBound > 0)
        #expect(range.x.upperBound < 0.1)
        #expect(range.x.lowerBound < -0.5)
    }

    // MARK: - The clamp

    /// The badge cannot be walked off the canvas, on the same rule the drag
    /// follows — `BadgeGeometry` is what keeps an export exactly its requested
    /// size, so a badge that would spill out moves inward instead.
    @Test("Presses stop at the limit rather than banking up dead travel")
    func pressesStopAtTheLimit() {
        var settings = visibleBadge()
        let range = BadgeGeometry.manualOffsetRange(
            for: settings,
            enclosureSize: BadgeNudge.referenceEnclosureSize
        )

        // Far more presses than the range is wide.
        for _ in 0..<500 { BadgeNudge.apply(.right, to: &settings) }
        #expect(settings.badge.offsetX == range.x.upperBound)

        for _ in 0..<1000 { BadgeNudge.apply(.left, to: &settings) }
        #expect(settings.badge.offsetX == range.x.lowerBound)
    }

    /// The clamp is asymmetric vertically — the badge's shadow falls downward, so
    /// it may sit closer to the top edge than the bottom. A nudge that used one
    /// limit for both would be wrong in one direction only.
    @Test("The vertical limits differ, because the shadow falls downward")
    func verticalLimitsAreAsymmetric() {
        var settings = visibleBadge()
        settings.badge.position = .topRight
        settings.badge.scale = 1.4

        let range = BadgeGeometry.manualOffsetRange(
            for: settings,
            enclosureSize: BadgeNudge.referenceEnclosureSize
        )
        #expect(abs(range.y.lowerBound) != abs(range.y.upperBound))

        var up = settings
        for _ in 0..<500 { BadgeNudge.apply(.up, to: &up) }
        #expect(up.badge.offsetY == range.y.lowerBound)

        var down = settings
        for _ in 0..<500 { BadgeNudge.apply(.down, to: &down) }
        #expect(down.badge.offsetY == range.y.upperBound)
    }

    /// `BadgeNudge` computes its limits against a fixed reference enclosure
    /// because it cannot learn the preview's display size — in System mode that
    /// number is computed inside `AppexPreviewPane` and never leaves it. That is
    /// only sound while `manualOffsetRange` is scale-invariant, which is a
    /// property of the arithmetic rather than a promise. This is what turns a
    /// future non-proportional term into a failing test rather than a badge that
    /// moves a different distance at each zoom level.
    @Test("The nudge is independent of the enclosure size", arguments: [64.0, 206.0, 512.0, 2048.0])
    func nudgeIsIndependentOfTheEnclosureSize(enclosure: Double) {
        var settings = visibleBadge()
        settings.badge.scale = 1.6 // past ~1.09, where the clamp actually bites

        let reference = BadgeGeometry.manualOffsetRange(
            for: settings,
            enclosureSize: BadgeNudge.referenceEnclosureSize
        )
        let other = BadgeGeometry.manualOffsetRange(for: settings, enclosureSize: enclosure)

        #expect(abs(reference.x.lowerBound - other.x.lowerBound) < 1e-9)
        #expect(abs(reference.x.upperBound - other.x.upperBound) < 1e-9)
        #expect(abs(reference.y.lowerBound - other.y.lowerBound) < 1e-9)
        #expect(abs(reference.y.upperBound - other.y.upperBound) < 1e-9)
    }

    // MARK: - When there is nothing to move

    /// With no badge on the icon the arrows must leave the settings alone —
    /// otherwise they would silently write an offset onto an invisible object,
    /// and the user's only feedback would be an undo entry appearing.
    @Test("An invisible badge is not moved")
    func invisibleBadgeIsNotMoved() {
        var settings = IconSettings() // badge foreground and background both hidden
        #expect(!settings.badge.isVisible)

        let before = settings
        for direction in [MoveCommandDirection.up, .down, .left, .right] {
            #expect(!BadgeNudge.apply(direction, to: &settings))
        }
        #expect(settings == before)
    }

    /// A badge whose *foreground* is hidden by an image import is still a badge —
    /// the background draws it — so it still moves. This is the case the
    /// visibility rule gets wrong if it reads a layer instead of the group.
    @Test("A badge visible only through its background still moves")
    func badgeVisibleOnlyThroughItsBackgroundStillMoves() {
        var settings = IconSettings()
        settings.badge.background.isHidden = false
        #expect(settings.badge.foreground.isHidden)
        #expect(settings.badge.isVisible)

        #expect(BadgeNudge.apply(.right, to: &settings))
        #expect(settings.badge.offsetX == BadgeNudge.step)
    }
}

// App/BadgeNudge.swift
//
// Arrow-key badge movement — the keyboard equivalent of the canvas drag, which
// was mouse-only. Item C1 of the Mac-conventions plan; the review filed it
// under *Accessibility* as "no arrow-key nudge for badge position", and it is
// reached through `.onMoveCommand` on the focused canvas in `ContentView`.
//
// A pure function over `IconSettings` rather than a closure inside that view,
// for the reason `SymbolPickerKey` is one: a key's *meaning* is testable and a
// modifier applied in a `body` is not. `ContentView.body` also sits at the
// type-checker's ceiling and has been pushed over it four times, so the handler
// arrives there as a method reference and does its thinking here.
//
// The placement itself still belongs to `BadgeGeometry` — the project notes' rule that
// new badge placement logic goes there and not to a call site. This adds no
// geometry; it steps a stored offset and asks that enum where the limits are.
import SwiftUI

/// One arrow press, applied to the badge's manual offset.
enum BadgeNudge {

    /// How far one press moves the badge, in stored manual-offset units
    /// (fractions of the enclosure). Deliberately the **same 0.01 the inspector's
    /// two offset sliders step by**, so a press and an arrow-key slider tick move
    /// the badge by the same distance and the sliders' percent readout advances
    /// by exactly one.
    static let step: Double = 0.01

    /// Apply one press, clamped to what the badge can actually use.
    ///
    /// - Returns: whether anything moved, so the caller can leave the key alone
    ///   when there is no badge to move. `.onMoveCommand` discards it; the tests
    ///   do not, and neither would a second caller.
    @discardableResult
    static func apply(_ direction: MoveCommandDirection, to settings: inout IconSettings) -> Bool {
        guard settings.badge.isVisible else { return false }

        let range = BadgeGeometry.manualOffsetRange(
            for: settings,
            enclosureSize: referenceEnclosureSize
        )

        switch direction {
        case .left:
            settings.badge.offsetX = stepped(settings.badge.offsetX, by: -step, into: range.x)
        case .right:
            settings.badge.offsetX = stepped(settings.badge.offsetX, by: step, into: range.x)
        case .up:
            // SwiftUI's canvas y grows downward, matching how the offset is
            // stored and how `BadgeGeometry.anchorSigns` reads a corner.
            settings.badge.offsetY = stepped(settings.badge.offsetY, by: -step, into: range.y)
        case .down:
            settings.badge.offsetY = stepped(settings.badge.offsetY, by: step, into: range.y)
        @unknown default:
            return false
        }
        return true
    }

    /// The enclosure the limits are computed against.
    ///
    /// **Any positive value gives the same answer**, and that is a property of
    /// `manualOffsetRange` rather than a coincidence worth relying on quietly:
    /// every term in it — the half-canvas, the badge extents, the anchor — is
    /// proportional to the enclosure, and the result is divided by it again. So
    /// the nudge does not have to know the preview's display size, which it could
    /// not learn anyway: in System mode that size is computed inside
    /// `AppexPreviewPane` and never leaves it. 256 is the reference canvas every
    /// layout constant in `IconContentView` is tuned against.
    /// `BadgeNudgeTests.nudgeIsIndependentOfTheEnclosureSize` pins the invariance,
    /// so a future non-proportional term fails a test rather than moving the badge
    /// a different distance at each zoom level.
    static let referenceEnclosureSize: CGFloat = 256

    /// Step, round, then clamp.
    ///
    /// Rounding before the clamp, not after, so a limit that is not a round
    /// number survives it — the clamp is the thing that must be exact, the step
    /// only has to stay off 0.30000000000000004 as presses accumulate.
    ///
    /// The clamp can *move a stored offset that was already outside the range*,
    /// and that is intended: past `badge.scale ≈ 1.09` the legal range no longer
    /// contains zero, so an untouched 0% is out of bounds. The canvas drag does
    /// the same on its first frame. What neither does is re-clamp on its own —
    /// the project notes' rule that stored offsets are clamped by live gestures only,
    /// or resizing a badge would silently rewrite a user's 0% into −6%.
    private static func stepped(_ value: Double, by delta: Double, into range: ClosedRange<Double>) -> Double {
        let moved = ((value + delta) * 10_000).rounded() / 10_000
        return min(max(moved, range.lowerBound), range.upperBound)
    }
}

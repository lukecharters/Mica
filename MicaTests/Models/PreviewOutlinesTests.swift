// MicaTests/Models/PreviewOutlinesTests.swift
// The three pure decisions behind the preview's two-weight outline: which
// outlines to draw for a given selection + hover, how heavy each weight is, and
// how often pointer motion is allowed to restart the fade.
//
// All three exist as values rather than as view state because none of them can be
// read back off the screen: an outline drawn at the wrong weight, a hover stroke
// doubled over the selection, or a fade that restarts sixty times a second all
// look approximately right in a screenshot. The behaviour they encode was measured
// against Icon Composer — see
// `docs/plans/hover-and-selection-outlines-2026-08-22.md` §1.

import Foundation
import Testing
@testable import Mica

@Suite("Preview outlines", .tags(.unit))
struct PreviewOutlinesTests {

    // MARK: - What gets drawn

    @Test("Nothing selected and nothing hovered draws nothing")
    func neither() {
        #expect(PreviewOutlines.resolve(selected: nil, hovered: nil).isEmpty)
    }

    @Test("A selection with no hover draws one selected outline")
    func selectedOnly() {
        let outlines = PreviewOutlines.resolve(selected: .iconForeground, hovered: nil)
        #expect(outlines == [PreviewOutline(selection: .iconForeground, emphasis: .selected)])
    }

    /// Only reachable where the gates return nil for the selection but not for the
    /// hover — but the pair is independent, so the case has to answer for itself
    /// rather than by "Mica always has a selection".
    @Test("A hover with no selection draws one hovered outline")
    func hoveredOnly() {
        let outlines = PreviewOutlines.resolve(selected: nil, hovered: .badge)
        #expect(outlines == [PreviewOutline(selection: .badge, emphasis: .hovered)])
    }

    /// The order is the whole point: the hovered stroke is drawn *first* so the
    /// selected one paints over it wherever the two shapes overlap — a badge glyph
    /// inside the badge, a foreground box inside the chiclet.
    @Test("Hovering another layer draws both, hovered underneath")
    func bothWithHoveredFirst() {
        let outlines = PreviewOutlines.resolve(selected: .iconBackground, hovered: .badgeForeground)
        #expect(outlines == [
            PreviewOutline(selection: .badgeForeground, emphasis: .hovered),
            PreviewOutline(selection: .iconBackground, emphasis: .selected)
        ])
    }

    /// Measured in Icon Composer: hovering the selected layer shows the selected
    /// weight alone. Two concentric strokes on one shape read as a doubled border
    /// rather than as two states.
    @Test(
        "Hovering the selected layer collapses to the selected weight",
        arguments: [
            PreviewSelection.iconForeground,
            .iconBackground,
            .icon,
            .badgeForeground,
            .badgeBackground,
            .badge
        ]
    )
    func hoverOnSelectionCollapses(selection: PreviewSelection) {
        let outlines = PreviewOutlines.resolve(selected: selection, hovered: selection)
        #expect(outlines == [PreviewOutline(selection: selection, emphasis: .selected)])
    }

    // MARK: - How heavy

    /// The figure the measurement produced: ~6pt of stroke where the canvas is
    /// ~512pt. Mica drew 4pt there while there was only one weight.
    @Test("The selected stroke matches the measured width")
    func measuredSelectedWidth() {
        #expect(PreviewOutlineEmphasis.selected.lineWidth(displaySize: 512) == 6)
        #expect(PreviewOutlineEmphasis.selected.lineWidth(displaySize: 256) == 3)
    }

    /// **The invariant, not an incidental ratio.** The clamp is applied to the
    /// selected width and the hover halved after it, precisely so this holds at the
    /// extremes too — clamping the two independently would make them equal at every
    /// size past the ceiling, which is a hover that looks selected.
    @Test(
        "A hover is exactly half a selection at every size",
        arguments: [16, 64, 128, 256, 512, 1024, 4096] as [CGFloat]
    )
    func hoverIsHalf(displaySize: CGFloat) {
        let selected = PreviewOutlineEmphasis.selected.lineWidth(displaySize: displaySize)
        let hovered = PreviewOutlineEmphasis.hovered.lineWidth(displaySize: displaySize)
        #expect(hovered == selected / 2)
    }

    @Test("The selected stroke clamps at both ends")
    func widthClamps() {
        #expect(PreviewOutlineEmphasis.selected.lineWidth(displaySize: 1) == PreviewOutlineEmphasis.minSelectedWidth)
        #expect(PreviewOutlineEmphasis.selected.lineWidth(displaySize: 100_000) == PreviewOutlineEmphasis.maxSelectedWidth)
    }

    @Test("Wider canvases never draw a thinner stroke")
    func widthIsMonotonic() {
        let sizes: [CGFloat] = [16, 64, 128, 256, 512, 1024, 4096]
        for emphasis in PreviewOutlineEmphasis.allCases {
            let widths = sizes.map { emphasis.lineWidth(displaySize: $0) }
            #expect(widths == widths.sorted())
        }
    }

    /// **The colours are the two weights' other difference, and the important one.**
    /// A translucent tint of the accent would be the same hue as the selection and
    /// would take the colour of whatever it sat on — measured against Mica's default
    /// blue icon, an accent stroke at 0.3 moved the chiclet's pixels by (−4, −7, −2),
    /// i.e. not at all. The hover is a solid light blue instead, Icon Composer's.
    @Test("The two weights are different colours, and the hover is solid")
    func strokeColours() throws {
        #expect(PreviewOutlineEmphasis.selected.strokeColor == .accentColor)
        #expect(PreviewOutlineEmphasis.hovered.strokeColor != PreviewOutlineEmphasis.selected.strokeColor)

        // Resolved through ColorParser, never `NSColor(someColor)` — SwiftUI's
        // bridge memoises through an unsynchronised process-global map and
        // segfaults under concurrent use. See CLAUDE.md.
        let hover = try #require(
            ColorParser.nsColor(from: PreviewOutlineEmphasis.hovered.strokeColor)
                .usingColorSpace(.sRGB)
        )
        let expected = PreviewOutlineEmphasis.hoverColorComponents
        #expect(abs(hover.redComponent * 255 - expected.red) < 1)
        #expect(abs(hover.greenComponent * 255 - expected.green) < 1)
        #expect(abs(hover.blueComponent * 255 - expected.blue) < 1)
        // Solid: the failure this catches is 0-255 components read as 0-1, which
        // would give a near-black stroke, and an alpha slipped back in.
        #expect(hover.alphaComponent == 1)
    }

    // MARK: - How often the fade restarts

    /// The case that matters most: the pointer has been still, the outlines have
    /// faded, and the *first* sample of new motion is the one that has to bring
    /// them back. A throttle that swallowed it would make the outlines appear only
    /// after a quarter-second of movement.
    @Test("The first motion always wakes")
    func firstMotionWakes() {
        var activity = PreviewOutlineActivity()
        // Hoisted out of `#expect`: the macro evaluates its expression inside a
        // closure, so a `mutating` call cannot be written in one.
        let firstEver = activity.noteMotion(now: 0)
        let firstAfterAWhile = activity.noteMotion(now: 1_000_000)
        #expect(firstEver)
        #expect(firstAfterAWhile)
    }

    @Test("Motion inside the window is swallowed, and the window's edge is not")
    func throttleWindow() {
        var activity = PreviewOutlineActivity()
        let opening = activity.noteMotion(now: 10)
        let sameInstant = activity.noteMotion(now: 10)
        let halfway = activity.noteMotion(now: 10 + PreviewOutlineActivity.throttle / 2)
        let onTheEdge = activity.noteMotion(now: 10 + PreviewOutlineActivity.throttle)
        #expect(opening)
        #expect(!sameInstant)
        #expect(!halfway)
        #expect(onTheEdge)
    }

    /// What `.onContinuousHover` actually delivers: a second of 60Hz samples. The
    /// point of the throttle is that this restarts the fade a handful of times
    /// rather than sixty, while never leaving the outlines to fade mid-movement —
    /// so the count is bounded on both sides.
    @Test("A second of 60Hz motion wakes a handful of times")
    func continuousMotionIsBounded() {
        var activity = PreviewOutlineActivity()
        var wakes = 0
        for frame in 0..<60 where activity.noteMotion(now: Double(frame) / 60) {
            wakes += 1
        }
        // One at t=0 and one per throttle window after it: 0, 0.25, 0.5, 0.75.
        #expect(wakes == Int(1 / PreviewOutlineActivity.throttle))
    }

    /// A timestamp going backwards can only mean the caller changed clocks. Waking
    /// is the safe reading: the alternative is outlines stuck faded until the
    /// difference elapses.
    @Test("A backwards clock wakes rather than locking out")
    func backwardsClockWakes() {
        var activity = PreviewOutlineActivity()
        let forwards = activity.noteMotion(now: 500)
        let backwards = activity.noteMotion(now: 1)
        #expect(forwards)
        #expect(backwards)
    }
}

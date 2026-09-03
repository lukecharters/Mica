// MicaTests/Models/BadgeCornerArrowTests.swift
//
// The arrow a badge preset's thumbnail draws in the badge's corner.

import AppKit
import SwiftUI
import Testing
@testable import Mica

@Suite("Badge thumbnail corner arrows")
struct BadgeCornerArrowTests {

    @Test("Every corner's arrow resolves as an SF Symbol")
    func everyArrowResolves() {
        // A misspelled SF Symbol name draws nothing at all, with no error, so the
        // thumbnail would simply say no corner.
        for position in BadgePosition.allCases {
            #expect(
                NSImage(systemSymbolName: position.cornerArrowSymbolName,
                        accessibilityDescription: nil) != nil,
                Comment(rawValue: "\(position.cornerArrowSymbolName) is not an SF Symbol")
            )
        }
    }

    @Test("No two corners share an arrow or an alignment")
    func cornersAreDistinct() {
        let arrows = BadgePosition.allCases.map(\.cornerArrowSymbolName)
        #expect(Set(arrows).count == arrows.count, Comment(rawValue: "\(arrows)"))
        let alignments = BadgePosition.allCases.map(\.cornerAlignment)
        #expect(Set(alignments.map { "\($0)" }).count == alignments.count)
    }

    @Test("The arrow points into the corner it sits in", arguments: BadgePosition.allCases)
    func arrowPointsIntoItsCorner(position: BadgePosition) {
        let arrow = position.cornerArrowSymbolName
        let alignment = position.cornerAlignment
        let up = arrow.contains(".up.")
        let left = arrow.hasSuffix(".left")
        #expect(up == (alignment.vertical == .top),
                Comment(rawValue: "\(arrow) sits at \(alignment)"))
        #expect(left == (alignment.horizontal == .leading),
                Comment(rawValue: "\(arrow) sits at \(alignment)"))
    }
}

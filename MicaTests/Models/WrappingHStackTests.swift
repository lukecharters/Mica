// MicaTests/Models/WrappingHStackTests.swift
// The row-breaking rule behind `WrappingHStack`, checked on plain sizes so the
// layout's only untested part is handing SwiftUI the frames it computed.

import CoreGraphics
import Testing
@testable import Mica

@Suite("Wrapping HStack arrangement", .tags(.unit))
struct WrappingHStackTests {

    private func arrange(_ sizes: [CGSize], in width: CGFloat) -> WrappingHStack.Arrangement {
        WrappingHStack.arrange(sizes: sizes, in: width, horizontalSpacing: 4, verticalSpacing: 6)
    }

    @Test("Subviews that fit stay on one row, separated by the horizontal spacing")
    func singleRow() {
        let sizes = [CGSize(width: 30, height: 10), CGSize(width: 40, height: 12), CGSize(width: 20, height: 8)]
        let result = arrange(sizes, in: 200)
        #expect(result.frames.map(\.minX) == [0, 34, 78])
        #expect(result.frames.allSatisfy { $0.minY == 0 })
        let expectedWidth: CGFloat = 30 + 4 + 40 + 4 + 20
        #expect(result.size == CGSize(width: expectedWidth, height: 12))
    }

    @Test("The first subview that would cross the width starts a new row")
    func wrapsAtWidth() {
        let sizes = Array(repeating: CGSize(width: 40, height: 10), count: 5)
        let result = arrange(sizes, in: 130)
        #expect(result.frames.map(\.minX) == [0, 44, 88, 0, 44])
        #expect(result.frames.map(\.minY) == [0, 0, 0, 16, 16])
        let expectedHeight: CGFloat = 10 + 6 + 10
        #expect(result.size == CGSize(width: 128, height: expectedHeight))
    }

    @Test("A row is as tall as its tallest subview, and the next row starts below it")
    func rowHeightIsTallestMember() {
        let sizes = [CGSize(width: 50, height: 10), CGSize(width: 50, height: 30), CGSize(width: 50, height: 10)]
        let result = arrange(sizes, in: 110)
        #expect(result.frames[2].minY == 36)
        #expect(result.size.height == 46)
    }

    @Test("A subview wider than the width takes a row alone and widens the result")
    func oversizedSubviewOverflows() {
        let sizes = [CGSize(width: 20, height: 10), CGSize(width: 150, height: 10), CGSize(width: 20, height: 10)]
        let result = arrange(sizes, in: 100)
        #expect(result.frames.map(\.minY) == [0, 16, 32])
        #expect(result.frames.allSatisfy { $0.minX == 0 })
        #expect(result.size.width == 150)
    }

    @Test("Nothing to lay out is a zero-sized arrangement")
    func emptyInput() {
        let result = arrange([], in: 100)
        #expect(result.frames.isEmpty)
        #expect(result.size == .zero)
    }

    @Test("An unbounded width never wraps")
    func infiniteWidthIsOneRow() {
        let sizes = Array(repeating: CGSize(width: 40, height: 10), count: 20)
        let result = arrange(sizes, in: .infinity)
        #expect(result.frames.allSatisfy { $0.minY == 0 })
        #expect(result.size.height == 10)
    }
}

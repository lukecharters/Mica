// SymbolGridNavigationTests.swift
import Testing
@testable import Mica

@Suite("Symbol grid keyboard navigation")
struct SymbolGridNavigationTests {

    // MARK: - Entering the grid

    @Test("Any arrow with no cursor enters at the first symbol")
    func noCursor_entersAtFirst() {
        for direction in [SymbolGridNavigation.Direction.up, .down, .left, .right] {
            #expect(
                SymbolGridNavigation.destination(from: nil, moving: direction, itemCount: 30) == 0,
                "\(direction) should enter the grid"
            )
        }
    }

    @Test("An out-of-range cursor is treated as no cursor")
    func staleCursor_entersAtFirst() {
        #expect(SymbolGridNavigation.destination(from: 99, moving: .down, itemCount: 30) == 0)
        #expect(SymbolGridNavigation.destination(from: -1, moving: .right, itemCount: 30) == 0)
    }

    @Test("An empty grid has nowhere to move")
    func emptyGrid_refusesEveryMove() {
        for direction in [SymbolGridNavigation.Direction.up, .down, .left, .right] {
            #expect(SymbolGridNavigation.destination(from: nil, moving: direction, itemCount: 0) == nil)
            #expect(SymbolGridNavigation.destination(from: 0, moving: direction, itemCount: 0) == nil)
        }
    }

    // MARK: - Horizontal

    @Test("Left and right step by one")
    func horizontal_stepsByOne() {
        #expect(SymbolGridNavigation.destination(from: 7, moving: .right, itemCount: 30) == 8)
        #expect(SymbolGridNavigation.destination(from: 7, moving: .left, itemCount: 30) == 6)
    }

    @Test("Horizontal movement runs across row ends, as a Finder icon view does")
    func horizontal_crossesRows() {
        // Column count 6, so index 5 is the last cell of the first row.
        #expect(SymbolGridNavigation.destination(from: 5, moving: .right, itemCount: 30) == 6)
        #expect(SymbolGridNavigation.destination(from: 6, moving: .left, itemCount: 30) == 5)
    }

    @Test("The two ends of the list stop")
    func horizontal_stopsAtTheEnds() {
        #expect(SymbolGridNavigation.destination(from: 0, moving: .left, itemCount: 30) == nil)
        #expect(SymbolGridNavigation.destination(from: 29, moving: .right, itemCount: 30) == nil)
    }

    // MARK: - Vertical

    @Test("Up and down step by a whole row")
    func vertical_stepsByARow() {
        #expect(SymbolGridNavigation.destination(from: 8, moving: .down, itemCount: 30) == 14)
        #expect(SymbolGridNavigation.destination(from: 8, moving: .up, itemCount: 30) == 2)
    }

    @Test("Up from the first row stops")
    func up_stopsOnTheFirstRow() {
        for index in 0..<SymbolGridNavigation.columnCount {
            #expect(SymbolGridNavigation.destination(from: index, moving: .up, itemCount: 30) == nil)
        }
    }

    @Test("Down from the last row stops")
    func down_stopsOnTheLastRow() {
        // 30 items in 6 columns is exactly five full rows.
        for index in 24..<30 {
            #expect(SymbolGridNavigation.destination(from: index, moving: .down, itemCount: 30) == nil)
        }
    }

    @Test("Down into a partly-filled last row lands on its last symbol")
    func down_intoAPartialRow_landsOnTheLastSymbol() {
        // 20 items: rows of 6, 6, 6 and a final row holding 18 and 19.
        #expect(SymbolGridNavigation.destination(from: 12, moving: .down, itemCount: 20) == 18)
        #expect(SymbolGridNavigation.destination(from: 13, moving: .down, itemCount: 20) == 19)
        #expect(SymbolGridNavigation.destination(from: 14, moving: .down, itemCount: 20) == 19)
        #expect(SymbolGridNavigation.destination(from: 17, moving: .down, itemCount: 20) == 19)
    }

    @Test("Down from the partial row itself stops")
    func down_fromThePartialRow_stops() {
        #expect(SymbolGridNavigation.destination(from: 18, moving: .down, itemCount: 20) == nil)
        #expect(SymbolGridNavigation.destination(from: 19, moving: .down, itemCount: 20) == nil)
    }

    @Test("A single row is a grid with no vertical movement")
    func singleRow_hasNoVerticalMovement() {
        #expect(SymbolGridNavigation.destination(from: 2, moving: .up, itemCount: 4) == nil)
        #expect(SymbolGridNavigation.destination(from: 2, moving: .down, itemCount: 4) == nil)
        #expect(SymbolGridNavigation.destination(from: 2, moving: .right, itemCount: 4) == 3)
    }

    // MARK: - Invariants

    @Test("Every destination is a real index")
    func everyDestination_isInRange() {
        for itemCount in [1, 5, 6, 7, 20, 30, 31] {
            for index in 0..<itemCount {
                for direction in [SymbolGridNavigation.Direction.up, .down, .left, .right] {
                    guard let destination = SymbolGridNavigation.destination(
                        from: index, moving: direction, itemCount: itemCount
                    ) else { continue }
                    #expect(
                        destination >= 0 && destination < itemCount,
                        "\(direction) from \(index) of \(itemCount) gave \(destination)"
                    )
                    #expect(destination != index, "\(direction) from \(index) did not move")
                }
            }
        }
    }

    @Test("Up undoes down wherever a full row is available")
    func verticalMovement_isReversible() {
        for index in 0..<24 {
            let down = SymbolGridNavigation.destination(from: index, moving: .down, itemCount: 30)
            #expect(down != nil)
            let back = down.flatMap {
                SymbolGridNavigation.destination(from: $0, moving: .up, itemCount: 30)
            }
            #expect(back == index)
        }
    }

    @Test("A zero column count cannot divide by itself")
    func zeroColumns_refusesEveryMove() {
        #expect(
            SymbolGridNavigation.destination(from: 3, moving: .down, itemCount: 30, columns: 0) == nil
        )
    }
}

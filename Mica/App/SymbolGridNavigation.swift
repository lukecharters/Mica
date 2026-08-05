// App/SymbolGridNavigation.swift
import Foundation

/// Where the keyboard cursor lands when an arrow key moves it through the symbol
/// picker's grid.
///
/// This is a separate type because the grid's column count has to be a *constant*.
/// The picker used `GridItem(.adaptive(minimum: 88))`, whose column count is decided
/// by the layout system and never reported back — so Up and Down had no distance to
/// move by. `columnCount` is read by both the grid and the arrow keys, which is what
/// stops the cursor jumping a different number of cells than the eye expects.
enum SymbolGridNavigation {
    /// Columns in the picker's grid. The sheet is a fixed width, so a fixed count
    /// costs nothing and makes vertical movement well defined.
    static let columnCount = 6

    enum Direction {
        case up, down, left, right
    }

    /// The index the cursor moves to, or nil when the move is not available.
    ///
    /// Horizontal movement runs through the whole list rather than stopping at a row
    /// end, matching a Finder icon view: Right on the last cell of a row lands on the
    /// first cell of the next.
    static func destination(
        from index: Int?,
        moving direction: Direction,
        itemCount: Int,
        columns: Int = columnCount
    ) -> Int? {
        guard itemCount > 0, columns > 0 else { return nil }

        // Any arrow key with no cursor yet enters the grid at the first symbol.
        guard let index, index >= 0, index < itemCount else { return 0 }

        switch direction {
        case .left:
            return index > 0 ? index - 1 : nil
        case .right:
            return index < itemCount - 1 ? index + 1 : nil
        case .up:
            let target = index - columns
            return target >= 0 ? target : nil
        case .down:
            let target = index + columns
            if target < itemCount { return target }
            // A partly-filled last row is still a row below: land on its last symbol
            // rather than refusing to move, which is what Finder does.
            let lastRow = (itemCount - 1) / columns
            return index / columns < lastRow ? itemCount - 1 : nil
        }
    }
}

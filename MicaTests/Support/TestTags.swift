// Tags for organising tests in the Xcode Test Navigator.
//
// Xcode's command-line test runner does NOT honour `includedTags` /
// `excludedTags` in .xctestplan JSON for Swift Testing @Tag values —
// tagging is still useful in-IDE for filtering the Navigator, but
// execution filtering must use runtime traits instead. See
// TestFilters.swift for the slow-test gate.

import Testing

extension Tag {
    @Tag static var unit: Self
    @Tag static var rendering: Self
    @Tag static var golden: Self
    @Tag static var slow: Self
}

// Tags for selecting subsets of tests in .xctestplan files.
//
// Default.xctestplan includes .unit and .rendering, excludes .slow.
// Full.xctestplan runs everything.

import Testing

extension Tag {
    @Tag static var unit: Self
    @Tag static var rendering: Self
    @Tag static var golden: Self
    @Tag static var slow: Self
}

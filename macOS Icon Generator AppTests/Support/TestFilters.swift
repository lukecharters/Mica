// Runtime gates for test subsets.
//
// Xcode test plans silently ignore Swift Testing `@Tag`-based filtering
// in their `includedTags`/`excludedTags` fields (the JSON schema is not
// honoured by the command-line runner, even though the UI exposes it).
// We drive slow-test inclusion from an environment variable that
// Full.xctestplan sets and Default.xctestplan does not.

import Foundation

enum TestFilters {
    /// True when the current test plan has opted into slow tests by
    /// setting `RUN_SLOW_TESTS=1` in its environment (see Full.xctestplan).
    static let runSlowTests: Bool = ProcessInfo.processInfo.environment["RUN_SLOW_TESTS"] == "1"
}

// Flips swift-snapshot-testing into record mode when RECORD_SNAPSHOTS=1
// (or "true", case-insensitive). Keep the logic testable by accepting
// an explicit environment dictionary; the default reads ProcessInfo.

import Foundation
import SnapshotTesting // Imported to verify the SPM dep linked correctly.

enum SnapshotConfig {

    /// Call from a Phase 5 suite's setUp to propagate the flag to the library.
    static func applyToSnapshotTesting() {
        SnapshotTesting.isRecording = isRecording()
    }

    static func isRecording(env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let value = env["RECORD_SNAPSHOTS"] else { return false }
        switch value.lowercased() {
        case "1", "true": return true
        default:          return false
        }
    }
}

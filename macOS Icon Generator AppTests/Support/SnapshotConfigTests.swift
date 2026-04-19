// SnapshotConfig centralises swift-snapshot-testing's record flag so the
// Phase 5 golden tests can all flip with a single env-var toggle.

import Testing
@testable import macOS_Icon_Generator_App

@Suite("SnapshotConfig", .tags(.unit))
struct SnapshotConfigTests {

    @Test("record is false by default (no env var set)")
    func record_defaultsFalse() {
        #expect(SnapshotConfig.isRecording(env: [:]) == false)
    }

    @Test("record is true when RECORD_SNAPSHOTS=1")
    func record_trueWhenOne() {
        #expect(SnapshotConfig.isRecording(env: ["RECORD_SNAPSHOTS": "1"]) == true)
    }

    @Test("record is true when RECORD_SNAPSHOTS=true (case-insensitive)")
    func record_trueWhenTrue() {
        #expect(SnapshotConfig.isRecording(env: ["RECORD_SNAPSHOTS": "true"]) == true)
        #expect(SnapshotConfig.isRecording(env: ["RECORD_SNAPSHOTS": "TRUE"]) == true)
    }

    @Test("record is false for other values")
    func record_falseForOther() {
        #expect(SnapshotConfig.isRecording(env: ["RECORD_SNAPSHOTS": "0"]) == false)
        #expect(SnapshotConfig.isRecording(env: ["RECORD_SNAPSHOTS": ""]) == false)
        #expect(SnapshotConfig.isRecording(env: ["RECORD_SNAPSHOTS": "no"]) == false)
    }
}

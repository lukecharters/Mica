// CLIVersionTests.swift
// Covers the version `mica-cli --version` reports, which is read from the
// bundle rather than written in the source. The literal it replaced had already
// drifted — 0.1.0 against an app at 0.1 — and nothing could have caught it: the
// mica-cli target carries no MARKETING_VERSION of its own, so there was no
// second value to disagree with.

import Testing
import Foundation

@Suite
struct CLIVersionTests {

    @Test("The version comes from CFBundleShortVersionString")
    func readsTheShortVersionString() {
        #expect(CLIVersion.resolve(infoDictionary: ["CFBundleShortVersionString": "0.1"]) == "0.1")
        #expect(CLIVersion.resolve(infoDictionary: ["CFBundleShortVersionString": "12.3.4"]) == "12.3.4")
    }

    /// CFBundleVersion is the commit count the packaging script passes in, which
    /// is not a version anyone would recognise. Reading the wrong one of the two
    /// would report something plausible, so the key is worth pinning by name.
    @Test("CFBundleVersion is not what is read")
    func ignoresTheBuildNumber() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "0.1",
            "CFBundleVersion": "412",
        ]
        #expect(CLIVersion.resolve(infoDictionary: info) == "0.1")
    }

    @Test("No bundle, no key and an empty value all report unbundled")
    func fallsBackWhenThereIsNoVersion() {
        #expect(CLIVersion.resolve(infoDictionary: nil) == CLIVersion.unbundled)
        #expect(CLIVersion.resolve(infoDictionary: [:]) == CLIVersion.unbundled)
        #expect(CLIVersion.resolve(infoDictionary: ["CFBundleVersion": "412"]) == CLIVersion.unbundled)
        #expect(CLIVersion.resolve(infoDictionary: ["CFBundleShortVersionString": ""]) == CLIVersion.unbundled)
    }

    /// The whole point of the fallback is that it cannot be mistaken for a
    /// release. A plausible number here would reintroduce the drifting literal
    /// this type exists to remove, and would look correct while being wrong.
    @Test("The fallback cannot be read as a version number")
    func fallbackIsNotAPlausibleVersion() {
        #expect(CLIVersion.unbundled.contains(where: { $0.isLetter }))
        #expect(CLIVersion.unbundled.first?.isNumber == false)
    }
}

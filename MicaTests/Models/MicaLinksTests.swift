// MicaLinksTests.swift
// The Help menu's links and the About panel's two resources — item B5 of
// the Mac-conventions plan.
//
// Every failure this pins is **silent in the app**. A renamed wiki page still opens,
// as a GitHub 404 that reads like the page merely moved. A `Credits.rtf` dropped from
// the bundle leaves the About panel looking deliberately plain. A missing
// `CFBundleShortVersionString` puts the word "unknown" in a filed bug report. None of
// them crash, none of them log, and the app cannot tell you about any of them.
//
// One check is missing from this file on purpose — that each linked wiki slug has a
// `wiki/<slug>.md`. It needs the repository source tree, which a hosted test in a
// sandboxed app cannot read. See the note above `everyLinkedPage_isDeclared`.

import Testing
import Foundation
@testable import Mica

@Suite("Mica links and the About panel")
struct MicaLinksTests {

    // MARK: - The link table

    /// Every URL the Help menu offers, with the item that shows it.
    static let allLinks: [(item: String, url: URL)] = [
        ("Mica Help", MicaLinks.help),
        ("Settings Index", MicaLinks.settingsIndex),
        ("Command Line Tool Reference", MicaLinks.cliReference),
        ("Release Notes", MicaLinks.releaseNotes),
        ("Report an Issue…", MicaLinks.reportIssue),
    ]

    @Test("Every Help link is https on github.com")
    func everyLink_isHTTPSOnGitHub() {
        for (item, url) in Self.allLinks {
            #expect(url.scheme == "https", "\(item) is not https")
            #expect(url.host() == "github.com", "\(item) points at \(url.host() ?? "nothing")")
        }
    }

    @Test("Every Help link sits under the one repository path")
    func everyLink_isUnderTheRepository() {
        // The point of `repository` being written once. A link assembled by hand
        // would still be https on github.com and would still 404.
        let base = MicaLinks.repository.absoluteString
        for (item, url) in Self.allLinks {
            #expect(url.absoluteString.hasPrefix(base + "/"), "\(item) is not under \(base)")
        }
    }

    @Test("No two Help items open the same page")
    func everyLink_isDistinct() {
        let urls = Self.allLinks.map(\.url.absoluteString)
        #expect(Set(urls).count == urls.count)
    }

    // MARK: - The wiki pages actually exist

    // **The other half of this check cannot live in this target.** Asserting that
    // every slug has a `wiki/<slug>.md` needs the repository source tree, and
    // `MicaTests` is injected into `Mica.app`, which is sandboxed
    // (`com.apple.security.app-sandbox`, with only `files.user-selected` granted).
    // `FileManager` there reports the repository as simply not existing, so a test
    // walking up from `#filePath` fails with "could not locate the repository root"
    // however correct the links are — measured 2026-08-04, not assumed.
    //
    // It lives in `scripts/tests/check-help-links.sh` instead, which runs outside the
    // sandbox. Deliberately *not* in `mica-cli Tests` — that target is unsandboxed and
    // could host it, but it would have to keep its own copy of the slug list, which is
    // the duplication being guarded against, and the project notes' CLI baseline must not
    // move for app-only work.
    //
    // What stays here is the half that needs no filesystem: the link table and the
    // slug list must not disagree with each other.

    @Test("Every linked wiki page is in the slug list")
    func everyLinkedPage_isDeclared() throws {
        // The two halves have to agree: a link built with `wikiPage(_:)` and left out
        // of `wikiPageSlugs` is exactly the link the test above cannot check.
        let wikiBase = MicaLinks.repository.appending(path: "wiki").absoluteString
        let declared = Set(MicaLinks.wikiPageSlugs)

        for (item, url) in Self.allLinks where url.absoluteString.hasPrefix(wikiBase + "/") {
            let slug = String(url.absoluteString.dropFirst(wikiBase.count + 1))
            #expect(declared.contains(slug), "\(item) links \(slug), which is not declared")
        }
    }

    // MARK: - The prefilled issue

    @Test("Report an Issue targets the new-issue form")
    func reportIssue_targetsTheForm() {
        let url = MicaLinks.reportIssue(appVersion: "0.1 (1)", systemVersion: "macOS 26.0")
        #expect(url.path() == "/lukecharters/Mica/issues/new")
    }

    @Test("The issue body survives percent-encoding intact")
    func issueBody_roundTripsThroughTheQuery() throws {
        let url = MicaLinks.reportIssue(appVersion: "0.1 (1)", systemVersion: "macOS 26.0 (Build 25A354)")

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(components.queryItems)
        #expect(items.count == 1, "the query must be the body alone")

        let body = try #require(items.first?.value)
        #expect(body == MicaLinks.issueBody(appVersion: "0.1 (1)",
                                            systemVersion: "macOS 26.0 (Build 25A354)"))
    }

    @Test("The prefilled body carries both versions and the headings")
    func issueBody_carriesWhatTheREADMEAsksFor() {
        // README ▸ Getting Help asks for the macOS version, the app version and, for
        // a rendering problem, the settings or the command. An empty form gets none
        // of that, which is the whole reason for prefilling.
        let body = MicaLinks.issueBody(appVersion: "0.1 (1)", systemVersion: "macOS 26.0")

        #expect(body.contains("Mica 0.1 (1)"))
        #expect(body.contains("macOS 26.0"))
        #expect(body.contains("### Steps to reproduce"))
        #expect(body.contains("mica-cli"))
    }

    @Test("The encoded query cannot escape itself")
    func issueBody_encodesEverythingReserved() throws {
        // The body holds `#` on every heading and a newline between each. Unencoded,
        // the first `#` would truncate the whole thing into a fragment.
        let url = MicaLinks.reportIssue(appVersion: "0.1 (1)", systemVersion: "macOS 26.0")
        let encoded = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .percentEncodedQuery)

        #expect(!encoded.contains("#"))
        #expect(!encoded.contains("\n"))
        #expect(!encoded.contains(" "))
        #expect(url.fragment() == nil)
    }

    // MARK: - What the About panel reads

    @Test("Credits.rtf is in the bundle")
    func credits_areBundled() throws {
        // The app target discovers files through a `PBXFileSystemSynchronizedRootGroup`,
        // so nothing declares this resource explicitly — and a resource that fails to
        // copy leaves the About panel merely looking plain. Hosted in Mica.app, so
        // `Bundle.main` is the app.
        let url = try #require(Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
                               "Credits.rtf did not reach Contents/Resources")

        let credits = try Data(contentsOf: url)
        #expect(credits.count > 0)

        let text = try #require(String(data: credits, encoding: .utf8))
        #expect(text.hasPrefix("{\\rtf"), "the About panel parses this as RTF")

        // Only the two things this file legally has to say. It asserted on
        // "calibration" too until 2026-08-05 — a word from the first draft's prose,
        // which `9dedc01` rewrote, leaving the suite red on main for a copy edit
        // that broke nothing. **Pin the attribution, not the wording.**
        #expect(text.contains("SF Symbols"), "Apple's symbols are attributed")
        #expect(text.contains("Apache License 2.0"), "the license is named")
    }

    @Test("The bundle carries the keys the About panel and a bug report read")
    func theBundleCarriesItsVersionKeys() throws {
        let info = try #require(Bundle.main.infoDictionary)

        // The About panel draws the version rows from these two, and
        // `currentAppVersion` falls back to "unknown" without them.
        let short = try #require(info["CFBundleShortVersionString"] as? String)
        let build = try #require(info["CFBundleVersion"] as? String)
        #expect(!short.isEmpty)
        #expect(!build.isEmpty)

        // Set in the project's two Mica configurations, not in Mica-Info.plist,
        // which is an empty dict — so this is the only thing pinning the pbxproj edit.
        let copyright = try #require(info["NSHumanReadableCopyright"] as? String)
        #expect(!copyright.isEmpty, "the About panel shows no copyright line")
    }

    @Test("The version summary reads as a version, not as the fallback")
    func currentAppVersion_isNotTheFallback() {
        #expect(!MicaLinks.currentAppVersion.contains("unknown"))
        #expect(MicaLinks.currentSystemVersion.hasPrefix("macOS "))
    }

    @Test("The system version does not read \"macOS Version 26.6\"")
    func currentSystemVersion_doesNotDoubleUpTheWordVersion() {
        // `ProcessInfo.operatingSystemVersionString` already begins "Version ", so a
        // naive prefix produced "macOS Version 26.6 (Build 25G70)" in the prefilled
        // bug report. Caught by reading the URL out of the browser, not by a test —
        // this is the test that would have caught it.
        #expect(!MicaLinks.currentSystemVersion.contains("macOS Version"))

        // The build number is the half worth keeping; nothing else exposes it.
        #expect(MicaLinks.currentSystemVersion.contains("Build"))
    }
}

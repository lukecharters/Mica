// App/MicaLinks.swift
import Foundation

/// Every URL the app links out to, derived from one repository path.
///
/// Mica is distributed free on GitHub and has no help book, so the Help menu *is*
/// the documentation — item B5 of the Mac-conventions plan. That makes a
/// dead link a shipped defect rather than a cosmetic one, and the failure is quiet:
/// a wrong URL opens a GitHub 404 that looks like the page merely moved.
///
/// **`App/`, not `Models/`** — the CLI prints its own help and never opens a
/// browser, so it does not compile this. See the project notes' rule on which list a new
/// file joins; a file here costs no `membershipExceptions` edits.
///
/// Two things hold it together:
///
/// - **`repository` is written once.** Everything else appends to it, so a rename
///   or a move under an organisation is a one-line edit rather than six.
/// - **`wikiPageSlugs` must match the files in `wiki/`.** The slugs are the
///   filenames without `.md`, because that is how GitHub addresses a wiki page.
///   `MicaLinksTests.everyWikiLinkHasAPage` reads the real directory and fails if a
///   page is renamed out from under a link — nothing else would notice until a user
///   clicked it.
enum MicaLinks {
    /// The one place the repository path appears.
    static let repository = URL(string: "https://github.com/lukecharters/Mica")!

    /// Help ▸ Mica Help. `Home` rather than a bare `/wiki` so every wiki link is
    /// one shape and the slug test can check this one too.
    static var help: URL { wikiPage("Home") }

    /// Help ▸ Settings Index — every setting, grouped by icon area.
    static var settingsIndex: URL { wikiPage("Settings-Index") }

    /// Help ▸ Command Line Tool Reference — every command and flag.
    static var cliReference: URL { wikiPage("CLI-Reference") }

    /// Help ▸ Release Notes.
    static var releaseNotes: URL { repository.appending(path: "releases") }

    /// The wiki pages linked from the Help menu, as `wiki/<slug>.md` filenames.
    static let wikiPageSlugs = ["Home", "CLI-Reference", "Settings-Index"]

    /// A wiki page by slug.
    static func wikiPage(_ slug: String) -> URL {
        repository.appending(path: "wiki").appending(path: slug)
    }

    // MARK: - Reporting an issue

    /// Help ▸ Report an Issue…, prefilled.
    ///
    /// The README's *Getting Help* section asks a reporter for their macOS version,
    /// the app version and — for a rendering problem — the settings or the full
    /// `mica-cli` command. Asking for that in prose and then opening an empty form
    /// gets it left out, so the form arrives with the two versions already filled in
    /// and a heading for the third.
    static var reportIssue: URL {
        reportIssue(appVersion: currentAppVersion, systemVersion: currentSystemVersion)
    }

    /// The prefilled new-issue URL for explicit versions. Split out from
    /// `reportIssue` so a test can pin the encoding without depending on the
    /// bundle it happens to be hosted in.
    static func reportIssue(appVersion: String, systemVersion: String) -> URL {
        let target = repository.appending(path: "issues").appending(path: "new")
        var components = URLComponents(url: target, resolvingAgainstBaseURL: false)!

        // `percentEncodedQuery` with an explicitly encoded value, not `queryItems`.
        // `URLComponents` leaves `+` literal in a query value, and a server reads
        // that back as a space — harmless for today's body and a trap for anyone who
        // edits the template.
        components.percentEncodedQuery = "body=" + percentEncodedForQuery(
            issueBody(appVersion: appVersion, systemVersion: systemVersion)
        )
        return components.url!
    }

    /// The issue template. Newlines and `#` survive because the whole thing is
    /// percent-encoded on the way into the query.
    static func issueBody(appVersion: String, systemVersion: String) -> String {
        """
        ### What happened


        ### What I expected


        ### Steps to reproduce

        1.
        2.

        ### Settings or command

        For a rendering problem, paste the exported configuration or the full \
        mica-cli command that reproduces it.


        ### Versions

        - Mica \(appVersion)
        - \(systemVersion)
        """
    }

    /// `CFBundleShortVersionString (CFBundleVersion)`, as the About panel writes it.
    ///
    /// Falls back to `unknown` rather than trapping — a missing key must not crash
    /// the app on the way to a bug report, and `unknown` in a filed issue reports
    /// itself. `MicaLinksTests.theBundleCarriesItsVersionKeys` is what stops a
    /// shipping build reaching that fallback silently.
    static var currentAppVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(short) (\(build))"
    }

    /// e.g. `macOS 26.6 (Build 25G70)`. Display only — never parse it.
    ///
    /// `operatingSystemVersionString` already begins "Version ", so prefixing it
    /// naively reads "macOS Version 26.6 (Build 25G70)" in a filed bug report. The
    /// prefix is dropped rather than the whole string rebuilt, because the build
    /// number in the parentheses is the useful half and nothing else exposes it.
    static var currentSystemVersion: String {
        let reported = ProcessInfo.processInfo.operatingSystemVersionString
        let withoutPrefix = reported.hasPrefix("Version ")
            ? String(reported.dropFirst("Version ".count))
            : reported
        return "macOS " + withoutPrefix
    }

    /// Percent-encodes everything outside RFC 3986's unreserved set, so a query
    /// value cannot terminate the query or start a fragment.
    private static func percentEncodedForQuery(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}

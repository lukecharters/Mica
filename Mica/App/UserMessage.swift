// App/UserMessage.swift
//
// The one thing Mica tells the user about after an action, and the two routes
// anything in the app uses to say it. Item B3 of `docs/plans/mac-conventions.md`.
//
// ## What this replaces
//
// Four presentation paths, counted on 2026-08-05:
//
//   - `print()` to a console the user cannot see — the four pastes, the canvas
//     drop, and **both branches of the PNG export**, so an export that failed
//     said nothing at all. That was the review's worst case.
//   - `NSAlert(error:).runModal()` — the four File-menu imports and the
//     inspector's Choose File…, each blocking the app on a modal that is not
//     attached to the window that caused it.
//   - Four SwiftUI `.alert`s on `ContentView`, one per error property.
//   - An inline error view in `AppexPreviewPane`.
//
// The first three are now this type plus one `.alert` in `ContentView`.
//
// ## The inline path stays, deliberately
//
// `AppexPreviewPane` still reads `IconViewModel.appexError` and draws it in
// place, and that is not a fifth path left behind. **This type is for failures
// that follow a discrete action** — a paste, an import, an export, a copy —
// which is exactly the set an alert suits: the user did one thing, it did not
// work, and there is nothing on screen to explain it. The appex error is
// continuously recomputed render *state*: it appears and clears as the user
// types a symbol name, and an alert per keystroke would be unusable. It also
// already has somewhere to live, which is the pane the missing image would have
// filled. Sort a new failure by that question, not by severity.

import SwiftUI
import os

/// One thing to tell the user about, after they asked for something.
///
/// `Equatable` and carrying no identity, so a test can assert on the message a
/// failure produces rather than on a bool — and so re-reporting the same failure
/// does not re-present the alert.
struct UserMessage: Equatable {
    enum Kind: Equatable {
        /// The action did not happen.
        case failure
        /// The action happened, but not entirely as asked.
        case advisory
    }

    var kind: Kind
    /// Sentence case, no trailing period: it is a title. Says what did not
    /// happen rather than what went wrong — "Couldn't Copy the Icon", not
    /// "Pasteboard Error" — because the user knows what they asked for and the
    /// message carries the detail.
    var title: String
    var message: String

    // MARK: Constructors
    //
    // Every call site builds a message through one of these, so a title cannot
    // be spelled two ways in two files.

    static func failure(_ title: String, _ error: Error) -> UserMessage {
        UserMessage(kind: .failure, title: title, message: error.localizedDescription)
    }

    static func failure(_ title: String, message: String) -> UserMessage {
        UserMessage(kind: .failure, title: title, message: message)
    }

    static func advisory(_ title: String, message: String) -> UserMessage {
        UserMessage(kind: .advisory, title: title, message: message)
    }

    // MARK: The app's messages

    static func exportFailed(_ error: Error) -> UserMessage {
        .failure("Couldn’t Export the Icon", error)
    }

    static func copyFailed(_ error: Error) -> UserMessage {
        .failure("Couldn’t Copy the Icon", error)
    }

    static func imageImportFailed(_ error: Error) -> UserMessage {
        .failure("Couldn’t Import the Image", error)
    }

    static func configurationExportFailed(_ error: Error) -> UserMessage {
        .failure("Couldn’t Export the Configuration", error)
    }

    static func configurationImportFailed(_ error: Error) -> UserMessage {
        .failure("Couldn’t Import the Configuration", error)
    }

    /// Nothing on the pasteboard a paste command could use.
    ///
    /// An advisory rather than nothing at all, which is what the four Paste as…
    /// items used to do — `ImageImportService.importFromPasteboard()` returns nil
    /// for an empty pasteboard instead of throwing, so the command silently did
    /// nothing and the user was left to guess whether it had run. That is half of
    /// item C7; the other half is the items disabling themselves, which needs the
    /// menu's validation timing measured and stays with C7.
    static let nothingToPaste = UserMessage.advisory(
        "Nothing to Paste",
        message: "The clipboard doesn’t contain an image Mica can use."
    )

    /// What an imported configuration could not honour, or nil if it honoured
    /// everything.
    ///
    /// Listed rather than counted — "3 problems" tells the user nothing about
    /// which layer came back empty. An advisory, because the configuration did
    /// import: this is the one message here that follows a *successful* action.
    static func configurationImportWarnings(_ warnings: [MicaConfigWarning]) -> UserMessage? {
        guard !warnings.isEmpty else { return nil }
        return .advisory(
            "Imported with Changes",
            message: warnings.map(\.message).joined(separator: "\n\n")
        )
    }
}

// MARK: - Reporting

/// How anything in the app hands a `UserMessage` to the window that will show it.
///
/// A wrapper rather than a bare closure so it can be an `@Entry` in both
/// `EnvironmentValues` and `FocusedValues` — a `FocusedValues` entry has to be a
/// plain value, and a bare `((UserMessage) -> Void)?` reads as a double optional
/// at the use site. Same reasoning as `FocusedAction`.
/// `Sendable` because `unattached` is a static let and a non-`Sendable` one is a
/// concurrency error under Swift 6. That costs nothing: the closure it wraps is
/// `@Sendable`, and the only closure Mica puts in it captures a `@MainActor`
/// class weakly, which is `Sendable` already.
struct UserMessageReporter: Sendable {
    let report: @Sendable (UserMessage) -> Void

    /// The environment's default, for a SwiftUI preview or a Debug tool that has
    /// no view model behind it.
    ///
    /// **It logs rather than swallowing.** A neutral default is how a reporting
    /// mechanism goes quiet without anyone noticing: the call site looks correct,
    /// the message goes nowhere, and no test can tell the difference. Anything
    /// arriving here means the environment value was never installed, so it says
    /// so in Console at `.error` — loudly enough to find, without crashing a
    /// preview that legitimately has no window.
    static let unattached = UserMessageReporter { message in
        Logger(subsystem: "com.lukecharters.Mica", category: "UserMessage")
            .error("No reporter installed — dropped \(message.title, privacy: .public): \(message.message, privacy: .public)")
    }
}

extension EnvironmentValues {
    /// The in-window route: the preview's drop handler and the inspector's
    /// Choose File… button, neither of which `ContentView` can hand a closure to
    /// without threading it through five views.
    @Entry var reportUserMessage = UserMessageReporter.unattached
}

extension FocusedValues {
    /// The menu route. `MicaApp`'s commands live in a `Scene`, which has no
    /// environment to read, so the focused window publishes its reporter the
    /// same way it publishes `iconSettings` — and nil means no window, exactly
    /// as it does for every other command there.
    @Entry var userMessageReporter: UserMessageReporter?
}

// UserMessageTests.swift
//
// Item B3: one error-presentation path. What can be tested here is the value
// side of it — every failure produces a `UserMessage`, one slot holds it, and
// the reporter both routes reach is the view model's.
//
// **What no test here can see** is the thing B3 was actually about: whether a
// failure reaches the *screen*. `ContentView` has one `.alert`, and a call site
// that dropped its error, or a view whose environment reporter was never
// installed, still compiles and still passes everything below.
// `UserMessageReporter.unattached` logging rather than swallowing is the one
// hedge against the second case; the first needs the on-screen checks listed in
// `docs/plans/mac-conventions.md` under B3.

import Testing
import SwiftUI
@testable import Mica

@Suite(.tags(.unit))
struct UserMessageTests {

    // MARK: - Constructors

    @Test("A failure carries the error's localized description")
    func failure_usesLocalizedDescription() {
        let message = UserMessage.failure("Couldn’t Do the Thing", ImageImportError.failedToNormalize)

        #expect(message.kind == .failure)
        #expect(message.title == "Couldn’t Do the Thing")
        #expect(message.message == ImageImportError.failedToNormalize.localizedDescription)
    }

    @Test("Every named message names the action that failed, not the mechanism")
    func namedMessages_titleTheAction() {
        let error = ImageImportError.failedToNormalize

        #expect(UserMessage.exportFailed(error).title == "Couldn’t Export the Icon")
        #expect(UserMessage.copyFailed(error).title == "Couldn’t Copy the Icon")
        #expect(UserMessage.imageImportFailed(error).title == "Couldn’t Import the Image")
        #expect(UserMessage.configurationExportFailed(error).title == "Couldn’t Export the Configuration")
        #expect(UserMessage.configurationImportFailed(error).title == "Couldn’t Import the Configuration")
    }

    @Test("Every named failure is a failure, and the two advisories are not")
    func kindsAreRight() {
        let error = ImageImportError.failedToNormalize
        let failures = [
            UserMessage.exportFailed(error),
            UserMessage.copyFailed(error),
            UserMessage.imageImportFailed(error),
            UserMessage.configurationExportFailed(error),
            UserMessage.configurationImportFailed(error),
        ]
        for failure in failures {
            #expect(failure.kind == .failure)
        }

        #expect(UserMessage.nothingToPaste.kind == .advisory)
        #expect(
            UserMessage.configurationImportWarnings(
                [MicaConfigWarning(key: "icon-fg", message: "nope")]
            )?.kind == .advisory
        )
    }

    // MARK: - Import warnings

    @Test("No warnings is nothing to say, not an empty alert")
    func warnings_emptyIsNil() {
        #expect(UserMessage.configurationImportWarnings([]) == nil)
    }

    @Test("Warnings are listed, not counted")
    func warnings_areListed() throws {
        let warnings = [
            MicaConfigWarning(key: "icon-fg", message: "the icon symbol image could not be read"),
            MicaConfigWarning(key: "badge-bg", message: "the badge background image could not be read"),
        ]

        let message = try #require(UserMessage.configurationImportWarnings(warnings))

        // Both messages present, and separately readable — "2 problems" would tell
        // the user nothing about which layer came back empty.
        for warning in warnings {
            #expect(message.message.contains(warning.message))
        }
    }

    // MARK: - Equality
    //
    // The type carries no identity on purpose: a test asserts on the message a
    // failure produces, and re-reporting the same failure does not re-present.

    @Test("Two messages built the same way are equal")
    func equality() {
        let error = ImageImportError.failedToNormalize
        #expect(UserMessage.copyFailed(error) == UserMessage.copyFailed(error))
        #expect(UserMessage.copyFailed(error) != UserMessage.exportFailed(error))
        #expect(
            UserMessage.failure("Same Title", message: "a") != .failure("Same Title", message: "b")
        )
        // Kind is part of it: the same words as a failure and as an advisory are
        // not the same message.
        #expect(
            UserMessage.failure("T", message: "m") != .advisory("T", message: "m")
        )
    }

    // MARK: - Reporting

    @MainActor
    @Test("The view model's reporter fills its one slot")
    func reporter_reachesTheViewModel() {
        let model = IconViewModel()
        #expect(model.userMessage == nil)

        model.messageReporter.report(.copyFailed(ImageImportError.failedToNormalize))

        #expect(model.userMessage == .copyFailed(ImageImportError.failedToNormalize))
    }

    @MainActor
    @Test("report(nil) is a no-op, so a caller need not unwrap")
    func report_nilChangesNothing() {
        let model = IconViewModel()
        model.report(.nothingToPaste)

        model.report(nil)

        #expect(model.userMessage == .nothingToPaste)
    }

    @MainActor
    @Test("The slot is last-write-wins")
    func report_replaces() {
        let model = IconViewModel()
        model.report(.nothingToPaste)

        model.report(.copyFailed(ImageImportError.failedToNormalize))

        #expect(model.userMessage == .copyFailed(ImageImportError.failedToNormalize))
    }

    @MainActor
    @Test("The reporter does not keep its view model alive")
    func reporter_isWeak() {
        // The reporter is handed to the environment and to a focused value, both of
        // which outlive a closing window. A strong capture would leak every window's
        // view model for the life of the app.
        var model: IconViewModel? = IconViewModel()
        let reporter = model!.messageReporter
        weak var observed = model

        model = nil

        #expect(observed == nil)
        // Still safe to call — it just has nowhere to put the message.
        reporter.report(.nothingToPaste)
    }
}

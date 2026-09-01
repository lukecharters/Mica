// PresetIndicatorTests.swift
//
// Which glyphs a preset tile draws beneath its name, and in what order.
//
// **This exists because nothing else in the preset list is reachable by a test.** The
// glyph row, the tile's tooltip and its accessibility label are all built from one
// list, and all three live inside a view's `body`. `PresetIndicator.indicators` is a
// pure function of three booleans precisely so the eight combinations can be
// enumerated here rather than checked by eye against a running app.
//
// What is *not* covered, and cannot be: that the row draws where it should, that the
// reserved height keeps the grid rows level, and that a glyph reads as chrome rather
// than as part of the icon. Those are screenshots.

import Testing
import AppKit
@testable import Mica

@Suite("Preset indicators", .tags(.unit))
struct PresetIndicatorTests {

    private func indicators(
        user: Bool,
        needsAdvanced: Bool,
        advancedEnabled: Bool
    ) -> [PresetIndicator] {
        PresetIndicator.indicators(
            isUserPreset: user,
            needsAdvancedControls: needsAdvanced,
            advancedControlsEnabled: advancedEnabled
        )
    }

    // MARK: - The rule

    @Test("A built-in that needs nothing draws no indicators")
    func plainBuiltInIsBare() {
        #expect(indicators(user: false, needsAdvanced: false, advancedEnabled: false).isEmpty)
        #expect(indicators(user: false, needsAdvanced: false, advancedEnabled: true).isEmpty)
    }

    @Test("A user preset is marked whatever the advanced-controls preference says",
          arguments: [false, true])
    func userPresetIsAlwaysMarked(advancedEnabled: Bool) {
        // Identity, not a warning. A preference about which *controls* are shown has
        // nothing to say about who saved a preset, and a glyph that came and went with
        // an unrelated setting would read as a bug.
        let found = indicators(user: true, needsAdvanced: false, advancedEnabled: advancedEnabled)
        #expect(found == [.userPreset])
    }

    @Test("The advanced-controls glyph is a warning, so it goes once the preference is on")
    func advancedControlsGlyphFollowsThePreference() {
        #expect(indicators(user: false, needsAdvanced: true, advancedEnabled: false)
                == [.advancedControls])
        // Nothing left to warn about — and left in, it would mark every flagged tile
        // for the rest of the session.
        #expect(indicators(user: false, needsAdvanced: true, advancedEnabled: true).isEmpty)
    }

    @Test("Both apply at once, identity first")
    func bothApply_identityLeads() {
        // The order is the assertion, not the membership. Whether a preset is the
        // user's cannot change while the app runs, while the advanced-controls glyph
        // appears and disappears with the preference — so identity leads, and a tile's
        // leading glyph stays put when the preference is toggled.
        #expect(indicators(user: true, needsAdvanced: true, advancedEnabled: false)
                == [.userPreset, .advancedControls])
        #expect(indicators(user: true, needsAdvanced: true, advancedEnabled: true)
                == [.userPreset])
    }

    @Test("No combination draws more than the two indicators that exist")
    func nothingIsDrawnTwice() {
        // Exhaustive over the three booleans, because the rule is small enough to be
        // and because a duplicated `append` is what a third indicator's copy-paste
        // produces. Every list must also be free of repeats — `id` is the symbol name,
        // and `ForEach` over a duplicated id is a runtime complaint, not a build error.
        for user in [false, true] {
            for needs in [false, true] {
                for enabled in [false, true] {
                    let found = indicators(user: user, needsAdvanced: needs, advancedEnabled: enabled)
                    #expect(found.count <= 2)
                    #expect(Set(found.map(\.id)).count == found.count,
                            Comment(rawValue: "repeated indicator in \(found.map(\.id))"))
                }
            }
        }
    }

    // MARK: - The glyphs and the wording

    // Iterated rather than parameterised: `PresetIndicator` carries a
    // `LocalizedStringKey`, which is not `Sendable`, so it cannot be a test argument.

    @Test("Every glyph resolves as an SF Symbol")
    func everyGlyphResolves() {
        // **A misspelled SF Symbol name draws nothing at all, with no error** — the row
        // would simply be short one glyph, with nothing to say which. Same guard, same
        // reason, as `SidebarPresentationTests` puts on the selector bar's two.
        for indicator in PresetIndicator.all {
            #expect(
                NSImage(systemSymbolName: indicator.symbolName,
                        accessibilityDescription: nil) != nil,
                Comment(rawValue: "\(indicator.symbolName) is not an SF Symbol")
            )
        }
    }

    @Test("No two indicators share a glyph")
    func glyphsAreDistinct() {
        // A row drawing the same picture twice says nothing, and it is what a
        // copy-paste of one of the static factories produces.
        let glyphs = PresetIndicator.all.map(\.symbolName)
        #expect(Set(glyphs).count == glyphs.count, Comment(rawValue: "\(glyphs)"))
    }

    @Test("Every indicator carries a distinct spoken clause")
    func clausesAreSaid() {
        // The glyphs are `accessibilityHidden`, so the clause is the *only* thing that
        // says the indicator to VoiceOver. An empty one hides the marker completely
        // from the user who most needs it told, and the tile's label still reads as a
        // well-formed sentence — there is nothing to notice.
        for indicator in PresetIndicator.all {
            #expect(!indicator.clause.isEmpty,
                    Comment(rawValue: "\(indicator.symbolName) has no spoken clause"))
        }
        let clauses = PresetIndicator.all.map(\.clause)
        #expect(Set(clauses).count == clauses.count, Comment(rawValue: "\(clauses)"))
    }

    @Test("`all` holds every indicator the rule can produce")
    func allIsComplete() {
        // Otherwise the two guards above iterate a list that has quietly fallen behind
        // `indicators(...)`, and report success over a subset.
        var produced: Set<String> = []
        for user in [false, true] {
            for needs in [false, true] {
                for enabled in [false, true] {
                    let found = indicators(user: user, needsAdvanced: needs, advancedEnabled: enabled)
                    produced.formUnion(found.map(\.id))
                }
            }
        }
        #expect(produced == Set(PresetIndicator.all.map(\.id)))
    }
}

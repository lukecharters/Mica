// MicaTests/Models/BadgeModeMemoryTests.swift
import Testing
@testable import Mica

/// `BadgeModeMemory` is the badge's way back out of System generation mode. The
/// badge stores no mode — `BadgeSpec.mode` is derived from `foreground.source` — so
/// switching to System destroys the value it has to restore, and nothing else in the
/// app remembers it.
///
/// These assert on `IconSettings`, not on the toolbar menu that drives it: the switch
/// was inline in `InspectorControls` and therefore untestable until the mode picker
/// moved to the toolbar on 2026-08-04.
@Suite("Badge generation mode memory")
struct BadgeModeMemoryTests {

    /// A badge on `.symbol` — the default — must come back to `.symbol`.
    @Test("A round trip through System restores the symbol source")
    func roundTripRestoresSymbol() {
        var settings = IconSettings()
        settings.badge.foreground.source = .symbol
        var memory = BadgeModeMemory()

        memory.setSystem(true, in: &settings)
        #expect(settings.badge.foreground.source == .system)
        #expect(settings.badge.mode == .system)

        memory.setSystem(false, in: &settings)
        #expect(settings.badge.foreground.source == .symbol)
        #expect(settings.badge.mode == .mica)
    }

    /// The case the memory exists for: an imported badge foreground must not be
    /// silently downgraded to a symbol by a visit to System mode.
    @Test("A round trip through System restores an imported source")
    func roundTripRestoresImage() {
        var settings = IconSettings()
        settings.badge.foreground.source = .image
        var memory = BadgeModeMemory()

        memory.setSystem(true, in: &settings)
        memory.setSystem(false, in: &settings)

        #expect(settings.badge.foreground.source == .image)
    }

    /// `setSystem` banks the source on the way in, so it does not depend on
    /// `observe` having been called by whatever changed the source.
    @Test("Switching to System banks the current source without a prior observe")
    func switchingToSystemBanksWithoutObserve() {
        var settings = IconSettings()
        var memory = BadgeModeMemory()
        // Note: no `memory.observe(.image)`.
        settings.badge.foreground.source = .image

        memory.setSystem(true, in: &settings)
        memory.setSystem(false, in: &settings)

        #expect(settings.badge.foreground.source == .image)
    }

    /// The observer's job: a source the badge reached from the inspector, a paste or
    /// a decoded configuration is the one a later round trip must restore.
    @Test("An observed source is what a later round trip restores")
    func observedSourceWins() {
        var settings = IconSettings()
        var memory = BadgeModeMemory()

        memory.observe(.image)
        settings.badge.foreground.source = .system

        memory.setSystem(false, in: &settings)
        #expect(settings.badge.foreground.source == .image)
    }

    /// `.system` is the state being remembered the way out of, so observing it must
    /// not overwrite the escape route — that would strand the badge in System mode.
    @Test("Observing .system does not overwrite the remembered source")
    func observingSystemIsIgnored() {
        var memory = BadgeModeMemory()

        memory.observe(.image)
        memory.observe(.system)

        #expect(memory.lastNonSystemSource == .image)
    }

    /// A badge that starts on System — from a configuration, say — still has to have
    /// somewhere to go, so the seed is a real source rather than nil.
    @Test("A badge that starts on System leaves for .symbol")
    func startingOnSystemLeavesForSymbol() {
        var settings = IconSettings()
        settings.badge.foreground.source = .system
        var memory = BadgeModeMemory()

        memory.setSystem(false, in: &settings)

        #expect(settings.badge.foreground.source == .symbol)
        #expect(settings.badge.mode == .mica)
    }

    /// Switching to System twice must not bank `.system` on the second call and lose
    /// the source the first one saved.
    @Test("Switching to System twice keeps the original source")
    func repeatedSwitchToSystemIsIdempotent() {
        var settings = IconSettings()
        settings.badge.foreground.source = .image
        var memory = BadgeModeMemory()

        memory.setSystem(true, in: &settings)
        memory.setSystem(true, in: &settings)
        memory.setSystem(false, in: &settings)

        #expect(settings.badge.foreground.source == .image)
    }

    /// The icon's mode has no memory to keep, and this is why: it is stored, so a
    /// round trip is lossless on its own. Pinned so the two are not "unified" later.
    @Test("The icon's mode round-trips without any memory")
    func iconModeNeedsNoMemory() {
        var settings = IconSettings()

        settings.icon.mode = .system
        #expect(settings.icon.mode == .system)
        settings.icon.mode = .mica
        #expect(settings.icon.mode == .mica)
        #expect(settings.icon.foreground.source == IconSettings().icon.foreground.source)
    }
}

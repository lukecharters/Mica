// LayoutSettingsTests.swift
// Locks in the default values of LayoutSettings. These drive the shared
// rendering geometry; an unintentional change here silently shifts every
// rendered icon.

import Testing
import SwiftUI
@testable import macOS_Icon_Generator_App

@Suite(.tags(.unit))
@MainActor
struct LayoutSettingsTests {

    @Test("Defaults match the shipped 256pt reference geometry")
    func defaults_areStable() {
        let l = LayoutSettings()
        #expect(l.iconSize == 256)
        #expect(l.cornerRadius == 70)
        #expect(l.backgroundInset == 25)
        #expect(l.symbolSize == 120)
        #expect(l.symbolFrameSize == 178)
        #expect(l.shadowRadius == 2)
        #expect(l.shadowOffset == 2.5)
        #expect(l.verticalAlignmentOffset == 5.5)
        #expect(l.symbolWeight == .regular)
    }

    @Test("Each property is independently mutable")
    func mutation_isIndependent() {
        var l = LayoutSettings()
        l.iconSize = 512
        l.cornerRadius = 112
        l.backgroundInset = 50
        l.symbolSize = 240
        l.symbolFrameSize = 356
        l.shadowRadius = 4
        l.shadowOffset = 5
        l.verticalAlignmentOffset = 10
        l.symbolWeight = .bold

        #expect(l.iconSize == 512)
        #expect(l.cornerRadius == 112)
        #expect(l.backgroundInset == 50)
        #expect(l.symbolSize == 240)
        #expect(l.symbolFrameSize == 356)
        #expect(l.shadowRadius == 4)
        #expect(l.shadowOffset == 5)
        #expect(l.verticalAlignmentOffset == 10)
        #expect(l.symbolWeight == .bold)
    }
}

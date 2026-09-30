// CalibrationAdvanceTests.swift
// Where the symbol calibration tool lands after Space, Tab or Escape.

import Testing
@testable import Mica

@Suite(.tags(.unit))
struct CalibrationAdvanceTests {

    @Test func nextMemberWhenTheFamilyHasOneLeft() {
        let ids = ["a", "b", "c"]
        let step = CalibrationAdvance.next(
            familyID: "b", memberIndex: 0, memberCount: 2, isContainer: false,
            before: ids, after: ids)
        #expect(step == .member(1))
    }

    @Test func nextFamilyAfterTheLastMember() {
        let ids = ["a", "b", "c"]
        let step = CalibrationAdvance.next(
            familyID: "b", memberIndex: 1, memberCount: 2, isContainer: false,
            before: ids, after: ids)
        #expect(step == .family(2))
    }

    @Test func aFamilyThatLeavesTheFilterDoesNotSkipTheNextOne() {
        let step = CalibrationAdvance.next(
            familyID: "gen3.left", memberIndex: 0, memberCount: 1, isContainer: false,
            before: ["gen3", "gen3.left", "gen3.right", "pro.left"],
            after: ["gen3", "gen3.right", "pro.left"])
        #expect(step == .family(1))
    }

    @Test func aFamilyThatLeavesTheFilterMidwayMovesOn() {
        let step = CalibrationAdvance.next(
            familyID: "b", memberIndex: 0, memberCount: 3, isContainer: false,
            before: ["a", "b", "c"], after: ["a", "c"])
        #expect(step == .family(1))
    }

    @Test func aContainerAlwaysMovesToTheNextFamily() {
        let ids = ["container.circle", "container.square"]
        let step = CalibrationAdvance.next(
            familyID: "container.circle", memberIndex: 0, memberCount: 40, isContainer: true,
            before: ids, after: ids)
        #expect(step == .family(1))
    }

    @Test func theLastFamilyStays() {
        let ids = ["a", "b"]
        let step = CalibrationAdvance.next(
            familyID: "b", memberIndex: 0, memberCount: 1, isContainer: false,
            before: ids, after: ids)
        #expect(step == .stay)
    }

    @Test func theLastFamilyLeavingTheFilterLandsOnTheNewLast() {
        let step = CalibrationAdvance.next(
            familyID: "b", memberIndex: 0, memberCount: 1, isContainer: false,
            before: ["a", "b"], after: ["a"])
        #expect(step == .family(0))
    }

    @Test func anEmptiedFilterStays() {
        let step = CalibrationAdvance.next(
            familyID: "a", memberIndex: 0, memberCount: 1, isContainer: false,
            before: ["a"], after: [])
        #expect(step == .stay)
    }
}

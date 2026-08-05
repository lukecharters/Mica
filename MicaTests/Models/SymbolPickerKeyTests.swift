// SymbolPickerKeyTests.swift
import AppKit
import Testing
@testable import Mica

@Suite("Symbol picker key handling")
@MainActor
struct SymbolPickerKeyTests {

    // MARK: - Event fixtures

    /// The arrow keys as AppKit actually delivers them: the function-key unicode value,
    /// and `.function` + `.numericPad` **always set**. Building them any other way would
    /// make these tests agree with a bug.
    private static func arrow(
        _ special: NSEvent.SpecialKey,
        extraModifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        let characters = String(UnicodeScalar(UInt32(special.rawValue))!)
        let alwaysSet: NSEvent.ModifierFlags = [.function, .numericPad]
        return event(characters: characters, modifiers: alwaysSet.union(extraModifiers))
    }

    private static func event(
        characters: String,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: 0
        )!
    }

    private static let escapeEvent = event(characters: "\u{1B}")
    private static let returnEvent = event(characters: "\r")

    private func intent(
        _ event: NSEvent,
        isEditingText: Bool = true,
        queryIsEmpty: Bool = true
    ) -> SymbolPickerKey.Intent? {
        SymbolPickerKey.intent(for: event, isEditingText: isEditingText, queryIsEmpty: queryIsEmpty)
    }

    // MARK: - Arrows

    @Test("Each arrow moves the cursor in its own direction")
    func arrows_moveTheCursor() {
        #expect(intent(Self.arrow(.upArrow)) == .move(.up))
        #expect(intent(Self.arrow(.downArrow)) == .move(.down))
        #expect(intent(Self.arrow(.leftArrow)) == .move(.left))
        #expect(intent(Self.arrow(.rightArrow)) == .move(.right))
    }

    /// The regression this file exists for. Every arrow key carries `.function` and
    /// `.numericPad`, so a guard of `intersection(.deviceIndependentFlagsMask).isEmpty`
    /// rejects all four — and the picker then behaves *exactly* as it did with no key
    /// handling at all, which is why nothing on screen looks broken.
    @Test("An arrow key's own .function and .numericPad flags are not treated as modifiers")
    func arrows_functionAndNumericPadAreNotModifiers() {
        let event = Self.arrow(.downArrow)
        #expect(event.modifierFlags.contains(.function))
        #expect(event.modifierFlags.contains(.numericPad))
        #expect(!event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                "the flags this guards against must actually be present, or the test proves nothing")
        #expect(intent(event) == .move(.down))
    }

    @Test("A modified arrow stays with the search field")
    func modifiedArrows_areLeftToTheField() {
        for modifier in [NSEvent.ModifierFlags.command, .option, .control, .shift] {
            #expect(
                intent(Self.arrow(.leftArrow, extraModifiers: modifier)) == nil,
                "\(modifier) + Left should reach the field so the query stays editable"
            )
        }
    }

    // MARK: - Return

    @Test("Return commits the cursor while the search field has focus")
    func return_commitsWhileEditing() {
        #expect(intent(Self.returnEvent, isEditingText: true) == .commit)
    }

    @Test("Return is left alone when a button has focus, so Cancel still cancels")
    func return_isLeftToAFocusedButton() {
        #expect(intent(Self.returnEvent, isEditingText: false) == nil)
    }

    @Test("Return commits whether or not a query has been typed")
    func return_commitsWithAndWithoutAQuery() {
        #expect(intent(Self.returnEvent, queryIsEmpty: true) == .commit)
        #expect(intent(Self.returnEvent, queryIsEmpty: false) == .commit)
    }

    // MARK: - Escape

    @Test("Escape on an empty query dismisses the picker")
    func escape_dismissesOnAnEmptyQuery() {
        #expect(intent(Self.escapeEvent, queryIsEmpty: true) == .dismiss)
    }

    @Test("Escape on a typed query belongs to the field, which clears it")
    func escape_isLeftToTheFieldWhileAQueryIsTyped() {
        #expect(intent(Self.escapeEvent, queryIsEmpty: false) == nil)
    }

    @Test("Escape dismisses from a focused button too")
    func escape_dismissesRegardlessOfFocus() {
        #expect(intent(Self.escapeEvent, isEditingText: false, queryIsEmpty: true) == .dismiss)
    }

    // MARK: - Everything else

    @Test("An ordinary character is left to the search field")
    func typing_isLeftToTheField() {
        for character in ["a", "s", ".", "1", " "] {
            #expect(intent(Self.event(characters: character)) == nil)
        }
    }

    @Test("Tab and Delete are not claimed")
    func otherSpecialKeys_areNotClaimed() {
        #expect(intent(Self.event(characters: "\t")) == nil)
        #expect(intent(Self.event(characters: "\u{7F}")) == nil)
    }

    @Test("The editing modifiers are named, not derived from the device-independent mask")
    func editingModifiers_excludeFunctionAndNumericPad() {
        #expect(!SymbolPickerKey.editingModifiers.contains(.function))
        #expect(!SymbolPickerKey.editingModifiers.contains(.numericPad))
        #expect(SymbolPickerKey.editingModifiers.contains(.command))
        #expect(SymbolPickerKey.editingModifiers.contains(.shift))
    }
}

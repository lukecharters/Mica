// App/SymbolPickerKey.swift
import AppKit

/// What a key press means to the symbol picker.
///
/// Pure and separate from the view so the decision can be tested: every rule below was
/// arrived at by driving the app on screen, and each one fails *silently* if it drifts —
/// a key the picker declines to handle behaves exactly like a picker with no keyboard
/// support at all.
enum SymbolPickerKey {
    enum Intent: Equatable {
        case move(SymbolGridNavigation.Direction)
        /// Apply the cursor and close.
        case commit
        /// Close without applying.
        case dismiss
    }

    /// Modifiers that mean the key belongs to the search field's text editing, so ⌥←
    /// still moves by word and ⇧← still selects.
    ///
    /// Deliberately **not** `.deviceIndependentFlagsMask`: every arrow key sets
    /// `.function` and `.numericPad`, so testing for "no modifiers at all" rejects the
    /// arrows this type exists to interpret.
    static let editingModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    private static let escape = "\u{1B}"

    /// - Parameters:
    ///   - isEditingText: whether the search field, rather than a button, has focus.
    ///   - queryIsEmpty: whether the search field is empty.
    static func intent(
        for event: NSEvent,
        isEditingText: Bool,
        queryIsEmpty: Bool
    ) -> Intent? {
        guard event.modifierFlags.intersection(editingModifiers).isEmpty else { return nil }

        switch event.specialKey {
        case .upArrow: return .move(.up)
        case .downArrow: return .move(.down)
        case .leftArrow: return .move(.left)
        case .rightArrow: return .move(.right)

        case .carriageReturn, .enter, .newline:
            // The field claims Return as a search submit, so the Select button's
            // `.defaultAction` never fires while the field has focus — and
            // `.onSubmit(of: .search)` does not fire on an empty query, which is exactly
            // the arrow-navigated case. Only claimed while the field has focus, so a
            // Return aimed at Cancel still cancels.
            return isEditingText ? .commit : nil

        default: break
        }

        // Escape on a query the field can clear is the field's own, and AppKit already
        // does it. Only an empty query closes the sheet.
        if event.charactersIgnoringModifiers == escape {
            return queryIsEmpty ? .dismiss : nil
        }

        return nil
    }
}

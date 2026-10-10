// App/ExportPanelOptions.swift
//
// The state behind the save panel's accessory view: the export settings,
// edited **for one export only**.
//
// The override is the whole point of the type. `spec` starts as a copy of the
// window's `ExportSpec` and nothing ever writes it back — so changing the size in
// the panel does not move the inspector's Size picker, does not register an undo
// entry (`settingsDidChange` observes `iconSettings`, which never sees this), and
// does not change what the drag-out or ⇧⌘C produce afterwards. The window's
// settings say what the icon *is*; this says what one file was asked for.
//
// Keeping `seed` alongside is what lets the accessory say so: a footnote appears
// only once the two disagree, rather than a permanent caption explaining a thing
// that has not happened.
import Foundation

struct ExportPanelOptions: Equatable {
    /// What the window's inspector says, captured when the panel opened.
    let seed: ExportSpec

    /// What this export will use. The accessory's controls bind straight into it.
    var spec: ExportSpec

    init(seed: ExportSpec) {
        self.seed = seed
        self.spec = seed
    }

    /// Whether this export differs from what the window is set to.
    ///
    /// Compares the whole spec rather than field by field, so a fourth export
    /// setting is covered the day it is added.
    var isOverridden: Bool { spec != seed }

    /// Discard the override and go back to the window's settings.
    mutating func reset() { spec = seed }

    /// The sizes the accessory's menu offers.
    var sizeChoices: [ExportSize] { ExportPreferences.sizeChoices(including: spec.exportSize) }

    /// The pixel dimensions this export will write, as `1024×1024px`.
    ///
    /// Built as a string and shown with `Text(verbatim:)`, deliberately: a
    /// `Text("\(Int(side))px")` literal is a `LocalizedStringKey`, whose `Int`
    /// interpolation applies locale grouping and renders 1024 as "1,024".
    var pixelDescription: String {
        // `.rounded()` rather than a bare `Int(_:)` truncation. Sizes are whole
        // numbers today, but `Int(0.29 * 100)` is 28 and this is the same shape.
        let side = Int(spec.pixelSize.rounded())
        return "\(side)×\(side)px"
    }
}

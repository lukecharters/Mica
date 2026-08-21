// App/ExportPanelOptions.swift
//
// The state behind the save panel's accessory view: the three export settings,
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
    var sizeChoices: [CGFloat] { Self.sizeChoices(including: spec.size) }

    /// `ExportPreferences.sizeChoices`, plus `size` itself when it is not one of
    /// them.
    ///
    /// A configuration file can carry any size in `ExportSpec.minSize...maxSize`,
    /// and a `Picker` whose selection matches no tag renders **empty** — so a
    /// window opened from a 300pt configuration would show a blank menu and lose
    /// the size the moment the user touched anything else. The odd size is offered
    /// in its sorted place instead.
    static func sizeChoices(including size: CGFloat) -> [CGFloat] {
        let choices = ExportPreferences.sizeChoices
        guard !choices.contains(size) else { return choices }
        return (choices + [size]).sorted()
    }

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

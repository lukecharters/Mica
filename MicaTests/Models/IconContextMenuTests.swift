// IconContextMenuTests.swift
// What a right-click offers, and what each row does. Item C2 of
// docs/plans/mac-conventions.md.
//
// The rows are tested rather than the menus because a context-menu row fails
// quietly in a way a view test could not see either: a row that should not have
// been offered looks exactly like one that should, and clicking it appears to do
// nothing at all. `IconContextMenu` exists as a pure type for that reason.

import Testing
import CoreGraphics
@testable import Mica

@Suite(.tags(.unit))
struct IconContextMenuTests {

    // MARK: - Fixtures

    private static let displaySize: CGFloat = 256

    private static func settingsWithBadge() -> IconSettings {
        var s = IconSettings()
        s.badge.isVisible = true
        s.badge.position = .bottomRight
        return s
    }

    /// Badge centre in canvas coordinates, from `BadgeGeometry` rather than a
    /// literal, so this cannot drift from the renderer.
    private static func badgeCentre(_ settings: IconSettings) -> CGPoint {
        let enclosure = PreviewHitTester.enclosureSize(displaySize: displaySize)
        let offset = BadgeGeometry.offset(for: settings, enclosureSize: enclosure)
        return CGPoint(x: displaySize / 2 + offset.width, y: displaySize / 2 + offset.height)
    }

    private static func edits(_ items: [IconContextItem]) -> [IconContextEdit] {
        items.compactMap { if case .edit(let e) = $0 { return e } else { return nil } }
    }

    private static func commands(_ items: [IconContextItem]) -> [IconContextCommand] {
        items.compactMap { if case .command(let c) = $0 { return c } else { return nil } }
    }

    // MARK: - Which group a click is about

    @Test("A click with no remembered pointer location is about the icon")
    func noHoverPoint_isTheIcon() {
        // `.contextMenu` supplies no location, so the group comes from the last
        // hover — and a menu opened before the pointer ever entered the canvas
        // has none. That resolves rather than special-casing.
        #expect(IconContextMenu.group(
            at: nil,
            settings: Self.settingsWithBadge(),
            displaySize: Self.displaySize,
            isSystem: false
        ) == .icon)
    }

    @Test("A click on the badge is about the badge")
    func badgeCentre_isTheBadge() {
        let s = Self.settingsWithBadge()
        #expect(IconContextMenu.group(
            at: Self.badgeCentre(s),
            settings: s,
            displaySize: Self.displaySize,
            isSystem: false
        ) == .badge)
    }

    @Test("A click that hits nothing is about the icon")
    func canvasCorner_isTheIcon() {
        // The canvas margin and the chiclet's rounded corners hit no layer, and
        // the icon is what a menu opened out there is about — the same rule
        // `PreviewDrop` follows.
        #expect(IconContextMenu.group(
            at: CGPoint(x: 1, y: 1),
            settings: Self.settingsWithBadge(),
            displaySize: Self.displaySize,
            isSystem: false
        ) == .icon)
    }

    @Test("A System-mode click routes through the System hit tester")
    func systemMode_resolvesTheBadgeSeparately() {
        var s = Self.settingsWithBadge()
        s.icon.mode = .system
        // The appex icon is one layer, but a Mica-composited badge over it still
        // has its own footprint — so `isSystem` changes which hit tester answers,
        // not whether the badge can be reached.
        #expect(IconContextMenu.group(
            at: Self.badgeCentre(s),
            settings: s,
            displaySize: Self.displaySize,
            isSystem: true
        ) == .badge)
        #expect(IconContextMenu.group(
            at: CGPoint(x: Self.displaySize / 2, y: Self.displaySize / 2),
            settings: s,
            displaySize: Self.displaySize,
            isSystem: true
        ) == .icon)
    }

    // MARK: - The canvas menu

    @Test("Copy and Export lead the canvas menu, and are gated together")
    func canvasMenu_exportRowsFollowCanExport() {
        let s = IconSettings()
        let available = IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true)
        #expect(Self.commands(available).prefix(2) == [.copyIcon, .exportPNG])

        // Both withdraw together while a System-mode layer's raster is pending —
        // the rule ⇧⌘E, ⇧⌘C and the drag-out already answer to. A menu row that
        // exported an icon with a layer missing would look like a successful
        // export.
        let pending = IconContextMenu.canvasItems(for: .icon, settings: s, canExport: false)
        #expect(!Self.commands(pending).contains(.copyIcon))
        #expect(!Self.commands(pending).contains(.exportPNG))
    }

    @Test("The canvas menu offers a paste for the clicked group, worded as the Edit menu words it")
    func canvasMenu_pasteNamesTheClickedGroup() {
        let s = Self.settingsWithBadge()
        #expect(Self.commands(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.pasteBackground(.icon)))
        #expect(Self.commands(IconContextMenu.canvasItems(for: .badge, settings: s, canExport: true))
            .contains(.pasteBackground(.badge)))

        // One command must not read two ways in two places, or it reads as two
        // commands. These are the Edit menu's titles verbatim.
        #expect(IconContextCommand.pasteBackground(.icon).title == "Paste as Icon Background")
        #expect(IconContextCommand.pasteBackground(.badge).title == "Paste as Badge Background")
    }

    @Test("Both layers are offered, in the Edit menu's order")
    func canvasMenu_offersBothLayersInAFixedOrder() {
        let s = Self.settingsWithBadge()
        for group in IconLayerGroup.allCases {
            let commands = Self.commands(
                IconContextMenu.canvasItems(for: group, settings: s, canExport: false)
            )
            // Background then symbol, matching Edit ▸ Paste as … — and *fixed*,
            // not led by whichever layer the pointer was over. The titles already
            // disambiguate, and rows that reorder by a sub-layer hit the user
            // cannot see are less predictable, not more.
            #expect(commands == [.pasteBackground(group), .pasteForeground(group)])
        }
        #expect(IconContextCommand.pasteForeground(.icon).title == "Paste as Icon Symbol")
        #expect(IconContextCommand.pasteForeground(.badge).title == "Paste as Badge Symbol")
    }

    @Test("A System-mode group is offered no layer rows at all")
    func systemMode_hasNoLayerRows() throws {
        var s = IconSettings()
        s.icon.mode = .system
        s.icon.background.apply(try .testFixture())
        s.icon.foreground.apply(try .testFixture())

        let items = IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true)
        // The appex pipeline takes a symbol and two colours and ignores every
        // background *and* imported-symbol key, so all four of these would be rows
        // that quietly do nothing.
        #expect(!Self.commands(items).contains(.pasteBackground(.icon)))
        #expect(!Self.commands(items).contains(.pasteForeground(.icon)))
        #expect(!Self.edits(items).contains(.removeBackgroundImage(.icon)))
        #expect(!Self.edits(items).contains(.removeForegroundImage(.icon)))
        // The group can still be hidden, which does work in System mode.
        #expect(Self.edits(items).contains(.setGroupHidden(.icon, true)))
    }

    @Test("Remove Imported Symbol appears only once the foreground holds artwork")
    func removeForegroundRow_needsAnImage() throws {
        var s = Self.settingsWithBadge()
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .badge, settings: s, canExport: true))
            .contains(.removeForegroundImage(.badge)))

        // Same two-part gate as the background's: the Type picker writes the source
        // before a file is chosen, and the layer draws its symbol in that state.
        s.badge.foreground.source = .image
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .badge, settings: s, canExport: true))
            .contains(.removeForegroundImage(.badge)))

        s.badge.foreground.image = try .testFixture()
        #expect(Self.edits(IconContextMenu.canvasItems(for: .badge, settings: s, canExport: true))
            .contains(.removeForegroundImage(.badge)))
        // And it is that group's row, not the other's.
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.removeForegroundImage(.icon)))
    }

    @Test("A sidebar row can remove either of its group's imported layers")
    func sidebarMenu_offersBothRemovals() throws {
        var s = IconSettings()
        s.icon.applyBackgroundImage(try .testFixture())
        s.icon.foreground.apply(try .testFixture())

        let edits = Self.edits(IconContextMenu.sidebarItems(for: .icon, settings: s))
        #expect(edits.contains(.removeBackgroundImage(.icon)))
        #expect(edits.contains(.removeForegroundImage(.icon)))
    }

    @Test("Remove appears only once there is artwork to remove")
    func removeRow_needsAnImage() throws {
        var s = IconSettings()
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.removeBackgroundImage(.icon)))

        // `source == .image` alone is what the inspector's Type picker writes
        // before any file is chosen, and the layer falls back to its colour in
        // that state — so the row would offer to remove something not there.
        s.icon.background.source = .image
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.removeBackgroundImage(.icon)))

        s.icon.background.image = try .testFixture()
        #expect(Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.removeBackgroundImage(.icon)))
    }

    @Test("Reset Badge Position appears only for a badge that has been nudged")
    func resetBadgePosition_needsAnOffset() {
        var s = Self.settingsWithBadge()
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .badge, settings: s, canExport: true))
            .contains(.resetBadgePosition))

        s.badge.offsetY = -0.02
        #expect(Self.edits(IconContextMenu.canvasItems(for: .badge, settings: s, canExport: true))
            .contains(.resetBadgePosition))

        // Never on the icon, whose group has no offset to reset.
        #expect(!Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.resetBadgePosition))
    }

    @Test("The visibility row offers the opposite of the current state")
    func visibilityRow_flipsWithTheGroup() {
        var s = IconSettings()
        #expect(Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.setGroupHidden(.icon, true)))
        #expect(IconContextEdit.setGroupHidden(.icon, true).title == "Hide Icon Layers")

        s.icon.isHidden = true
        #expect(Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.setGroupHidden(.icon, false)))
        #expect(IconContextEdit.setGroupHidden(.icon, false).title == "Show Icon Layers")
    }

    @Test("A partly hidden group offers Hide, matching the sidebar's eye")
    func mixedVisibility_offersHide() {
        var s = IconSettings()
        s.icon.foreground.isHidden = true
        #expect(s.icon.visibility == .mixed)
        // The group eye hides everything from `.mixed`; a menu row that showed
        // everything instead would be a second answer to one question.
        #expect(Self.edits(IconContextMenu.canvasItems(for: .icon, settings: s, canExport: true))
            .contains(.setGroupHidden(.icon, true)))
    }

    // MARK: - Separators

    @Test("No menu shape has a leading, trailing or doubled separator", arguments: [true, false])
    func separatorsAreNeverStranded(canExport: Bool) throws {
        var shapes: [IconSettings] = [IconSettings(), Self.settingsWithBadge()]

        var system = IconSettings()
        system.icon.mode = .system
        shapes.append(system)

        var imported = Self.settingsWithBadge()
        imported.icon.applyBackgroundImage(try .testFixture())
        imported.badge.applyBackgroundImage(try .testFixture())
        shapes.append(imported)

        var allFourLayersImported = Self.settingsWithBadge()
        allFourLayersImported.icon.applyBackgroundImage(try .testFixture())
        allFourLayersImported.badge.applyBackgroundImage(try .testFixture())
        allFourLayersImported.icon.foreground.apply(try .testFixture())
        allFourLayersImported.badge.foreground.apply(try .testFixture())
        shapes.append(allFourLayersImported)

        var hidden = Self.settingsWithBadge()
        hidden.icon.isHidden = true
        hidden.badge.isHidden = true
        shapes.append(hidden)

        var nudged = Self.settingsWithBadge()
        nudged.badge.offsetX = 0.05
        shapes.append(nudged)

        for settings in shapes {
            for group in IconLayerGroup.allCases {
                let menus = [
                    IconContextMenu.canvasItems(for: group, settings: settings, canExport: canExport),
                    IconContextMenu.sidebarItems(for: group, settings: settings),
                ]
                for items in menus {
                    #expect(items.first != .separator)
                    #expect(items.last != .separator)
                    for (previous, next) in zip(items, items.dropFirst()) {
                        #expect(!(previous == .separator && next == .separator))
                    }
                    #expect(!items.isEmpty)
                }
            }
        }
    }

    // MARK: - The sidebar menu

    @Test("A sidebar menu holds no command rows")
    func sidebarMenu_needsNoHandler() throws {
        // The sidebar passes no `PreviewContextActions`, so a command row there
        // would log and do nothing. This is the invariant that lets it not thread
        // a handler it has no use for.
        var s = Self.settingsWithBadge()
        s.icon.applyBackgroundImage(try .testFixture())
        for group in IconLayerGroup.allCases {
            #expect(Self.commands(IconContextMenu.sidebarItems(for: group, settings: s)).isEmpty)
        }
    }

    @Test("Reset is the sidebar menu's last row, and appears nowhere else")
    func resetGroup_isSidebarOnly() {
        let s = Self.settingsWithBadge()
        for group in IconLayerGroup.allCases {
            let items = IconContextMenu.sidebarItems(for: group, settings: s)
            #expect(items.last == .edit(.resetGroup(group)))
            // Kept off the canvas deliberately: it is the more destructive row of
            // the two, and a right-click on the artwork is the likelier misaim.
            #expect(!Self.edits(IconContextMenu.canvasItems(for: group, settings: s, canExport: true))
                .contains(.resetGroup(group)))
        }
    }

    @Test("A sidebar row can remove that group's imported background")
    func sidebarMenu_offersRemove() throws {
        var s = Self.settingsWithBadge()
        s.badge.applyBackgroundImage(try .testFixture())
        #expect(Self.edits(IconContextMenu.sidebarItems(for: .badge, settings: s))
            .contains(.removeBackgroundImage(.badge)))
        #expect(!Self.edits(IconContextMenu.sidebarItems(for: .icon, settings: s))
            .contains(.removeBackgroundImage(.icon)))
    }

    // MARK: - Applying an edit

    @Test("Hiding a group writes both its layers")
    func setGroupHidden_writesBothLayers() {
        var s = IconSettings()
        s.icon.foreground.isHidden = true          // a per-layer flag left behind
        IconContextMenu.apply(.setGroupHidden(.icon, false), to: &s)
        #expect(s.icon.foreground.isHidden == false)
        #expect(s.icon.background.isHidden == false)
    }

    @Test("Reset Badge Position zeroes the nudge and leaves the anchor alone")
    func resetBadgePosition_keepsThePosition() {
        var s = Self.settingsWithBadge()
        s.badge.position = .topLeft
        s.badge.offsetX = 0.12
        s.badge.offsetY = -0.07

        IconContextMenu.apply(.resetBadgePosition, to: &s)

        #expect(s.badge.offsetX == 0)
        #expect(s.badge.offsetY == 0)
        // `position` is a picker the user set on purpose; the offsets are what a
        // drag or an arrow press accumulates. Only the second is what "reset
        // position" can mean without discarding a choice.
        #expect(s.badge.position == .topLeft)
    }
}

// MARK: - The model operations behind two of the rows

@Suite(.tags(.unit))
struct RemoveBackgroundImageTests {

    @Test("Removing an icon background undoes every guess the import made")
    func iconRemove_isTheInverseOfApply() throws {
        var s = IconSettings()
        s.icon.background.cornerRadiusStyle = .macOS26
        s.icon.applyBackgroundImage(try .testFixture(), defaults: .fixed)
        // What the import changed.
        #expect(s.icon.background.source == .image)
        #expect(s.icon.background.compensatesForPadding == true)
        #expect(s.icon.background.shadowStyle == .off)
        #expect(s.icon.background.cornerRadiusStyle == .off)
        #expect(s.icon.foreground.isHidden == true)

        s.icon.removeBackgroundImage()

        let fresh = IconBackgroundSpec()
        #expect(s.icon.background.image == nil)
        #expect(s.icon.background.source == fresh.source)
        #expect(s.icon.background.compensatesForPadding == fresh.compensatesForPadding)
        #expect(s.icon.background.shadowStyle == fresh.shadowStyle)
        #expect(s.icon.background.cornerRadiusStyle == fresh.cornerRadiusStyle)
        // The reason the row exists: an imported background hides the foreground,
        // so removing the artwork without putting it back leaves an empty layer.
        #expect(s.icon.foreground.isHidden == false)
    }

    @Test("Removing a background keeps the colour the layer had before the import")
    func remove_keepsTheColourChoices() throws {
        var s = IconSettings()
        s.icon.background.color = .token("orange")
        s.icon.background.usesCustomGradient = true
        s.icon.background.gradientStartColor = .token("pink")
        s.icon.applyBackgroundImage(try .testFixture())

        s.icon.removeBackgroundImage()

        // An import never touched these, so removing the artwork must not reset
        // them — it returns the layer to the colour it had, not to blue.
        #expect(s.icon.background.color.tokenName == "orange")
        #expect(s.icon.background.usesCustomGradient == true)
        #expect(s.icon.background.gradientStartColor.tokenName == "pink")
    }

    @Test("Removing a badge background does not resurrect a hidden badge")
    func badgeRemove_leavesAHiddenBadgeHidden() throws {
        var s = IconSettings()
        #expect(s.badge.isVisible == false)
        // Reaching this state needs an import onto a badge nobody switched on.
        s.badge.applyBackgroundImage(try .testFixture())

        s.badge.removeBackgroundImage()

        // Unhiding the foreground here would make the badge appear out of a row
        // called Remove — `isVisible` is "either layer showing".
        #expect(s.badge.isVisible == false)
    }

    @Test("Removing imported foreground artwork brings back the exact symbol")
    func foregroundRemove_restoresTheSymbol() throws {
        var s = IconSettings()
        s.icon.foreground.symbolName = "bolt.fill"
        s.icon.foreground.symbolScale = 1.4
        s.icon.foreground.apply(try .testFixture())
        #expect(s.icon.foreground.source == .image)
        #expect(s.icon.foreground.drawsShadow == false)

        s.icon.foreground.removeImage()

        // The lossless one of the three removals: an image import never touched
        // `symbolName`, so the symbol comes back rather than being reconstructed.
        #expect(s.icon.foreground.symbolName == "bolt.fill")
        #expect(s.icon.foreground.source == .symbol)
        #expect(s.icon.foreground.image == nil)
        #expect(s.icon.foreground.drawsShadow == true)
        // Untouched by either direction — it is not one of the import's guesses.
        #expect(s.icon.foreground.symbolScale == 1.4)
    }

    @Test("Removing foreground artwork does not change the layer's visibility")
    func foregroundRemove_leavesVisibilityAlone() throws {
        var s = IconSettings()
        // The state a background import leaves behind: foreground hidden, and now
        // also holding artwork of its own.
        s.icon.applyBackgroundImage(try .testFixture())
        s.icon.foreground.apply(try .testFixture())
        #expect(s.icon.foreground.isHidden == true)

        s.icon.foreground.removeImage()

        // Unlike the two background removals, there is no hide guess to reverse
        // here — a foreground import hides nothing.
        #expect(s.icon.foreground.isHidden == true)
    }

    @Test("Removing a visible badge's background puts its symbol back")
    func badgeRemove_restoresTheGlyph() throws {
        var s = IconSettings()
        s.badge.isVisible = true
        s.badge.applyBackgroundImage(try .testFixture())
        #expect(s.badge.foreground.isHidden == true)

        s.badge.removeBackgroundImage()

        #expect(s.badge.foreground.isHidden == false)
        #expect(s.badge.background.source == .color)
        #expect(s.badge.background.drawsShadow == true)
        #expect(s.badge.isVisible == true)
    }
}

@Suite(.tags(.unit))
struct ResetGroupTests {
    @Test("Resetting the icon restores its appearance but not its mode or visibility")
    func iconReset_keepsModeAndVisibility() throws {
        var s = IconSettings()
        s.icon.mode = .system
        s.icon.isHidden = true
        s.icon.foreground.symbolName = "bolt.fill"
        s.icon.foreground.symbolScale = 1.8
        s.icon.background.color = .token("orange")
        s.icon.applyBackgroundImage(try .testFixture())

        s.icon.reset()

        #expect(s.icon.foreground.symbolName == ForegroundSpec.iconDefault.symbolName)
        #expect(s.icon.foreground.symbolScale == ForegroundSpec.iconDefault.symbolScale)
        #expect(s.icon.background.color == IconBackgroundSpec().color)
        #expect(s.icon.background.image == nil)
        #expect(s.icon.background.source == .color)
        // The mode says which pipeline draws the group, not what it looks like; a
        // reset that silently left System mode would read as having failed.
        #expect(s.icon.mode == .system)
        // And a reset should not decide whether the group is on screen.
        #expect(s.icon.isHidden == true)
    }

    @Test("Resetting the badge does not delete it")
    func badgeReset_keepsAVisibleBadgeVisible() {
        var s = IconSettings()
        s.badge.isVisible = true
        s.badge.position = .topLeft
        s.badge.scale = 1.4
        s.badge.offsetX = 0.2
        s.badge.foreground.symbolName = "bolt.fill"

        s.badge.reset()

        #expect(s.badge.position == BadgeSpec().position)
        #expect(s.badge.scale == BadgeSpec().scale)
        #expect(s.badge.offsetX == 0)
        #expect(s.badge.foreground.symbolName == ForegroundSpec.badgeDefault.symbolName)
        // A fresh `BadgeSpec` has both layers hidden, so restoring the defaults
        // wholesale would make Reset Badge delete the badge.
        #expect(s.badge.isVisible == true)
    }

    @Test("Resetting a System-mode badge leaves it in System mode")
    func badgeReset_keepsSystemMode() {
        var s = IconSettings()
        s.badge.isVisible = true
        s.badge.mode = .system
        #expect(s.badge.foreground.source == .system)

        s.badge.reset()

        // The badge's mode is *derived* from its foreground source, so a reset
        // that restored the default source would silently switch pipelines.
        #expect(s.badge.mode == .system)
        #expect(s.badge.isVisible == true)
    }
}

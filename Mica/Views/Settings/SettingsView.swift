// Views/Settings/SettingsView.swift
import SwiftUI

/// The ⌘, window.
///
/// macOS supplies the **Mica ▸ Settings…** item, its shortcut and the window title
/// for a `Settings` scene, so nothing in `MicaApp`'s `.commands` block mentions it —
/// and ⌘, is not in the project-structure notes's shortcut table for the same
/// reason: it is not ours to bind.
///
/// The first three tabs split by **when a preference takes effect**, not by how
/// advanced it is:
///
/// - **General** changes the inspector you are looking at right now.
/// - **Export** seeds the next window you open, and leaves open ones alone.
/// - **Importing** changes what importing a background does to the layer over it.
///
/// **Developer** is a fourth answer rather than one of those three: it takes
/// effect on the menu bar, and on which calibration the renderer reads.
///
/// That third tab is called Importing rather than the plan's "Advanced": *Advanced*
/// next to a General tab whose only control is Show Advanced **Controls** reads as
/// one setting split across two tabs, and "Importing" is what the two switches are
/// actually about.
///
/// Every key here was already shipping and reachable only by editing the defaults
/// domain by hand — see §2.2 of the Mac-conventions plan, which is the debt
/// this window pays off.
struct SettingsView: View {
    private enum Tab: Hashable { case general, export, importing, developer }

    @State private var selection: Tab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)

            ExportDefaultsSettingsTab()
                // Matches the inspector's own Export button glyph.
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
                .tag(Tab.export)

            ImportSettingsTab()
                .tabItem { Label("Importing", systemImage: "square.and.arrow.down") }
                .tag(Tab.importing)

            DeveloperSettingsTab()
                .tabItem { Label("Developer", systemImage: "hammer") }
                .tag(Tab.developer)
        }
        // Width fixed, height intrinsic: a settings window that resizes between tabs
        // is the platform norm, one that changes width is not.
        .frame(width: 480)
    }
}

// MARK: - General

/// Just the advanced-controls flag, which is the one preference that changes the
/// window you are already looking at. It sat at the bottom of the inspector until
/// 2026-08-04 — a preference wearing a control's clothes, inside the very panel it
/// reconfigures.
///
/// **The label is a fixed string.** "Show Advanced Controls" is the name the gate
/// tables at the top of `wiki/Icon-Settings.md` and `wiki/Badge-Settings.md` use, and
/// the toolbar toggle and View menu spell it the same way; renaming it here would
/// strand all four.
///
/// The two captions follow the `write-mica-user-docs` prose rules — one idea per
/// sentence, active voice, answer before reason — because user-facing text in the app
/// and user-facing text in the wiki are the same body of writing.
struct GeneralSettingsTab: View {
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $advancedControlsEnabled) {
                    Text("Show Advanced Controls")
                    // A caption inside the Toggle's label rather than a sibling
                    // `Text`, so VoiceOver reads it as part of the switch.
                    Text("Shows a Foreground and a Background layer for each group. "
                         + "Each layer gets its own controls. Off shows one pane per group.")
                }
            } header: {
                Text("Inspector")
            } footer: {
                // `revealAdvancedControlsIfNeeded()` flips this out from under the
                // user. Unexplained, that reads as a bug in this window.
                Text("Importing an image switches this on. The simple pane has no "
                     + "controls for imported artwork.")
                    .settingsFooter()
            }
        }
        .settingsForm()
    }
}

// MARK: - Export

/// Default export size and colour space — the two settings a repeat user re-sets on
/// every launch, because Mica keeps nothing between them.
///
/// Named `ExportDefaultsSettingsTab` rather than `ExportSettingsTab` to stay clear of
/// `ExportSettingsSection`, the inspector tab editing the *current* icon's export
/// settings. The two look alike and mean different things.
struct ExportDefaultsSettingsTab: View {
    @AppStorage(ExportPreferences.defaultSizeKey)
    private var defaultSize = Double(ExportSpec.defaultSize)

    @AppStorage(ExportPreferences.defaultColorSpaceKey)
    private var defaultColorSpace = ExportColorSpace.sRGB

    var body: some View {
        Form {
            // "New Icons" carries the word "default" once, so the rows below can be
            // spelled exactly as the inspector spells them.
            Section {
                Picker("Size", selection: $defaultSize) {
                    ForEach(ExportPreferences.sizeChoices, id: \.self) { size in
                        // See `ExportSettingsSection` — without `verbatim:` this is
                        // a `LocalizedStringKey` and 1024 renders as "1,024pt".
                        Text(verbatim: "\(Int(size))pt").tag(Double(size))
                    }
                }

                Picker("Color Space", selection: $defaultColorSpace) {
                    ForEach(ExportColorSpace.allCases) { colorSpace in
                        Text(colorSpace.displayName).tag(colorSpace)
                    }
                }

                Text(colorSpaceDescription)
                    .settingsFooter()
            } header: {
                Text("New Icons")
            } footer: {
                // The load-bearing line. Mica keeps nothing between launches, so a
                // repeat user's first question is whether this touched the icon they
                // are looking at. It didn't.
                Text("New windows start here. Windows already open keep their own settings.")
                    .settingsFooter()
            }
        }
        .settingsForm()
    }

    /// Word for word what the inspector's Color Space section says, so the same
    /// choice is not explained two ways in one app.
    ///
    /// **`LocalizedStringKey`, not `String`.** Both strings are in
    /// `Localizable.xcstrings` with all seven variants, and both say *color* — so
    /// returning a `String` here hands `Text` its verbatim overload and the en-GB
    /// spelling never resolves. The catalog entry looks correct while the app shows the
    /// American word, which is the failure the type is the only guard against.
    private var colorSpaceDescription: LocalizedStringKey {
        switch defaultColorSpace {
        case .sRGB: return "Standard color space for web and most displays."
        case .displayP3: return "Wider color gamut for modern Apple displays."
        }
    }
}

// MARK: - Importing

/// The two import defaults, shipped with no UI on 2026-08-03 on the understanding
/// that this window would close that gap.
///
/// Both are guesses Mica makes on your behalf, both are reversible on the icon
/// itself, and both are wrong every time for one specific workflow — which is what
/// earns them a preference rather than a better guess.
struct ImportSettingsTab: View {
    @AppStorage(InspectorPreferences.hidesForegroundOnBackgroundImportKey)
    private var hidesForeground = true

    @AppStorage(InspectorPreferences.turnsOffCornerRadiusOnBackgroundImportKey)
    private var turnsOffCornerRadius = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hidesForeground) {
                    Text("Hide the Foreground on Import")
                    Text("Hides the symbol when you import a background image. A "
                         + "background image is usually a finished icon. Turn this off "
                         + "to put a symbol on your own artwork.")
                }

                // Names the control it moves — the Corners picker, its Off case — so
                // the user can go and undo it.
                Toggle(isOn: $turnsOffCornerRadius) {
                    Text("Set Corners to Off on Import")
                    Text("Turns corner rounding off for imported artwork. Rounding cuts "
                         + "the corners from artwork that fills its own bounds. Turn "
                         + "this off to clip a photo or texture to the icon's shape.")
                }
            } header: {
                Text("Imported Backgrounds")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You can change both on the icon itself. The sidebar eye shows "
                         + "a hidden foreground again. Corners sits in the icon's "
                         + "Background tab.")

                    // The honest version of `ImportDefaults` being split across
                    // targets. Without it, someone who turns both off and then runs
                    // the CLI gets a different icon with no way to know why.
                    Text("These settings apply to Mica only. mica-cli always hides the "
                         + "foreground and sets Corners to Off. Imported configurations "
                         + "do the same. One configuration then renders the same way "
                         + "everywhere.")
                }
                .settingsFooter()
            }
        }
        .settingsForm()
    }
}

// MARK: - Developer

/// The switch that puts the Developer menu in the menu bar — the calibration and
/// comparison tools Mica is built with, which were excluded from Release builds
/// entirely until 2026-08-21.
///
/// **The honest framing is a maintainer's switch, not a feature.** These tools
/// have no user-facing job: they exist to measure Apple's own icon rendering and
/// to calibrate how Mica sizes SF Symbols against it. Two things the footer has
/// to say, because neither is guessable:
///
/// - The calibration tool **writes the file the renderer reads**. That is gated on
///   this same preference, so it cannot affect anyone who leaves it off.
/// - Symbol sizing is read **once per launch**, so turning this off does not
///   un-apply an override that has already been written until Mica is relaunched.
struct DeveloperSettingsTab: View {
    @AppStorage(DeveloperToolsPreference.enabledKey) private var developerToolsEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $developerToolsEnabled) {
                    Text("Show the Developer Menu")
                    Text("Adds a Developer menu to the menu bar. It holds the symbol "
                         + "calibration, reference comparison and metrics tools. None "
                         + "of its items has a keyboard shortcut.")
                }
            } header: {
                Text("Developer Tools")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You do not need these tools to make icons. They are not "
                         + "supported. Symbol Calibration changes how Mica sizes "
                         + "symbols in every icon you make. Mica only reads that "
                         + "change while this setting is on.")

                    Text("Mica reads symbol sizing once when it starts. Quit and "
                         + "reopen Mica to apply a change to this setting. Click "
                         + "Restore Bundled Calibration in that window to undo a "
                         + "calibration.")
                }
                .settingsFooter()
            }
        }
        .settingsForm()
    }
}

// MARK: - Shared styling

private extension View {
    /// One place for the form styling, so four tabs cannot drift apart.
    func settingsForm() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Footers are explanation, not label: secondary, and allowed to wrap.
    func settingsFooter() -> some View {
        font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("General") {
    GeneralSettingsTab().frame(width: 480)
}

#Preview("Export") {
    ExportDefaultsSettingsTab().frame(width: 480)
}

#Preview("Importing") {
    ImportSettingsTab().frame(width: 480)
}

#Preview("Developer") {
    DeveloperSettingsTab().frame(width: 480)
}

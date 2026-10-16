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
                    Text("Shows separate Foreground and Background layers for each group.")
                }
            } header: {
                Text("Inspector")
            } footer: {
                // `revealAdvancedControlsIfNeeded()` flips this out from under the
                // user. Unexplained, that reads as a bug in this window.
                Text("Importing an image turns this on. Imported artwork needs these controls.")
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

    @AppStorage(ExportPreferences.defaultScaleKey)
    private var defaultScale = ExportScale.oneX

    @AppStorage(ExportPreferences.defaultColorSpaceKey)
    private var defaultColorSpace = ExportColorSpace.sRGB

    /// The two stored halves as the one value the menu picks.
    private var defaultExportSize: Binding<ExportSize> {
        Binding {
            ExportSize(points: CGFloat(defaultSize), scale: defaultScale)
        } set: { size in
            defaultSize = Double(size.points)
            defaultScale = size.scale
        }
    }

    var body: some View {
        Form {
            // The header carries the word "default" once, so the rows below can be
            // spelled exactly as the inspector spells them.
            Section {
                Picker("Size", selection: defaultExportSize) {
                    ForEach(ExportPreferences.sizeChoices(including: defaultExportSize.wrappedValue),
                            id: \.self) { size in
                        // See `ExportSettingsSection` — without `verbatim:` this is
                        // a `LocalizedStringKey` and 1024 renders as "1,024pt".
                        Text(verbatim: size.displayName).tag(size)
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
                Text("Defaults for New Windows")
            } footer: {
                // The load-bearing line. Mica keeps nothing between launches, so a
                // repeat user's first question is whether this touched the icon they
                // are looking at. It didn't.
                Text("Windows already open keep their own settings.")
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
                    Text("Hide Foreground")
                    Text("An imported background is usually a finished icon. Turn this off to add a symbol to your own artwork.")
                }

                // Names the control it moves — the Corners picker, its Off case — so
                // the user can go and undo it.
                Toggle(isOn: $turnsOffCornerRadius) {
                    Text("Turn Off Corners")
                    Text("Keeps rounded corners from clipping the artwork. Turn this off to round a photo or texture to the icon's shape.")
                }
            } header: {
                Text("When Importing a Background")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To undo either one, click the eye in the sidebar or change Corners on the icon's Background layer.")

                    // The honest version of `ImportDefaults` being split across
                    // targets. Without it, someone who turns both off and then runs
                    // the CLI gets a different icon with no way to know why.
                    Text("mica-cli and imported configurations ignore these settings. They always hide the foreground and turn off corners.")
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
                    Text("Show Developer Menu")
                    Text("Adds the symbol calibration and reference comparison tools to the menu bar.")
                }
            } header: {
                Text("Developer Tools")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These tools are unsupported and not needed to make icons.")

                    Text("Symbol Calibration can change how symbols are sized in every icon. That change applies only while this setting is on. Quit and reopen Mica after you change this setting.")

                    Text("To undo a calibration, click Restore Bundled Calibration in Symbol Calibration.")
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

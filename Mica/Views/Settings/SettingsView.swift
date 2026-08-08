// Views/Settings/SettingsView.swift
import SwiftUI

/// The ⌘, window.
///
/// macOS supplies the **Mica ▸ Settings…** item, its shortcut and the window title
/// for a `Settings` scene, so nothing in `MicaApp`'s `.commands` block mentions it —
/// and ⌘, is not in the project-structure notes's shortcut table for the same
/// reason: it is not ours to bind.
///
/// The three tabs split by **when a preference takes effect**, not by how advanced
/// it is:
///
/// - **General** changes the inspector you are looking at right now.
/// - **Export** seeds the next window you open, and leaves open ones alone.
/// - **Importing** changes what importing a background does to the layer over it.
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
    private enum Tab: Hashable { case general, export, importing }

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
/// **The label is a fixed string.** "Show Advanced Controls" is named that way in
/// `wiki/App-Guide.md` and `wiki/Getting-Started.md`; renaming it on the way into
/// Settings would strand both.
struct GeneralSettingsTab: View {
    @AppStorage(InspectorPreferences.advancedControlsKey) private var advancedControlsEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $advancedControlsEnabled) {
                    Text("Show Advanced Controls")
                    // A caption inside the Toggle's label rather than a sibling
                    // `Text`, so VoiceOver reads it as part of the switch.
                    Text("Splits each group into Foreground and Background layers, "
                         + "with every per-layer control. Off keeps one pane per group.")
                }
            } header: {
                Text("Inspector")
            } footer: {
                // `revealAdvancedControlsIfNeeded()` flips this out from under the
                // user. Unexplained, that reads as a bug in this window.
                Text("Importing an image switches this on, because the simple pane "
                     + "has no controls for imported artwork.")
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
    private var colorSpaceDescription: String {
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
                    Text("A background image is usually a finished icon, so the symbol "
                         + "over it is hidden. Turn this off if you import artwork to "
                         + "put a symbol on top.")
                }

                // Names the control it moves — the Corners picker, its Off case — so
                // the user can go and undo it.
                Toggle(isOn: $turnsOffCornerRadius) {
                    Text("Set Corners to Off on Import")
                    Text("Artwork that fills its own bounds loses its corners to any "
                         + "rounding. Turn this off for a texture or photo that should "
                         + "be clipped to the icon's shape.")
                }
            } header: {
                Text("Imported Backgrounds")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Both are starting points, not decisions: the eye brings a "
                         + "hidden foreground back, and Corners is in the icon's "
                         + "Background tab.")

                    // The honest version of `ImportDefaults` being split across
                    // targets. Without it, someone who turns both off and then runs
                    // the CLI gets a different icon with no way to know why.
                    Text("These apply to Mica only. mica-cli and imported "
                         + "configurations always hide the foreground and set Corners "
                         + "to Off, so one configuration renders the same everywhere.")
                }
                .settingsFooter()
            }
        }
        .settingsForm()
    }
}

// MARK: - Shared styling

private extension View {
    /// One place for the form styling, so three tabs cannot drift apart.
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

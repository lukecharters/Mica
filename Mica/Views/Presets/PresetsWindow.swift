// Views/Presets/PresetsWindow.swift
//
// The presets library as a window of its own — the Content Hub to the toolbar
// popovers' insert menus. One scope at a time, chosen by the selector across the top;
// a search field; and within the scope two sections, the presets Mica ships and the
// ones the user saved.
//
// **It applies to `PresetTarget.shared`**, the icon window that was key last, not to
// whichever window is key now — while the user clicks in here, this window is key and
// every focused value is nil. With no target it still browses and still deletes; only
// applying and saving need an icon, and a notice above the grid says so.
//
// **Its errors are its own.** A delete or a reload can fail with no icon window open
// at all, so this window presents its own `UserMessage` rather than borrowing a view
// model's. A save goes through the target's view model, whose alert is on the icon
// window — the save is that window's icon, and that window's undo stack.

import SwiftUI

struct PresetsWindow: View {
    static let id = "presets"

    private let library = PresetLibrary.shared
    private let target = PresetTarget.shared
    private let request = PresetsWindowRequest.shared

    /// The scope on show. Seeded by whichever popover footer opened the window; ⌃⌘P
    /// leaves it as it was.
    @State private var scope: PresetScope = .icon
    @State private var query = ""
    /// Non-nil while the save sheet is up, carrying the scope it will save.
    @State private var savePresetScope: PresetScope?
    @State private var message: UserMessage?

    /// Per-section folds, persisted: a folded section is a lasting preference about
    /// the shape of the window, like the inspector's thirteen.
    @AppStorage("presetsWindow.builtIn.expanded") private var builtInExpanded = true
    @AppStorage("presetsWindow.yours.expanded") private var yoursExpanded = true

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                selector
                    .padding(.horizontal, PresetGridMetrics.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                if target.handle == nil {
                    noTargetNotice
                        .padding(.horizontal, PresetGridMetrics.horizontalPadding)
                        .padding(.bottom, 10)
                }

                ScrollView {
                    sections
                        .padding(.horizontal, PresetGridMetrics.horizontalPadding)
                        .padding(.vertical, 8)
                }
            }
            .searchable(text: $query, prompt: "Search Presets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    saveButton
                }
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            adoptRequestedScope()
            reload()
        }
        .onChange(of: request.generation) { adoptRequestedScope() }
        .sheet(item: $savePresetScope) { scope in
            SavePresetSheet(
                scope: scope,
                existing: library.all,
                onSave: { savePreset(named: $0, scope: scope) },
                onCancel: { savePresetScope = nil }
            )
        }
        .alert(
            message?.title ?? "",
            isPresented: messageIsPresented,
            presenting: message
        ) { _ in
            Button("OK", role: .cancel) { message = nil }
        } message: { message in
            Text(message.message)
        }
    }

    // MARK: - The selector

    /// Icon or Badge, drawn as tabs: two views of one library, not two values of a
    /// setting. Bounded rather than filling the window, so a wide window does not
    /// stretch two words across it.
    private var selector: some View {
        FillingSegmentedPicker(
            segments: PresetScope.allCases.map { .init($0.segmentTitle, value: $0) },
            selection: $scope,
            accessibilityLabel: String(localized: "Preset Scope"),
            role: .tabs
        )
        .frame(maxWidth: 280)
    }

    // MARK: - The notice

    private var noTargetNotice: some View {
        Label("Open an icon window to apply a preset.", systemImage: "macwindow")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - The sections

    @ViewBuilder
    private var sections: some View {
        let rows = PresetSearch.filter(library.resolved, scope: scope, query: query)
        let builtIn = rows.filter { !$0.isUserPreset }
        let yours = rows.filter(\.isUserPreset)

        if rows.isEmpty && isSearching {
            ContentUnavailableView.search(text: query)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                // A section with no matches is left out of a search rather than shown
                // empty; without a search every section is shown, so the user can see
                // that "Yours" exists before they have saved anything.
                if !builtIn.isEmpty || !isSearching {
                    section("Built-in", rows: builtIn, isExpanded: $builtInExpanded)
                }
                if !yours.isEmpty || !isSearching {
                    section("Yours", rows: yours, isExpanded: $yoursExpanded)
                }
            }
        }
    }

    @ViewBuilder
    private func section(
        _ title: LocalizedStringKey,
        rows: [ResolvedPreset],
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PresetSectionHeader(title, isExpanded: isExpanded)

            if isExpanded.wrappedValue {
                if rows.isEmpty {
                    Text(scope == .icon
                         ? "No saved icon presets yet. Click + to save the current icon."
                         : "No saved badge presets yet. Click + to save the current badge.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    PresetGrid(rows: rows, onApply: apply, onDelete: deletePreset)
                        // Dimmed, not disabled: the context menu's Delete has to keep
                        // working with no icon window, and `.disabled` would take it.
                        .opacity(target.handle == nil ? 0.5 : 1)
                }
            }
        }
    }

    // MARK: - The toolbar

    /// The `+`, saving into the scope on show. Off with no icon window to capture, and
    /// off for a badge preset while the target's badge is hidden.
    private var saveButton: some View {
        let handle = target.handle
        let canSave = handle.map { UserPresetStore.canCapture($0.iconSettings, scope: scope) } ?? false

        return Button {
            savePresetScope = scope
        } label: {
            Label(PresetSaveButton.title(for: scope), systemImage: "plus")
        }
        .disabled(!canSave)
        .help(handle == nil
              ? "Open an icon window to save a preset"
              : PresetSaveButton.helpText(for: scope, canSave: canSave))
    }

    // MARK: - Actions

    private func adoptRequestedScope() {
        if let requested = request.scope {
            scope = requested
        }
    }

    private func apply(_ preset: MicaPreset) {
        target.handle?.apply(preset)
    }

    private func savePreset(named name: String, scope: PresetScope) {
        savePresetScope = nil
        // The target is re-read at save time: the icon window can close while the
        // sheet is up, and there is then nothing to capture.
        guard let handle = target.handle else { return }
        _ = handle.viewModel.saveCurrentAsPreset(scope: scope, name: name, existing: library.all)
        reload()
    }

    /// Through the store directly, not a view model's `deletePreset`, because there
    /// need be no icon window for this to work.
    private func deletePreset(_ preset: MicaPreset) {
        do {
            try UserPresetStore.delete(preset)
        } catch {
            message = .presetDeleteFailed(preset.name, error)
        }
        reload()
    }

    private func reload() {
        let problems = library.reload()
        if !problems.isEmpty {
            message = .presetsUnreadable(problems)
        }
    }

    private var messageIsPresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }
}

#Preview {
    PresetsWindow()
        .frame(width: 720, height: 560)
}

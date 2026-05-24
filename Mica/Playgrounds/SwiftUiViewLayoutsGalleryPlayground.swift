// ViewLayoutsGalleryPlayground.swift
// Debug-only window that previews SwiftUI layout/container elements
// (NavigationStack, NavigationSplitView, TabView, split views, toolbars, etc.)
// inside fixed-size "mini window" frames so they can be compared at a glance.

import SwiftUI

struct ViewLayoutsGalleryPlayground: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                NavigationStackSection()
                NavigationSplitTwoColumnSection()
                NavigationSplitThreeColumnSection()
                TabViewSection()
                HSplitViewSection()
                VSplitViewSection()
                ToolbarSection()
                InspectorSection()
                PresentationSection()
                SceneLevelSection()
                if #available(macOS 26.0, *) {
                    LiquidGlassLayoutSection()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("View Layouts Gallery")
                .font(.largeTitle.bold())
            Text("Window-level layout containers: navigation, splits, tabs, toolbars, and presentations.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Section chrome (shared visuals)

private struct LayoutSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
    }
}

private struct WindowFrame<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            content
                .frame(width: width, height: height)
                .clipped()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
    }

    private var titleBar: some View {
        HStack(spacing: 6) {
            Circle().fill(.red.opacity(0.8)).frame(width: 10, height: 10)
            Circle().fill(.yellow.opacity(0.8)).frame(width: 10, height: 10)
            Circle().fill(.green.opacity(0.8)).frame(width: 10, height: 10)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: width)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        .overlay(Divider(), alignment: .bottom)
    }
}

// MARK: - NavigationStack

private struct NavigationStackSection: View {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let icon: String
    }

    private let items: [Item] = [
        .init(name: "Inbox", icon: "tray.fill"),
        .init(name: "Drafts", icon: "doc.text"),
        .init(name: "Sent", icon: "paperplane.fill"),
        .init(name: "Trash", icon: "trash.fill")
    ]

    var body: some View {
        LayoutSection(
            "NavigationStack",
            subtitle: "Push-based navigation with a stack of destinations. Single-column."
        ) {
            WindowFrame(width: 420, height: 280) {
                NavigationStack {
                    List(items) { item in
                        NavigationLink(value: item) {
                            Label(item.name, systemImage: item.icon)
                        }
                    }
                    .navigationTitle("Mail")
                    .navigationDestination(for: Item.self) { item in
                        VStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(.tint)
                            Text(item.name).font(.title2.bold())
                            Text("Detail for \(item.name)")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .navigationTitle(item.name)
                    }
                }
            }
        }
    }
}

// MARK: - NavigationSplitView (two column)

private struct NavigationSplitTwoColumnSection: View {
    enum Folder: String, CaseIterable, Identifiable {
        case inbox = "Inbox"
        case drafts = "Drafts"
        case sent = "Sent"
        case archive = "Archive"
        var id: Self { self }

        var icon: String {
            switch self {
            case .inbox: "tray.fill"
            case .drafts: "doc.text"
            case .sent: "paperplane.fill"
            case .archive: "archivebox.fill"
            }
        }
    }

    @State private var selection: Folder? = .inbox

    var body: some View {
        LayoutSection(
            "NavigationSplitView (two-column)",
            subtitle: "Sidebar + detail. Most common macOS shell."
        ) {
            WindowFrame(width: 560, height: 320) {
                NavigationSplitView {
                    List(Folder.allCases, selection: $selection) { folder in
                        Label(folder.rawValue, systemImage: folder.icon)
                            .tag(folder)
                    }
                    .navigationSplitViewColumnWidth(min: 140, ideal: 160)
                } detail: {
                    if let selection {
                        VStack(spacing: 8) {
                            Image(systemName: selection.icon)
                                .font(.system(size: 44))
                                .foregroundStyle(.tint)
                            Text(selection.rawValue).font(.title.bold())
                            Text("Two-column detail view")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Pick a folder").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - NavigationSplitView (three column)

private struct NavigationSplitThreeColumnSection: View {
    enum Group: String, CaseIterable, Identifiable {
        case favourites = "Favourites"
        case projects = "Projects"
        case archived = "Archived"
        var id: Self { self }
    }

    struct Note: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let body: String
    }

    @State private var group: Group? = .favourites
    @State private var note: Note?

    private let notesByGroup: [Group: [Note]] = [
        .favourites: [
            .init(title: "Welcome", body: "This is your first note. Pin it for quick access."),
            .init(title: "Ideas", body: "Things to explore later when there's time.")
        ],
        .projects: [
            .init(title: "Mica roadmap", body: "Plan the next set of features and improvements."),
            .init(title: "Calibration tasks", body: "Outstanding items in the symbol calibration backlog.")
        ],
        .archived: [
            .init(title: "Old plans", body: "Notes from previous quarters, kept for posterity.")
        ]
    ]

    var body: some View {
        LayoutSection(
            "NavigationSplitView (three-column)",
            subtitle: "Sidebar + content list + detail. Mail/Notes-style triple-pane shell."
        ) {
            WindowFrame(width: 720, height: 340) {
                NavigationSplitView {
                    List(Group.allCases, selection: $group) { g in
                        Text(g.rawValue).tag(g)
                    }
                    .navigationSplitViewColumnWidth(min: 120, ideal: 140)
                } content: {
                    if let group, let notes = notesByGroup[group] {
                        List(notes, selection: $note) { n in
                            VStack(alignment: .leading) {
                                Text(n.title).font(.headline)
                                Text(n.body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .tag(n)
                        }
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
                    } else {
                        Text("Pick a group").foregroundStyle(.secondary)
                    }
                } detail: {
                    if let note {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.title).font(.title.bold())
                            Text(note.body).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Pick a note").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - TabView

private struct TabViewSection: View {
    @State private var selection = 0

    var body: some View {
        LayoutSection(
            "TabView",
            subtitle: "Top-mounted tabs on macOS. Use for sibling sections of equal importance."
        ) {
            WindowFrame(width: 500, height: 320) {
                TabView(selection: $selection) {
                    tabContent(symbol: "house.fill", title: "Home", colour: .blue)
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(0)
                    tabContent(symbol: "magnifyingglass", title: "Search", colour: .orange)
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        .tag(1)
                    tabContent(symbol: "gearshape.fill", title: "Settings", colour: .gray)
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(2)
                }
                .padding(.top, 6)
            }
        }
    }

    private func tabContent(symbol: String, title: String, colour: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(colour)
            Text(title).font(.title2.bold())
            Text("Content for the \(title.lowercased()) tab")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HSplitView

private struct HSplitViewSection: View {
    var body: some View {
        LayoutSection(
            "HSplitView (macOS)",
            subtitle: "Two horizontally arranged panes with a draggable divider."
        ) {
            WindowFrame(width: 560, height: 260) {
                HSplitView {
                    VStack {
                        Text("Left pane").font(.headline)
                        Text("Drag the divider →").foregroundStyle(.secondary).font(.caption)
                    }
                    .frame(minWidth: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.opacity(0.15))

                    VStack {
                        Text("Right pane").font(.headline)
                        Text("← Drag the divider").foregroundStyle(.secondary).font(.caption)
                    }
                    .frame(minWidth: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.orange.opacity(0.15))
                }
            }
        }
    }
}

// MARK: - VSplitView

private struct VSplitViewSection: View {
    var body: some View {
        LayoutSection(
            "VSplitView (macOS)",
            subtitle: "Two vertically arranged panes with a draggable divider."
        ) {
            WindowFrame(width: 400, height: 340) {
                VSplitView {
                    VStack {
                        Text("Top pane").font(.headline)
                        Text("Drag the divider ↓").foregroundStyle(.secondary).font(.caption)
                    }
                    .frame(minHeight: 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.purple.opacity(0.15))

                    VStack {
                        Text("Bottom pane").font(.headline)
                        Text("↑ Drag the divider").foregroundStyle(.secondary).font(.caption)
                    }
                    .frame(minHeight: 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.green.opacity(0.15))
                }
            }
        }
    }
}

// MARK: - Toolbar

private struct ToolbarSection: View {
    @State private var searchText = ""

    var body: some View {
        LayoutSection(
            "Toolbar",
            subtitle: "NavigationStack with .toolbar items placed in leading, principal, and trailing slots."
        ) {
            WindowFrame(width: 520, height: 280) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(.tint)
                        Text("Document.txt").font(.headline)
                        Text("Try the toolbar buttons above")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Document")
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button { } label: { Image(systemName: "sidebar.leading") }
                        }
                        ToolbarItemGroup(placement: .principal) {
                            Button { } label: { Image(systemName: "bold") }
                            Button { } label: { Image(systemName: "italic") }
                            Button { } label: { Image(systemName: "underline") }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button { } label: { Label("Share", systemImage: "square.and.arrow.up") }
                        }
                    }
                    .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
                }
            }
        }
    }
}

// MARK: - Inspector

private struct InspectorSection: View {
    @State private var showInspector = true

    var body: some View {
        LayoutSection(
            "Inspector",
            subtitle: ".inspector(isPresented:) attaches a trailing detail panel toggleable from the toolbar."
        ) {
            WindowFrame(width: 540, height: 320) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("Selected item").font(.headline)
                        Text("Inspector lives on the trailing edge")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showInspector.toggle()
                            } label: {
                                Image(systemName: "sidebar.trailing")
                            }
                        }
                    }
                    .inspector(isPresented: $showInspector) {
                        Form {
                            Section("Attributes") {
                                LabeledContent("Type", value: "PNG")
                                LabeledContent("Size", value: "1024 × 1024")
                                LabeledContent("Colour space", value: "sRGB")
                            }
                            Section("Tags") {
                                Label("Icon", systemImage: "tag.fill")
                                Label("Reference", systemImage: "tag.fill")
                            }
                        }
                        .formStyle(.grouped)
                        .inspectorColumnWidth(min: 180, ideal: 200, max: 240)
                    }
                }
            }
        }
    }
}

// MARK: - Presentation (Sheet, Popover, ConfirmationDialog, Alert)

private struct PresentationSection: View {
    @State private var showSheet = false
    @State private var showPopover = false
    @State private var showConfirm = false
    @State private var showAlert = false

    var body: some View {
        LayoutSection(
            "Presentations",
            subtitle: "Sheet, popover, confirmation dialog, and alert overlays."
        ) {
            WindowFrame(width: 520, height: 240) {
                VStack(spacing: 16) {
                    Text("Tap a button to present").foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("Sheet") { showSheet = true }
                            .buttonStyle(.borderedProminent)
                        Button("Popover") { showPopover = true }
                            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                                VStack(spacing: 8) {
                                    Text("Popover content").font(.headline)
                                    Text("Anchored to its source.")
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                }
                                .padding()
                                .frame(width: 200)
                            }
                        Button("Confirmation") { showConfirm = true }
                        Button("Alert") { showAlert = true }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $showSheet) {
                    SheetContent()
                }
                .confirmationDialog("Delete this file?", isPresented: $showConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {}
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
                .alert("Heads up", isPresented: $showAlert) {
                    Button("OK") {}
                } message: {
                    Text("This is an alert.")
                }
            }
        }
    }

    private struct SheetContent: View {
        @Environment(\.dismiss) private var dismiss
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                Text("Sheet").font(.title2.bold())
                Text("Modal overlay presented from the parent view.")
                    .foregroundStyle(.secondary)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(40)
            .frame(width: 360)
        }
    }
}

// MARK: - Scene-level (Window, WindowGroup, MenuBarExtra, Settings)

private struct SceneLevelSection: View {
    var body: some View {
        LayoutSection(
            "Scene-level containers",
            subtitle: "Defined in App body, not inside another view. Listed here for reference."
        ) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    bullet("WindowGroup { ContentView() }", "Standard document/main window scene.")
                    bullet("Window(\"Title\", id: \"id\") { ... }", "Single-instance utility window — what these playgrounds use.")
                    bullet(".windowStyle(.hiddenTitleBar)", "Removes the title bar.")
                    bullet(".windowToolbarStyle(.unified)", "Compact toolbar merged with title bar (also .unifiedCompact, .expanded).")
                    bullet(".defaultSize(width:height:)", "Initial window size.")
                    bullet("MenuBarExtra(\"Title\", systemImage: \"...\") { ... }", "Status item in the menu bar.")
                    bullet("Settings { ... }", "macOS Settings scene (Cmd+,).")
                    bullet("DocumentGroup(newDocument:) { ... }", "Document-based app entry point.")
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bullet(_ code: String, _ description: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(code)
                .font(.callout.monospaced())
                .foregroundStyle(.tint)
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Liquid Glass layouts (macOS 26+)

@available(macOS 26.0, *)
private struct LiquidGlassLayoutSection: View {
    @State private var selection: Int? = 0

    var body: some View {
        LayoutSection(
            "Liquid Glass layouts (macOS 26+)",
            subtitle: "Glass-styled sidebar and toolbar surfaces, gated with #available."
        ) {
            WindowFrame(width: 560, height: 320) {
                NavigationSplitView {
                    List(0..<4, id: \.self, selection: $selection) { idx in
                        Label("Item \(idx + 1)", systemImage: "circle.fill")
                            .tag(idx)
                    }
                } detail: {
                    VStack(spacing: 12) {
                        Text("Glass surfaces")
                            .font(.title2.bold())
                        Text("Sidebar adopts glass automatically on macOS 26.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .glassEffect()
                    .padding()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ViewLayoutsGalleryPlayground()
        .frame(width: 1100, height: 900)
}

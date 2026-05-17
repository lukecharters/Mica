// SwiftUIControlsGalleryPlayground.swift
// Debug-only window that previews common SwiftUI controls from the Xcode Library
// so we can quickly see what each looks like on macOS.

import SwiftUI

struct SwiftUIControlsGalleryPlayground: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                ButtonsSection()
                SelectionSection()
                InputSection()
                IndicatorsSection()
                DisplaySection()
                ContainersSection()
                ListsSection()
                if #available(macOS 26.0, *) {
                    LiquidGlassSection()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 700, minHeight: 600)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SwiftUI Controls Gallery")
                .font(.largeTitle.bold())
            Text("Visual reference for the controls available in the Xcode Library on macOS.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Section chrome

private struct GallerySection<Content: View>: View {
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
                Text(title)
                    .font(.title2.bold())
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

private struct DemoRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        GroupBox(label: Text(label).font(.headline)) {
            content
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Buttons & Actions

private struct ButtonsSection: View {
    @State private var copiedText = "Tap a button"

    var body: some View {
        GallerySection("Buttons & Actions", subtitle: "Triggers and command surfaces.") {
            DemoRow("Button styles") {
                HStack(spacing: 12) {
                    Button("Automatic") {}
                    Button("Bordered") {}
                        .buttonStyle(.bordered)
                    Button("Prominent") {}
                        .buttonStyle(.borderedProminent)
                    Button("Borderless") {}
                        .buttonStyle(.borderless)
                    Button("Plain") {}
                        .buttonStyle(.plain)
                    Button("Link") {}
                        .buttonStyle(.link)
                }
            }

            DemoRow("Control sizes") {
                HStack(spacing: 12) {
                    Button("Mini") {}.controlSize(.mini)
                    Button("Small") {}.controlSize(.small)
                    Button("Regular") {}.controlSize(.regular)
                    Button("Large") {}.controlSize(.large)
                }
                .buttonStyle(.borderedProminent)
            }

            DemoRow("Roles") {
                HStack(spacing: 12) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {}
                    Button(role: .none) {} label: {
                        Label("Confirm", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            DemoRow("Menu") {
                HStack(spacing: 12) {
                    Menu("Flat menu") {
                        Button("First") {}
                        Button("Second") {}
                        Button("Third") {}
                    }
                    Menu("Nested menu") {
                        Button("Top-level") {}
                        Menu("Submenu") {
                            Button("Nested 1") {}
                            Button("Nested 2") {}
                        }
                        Divider()
                        Button("Bottom") {}
                    }
                }
            }

            DemoRow("ShareLink & PasteButton") {
                HStack(spacing: 12) {
                    ShareLink(item: URL(string: "https://www.apple.com")!)
                    PasteButton(payloadType: String.self) { strings in
                        copiedText = strings.first ?? "(empty)"
                    }
                    Text(copiedText)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            DemoRow("ControlGroup") {
                ControlGroup {
                    Button { } label: { Image(systemName: "bold") }
                    Button { } label: { Image(systemName: "italic") }
                    Button { } label: { Image(systemName: "underline") }
                }
                .controlGroupStyle(.automatic)
                .frame(width: 200)
            }
        }
    }
}

// MARK: - Stretched segmented helpers

/// Wraps `NSSegmentedControl` so segments fill-equally across the available width.
private struct StretchedSegmentedPicker<T: Hashable>: NSViewRepresentable {
    @Binding var selection: T
    let options: [Option]

    struct Option {
        let value: T
        let image: NSImage?
        let label: String?

        init(_ value: T, image: NSImage? = nil, label: String? = nil) {
            self.value = value
            self.image = image
            self.label = label
        }
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentCount = options.count
        control.segmentDistribution = .fillEqually
        control.trackingMode = .selectOne
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        configure(control)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        if nsView.segmentCount != options.count {
            nsView.segmentCount = options.count
        }
        configure(nsView)
    }

    private func configure(_ control: NSSegmentedControl) {
        for (i, opt) in options.enumerated() {
            control.setImage(opt.image, forSegment: i)
            control.setLabel(opt.label ?? "", forSegment: i)
        }
        if let idx = options.firstIndex(where: { $0.value == selection }) {
            control.selectedSegment = idx
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: StretchedSegmentedPicker
        init(parent: StretchedSegmentedPicker) { self.parent = parent }
        @objc func changed(_ sender: NSSegmentedControl) {
            let idx = sender.selectedSegment
            guard options(in: parent).indices.contains(idx) else { return }
            parent.selection = options(in: parent)[idx].value
        }
        private func options(in parent: StretchedSegmentedPicker) -> [Option] { parent.options }
    }
}

/// Pure-SwiftUI segmented picker with a tinted capsule for the selected segment.
private struct CapsuleSegmentedPicker<T: Hashable, Content: View>: View {
    @Binding var selection: T
    let options: [T]
    @ViewBuilder var label: (T) -> Content

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    label(option)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == option ? Color.white : .primary)
                        .background {
                            if selection == option {
                                Capsule().fill(.tint)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
//        .padding(2)
        .background(Capsule().fill(.quaternary))
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

// MARK: - Selection

private struct SelectionSection: View {
    enum TextOption: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: Self { self }
        var label: String { rawValue.capitalized }
    }

    enum SymbolOption: String, CaseIterable, Identifiable {
        case sun = "sun.max"
        case cloud = "cloud"
        case rain = "cloud.rain"
        var id: Self { self }
    }

    enum CombinedOption: String, CaseIterable, Identifiable {
        case house, gear, person
        var id: Self { self }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .house: return "house.fill"
            case .gear: return "gearshape.fill"
            case .person: return "person.fill"
            }
        }
    }

    @State private var toggleOn = true
    @State private var checkboxOn = true
    @State private var textPick: TextOption = .medium
    @State private var symbolPick: SymbolOption = .cloud
    @State private var combinedPick: CombinedOption = .gear
    @State private var date = Date()
    @State private var color: Color = .accentColor

    var body: some View {
        GallerySection("Selection", subtitle: "Pickers, toggles, and choosers.") {
            DemoRow("Toggle styles") {
                HStack(spacing: 24) {
                    Toggle("Switch", isOn: $toggleOn)
                        .toggleStyle(.switch)
                    Toggle("Checkbox", isOn: $checkboxOn)
                        .toggleStyle(.checkbox)
                    Toggle("Button", isOn: $toggleOn)
                        .toggleStyle(.button)
                }
            }

            DemoRow("Text-only pickers") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Menu", selection: $textPick) {
                        ForEach(TextOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280)

                    Picker("Segmented", selection: $textPick) {
                        ForEach(TextOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)

                    Picker("Radio Group", selection: $textPick) {
                        ForEach(TextOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Picker("Inline", selection: $textPick) {
                        ForEach(TextOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }

            DemoRow("Symbol-only pickers") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Menu", selection: $symbolPick) {
                        ForEach(SymbolOption.allCases) { option in
                            Image(systemName: option.rawValue).tag(option)
                            .imageScale(.large)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280)

                    Picker("Segmented", selection: $symbolPick) {
                        ForEach(SymbolOption.allCases) { option in
                            Image(systemName: option.rawValue).tag(option)
                            
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

                    Picker("Radio Group", selection: $symbolPick) {
                        ForEach(SymbolOption.allCases) { option in
                            Image(systemName: option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Picker("Inline", selection: $symbolPick) {
                        ForEach(SymbolOption.allCases) { option in
                            Image(systemName: option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }

            DemoRow("Symbol + text pickers") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Menu", selection: $combinedPick) {
                        ForEach(CombinedOption.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280)

                    Picker("Segmented", selection: $combinedPick) {
                        ForEach(CombinedOption.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)

                    Picker("Radio Group", selection: $combinedPick) {
                        ForEach(CombinedOption.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Picker("Inline", selection: $combinedPick) {
                        ForEach(CombinedOption.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }

            DemoRow("Stretched (NSSegmentedControl, .fillEqually)") {
                VStack(alignment: .leading, spacing: 12) {
                    StretchedSegmentedPicker(
                        selection: $symbolPick,
                        options: SymbolOption.allCases.map {
                            .init($0, image: NSImage(systemSymbolName: $0.rawValue, accessibilityDescription: nil))
                        }
                    )
                    .frame(height: 24)

                    StretchedSegmentedPicker(
                        selection: $combinedPick,
                        options: CombinedOption.allCases.map {
                            .init(
                                $0,
                                image: NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil),
                                label: $0.label
                            )
                        }
                    )
                    .frame(height: 24)

                    StretchedSegmentedPicker(
                        selection: $textPick,
                        options: TextOption.allCases.map { .init($0, label: $0.label) }
                    )
                    .frame(height: 24)
                }
                .frame(maxWidth: .infinity)
            }

            DemoRow("Stretched (Capsule, custom SwiftUI)") {
                VStack(alignment: .leading, spacing: 12) {
                    CapsuleSegmentedPicker(selection: $symbolPick, options: SymbolOption.allCases) { option in
                        Image(systemName: option.rawValue)
                    }

                    CapsuleSegmentedPicker(selection: $combinedPick, options: CombinedOption.allCases) { option in
                        Label(option.label, systemImage: option.symbol)
                            .labelStyle(.titleAndIcon)
                    }

                    CapsuleSegmentedPicker(selection: $textPick, options: TextOption.allCases) { option in
                        Text(option.label)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            DemoRow("DatePicker styles") {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Compact", selection: $date)
                        .datePickerStyle(.compact)
                    DatePicker("Field", selection: $date)
                        .datePickerStyle(.field)
                    DatePicker("Stepper Field", selection: $date)
                        .datePickerStyle(.stepperField)
                    DatePicker("Graphical", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .frame(maxWidth: 320)
                }
            }

            DemoRow("ColorPicker") {
                HStack(spacing: 16) {
                    ColorPicker("Pick a colour", selection: $color)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 80, height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                }
            }
        }
    }
}

// MARK: - Input

private struct InputSection: View {
    @State private var text = ""
    @State private var secret = ""
    @State private var notes = "Type something\non multiple lines…"
    @State private var sliderValue: Double = 0.4
    @State private var steppedValue: Double = 5
    @State private var stepperValue = 3

    var body: some View {
        GallerySection("Input", subtitle: "Text, numbers, and continuous values.") {
            DemoRow("TextField styles") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Rounded border", text: $text)
                        .textFieldStyle(.roundedBorder)
                    TextField("Plain", text: $text)
                        .textFieldStyle(.plain)
                    TextField("Square border", text: $text)
                        .textFieldStyle(.squareBorder)
                }
                .frame(maxWidth: 360)
            }

            DemoRow("SecureField") {
                SecureField("Password", text: $secret)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
            }

            DemoRow("TextEditor") {
                TextEditor(text: $notes)
                    .font(.body.monospaced())
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            }

            DemoRow("Slider") {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $sliderValue, in: 0...1)
                    Slider(value: $sliderValue, in: 0...1) {
                        Text("Volume")
                    } minimumValueLabel: {
                        Image(systemName: "speaker")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3")
                    }
                    Slider(value: $steppedValue, in: 0...10, step: 1) {
                        Text("Stepped")
                    }
                    Text("Value: \(sliderValue, format: .number.precision(.fractionLength(2)))")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 420)
            }

            DemoRow("Stepper") {
                Stepper(value: $stepperValue, in: 0...10) {
                    Text("Quantity: \(stepperValue)")
                }
                .frame(maxWidth: 240)
            }
        }
    }
}

// MARK: - Indicators

private struct IndicatorsSection: View {
    @State private var progress: Double = 0.35
    @State private var gauge: Double = 0.6

    var body: some View {
        GallerySection("Indicators", subtitle: "Progress, status, and feedback.") {
            DemoRow("ProgressView") {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    ProgressView(value: progress) {
                        Text("Linear with value")
                    }
                    ProgressView {
                        Text("Circular")
                    }
                    .progressViewStyle(.circular)
                    Slider(value: $progress, in: 0...1)
                }
                .frame(maxWidth: 360)
            }

            DemoRow("Gauge") {
                HStack(spacing: 24) {
                    Gauge(value: gauge) {
                        Text("Linear")
                    } currentValueLabel: {
                        Text("\(Int(gauge * 100))")
                    }
                    .gaugeStyle(.linearCapacity)
                    .frame(width: 160)

                    Gauge(value: gauge) {
                        Text("Accessory linear")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .frame(width: 160)

                    Gauge(value: gauge) {
                        Image(systemName: "drop.fill")
                    } currentValueLabel: {
                        Text("\(Int(gauge * 100))")
                    }
                    .gaugeStyle(.accessoryCircular)

                    Gauge(value: gauge) {
                        Image(systemName: "drop.fill")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)

                    Slider(value: $gauge, in: 0...1)
                        .frame(width: 140)
                }
            }

            DemoRow("Label & Link") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Document", systemImage: "doc.fill")
                    Label("Star", systemImage: "star.fill")
                        .labelStyle(.iconOnly)
                    Label("Star", systemImage: "star.fill")
                        .labelStyle(.titleOnly)
                    Link("Open apple.com", destination: URL(string: "https://www.apple.com")!)
                }
            }

            DemoRow("ContentUnavailableView") {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(height: 220)
            }
        }
    }
}

// MARK: - Display

private struct DisplaySection: View {
    private let gradient = LinearGradient(
        colors: [.pink, .orange, .yellow],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GallerySection("Display", subtitle: "Text, images, dividers, and spacing.") {
            DemoRow("Text styles") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large title").font(.largeTitle)
                    Text("Title").font(.title)
                    Text("Title 2").font(.title2)
                    Text("Headline").font(.headline)
                    Text("Body").font(.body)
                    Text("Callout").font(.callout)
                    Text("Footnote").font(.footnote)
                    Text("Caption").font(.caption)
                    Text("**Markdown** with _italics_ and `code`.")
                    Text("Gradient foreground")
                        .font(.title2.bold())
                        .foregroundStyle(gradient)
                }
            }

            DemoRow("Image & SF Symbols") {
                HStack(spacing: 16) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                    Image(systemName: "cloud.sun.rain.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.multicolor)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.indigo)
                    Image(systemName: "thermometer.sun.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, .yellow)
                    AsyncImage(url: URL(string: "https://developer.apple.com/swift/images/swift-og.png")) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 48, height: 48)
                }
            }

            DemoRow("Divider & Spacer") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Above divider")
                    Divider()
                    Text("Below divider")

                    HStack(spacing: 0) {
                        Color.blue.opacity(0.3).frame(width: 80, height: 24)
                        Spacer().frame(minWidth: 40)
                            .overlay(Rectangle().stroke(.separator).opacity(0.4))
                        Color.green.opacity(0.3).frame(width: 80, height: 24)
                    }
                    .frame(maxWidth: 360)
                }
            }
        }
    }
}

// MARK: - Containers

private struct ContainersSection: View {
    @State private var expanded = true
    @State private var formToggle = true
    @State private var formText = ""
    @State private var formValue: Double = 50

    var body: some View {
        GallerySection("Containers", subtitle: "GroupBox, Form, DisclosureGroup, Section.") {
            DemoRow("GroupBox") {
                GroupBox("Settings") {
                    VStack(alignment: .leading) {
                        Text("Content inside a GroupBox.")
                        Toggle("Enabled", isOn: $formToggle)
                    }
                }
                .frame(maxWidth: 360)
            }

            DemoRow("DisclosureGroup") {
                DisclosureGroup("Advanced Options", isExpanded: $expanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Verbose logging", isOn: $formToggle)
                        TextField("Endpoint", text: $formText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: 360)
            }

            DemoRow("Form") {
                Form {
                    Section("General") {
                        Toggle("Enable feature", isOn: $formToggle)
                        TextField("Name", text: $formText)
                    }
                    Section("Tuning") {
                        Slider(value: $formValue, in: 0...100) {
                            Text("Threshold")
                        }
                        Text("\(Int(formValue))")
                            .font(.callout.monospacedDigit())
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 420, maxHeight: 320)
            }
        }
    }
}

// MARK: - Lists

private struct ListsSection: View {
    struct Person: Identifiable {
        let id = UUID()
        let name: String
        let role: String
        let team: String
    }

    private let people: [Person] = [
        .init(name: "Ada Lovelace", role: "Engineer", team: "Compiler"),
        .init(name: "Alan Turing", role: "Researcher", team: "Foundations"),
        .init(name: "Grace Hopper", role: "Engineer", team: "Tooling"),
        .init(name: "Margaret Hamilton", role: "Lead", team: "Reliability")
    ]

    @State private var selection: Person.ID?

    var body: some View {
        GallerySection("Lists & Tables", subtitle: "Vertical collections with macOS styling.") {
            DemoRow("List (.bordered)") {
                List(selection: $selection) {
                    ForEach(people) { person in
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(person.name).font(.body)
                                Text(person.role).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(person.id)
                    }
                }
                .listStyle(.bordered)
                .frame(height: 160)
            }

            DemoRow("List (.inset)") {
                List(people) { person in
                    Text(person.name)
                }
                .listStyle(.inset)
                .frame(height: 140)
            }

            DemoRow("List (.sidebar)") {
                List {
                    Section("Team") {
                        ForEach(people) { person in
                            Label(person.name, systemImage: "person.fill")
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(height: 220)
            }

            DemoRow("Table") {
                Table(people) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Role", value: \.role)
                    TableColumn("Team", value: \.team)
                }
                .frame(height: 200)
            }
        }
    }
}

// MARK: - Liquid Glass (macOS 26+)

@available(macOS 26.0, *)
private struct LiquidGlassSection: View {
    @State private var toggle = true
    @State private var value: Double = 0.5

    var body: some View {
        GallerySection(
            "Liquid Glass (macOS 26+)",
            subtitle: "Glass surfaces and effects, gated with #available."
        ) {
            DemoRow("Glass-backed card") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glass background")
                        .font(.headline)
                    Toggle("Effects enabled", isOn: $toggle)
                    Slider(value: $value, in: 0...1)
                }
                .padding(16)
                .frame(maxWidth: 360)
                .glassEffect()
            }

            DemoRow("Tinted glass") {
                HStack(spacing: 12) {
                    ForEach([Color.blue, .purple, .pink, .orange], id: \.self) { tint in
                        Text(tint.description.capitalized)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular.tint(tint.opacity(0.4)))
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SwiftUIControlsGalleryPlayground()
        .frame(width: 1000, height: 900)
}

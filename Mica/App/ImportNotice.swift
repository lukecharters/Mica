// App/ImportNotice.swift
import Foundation

/// What a background image import changed beyond the image itself, and how to put
/// those settings back.
///
/// Built by comparing the settings before and after an import, so every import
/// route — menus, paste, canvas drop, the inspector's Choose File… — produces one
/// without the routes knowing about it. `IconViewModel.observeImport(from:)` is the
/// one caller.
struct ImportNotice: Identifiable, Equatable {
    /// A setting an import can change, in the order the notice lists them.
    enum Field: CaseIterable, Equatable {
        case padding, shadow, corners, foreground
    }

    /// The fields of one group that a background import can touch. The icon's
    /// shadow is a style and the badge's an on/off, and only the icon has corners.
    struct Snapshot: Equatable {
        var compensatesForPadding: Bool
        var iconShadow: DropShadowStyle?
        var badgeShadow: Bool?
        var corners: IconCornerRadiusStyle?
        var foregroundHidden: Bool

        init(_ settings: IconSettings, group: IconLayerGroup) {
            switch group {
            case .icon:
                compensatesForPadding = settings.icon.background.compensatesForPadding
                iconShadow = settings.icon.background.shadowStyle
                badgeShadow = nil
                corners = settings.icon.background.cornerRadiusStyle
                foregroundHidden = settings.icon.foreground.isHidden
            case .badge:
                compensatesForPadding = settings.badge.background.compensatesForPadding
                iconShadow = nil
                badgeShadow = settings.badge.background.drawsShadow
                corners = nil
                foregroundHidden = settings.badge.foreground.isHidden
            }
        }

        func differs(from other: Snapshot, in field: Field) -> Bool {
            switch field {
            case .padding: compensatesForPadding != other.compensatesForPadding
            case .shadow: iconShadow != other.iconShadow || badgeShadow != other.badgeShadow
            case .corners: corners != other.corners
            case .foreground: foregroundHidden != other.foregroundHidden
            }
        }

        var shadowIsOn: Bool {
            if let iconShadow { return iconShadow != .off }
            return badgeShadow ?? false
        }
    }

    let id = UUID()
    let group: IconLayerGroup
    let image: ImportedImage
    let before: Snapshot
    let after: Snapshot
    let fields: [Field]

    /// The notice for an import between `previous` and `current`, or nil when no
    /// background received a new image or the import changed nothing else.
    static func detect(from previous: IconSettings, to current: IconSettings) -> ImportNotice? {
        for group in IconLayerGroup.allCases {
            guard let image = backgroundImage(of: group, in: current),
                  backgroundImage(of: group, in: previous)?.id != image.id else { continue }
            let before = Snapshot(previous, group: group)
            let after = Snapshot(current, group: group)
            let fields = Field.allCases.filter { before.differs(from: after, in: $0) }
            guard !fields.isEmpty else { return nil }
            return ImportNotice(group: group, image: image, before: before, after: after, fields: fields)
        }
        return nil
    }

    /// The image this notice is about, while its group's background still draws it.
    private static func backgroundImage(of group: IconLayerGroup, in settings: IconSettings) -> ImportedImage? {
        switch group {
        case .icon:
            settings.icon.background.source == .image ? settings.icon.background.image : nil
        case .badge:
            settings.badge.background.source == .image ? settings.badge.background.image : nil
        }
    }

    /// False once the import has been undone or replaced, when reverting would
    /// write over settings this notice did not set.
    func isCurrent(in settings: IconSettings) -> Bool {
        Self.backgroundImage(of: group, in: settings)?.id == image.id
    }

    /// Puts back the value each listed field had before the import. The image stays.
    func revert(_ settings: inout IconSettings) {
        guard isCurrent(in: settings) else { return }
        for field in fields {
            switch (group, field) {
            case (.icon, .padding): settings.icon.background.compensatesForPadding = before.compensatesForPadding
            case (.badge, .padding): settings.badge.background.compensatesForPadding = before.compensatesForPadding
            case (.icon, .shadow):
                if let style = before.iconShadow { settings.icon.background.shadowStyle = style }
            case (.badge, .shadow):
                if let drawsShadow = before.badgeShadow { settings.badge.background.drawsShadow = drawsShadow }
            case (.icon, .corners):
                if let corners = before.corners { settings.icon.background.cornerRadiusStyle = corners }
            case (.badge, .corners): break
            case (.icon, .foreground): settings.icon.foreground.isHidden = before.foregroundHidden
            case (.badge, .foreground): settings.badge.foreground.isHidden = before.foregroundHidden
            }
        }
    }

    // MARK: - Text

    var title: String {
        image.hasIconMargin
            ? String(localized: "App Icon Imported")
            : String(localized: "Artwork Imported")
    }

    /// One short phrase per changed field, naming the inspector control and the
    /// value it now has.
    var changeDescriptions: [String] {
        fields.map { field in
            switch field {
            case .padding:
                after.compensatesForPadding
                    ? String(localized: "Icon Padding off")
                    : String(localized: "Icon Padding on")
            case .shadow:
                after.shadowIsOn ? String(localized: "Shadow on") : String(localized: "Shadow off")
            case .corners:
                after.corners == .off ? String(localized: "Corners off") : String(localized: "Corners on")
            case .foreground:
                after.foregroundHidden
                    ? String(localized: "Foreground hidden")
                    : String(localized: "Foreground shown")
            }
        }
    }

    var subtitle: String {
        changeDescriptions.joined(separator: " · ")
    }
}

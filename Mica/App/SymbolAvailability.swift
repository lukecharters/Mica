// App/SymbolAvailability.swift
//
// Whether each layer's symbol can be drawn, for the four places the app says so:
// the name field, the canvas marker, the export panel and the load warnings.
//
// A Mica-mode layer is decided by the catalog and then NSImage. A System-mode layer
// is decided by the catalog for the names it knows and by its last appex render for
// the rest, so a name reaches the appex before anything calls it unknown.
import AppKit
import SwiftUI

/// The symbol name, per System-mode layer, whose last appex render was IconServices'
/// stand-in for a name it could not resolve. Kept as the name rather than a flag, so
/// a name typed since that render is not judged by it. Only the view model knows.
struct UnresolvedSystemRenders: Equatable {
    var icon: String?
    var badge: String?
}

extension EnvironmentValues {
    @Entry var unresolvedSystemRenders = UnresolvedSystemRenders()
}

enum SymbolAvailability {
    static func status(
        of name: String,
        isSystem: Bool,
        renderIsUnresolved: Bool,
        catalog: SymbolCatalog = .bundled,
        os: MacOSVersion = .running,
        systemResolves: (String) -> Bool = { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
    ) -> SymbolCatalog.Status {
        isSystem
            ? catalog.status(of: name, on: os, systemResolves: { _ in !renderIsUnresolved })
            : catalog.status(of: name, on: os, systemResolves: systemResolves)
    }

    /// Nil when the icon draws an image rather than a symbol.
    static func iconStatus(
        _ settings: IconSettings,
        renders: UnresolvedSystemRenders,
        catalog: SymbolCatalog = .bundled,
        os: MacOSVersion = .running
    ) -> SymbolCatalog.Status? {
        guard settings.icon.foreground.source != .image else { return nil }
        return status(
            of: settings.icon.foreground.symbolName,
            isSystem: settings.icon.mode == .system,
            renderIsUnresolved: renders.icon == settings.icon.foreground.symbolName,
            catalog: catalog,
            os: os
        )
    }

    /// Nil when the badge is hidden or draws an image.
    static func badgeStatus(
        _ settings: IconSettings,
        renders: UnresolvedSystemRenders,
        catalog: SymbolCatalog = .bundled,
        os: MacOSVersion = .running
    ) -> SymbolCatalog.Status? {
        guard settings.badge.isVisible, settings.badge.foreground.source != .image else { return nil }
        return status(
            of: settings.badge.foreground.symbolName,
            isSystem: settings.badge.foreground.source == .system,
            renderIsUnresolved: renders.badge == settings.badge.foreground.symbolName,
            catalog: catalog,
            os: os
        )
    }

    /// The layers the preview marks as not drawing: the foreground in Mica mode, the
    /// whole group in System mode, where the appex image is one layer.
    static func markedLayers(_ settings: IconSettings, renders: UnresolvedSystemRenders) -> [PreviewSelection] {
        var layers: [PreviewSelection] = []
        if problem(with: settings.icon.foreground.symbolName, status: iconStatus(settings, renders: renders)) != nil {
            layers.append(settings.icon.mode == .system ? .icon : .iconForeground)
        }
        if problem(with: settings.badge.foreground.symbolName, status: badgeStatus(settings, renders: renders)) != nil {
            layers.append(settings.badge.foreground.source == .system ? .badge : .badgeForeground)
        }
        return layers
    }

    /// What is wrong with `name`, or nil when `status` is `.available`.
    static func problem(with name: String, status: SymbolCatalog.Status?) -> String? {
        switch status {
        case .unknown:
            String(localized: "\u{201C}\(name)\u{201D} isn\u{2019}t an SF Symbol available on this Mac.")
        case .needsNewerMacOS(let version):
            String(localized: "\u{201C}\(name)\u{201D} needs macOS \(version.description) or later.")
        case .available, nil:
            nil
        }
    }

    /// The export panel's warnings: one line per layer whose symbol will not draw.
    static func exportWarnings(_ settings: IconSettings, renders: UnresolvedSystemRenders) -> [String] {
        let icon = problem(with: settings.icon.foreground.symbolName, status: iconStatus(settings, renders: renders))
        let badge = problem(with: settings.badge.foreground.symbolName, status: badgeStatus(settings, renders: renders))
        return [
            icon.map { String(localized: "Icon: \($0)") },
            badge.map { String(localized: "Badge: \($0)") },
        ].compactMap { $0 }
    }

    /// Warnings for the Mica-mode symbols a configuration or preset brings in.
    ///
    /// Only a name that differs from what `current` already has is checked, so a
    /// preset that leaves the foreground alone does not re-report it. System-mode
    /// layers are left to their render, which the canvas and the field report.
    static func loadWarnings(
        importing imported: IconSettings,
        over current: IconSettings,
        catalog: SymbolCatalog = .bundled,
        os: MacOSVersion = .running,
        systemResolves: (String) -> Bool = { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
    ) -> [MicaConfigWarning] {
        var warnings: [MicaConfigWarning] = []
        func check(_ name: String, previous: String, key: MicaConfigKey) {
            guard name != previous else { return }
            let status = status(of: name, isSystem: false, renderIsUnresolved: false,
                                catalog: catalog, os: os, systemResolves: systemResolves)
            if let problem = problem(with: name, status: status) {
                warnings.append(MicaConfigWarning(key: key.rawValue, message: problem))
            }
        }
        if imported.icon.mode != .system, imported.icon.foreground.source == .symbol {
            check(imported.icon.foreground.symbolName, previous: current.icon.foreground.symbolName, key: .iconFG)
        }
        if imported.badge.isVisible, imported.badge.foreground.source == .symbol {
            check(imported.badge.foreground.symbolName, previous: current.badge.foreground.symbolName, key: .badgeFG)
        }
        return warnings
    }
}

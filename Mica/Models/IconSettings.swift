// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    // MARK: - Storage
    //
    // Grouped as the UI, the CLI flag namespaces and the `.mica` document all
    // group it: two layer groups, each with a foreground and a background, plus
    // export settings. Icon and badge foregrounds share one type because their
    // property sets are identical — 15 each, one-to-one — which is what stops a
    // new foreground feature being added to one and forgotten on the other.

    var export: ExportSpec = ExportSpec()
    var icon: IconSpec = IconSpec()
    var badge: BadgeSpec = BadgeSpec()

    // MARK: - Compatibility accessors
    //
    // The 62 flat property names this struct used to store, forwarding to the
    // specs above. Added so the storage could be regrouped without touching any
    // of the ~1,780 call sites in the same commit; they are deleted surface by
    // surface as callers migrate. Do not add new ones.
    // See docs/plans/naming-and-structure-review-2026-07-28.md Appendix A.

    var exportSize: CGFloat {
        get { export.size }
        set { export.size = newValue }
    }
    var exportRetinaSize: Bool {
        get { export.isRetina }
        set { export.isRetina = newValue }
    }
    var exportColorSpace: ExportColorSpace {
        get { export.colorSpace }
        set { export.colorSpace = newValue }
    }
    var iconGenerationMode: GenerationMode {
        get { icon.mode }
        set { icon.mode = newValue }
    }
    var symbolName: String {
        get { icon.foreground.symbolName }
        set { icon.foreground.symbolName = newValue }
    }
    var symbolWeight: SymbolWeight {
        get { icon.foreground.symbolWeight }
        set { icon.foreground.symbolWeight = newValue }
    }
    var manualSymbolScale: Double {
        get { icon.foreground.symbolScale }
        set { icon.foreground.symbolScale = newValue }
    }
    var iconSource: ForegroundSource {
        get { icon.foreground.source }
        set { icon.foreground.source = newValue }
    }
    var importedImage: ImportedImage? {
        get { icon.foreground.image }
        set { icon.foreground.image = newValue }
    }
    var importedImageScale: Double {
        get { icon.foreground.imageScale }
        set { icon.foreground.imageScale = newValue }
    }
    var symbolColor: Color {
        get { icon.foreground.color }
        set { icon.foreground.color = newValue }
    }
    var symbolRenderingMode: SymbolRenderingStyle {
        get { icon.foreground.renderingStyle }
        set { icon.foreground.renderingStyle = newValue }
    }
    var symbolColorRenderingMode: SymbolFillStyle {
        get { icon.foreground.fillStyle }
        set { icon.foreground.fillStyle = newValue }
    }
    var hierarchicalSymbolColor: Color {
        get { icon.foreground.hierarchicalColor }
        set { icon.foreground.hierarchicalColor = newValue }
    }
    var paletteSymbolPrimaryColor: Color {
        get { icon.foreground.palettePrimaryColor }
        set { icon.foreground.palettePrimaryColor = newValue }
    }
    var paletteSymbolSecondaryColor: Color {
        get { icon.foreground.paletteSecondaryColor }
        set { icon.foreground.paletteSecondaryColor = newValue }
    }
    var paletteSymbolTertiaryColor: Color {
        get { icon.foreground.paletteTertiaryColor }
        set { icon.foreground.paletteTertiaryColor = newValue }
    }
    var enableSymbolShadow: Bool {
        get { icon.foreground.drawsShadow }
        set { icon.foreground.drawsShadow = newValue }
    }
    var iconForegroundHidden: Bool {
        get { icon.foreground.isHidden }
        set { icon.foreground.isHidden = newValue }
    }
    var backgroundMode: IconBackgroundSource {
        get { icon.background.source }
        set { icon.background.source = newValue }
    }
    var baseColor: Color {
        get { icon.background.color }
        set { icon.background.color = newValue }
    }
    var enableBackgroundGradient: Bool {
        get { icon.background.usesGradient }
        set { icon.background.usesGradient = newValue }
    }
    var useCustomColors: Bool {
        get { icon.background.usesCustomGradient }
        set { icon.background.usesCustomGradient = newValue }
    }
    var customPrimaryColor: Color {
        get { icon.background.gradientStartColor }
        set { icon.background.gradientStartColor = newValue }
    }
    var customSecondaryColor: Color {
        get { icon.background.gradientEndColor }
        set { icon.background.gradientEndColor = newValue }
    }
    var preRenderedColorName: String {
        get { icon.background.preRenderedColorName }
        set { icon.background.preRenderedColorName = newValue }
    }
    var cornerRadiusStyle: IconCornerRadiusStyle {
        get { icon.background.cornerRadiusStyle }
        set { icon.background.cornerRadiusStyle = newValue }
    }
    var backgroundShadowStyle: BackgroundShadowStyle {
        get { icon.background.shadowStyle }
        set { icon.background.shadowStyle = newValue }
    }
    var importedBackground: ImportedImage? {
        get { icon.background.image }
        set { icon.background.image = newValue }
    }
    var importedBackgroundScale: Double {
        get { icon.background.imageScale }
        set { icon.background.imageScale = newValue }
    }
    var importedBackgroundPaddingCompensation: Bool {
        get { icon.background.compensatesForPadding }
        set { icon.background.compensatesForPadding = newValue }
    }
    var iconBackgroundHidden: Bool {
        get { icon.background.isHidden }
        set { icon.background.isHidden = newValue }
    }
    var badgePosition: BadgePosition {
        get { badge.position }
        set { badge.position = newValue }
    }
    var badgeScale: Double {
        get { badge.scale }
        set { badge.scale = newValue }
    }
    var badgeManualOffsetX: Double {
        get { badge.offsetX }
        set { badge.offsetX = newValue }
    }
    var badgeManualOffsetY: Double {
        get { badge.offsetY }
        set { badge.offsetY = newValue }
    }
    var badgeSymbolName: String {
        get { badge.foreground.symbolName }
        set { badge.foreground.symbolName = newValue }
    }
    var badgeSymbolWeight: SymbolWeight {
        get { badge.foreground.symbolWeight }
        set { badge.foreground.symbolWeight = newValue }
    }
    var badgeSymbolScale: Double {
        get { badge.foreground.symbolScale }
        set { badge.foreground.symbolScale = newValue }
    }
    var badgeIconSource: ForegroundSource {
        get { badge.foreground.source }
        set { badge.foreground.source = newValue }
    }
    var badgeImportedImage: ImportedImage? {
        get { badge.foreground.image }
        set { badge.foreground.image = newValue }
    }
    var badgeImportedImageScale: Double {
        get { badge.foreground.imageScale }
        set { badge.foreground.imageScale = newValue }
    }
    var badgeSymbolColor: Color {
        get { badge.foreground.color }
        set { badge.foreground.color = newValue }
    }
    var badgeSymbolRenderingMode: SymbolRenderingStyle {
        get { badge.foreground.renderingStyle }
        set { badge.foreground.renderingStyle = newValue }
    }
    var badgeSymbolColorRenderingMode: SymbolFillStyle {
        get { badge.foreground.fillStyle }
        set { badge.foreground.fillStyle = newValue }
    }
    var badgeHierarchicalSymbolColor: Color {
        get { badge.foreground.hierarchicalColor }
        set { badge.foreground.hierarchicalColor = newValue }
    }
    var badgePaletteSymbolPrimaryColor: Color {
        get { badge.foreground.palettePrimaryColor }
        set { badge.foreground.palettePrimaryColor = newValue }
    }
    var badgePaletteSymbolSecondaryColor: Color {
        get { badge.foreground.paletteSecondaryColor }
        set { badge.foreground.paletteSecondaryColor = newValue }
    }
    var badgePaletteSymbolTertiaryColor: Color {
        get { badge.foreground.paletteTertiaryColor }
        set { badge.foreground.paletteTertiaryColor = newValue }
    }
    var badgeEnableSymbolShadow: Bool {
        get { badge.foreground.drawsShadow }
        set { badge.foreground.drawsShadow = newValue }
    }
    var badgeForegroundHidden: Bool {
        get { badge.foreground.isHidden }
        set { badge.foreground.isHidden = newValue }
    }
    var badgeBaseColor: Color {
        get { badge.background.color }
        set { badge.background.color = newValue }
    }
    var badgeEnableBackgroundGradient: Bool {
        get { badge.background.usesGradient }
        set { badge.background.usesGradient = newValue }
    }
    var badgeUseCustomColors: Bool {
        get { badge.background.usesCustomGradient }
        set { badge.background.usesCustomGradient = newValue }
    }
    var badgeCustomPrimaryColor: Color {
        get { badge.background.gradientStartColor }
        set { badge.background.gradientStartColor = newValue }
    }
    var badgeCustomSecondaryColor: Color {
        get { badge.background.gradientEndColor }
        set { badge.background.gradientEndColor = newValue }
    }
    var badgeEnableBackgroundShadow: Bool {
        get { badge.background.drawsShadow }
        set { badge.background.drawsShadow = newValue }
    }
    var badgeImportedBackground: ImportedImage? {
        get { badge.background.image }
        set { badge.background.image = newValue }
    }
    var badgeImportedBackgroundScale: Double {
        get { badge.background.imageScale }
        set { badge.background.imageScale = newValue }
    }
    var badgeImportedBackgroundPaddingCompensation: Bool {
        get { badge.background.compensatesForPadding }
        set { badge.background.compensatesForPadding = newValue }
    }
    var badgeBackgroundHidden: Bool {
        get { badge.background.isHidden }
        set { badge.background.isHidden = newValue }
    }

    /// Bool ⇄ enum bridge: the badge background used to carry a free `Bool`
    /// where the icon used a mode enum — the same idea expressed two ways, which
    /// is why `BadgeBackgroundSource` now exists. Two cases, so the round-trip is
    /// exact.
    var badgeUseImportedBackground: Bool {
        get { badge.background.source == .image }
        set { badge.background.source = newValue ? .image : .color }
    }

    /// Badge generation mode derived from `badgeIconSource`. Setting `.system`
    /// locks the badge source to `.system`; setting `.mica` falls back to
    /// `.symbol` when needed. The LayerSidebar keeps a separate UI-state memory of
    /// the previous non-system source so the user's pick is restored on round-trip.
    var badgeGenerationMode: GenerationMode {
        get { badgeIconSource == .system ? .system : .mica }
        set {
            switch newValue {
            case .system:
                badgeIconSource = .system
            case .mica:
                if badgeIconSource == .system {
                    badgeIconSource = .symbol
                }
            }
        }
    }

    /// True only when an imported badge background will actually draw. The
    /// "use imported" flag can be set before any image is chosen (the Type picker
    /// writes it directly); in that state the badge falls back to its colour
    /// background and keeps its symbol instead of rendering nothing.
    ///
    /// Shared by `BadgeView` (what to draw) and `BadgeGeometry` (how much room it
    /// needs) — they must agree, or the badge is clamped against a footprint it
    /// doesn't have.
    var badgeDrawsImportedBackground: Bool {
        !badgeBackgroundHidden && badgeUseImportedBackground && badgeImportedBackground != nil
    }

    /// The imported badge background is drawn into a frame this many times the
    /// badge diameter — import scale, plus the padding compensation that scales a
    /// native app icon's chiclet up to fill the frame. Can exceed 1, so the badge's
    /// drawn footprint is not bounded by its nominal diameter.
    var badgeImportedBackgroundEffectiveScale: CGFloat {
        badgeImportedBackgroundScale
            * (badgeImportedBackgroundPaddingCompensation
                ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
    }

    /// True when at least one badge layer is visible. Setting this updates both
    /// `badgeForegroundHidden` and `badgeBackgroundHidden` together.
    var showBadge: Bool {
        get { !badgeForegroundHidden || !badgeBackgroundHidden }
        set {
            badgeForegroundHidden = !newValue
            badgeBackgroundHidden = !newValue
        }
    }

    /// Group-level visibility for the Icon (both layers). Setting it mirrors the
    /// value into both `iconForegroundHidden` and `iconBackgroundHidden`.
    var iconHidden: Bool {
        get { iconForegroundHidden && iconBackgroundHidden }
        set {
            iconForegroundHidden = newValue
            iconBackgroundHidden = newValue
        }
    }

    /// Group-level visibility for the Badge (both layers). Inverse of `showBadge`.
    var badgeHidden: Bool {
        get { badgeForegroundHidden && badgeBackgroundHidden }
        set {
            badgeForegroundHidden = newValue
            badgeBackgroundHidden = newValue
        }
    }

    /// Tri-state visibility for use in group header eye toggles.
    func iconVisibility() -> LayerGroupVisibility {
        switch (iconForegroundHidden, iconBackgroundHidden) {
        case (true, true):   return .off
        case (false, false): return .on
        default:             return .mixed
        }
    }

    func badgeVisibility() -> LayerGroupVisibility {
        switch (badgeForegroundHidden, badgeBackgroundHidden) {
        case (true, true):   return .off
        case (false, false): return .on
        default:             return .mixed
        }
    }

    var gradientColors: [Color] {
        [customPrimaryColor, customSecondaryColor]
    }
    
    var badgeGradientColors: [Color] {
        [badgeCustomPrimaryColor, badgeCustomSecondaryColor]
    }
    
    var preRenderedAssetName: String {
        "background-\(preRenderedColorName.lowercased())-\(enableBackgroundGradient ? "gradient" : "solid")"
    }

    var finalExportSize: CGFloat {
        return exportRetinaSize ? exportSize * 2 : exportSize
    }

    /// Default export filename (without extension): the imported background image's
    /// file name when the icon uses a custom background, otherwise the SF Symbol
    /// name, with a `-mica` suffix appended.
    var exportBaseName: String {
        let base: String
        if backgroundMode == .image, let imported = importedBackground {
            base = (imported.sourceName as NSString).deletingPathExtension
        } else {
            base = symbolName
        }
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        return "\(trimmed.isEmpty ? "CustomIcon" : trimmed)-mica"
    }
}

// MARK: - Specs
//
// The structs `IconSettings` actually stores. Shapes match the `.mica` document
// DTO in docs/plans/mica-document-format.md, so that mapping is field-for-field
// rather than a translation layer.

/// Export settings: what size, at what scale, in which colour space.
struct ExportSpec: Equatable {
    var size: CGFloat = 512
    var isRetina: Bool = false
    var colorSpace: ExportColorSpace = .sRGB

    /// The exported pixel dimension — `size` after the retina multiplier.
    var pixelSize: CGFloat { isRetina ? size * 2 : size }
}

/// The Icon group: how it is rendered, and its two layers.
struct IconSpec: Equatable {
    var mode: GenerationMode = .mica
    var foreground: ForegroundSpec = .iconDefault
    var background: IconBackgroundSpec = IconBackgroundSpec()
}

/// The Badge group: where it sits, how big, and its two layers.
struct BadgeSpec: Equatable {
    var position: BadgePosition = .bottomRight
    var scale: Double = 1.0
    /// Manual nudge, as a fraction of enclosure size so it scales to any export.
    /// Deliberately two `Double`s rather than a `CGSize`: `BadgeGeometry.offset`
    /// already returns a `CGSize` meaning the *resolved, clamped* offset in
    /// points, and two same-typed values meaning different things in one call
    /// chain is the confusion this naming pass exists to remove.
    var offsetX: Double = 0.0
    var offsetY: Double = 0.0
    var foreground: ForegroundSpec = .badgeDefault
    var background: BadgeBackgroundSpec = BadgeBackgroundSpec()
}

/// A foreground layer — the symbol-or-image on top. Shared by the icon and the
/// badge, whose property sets are identical.
///
/// `symbolName` and `isHidden` have no defaults because the two groups genuinely
/// differ (the icon starts on `command` and visible, the badge on
/// `gearshape.fill` and hidden). Use `.iconDefault` / `.badgeDefault`.
struct ForegroundSpec: Equatable {
    var source: ForegroundSource = .symbol
    var symbolName: String
    var symbolWeight: SymbolWeight = .auto
    var symbolScale: Double = 1.0
    var image: ImportedImage? = nil
    var imageScale: Double = 1.0
    var color: Color = .white
    var renderingStyle: SymbolRenderingStyle = .monochrome
    var fillStyle: SymbolFillStyle = .flat
    var hierarchicalColor: Color = .white
    var palettePrimaryColor: Color = .white
    var paletteSecondaryColor: Color = .mint
    var paletteTertiaryColor: Color = .yellow
    var drawsShadow: Bool = true
    var isHidden: Bool

    static let iconDefault = ForegroundSpec(symbolName: "command", isHidden: false)
    static let badgeDefault = ForegroundSpec(symbolName: "gearshape.fill", isHidden: true)
}

/// The icon's background layer. Separate from the badge's because it has two
/// things the badge does not: pre-rendered Liquid Glass assets, and a corner
/// radius (the badge's shape is fixed by `BadgeGeometry.badgeCornerRadiusRatio`).
struct IconBackgroundSpec: Equatable {
    var source: IconBackgroundSource = .color
    var color: Color = .blue
    var usesGradient: Bool = true
    var usesCustomGradient: Bool = false
    var gradientStartColor: Color = .blue
    var gradientEndColor: Color = .purple
    var preRenderedColorName: String = "Blue"
    var cornerRadiusStyle: IconCornerRadiusStyle = .macOS26
    var shadowStyle: BackgroundShadowStyle = .macOS26
    var image: ImportedImage? = nil
    var imageScale: Double = 1.0
    var compensatesForPadding: Bool = false
    var isHidden: Bool = false

    var gradientColors: [Color] { [gradientStartColor, gradientEndColor] }

    var preRenderedAssetName: String {
        "background-\(preRenderedColorName.lowercased())-\(usesGradient ? "gradient" : "solid")"
    }
}

/// The badge's background layer. Its shadow is on/off rather than a preset enum,
/// because a badge only ever has one shadow shape.
struct BadgeBackgroundSpec: Equatable {
    var source: BadgeBackgroundSource = .color
    var color: Color = .gray
    var usesGradient: Bool = true
    var usesCustomGradient: Bool = false
    var gradientStartColor: Color = .white
    var gradientEndColor: Color = .indigo
    var drawsShadow: Bool = true
    var image: ImportedImage? = nil
    var imageScale: Double = 1.0
    var compensatesForPadding: Bool = false
    var isHidden: Bool = true

    var gradientColors: [Color] { [gradientStartColor, gradientEndColor] }
}

/// What the badge's background layer draws. Smaller than `IconBackgroundSource`
/// — there are no pre-rendered badge assets — so the two are separate types
/// rather than one with cases the badge ignores.
enum BadgeBackgroundSource: String, CaseIterable, Identifiable {
    case color = "Custom"
    case image = "Image"
    var id: String { rawValue }
}

enum SymbolRenderingStyle: String, CaseIterable, Identifiable {
    case monochrome = "Monochrome"
    case hierarchical = "Hierarchical"
    case palette = "Palette"
    case multicolor = "Multicolor"
    
    var id: String { self.rawValue }
    
    var symbolRenderingMode: SwiftUI.SymbolRenderingMode {
        switch self {
        case .hierarchical:
            return .hierarchical
        case .monochrome:
            return .monochrome
        case .multicolor:
            return .multicolor
        case .palette:
            return .palette
        }
    }
}


/// What a *foreground* layer draws — an SF Symbol, an imported image, or (icon
/// group only) the whole thing handed to Apple's appex pipeline.
///
/// Raw values are user-visible picker labels, so they deliberately keep their
/// original wording even though the case names changed: retiring "Custom Image"
/// from the interface is a copy decision, not a rename.
enum ForegroundSource: String, CaseIterable, Identifiable, Equatable {
    case symbol = "SF Symbol"
    case image = "Custom Image"
    case system = "System"
    var id: String { rawValue }
}

/// What the icon's *background* layer draws. The badge's background has its own,
/// smaller set — it has no pre-rendered assets — so the two are separate types
/// rather than one with cases the badge ignores.
///
/// Raw values are user-visible picker labels; see `ForegroundSource`.
enum IconBackgroundSource: String, CaseIterable, Identifiable {
    case color = "Custom"
    case preRendered = "Pre-rendered"
    case image = "Image"
    var id: String { rawValue }
}

enum SymbolFillStyle: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case gradient = "Gradient"
    
    var id: String { self.rawValue }
    @available(macOS 26.0, *)
    var symbolColorRenderingMode: SwiftUI.SymbolColorRenderingMode {
        switch self {
        case .flat:
            return .flat
        case .gradient:
            return .gradient
        }
    }
}

enum ExportColorSpace: String, CaseIterable, Identifiable {
    case sRGB = "sRGB"
    case displayP3 = "displayP3"

    var id: String { self.rawValue }

    /// GUI display string; the rawValue is the CLI's --color-space token.
    var displayName: String {
        switch self {
        case .sRGB: return "sRGB"
        case .displayP3: return "Display P3"
        }
    }
    
    var nsColorSpace: NSColorSpace {
        switch self {
        case .sRGB:
            return NSColorSpace.sRGB
        case .displayP3:
            return NSColorSpace.displayP3
        }
    }

    var cgColorSpace: CGColorSpace {
        switch self {
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)!
        }
    }
}

enum BadgePosition: String, CaseIterable, Identifiable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var id: String { rawValue }
}

enum IconCornerRadiusStyle: String, CaseIterable, Identifiable {
    case macOS11 = "macOS 11-15"
    case macOS26 = "macOS 26"

    var id: String { rawValue }
}

enum BackgroundShadowStyle: String, CaseIterable, Identifiable {
    case off = "Off"
    case sequoia = "macOS 11-15"
    case macOS26 = "macOS 26"

    var id: String { rawValue }
}

enum SymbolWeight: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case ultraLight = "Ultralight"
    case thin = "Thin"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"

    var id: String { rawValue }

    /// Returns the corresponding `Font.Weight`, or `nil` for `.auto` (caller uses calibration data).
    var fontWeight: Font.Weight? {
        switch self {
        case .auto:       return nil
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        }
    }
}

/// Tri-state used by group header eye toggles where children may disagree.
enum LayerGroupVisibility {
    case off    // all child layers hidden
    case mixed  // some children hidden, some visible
    case on     // all child layers visible
}

extension IconSettings {
    static let minExportSize: CGFloat = 16
    static let maxExportSize: CGFloat = 1024
    static let defaultExportSize: CGFloat = 512
    static let manualSymbolScaleRange: ClosedRange<Double> = 0.3...2.0
    static let badgeOffsetRange: ClosedRange<Double> = -1.0...1.0
    static let importedImageScaleRange: ClosedRange<Double> = 0.3...2.0

    var isExportSizeValid: Bool {
        (Self.minExportSize...Self.maxExportSize).contains(exportSize)
    }
}

// MARK: - Imported image defaults
//
// When an image is imported into any of the four image slots we default the
// "Icon Padding" compensation (where the toggle exists — the two background
// slots) to off, scaling the image up to fill the frame, and turn off the
// imported-image drop shadow. These are import-time defaults the user can still
// change afterwards; SF Symbol shadows are unaffected because they default from
// the struct, not from these helpers. Centralised here so every entry point
// (menu, paste, drag, sidebar, CLI) stays consistent.
extension IconSettings {
    /// Apply an image as the icon foreground (custom symbol image).
    mutating func applyImportedIconForeground(_ image: ImportedImage) {
        importedImage = image
        iconSource = .image
        enableSymbolShadow = false
    }

    /// Apply an image as the icon background.
    mutating func applyImportedIconBackground(_ image: ImportedImage) {
        importedBackground = image
        backgroundMode = .image
        importedBackgroundPaddingCompensation = true // "Icon Padding" off → fill frame
        backgroundShadowStyle = .off
    }

    /// Apply an image as the badge foreground (custom badge symbol image).
    mutating func applyImportedBadgeForeground(_ image: ImportedImage) {
        badgeImportedImage = image
        badgeIconSource = .image
        badgeEnableSymbolShadow = false
    }

    /// Apply an image as the badge background.
    mutating func applyImportedBadgeBackground(_ image: ImportedImage) {
        badgeImportedBackground = image
        badgeUseImportedBackground = true
        badgeImportedBackgroundPaddingCompensation = true // "Icon Padding" off → fill frame
        badgeEnableBackgroundShadow = false
    }
}

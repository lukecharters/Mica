// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    // MARK: - Storage
    //
    // Grouped as the UI and the CLI flag namespaces group it: two layer groups,
    // each with a foreground and a background, plus export settings. Icon and badge foregrounds share one type because their
    // property sets are identical — 15 each, one-to-one — which is what stops a
    // new foreground feature being added to one and forgotten on the other.

    var export: ExportSpec = ExportSpec()
    var icon: IconSpec = IconSpec()
    var badge: BadgeSpec = BadgeSpec()

    /// Default export filename (without extension): the imported background image's
    /// file name when the icon uses a custom background, otherwise the SF Symbol
    /// name, with a `-mica` suffix appended.
    ///
    /// One of the few things that has to live up here: it reads the icon's
    /// background *and* its foreground, so it cannot move onto either spec.
    var exportBaseName: String {
        let base: String
        if icon.background.source == .image, let imported = icon.background.image {
            base = (imported.sourceName as NSString).deletingPathExtension
        } else {
            base = icon.foreground.symbolName
        }
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        return "\(trimmed.isEmpty ? "CustomIcon" : trimmed)-mica"
    }
}

// MARK: - Specs
//
// The structs `IconSettings` actually stores, shaped so that anything carrying a
// whole configuration (the CLI's flag namespaces, the JSON config format) maps
// field-for-field rather than through a translation layer.
//
// **Imported image defaults.** Each layer spec has an `apply(_:)` carrying the
// import-time defaults: the drop shadow off, and — on the two backgrounds, which
// are the specs with the toggle — "Icon Padding" compensation on, scaling a native
// app icon's chiclet up to fill the frame. The user can change either afterwards;
// SF Symbol shadows are unaffected, because those default from the struct rather
// than from an import. Keeping the defaults on the specs is what makes every entry
// point agree — menu, paste, drag, inspector and CLI — whichever layer it reaches
// and however it gets there.

/// Export settings: what size, at what scale, in which colour space.
struct ExportSpec: Equatable {
    static let minSize: CGFloat = 16
    static let maxSize: CGFloat = 1024
    static let defaultSize: CGFloat = 512

    var size: CGFloat = ExportSpec.defaultSize
    var isRetina: Bool = false
    var colorSpace: ExportColorSpace = .sRGB

    /// The exported pixel dimension — `size` after the retina multiplier.
    var pixelSize: CGFloat { isRetina ? size * 2 : size }

    var isSizeValid: Bool { (ExportSpec.minSize...ExportSpec.maxSize).contains(size) }
}

/// The Icon group: how it is rendered, and its two layers.
struct IconSpec: Equatable {
    var mode: GenerationMode = .mica
    var foreground: ForegroundSpec = .iconDefault
    var background: IconBackgroundSpec = IconBackgroundSpec()

    /// Group-level visibility: hidden only when *both* layers are. Setting it
    /// writes both, so it clears a per-layer flag rather than leaving one behind.
    var isHidden: Bool {
        get { foreground.isHidden && background.isHidden }
        set {
            foreground.isHidden = newValue
            background.isHidden = newValue
        }
    }

    /// Tri-state for the sidebar's group eye, where the two layers may disagree.
    var visibility: LayerGroupVisibility {
        LayerGroupVisibility(foregroundHidden: foreground.isHidden,
                             backgroundHidden: background.isHidden)
    }

    /// Import a background image, applying the defaults that reach *both* layers.
    ///
    /// This has to live on `IconSpec` rather than on `IconBackgroundSpec`:
    /// `IconBackgroundSpec.apply(_:)` cannot reach the foreground, and the repo's
    /// rule is that derived state lives on the spec owning its inputs. **Every
    /// background import routes through here** — the File and Edit menus, the
    /// inspector's source section, the canvas drop, the CLI's `--icon-bg` branch
    /// and the configuration decoder. Leaving one out is the failure mode.
    ///
    /// Hiding the foreground is a *default*, not a veto: the user can switch it
    /// back on and both layers draw.
    mutating func applyBackgroundImage(_ image: ImportedImage,
                                       defaults: ImportDefaults = .fixed) {
        background.apply(image)                     // source, padding, shadow off
        if defaults.turnsOffCornerRadius {
            background.cornerRadiusStyle = .off
        }
        if defaults.hidesForeground {
            foreground.isHidden = true
        }
    }

    /// Drop an imported background and put back everything importing it changed.
    ///
    /// The inverse of `applyBackgroundImage(_:defaults:)`, field for field: the
    /// image, the source, the padding compensation, the shadow and the corner
    /// radius. The colour and gradient are *not* touched, because an import never
    /// touched them — so removing artwork returns the layer to the colour it had
    /// before, not to blue.
    ///
    /// It reverses the hide guess too, but only while the background layer is
    /// showing. A group whose background is hidden did not get its foreground
    /// hidden *by* this import in any meaningful sense, and unhiding it there
    /// would make an invisible badge reappear from a Remove.
    ///
    /// It cannot know whether the user re-made one of those choices deliberately
    /// after the import — which is the honest reason the menu row says "Remove"
    /// and the whole thing is one undo step.
    mutating func removeBackgroundImage() {
        let fresh = IconBackgroundSpec()
        background.image = nil
        background.source = fresh.source
        background.compensatesForPadding = fresh.compensatesForPadding
        background.shadowStyle = fresh.shadowStyle
        background.cornerRadiusStyle = fresh.cornerRadiusStyle
        if !background.isHidden {
            foreground.isHidden = false
        }
    }

    /// Everything about how this group looks, back to defaults.
    ///
    /// Two things survive, and neither is an appearance:
    ///
    /// - **The generation mode**, which is chosen in the toolbar and says which
    ///   pipeline draws the group rather than what it looks like. A reset that
    ///   silently left System mode would read as the reset having failed.
    /// - **Both layers' visibility.** Resetting how a group looks should not
    ///   decide whether it is on screen — and for the badge, whose layers both
    ///   default to hidden, restoring the defaults there would make it vanish.
    mutating func reset() {
        let mode = self.mode
        let foregroundHidden = foreground.isHidden
        let backgroundHidden = background.isHidden
        self = IconSpec()
        self.mode = mode
        foreground.isHidden = foregroundHidden
        background.isHidden = backgroundHidden
    }
}

/// The Badge group: where it sits, how big, and its two layers.
struct BadgeSpec: Equatable {
    /// Bounds for `offsetX` / `offsetY`, in enclosure fractions. Also the
    /// accepted range for `--badge-offset-x` / `--badge-offset-y`. Deliberately
    /// not the *clamped* range — see `BadgeGeometry.manualOffsetRange`, which is
    /// what the canvas drag uses.
    static let offsetRange: ClosedRange<Double> = -1.0...1.0

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

    /// Derived from the foreground source: a badge is in System mode exactly when
    /// its foreground is the appex raster. Setting `.system` locks the source
    /// there; setting `.mica` falls back to `.symbol`. `LayerSidebar` keeps its own
    /// UI-state memory of the previous non-system source so a round-trip restores
    /// the user's pick.
    var mode: GenerationMode {
        get { foreground.source == .system ? .system : .mica }
        set {
            switch newValue {
            case .system:
                foreground.source = .system
            case .mica:
                if foreground.source == .system {
                    foreground.source = .symbol
                }
            }
        }
    }

    /// True when at least one badge layer is visible — the badge is on screen.
    /// Setting it writes both layers.
    var isVisible: Bool {
        get { !foreground.isHidden || !background.isHidden }
        set {
            foreground.isHidden = !newValue
            background.isHidden = !newValue
        }
    }

    /// Group-level visibility: hidden only when *both* layers are. The inverse of
    /// `isVisible`; both spellings exist because call sites read better one way or
    /// the other.
    var isHidden: Bool {
        get { foreground.isHidden && background.isHidden }
        set {
            foreground.isHidden = newValue
            background.isHidden = newValue
        }
    }

    /// Tri-state for the sidebar's group eye, where the two layers may disagree.
    var visibility: LayerGroupVisibility {
        LayerGroupVisibility(foregroundHidden: foreground.isHidden,
                             backgroundHidden: background.isHidden)
    }

    /// Import a background image, applying the defaults that reach *both* layers.
    /// The icon's counterpart, and the same contract — see
    /// `IconSpec.applyBackgroundImage(_:defaults:)`.
    ///
    /// No corner radius here: the badge has none, its shape coming from
    /// `BadgeGeometry.badgeCornerRadiusRatio` or, for imported artwork, from the
    /// artwork's own alpha. `ImportDefaults.turnsOffCornerRadius` is therefore
    /// ignored rather than absent, so one type serves both seams.
    mutating func applyBackgroundImage(_ image: ImportedImage,
                                       defaults: ImportDefaults = .fixed) {
        background.apply(image)                     // source, padding, shadow off
        if defaults.hidesForeground {
            foreground.isHidden = true
        }
    }

    /// Drop an imported background and put back everything importing it changed.
    /// The icon's counterpart, on the same terms — see
    /// `IconSpec.removeBackgroundImage()`. One field fewer, because the badge has
    /// no corner radius to restore.
    mutating func removeBackgroundImage() {
        let fresh = BadgeBackgroundSpec()
        background.image = nil
        background.source = fresh.source
        background.compensatesForPadding = fresh.compensatesForPadding
        background.drawsShadow = fresh.drawsShadow
        if !background.isHidden {
            foreground.isHidden = false
        }
    }

    /// Everything about how this badge looks and where it sits, back to defaults —
    /// position, scale, both offsets and both layers. Keeps the generation mode
    /// and the visibility, for the reasons `IconSpec.reset()` gives; here the
    /// visibility matters more, since a fresh `BadgeSpec` has both layers hidden
    /// and restoring that would make Reset Badge delete the badge.
    mutating func reset() {
        let mode = self.mode
        let foregroundHidden = foreground.isHidden
        let backgroundHidden = background.isHidden
        self = BadgeSpec()
        self.mode = mode
        foreground.isHidden = foregroundHidden
        background.isHidden = backgroundHidden
    }
}

/// A foreground layer — the symbol-or-image on top. Shared by the icon and the
/// badge, whose property sets are identical.
///
/// `symbolName` and `isHidden` have no defaults because the two groups genuinely
/// differ (the icon starts on `command` and visible, the badge on
/// `gearshape.fill` and hidden). Use `.iconDefault` / `.badgeDefault`.
struct ForegroundSpec: Equatable {
    static let symbolScaleRange: ClosedRange<Double> = 0.3...2.0
    static let imageScaleRange: ClosedRange<Double> = 0.3...2.0

    var source: ForegroundSource = .symbol
    var symbolName: String
    var symbolWeight: SymbolWeight = .auto
    var symbolScale: Double = 1.0
    var image: ImportedImage? = nil
    var imageScale: Double = 1.0
    var color: MicaColorValue = .white
    var renderingStyle: SymbolRenderingStyle = .monochrome
    var fillStyle: SymbolFillStyle = .flat
    var hierarchicalColor: MicaColorValue = .white
    var palettePrimaryColor: MicaColorValue = .white
    var paletteSecondaryColor: MicaColorValue = .mint
    var paletteTertiaryColor: MicaColorValue = .yellow
    var drawsShadow: Bool = true
    var isHidden: Bool

    static let iconDefault = ForegroundSpec(symbolName: "command", isHidden: false)
    static let badgeDefault = ForegroundSpec(symbolName: "gearshape.fill", isHidden: true)

    /// Import an image as this layer's artwork, with the import-time defaults: the
    /// drop shadow off, because an imported graphic usually carries its own.
    /// One implementation for both groups — the icon's and the badge's imports
    /// were two identical methods before the specs collapsed them.
    mutating func apply(_ image: ImportedImage) {
        self.image = image
        source = .image
        drawsShadow = false
    }
}

/// The icon's background layer. Separate from the badge's because it has two
/// things the badge does not: pre-rendered Liquid Glass assets, and a corner
/// radius (the badge's shape is fixed by `BadgeGeometry.badgeCornerRadiusRatio`).
struct IconBackgroundSpec: Equatable {
    var source: IconBackgroundSource = .color
    var color: MicaColorValue = .blue
    var usesGradient: Bool = true
    var usesCustomGradient: Bool = false
    var gradientStartColor: MicaColorValue = .blue
    var gradientEndColor: MicaColorValue = .purple
    var preRenderedColorName: String = "Blue"
    var cornerRadiusStyle: IconCornerRadiusStyle = .macOS26
    var shadowStyle: BackgroundShadowStyle = .macOS26
    var image: ImportedImage? = nil
    var imageScale: Double = 1.0
    var compensatesForPadding: Bool = false
    var isHidden: Bool = false

    var gradientColors: [Color] { [gradientStartColor.resolved, gradientEndColor.resolved] }

    var preRenderedAssetName: String {
        "background-\(preRenderedColorName.lowercased())-\(usesGradient ? "gradient" : "solid")"
    }

    /// Import an image as this background, with the import-time defaults: "Icon
    /// Padding" compensation on (scaling a native app icon's chiclet up to fill
    /// the frame) and the shadow off.
    mutating func apply(_ image: ImportedImage) {
        self.image = image
        source = .image
        compensatesForPadding = true
        shadowStyle = .off
    }
}

/// The badge's background layer. Its shadow is on/off rather than a preset enum,
/// because a badge only ever has one shadow shape.
struct BadgeBackgroundSpec: Equatable {
    var source: BadgeBackgroundSource = .color
    var color: MicaColorValue = .gray
    var usesGradient: Bool = true
    var usesCustomGradient: Bool = false
    var gradientStartColor: MicaColorValue = .white
    var gradientEndColor: MicaColorValue = .indigo
    var drawsShadow: Bool = true
    var image: ImportedImage? = nil
    var imageScale: Double = 1.0
    var compensatesForPadding: Bool = false
    var isHidden: Bool = true

    var gradientColors: [Color] { [gradientStartColor.resolved, gradientEndColor.resolved] }

    /// True only when an imported background will actually draw. `source` can be
    /// `.image` before any image is chosen (the Type picker writes it directly); in
    /// that state the badge falls back to its colour background rather than
    /// rendering nothing.
    ///
    /// Shared by `BadgeView` (what to draw) and `BadgeGeometry` (how much room it
    /// needs) — they must agree, or the badge is clamped against a footprint it
    /// doesn't have. Being a property of the spec itself, they now cannot disagree.
    var drawsImage: Bool {
        !isHidden && source == .image && image != nil
    }

    /// The imported background is drawn into a frame this many times the badge
    /// diameter — import scale, plus the padding compensation that scales a native
    /// app icon's chiclet up to fill the frame. Can exceed 1, so the badge's drawn
    /// footprint is not bounded by its nominal diameter.
    var effectiveImageScale: CGFloat {
        imageScale
            * (compensatesForPadding ? ImportedImageGeometry.paddingCompensationFactor : 1.0)
    }

    /// Import an image as this background, with the import-time defaults: "Icon
    /// Padding" compensation on (scaling a native app icon's chiclet up to fill
    /// the frame) and the shadow off.
    mutating func apply(_ image: ImportedImage) {
        self.image = image
        source = .image
        compensatesForPadding = true
        drawsShadow = false
    }
}

/// What the badge's background layer draws. Smaller than `IconBackgroundSource`
/// — there are no pre-rendered badge assets — so the two are separate types
/// rather than one with cases the badge ignores.
///
/// Raw values are not authoritative; see `ForegroundSource`.
enum BadgeBackgroundSource: String, CaseIterable, Identifiable {
    case color = "Color"
    case image = "Imported"
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
/// Raw values are **not** authoritative for anything: the inspector writes its own
/// picker labels (`Views/Inspector/…SourceSection.swift`) and the CLI/config
/// format writes its own tokens. They are kept equal to the shipped labels only so
/// that searching the interface's wording finds this type — they used to say
/// "Custom Image" long after the picker had stopped, which read as a live open
/// question rather than the stale string it was.
enum ForegroundSource: String, CaseIterable, Identifiable, Equatable {
    case symbol = "SF Symbol"
    case image = "Imported"
    case system = "System"
    var id: String { rawValue }
}

/// What the icon's *background* layer draws. The badge's background has its own,
/// smaller set — it has no pre-rendered assets — so the two are separate types
/// rather than one with cases the badge ignores.
///
/// Raw values are not authoritative; see `ForegroundSource`.
enum IconBackgroundSource: String, CaseIterable, Identifiable {
    case color = "Color"
    case preRendered = "Pre-Rendered"
    case image = "Imported"
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

/// How the icon's chiclet is rounded. `.off` is auto-selected when a background
/// image is imported, because artwork that fills its own bounds loses its corners
/// to any radius at all — the same reason an imported *badge* background is
/// deliberately unclipped. On a colour background `.off` gives a square chiclet:
/// an option nobody is obliged to pick.
///
/// Deliberately the same three-case shape as `BackgroundShadowStyle`, which
/// already reads `off / macOS 11-15 / macOS 26` and is already auto-set to `off`
/// on import.
enum IconCornerRadiusStyle: String, CaseIterable, Identifiable {
    case off = "Off"
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

    /// Resolve from a group's two layers. Both groups have exactly a foreground
    /// and a background, so `IconSpec.visibility` and `BadgeSpec.visibility` share
    /// this rather than each switching on its own pair.
    init(foregroundHidden: Bool, backgroundHidden: Bool) {
        switch (foregroundHidden, backgroundHidden) {
        case (true, true):   self = .off
        case (false, false): self = .on
        default:             self = .mixed
        }
    }
}


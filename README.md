# Mica

The Mac admin's Icon Creation App

## Table of Contents

- [About](#about)
- [Installation](#installation)
- [Usage](#usage)
  - [App](#app)
  - [CLI](#cli)
- [Known issues and limitations](#known-issues-and-limitations)
- [Getting help](#getting-help)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## About

Mica is an app for device administrators to quickly create macOS style icons for MDM self service portals and other workflows. You can preview and fine tune your design in the GUI or create icons declaratively with `mica-cli`.


**What you can make:**

- **Icons from SF Symbols** — pick any symbol, choose colors, rendering mode (monochrome, hierarchical, palette, multicolor), weight, and size, and place it on an icon background in either the new macOS 26+ design or the prior design in macOS 11-15.
- **Icons from images, apps, or files** — drag and drop an image for the icon foreground, the background, or both. Alternatively, drag in any non-image object and icon will be extracted. Add padding and drop shadow if missing.
- **Badges** — overlay a second, smaller icon in any corner, with full control over its position. Same options as above.
- **Liquid glass icons** — System mode renders an icon through macOS's own pipeline used by System Settings, so the result matches exactly what the system itself would produce. Create icons with Liquid Glass effects on macOS 26 and newer.

**Built for deployment:**

- Export PNGs from 16 px up to 1024 px, with optional @2x retina output and a choice of sRGB or Display P3 color space.
- Preview your icon at the exact sizes used by MDM portals — including Jamf Self Service and Self Service+ catalog and detail views — so you know how it will look where your users will actually see it, before you export.
- A companion command-line tool (`mica-cli`) produces identical output to the app, so you can script icon generation in CI or batch workflows. It can also extract existing icons from apps and files on disk.

Mica requires **macOS 15 (Sequoia) or later**. Liquid Glass backgrounds and symbol gradients additionally require macOS 26 or later.

## Installation

Download the latest .pkg from releases.

Other installation methods coming soon.

## Usage

### App

1. **Pick a symbol.** Click the symbol well and search the built-in SF Symbols browser, or switch the icon source to *Image* and import an image or extract an app or file icon.
2. **Style the layers.** The sidebar is organized by layer — select the icon's background or foreground to adjust colors, gradients, rendering mode, symbol weight, scale, and shadows. Backgrounds can be a solid color, a gradient, a Liquid Glass material (macOS 26+), or an imported image.
3. **Add a badge (optional).** Turn on the badge layer to overlay a second symbol or image in any corner. Drag the badge directly on the preview to fine-tune its position, or use the offset sliders.
4. **Preview at real-world sizes.** Use the preview size menu to see your icon exactly as it will appear in Jamf Self Service / Self Service+ catalog and item views, or at any standard icon size from 16 px to 1024 px. Zoom from 25% to 800% to inspect details.
5. **Export.** Press **⌘E**, choose a size (16–1024 px), optionally enable @2x retina output, pick sRGB or Display P3, and save your PNG.

**System mode** switch the generation mode to *System* to have macOS itself render the icon, using Apple's own symbol sizing and color palette. You choose a background and symbol color from the system palette; layout is handled automatically. Use this when you want output indistinguishable from native system icons.

### CLI

`mica-cli` shares its rendering engine with the app — all settings in the UI are available. Run `mica-cli --help` for the full list of options.

#### Generating icons

```bash
# Simplest case: a symbol on the default blue gradient, saved as star.fill.png
mica-cli star.fill

# Choose output path, size, and background color
mica-cli folder.fill -o ~/Desktop/folder-icon.png --size 512 --base-color red

# Custom gradient (hex colors supported)
mica-cli app.fill --use-custom-colors --custom-primary "#FF6B35" --custom-secondary "#F7931E"

# Symbol styling
mica-cli shield.fill --rendering-mode hierarchical --hierarchical-color white
mica-cli star.fill --symbol-weight bold --symbol-scale 1.3

# Classic macOS 11–15 look, flat color
mica-cli star.fill --corner-radius macos11 --no-gradient

# Add a badge
mica-cli star.fill --badge plus.circle --badge-position bottom-right
mica-cli star.fill --badge gear --badge-scale 1.3 --badge-offset-x 0.2 --badge-offset-y -0.1

# Use your own images for the foreground and/or background
mica-cli my-app --icon-source image --imported-image ~/logo.png
mica-cli my-app --background-mode image --imported-background ~/bg.png

# Apple Reference mode (system-rendered)
mica-cli star.fill --icon-mode apple-reference \
  --appex-enclosure-color blue --appex-symbol-color white

# High-resolution export
mica-cli app.fill --size 1024 --retina --color-space displayP3
```

Colors can be given as named colors (`blue`, `red`, `indigo`, …) or hex values (`"#FF6B35"`). Secondary and tertiary palette colors also accept an opacity suffix, e.g. `white:0.5`.

#### Extracting existing icons

The `geticon` subcommand exports the icon of any app, file, or folder on disk as a PNG. It also has a recursive mode to extract an entire folder of icons.

```bash
# Export one app's icon to the current directory
mica-cli geticon /Applications/Safari.app

# Export every icon in /Applications at 512 px @2x
mica-cli geticon /Applications ~/Desktop/icons --recursive --size 512 --scalefactor 2
```

## Known issues and limitations

- Mica requires macOS 15 or later; Liquid Glass icons in system mode and SF symbol gradients require macOS 26.
- Export is PNG only.
- Apple Reference mode renders at the system's native size (512 pt @2x) and supports the fixed system color palette only.
- Apple Reference mode relies on macOS's own icon rendering, so its output can change between macOS releases.

## Getting help

Found a bug or have a question? [Open an issue](../../issues) — please include your macOS version and, for rendering problems, the symbol name and settings (or the full `mica-cli` command) that reproduce it.

## Contributing

Issues and pull requests are welcome. If you're proposing a feature, note that Mica keeps the app and CLI in lockstep — new capabilities should generally work in both. Commit messages follow the [Conventional Commits](https://www.conventionalcommits.org) format.

## License

Distributed under the [Apache License, Version 2.0](./LICENSE)

## Acknowledgements

- Apple's [SF Symbols](https://developer.apple.com/sf-symbols/) — the symbol library that powers Mica's icons. SF Symbols are subject to [Apple's licensing terms](https://developer.apple.com/support/terms/).
- Built with Swift, SwiftUI, and [swift-argument-parser](https://github.com/apple/swift-argument-parser).

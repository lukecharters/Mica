# Mica

*Add some sparkle to your self-service portal*

<img src="assets/images/screenshot-app-hero.png" alt="The Mica main window" width="800">

## Table of Contents

- [About](#about)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Uninstalling](#uninstalling)
- [Usage](#usage)
  - [App](#app)
  - [CLI](#cli)
- [Documentation](#documentation)
- [Getting Help](#getting-help)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)
- [Alternatives](#alternatives)

## About

Mica (Mac admin Icon Creation App) is an app for Mac Admins to create icons for self service catalogues, user facing scripts and workflows, and anywhere else you can find a use for them.

It pairs customisable SwiftUI elements with SF Symbols or imported graphics to enable you to quickly create visually consistent icons that look native on Apple platforms.

 ![Inventory update icon with checkmark badge](assets/images/examples/gearshape.arrow.trianglehead.2.clockwise.rotate.90-mica.png) | ![Trash icon with uninstall badge](assets/images/examples/trash-mica.png) | ![Multicolor weather symbol with gradient background](assets/images/examples/cloud.sun.rain.fill-mica.png)  | ![This looks familiar...](assets/images/examples/bubble.fill-mica.png) | ![Uh oh](assets/images/examples/questionmark.folder.fill-mica.png) | ![You wouldn't download a car](assets/images/examples/download.a.car.png) | ![Menu bar and dock icon with reset badge](assets/images/examples/menubar.dock.rectangle-mica.png) | 
|---|---|---|---|---|---|---|

*These were all created with Mica, it would be weird to put them here if they weren't.*

## Features

- **Icons from SF Symbols** - pick any SF Symbol and put in a squircle, with many SwiftUI styling options to choose from. SF Symbols are not consistent in size, visual alignment, or built-in padding, so I hand aligned and resized 7000+ SF Symbols for improved visual consistency.

- **Icons from your own images** - Don’t like SF Symbols or have a custom one you want to use? No worries, you can swap out the SF Symbol for any custom graphic.

- **Extract app icons** - Need to grab an app icon? Just drag and drop it in. Did the developer neglect to add padding and shadow to the icon and now you have a big flat abomination marring the beauty of your self service catalogue? Well now you can add them back with two clicks. Also, you can extract icons with the bundled CLI tool, point it at an app to grab its icon or point it at `/Applications` to grab every icon, perfect for when you need to update your catalogue every time Apple redesigns them.

- **Extract file icons** - Extracting icons isn’t limited to apps. Import any file type to extract its icon. Image file types import the image themselves.

- **Badges** - overlay a second, smaller icon in any corner. Great for maintenance, repair, or uninstall scripts.

- **Liquid Glass Icons** - System Mode renders through macOS's own icon rendering pipeline. This enables you to create icons with Liquid Glass effects on macOS 26+.

- **Self Service Previews** - Preview your icon at the exact sizes in common MDM portals so you know it looks right in the context of how your users will see it. If yours is missing, let me know the size it displays at and I'll add it.

- **CLI** - A companion command-line tool (`mica-cli`) produces identical output to the app, so you can script icon generation in CI or batch workflows. It can also extract existing icons from apps and files on disk.

- **JSON Import/Export** - Everything else is becoming delcarative and now your icons can too. Save your design as JSON to reuse later in the app or with `mica-cli`.


## Requirements

- **macOS 15 Sequoia or later.**
- Some features rely on newer APIs and require **macOS 26 Tahoe or later**: System generation mode (Liquid Glass icons) and gradient SF symbol rendering. Everything else works on macOS 15.

## Installation

### Download

Download the latest `.pkg` or `.dmg` from [Releases](../../releases).

The `.pkg` installs `Mica.app` and symlinks `/Applications/Mica.app/Contents/MacOS/mica-cli` to `/usr/local/bin/mica-cli` so the CLI is on your `PATH`.

If you don't want the symlink, download the `.dmg` and copy `Mica.app` to `/Applications`.

If you installed from the `.dmg` and do want the CLI on your `PATH`, run:

```shell
sudo ln -s /Applications/Mica.app/Contents/MacOS/mica-cli /usr/local/bin/mica-cli
```
#### Uninstalling

```shell
# CLI symlink
sudo rm /usr/local/bin/mica-cli
# app
rm -rf /Applications/Mica.app
# settings and app data
rm -rf ~/Library/Containers/com.lukecharters.Mica
```

### Homebrew

```sh
brew tap lukecharters/mica
brew trust lukecharters/mica
brew install --cask mica
```
This also adds `mica-cli` to `PATH`.

#### Uninstalling

```sh
brew uninstall --cask mica
```
Add `--zap` to remove Mica's preferences and support files as well.

## Usage

Mica provides a Mac app and a command line tool. Both use the same settings and produce the same PNG output.

### App

Use the app to design and preview one icon.

1. Select **Icon** in the sidebar.
2. Choose Mica mode or System mode in the inspector.
3. Click the grid button beside **Symbol**, then choose an SF Symbol.
4. Set the colours and other styles in the inspector.
5. Use the sliders button in the toolbar to show advanced controls.
6. Select **Badge** and turn on **Visible** to add an optional badge.
7. Open **Export** in the inspector and choose the output settings.
8. Press **⇧⌘E**, choose a file name, and save the PNG.

You can also drop artwork onto the icon or badge. Drag the badge on the canvas to change its position.

Follow [Getting Started](../../wiki/Getting-Started) for a guided first icon. See [The Mica Window](../../wiki/The-Mica-Window) for every pane and shortcut.

### CLI

Use `mica-cli` for scripts, CI, and batch work.

```shell
mkdir -p ~/Desktop/mica-icons

mica-cli --icon-symbol star.fill \
  --output ~/Desktop/mica-icons/star.png

mica-cli --icon-symbol app.fill \
  --badge-symbol plus.circle.fill \
  --output ~/Desktop/mica-icons/install.png

mica-cli extract /Applications/Safari.app \
  --output ~/Desktop/mica-icons
```

**Result:** `~/Desktop/mica-icons` contains two generated icons and Safari's assigned icon.

See [Bulk Generate Icons](../../wiki/Bulk-Generate-Icons) for shell and CSV examples. See [CLI Reference](../../wiki/CLI-Reference) for every command and flag.

## Documentation

Detailed documentation lives in the [Mica wiki](../../wiki).

| Need | Page |
|---|---|
| Install Mica and create your first icons | [Getting Started](../../wiki/Getting-Started) |
| Identify each part of the app | [The Mica Window](../../wiki/The-Mica-Window) |
| Create artwork for fleet tools | [Make Icons For Self Service](../../wiki/Make-Icons-For-Self-Service) |
| Choose Mica mode or System mode | [Generation Modes](../../wiki/Generation-Modes) |
| Find an app or command line setting | [Settings Index](../../wiki/Settings-Index) |
| Check every command and flag | [CLI Reference](../../wiki/CLI-Reference) |
| Check accepted colour values | [Colour Formats](../../wiki/Colour-Formats) |
| Reuse settings in JSON files | [Configuration File Reference](../../wiki/Configuration-File-Reference) |

## Getting Help
Found a bug or have a question/feature request? [Open an issue](../../issues).

For bugs, please include your macOS version, app version, and what you did to break it.

## Contributing
Contributions are welcome, please open an issue or discussion first though. See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to build from source and run the tests.

## License
Distributed under the [Apache License, Version 2.0](./LICENSE).


## Acknowledgements
- [Trevor Sysock/BigMacAdmin](https://github.com/bigmacadmin) for putting me onto [Pico Mitchell's](https://github.com/PicoMitchell) icon generation [discoveries](https://bigmacadmin.wordpress.com/2023/06/02/fun-with-app-icons/).
- [Pico Mitchell](https://github.com/PicoMitchell) for the above.
- [Trevor Sysock/BigMacAdmin](https://github.com/bigmacadmin) again for starting me down the path of automated icon extraction with [IconGrabber.sh](https://bigmacadmin.wordpress.com/2024/05/30/icongrabber-sh-find-and-convert-icns-to-png-easily-mac-admins-utility/)
- Apple's [SF Symbols](https://developer.apple.com/sf-symbols/).
SF Symbols are subject to [Apple's licensing terms](https://developer.apple.com/support/terms/).

## Alternatives
Mac Admins are awesome and love creating free tools for the community. If Mica doesn't fit your needs them here are some alternative icon tools.
- SAP's [Icons](https://github.com/SAP/macOS-icon-generator)
- Kitzy's [Icon Grabber](https://github.com/macadmins/icongrabber)
- Adam Anklewicz's [SFIcons](https://github.com/aanklewicz/SFIcons)
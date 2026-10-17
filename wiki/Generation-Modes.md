# Generation Modes

Generation mode chooses who draws an icon group.
Mica mode uses Mica's full settings.
System mode asks macOS to draw the symbol and rounded square.

The icon and badge choose their modes separately.

## Compare the modes

| | Mica mode | System mode |
|---|---|---|
| The Mac that runs Mica needs | macOS 15 or later | macOS 26 or later |
| Main use | Full control | Current macOS system style |
| Foreground | SF Symbol or image | SF Symbol |
| Background | Colour, gradient, or image | System colour |
| Symbol colour | Full colour grammar | Must fit inside sRGB |
| Background colour | Full colour grammar | Opaque and inside sRGB |
| Badge layout | Supported | Supported |

## What System mode keeps

System mode uses three appearance settings for each group.

| Setting | Icon | Badge |
|---|---|---|
| Symbol name | `--icon-symbol` | `--badge-symbol` |
| Symbol colour | `--icon-symbol-color` | `--badge-symbol-color` |
| Background colour | `--icon-bg-color` | `--badge-bg-color` |

Badge position, size, and offsets still work.
Those settings place the finished badge on the icon.

## What System mode ignores

System mode ignores Mica appearance settings for that group.

| Ignored setting type | Examples |
|---|---|
| Imported artwork | Foreground and background images |
| Background style | Gradients, corners, padding, and background scale |
| Shadows | Foreground and background shadows |
| Symbol style | Weight, rendering mode, palette, gradient, and scale |
| Layer visibility | Separate foreground and background visibility |

The app hides controls that System mode cannot use.
The command line accepts some shared flags but they do not change that System result.

## Choose Mica mode

Choose Mica mode when you need control over the design.
It supports imported artwork, custom gradients, shadows, corners, and symbol styles.

Choose it when the Mac that runs Mica has macOS 15.
Mica mode is the default.

## Choose System mode

Choose System mode when you want the icon macOS 26 draws.
The Mac that runs Mica must run macOS 26 or later.
Fleet Macs that show the exported icon can run any version.

Use a valid SF Symbol.
Choose symbol and background colours that fit inside sRGB.
Keep the background colour fully opaque.

System mode refuses unsupported colours.
It does not silently clamp colour values or remove opacity.

```shell
mica-cli --icon-symbol lock.shield.fill \
  --icon-generation-mode system \
  --icon-symbol-color white \
  --icon-bg-color blue \
  --output system-icon.png
```

See [Icon Settings](Icon-Settings#generation-mode) for the icon control.
See [Badge Settings](Badge-Settings#generation-mode) for the badge control.

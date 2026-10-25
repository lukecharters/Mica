# Generation Modes

Generation mode chooses who draws an icon.
Mica mode uses Mica's full suite of SwiftUI effects and supports importing images.
System mode asks macOS to draw the symbol and rounded square.

Icon and badge generation modes are independent of each other so you can mix and match styles.

## Compare the modes

| | Mica mode | System mode |
|---|---|---|
| Main use | Full customisation | Liquid glass icons on macOS 26+ |
| Foreground | SF Symbol: any rendering mode<br/>Image | SF Symbol: fixed rendering mode |
| Background | Gradient or solid colour<br/>Image | Single colour gradient |
| Symbol colour | sRGB or P3 with opacity control | sRGB with opacity control |
| Background colour | sRGB or P3 with opacity control  | sRGB |

## System mode options

System mode only has three appearance settings for a badge or icon.

| Setting | Icon | Badge |
|---|---|---|
| Symbol name | `--icon-symbol` | `--badge-symbol` |
| Symbol colour | `--icon-symbol-color` | `--badge-symbol-color` |
| Background colour | `--icon-bg-color` | `--badge-bg-color` |

Badge size and layout options still work.

### Example

```shell
mica-cli --icon-symbol lock.shield.fill \
  --icon-generation-mode system \
  --icon-symbol-color white \
  --icon-bg-color blue \
  --output system-icon.png
```

See [Icon Settings](Icon-Settings#generation-mode) for icon settings.<br/>
See [Badge Settings](Badge-Settings#generation-mode) for badge settings.

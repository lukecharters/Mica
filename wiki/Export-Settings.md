# Export Settings

Export settings control the PNG dimensions and colour space.
The app offers seven common sizes.
The command line accepts any whole number from 16 through 1024.

The Save panel shows the same three settings.
A change you make there applies to that one file.
Your window keeps the settings shown in the Export tab.
Click **Reset** in the panel to go back to them.

| App size | Common use |
|---:|---|
| 16, 32, 64 | Small interface icons |
| 128, 256 | Larger interface icons |
| 512 | Standard source artwork |
| 1024 | High-resolution source artwork |

| Destination preview | Size |
|---|---:|
| Fleet Desktop software list | 24 |
| Fleet Desktop narrow window | 40 |
| Fleet Desktop updates | 64 |
| Jamf Self Service+ catalogue | 40 |
| Jamf Self Service+ item | 88 |
| Jamf Self Service classic catalogue | 75 |
| Jamf Self Service classic item | 120 |
| Managed Software Center updates | 64 |
| Managed Software Center categories | 75 |
| Managed Software Center software | 90 |
| Managed Software Center item | 140 |

### Export Size

Sets the width and height before the Retina multiplier.

| | |
|---|---|
| **In the app** | Export ▸ **Size**, or the Save panel |
| **Command line** | `--size 16...1024` |
| **Config key** | `"size"` |
| **Default** | `512` |
| **Shown when** | Always shown. |

The exported PNG is square.
A `512` export at `1x` is 512 by 512 pixels.

```shell
mica-cli --icon-symbol star.fill --size 512
```

### Export Scale

Chooses a standard or Retina pixel multiplier.

| | |
|---|---|
| **In the app** | Export ▸ **2x (Retina)**, or the Save panel |
| **Command line** | `--scale 1x\|2x` |
| **Config key** | `"scale"` |
| **Default** | `1x` |
| **Shown when** | Always shown. |

At `2x`, Mica doubles both pixel dimensions.
A size of `512` produces a 1024 by 1024 PNG.

```shell
mica-cli --icon-symbol star.fill --size 512 --scale 2x
```

### Colour Space

Chooses the colour space stored in the exported PNG.

| | |
|---|---|
| **In the app** | Export ▸ **Color Space**, or the Save panel |
| **Command line** | `--color-space sRGB\|displayP3` |
| **Config key** | `"color-space"` |
| **Default** | `sRGB` |
| **Shown when** | Always shown. |

Use sRGB for broad support.
Use Display P3 when your source artwork uses its wider colour range.

```shell
mica-cli --icon-symbol star.fill --size 512 --color-space displayP3
```

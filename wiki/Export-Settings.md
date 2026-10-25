# Export Settings

Export settings control the PNG dimensions and colour space.
The app offers seven common sizes, each at 1x and @2x.
The command line accepts any whole number from 16 through 1024, with or without `@2x`.

The Save panel shows the same two settings.
A change you make there applies to that one file.
Your window keeps the settings shown in the Document tab.
Click **Reset** in the panel to go back to them.

| App size | Common use |
|---:|---|
| 16, 32, 64 | Small interface icons |
| 128, 256 | Larger interface icons |
| 512 | Standard source artwork |
| 1024 | High-resolution source artwork |

Each size also comes as `@2x`.
An `@2x` size has twice the pixels in each direction.

For MDM portal icon sizes, see [Preview sizes](The-Mica-Window#preview-sizes).

### Export Size

Sets the width and height of the PNG.
Add `@2x` to double the pixels.

| | |
|---|---|
| **In the app** | Document ▸ **Size**, or the Save panel |
| **Command line** | `--size 16...1024`, optionally followed by `@2x` |
| **Config key** | `"size"` |
| **Default** | `512` |
| **Shown when** | Always shown. |

The exported PNG is square.

| Size | PNG |
|---|---|
| `512` | 512 by 512 pixels |
| `512@2x` | 1024 by 1024 pixels |

In a configuration file, write a 1x size as a number and an @2x size as a string.
For example, `"size": 512` or `"size": "512@2x"`.
Older files with a `"scale": "2x"` key still load at @2x.

```shell
mica-cli --icon-symbol star.fill --size 512@2x --output star-1024.png
```

### Colour Space

Chooses the colour space stored in the exported PNG.

| | |
|---|---|
| **In the app** | Document ▸ **Color Space**, or the Save panel |
| **Command line** | `--color-space sRGB\|displayP3` |
| **Config key** | `"color-space"` |
| **Default** | `sRGB` |
| **Shown when** | Always shown. |

Use sRGB for broad support.
Use Display P3 when your source artwork uses its wider colour range.
Also use Display P3 when a colour setting uses a Display P3 or extended colour outside sRGB.
An sRGB export changes that colour to the closest sRGB colour.
See [Colour spaces](Colour-Formats#colour-spaces).

```shell
mica-cli --icon-symbol star.fill --size 512 --color-space displayP3 --output star-p3.png
```

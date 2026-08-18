# Badge Settings

This page lists every setting for the badge.
Use [Settings Index](Settings-Index) to find a setting by name or flag.

## Turn the badge on

The badge starts off.
In the app, select the Badge eye in the sidebar.
On the command line, use a badge symbol, foreground, background, or visibility flag.

| Gate | Default | Effect |
|---|---|---|
| **Badge active** | Off | An active badge uses its visibility and appearance settings. |
| **Show Advanced Controls** | Off | On shows Layout, Foreground, and Background rows. |
| **Generation Mode** | Mica | System shows one pane and ignores most Mica settings. |
| **Foreground Source** | SF Symbol | Imported shows image controls instead of symbol controls. |
| **Rendering** | Monochrome | Palette shows three colour controls. |
| **Background Type** | Colour | Imported shows image layout controls. |
| **Custom Gradient** | Off | On shows two gradient colour controls. |
| **macOS 26** | Not applicable | System mode and symbol gradients need macOS 26. |

Advanced controls are off by default.
The simple pane shows six controls while your other settings still apply.
Turning advanced controls off folds away imported images, palettes, and custom gradients.
Mica keeps the artwork and colours under those settings.

<img src="images/advanced-off.png" width="300" alt="A group pane with advanced controls off, showing six controls"> <img src="images/advanced-on.png" width="300" alt="A Foreground layer with advanced controls on, showing every control">

Left: advanced controls off. Right: advanced controls on, editing the Foreground layer.
The badge pane works the same way, and adds a Layout row.

Each eye in the sidebar shows or hides one layer.

<img src="images/sidebar-eyes.png" width="280" alt="Sidebar rows with both badge layers visible and the Icon group eye mixed">

Both badge layers are visible here, so the Badge eye is on.

## Visibility examples

<img src="images/badge-visibility-all-on.png" width="128" alt="Both badge layers visible"> <img src="images/badge-visibility-fg-off.png" width="128" alt="Badge foreground hidden"> <img src="images/badge-visibility-bg-off.png" width="128" alt="Badge background hidden"> <img src="images/badge-visibility-group-off.png" width="128" alt="Whole badge hidden">

From left: both layers visible, foreground hidden, background hidden, whole badge hidden.

## Whole badge

### Generation Mode

Chooses whether Mica or macOS draws the badge.

| | |
|---|---|
| **In the app** | Badge ▸ **Generation Mode** |
| **Command line** | `--badge-generation-mode mica\|system` |
| **Config key** | `"badge-generation-mode"` |
| **Default** | `mica` |
| **Shown when** | The badge is active. System needs macOS 26. |

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --badge-generation-mode mica
```

### Badge Visibility

Shows or hides both badge layers.

| | |
|---|---|
| **In the app** | Sidebar ▸ Badge eye |
| **Command line** | `--badge-visibility on\|off` |
| **Config key** | `"badge-visibility"` |
| **Default** | `on` when the badge is active |
| **Shown when** | Always shown. |

```shell
mica-cli --icon-symbol star.fill --badge-visibility on
```

## Layout

Layout moves and resizes the whole badge.
The badge background has no corner setting because Mica sets its shape.

| Setting | Changes |
|---|---|
| Badge Size | The whole badge against the standard macOS badge size. |
| Foreground Scale | The symbol or image inside the badge. |

### Position

Chooses the icon corner that holds the badge.

| | |
|---|---|
| **In the app** | Badge ▸ Layout ▸ **Position** |
| **Command line** | `--badge-position top-left\|top-right\|bottom-left\|bottom-right` |
| **Config key** | `"badge-position"` |
| **Default** | `bottom-right` |
| **Shown when** | The badge is active. |

<img src="images/badge-position-top-left.png" width="128" alt="Badge at top left"> <img src="images/badge-position-top-right.png" width="128" alt="Badge at top right"> <img src="images/badge-position-bottom-left.png" width="128" alt="Badge at bottom left"> <img src="images/badge-position-bottom-right.png" width="128" alt="Badge at bottom right">

From left: `top-left`, `top-right`, `bottom-left`, `bottom-right`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-position bottom-right
```

### Badge Size

Changes the size of the whole badge.

| | |
|---|---|
| **In the app** | Badge ▸ Layout ▸ **Size** |
| **Command line** | `--badge-scale 0.3...2.0` |
| **Config key** | `"badge-scale"` |
| **Default** | `1.0` |
| **Shown when** | The badge is active. |

<img src="images/badge-scale-0.7.png" width="128" alt="Badge size 0.7"> <img src="images/badge-scale-1.0.png" width="128" alt="Badge size 1.0"> <img src="images/badge-scale-1.4.png" width="128" alt="Badge size 1.4">

From left: `0.7`, `1.0`, `1.4`.
Above about 109%, the badge moves inward to stay inside the icon.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-scale 1.4
```

### X Offset

Moves the badge left or right from its chosen corner.

| | |
|---|---|
| **In the app** | Badge ▸ Layout ▸ **X Offset** |
| **Command line** | `--badge-offset-x=-1.0...1.0` |
| **Config key** | `"badge-offset-x"` |
| **Default** | `0` |
| **Shown when** | The badge is active. |

<img src="images/badge-offset-x-minus0.15.png" width="128" alt="Negative badge X offset"> <img src="images/badge-offset-x-0.png" width="128" alt="Zero badge X offset"> <img src="images/badge-offset-x-0.15.png" width="128" alt="Positive badge X offset">

From left: `-0.15`, `0`, `0.15`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-offset-x=0.15
```

Attach a negative value with `=`.
A space causes a missing-value error.

### Y Offset

Moves the badge up or down from its chosen corner.

| | |
|---|---|
| **In the app** | Badge ▸ Layout ▸ **Y Offset** |
| **Command line** | `--badge-offset-y=-1.0...1.0` |
| **Config key** | `"badge-offset-y"` |
| **Default** | `0` |
| **Shown when** | The badge is active. |

<img src="images/badge-offset-y-minus0.15.png" width="128" alt="Negative badge Y offset"> <img src="images/badge-offset-y-0.png" width="128" alt="Zero badge Y offset"> <img src="images/badge-offset-y-0.15.png" width="128" alt="Positive badge Y offset">

From left: `-0.15`, `0`, `0.15`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-offset-y=0.15
```

Attach a negative value with `=`.
A space causes a missing-value error.

## Foreground

The foreground contains an SF Symbol or an imported image.

### Foreground Source

Chooses an SF Symbol or an imported image for the badge foreground.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Source ▸ **Source** and symbol or image picker |
| **Command line** | `--badge-symbol NAME`, `--badge-fg symbol:NAME`, or `--badge-fg PATH` |
| **Config key** | `"badge-fg"` |
| **Default** | `symbol:gearshape.fill` when the badge is active |
| **Shown when** | Advanced controls are on and Mica mode is active. |

<img src="images/badge-fg-symbol.png" width="128" alt="SF Symbol badge foreground"> <img src="images/badge-fg-image.png" width="128" alt="Imported badge foreground">

Left: SF Symbol. Right: imported image.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-fg logo.png --badge-scale 2.0
```

Do not use the `symbol:` prefix with `--badge-symbol`.
Giving both foreground flags is an error.

### Foreground Visibility

Shows or hides the badge foreground.

| | |
|---|---|
| **In the app** | Sidebar ▸ Badge ▸ Foreground eye or Badge ▸ Foreground ▸ Source ▸ **Visible** |
| **Command line** | `--badge-fg-visibility on\|off` |
| **Config key** | `"badge-fg-visibility"` |
| **Default** | `on` when the badge is active |
| **Shown when** | Advanced controls are on and Mica mode is active. |

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --badge-fg-visibility off
```

> **System mode ignores this layer setting.**

### Foreground Scale

Changes the symbol or image size inside the badge.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Layout ▸ **Symbol Scale** or **Image Scale** |
| **Command line** | `--badge-fg-scale 0.3...2.0` |
| **Config key** | `"badge-fg-scale"` |
| **Default** | `1.0` |
| **Shown when** | Advanced controls are on and Mica mode is active. |

<img src="images/badge-fg-scale-0.5.png" width="128" alt="Badge foreground scale 0.5"> <img src="images/badge-fg-scale-1.0.png" width="128" alt="Badge foreground scale 1.0"> <img src="images/badge-fg-scale-1.5.png" width="128" alt="Badge foreground scale 1.5">

From left: `0.5`, `1.0`, `1.5`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-fg-scale 1.5
```

> **System mode ignores this.**

### Symbol Rendering

Chooses how the badge symbol uses colour across its layers.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Appearance ▸ **Rendering** |
| **Command line** | `--badge-symbol-rendering monochrome\|hierarchical\|multicolor\|palette` |
| **Config key** | `"badge-symbol-rendering"` |
| **Default** | `monochrome` |
| **Shown when** | Advanced controls are on, Mica mode is active, and the foreground source is SF Symbol. |

<img src="images/badge-symbol-rendering-monochrome.png" width="128" alt="Monochrome badge symbol"> <img src="images/badge-symbol-rendering-hierarchical.png" width="128" alt="Hierarchical badge symbol"> <img src="images/badge-symbol-rendering-multicolor.png" width="128" alt="Multicolour badge symbol"> <img src="images/badge-symbol-rendering-palette.png" width="128" alt="Palette badge symbol">

From left: `monochrome`, `hierarchical`, `multicolor`, `palette`.
Hierarchical may match monochrome on a single-layer symbol.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-symbol cloud.sun.rain.fill --badge-scale 2.0 --badge-symbol-rendering palette
```

> **System mode ignores this.**

### Symbol Colour

Sets the badge symbol colour outside palette mode.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Appearance ▸ **Color** |
| **Command line** | `--badge-symbol-color COLOR` |
| **Config key** | `"badge-symbol-color"` |
| **Default** | `white` |
| **Shown when** | The foreground source is SF Symbol and Rendering is not Palette. |

<img src="images/badge-symbol-color-white.png" width="128" alt="White badge symbol"> <img src="images/badge-symbol-color-black.png" width="128" alt="Black badge symbol"> <img src="images/badge-symbol-color-yellow.png" width="128" alt="Yellow badge symbol">

From left: `white`, `black`, `yellow`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-symbol-color yellow
```

See [Colour Formats](Colour-Formats) for accepted values.

### Symbol Palette

Sets three colours for palette rendering on the badge symbol.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Appearance ▸ **Primary**, **Secondary**, and **Tertiary** |
| **Command line** | `--badge-symbol-palette COLOR,COLOR,COLOR` |
| **Config key** | `"badge-symbol-palette"` |
| **Default** | `white,green,yellow` |
| **Shown when** | Advanced controls are on, Mica mode is active, and Rendering is Palette. |

<img src="images/badge-symbol-palette-default.png" width="128" alt="Default badge symbol palette"> <img src="images/badge-symbol-palette-custom.png" width="128" alt="Custom badge symbol palette">

Left: default. Right: `yellow,white,cyan`.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-symbol cloud.sun.rain.fill --badge-scale 2.0 --badge-symbol-rendering palette --badge-symbol-palette yellow,white,cyan
```

> **System mode ignores this.**

### Symbol Weight

Sets the stroke weight for the badge symbol.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Appearance ▸ **Weight** |
| **Command line** | `--badge-symbol-weight auto\|ultralight\|thin\|light\|regular\|medium\|semibold\|bold\|heavy\|black` |
| **Config key** | `"badge-symbol-weight"` |
| **Default** | `auto` |
| **Shown when** | Advanced controls are on, Mica mode is active, and the foreground source is SF Symbol. |

<img src="images/badge-symbol-weight-ultralight.png" width="128" alt="Ultralight badge symbol"> <img src="images/badge-symbol-weight-regular.png" width="128" alt="Regular badge symbol"> <img src="images/badge-symbol-weight-black.png" width="128" alt="Black weight badge symbol">

From left: `ultralight`, `regular`, `black`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-symbol-weight black
```

> **System mode ignores this.**

### Symbol Gradient

Adds a vertical gradient to the badge symbol fill.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Appearance ▸ **Gradient** |
| **Command line** | `--badge-symbol-gradient on\|off` |
| **Config key** | `"badge-symbol-gradient"` |
| **Default** | `off` |
| **Shown when** | Advanced controls are on, Mica mode is active, the source is SF Symbol, and macOS 26 is installed. |

<img src="images/badge-symbol-gradient-on.png" width="128" alt="Badge symbol gradient on"> <img src="images/badge-symbol-gradient-off.png" width="128" alt="Badge symbol gradient off">

Left: `on`. Right: `off`.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-symbol heart.fill --badge-scale 2.0 --badge-symbol-gradient off
```

> **This setting needs macOS 26. System mode ignores it.**

### Foreground Shadow

Shows or hides the shadow behind the badge foreground.

| | |
|---|---|
| **In the app** | Badge ▸ Foreground ▸ Appearance ▸ **Shadow** |
| **Command line** | `--badge-fg-shadow on\|off` |
| **Config key** | `"badge-fg-shadow"` |
| **Default** | `on` for SF Symbols, `off` for images |
| **Shown when** | Mica mode. |

<img src="images/badge-fg-shadow-on.png" width="128" alt="Badge foreground shadow on"> <img src="images/badge-fg-shadow-off.png" width="128" alt="Badge foreground shadow off">

Left: `on`. Right: `off`.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-symbol heart.fill --badge-scale 2.0 --badge-fg-shadow off
```

> **System mode ignores this.**

## Background

The background uses a colour, custom gradient, or imported image.
Mica sets the badge shape, so there is no badge corner setting.

### Background Type

Chooses a standard colour, custom gradient, or imported image.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Source ▸ **Type** and image picker |
| **Command line** | `--badge-bg standard\|custom-gradient\|PATH` |
| **Config key** | `"badge-bg"` |
| **Default** | `standard` |
| **Shown when** | Advanced controls are on and Mica mode is active. |

<img src="images/badge-bg-standard.png" width="128" alt="Standard badge background"> <img src="images/badge-bg-custom-gradient.png" width="128" alt="Custom gradient badge background"> <img src="images/badge-bg-image.png" width="128" alt="Imported badge background">

From left: `standard`, `custom-gradient`, imported image.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-bg artwork.png
```

Importing a badge background hides its foreground by default.
Any other badge foreground flag shows the foreground.

> **System mode ignores imported backgrounds and custom gradients.**

### Background Visibility

Shows or hides the badge background.

| | |
|---|---|
| **In the app** | Sidebar ▸ Badge ▸ Background eye or Badge ▸ Background ▸ Source ▸ **Visible** |
| **Command line** | `--badge-bg-visibility on\|off` |
| **Config key** | `"badge-bg-visibility"` |
| **Default** | `on` when the badge is active |
| **Shown when** | Advanced controls are on and Mica mode is active. |

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --badge-bg-visibility off
```

> **System mode ignores this layer setting.**

### Background Colour

Sets the badge background colour.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Appearance ▸ **Color** |
| **Command line** | `--badge-bg-color COLOR` |
| **Config key** | `"badge-bg-color"` |
| **Default** | `gray` in Mica mode, `blue` in System mode |
| **Shown when** | Background Type is Colour and Custom Gradient is off. |

<img src="images/badge-bg-color-gray.png" width="128" alt="Grey badge background"> <img src="images/badge-bg-color-blue.png" width="128" alt="Blue badge background"> <img src="images/badge-bg-color-red.png" width="128" alt="Red badge background">

From left: `gray`, `blue`, `red`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-bg-color red
```

See [Colour Formats](Colour-Formats) for accepted values.

### Background Gradient Colours

Sets the top and bottom colours for a custom badge gradient.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Appearance ▸ **Primary** and **Secondary** |
| **Command line** | `--badge-bg-gradient-colors COLOR,COLOR` |
| **Config key** | `"badge-bg-gradient-colors"` |
| **Default** | None. Required with `custom-gradient`. |
| **Shown when** | Advanced controls are on, Mica mode is active, and Custom Gradient is on. |

<img src="images/badge-bg-gradient-colors-sunset.png" width="128" alt="Orange badge gradient"> <img src="images/badge-bg-gradient-colors-ocean.png" width="128" alt="Blue and purple badge gradient">

Left: `#FF6B35,#F7931E`. Right: `#2E86AB,#A23B72`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-bg custom-gradient --badge-bg-gradient-colors '#2E86AB,#A23B72'
```

> **System mode ignores this.**

### Background Gradient

Adds a soft top-to-bottom gradient to the badge background colour.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Appearance ▸ **Gradient** |
| **Command line** | `--badge-bg-gradient on\|off` |
| **Config key** | `"badge-bg-gradient"` |
| **Default** | `on` |
| **Shown when** | Advanced controls are on, Mica mode is active, Background Type is Colour, and Custom Gradient is off. |

<img src="images/badge-bg-gradient-on.png" width="128" alt="Badge background gradient on"> <img src="images/badge-bg-gradient-off.png" width="128" alt="Badge background gradient off">

Left: `on`. Right: `off`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-bg-gradient off
```

> **System mode ignores this.**

### Background Shadow

Shows or hides the shadow behind the badge background.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Appearance ▸ **Shadow** |
| **Command line** | `--badge-bg-shadow on\|off` |
| **Config key** | `"badge-bg-shadow"` |
| **Default** | `off` for images, `on` otherwise |
| **Shown when** | Mica mode. |

<img src="images/badge-bg-shadow-on.png" width="128" alt="Badge background shadow on"> <img src="images/badge-bg-shadow-off.png" width="128" alt="Badge background shadow off">

Left: `on`. Right: `off`.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --size 512 --badge-bg-shadow off
```

> **System mode ignores this.**

### Background Padding

Controls whether Mica keeps padding already present in imported badge artwork.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Layout ▸ **Icon Padding** |
| **Command line** | `--badge-bg-padding on\|off` |
| **Config key** | `"badge-bg-padding"` |
| **Default** | `off` |
| **Shown when** | Advanced controls are on, Mica mode is active, and Background Type is Imported. |

<img src="images/badge-bg-padding-on.png" width="128" alt="Imported badge padding preserved"> <img src="images/badge-bg-padding-off.png" width="128" alt="Imported badge background scaled to fill">

Left: `on` keeps padding. Right: `off` fills the frame.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-bg artwork.png --badge-bg-padding off
```

> **System mode ignores this.**

### Background Scale

Changes the size of an imported badge background.

| | |
|---|---|
| **In the app** | Badge ▸ Background ▸ Layout ▸ **Image Scale** |
| **Command line** | `--badge-bg-scale 0.3...2.0` |
| **Config key** | `"badge-bg-scale"` |
| **Default** | `1.0` |
| **Shown when** | Advanced controls are on, Mica mode is active, and Background Type is Imported. |

Use the imported artwork examples under Background Type to see image scaling.

```shell
mica-cli --icon-symbol star.fill --size 512 --badge-bg artwork.png --badge-bg-scale 1.5
```

> **System mode ignores this.**

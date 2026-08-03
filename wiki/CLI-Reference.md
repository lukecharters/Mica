# CLI Reference

Complete reference for `mica-cli`. For a task-oriented introduction, see the [CLI Guide](CLI-Guide).

```
mica-cli [generate] <symbol-name> [<options>]   # generate an icon (default subcommand)
mica-cli extract <path> [<options>]             # extract icons from apps/files
mica-cli --version
mica-cli --help
```

`generate` is the default subcommand — `mica-cli star.fill` and `mica-cli generate star.fill` are identical.

**Spelling:** every `--…-color` flag also accepts a `--…-colour` alias, `grey` is accepted wherever `gray` is, and `multicolour` works for `multicolor`. The US spellings are canonical in `--help`.

---

## `generate`

### Argument

| Argument | Description |
|---|---|
| `<symbol-name>` | The SF Symbol to render — shorthand for `--icon-fg symbol:<name>`. Optional when `--icon-fg` is given (`--icon-fg` wins if both are present). |

### Generation

| Flag | Values | Default | Description |
|---|---|---|---|
| `--icon-generation-mode` | `mica`, `system` | `mica` | How the icon is rendered: `mica` (SwiftUI pipeline) or `system` (Apple's own appex rendering — Liquid Glass on macOS 26+). |
| `--badge-generation-mode` | `mica`, `system` | `mica` | Same choice for the badge, independent of the icon. `system` badges require an SF Symbol foreground. |

### Icon foreground

| Flag | Values | Default | Description |
|---|---|---|---|
| `--icon-fg` | `symbol:NAME` or an image path | — | Foreground source. `symbol:star.fill` selects an SF Symbol; anything else is treated as an image file path. |
| `--icon-fg-scale` | 0.3–2.0 | 1.0 | Foreground scale multiplier (drives whichever source is active). |
| `--icon-symbol-rendering` | `monochrome`, `hierarchical`, `multicolor`, `palette` | `monochrome` | SF Symbol rendering mode. |
| `--icon-symbol-color` | any [colour](Colour-Formats) | `white` | Symbol colour (monochrome, hierarchical, and multicolor modes). In system mode: an appex colour. |
| `--icon-symbol-palette` | `c1,c2,c3` | `white,white:0.5,white:0.26` | Palette-mode colours; the 2nd and 3rd accept an `:opacity` suffix. |
| `--icon-symbol-weight` | `auto`, `ultralight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` | `auto` | Symbol weight. `auto` uses Mica's per-symbol calibration. |
| `--icon-symbol-gradient` | `on`, `off` | `off` | Gradient fill on the symbol colour (requires macOS 26+). |
| `--icon-fg-shadow` | `on`, `off` | `on` for SF Symbols, `off` for images | Drop shadow behind the foreground. |
| `--icon-fg-visibility` | `on`, `off` | `on` | Hide the foreground entirely with `off`. |

### Icon background

| Flag | Values | Default | Description |
|---|---|---|---|
| `--icon-bg` | `standard`, `custom-gradient`, `prerendered-liquid-glass`, or an image path | `standard` | Background source. |
| `--icon-bg-color` | any [colour](Colour-Formats); for `prerendered-liquid-glass` a named asset colour | `blue` | Background colour: base colour (mica), appex enclosure colour (system), or Liquid Glass asset colour. |
| `--icon-bg-gradient-colors` | `c1,c2` (top,bottom) | — | The two stops for `custom-gradient` backgrounds. Required with `--icon-bg custom-gradient`. |
| `--icon-bg-gradient` | `on`, `off` | `on` | Gradient derived from the base colour (standard backgrounds). |
| `--icon-bg-corner-radius` | `macos11`, `macos26` | `macos26` | Corner-radius silhouette style. |
| `--icon-bg-scale` | 0.3–2.0 | 1.0 | Scale for an imported background image. |
| `--icon-bg-shadow` | `off`, `macos11`, `macos26` | `macos26` (`off` for image backgrounds) | Background drop-shadow style. |
| `--icon-bg-padding` | `on`, `off` | `off` | Keep an imported background's native macOS icon padding (`on`), or fill the frame (`off`). |
| `--icon-bg-visibility` | `on`, `off` | `on` | Hide the background entirely with `off`. |

### Badge

Any of `--badge-fg`, `--badge-bg` or `--badge-visibility on` activates the badge. Every other
flag in the namespace describes a badge rather than asking for one, and does nothing on its own.

| Flag | Values | Default | Description |
|---|---|---|---|
| `--badge-fg` | `symbol:NAME` or an image path | — | Badge foreground source; activates the badge. |
| `--badge-fg-scale` | 0.3–2.0 | 1.0 | Badge foreground scale multiplier. |
| `--badge-symbol-rendering` | `monochrome`, `hierarchical`, `multicolor`, `palette` | `monochrome` | Badge symbol rendering mode. |
| `--badge-symbol-color` | any [colour](Colour-Formats) | `white` | Badge symbol colour. |
| `--badge-symbol-palette` | `c1,c2,c3` | `white,white:0.5,white:0.26` | Badge palette-mode colours. |
| `--badge-symbol-weight` | as icon weights | `auto` | Badge symbol weight. |
| `--badge-symbol-gradient` | `on`, `off` | `off` | Gradient fill on the badge symbol colour (macOS 26+). |
| `--badge-fg-shadow` | `on`, `off` | `on` for SF Symbols, `off` for images | Badge foreground drop shadow. |
| `--badge-fg-visibility` | `on`, `off` | `on` | Hide the badge foreground. |
| `--badge-bg` | `standard`, `custom-gradient`, or an image path | `standard` | Badge background; activates the badge. An image on its own gives artwork with no symbol over it. |
| `--badge-bg-color` | any [colour](Colour-Formats) | `gray` (mica) / `blue` (system) | Badge background colour. |
| `--badge-bg-gradient-colors` | `c1,c2` | — | Stops for `custom-gradient` badge backgrounds. Required with `--badge-bg custom-gradient`. |
| `--badge-bg-gradient` | `on`, `off` | `on` | Gradient on the badge background colour. |
| `--badge-bg-scale` | 0.3–2.0 | 1.0 | Scale for an imported badge background image. |
| `--badge-bg-shadow` | `on`, `off` | `on` (`off` for image backgrounds) | Badge background drop shadow. |
| `--badge-bg-padding` | `on`, `off` | `off` | Keep an imported badge background's padding, or fill the frame. |
| `--badge-bg-visibility` | `on`, `off` | `on` | Hide the badge background. |
| `--badge-position` | `top-left`, `top-right`, `bottom-left`, `bottom-right` | `bottom-right` | Corner the badge anchors to. |
| `--badge-scale` | 0.3–2.0 | 1.0 | Overall badge size. |
| `--badge-offset-x` | −1.0–1.0 | 0.0 | Horizontal fine offset from the anchor (fraction of icon size). |
| `--badge-offset-y` | −1.0–1.0 | 0.0 | Vertical fine offset from the anchor. |

Write negative offsets as `--badge-offset-y=-0.05`. Given a space, `-0.05` is read as another flag and the command fails with `Missing value for '--badge-offset-y <offset>'`.

### Group visibility

One flag per group, writing **both** of its layers — the CLI equivalent of the sidebar's eye.
The group flag applies first and a per-layer flag overrides it, so
`--icon-visibility off --icon-fg-visibility on` is a visible foreground on a hidden background.
Because it writes both layers, one flag reliably brings a whole group back.

| Flag | Values | Default | Description |
|---|---|---|---|
| `--icon-visibility` | `on`, `off` | `on` | Show or hide both icon layers. |
| `--badge-visibility` | `on`, `off` | `off` | Show or hide both badge layers. `on` activates the badge; `off` is the only way to turn off a badge a `--config` file supplied. |

### Export

| Flag | Values | Default | Description |
|---|---|---|---|
| `-o, --output` | file path | `./<symbol-name>.png` | Output PNG path. |
| `-s, --size` | 16–1024 | 512 | Export size in pixels. |
| `--scale` | `1x`, `2x` | `1x` | Output resolution; `2x` doubles the pixel dimensions. |
| `--color-space` | `sRGB`, `displayP3` | `sRGB` | Colour space to render in. |

### Output modes

| Flag | Description |
|---|---|
| `--json` | Emit a single JSON object describing the result to stdout. |
| `-q, --quiet` | Suppress diagnostics; only the saved path prints to stdout. |
| `-v, --verbose` | Per-phase progress on stderr. |

`--quiet` and `--verbose` cannot be combined. The saved path always goes to **stdout** and diagnostics to **stderr**, so `mica-cli` pipes cleanly in scripts.

---

## `extract`

```
mica-cli extract <path> [<options>]
```

| Flag | Values | Default | Description |
|---|---|---|---|
| `<path>` | file or directory | required | The item whose icon to export; a directory with `--recursive` exports everything inside it. |
| `-o, --output` | directory | working directory | Destination directory for exported PNGs. |
| `-s, --size` | pixels | 512 | Icon size. |
| `--scale` | `1x`, `2x` | `1x` | Output resolution. |
| `-r, --recursive` | — | off | Process directory contents. |
| `--depth` | ≥ 0 | — | Maximum nested depth when the input is a directory (`0` = direct children only). Requires `--recursive`. |
| `--color-space` | `sRGB`, `displayP3` | `sRGB` | Colour space to render in. |
| `--json`, `-q`, `-v` | — | — | Output modes, as for `generate`. |

See [Extracting Icons](Extracting-Icons) for worked examples.

---

## JSON output

With `--json`, both subcommands print a single JSON object to stdout describing the command and its output files (path and dimensions), or an error object (`command`, `kind`, `message`) on failure. Exit codes are non-zero on failure, so scripts can rely on either.

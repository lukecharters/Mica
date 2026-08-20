# CLI Reference

`mica-cli` generates icons and extracts existing app icons.

```text
mica-cli [generate] [options]
mica-cli extract <path> [options]
mica-cli --help
mica-cli --version
```

`generate` is the default subcommand.
You can omit its name.
It takes no positional symbol name.

```shell
mica-cli --icon-symbol star.fill --output icon.png
```

## Generate

### Generation

| Flag | Details |
|---|---|
| `--icon-generation-mode` | [Icon generation mode](Icon-Settings#generation-mode) |
| `--badge-generation-mode` | [Badge generation mode](Badge-Settings#generation-mode) |

### Icon foreground

| Flag | Details |
|---|---|
| `--icon-fg` | [Foreground source](Icon-Settings#foreground-source) |
| `--icon-symbol` | [Foreground source shorthand](Icon-Settings#foreground-source) |
| `--icon-fg-scale` | [Foreground scale](Icon-Settings#foreground-scale) |
| `--icon-fg-offset-x` | [Foreground X offset](Icon-Settings#foreground-x-offset) |
| `--icon-fg-offset-y` | [Foreground Y offset](Icon-Settings#foreground-y-offset) |
| `--icon-symbol-rendering` | [Symbol rendering](Icon-Settings#symbol-rendering) |
| `--icon-symbol-color` | [Symbol colour](Icon-Settings#symbol-colour) |
| `--icon-symbol-palette` | [Symbol palette](Icon-Settings#symbol-palette) |
| `--icon-symbol-weight` | [Symbol weight](Icon-Settings#symbol-weight) |
| `--icon-symbol-gradient` | [Symbol gradient](Icon-Settings#symbol-gradient) |
| `--icon-fg-shadow` | [Foreground shadow](Icon-Settings#foreground-shadow) |
| `--icon-fg-visibility` | [Foreground visibility](Icon-Settings#foreground-visibility) |

### Icon background

| Flag | Details |
|---|---|
| `--icon-bg` | [Background type](Icon-Settings#background-type) |
| `--icon-bg-color` | [Background colour](Icon-Settings#background-colour) |
| `--icon-bg-gradient-colors` | [Background gradient colours](Icon-Settings#background-gradient-colours) |
| `--icon-bg-gradient` | [Background gradient](Icon-Settings#background-gradient) |
| `--icon-bg-corner-radius` | [Background corners](Icon-Settings#background-corners) |
| `--icon-bg-scale` | [Background scale](Icon-Settings#background-scale) |
| `--icon-bg-shadow` | [Background shadow](Icon-Settings#background-shadow) |
| `--icon-bg-padding` | [Background padding](Icon-Settings#background-padding) |
| `--icon-bg-visibility` | [Background visibility](Icon-Settings#background-visibility) |

### Badge foreground

| Flag | Details |
|---|---|
| `--badge-fg` | [Foreground source](Badge-Settings#foreground-source) |
| `--badge-symbol` | [Foreground source shorthand](Badge-Settings#foreground-source) |
| `--badge-fg-scale` | [Foreground scale](Badge-Settings#foreground-scale) |
| `--badge-fg-offset-x` | [Foreground X offset](Badge-Settings#foreground-x-offset) |
| `--badge-fg-offset-y` | [Foreground Y offset](Badge-Settings#foreground-y-offset) |
| `--badge-symbol-rendering` | [Symbol rendering](Badge-Settings#symbol-rendering) |
| `--badge-symbol-color` | [Symbol colour](Badge-Settings#symbol-colour) |
| `--badge-symbol-palette` | [Symbol palette](Badge-Settings#symbol-palette) |
| `--badge-symbol-weight` | [Symbol weight](Badge-Settings#symbol-weight) |
| `--badge-symbol-gradient` | [Symbol gradient](Badge-Settings#symbol-gradient) |
| `--badge-fg-shadow` | [Foreground shadow](Badge-Settings#foreground-shadow) |
| `--badge-fg-visibility` | [Foreground visibility](Badge-Settings#foreground-visibility) |

### Badge background

| Flag | Details |
|---|---|
| `--badge-bg` | [Background type](Badge-Settings#background-type) |
| `--badge-bg-color` | [Background colour](Badge-Settings#background-colour) |
| `--badge-bg-gradient-colors` | [Background gradient colours](Badge-Settings#background-gradient-colours) |
| `--badge-bg-gradient` | [Background gradient](Badge-Settings#background-gradient) |
| `--badge-bg-scale` | [Background scale](Badge-Settings#background-scale) |
| `--badge-bg-shadow` | [Background shadow](Badge-Settings#background-shadow) |
| `--badge-bg-padding` | [Background padding](Badge-Settings#background-padding) |
| `--badge-bg-visibility` | [Background visibility](Badge-Settings#background-visibility) |

### Badge layout

| Flag | Details |
|---|---|
| `--badge-position` | [Position](Badge-Settings#position) |
| `--badge-scale` | [Badge size](Badge-Settings#badge-size) |
| `--badge-offset-x` | [X offset](Badge-Settings#x-offset) |
| `--badge-offset-y` | [Y offset](Badge-Settings#y-offset) |

### Group visibility

| Flag | Details |
|---|---|
| `--icon-visibility` | [Icon visibility](Icon-Settings#icon-visibility) |
| `--badge-visibility` | [Badge visibility](Badge-Settings#badge-visibility) |

### Export

| Flag | Short form | Details |
|---|---|---|
| `--size` | `-s` | [Export size](Export-Settings#export-size) |
| `--scale` | None | [Export scale](Export-Settings#export-scale) |
| `--color-space` | None | [Colour space](Export-Settings#colour-space) |

Every `color` flag also accepts a `colour` alias.
The help output uses the American spelling.

See [Colour Formats](Colour-Formats) for accepted colour values.

## Invocation options

These options control the command.
They are not icon settings.

| Flag | Short form | Effect |
|---|---|---|
| `--output PATH` | `-o` | Saves the PNG at `PATH`. |
| `--config PATH` | None | Loads a JSON configuration before other flags. |
| `--json` | None | Writes one result object to standard output. |
| `--quiet` | `-q` | Hides diagnostics and keeps errors. |
| `--verbose` | `-v` | Writes progress details to standard error. |

Command-line settings override values from `--config`.
You cannot combine `--quiet` and `--verbose`.

Without `--output`, Mica saves into the working directory.
It names the file from the symbol or imported image.

See [Configuration File Reference](Configuration-File-Reference) for the JSON format.

## Common options

| Flag | Short form | Effect |
|---|---|---|
| `--help` | `-h` | Shows help for the current command. |
| `--version` | None | Shows the installed Mica version. |

## Output and exit status

Saved paths go to standard output.
Diagnostics go to standard error.
This split keeps pipelines clean.

| Status | Meaning |
|---:|---|
| `0` | The command completed successfully. |
| Non-zero | Validation, reading, rendering, or writing failed. |

`--json` writes one JSON result object.
Failures still return a non-zero status.

## Extract

`extract` exports the icon assigned by macOS.

```text
mica-cli extract <path> [options]
```

| Item | Short form | Values or effect |
|---|---|---|
| `<path>` | None | A file or directory to inspect. |
| `--output PATH` | `-o` | Destination directory. |
| `--size PIXELS` | `-s` | Icon size. Default: `512`. |
| `--scale SCALE` | None | `1x` or `2x`. Default: `1x`. |
| `--recursive` | `-r` | Processes directory contents. |
| `--depth NUMBER` | None | Limits nested depth. Requires `--recursive`. |
| `--color-space SPACE` | None | `sRGB` or `displayP3`. |
| `--json` | None | Writes one result object. |
| `--quiet` | `-q` | Hides diagnostics and keeps errors. |
| `--verbose` | `-v` | Writes progress details. |

Depth `0` includes direct children only.
Depth must be zero or greater.

```shell
mica-cli extract /Applications/Notes.app --output extracted-icons
```

## Negative values

Attach negative badge offsets with `=`.
A space makes the number look like another flag.

```shell
mica-cli --icon-symbol star.fill --badge-symbol plus --badge-offset-y=-0.15
```

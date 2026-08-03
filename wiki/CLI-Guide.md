# CLI Guide

`mica-cli` is the command-line companion to the Mica app. It shares the app's rendering engine, so the same settings produce pixel-identical output — design an icon in the app, then reproduce and batch it in scripts or CI.

This page is task-oriented; every flag is catalogued in the [CLI Reference](CLI-Reference).

## Basics

```shell
# An SF Symbol on the default blue gradient, saved as star.fill.png
mica-cli star.fill

# Choose the output path and size
mica-cli star.fill -o ~/Desktop/star.png --size 1024

# See everything
mica-cli --help
```

The positional argument is an SF Symbol name. Flags are namespaced by layer: `--icon-fg…`, `--icon-bg…`, `--badge-fg…`, `--badge-bg…` — the same four layers you see in the app's sidebar.

> **Spelling:** both English spellings work — every `--…-color` flag has a `--…-colour` alias, `grey` works wherever `gray` does, and `multicolour` is accepted for `multicolor`.

## Styling the icon

```shell
# Background colour (flat or gradient)
mica-cli terminal.fill --icon-bg-color black
mica-cli command --icon-bg-colour red --icon-bg-gradient off

# Custom two-colour gradient
mica-cli paintbrush.fill --icon-bg custom-gradient --icon-bg-gradient-colors "#FF6B35,#F7931E"

# Classic macOS 11–15 chiclet
mica-cli gear --icon-bg-corner-radius macos11

# Symbol rendering, colour, and weight
mica-cli shield.lefthalf.filled --icon-symbol-rendering hierarchical --icon-bg-color teal
mica-cli gear --icon-symbol-rendering palette --icon-symbol-palette "mint,white:0.75,white:0.4"
mica-cli star --icon-symbol-weight black

# Pre-rendered Liquid Glass background
mica-cli star.fill --icon-bg prerendered-liquid-glass --icon-bg-color blue
```

| `terminal.fill` on black | Hierarchical on teal | Custom gradient | Liquid Glass |
|---|---|---|---|
| ![Terminal](images/terminal-black.png) | ![Shield](images/hierarchical-teal.png) | ![Gradient](images/custom-gradient.png) | ![Liquid Glass](images/liquid-glass.png) |

Colour values can be names, hex, `rgb()`/`hsl()`, or components in a named space (`srgb:`, `display-p3:`) — see [Colour Formats](Colour-Formats).

## System (Apple) generation mode

Let macOS itself render the icon, with Apple's own sizing, layout, and (on macOS 26+) Liquid Glass:

```shell
mica-cli star.fill --icon-generation-mode system --icon-bg-color blue --icon-symbol-color white
```

![System mode](images/system-mode.png)

In System mode the colour flags accept Apple's named tokens for the curated system look, or any custom colour (hex, `srgb:`, …) for an exact match to your branding. The colour flags are optional — omitting them gives the default white symbol on a blue enclosure.

Note that macOS renders the icon in the Mac's current appearance, so on a Mac in dark mode the output is the dark variant (dark enclosure, tinted symbol).

## Badges

Supplying `--badge-fg` activates the badge:

```shell
# A plus badge in the default bottom-right corner
mica-cli star.fill --badge-fg symbol:plus.circle.fill

# Position, size, and fine offset
mica-cli star.fill --badge-fg symbol:trash.fill --badge-position top-right --badge-scale 1.2

# Attach a negative offset with =, or -0.05 is read as another flag
mica-cli star.fill --badge-fg symbol:gear --badge-offset-x 0.1 --badge-offset-y=-0.05

# Styled badge background
mica-cli folder.fill --badge-fg symbol:gearshape.fill \
  --badge-bg custom-gradient --badge-bg-gradient-colors "red,orange"
```

![Styled badge](images/badge-styled.png)

A common admin pattern — one base icon, badge variants for install/uninstall/repair:

```shell
for variant in "plus.circle.fill:install" "minus.circle.fill:uninstall" "wrench.fill:repair"; do
  symbol="${variant%%:*}"; name="${variant##*:}"
  mica-cli --icon-fg ~/firefox-logo.png \
    --badge-fg "symbol:$symbol" -o "icons/firefox-$name.png"
done
```

## Using your own images

Any of the four layers can be an image file instead of a symbol or generated background:

```shell
# Your logo as the foreground
mica-cli --icon-fg ~/logo.png

# An image background behind a symbol
mica-cli star.fill --icon-bg ~/bg.png --icon-bg-scale 0.9

# An extracted app icon as the background, with native padding kept
mica-cli extract "/Applications/Company Portal.app" -o /tmp
mica-cli --icon-bg "/tmp/Company Portal.png" --icon-bg-padding on --icon-fg-visibility off
```

## Export options

```shell
mica-cli app.fill --size 1024 --scale 2x --color-space displayP3
```

`--size` is 16–1024 pixels; `--scale 2x` doubles the output pixels; the colour space defaults to sRGB (the right choice for most MDM portals).

## Scripting

The saved file path goes to **stdout**; everything else goes to **stderr**. That means `mica-cli` composes cleanly with pipes, `$(…)`, and `xargs`:

```shell
icon=$(mica-cli star.fill --quiet)
echo "Saved to $icon"
```

Output modes:

```shell
mica-cli star.fill --json      # a single JSON result object on stdout
mica-cli star.fill --quiet     # only the path on stdout, errors on stderr
mica-cli star.fill --verbose   # per-phase progress on stderr
```

Batch generation is just a loop:

```shell
while IFS=, read -r symbol colour; do
  mica-cli "$symbol" --icon-bg-color "$colour" -o "icons/$symbol.png" --quiet
done <<'EOF'
star.fill,blue
wrench.fill,orange
trash.fill,red
EOF
```

Exit codes are non-zero on failure, and `--json` emits an error object instead of a result, so CI can rely on either.

## Extracting icons

The `extract` subcommand exports the icon of any app, file, or folder — including bulk extraction of a whole directory. It has its own page: [Extracting Icons](Extracting-Icons).

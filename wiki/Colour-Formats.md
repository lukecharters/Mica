# Colour Formats

Every colour flag in `mica-cli` accepts the formats below. In the app, colours are picked with dropdowns and colour wells, so this page is mostly for CLI users.

Both English spellings work throughout: every `--…-color` flag has a `--…-colour` alias, and `grey` is accepted wherever `gray` is.

## Named colours

Standard names:

```
blue  red  green  orange  yellow  pink  purple  indigo  teal  mint  cyan
brown  white  black  gray/grey  clear/transparent
```

Extended names:

```
lightgray/lightgrey  darkgray/darkgrey  magenta  lime  navy  maroon  olive
silver  gold  crimson  violet  turquoise  coral  salmon  khaki  plum  orchid
```

macOS system colours (adapt to the system's colour definitions):

```
system.blue  system.red  system.green  system.orange  system.yellow
system.pink  system.purple  system.teal  system.indigo  system.mint
system.cyan  system.brown  system.gray/system.grey
label  secondary.label  tertiary.label  quaternary.label
```

## Hex

```shell
--icon-bg-color "#FF6B35"     # RRGGBB
--icon-bg-color "#F80"        # RGB shorthand → FF8800
--icon-bg-color "#FF6B35CC"   # RRGGBBAA (with alpha)
--icon-bg-color FF6B35        # the # is optional
```

## RGB components

Bare comma-separated `r,g,b` or `r,g,b,a`:

```shell
--icon-bg-color "0.2,0.4,0.9"        # 0–1 floats
--icon-bg-color "51,102,230"         # 0–255 (used when any component exceeds 1)
--icon-bg-color "20%,40%,90%"        # percentages
--icon-bg-color "1,0.0902,0.2118,1"  # with alpha (alpha is always 0–1)
```

## CSS functions

```shell
--icon-bg-color "rgb(255,107,53)"
--icon-bg-color "rgba(255,107,53,0.8)"
--icon-bg-color "hsl(9,100%,60%)"
--icon-bg-color "hsla(9,100%,60%,0.8)"
```

## Greyscale

A single number is treated as a grey level: `0.5` or `128`.

## Opacity suffix

Palette colours (the 2nd and 3rd entries of `--icon-symbol-palette` / `--badge-symbol-palette`) accept an `:opacity` suffix:

```shell
--icon-symbol-rendering palette --icon-symbol-palette "blue,white:0.5,white:0.26"
```

## System (appex) mode colours

In System generation mode (`--icon-generation-mode system` / `--badge-generation-mode system`), `--icon-bg-color`, `--icon-symbol-color`, `--badge-bg-color`, and `--badge-symbol-color` resolve against Apple's icon pipeline:

- A **named token** gets Apple's curated rendering for that colour:

  ```
  black  blue  brown  cyan  gray/grey  green  indigo  orange  pink  purple
  red  teal  white  yellow
  ```

  (Note: no `mint` in System mode.)

- **Anything else** (hex, `r,g,b,a`, CSS, extended names) is converted to an exact `r,g,b,a` value and passed through, giving you fully custom System-mode colours.

## Pre-rendered Liquid Glass backgrounds

`--icon-bg prerendered-liquid-glass` takes a named asset colour via `--icon-bg-color`:

```
black  blue  brown  cyan  darkgray/darkgrey  darkmode  gray/grey  green
indigo  lightgray/lightgrey  mint  orange  pink  purple  red  teal  white  yellow
```

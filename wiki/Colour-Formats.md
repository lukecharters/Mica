# Colour Formats

Every colour flag in `mica-cli` accepts the formats below, and so does every colour value in a JSON configuration. In the app, colours are picked with dropdowns and colour wells, so this page is mostly for CLI users.

Both English spellings work throughout: every `--…-color` flag has a `--…-colour` alias, and `grey` is accepted wherever `gray` is.

There are five forms. A colour has one spelling in each — if two forms could express the same colour, only one of them is accepted.

## Named colours

```
blue  red  green  orange  yellow  pink  purple  indigo  teal  mint  cyan
brown  white  black  gray/grey  clear/transparent
```

macOS system colours, which follow the system's own colour definitions and adapt to light and dark:

```
system.blue  system.red  system.green  system.orange  system.yellow
system.pink  system.purple  system.teal  system.indigo  system.mint
system.cyan  system.brown  system.gray/system.grey
label  secondary.label  tertiary.label  quaternary.label
```

A name is a name, not a value: `blue` renders as whatever this machine's macOS says blue is today. That is why a saved configuration reopens correctly in the other appearance, and why it will pick up a future OS's colours rather than freezing to the ones current when you saved.

Names are case-insensitive. The dot is not optional — `system.blue`, never `systemblue`.

## Hex

```shell
--icon-bg-color "#FF6B35"     # RRGGBB
--icon-bg-color "#F80"        # RGB shorthand → FF8800
--icon-bg-color "#FF6B35CC"   # RRGGBBAA (with alpha)
--icon-bg-color FF6B35        # the # is optional
```

## `rgb()` and `hsl()`

```shell
--icon-bg-color "rgb(255,107,53)"        # 0–255
--icon-bg-color "rgb(255,107,53,0.8)"    # a 4th value is the alpha, 0–1
--icon-bg-color "hsl(9,100%,60%)"        # hue in degrees, then percentages
--icon-bg-color "hsl(9,100%,60%,0.8)"
```

`hsl()` is CSS HSL, not HSB: `hsl(0,100%,50%)` is pure red, and lightness 100% is white whatever the saturation.

## Components in a named colour space

The prefix says which space the numbers are in, so nothing has to be guessed:

```shell
--icon-bg-color "srgb:0.2,0.42,0.9"          # sRGB, 0–1
--icon-bg-color "srgb:0.2,0.42,0.9,0.8"      # the 4th value is the alpha
--icon-bg-color "display-p3:1,0.2,0"         # Display P3, 0–1
```

`srgb:` and `display-p3:` are **bounded** spaces: every component must be 0–1, and one outside that is an error rather than a colour quietly clamped to fit.

Two further prefixes are unbounded, and that is how a colour beyond sRGB's gamut is carried:

```shell
--icon-bg-color "extended-srgb:1.093,-0.2267,-0.1501,1"   # = display-p3:1,0,0
--icon-bg-color "extended-gray:1,1"                       # white, 2 components
```

`extended-srgb:` is the form Mica writes into a configuration for any colour that has no name, so you can copy a value straight out of a `.json` file onto the command line. `extended-gray:` is accepted because Icon Composer writes it; Mica never produces it.

Use `display-p3:1,0,0` in preference to the extended spelling of the same colour — it is the same red, and legible.

## Opacity suffix

Any named colour, hex value or function call takes a `:opacity` suffix:

```shell
--icon-symbol-color "white:0.5"
--icon-bg-color "#0088FF:0.5"
--icon-bg-color "rgb(0,136,255):0.5"
```

The suffix **scales** the colour's existing alpha rather than replacing it. Most colours are fully opaque, so `white:0.5` is 50% — but `label` is only about 85% opaque to begin with, so `label:0.5` renders at about 42%.

The space-prefixed forms take no suffix: their last component is already the alpha.

## Colours that contain a comma

Four options take several colours at once and split their value on commas:

```
--icon-bg-gradient-colors   --badge-bg-gradient-colors
--icon-symbol-palette       --badge-symbol-palette
```

Only the comma-free forms work inside them — a name, hex, or either with an opacity suffix. `srgb:`, `display-p3:` and the extended forms cannot be used there. That is why the default palette reads `white,white:0.5,white:0.26`.

In a JSON configuration these four keys also accept a JSON array, which *is* able to carry a comma-containing colour:

```json
{ "icon-bg-gradient-colors": ["display-p3:1,0.2,0", "srgb:0,0.53,1"] }
```

## System (appex) mode colours

In System generation mode (`--icon-generation-mode system` / `--badge-generation-mode system`), `--icon-bg-color`, `--icon-symbol-color`, `--badge-bg-color` and `--badge-symbol-color` resolve against Apple's icon pipeline. The grammar is the same as everywhere else; one branch is special.

- One of Apple's **own 15 tokens** gets its curated rendering — Apple's gradient and material for that colour, not a flat fill:

  ```
  black  blue  brown  cyan  gray/grey  green  indigo  mint  orange  pink
  purple  red  teal  white  yellow
  ```

- **Anything else** — hex, `rgb()`, `srgb:`, a `label`-family token — resolves to exact components and is passed through as a custom colour.

So `white` and `white:0.5` deliberately differ for a *symbol*: the first is Apple's white, the second is a custom translucent white.

Two things System mode cannot do, and it says so rather than rendering something else:

- **A colour outside sRGB.** Apple's pipeline rejects out-of-range components, and clamping one would desaturate your colour without telling you. `display-p3:1,0,0` is refused, with the nearest sRGB colour named in the error. A Display P3 colour *inside* sRGB — most of them — converts exactly and is fine.
- **A translucent background.** The OS honours a symbol's opacity and ignores an enclosure's, so `--icon-bg-color blue:0.5` would render fully opaque. It is refused instead. Put the opacity on the symbol colour, where it works.

  Note `label` and its family count as translucent: `labelColor` is only about 85% opaque, so it cannot be a System-mode background either.

## Pre-rendered Liquid Glass backgrounds

`--icon-bg prerendered-liquid-glass` picks a bundled asset rather than mixing a colour, so `--icon-bg-color` there takes an asset name from its own fixed list rather than the colour grammar above:

```
black  blue  brown  cyan  darkgray/darkgrey  darkmode  gray/grey  green
indigo  lightgray/lightgrey  mint  orange  pink  purple  red  teal  white  yellow
```

## Forms that are not accepted

Each of these once worked and was removed, because it duplicated something above or had to guess what you meant.

| Not accepted | Write instead |
|---|---|
| `0,136,255` or `0.2,0.42,0.9` | `srgb:0.2,0.42,0.9` or `rgb(0,136,255)` |
| `crimson`, `khaki`, `orchid`, `gold`, `lime`, `navy`, `maroon`, `olive`, `silver`, `violet`, `turquoise`, `coral`, `salmon`, `plum`, `magenta`, `lightgray`, `darkgray` | the hex value |
| `rgb(50%,20%,0%)` | `srgb:0.5,0.2,0` |
| `0.5` or `128` | `srgb:0.5,0.5,0.5` |
| `systemblue` | `system.blue` |
| `rgba(255,0,0,0.5)`, `hsla(0,100%,50%,0.5)` | `rgb(255,0,0,0.5)`, `hsl(0,100%,50%,0.5)` |

The bare component list is the one worth explaining: it read its numbers as 0–1 unless one of them exceeded 1, and then as 0–255. So `1,1,1` was white while `2,2,2` was dark gray, and there was no way to ask for the dark gray `0.008,0.008,0.008`. `srgb:` and `rgb()` each say one thing.

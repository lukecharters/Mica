# Colour Formats

Every Mica colour setting accepts the same seven formats.
This rule covers command-line flags and configuration values.

## Accepted forms

| Format | Example | Rules |
|---|---|---|
| Token | `blue` | Uses a named system colour. |
| Hex | `#0088FFCC` | Accepts 3, 6, or 8 digits. |
| RGB | `rgb(0,136,255)` | Uses values from 0 through 255. |
| HSL | `hsl(209,100%,50%)` | Uses degrees and percentages. |
| sRGB components | `srgb:0,0.53,1` | Uses values from 0 through 1. |
| Display P3 components | `display-p3:1,0,0` | Uses the wider Display P3 range. |
| Extended components | `extended-srgb:1.093,-0.227,-0.15,1` | Keeps values outside standard sRGB. |

RGB and HSL accept an optional fourth alpha value equivalent to rgba and hsla.
`extended-srgb:` needs four components.
`extended-gray:` needs two components.

```shell
mica-cli --icon-symbol star.fill --icon-bg-color "hsl(209,100%,50%)" --output star-hsl.png
```

## Colour spaces

A colour space is the range of colours a format can describe.
Display P3 covers more colours than sRGB, mostly more vivid reds and greens.

| Format | Colour space |
|---|---|
| Token, hex, RGB, HSL | sRGB |
| sRGB components | sRGB |
| Display P3 components | Display P3 |
| Extended components | Extended sRGB or extended gray |

### Colours outside sRGB

Some Display P3 and extended colours fall outside the sRGB range.
To keep these colours, export in the Display P3 colour space.
See [Colour Space](Export-Settings#colour-space).

An sRGB export changes each of these colours to the closest sRGB colour.
The result looks less vivid.
sRGB is the default export colour space.

A Display P3 colour inside the sRGB range looks the same in both exports.
A Display P3 export has limits too.
Extended values beyond Display P3 also change to the closest colour it can show.

### Extended sRGB and extended gray

These two formats come from Apple's tools.
Icon Composer writes them in its files.
You rarely need to type one yourself.

**Extended sRGB** uses the sRGB red, green and blue channels.
Its values can go below 0 or above 1.
Those values describe colours that sRGB cannot show.
It takes four values: red, green, blue and alpha.

```text
extended-srgb:1.093,-0.227,-0.15,1
```

This is the most vivid Display P3 red.

When Mica saves a configuration file, it writes custom colours in this format.
Tokens stay as tokens.

**Extended gray** describes a shade of grey.
It takes two values: brightness and alpha.
A brightness of 0 is black and 1 is white.
`extended-gray:0.5,1` is an opaque mid grey.
Mica reads this format but does not write it.

## Colour tokens

Tokens follow the current macOS colour.
They do not represent fixed hex values.

| | | |
|---|---|---|
| `white` | `black` | `clear` |
| `gray` | `blue` | `red` |
| `green` | `orange` | `yellow` |
| `pink` | `purple` | `indigo` |
| `teal` | `mint` | `cyan` |
| `brown` | `primary` | `secondary` |

`grey` is an alias for `gray`.
`transparent` is an alias for `clear`.

The app's preset list contains 15 tokens.
It omits `clear`, `primary`, and `secondary`.
You can still use those tokens in flags and configuration files.

## Opacity

Add `:opacity` to a token, hex value, RGB value, or HSL value.

```shell
mica-cli --icon-symbol star.fill --icon-symbol-color "white:0.5" --output star-opacity.png
```

The suffix multiplies the colour's existing alpha.
It does not replace that alpha.
`primary:0.5` renders near 42% opacity.
The `primary` token starts near 85% opacity.

Component forms do not take this suffix.
Use their alpha component instead.

## Multi-colour settings

Four settings take more than one colour.

| Flag | Required items |
|---|---:|
| `--icon-bg-gradient-colors` | 2 |
| `--badge-bg-gradient-colors` | 2 |
| `--icon-symbol-palette` | 3 |
| `--badge-symbol-palette` | 3 |

On the command line, give each colour as its own value.
Every colour form works this way.

```shell
mica-cli --icon-symbol star.fill --icon-bg custom-gradient --icon-bg-gradient-colors display-p3:1,0.2,0 "rgb(0,136,255)" --output star-gradient.png
```

You can also give one value with commas between the colours.

```shell
mica-cli --icon-symbol star.fill --icon-bg custom-gradient --icon-bg-gradient-colors "blue,rgb(255,107,53)" --output star-gradient-commas.png
```

One comma-separated value accepts every form except the component forms.
A component form has its own commas.
Give each component form as its own value.

Configuration files use an array.

```json
{
  "icon-bg-gradient-colors": [
    "display-p3:1,0.2,0",
    "srgb:0,0.53,1"
  ]
}
```

## System mode

System mode accepts the same colour grammar.
It adds limits for macOS icon rendering.

The following 15 tokens receive Apple's system treatment.

| | | |
|---|---|---|
| `black` | `blue` | `brown` |
| `cyan` | `gray` | `green` |
| `indigo` | `mint` | `orange` |
| `pink` | `purple` | `red` |
| `teal` | `white` | `yellow` |

Other accepted colours use their exact components.
Every System mode colour must fit inside sRGB.
System mode refuses colours outside that range.

System mode background colours must be fully opaque.
This rule applies to icon and badge backgrounds.
Symbol colours can use opacity.

`clear`, `primary`, and `secondary` are not System mode tokens.
`primary` and `secondary` are also translucent.
You cannot use them for a System mode background.

See [Generation Modes](Generation-Modes) for the full mode comparison.

## Not accepted

Mica refuses forms that duplicate another form or hide the colour space.

| Not accepted | Use instead |
|---|---|
| `rgba(0,136,255,0.5)` | `rgb(0,136,255,0.5)` |
| `hsla(209,100%,50%,0.5)` | `hsl(209,100%,50%,0.5)` |
| `0,136,255` | `rgb(0,136,255)` |
| `crimson` or `khaki` | A hex value |
| `rgb(50%,20%,0%)` | `srgb:0.5,0.2,0` |
| `0.5` | `srgb:0.5,0.5,0.5` |
| `system.blue` | `blue` |
| `label` | `primary` |
| `secondary.label` | `secondary` |

The command line stops when a colour is invalid.
A configuration file warns for that key.
It continues loading the remaining keys.

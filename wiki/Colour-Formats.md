# Colour Formats

Every Mica colour setting accepts the same seven forms.
This rule covers command-line flags and configuration values.

## Accepted forms

| Form | Example | Rules |
|---|---|---|
| Token | `blue` | Uses a named system colour. |
| Hex | `#0088FFCC` | Accepts 3, 6, or 8 digits. |
| RGB | `rgb(0,136,255)` | Uses values from 0 through 255. |
| HSL | `hsl(209,100%,50%)` | Uses degrees and percentages. |
| sRGB components | `srgb:0,0.53,1` | Uses values from 0 through 1. |
| Display P3 components | `display-p3:1,0,0` | Converts to Mica's stored colour space. |
| Extended components | `extended-srgb:1.093,-0.227,-0.15,1` | Keeps values outside standard sRGB. |

RGB and HSL accept an optional fourth alpha value.
`extended-srgb:` needs four components.
`extended-gray:` needs two components.

```shell
mica-cli --icon-symbol star.fill --icon-bg-color "hsl(209,100%,50%)"
```

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
mica-cli --icon-symbol star.fill --icon-symbol-color "white:0.5"
```

The suffix multiplies the colour's existing alpha.
It does not replace that alpha.
`primary:0.5` renders near 42% opacity.
The `primary` token starts near 85% opacity.

Component forms do not take this suffix.
Use their alpha component instead.

## Multi-colour settings

Four command-line flags split their values at commas.

| Flag | Required items |
|---|---:|
| `--icon-bg-gradient-colors` | 2 |
| `--badge-bg-gradient-colors` | 2 |
| `--icon-symbol-palette` | 3 |
| `--badge-symbol-palette` | 3 |

Use tokens or hex values in these flags.
Either form can include an opacity suffix.
Component forms contain commas and cannot work inside these flags.

Configuration files can use an array instead.

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

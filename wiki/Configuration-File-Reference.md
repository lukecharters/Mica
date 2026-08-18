# Configuration File Reference

A configuration file stores the settings that affect one icon.
Use it to keep icon designs in version control.

Mica keeps no work between launches.
Export a configuration when you need to keep your settings.

## File format

A configuration is one flat JSON object.
Each key matches a long command-line flag without `--`.

| Command-line flag | Configuration key |
|---|---|
| `--icon-bg-color` | `"icon-bg-color"` |
| `--badge-position` | `"badge-position"` |
| `--size` | `"size"` |

`--icon-symbol` and `--badge-symbol` have no configuration keys.
Use `"icon-fg": "symbol:NAME"` or `"badge-fg": "symbol:NAME"`.

Invocation options also have no keys.
These options are `--output`, `--config`, `--json`, `--quiet`, and `--verbose`.

## Complete example

This example creates a configuration and generates its icon.

```shell
cat > fleet-icon.json <<'JSON'
{
  "size": 512,
  "scale": "1x",
  "color-space": "sRGB",
  "icon-generation-mode": "mica",
  "icon-fg": "symbol:lock.shield.fill",
  "icon-symbol-color": "white",
  "icon-bg": "standard",
  "icon-bg-color": "blue",
  "badge-fg": "symbol:checkmark",
  "badge-symbol-color": "white",
  "badge-bg-color": "green",
  "badge-position": "bottom-right"
}
JSON

mica-cli --config fleet-icon.json --output fleet-icon.png
```

The command creates `fleet-icon.png`.
Command-line settings override matching configuration values.

```shell
mica-cli --config fleet-icon.json --size 1024 --output fleet-icon-1024.png
```

## Value shapes

Most values use strings.
Size and numeric scales can use JSON numbers.
On/off settings accept two shapes.

| Setting type | Accepted JSON |
|---|---|
| Text or token | `"blue"` |
| Number | `512` or `1.25` |
| Switch | `true`, `false`, `"on"`, or `"off"` |

Four multi-colour keys also accept a JSON array.

| Key | Array length |
|---|---:|
| `"icon-bg-gradient-colors"` | 2 |
| `"badge-bg-gradient-colors"` | 2 |
| `"icon-symbol-palette"` | 3 |
| `"badge-symbol-palette"` | 3 |

Arrays allow colours that contain commas.

```json
{
  "icon-symbol-rendering": "palette",
  "icon-symbol-palette": [
    "display-p3:1,0,0",
    "srgb:0,0.53,1",
    "white:0.7"
  ]
}
```

See [Colour Formats](Colour-Formats) for every accepted colour form.

## Image paths

An image source can use an absolute or relative path.
A relative path starts from the configuration file's folder.

```json
{
  "icon-fg": "images/company-mark.png",
  "icon-bg-color": "blue"
}
```

This example expects an `images` folder beside the configuration file.

## Warnings and errors

An unknown key produces a warning.
An unusable value also produces a warning.
Mica still loads the remaining valid keys.

Malformed JSON stops the import.
A missing image also prevents that image from loading.

The following file warns about `team-name`.
It still loads the icon settings.

```json
{
  "team-name": "Security",
  "icon-fg": "symbol:lock.fill",
  "icon-bg-color": "blue"
}
```

## Exports with images

An export with no imported images creates one JSON file.
An export with images creates a folder.

The folder contains one JSON file and flat PNG sidecars.
Re-import the folder to restore the images.
Do not import only the JSON inside that folder.

Importing that JSON loads the settings without its images.
Mica warns you to import the folder.

Image bytes can change after a round trip.
Mica re-encodes the same picture.

## What an export keeps

A configuration records settings that affect the current icon.
It does not store inactive alternatives.

For example, palette colours only affect palette rendering.
Switching to monochrome removes those colours from the next export.

Hidden layer appearance settings are also omitted.
System mode omits Mica-only settings for that group.

See [Settings Index](Settings-Index) for all configuration keys.

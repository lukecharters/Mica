# Reuse Settings With Config Files

Design one icon in the app and reuse its settings from scripts or Git.

## Export from the app

1. Create the icon in Mica.
2. Choose **File ▸ Export Configuration**.
3. Save the file as `fleet-icon.json`.

If your icon uses imported images, Mica exports a folder.
Keep the whole folder together.

**Result:** The configuration records the settings that affect the current icon.

## Render it from Terminal

Open Terminal in the folder that contains the configuration.

```shell
mica-cli --config fleet-icon.json --output fleet-icon.png
```

**Result:** `fleet-icon.png` matches the app preview.

## Override one setting

```shell
mica-cli --config fleet-icon.json \
  --icon-bg-color red \
  --output fleet-icon-red.png
```

Command-line settings override matching configuration values.

## Keep it in Git

```shell
git add fleet-icon.json
git commit -m "docs: add fleet icon configuration"
```

Commit the exported folder when the configuration uses images.
Re-import that folder instead of its JSON file.

## Change the result

- [Configuration File Reference](Configuration-File-Reference) explains every file rule.
- [Settings Index](Settings-Index) lists all configuration keys.

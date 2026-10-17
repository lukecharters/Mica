# Use Presets
A preset is a saved look you can apply in one click.
Mica ships a set of presets and lets you save your own.

An icon preset changes the icon only.
A badge preset changes the badge only.
Neither changes your export size or colour space.

## Apply a preset
1. Click **Icon Presets** or **Badge Presets** in the toolbar. They sit left of the size and zoom menus.
2. Click a preset.

The popover stays open, so you can try several presets in a row.
Click anywhere else, or press **Escape**, to close it.
Press **⌘Z** to undo a preset.

Each thumbnail draws the preset on its own, not on your icon.
A badge thumbnail has an arrow that points to the badge's corner.

To search every preset, click **Show All Presets…** at the bottom of the popover.
See [Presets window](The-Mica-Window#presets-window).

## What a preset replaces
A preset replaces its whole half of the icon.
Settings the preset does not name go back to their defaults.
Two presets in a row give the same result as the second one alone.
A badge preset also sets the badge's corner, size and offsets.
Applying a badge preset turns the badge on.

A sliders symbol after a name means the preset needs advanced controls.
Applying it turns on **Show Advanced Controls**. Undo leaves them on.

## Save your own
1. Set up the icon or badge the way you want it.
2. Click **+** at the top of the **Icon Presets** or **Badge Presets** popover.
3. Type a name and click **Save**.

Save a badge preset only while the badge is on.
Your presets show a person symbol before their name.
A preset cannot hold imported artwork. Mica saves the rest and tells you what it left out.

To delete one of your presets, right-click it and choose **Delete**.
You cannot delete the built-in presets.

Mica keeps your presets as files in this folder:

```text
~/Library/Containers/com.lukecharters.Mica/Data/Library/Application Support/Mica/Presets
```

## Use a preset on the command line
Give the preset's name or slug to `--icon-preset` or `--badge-preset`.

```shell
mica-cli --icon-preset Settings --icon-symbol hammer.fill --output icon.png
```

That command uses the Settings preset's colours with a different symbol.
See [CLI Reference](CLI-Reference#presets) for slugs and badge presets.

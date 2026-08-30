# Use Presets
A preset is a saved look you can apply in one click.
Mica ships ten presets and lets you save your own.

There are two kinds.
An icon preset changes the icon only.
A badge preset changes the badge only.
Neither changes your export size, scale, or colour space.

## Apply a preset
1. Open Mica.
2. Click the presets button at the top left, beside the sidebar button. You can also choose **View ▸ Show Presets**, or press **⌃⌘P**.
3. Click a preset.

The presets button fills in while the pane is open.

The pane shows Icon Presets first, then Badge Presets.
Each thumbnail draws that preset on its own.
It does not show your current icon.

A badge thumbnail shows the badge in the centre.
Behind it is one corner of a grey placeholder icon.
That corner is the corner the preset puts the badge in.

Press **⌘Z** to undo a preset.

## What a preset replaces
A preset replaces its whole half of the icon.
Settings the preset does not name go back to their defaults.

This means clicking two presets in a row gives the same result as clicking the second one alone.
A badge preset also sets the corner, the size, and both offsets.
It replaces an arrow-key nudge. Press **⌘Z** to get the nudge back.

Applying a badge preset turns the badge on.

## The advanced controls marker
Some presets need settings the simple inspector cannot show.
Those presets carry a small marker in the corner of the thumbnail.

Applying one turns on **Show Advanced Controls**.
The marker only appears while advanced controls are off.

Undo restores your icon. It leaves advanced controls on.

## Save your own
1. Select **Icon** or **Badge** in the sidebar.
2. Click **Save Icon Preset…** or **Save Badge Preset…** at the bottom of the pane.
3. Type a name and click **Save**.

The button follows the sidebar selection.
Save a badge preset only while the badge is on.

Mica adds a number if the name is taken.
The sheet tells you before you save.

Right-click one of your presets and choose **Delete** to remove it.
You cannot delete the ten built-in presets.

Your presets are files. Mica keeps them here:

```text
~/Library/Containers/com.lukecharters.Mica/Data/Library/Application Support/Mica/Presets
```

A preset cannot hold imported artwork.
Mica saves the rest and tells you what it left out.

## Presets on the command line
Use `--icon-preset` and `--badge-preset` with the preset's name.

```shell
mica-cli --icon-preset Installer --output icon.png
```

Presets apply before your other flags.
So a flag always wins.

```shell
mica-cli --icon-preset Media --icon-symbol hammer.fill --output icon.png
```

That command uses Media's colours with a different symbol.

`mica-cli` reads the presets you saved in the app.
Names are not case sensitive.

A badge preset does not supply an icon symbol.
Give one with `--icon-symbol`.

```shell
mica-cli --icon-symbol app.fill --badge-preset Update --output icon.png
```

See [CLI Reference](CLI-Reference) for every flag.
See [Reuse Settings With Config Files](Reuse-Settings-With-Config-Files) for whole-icon files you can share.

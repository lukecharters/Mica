# Use Presets
A preset is a saved look you can apply in one click.
Mica ships a set of presets and lets you save your own.

There are two kinds.
An icon preset changes the icon only.
A badge preset changes the badge only.
Neither changes your export size, scale, or colour space.

## Apply a preset
1. Open Mica.
2. Click **Icon Presets** or **Badge Presets** in the toolbar. They are the two buttons right of the zoom and size menus.
3. Click a preset.

The presets open in a popover under the button.
The popover stays open, so you can try several presets in a row.
Click anywhere else, or press **Escape**, to close it.

Each thumbnail draws that preset on its own.
It does not show your current icon.

A badge thumbnail shows the badge in the centre.
A small arrow points to the corner the preset puts the badge in.

Press **⌘Z** to undo a preset.

## The Presets window
The Presets window shows every preset and has a search field.
Open it in one of three ways.

| Way | Where |
|---|---|
| **Show All Presets…** | The button at the bottom of either popover |
| **View ▸ Show Presets** | The menu bar. Or press **⌃⌘P**. |
| **Window ▸ Presets** | The menu bar |

Click **Icon** or **Badge** at the top to choose the kind.
Type in the search field to filter by name.
Each kind has two sections: **Built-in** and **Yours**.
Click a section heading to fold that section away.
Mica remembers which sections you folded.

A preset applies to the icon window you used last.
The Presets window can stay open while you work in that window.
With no icon window open, a notice appears and the presets dim.
You can still browse and delete presets. Open an icon window to apply one.

## What a preset replaces
A preset replaces its whole half of the icon.
Settings the preset does not name go back to their defaults.

This means clicking two presets in a row gives the same result as clicking the second one alone.
A badge preset also sets the corner, the size, and both offsets.
It replaces an arrow-key nudge. Press **⌘Z** to get the nudge back.

Applying a badge preset turns the badge on.

## The advanced controls marker
Some presets need settings the simple inspector cannot show.
Those presets show a sliders symbol after their name.

Applying one turns on **Show Advanced Controls**.
The symbol only appears while advanced controls are off.

Undo restores your icon. It leaves advanced controls on.

## Save your own
1. Click **+** at the top of the **Icon Presets** or **Badge Presets** popover.
2. Type a name and click **Save**.

Each popover's **+** saves that kind of preset.
The **+** in the Presets window saves the kind you chose at the top.
A badge **+** is dimmed while the badge is off.
Save a badge preset only while the badge is on.

Your presets show a person symbol before their name.

Mica adds a number if the name is taken.
The sheet tells you before you save.

Right-click one of your presets and choose **Delete** to remove it.
You cannot delete the built-in presets.

Your presets are files. Mica keeps them here:

```text
~/Library/Containers/com.lukecharters.Mica/Data/Library/Application Support/Mica/Presets
```

A preset cannot hold imported artwork.
Mica saves the rest and tells you what it left out.

## Presets on the command line
Use `--icon-preset` and `--badge-preset` with the preset's name.

```shell
mica-cli --icon-preset Settings --output icon.png
```

Presets apply before your other flags.
So a flag always wins.

```shell
mica-cli --icon-preset Settings --icon-symbol hammer.fill --output icon.png
```

That command uses the Settings preset's colours with a different symbol.

`mica-cli` reads the presets you saved in the app.
Names are not case sensitive.

A badge preset does not supply an icon symbol.
Give one with `--icon-symbol`.

```shell
mica-cli --icon-symbol app.fill --badge-preset Update --output icon.png
```

See [CLI Reference](CLI-Reference) for every flag.
See [Reuse Settings With Config Files](Reuse-Settings-With-Config-Files) for whole-icon files you can share.

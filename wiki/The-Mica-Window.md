# The Mica Window
The Mica window has three panes for selecting, viewing, and changing an icon.

<img src="images/window-anatomy.png" width="900" alt="The Mica window with the sidebar, canvas, and inspector labelled">

## Panes
| Pane | Purpose |
|---|---|
| Sidebar | Selects the Icon or Badge group and its layers. |
| Canvas | Shows the current icon and accepts direct actions. |
| Inspector | Changes the selected group or layer. |

Use **View ▸ Show Sidebar** or **⌃⌘S** to show the sidebar.
Use **View ▸ Show Inspector** or **⌃⌘I** to show the inspector.

## Sidebar
The sidebar contains the Icon and Badge groups.
Advanced controls add Foreground and Background rows.
The Badge group also has a Layout row.

Select a row to show its controls.
Each eye shows or hides that layer.
A mixed group eye means one layer is hidden.
The Layout row has no eye because it is not a layer.

<img src="images/sidebar-eyes.png" width="280" alt="Sidebar rows with the icon background hidden and the Icon group eye mixed">

The icon background is hidden here, so the Icon eye is mixed.

## Toolbar
| Control | Purpose |
|---|---|
| Zoom | Changes the canvas zoom. Lists nine steps from 25% to 800%. |
| Preview Size | Shows the icon at a chosen point size. |
| Sliders button | Shows or hides advanced controls. |
| Controls and Export | Selects the inspector tab. |
| Inspector button | Shows or hides the inspector. |

Preview size and zoom do not change the exported PNG.

A pinch or a ⌘ scroll can set any zoom between 25% and 800%.
The menu then shows that value with no step ticked.
⌘+ and ⌘− still move to the next step up or down.

## Symbol browser
Click the grid button beside a Symbol field to open the symbol browser.
Type in Search to filter the grid.
Use the Rendering menu to change how the grid draws each symbol.
This changes the grid only.
It does not change your icon.
Use the arrow keys to move the highlight.
Press Return to select the highlighted symbol.
Press Escape with an empty search to close the browser.

<img src="images/symbol-browser.png" width="700" alt="The symbol browser filtered by a search for star">

## Canvas actions
| Action | Result |
|---|---|
| Click a visible layer | Selects that layer. |
| Drag the badge | Changes its offset. |
| Press an arrow key | Nudges the badge by one percent. |
| Drop an image on the icon | Imports the icon background. |
| Drop an image on the badge | Imports the badge background. |
| Right-click | Opens copy, export, paste, remove, and reset actions. |
| Pinch on a trackpad | Zooms the canvas. |
| Hold ⌘ and scroll | Zooms the canvas. |
| Scroll | Moves the canvas when the icon is larger than the pane. |

System mode does not accept image drops for that group.

Both zoom gestures work in Mica mode and System mode.
The pointer must be over the canvas.

## Exporting a PNG
Press ⇧⌘E, or click **Export** in the Export tab.
The Save panel opens with the size, scale, and colour space at the bottom.
Change them there to export one file at different settings.
The window's own settings do not change.

## Developer menu
Mica includes the tools used to build it. They are hidden by default.

Turn them on in **Settings ▸ Developer**. A **Developer** menu appears in the menu bar.
You do not need these tools to make icons. They are not supported.

| Menu item | What it does |
|---|---|
| Symbol Calibration | Reviews and changes how each SF Symbol is sized. |
| Reference Comparison | Compares a Mica icon against a reference image. |
| Generate Symbol Metrics | Measures every SF Symbol again. |
| Export Shadow Variations… | Saves a set of icons with different shadows. |

Symbol Calibration changes how Mica sizes symbols in every icon you make.
Click **Restore Bundled Calibration** in that window to undo the change.
Mica reads symbol sizing once when it starts. Quit and reopen Mica to apply it.

None of these items has a keyboard shortcut.

## Keyboard shortcuts
| Shortcut | Action |
|---|---|
| ⇧⌘E | Export as PNG |
| ⌘S | Export Configuration |
| ⌘O | Import Configuration |
| ⇧⌘C | Copy Icon |
| ⌘C | Copy the focused canvas icon or selected text |
| ⌘V | Paste an image as the icon background |
| ⌃⌘S | Show or hide the sidebar |
| ⌃⌘I | Show or hide the inspector |
| ⌘+ / ⌘− / ⌘0 | Zoom in, zoom out, or use actual size |
| ⌘, | Open Settings |

The four **Paste as** and four **Import as** commands have no shortcuts.

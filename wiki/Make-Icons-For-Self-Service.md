# Make Icons For Self Service

Create a 512-pixel PNG and upload it to your Self Service item.

## Generate the icon

```shell
mkdir -p ~/Desktop/mica-icons
mica-cli --icon-symbol lock.shield.fill \
  --icon-bg-color blue \
  --size 512 \
  --output ~/Desktop/mica-icons/security-tools.png
```

**Result:** `~/Desktop/mica-icons/security-tools.png` is ready for upload.

## Add it to Jamf Self Service

1. Open the policy in Jamf Pro.
2. Open its **Self Service** settings.
3. Upload `security-tools.png` in the icon field.
4. Save the policy.
5. Check the catalogue and item views.

Use Mica's **Preview Size** menu before upload.
Self Service+ uses 40 points in the catalogue and 88 points on the item page.
Self Service classic uses 75 points and 120 points.

## Other fleet tools

| Tool | Where to use the PNG |
|---|---|
| Microsoft Intune | Company Portal app or script assignment artwork |
| Mosyle | Self-Service item artwork |
| Kandji | Self Service Library item artwork |

Check current vendor guidance before upload.
File limits and required dimensions can change.

## Change the result

- [Icon Settings](Icon-Settings) lists every visual control.
- [Export Settings](Export-Settings) explains size, scale, and colour space.
- [Bulk Generate Icons](Bulk-Generate-Icons) creates a full catalogue.

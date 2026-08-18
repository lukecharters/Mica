# Badge An Icon

Add a badge when one base icon needs install, repair, or removal variants.

## Add the badge

```shell
mica-cli --icon-symbol app.fill \
  --badge-symbol plus.circle.fill \
  --output install.png
```

**Result:** `install.png` has a plus badge in the bottom-right corner.

## Move the badge

```shell
mica-cli --icon-symbol app.fill \
  --badge-symbol wrench.fill \
  --badge-position top-right \
  --output repair.png
```

## Resize the badge

```shell
mica-cli --icon-symbol app.fill \
  --badge-symbol minus.circle.fill \
  --badge-scale 1.2 \
  --output remove.png
```

## Fine-tune the position

```shell
mica-cli --icon-symbol app.fill \
  --badge-symbol checkmark \
  --badge-offset-x=-0.08 \
  --badge-offset-y=0.05 \
  --output complete.png
```

Attach a negative value with `=`.
A space makes the number look like another flag.

Above about 109% size, the badge moves inward to stay inside the icon.
The exported PNG keeps the requested size.

## Change the result

- [Badge Settings](Badge-Settings) covers every badge control.
- [Colour Formats](Colour-Formats) lists accepted badge colours.

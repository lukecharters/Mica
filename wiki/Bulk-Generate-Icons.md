# Bulk Generate Icons
Generate a consistent icon set from a shell list, CSV file, or base configuration.

## Generate a list of symbols

```shell
mkdir -p icons
for symbol in lock.fill wrench.fill trash.fill; do
  name="${symbol//./-}"
  mica-cli --icon-symbol "$symbol" --icon-bg-color blue --output "icons/$name.png" --quiet
done
```
**Result:** The `icons` folder contains three blue icons.

## Read names, symbols, and colours from CSV

```shell
cat > icons.csv <<'CSV'
name,symbol,colour
security,lock.shield.fill,blue
repair,wrench.and.screwdriver.fill,orange
remove,trash.fill,red
CSV

mkdir -p icons
tail -n +2 icons.csv | while IFS=, read -r name symbol colour; do
  mica-cli --icon-symbol "$symbol" --icon-bg-color "$colour" --output "icons/$name.png" --quiet
done
```
**Result:** Each CSV row creates one named PNG.

## Use a base configuration

```shell
cat > base-icon.json <<'JSON'
{
  "size": 512,
  "icon-generation-mode": "mica",
  "icon-fg": "symbol:app.fill",
  "icon-symbol-color": "white",
  "icon-bg": "standard",
  "icon-bg-color": "blue"
}
JSON

mkdir -p icons
for item in "security:lock.shield.fill" "repair:wrench.fill"; do
  name="${item%%:*}"
  symbol="${item#*:}"
  mica-cli --config base-icon.json --icon-symbol "$symbol" \
    --output "icons/$name.png" --json |
    plutil -extract outputs.0.path raw -o - -
done
```
**Result:** `plutil` prints each saved path.
## Change the result

- [Configuration File Reference](Configuration-File-Reference) documents the base file.
- [CLI Reference](CLI-Reference) lists output modes and exit status.

<!--
Please open an issue to discuss code changes before opening a pull request.
See CONTRIBUTING.md — "Open an issue first".
-->

## What this changes

<!-- The intent of the change, not a file-by-file list. -->

Closes #

## Tests run

<!-- Paste the commands you ran and their result. -->

```shell
xcodebuild test -project Mica.xcodeproj -scheme Mica -destination "platform=macOS"
xcodebuild test -project Mica.xcodeproj -scheme mica-cli -destination "platform=macOS"
scripts/tests/cli-smoke-test.sh
```

## Checklist

- [ ] The change landed in **both** the app and the CLI, or it only applies to one and I've said which.
- [ ] New behaviour has tests. Shared logic (`Models/`, `Services/`) is tested in `MicaTests`; flag parsing in `mica-cli Tests`.
- [ ] Any new file under `Mica/Models/` or `Mica/Services/` was added to both `membershipExceptions` lists in `project.pbxproj`; any new file under `mica-cli/CLI/` was added to the `mica-cli Tests` list.
- [ ] Documentation follows the change — the `wiki/` page for any setting or flag, and the README if it touches the essentials shown there.
- [ ] I have not committed a `DEVELOPMENT_TEAM` change.

## Screenshots or output

<!-- Include these whenever behaviour changes. Before/after images for anything visual. -->

## AI-assisted contributions

If any of this was written with AI assistance, please confirm:

- [ ] I use Mica and found this problem or wanted this feature myself.
- [ ] I have built and run this, and verified it does what I expected.
- [ ] The existing tests pass and new behaviour has tests.

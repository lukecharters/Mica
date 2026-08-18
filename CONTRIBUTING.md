# Contributing to Mica

Thanks for your interest in contributing.

## Open an issue first

**Please open an issue to discuss what you'd like to change before opening a pull request.**
Bug reports and feature ideas are very welcome and need no discussion first — file them freely.
It's code changes that want a conversation up front.

Mica is early, and a fair amount of the design has reasoning behind it that isn't visible in the
code yet: why the badge clamps inward instead of growing the canvas, why a colour carries its
provenance, why an imported background hides the foreground. That reasoning is written down, but
it isn't published yet, so an unsolicited pull request is likely to run into a constraint neither
of us can see coming — and that wastes your time more than mine.

Tell me what you want to build in an issue and I'll tell you what you need to know about that part
of the codebase, and publish the relevant design notes. As people start doing that, more of those
notes will be published as a matter of course.

## AI-assisted contributions

AI assisted contributions are welcome under the following criteria:

1. You are a human who uses the app and found a problem or had an idea for a feature/improvement.
2. You, a human, validated that the code builds, runs, and works as you expected.
3. The build passes all existing tests and any new features have a test created for them.

Drive-by AI pull requests will not be accepted.

## Requirements

- macOS 15 Sequoia or later (macOS 26 Tahoe to work on Liquid Glass / System mode features)
- Xcode 16 or later

## Building from source

Clone the repository and open `Mica.xcodeproj` in Xcode. There are two main schemes:

- **Mica** — the macOS app. The built app embeds the CLI binary.
- **mica-cli** — the command-line tool.

Or build from the command line:

```shell
xcodebuild build -project Mica.xcodeproj -scheme Mica -destination "generic/platform=macOS" -quiet
```

Use `generic/platform=macOS` (not `platform=macOS`) for builds — it builds all configured architectures, which is what you want for anything that will be distributed.

There is no SwiftPM package; the CLI is an Xcode target whose sources live in `mica-cli/CLI/` and share `Mica/Models/` and `Mica/Services/` with the app.

### Project layout

| Path | Contents |
|---|---|
| `Mica/Models/` | Configuration models shared by the app and CLI (`IconSettings`, `GenerationMode`, …). Adding a file here means editing two `membershipExceptions` lists in `project.pbxproj` — if the CLI doesn't need it, put it in `Mica/App/` |
| `Mica/Services/` | The rendering engine (`IconRenderer`), export, symbol sizing, image import |
| `Mica/App/` | App-target-only code: `IconViewModel` (state coordinator), the PNG export payload, preview hit testing, inspector state |
| `Mica/Views/` | All SwiftUI views (sidebar, preview, symbol picker, controls) |
| `mica-cli/CLI/` | CLI argument parsing and command implementations |
| `MicaTests/`, `MicaUITests/`, `mica-cli Tests/` | Test targets |
| `scripts/` | Packaging (`build-pkg/`), the end-to-end CLI smoke test and the documentation checks (`tests/`), and the wiki generator and sync (`docs/`) |

Both interfaces share the same models and services — a new feature should land in **both** the app and the CLI wherever it applies, with tests.

## Running the tests

Tests use the Swift Testing framework (`@Suite`, `@Test`, `#expect`).

Run in Xcode via the Test Navigator, or from the command line — no signing overrides:

```shell
# App/shared-logic tests
xcodebuild test -project Mica.xcodeproj -scheme Mica -destination "platform=macOS"

# CLI tests (flag parsing and CLI contract)
xcodebuild test -project Mica.xcodeproj -scheme mica-cli -destination "platform=macOS"

# End-to-end CLI smoke test
scripts/tests/cli-smoke-test.sh
```

`MicaTests` and `MicaUITests` are injected into `Mica.app`, and macOS refuses to load a test bundle whose Team ID differs from the host's — so set `DEVELOPMENT_TEAM` to **your own** team on every target (Xcode ▸ target ▸ Signing & Capabilities, with "Automatically manage signing" on) rather than disabling signing on some targets and not others. Don't commit that change.

Put tests for shared logic (`Models/`, `Services/`) in `MicaTests`; CLI flag-parsing tests belong in `mica-cli Tests`.

Note: if you add a new source file under `mica-cli/CLI/`, it must also be added to the `mica-cli Tests` target's membership exceptions in `project.pbxproj` (the test bundle compiles the CLI sources directly).

## Documentation and the wiki

The GitHub wiki's source pages live in `wiki/` in this repository. A GitHub wiki is its own git repository and is not included when you clone this one, so `wiki/` is the source of truth — versioned alongside the code, reviewable in a pull request, and covered by the checks below. The published wiki is only ever a copy of it.

To publish:

```shell
scripts/docs/sync-wiki.sh

DRY_RUN=1 scripts/docs/sync-wiki.sh   # show what would change, push nothing
```

It clones the wiki repository, syncs `wiki/` across, pushes, and then checks that the pages the app's Help menu opens actually resolve. Read its header before changing it — it records four things that will otherwise cost you an hour.

Two of those matter even if you ever sync by hand:

- **The first sync has to be preceded by creating a page in the browser.** Enabling Wikis in Settings does not create the repository, and there is no API for creating a page. Until one exists the clone fails with "repository not found", which reads exactly like an auth failure.
- **The sync must delete.** Copying with `cp` only ever adds and overwrites, so a renamed or deleted page stays on the published wiki forever, still linked from search, with nothing to tell you. (The wiki's branch may also be `master` rather than `main`; pushing a hardcoded `main` creates a second branch that renders nothing.)

If a change alters CLI flags or app controls, update the matching wiki page (and the README if it touches the essentials shown there). Two checks run against `wiki/`, and both are worth running before you push:

```shell
scripts/tests/check-wiki-coverage.sh   # every configuration key has a reference entry
scripts/tests/check-help-links.sh      # every page the Help menu links to exists
```

Example images are generated rather than hand-made — `scripts/docs/generate-wiki-examples.sh`, with the exact command behind each one recorded in `wiki/images/MANIFEST.md`. Changing a default means re-running the generator, or the page shows a picture of the old one.

## Commit style

The project uses [Conventional Commits](https://www.conventionalcommits.org): `feat|fix|chore|docs|test|refactor|build|ci|style|perf`, with an optional scope, e.g. `feat(cli): add capture retry`.

## Pull requests

- Link the issue where the change was discussed.
- Summarise the intent of the change.
- List the test commands you ran.
- Mention any documentation updates (README / wiki).
- Include screenshots or terminal snippets when behaviour changes.

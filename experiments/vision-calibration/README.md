# Vision-model calibration feasibility

A throwaway harness that asks whether Apple's Foundation Models (macOS 27, on-device and
Private Cloud Compute) can do the symbol calibration that is currently done by eye in
Developer ▸ Symbol Calibration. It has no dependency on the Mica targets and is not built by
the Xcode project.

It reproduces the calibration tool's two halves:

- **Mica's side**: `DimIconView`'s geometry from `Mica/DevTools/SymbolCalibrationTool.swift`
  (256-unit base, 25-unit inset, `fontSize = enclosure × multiplier`, offsets as fractions of
  the enclosure), rendered at 512 pt @2x.
- **Apple's side**: `Storage.appex` with `ISSymbolName` rewritten, read back through
  `NSWorkspace`, as `AppexReferenceService` does. Renders are cached in `.cache/refs/`.

Ground truth is the hand-calibrated entries in `Mica/Resources/symbol-calibration.json`,
sampled evenly from four strata (non-zero offset, non-regular weight, multiplier < 0.62, the
rest).

## Running

Everything needs the Bash sandbox off: IconServices and the model service are both blocked
inside it.

```bash
swift build
.build/debug/vcal probe                      # which models are available, with vision?
.build/debug/vcal render figure.tennis 0.65 0 0 regular   # eyeball the inputs
.build/debug/vcal perceive --reference mica  # can it tell which way an error runs?
.build/debug/vcal calibrate                  # one-shot vs iterative vs pixel fit
swift build -c release && .build/release/vcal precision --colours blue+white,black+white,white+black,white+blue
```

**References follow the system appearance.** In dark mode IconServices draws the dark variant (a
near-black enclosure with the glyph in the enclosure colour), and neither the drawing appearance
nor `NSApp.appearance` changes that. References are cached under `.cache/refs/light/` or `dark/`,
and a render is refused when the system is not in the mode asked for. Every result below is light mode.

Each run writes `runs/<name>/summary.md`, `results.json`, and the model's input images for
the first few symbols.

## What each command measures

- **`perceive`** perturbs one parameter of a known-good render by a known amount (size ±2–20%,
  offset ±0.01–0.06 of the enclosure, weight ±1–2 steps) and asks which way the candidate
  differs. This decides whether iteration could converge at all: a loop can only get as close
  as the smallest error the model can see the direction of. `--reference mica` compares
  Mica against Mica, so nothing differs except the perturbation.
- **`calibrate`** starts each symbol from a seeded perturbation of its hand values and runs:
  - `oneshot`: one call returning numeric corrections (size %, move right %, move down %, weight).
  - `iterate`: the model reports direction and rough size per axis; each axis keeps its own
    step, halved when the model reverses. Up to `--steps` calls.
  - `pixel`: no model. Bounding-box alignment then coordinate descent on glyph-mask IoU,
    once per weight.

## Two cautions when reading results

- **The hand values are stale on macOS 27 for some symbols.** `envelope.and.hand.raised.fill`
  is stored at 0.58; Apple now draws it at about 0.47. Distance from the hand values
  therefore understates any method that tracks Apple's current render, which is why the
  summaries also report IoU against the reference and distance from the pixel fit.
- **The glyph mask is a threshold** (`min(r,g,b) > 175` on an opaque pixel). It separates a
  white glyph from the default blue enclosure and nothing else; other colours need a
  different rule.

## Findings, 2026-10-02 (macOS 27.0, Xcode 27.2 SDK)

**The on-device model cannot do this, and iteration does not rescue it.** 140 perception
trials per configuration, six symbols, Mica-vs-Mica references so only the perturbation differs:

| configuration | size, 20% error | x, 0.06 error | y, 0.06 error | unperturbed read as a match |
|---|---|---|---|---|
| overlay | 25% right, 67% "same" | 8% | 0%, always "aligned" | 83% |
| side by side | 0%, always "same" | 50%, always "right" | 0% | 0% |
| both images + observation | 17% | 42% | 8% | 0% |
| overlay + observation | 8% | 67%, always "right" | 0% | 0% |

The answers barely depend on the input. It says "same" for a 20% size error, "aligned"
vertically for every case, and "right" horizontally whichever way the glyph moved. A loop can
only get as close as the smallest error whose direction the model can see; here there isn't one.

`calibrate`, 12 symbols, from starts about 8–20% off in size and 0.02–0.06 off in each offset:

| method | mean IoU with Apple's render | median Δm vs pixel fit | median s |
|---|---|---|---|
| start | 0.298 | 0.074 | – |
| oneshot | 0.212 (worse than start) | 0.086 | 1.6 |
| iterate | 0.305 (model declared a match on 11 of 12, mean 1.9 calls) | 0.074 | 0.8 |
| pixel fit, no model | **0.967** | – | 8.5 |
| hand values | 0.813 | 0.010 | – |

**Private Cloud Compute was not testable.** It reports `available` with vision and a 32K
context, but every call fails with `ModelManagerError 1046`, text-only prompts included.
Signing the binary turns the error into a message that PCC needs a managed entitlement:
https://developer.apple.com/contact/request/private-cloud-compute/

**The pixel fit is the useful result.** With no model it beats the hand values on every
sampled symbol (IoU 0.967 vs 0.813) in about 9 s a symbol, and it shows that some hand values
are stale on 27. It is weak on weight: it prefers medium where the hand values say regular
(Apple's 27 strokes measure closer to medium), and the IoU difference is small enough that a person
should decide. If calibration is automated, this is the place to start, with a vision model
at most as a second opinion on weight once a larger one is reachable.

## Pixel fit precision, 2026-10-02

`vcal precision`, 8 symbols. Mica's side is the glyph's exact alpha at 1024 px; two ways of
reading Apple's side:

- `threshold`: one global cut halfway between enclosure and glyph level, then binary IoU.
- `normalised`: each pixel unmixed between the darkest and brightest values within ~10 px,
  so a gradient across the glyph cancels; soft IoU.

**Synthetic references with known answers** (Mica's glyph shaded top to bottom, up to
255 → 140, optionally blurred): both methods recover the multiplier to a median 0.0001 and the
offsets to about 0.0004 (0.3 px at 1024), with the weight right every time. The gradient does
not move the fitted edge.

**Apple's renders in four colour combinations** (blue+white, black+white, white+black,
white+blue). The glyph's geometry should not depend on colour, so disagreement between
combinations is error the method adds:

| method | median spread, m | max spread, m | median spread, x / y | same weight in every combination | s per fit |
|---|---|---|---|---|---|
| threshold | 0.0016 | 0.0038 | 0.0005 / 0.0003 | 88% | 3.4 |
| normalised | 0.0008 | 0.0025 | 0.0003 / 0.0005 | 100% | 0.5 |

The two methods land within 0.0005 of each other in every combination.

So **higher contrast colours do not help, and the liquid glass gradient needs no special
compensation.** Every combination gives the same answer to about a tenth of the hand
calibration's 0.005–0.01 grain. What mattered was how the first harness cut the mask: a fixed
`min(r,g,b) > 175` rule at 512 px, applied differently to each side. `normalised` is a little
tighter and much faster, so it is the one to keep.

**Open: weight.** The fits pick medium, semibold or bold for five of the eight symbols where
the hand values say regular, and they pick the same heavier weight in every colour combination.
Synthetic tests recover the weight every time, so the method can tell weights apart; whether
Apple draws these glyphs heavier, or a heavier weight at a slightly different size just overlaps
better, is not yet settled.

## Misplaced parts: the second pass, 2026-10-03

`allergens` and `allergens.fill` fit bold, but their rings are medium. Apple draws the dots at a
different angle from the SF Symbol, and no size or offset aligns them, so a thicker weight wins
by smearing over them. `vcal pieces` tests a second pass:

1. Fit each weight as now.
2. Split Apple's glyph into 8-connected pieces (≥ 40 px). At each weight, match each to the Mica
   piece that overlaps it most and measure their centre distance as a fraction of the piece's
   radius. A piece is **misplaced** when that exceeds 0.5 at any weight, with a match of similar
   area (½–2×) and a distance under 1.5 radii.
3. Refit every weight with soft IoU outside the misplaced pieces, plus each misplaced piece scored
   against Mica's match **moved onto its centre**: size and stroke count, position does not.
   Masking the pieces outright left `allergens.fill` as two discs that every weight fits
   (0.971/0.967/0.964/0.959).
4. Keep the refit only if a misplaced piece is still displaced at the weight it chose. Otherwise
   the piece was displaced only at weights the fit rejects, and the first pass stands unchanged.

| symbol | first pass | second pass |
|---|---|---|
| allergens | bold 0.718 | medium 0.914 (bold 0.767) |
| allergens.fill | bold 0.864 | medium 0.961 (bold 0.909) |

Sweep: the 24 fitted symbols below 0.85 plus 1,500 random (seed 7), 1,520 in all. 52 were flagged at
step 2; step 4 kept the first pass for 50 of them, so **only the two `allergens` symbols changed**.
Without step 4 the 50 drifted slightly, except `iphone.gen2`, whose frame merges with another part
at bold: the refit masked the whole frame and visibly grew the symbol.

The first full fit had flagged 125 below 0.85, not 24. Between the two, the user accepted most of
them in the calibration tool, and accepting a symbol then rewrote it as a hand edit with no
`fitScore`, which `--low` does not select. About 100 of the 125 were therefore left out of the
sweep. Accepting now keeps the score and sets `reviewed`.

Two shapes that must not count as misplaced, both seen: a translucent layer that Mica's alpha
leaves under the 0.5 cut (no overlapping piece, so missing rather than misplaced:
`hifispeaker.and.homepod`), and strokes that merge at a heavier weight (`iphone.gen2`).

```bash
.build/release/vcal pieces --symbols allergens,allergens.fill
.build/release/vcal pieces --low --sample 1500 --seed 7   # about a second a symbol, cached refs
```

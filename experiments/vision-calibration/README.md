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
```

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

# Visual & Motion Design Direction

Brief: *unique, minimal, functional, sophisticated, animated.*

## 1. The differentiating decision: no cage fills

Every Calcudoku app on the App Store — including the legacy Numeriqo, which
ships `CageColorPalette.swift` — distinguishes cages with **pastel fill colours**.
The result is uniformly the same: a spreadsheet wearing a beach towel. It also
actively fights the game, because colour is the strongest signal on screen and
it's being spent on static structure the player memorises in ten seconds.

**Numeriqo draws cages as ink, not as fill.**

- **One lattice, one corner treatment.** Every line sits on the same grid.
  Nothing is inset, nothing is rounded.
- **Line style encodes cage membership.** A boundary *between* cages is a solid
  2pt ink rule. A division *inside* a cage is a fine dotted rule. No edge is ever
  drawn twice, and the board needs no second device to explain its own structure.
- The board is monochrome. **Colour is reserved entirely for meaning**: the
  active digit, the current hint's argument, an error, a satisfied cage.

### Revised after building it (2026-08-01)

The first build inherited the legacy app's rounded, inset "soft tile" cage
outline, and it put **three competing geometries on one board** — square cells,
rounded cages, square selection borders. A selection wash inside a rounded cage
bled through its corners, and because a full hairline grid was drawn *underneath*
inset cage strokes, every cage edge was doubled. The result read as fussy, which
is the opposite of the brief.

Two further faults the screenshots exposed:

- **Clue labels printed straight through pencil notes** (`144x` over `1 2 3`).
  Anchor cells now reserve a clue gutter and their notes and digit start below it.
- **The selection wash was a fixed blue** while the selection border used the
  per-tier accent. Washes now derive from the tier, so the board never mixes hues.

Typography moved off `SF Rounded`. Soft terminals read as a friendly consumer
app and fought both the ink surface and the arithmetic; the default grotesque is
quieter and leaves the accent stroke as the only expressive mark on the board.

The paper was pulled from warm cream toward a cool near-neutral. Warm cream with
a high-contrast serif is the single most common generated-design signature going,
and the ink here should read as graphite rather than parchment.

This buys the thing every competitor has spent away: when something turns
colour, it *means* something. The hint system's drawn arguments only read as
striking because the surrounding board is quiet.

## 2. Palette

Two ink-on-paper themes, and one accent that shifts by difficulty tier.

| Token | Light | Dark | Role |
|---|---|---|---|
| `paper` | `#F7F6F4` | `#121315` | behind the board |
| `surface` | `#FFFFFF` | `#1D1F22` | cell fill |
| `ink` | `#1A1A1E` | `#F2F0EC` | entered digits |
| `inkSecondary` | 55% ink | 55% ink | notes |
| `cellRule` | 22% ink, **dotted** | 26% ink, dotted | division inside a cage |
| `cageRule` | 82% ink, **solid 2pt** | 80% ink | boundary between cages |
| `tierAccent(_:)` | per tier (below) | per tier | the one expressive colour |
| `tierWash(_:strength:)` | tier accent at 10% × strength | same | every board wash |
| `error` | desaturated rust `#B4462F` | `#E0714F` | a digit that isn't the one |
| `success` | the accent, never green | | |

There is **no fixed accent-wash token**. Washes derive from the tier, because a
board that mixes a blue wash with a green selection border looks assembled
rather than designed.

Tier accents — a single hue rotation, so the *app* changes temperature as the
player climbs, which is a quiet progress signal:

Gentle `#3E7CB1` → Steady `#4E8A6F` → Sharp `#B8863B` → Deep `#A85438` → Severe `#7C4B7D`

Full support for light/dark, Dynamic Type, Increase Contrast, and Reduce Motion
is a Phase-1 requirement, not a polish item.

## 3. Typography

Typography carries the whole design, since colour is withheld.

- **One face throughout**: the system grotesque, **never `.rounded`**. Soft
  terminals read as a friendly consumer app and fight both the ink surface and
  the arithmetic.
- **`.monospacedDigit()` everywhere.** Non-tabular figures make a numeric grid
  shimmer as values change — the columns visibly breathe.
- **Player entries**: `ink`, regular weight, 50% of cell.
- **Cage targets**: 24% of cell, semibold, 62% ink, top-left of the anchor cell.
  Never centred — the offset corner is part of the genre's grammar, and its
  asymmetry is what makes the grid read as a puzzle rather than a table.
- **The anchor cell reserves a clue gutter.** Its notes and its digit both start
  below the clue. Without this, `144x` prints straight through `1 2 3` and
  neither can be read — which is what the first build shipped.
- **Candidate notes**: a micro-grid sized to `N`, not a fixed 3×3 — a 6×6 wants
  1–6 and a 4×4 wants 1–4. Absent digits hold their slot so marks never reflow.
  A candidate the current hint eliminates is struck **in place, in the tier
  accent**: "3 candidates ruled out" has to be visible as *which three*.

## 4. Motion vocabulary

Motion has one job here: **make logic visible**. Decorative motion is cut.

| Event | Motion | Duration |
|---|---|---|
| Digit placed | spring scale 0.8→1.0, slight overshoot | ~0.28s |
| Digit removed | scale down + fade | 0.18s |
| Candidate eliminated | strike-through draws L→R, then glyph fades | 0.22s |
| Cage satisfied | outline draws once around the cage perimeter, then settles to rest weight | 0.5s |
| Row/column complete | a light sweep along the line | 0.4s |
| **Hint argument** | witness cells lift in sequence (~0.1s stagger); a stroke draws between them; explanation slides up | ~1.2s total |
| Puzzle complete | cage outlines dissolve, digits settle into a plain Latin square, then a slow scale-back | ~2s |

**The signature moment is the hint's drawn argument.** No competitor animates
the *reasoning*. A stroke travelling from the two cells of a locked cage along
the row it constrains, ending on the cell it eliminates, is the entire product
thesis expressed in half a second. Prototype this first — it is the thing to
get right before anything else, and the thing to lead the App Store video with.

Completion deliberately *removes* the cages: the board resolves into the clean
Latin square underneath. The puzzle dissolving to reveal the order beneath it is
a better ending than confetti, and it is on-theme.

Implementation: `PhaseAnimator` for the multi-step hint choreography,
`KeyframeAnimator` for completion, `Canvas` + animatable `Path` trimming for
drawn strokes, `matchedTransitionSource` for board↔menu transitions. A Metal
shader for a subtle ink-bleed on placement is optional Phase 7 polish — cut it
if it costs frame time on older devices.

All of the above must degrade cleanly under **Reduce Motion**: cross-fades
replace travel, the hint argument shows all witnesses at once rather than in
sequence. It must never *skip* the argument — that would remove information.

## 5. The loading screen

Generating a 9×9 with technique grading measures 125ms median and **688ms worst**
in Release on a Mac, and Debug-on-simulator is several times slower
([`ARCHITECTURE.md`](ARCHITECTURE.md) §4). So this screen is real at the top
sizes, though `PuzzleCache` should hide it most of the time — it is the
*exception*: cold start, size change, or the player finishing faster than the
warm generation. Which is exactly why it should be good: a rare screen that
looks considered reads as craft, and a spinner does not.

**The board builds itself.**

1. The empty grid fades in first — dotted cell rules only, correct size, at the exact
   final position and scale of the real board.
2. Cage outlines then **draw themselves** one at a time, in the ink stroke of the
   real thing, at a steady rhythm (~40ms apart, order randomised per launch).
3. When generation completes, the clue numerals fade into their corners and the
   screen **becomes** the board. No transition, no dissolve — it was the board
   the whole time.

This works for three reasons. It is honest — a puzzle really is a cage partition
being assembled. It reuses the app's signature gesture, the animated stroke, so
the loading state teaches the visual language before play begins. And because the
grid is already at its final position, there is no jarring hand-off; the player
is looking at the board they are about to solve.

**It must not depend on real progress.** Node-budget progress is lumpy and
non-monotonic, and a bar that stalls at 80% is worse than no bar. The cage
animation loops on its own clock and simply stops when the puzzle arrives.
Bounded worst-case latency — guaranteed by the budget-plus-baked-fallback design —
is what makes an indeterminate animation honest rather than evasive.

Details:

- **Cancellable and obvious.** A back affordance from the first frame; backing
  out cancels the `Task`.
- **No screen at all below ~250ms.** Present it only after a short delay, so
  small grids never flash it. A loading screen that appears and vanishes in two
  frames reads as a bug.
- **Reduce Motion**: the grid and a static set of cage outlines appear at once,
  with a slow opacity pulse rather than sequential drawing.
- **VoiceOver**: announce "Building a 9 by 9 puzzle", then post the board when
  ready. Never announce per-cage steps.
- If the baked fallback path is taken, say nothing — the player has no use for
  the distinction.

## 6. Haptics & sound

> **Sound is not implemented, and that is a decision rather than an omission.**
> The vocabulary below still describes what it should be. It is unbuilt because
> it cannot be judged: the simulator's audio is not audible to whoever writes
> this code, and audio nobody has heard is not something to ship. Haptics, which
> can be reasoned about from the vocabulary alone, are implemented in full.


Per `design/game-feel`: feedback must scale with rarity, and exactly one layer
owns each event.

| Event | Haptic | Sound |
|---|---|---|
| Digit placed | `.light` | soft wooden tick, pitch rises with digit value |
| Note toggled | `.selection` | quieter tick |
| Invalid entry | `.warning` | muted thunk, no buzzer |
| Cage satisfied | `.light` | short resolved interval |
| Line complete | `.medium` | rising third |
| Hint revealed | `.selection` | single soft chime |
| Puzzle complete | `.success` | the only full musical phrase in the app |

Pitch-mapping placement sounds to digit value means a solved row *plays a
scale*. It is a small thing that makes the board feel like an instrument, and it
is the kind of detail reviewers single out in Good Sudoku.

Ambient music: off by default, optional, low and textural.

## 7. Layout

- **iPhone**: board fixed at the optical centre, number pad thumb-reachable at
  the bottom, chrome minimal. The board never moves when the pad changes state.
- **iPad / macOS**: board centred with the technique/hint panel in a sidebar
  rather than an overlay — this is where the Academy shines on a big screen.
- Full keyboard support on macOS and iPad: digits type, arrows move,
  space toggles note mode.
- **Ship iPhone-only first.** The legacy Numeriqo spread itself across iOS,
  macOS, and visionOS; that surface area is what makes a small team ship
  compromises. Add platforms once the core is excellent.

## 8. House style for player-facing words

The app had three words for the thing you fill: *grid*, *board* and *puzzle*.
`PuzzleLoadingView` used all three on one screen. That is not variety, it is
three names for one object, and the reader has to check each time whether a
distinction is intended.

Settled:

- **grid** is the lattice you fill. "Fill the grid", "Bigger grids", the picker.
- **puzzle** is the instance you solve. "Today's puzzle", "Puzzles solved".
- **board** stays as the name of the *type* in code and in these docs. It does
  not appear on screen.

Three more rules, enforced by `theCopyKeepsToHouseStyle` in `TeachingTests`:

- **No em dashes or en dashes** in player-facing strings. Use a full stop, a
  comma, or a colon. They are the single most reliable tell that copy was
  generated rather than written.
- **No curly quotes.**
- **Never the word "KenKen"**, which is a live registered trademark. See
  `RULES.md` §6.

Two habits the test cannot catch, so watch for them by hand:

- **No rhetorical drumrolls.** Four of the sixteen lessons used to open on a
  bare noun phrase: "The workhorse.", "The signature move.", "The mirror
  image.", "The simplest closing move." Each reads fine alone. A player meeting
  the fourth sees the formula, and the formula is doing the work the sentence
  should.
- **No reason the player can check and find redundant.** The tutorial once
  justified a 3+ pair being 1 and 2 by saying the cells share a row and cannot
  repeat, which is true but beside the point: nothing else adds to 3 either way.
  Offering a reason that does not hold weight teaches the player to stop reading
  the reasons.

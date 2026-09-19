# Numeriqo 3.0 — Master Plan

A major update turning Numeriqo into a Calcudoku game that **teaches you to
actually get good at it**, in the tradition of Good Sudoku — and, in this
workspace, of Just Kakuro.

> Read alongside: [`RULES.md`](RULES.md) · [`TECHNIQUES.md`](TECHNIQUES.md) ·
> [`TEACHING.md`](TEACHING.md) · [`DESIGN.md`](DESIGN.md) ·
> [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`MONETIZATION.md`](MONETIZATION.md)

---

## 1. The thesis

Almost every Calcudoku app is a *puzzle dispenser*: it hands you grids and
validates answers. If you get better, that happened despite the app. Today's
Numeriqo is one of them.

Good Sudoku proved a different product exists — one whose hints name the
**technique** rather than the answer, so the skill transfers off the screen.
Nobody has built it for Calcudoku.

**Numeriqo 3.0 is that app.** The measurable promise: *a player who has never
seen a Calcudoku can solve a 7×7 unaided within two weeks.*

It is also the genre's original intent. Tetsuya Miyamoto invented these puzzles
in 2004 as "an instruction-free method of training the brain" — *the art of
teaching without teaching*. His method was pure difficulty laddering: sequence
puzzles so each demands exactly one new idea, then say nothing. Numeriqo's one
departure is that it will name a pattern when a player is stuck — but it never
places the digit unless asked twice.

## 2. This is Just Kakuro's architecture, applied to a different puzzle

`/Users/kai/work/areas/ios/just-puzzles/kakuro/` is already a shipping implementation of this
exact product shape: human-technique solver, teaching hint engine with escalating
levels, per-technique practice drills, mastery tracking, one-time unlock. Its
`docs/ENGINEERING.md` records mistakes already paid for once — a MainActor
isolation crash that shipped, two persistence bugs that survived a green test
suite, generation strategies that didn't work.

**Read it before writing code.** The plan below assumes porting its structure and
deviating only where Calcudoku genuinely differs. That is the single biggest
schedule lever available.

### Where Calcudoku genuinely differs from Kakuro

1. **Digits may repeat within a cage** (Kakuro forbids repeats in a run). Cage
   enumeration must produce **multisets** filtered by cage *shape* — straight-line
   cages can't repeat, dog-legs can. This is the subtlest rule in the game and
   the easiest place to be silently wrong.
2. **Four operators**, not just sums. `×` cages need factorisation reasoning;
   `−`/`÷` are order-independent and restricted to two-cell cages.
3. **The Latin constraint replaces run-uniqueness**, which makes fish techniques
   (X-Wing, Swordfish) apply cleanly — no boxes to complicate them.
4. **Two techniques with no Sudoku or Kakuro analogue**: the Rule of n! divisor
   test, and parity. These are the strongest differentiators and deserve the best
   lessons.

## 3. Hard constraint: the name

**"KenKen" is a live registered trademark** (KenKen Puzzle LLC). Registration
**3941027** expressly covers *"electronic game software for cellular telephones"* —
this exact product category — and the holder has enforced before, forcing
Conceptis to rename "KenDoku" to "CalcuDoku" in 2008.

Binding on the whole project: ship as **Numeriqo**; use *Calcudoku* / *MathDoku*
for ASO; the mark appears nowhere in app name, subtitle, keywords, description,
screenshots, icon, or source identifiers. Detail in [`RULES.md` §6](RULES.md).

## 4. Shipping shape

**A 3.0 update to the existing app**, not a new SKU — the ratings history is
worth more than pricing flexibility.

| App | Bundle | ASC ID | After 3.0 |
|---|---|---|---|
| Numeriqo | `de.kaikunze.numeriqo` | 6749287069 | Free + `de.kaikunze.numeriqo.full` @ $4.99 |
| Numeriqo Pro | `de.kaikunze.numeriqopro` | 6751394841 | Same 3.0 build, permanently unlocked, removed from sale |

**Existing Pro owners must not be asked to pay again.** The `NUMERIQO_PRO`
compilation flag already in the codebase becomes a permanent entitlement
override, so the Pro build ships the whole teaching product unlocked with no
migration, no keychain, and no user action. Full reasoning and the store
lifecycle in [`MONETIZATION.md` §3](MONETIZATION.md).

The free tier is drawn to **exactly match what free Numeriqo offers today** —
3×3–5×5, all difficulties, and best-time tracking — so no existing user loses
anything. **3.0 never removes something 2.x gave away.**

**Scope cuts:** iPhone and iPad only. Drop macOS and visionOS — the legacy app
spread across four platforms and the cost is visible in all of them. Kakuro
ships two and is better for it. No online leaderboards in 3.0 (local streaks
only), no ads, no subscription.

## 5. Roadmap

Nine phases, each ending in something runnable.

### Phase 0 — Project setup (½ day)
New Xcode project in Kakuro's shape (§`ARCHITECTURE.md` §1): synchronized root
groups, Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `StoreKit/`
outside the source root. Port `ThemeIsolationTests` **before** writing any
`Design/` code — that crash is easier to prevent than to diagnose.

### Phase 1 — Engine core & cage enumeration (2 days)
Models, `UInt16` candidate bitmasks, `CageCombinations`. **The correctness
lynchpin**, because of in-cage repeats.
*Exit: differential test against brute force passes for every
`(N ≤ 6, operation, target, shape)`.*

### Phase 2 — Logical solver & technique ladder (5–7 days) ⚠️ *the risk*
T1–T23 as ordered rules, lowest-tier-first application, `BacktrackingSolver` for
uniqueness. Firing **and near-miss** fixtures per technique — a technique that
fires spuriously produces a *wrong* hint, which is worse than none.

Longest, least visual phase, and where the project succeeds or fails. Resist
starting UI first. Iterate via the CLI harness, not the simulator
([`ARCHITECTURE.md`](ARCHITECTURE.md) §7).
*Exit: tier assignments match human judgement on 20 blind-rated puzzles.*

### Phase 3 — Generation & the loading screen (3–4 days)
Randomised-backtracking Latin squares (not the legacy cyclic construction),
flood-fill caging, operator assignment, uniqueness repair, technique grading.
**All sizes generate on device** — deterministic node budget, baked fallback
grids, cancellable `async` generation, and `PuzzleCache` warming the next puzzle
while the player solves the current one. Seeded generation for dailies, pinned
by a reproducibility test.
*Exit: 9×9 worst case bounded and measured in Release on device; cache hit rate
high enough that the loading screen is genuinely rare; 100% unique and
`LogicalSolver`-solvable at every size.*

### Phase 4 — Board UI & the signature animation (3–4 days)
Design tokens, ink-outline cages, number-first input, notes, undo. **Then build
the hint's drawn-argument animation before anything else** — it is the thesis
made visible, and if it doesn't feel remarkable, the design direction needs to
change while changing it is cheap.
*Skills: `design/ui-prototyping` (go wide before committing), `design/animation-patterns`.*

### Phase 5 — Teaching layer (4 days)
Rules tutorial, four-level hint ladder, technique lessons, practice drills,
mastery tracking. **Hand-author boards for the early lessons from the start** —
expect T1–T5 to be unreachable in generated traces, as three of Kakuro's eight
were, and pin the assumption with a test.
*Exit: a new player can be handed the phone and reach a solved 5×5.*

### Phase 6 — Progression & persistence (2 days)
Dailies (fixed seed), streaks, skill map, stats, saved game. Port Kakuro's two
persistence invariants and their regression tests.
*Skills: `generators/streak-tracker`.*

### Phase 7 — Store layer (1–2 days)
Port `Kakuro/Store/` wholesale. `FeatureGate` as pure functions,
`EntitlementSource` seam, `NUMERIQO_PRO` override, contextual paywall.
`EntitlementTests` asserting the free set exactly.
*Skills: `monetization/*`, `generators/paywall-generator`.*

### Phase 8 — Feel & accessibility (2–3 days)
Haptic and sound vocabulary. Full VoiceOver — a grid of irregular cages is
genuinely hard to voice; budget real time. Reduce Motion, Dynamic Type.
*Skills: `design/game-feel`, `ios/accessibility-audit`.*

### Phase 9 — Ship (3 days)
End-to-end simulator verification via `fb-idb` — unit tests cannot reach view
lifecycle, and both of Kakuro's persistence bugs survived a green suite. Icon,
screenshots leading with the drawn argument, **trademark-clean** store copy,
privacy manifest, TestFlight. Ship both SKUs simultaneously, then remove Pro
from sale.
*Skills: `app-store/*`, `release-review/*`.*

**Estimate: ~5 weeks.** Phase 2 dominates and is most likely to overrun.

## 6. Principal risks

| Risk | Mitigation |
|---|---|
| **Pro owners asked to pay twice.** Fastest route to one-star reviews from the users who liked the app most. | `NUMERIQO_PRO` as permanent entitlement override; both SKUs ship 3.0 together. |
| **Technique solver under-estimated.** Everything depends on it. | Largest phase, gated by human-agreement test, built before any UI. |
| **A technique fires spuriously** → the app teaches something false. | Near-miss fixtures per technique are mandatory. |
| **In-cage repeats mishandled** — corrupts enumeration, grading, hints and generation at once, silently. | Phase 1 differential test against brute force. |
| **MainActor isolation crash in `Design/`.** Kakuro shipped this; it crashed intermittently, anywhere, including idle. | Port `ThemeIsolationTests` in Phase 0, before any Design code exists. |
| **Trademark.** | Codified in `RULES.md` §6; re-verified in Phase 9. |
| **Minimal monochrome board reads "unfinished"** rather than sophisticated. | `design/ui-prototyping` in Phase 4 — build divergent directions as real `#Preview`s and choose. |
| **VoiceOver over irregular cages.** | Dedicated Phase 8 time; a design problem, not a labelling one. |
| **Assists breed reliance that doesn't transfer to paper** — the sharpest published criticism of Good Sudoku ([Eurogamer](https://www.eurogamer.net/if-you-really-want-to-learn-from-good-sudoku-i-reckon-arcade-mode-is-the-way-to-go)). | Immediate error feedback as the default, and the transfer test applied to every convenience feature ([`TEACHING.md` §6](TEACHING.md)). |

## 7. Decisions made

- **Name: Numeriqo.** Existing brand, existing ratings, trademark-clean.
- **All sizes generate on device**, 3×3–9×9. No shipped puzzle bank. Latency at
  the top sizes is absorbed by `PuzzleCache` plus a designed loading screen
  ([`DESIGN.md` §5](DESIGN.md)); worst case is bounded by the node budget and
  baked fallbacks.
- **Best times stay free.** 3.0 never removes something 2.x gave away; only the
  richer stats (solve counts, hint trend, mastery path) sit behind the unlock.
  Legacy records must migrate intact ([`MONETIZATION.md` §2](MONETIZATION.md)).

## 8. Open questions

1. **Academy naming** — "Techniques", "Improve", or "Academy"? Avoid "Dojo";
   the Japanese origin makes it tempting and for that reason it reads as
   costume. (Phase 5)
2. **Does the loading screen ever show a tip?** A technique reminder while a 9×9
   builds is tempting and would use the time well, but it competes with the
   build animation for attention. Try both in Phase 4. (Phase 4)

## 9. Installed tooling

- **`apple-skills@indie-apple-stack`** — 164 Apple-platform skills
  (`rshankras/claude-code-apple-skills`), user scope.
- **`frontend-design@claude-plugins-official`** — Anthropic Frontend Design,
  user scope.

Toolchain verified: Xcode 26.5, Swift 6.3.2, iPhone 16 Pro simulators available.
Pin `OS=` in every destination — several runtimes are installed.

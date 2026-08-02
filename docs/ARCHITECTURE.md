# Architecture

**Numeriqo 3.0 follows Just Kakuro's structure.** That project is a shipping,
tested implementation of this exact product shape — human-technique solver,
teaching hint engine, practice drills, mastery tracking, one-time unlock. Its
`docs/ENGINEERING.md` records mistakes that have already been paid for once.
**Read it before starting.** Deviate only where Calcudoku genuinely differs.

Reference: `/Users/kai/work/areas/ios/kakuro/`

## 1. Project shape

A **single Xcode project**, not a workspace + SPM package. Kakuro proves the
simpler shape carries this product fine, and it avoids a build-graph rewrite of
an app that already ships.

```
numeriqo_new/
├── Numeriqo.xcodeproj
├── Numeriqo/
│   ├── App/            # @main, ContentView, Route enum navigation
│   ├── Engine/         # pure logic. No SwiftUI. All `nonisolated` value types.
│   ├── Game/           # play screen, board rendering, number pad, puzzle cache
│   ├── Teaching/       # lessons, hint engine, drills, mastery
│   ├── Design/         # Theme, Motion, Haptics
│   ├── Persistence/    # settings, stats, best times, saved game
│   └── Store/          # the one-time unlock
├── NumeriqoTests/
├── StoreKit/
│   └── Numeriqo.storekit    # deliberately OUTSIDE Numeriqo/
└── docs/
```

`objectVersion 77` with `PBXFileSystemSynchronizedRootGroup`: **new Swift files
under `Numeriqo/` and `NumeriqoTests/` are picked up automatically — never edit
`project.pbxproj` to add files.**

`StoreKit/` sits outside the synchronized root on purpose; inside, it would ship
in the app bundle.

## 2. Conventions

Inherited from Kakuro, and consistent with the workspace `CLAUDE.md`:

- Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project-wide. **Engine
  types are explicitly `nonisolated`** so generation runs off-main.
- Model-View, **no ViewModels**. `@Observable` (never `ObservableObject`/
  `@Published`). `@Environment` for services. View state as enums.
  `.task(id:)` for async effects.
- `struct` over `class`; classes `final`; no force unwraps.
- Swift Testing.
- Two platform targets only: iPhone and iPad. **Drop macOS and visionOS.** The
  legacy Numeriqo spread across four platforms and the cost shows in all of
  them; Kakuro ships two and is better for it.

### The `nonisolated` trap in `Design/`

Kakuro shipped a crash here and the note is worth repeating verbatim in intent:
with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, every unannotated type is
`@MainActor` — **including closures handed to UIKit**.
`UIColor.init(dynamicProvider:)` is imported without `NS_SWIFT_SENDABLE`, so a
closure literal passed to it inherits MainActor isolation and Swift 6 emits an
executor assertion. UIKit resolves dynamic colors on
`com.apple.SwiftUI.AsyncRenderer`, that assertion trips, and the app traps —
**intermittently, anywhere, including idle on Home.**

`Theme` and `Motion` must be `nonisolated`; `Haptics` must stay `@MainActor`.
Port Kakuro's three-way `ThemeIsolationTests` guard (compile-time, runtime
off-main resolve, and a source scan) rather than reinventing it.

## 3. Engine

### Core types

```swift
nonisolated struct Cell: Hashable { let row, col: Int }
nonisolated enum Operation { case none, add, subtract, multiply, divide }

nonisolated struct Cage {
    let cells: [Cell]
    let operation: Operation
    let target: Int
    var anchor: Cell        // top-left; where the clue draws
    var isStraightLine: Bool // all cells share a row or a column
}
```

Candidates are `UInt16` bitmasks throughout, as in both prior projects.

### Cage combination enumeration — the correctness lynchpin

`CageCombinations`, analogous to Kakuro's `SumCombinations`, but **materially
harder**, because Calcudoku permits in-cage repeats where Kakuro forbids them.

The rule: *digits may repeat within a cage, provided they do not share a row or
column.* Therefore cage **shape** decides what is legal:

- **Straight-line cage** (all cells in one row or column) → no repeats possible.
- **Dog-leg cage** (has a bend — L, S, T, plus) → repeats possible between cells
  sharing neither row nor column.

Worked example, 6×6, three-cell `20×` cage:
- straight line → `20 = 1×4×5` only → `{1,4,5}`
- L-shaped → additionally `{2,2,5}`, the two 2s in elbow positions

So enumeration is:

1. Generate **multisets** of size `|cells|` from `1…N` satisfying the operator.
2. Generate distinct permutations onto the cage's actual cells.
3. Discard permutations placing equal digits in a shared row or column.

Memoise on `(N, operation, target, cageShapeSignature)` — this is called by
nearly every technique.

**Test it differentially against brute force for every `(N ≤ 6, operation,
target, shape)`.** This is the single easiest place to be silently wrong, and
being wrong here corrupts difficulty ratings, hints, and generation at once.

Also worth hard-coding, since they are small and constantly used — the two-cell
tables. In an `N×N` grid, `t−` has exactly `N−t` pairs and `t÷` has exactly
`⌊N/t⌋`. In 6×6, `5−`, `4÷`, `5÷` and `6÷` are each a **single forced pair**,
which makes them the most valuable clues on a beginner board.

### Solvers

Two, with strictly separate jobs — Kakuro's split, which is right:

- **`LogicalSolver`** — the human-technique solver. `nextStep(puzzle:board:)`
  powers hints. Applies the **lowest-tier applicable technique**, never the
  first found, or difficulty ratings inflate.
- **`BacktrackingSolver`** — `countSolutions(limit: 2)`, uniqueness proof only.
  Never a hint source. Its hot path must stay allocation-free; Kakuro measured
  arrays/filter/reduce there at ~7µs/node against ~1µs.

`Technique` is an enum whose **declaration order is the source of truth** for
the solver loop, difficulty grading, hint escalation, tutorial sequence, and
practice menu. One ordering, five consumers. See [`TECHNIQUES.md`](TECHNIQUES.md).

## 4. Generation

**Invariant, inherited from Kakuro: every shipped puzzle must be provably unique
*and* fully solvable by `LogicalSolver`.** Enforced at `generate()`'s single
exit. A board failing either test is never returned. This is what makes the hint
guarantee real — the app can always name a next technique because no puzzle
ships that would require guessing.

Pipeline:

1. Random Latin square. **Do not use the legacy cyclic-shift-plus-shuffle**
   (`generateLatinSquare` builds `((i+j) % size) + 1` then permutes) — it reaches
   only the cyclic isotopy class, so every row is a rearranged shift of every
   other and experienced players can exploit it. Use randomised backtracking.
2. Partition into cages by random flood-fill. Bias the requested size
   distribution **upward**: large cages statistically fail to fit the remaining
   space, so the empirical distribution skews smaller than requested.
3. Assign operators and targets from the solution. `−`/`÷` on two-cell cages
   only. Reject `−` target 0 and `÷` target 1 (both imply a useless repeat).
   Use 64-bit for `×` — a 5-cell 9×9 cage reaches 15,120.
4. Prove uniqueness with `BacktrackingSolver`. On failure, **repair** rather
   than discard: find a cell where the two solutions differ and split the cage
   containing it, or swap a `+` cage to a tighter `×`.
5. Run `LogicalSolver`. Reject anything needing bifurcation.
6. Grade by hardest technique required.

Difficulty knobs, in rough order of power: freebie count (cap it — excessive
single-cell cages trivialise a board, and Hard should have zero), count of
forced clues (a puzzle with none is never Easy), mean cage size, dog-leg
fraction, operator mix.

Kakuro's hard-won generation lessons that transfer directly: bound `generate()`
by a **deterministic node budget**, not attempt counts or wall-clock, or
per-seed determinism breaks and generation tests become flaky. Ship
**pre-verified baked fallback grids** for the budget-exhausted path rather than
a template-plus-repair loop.

### Where to generate — on device, all sizes

**Decision: everything generates on device, 3×3 through 9×9.** No shipped puzzle
bank. The app stays small, every puzzle is fresh, and there is no content
pipeline to maintain.

#### Measured (Release `-O`, Apple silicon)

Phase 3 measured uniqueness-only. Phase 2 added the **solvability gate** — every
puzzle must be finishable by the curriculum.

| Size | Uniqueness only | Gate, 10 techniques | Gate, 16 techniques |
|---|---|---|---|
| 4×4 | <1ms | 1ms / 4ms, 7.2 attempts | 1ms / 4ms, 4.4 attempts |
| 6×6 | <1ms / 3ms | 18ms / 103ms, 17.5 | **10ms / 40ms, 5.7** |
| 7×7 | 1ms / 5ms | 60ms / 207ms, 20.5 | **25ms / 91ms, 6.1** |
| 9×9 | 1ms / 6ms | 125ms / 688ms, 15.3 | **62ms / 191ms, 3.1** |

*(median / worst, then mean attempts. Zero generation failures throughout.)*

**Adding techniques made generation faster**, which is counterintuitive but
follows directly: the gate rejects any puzzle the curriculum cannot finish, so a
stronger curriculum rejects less. Solvability rose from 25–62% to 74–95%, and
attempts fell from ~15–20 to ~3–6. The gate is not a tax to be minimised — it is
a measurement of how good the curriculum is.

9×9 worst case is 191ms in Release on a Mac. Debug-on-simulator runs several
times slower, so the loading screen ([`DESIGN.md` §5](DESIGN.md)) is still worth
building for the top sizes, but it should rarely be seen once `PuzzleCache`
warms the next puzzle. Re-measure on device.

#### Discard-and-retry, not repair

About a third of freshly-clued partitions are unique with no repair at all. Since
an attempt costs ~1ms, `generate` **re-rolls rather than repairs**, and only
falls back to repair after exhausting 75% of its attempt budget.

This matters for quality, not speed. Repair buys uniqueness by splitting cells
off as freebies; leaning on it produced boards **30–40% pre-filled**, which are
unique and not worth solving. Re-rolling holds freebies at 5–10%.

Two measured traps worth not re-discovering:

- **Seed cages in reading order, not at random.** Random seeding fragments the
  free space and strands isolated cells as unwanted freebies — 21–24% against a
  requested 6%.
- **`freebieRate` and `maxFreebieFraction` must use the same unit.** Expressing
  one as a share of cells and the other as a share of cages silently made the
  quality bar reject every board the partitioner was built to produce.

#### Operator balance

`tightnessBias` defaults to **0**. Preferring tighter clues raises natural
uniqueness but skews boards heavily toward `×` — 57% multiplication at bias 0.5
against 40% at 0. The retry loop converges without it, so the bias is kept only
as a difficulty dial.

Known gap: `÷` lands at 3–5% of cages, so roughly half of 6×6 boards contain
none — yet division is a taught technique (T5). Worth weighting up during
Phase 2 difficulty tuning.

Three mechanisms make that acceptable:

#### 1. `PuzzleCache` — warm the next puzzle while the player solves this one

Port Kakuro's cache. The moment a game starts, kick off background generation for
the *same* `(size, tier)` the player is currently on, and hold the result. When
they tap "new puzzle," it is usually already there and appears instantly.

This is the primary mechanism. **The loading screen should be the exception, not
the rule** — it appears on a cold start, on a size/tier change, or when the
player finishes faster than generation.

Cache one puzzle per `(size, tier)` the player has recently touched; evict the
rest. Persist the warm puzzle across launches so a cold start after a warm exit
is also instant.

#### 2. Generation is `async`, off-main, and cancellable

`Engine` types are `nonisolated`, so generation runs off the main actor already.
It must also be **cancellable** — a player who backs out of a 9×9 must not leave
a core spinning. Check `Task.isCancelled` at each node-budget checkpoint.

#### 3. Deterministic node budget with baked fallbacks

Bound generation by a **deterministic node budget**, not wall-clock and not
attempt count — a wall-clock deadline breaks per-seed determinism and makes
generation tests flaky. Kakuro learned this one the hard way.

When the budget is exhausted, fall back to **pre-verified baked solution grids**
(three per size), not a template-plus-repair loop. Searching in the fallback path
is the wrong tool: it can churn for seconds and still return an ambiguous board.
A test must re-prove the baked grids are unique and `LogicalSolver`-solvable.

This makes worst-case latency **bounded**, which is what the loading screen's
design depends on.

#### Dailies

Dailies need a **fixed seed** derived from the date, so every player gets the
same board from the same local generation. Seeded generation must be
bit-reproducible across devices and OS versions — pin it with a test asserting
known seeds produce known boards. `SeededRandomNumberGenerator` ports from Kakuro.

## 5. Teaching

Mirrors `Kakuro/Teaching/` file-for-file:

| File | Role |
|---|---|
| `HintEngine.swift` | nudge → technique → highlight → resolution escalation |
| `TechniqueContent.swift` | per-technique copy |
| `TutorialScript.swift` / `TutorialPuzzles.swift` | script DSL + hand-authored fixture boards |
| `PracticeDrills.swift` / `PracticeView.swift` | per-technique drills |
| `MasteryTracker.swift` | what the player has earned unaided |
| `LearnMenuView.swift`, `HintBanner.swift`, `TutorialView.swift` | UI |

**Bake the early curriculum.** Kakuro found that three of its eight techniques
can *never* appear in a generated solver trace, because a cheaper detector always
reaches those positions first — so searching for a board that exercises them
cannot succeed at any size or difficulty. Their drills use hand-authored boards,
and a test pins the premise so that if detector precedence changes, it fails and
says so.

Expect the same in Numeriqo, and expect it to bite hardest on the low tiers
(Freebie Cage, Cage Combinations) where a naked single almost always fires
first. Plan hand-authored boards for the early lessons from the start, and pin
the assumption with a test like `TutorialFixtureTests`.

## 6. Persistence

`ProgressStore`, `@Observable`, UserDefaults + Codable, versioned keys
(`numeriqo.*.v1`), `init(userDefaults:)` seam for tests.

Two invariants Kakuro regressed on independently — port both, and their tests:

- **Save as the player works** — on board change, scene backgrounding, and
  disappear. Saving only on phase change silently loses everything, because a
  game that is started and never paused never changes phase.
- **`savedGame` must be observable state, not a UserDefaults read.** A view body
  calling `defaults.object(forKey:)` never invalidates, so the Continue card
  wouldn't appear until relaunch.

## 7. Testing

- Per-technique fixtures: boards where the technique **must** fire, and
  near-misses where it **must not**. Non-negotiable — a technique that fires
  spuriously produces a *wrong* hint, which is worse than no hint.
- Differential test of cage enumeration against brute force (§3).
- Property tests: every generated puzzle unique, `LogicalSolver`-solvable, and
  its stored tier matching its trace.
- `EntitlementTests` asserting the free set exactly.
- `ThemeIsolationTests`, ported.

Pin `OS=` in every destination — this machine has multiple runtimes and an
unpinned device name matches several.

```bash
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
```

Known quirk from Kakuro: simulator cloning for parallel testing intermittently
fails; fall back to `-destination 'id=<udid>' -parallel-testing-enabled NO`.

### Fast engine iteration without the simulator

Because `Engine/` has no UIKit/SwiftUI imports, compile it into a CLI binary:

```bash
swiftc -O -o bench Numeriqo/Engine/*.swift main.swift
```

Write benchmark output to **stderr** — stdout is block-buffered under a pipe.
Keeping `Engine/` UI-free is what makes this possible; enforce it with a test.

### End-to-end verification

Unit tests cannot reach view lifecycle, and both of Kakuro's persistence bugs
survived a green suite. Drive the simulator with `fb-idb` **from a single Python
process** — chained `idb ui tap` calls in one shell invocation drop taps.
Confirm each tap by re-reading the accessibility tree, and check liveness
separately, because a dropped tap and a dead app look identical from outside.
Kakuro's `docs/ENGINEERING.md` has the full recipe.

## 8. What to take from the legacy Numeriqo

`numeriqo/numeriqopro/Numeriqo/` — worth reading, mostly not worth porting now
that Kakuro is the better template.

Take:
- `MathMazeSolver.swift`'s bitmask propagation and uniqueness backtracker.
- `CageShape.swift`'s cage-outline path construction, if the geometry is clean.
- The `NUMERIQO_PRO` flag — repurposed as a permanent entitlement override
  (see [`MONETIZATION.md`](MONETIZATION.md) §3).

Leave:
- `DifficultyRater` — rates by *machine* effort (guess count, search depth). It
  cannot express "this puzzle teaches parity," so it cannot drive a teaching
  game. Replaced by technique-based grading.
- `generateLatinSquare`'s cyclic construction (§4).
- All view code — the colour-filled cage aesthetic is being abandoned
  (see [`DESIGN.md`](DESIGN.md) §1).
- The `KenKen*` file names, for trademark hygiene ([`RULES.md`](RULES.md) §6).

# Engineering notes

Working notes: architecture, invariants, and things that have already gone wrong
once. Mirrors the role of `../kakuro/docs/ENGINEERING.md`.

## Build & test

Two independent verification paths. **Both must pass.**

```bash
# 1. Engine harness — pure Swift, no simulator, ~10s.
swiftc -O -o /tmp/enginecheck Numeriqo/Engine/*.swift Tools/EngineCheck/*.swift
/tmp/enginecheck; echo "exit=$?"        # 9689 checks, 20472 differential comparisons

# 2. App + play layer.
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'

# 3. The Pro SKU. Its scheme runs ProBuildTests and nothing else.
xcodebuild test -project Numeriqo.xcodeproj -scheme "Numeriqo Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

**Always pin `OS=`.** This machine has 11 iOS runtimes installed and an unpinned
device name matches several of them.

Resolve a built `.app` with `-showBuildSettings`, never `find`: the legacy 2.x
project produces its own `Numeriqo.app` under the same bundle id, and
`find | head -1` has installed the wrong one before.

Difficulty recalibration: `NUMERIQO_CALIBRATE=1 /tmp/enginecheck` prints a
threshold table to paste into `DifficultyRater.thresholds`. Re-run it whenever
generation, the technique set, or the weights change — the numbers are
meaningless otherwise.

### Why two suites rather than one

The engine harness runs in seconds without a simulator, which is what made
16 techniques and 20k differential comparisons practical to iterate on. But it
compiles **without** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so it cannot
see the concurrency errors the app target sees. The first `xcodebuild` of a
fully green engine surfaced two real ones (a mutable static, and a
MainActor-isolated extension the nonisolated solver could not call). Keep both.

## Project

Single Xcode project, `objectVersion 77` with `PBXFileSystemSynchronizedRootGroup`
— **new Swift files under `Numeriqo/` and `NumeriqoTests/` are picked up
automatically; never edit `project.pbxproj` to add files.**

`Tools/` and `docs/` sit outside `Numeriqo/` deliberately: the synchronized group
would otherwise ship the CLI harness inside the app bundle. `Tools/EngineCheck/`
contains top-level code in `main.swift`, which cannot be in an app target at all.

Deployment target is **iOS 18.5**, matching the shipping Numeriqo. This is a 3.0
update; raising the floor would strand existing users.

## Actor isolation in `Design/`

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means **every unannotated type is
`@MainActor`** — including closures it hands to UIKit.

- `Theme` and `Motion` are **`nonisolated`**, and that is load-bearing.
  `UIColor.init(dynamicProvider:)` is imported without `NS_SWIFT_SENDABLE`, so a
  closure literal passed to it inherits MainActor isolation and Swift 6 emits an
  executor assertion in its prologue. UIKit resolves dynamic colours on
  `com.apple.SwiftUI.AsyncRenderer`, so that assertion trips and the app traps.
  It shipped this way in Just Kakuro and crashed **intermittently, anywhere,
  including an idle Home screen**, because whether a resolve lands off-main is a
  race.
- `ThemeRGBA` holds plain components rather than a `UIColor`, so the provider
  closure captures only `Sendable` values.
- `Haptics` is `@MainActor` and must stay so (`UIFeedbackGenerator` is
  `NS_SWIFT_UI_ACTOR`, and `enabled` is mutable global state).
- Guarded three ways by `ThemeIsolationTests`: a compile-time guard (a
  `nonisolated` helper that fails the *build* if the annotation is lost), a
  runtime guard resolving every token off-main, and a source scan that fails if
  a dynamic provider appears outside `Theme.swift`.

Engine extensions need `nonisolated` too. `extension Puzzle` in `BoardState.swift`
is explicitly `nonisolated` because `LogicalSolver` is nonisolated and otherwise
cannot call it.

## SwiftUI type-checker budget

Three separate views failed to compile with *"unable to type-check this
expression in reasonable time"* before anything was ever run: `CageOutline`'s
corner-inset arithmetic, `BoardView`'s cell placement, and `CellView.body`. All
three are split into small `@ViewBuilder` pieces or intermediate `let`s with
explicit types, and say so in a comment. Do not re-inline them.

## Board layout

**One absolutely-positioned layer.** `BoardGeometry` is the single source of
truth for cell rects; cells, hairlines, cage outlines, clue labels and the hint's
drawn argument all position against it. The legacy app mixed absolute cage
geometry with stack-laid cells and needed half-point fudges to reconcile them.

It is also what makes the drawn argument possible: connecting two cells with a
stroke needs their frames, and computing rects up front avoids any
`anchorPreference` plumbing. Kakuro has no such mechanism, which is why it
cannot draw between cells at all.

Cell size is floored to a whole point — fractional sizes seam at some scales and
not others, which reads as a rendering bug.

## `CageOutline`

Ported from the legacy `CageShape.swift`, whose half-edge boundary walk is good
work: directed lattice edges with the interior always on the right, chained into
loops with a right-turn preference at pinch points, collinear vertices dropped,
and a corner inset that is correct at **reflex** corners as well as convex ones.

Four things changed:

1. **The walk seeds from the lexicographically smallest lattice point**, not
   `Dictionary.first(where:)`. Dictionary order varies per launch, so the
   animated stroke used to begin at a random corner. The smallest point is the
   top-left of the anchor cell — exactly where the clue is drawn — so the reveal
   now always starts at the clue and travels around.
2. Pitch derives from `BoardGeometry` rather than a baked-in `cellSize + 1`.
3. An assertion catches multi-subpath (donut) cages, where `.trim` would draw
   the loops sequentially instead of as one stroke. Generated cages cap at four
   cells so it cannot arise, but it would be baffling to debug from the
   animation alone.
4. `animatableData` on cell size.

Pinned by `cageOutlineIsOneClosedContour` and `cageOutlineStartsDeterministically`.

## Play layer invariants

- **`apply` must materialise candidates before subtracting.** An elimination
  against a cell with no notes is a no-op, so Apply would look like it did
  nothing. `LogicalSolver.applyEliminations` handles this; reuse it.
- **Pad dimming uses only the Latin constraint**, never the solver. The legacy
  app dimmed via full propagation, and its own notes flag that as a route to
  leaking the unique solution.
- **`tap` does not toggle selection off.** Kakuro's does, and its notes record
  that a UI driver re-tapping a selected cell looks exactly like the app
  ignoring input.
- **Errors compare against the solution, not the rules.** A Calcudoku digit is
  often locally legal — breaking no Latin constraint and satisfying its cage —
  yet still wrong. Those are precisely the mistakes that let a player drift for
  twenty moves before anything visibly breaks. See `docs/TEACHING.md` §6.
- Eliminations strike **the specific candidate glyphs**, not a bar across the
  cell. "3 candidates ruled out" has to be visible as *which three*; the first
  version drew a centred bar that read as an underline.

## Teaching layer

- **The engine never holds a string.** `LogicalSolver` emits `ExplanationData`
  (cage indices, digits, combinations, an optional `Line`) and
  `TechniqueContent` is the only place those become English. Every
  context-dependent branch there degrades to `rule(for:)` rather than emitting a
  sentence with a hole in it.
- **The hint ladder discloses progressively.** `focusCells` is empty below
  `.highlight`, and `Hint.showsArgument` gates the drawn argument on the same
  threshold — naming the region is the whole point of the first two rungs.
- **A withheld hint must not call `recordHint`.** Penalising mastery for a hint
  the player never saw damages their progress path the moment they later pay.
- **`unaided` is the caller's to declare.** A digit placed by tapping Apply is
  indistinguishable from a reasoned one once it is on the board. `GameView`
  combines two guards: `!appliedHint && game.claimMasteryCredit(at:)`.
- **`creditedCells` survives undo, deliberately.** Place, undo, place again is
  identical to a fresh deduction from the board alone, so without it a technique
  could be farmed to Learned by tapping undo in a loop.
- **Mastery credits the hardest link in the chain**, ranked by
  `DifficultyRater.weight` rather than curriculum position — `nakedSingle` is
  taught late but trivial, so ranking by `rawValue` would credit it over the
  elimination work that earned the placement. This is also what lets
  elimination-only techniques be learned through play at all.
- **`fillAutoNotes` runs only techniques `<= .minMaxBounds`.** Auto-notes remove
  counting, not thinking; the full solver would hand over deductions unearned.

### Drill boards

Two techniques cannot be drilled from a live search, for different measured
reasons:

| Technique | Appearances in 1,200 boards | Handling |
|---|---|---|
| Odd & Even (parity) | **0** | Genuinely unreachable; recorded in `Technique.unreachableInGeneratedPuzzles` and pinned both ways by the engine harness. |
| Spill Over (outie) | **6 (0.5%)** | Findable but needs ~200 generations. Board found by an offline search once and frozen in `bakedBoards`. |

`PracticeDrills.bakedBoardsThatDemonstrateTheirTechnique` records which baked
boards actually exercise what they claim. **Parity's does not** — its board is
unique and curriculum-solvable, but the solver cracks it before a parity argument
is needed, which is the same reason parity is unsearchable. Constructing a board
that *forces* a parity deduction is real puzzle-design work and is outstanding.
It is surfaced in code rather than hidden behind a test exemption.

## Persistence

- **Legacy best times migrate, never reset.** 2.x wrote `NumeriqoBestTimes` and
  `NumeriqoBestTimesByDifficulty`; `ProgressStore.migrateLegacyBestTimes` folds
  both in once, maps the old three tiers onto the new five, and never overwrites
  a better 3.0 record. The old keys are read and left in place.
- **Save as the player works** — on board change, backgrounding, and disappear.
  Saving only on phase change loses everything, because a game started and never
  paused never changes phase.
- **`savedGame` is observable state, not a UserDefaults read.** A view body
  calling `defaults.object(forKey:)` never invalidates, so the Continue card
  would not appear until relaunch.
- **`ResumeGameView` resolves the snapshot once, on appear.** Reading
  `progress.savedGame` inline means winning — which clears the save —
  invalidates the destination and swaps the live game out mid-celebration.
- **`recordSolve` returns whether it was a record.** Re-deriving that by
  comparing against an already-updated store claims a record on an exact tie.

## Store

- `isOwned` returns `Bool?`. **`nil` means "couldn't determine" and must never
  downgrade** — the error path is what protects offline players.
- `NUMERIQO_PRO` is a permanent entitlement override, so existing Pro owners are
  never asked to pay twice. That build never talks to StoreKit for entitlement.

### The two SKUs are one target-level difference

`Numeriqo Pro` is a second native target listing the **same**
`fileSystemSynchronizedGroup` as the standard target, so there is no file
duplication and every `Sources` phase stays empty. Only five settings differ:

| | Numeriqo | Numeriqo Pro |
|---|---|---|
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | (project default) | `DEBUG NUMERIQO_PRO` / `NUMERIQO_PRO` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `de.kaikunze.numeriqo` | `de.kaikunze.numeriqopro` |
| `INFOPLIST_KEY_CFBundleDisplayName` | Numeriqo | Numeriqo Pro |
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon` | `AppIconPro` |
| StoreKit config in the scheme | yes | no (Pro never talks to StoreKit) |

Both icons come out of `Tools/AppIcon/make_pro_icon.py`, so the two SKUs are the
same drawing rather than two similar ones. Do not hand-edit the PNGs.

`theBuildFlagIsTheWholeProEntitlement` is written to hold in **both** builds
(`store.isUnlocked == EntitlementStore.isUnlockedByBuild`) rather than asserting
one answer, so it is a real check whichever scheme runs it.

`ProBuildTests` drives Pro through `XCUIApplication(bundleIdentifier:)`, because
the UI test target is hosted by the standard app. That is why it lives in the
Pro scheme's `TestAction` with the other UI classes skipped, and why the
standard scheme skips it: every assertion in it is deliberately false of the
free build. **A scheme-level `<SkippedTests>` beats `-only-testing` on the
command line**, so a skipped class cannot be run back by asking for it.
- Free tier is drawn to match what 2.x already gave away: 3x3-5x5, every
  difficulty, and **best times**. `FeatureGate` holds every decision as pure
  functions, asserted exactly by `PersistenceTests`.

## Accessibility

`NumeriqoUITests` runs `performAccessibilityAudit()` per screen — the same checks
Accessibility Inspector makes: contrast, hit targets, missing labels, Dynamic
Type scaling, clipped text. It found real defects on the first run and is worth
keeping green.

What it caught and what fixed it:

| Finding | Cause | Fix |
|---|---|---|
| 13 contrast failures on Learn | `.disabled()` dims a Button, pushing already-secondary text under threshold | Locked rows are no longer disabled. They stay readable and say what unlocks them, which teaches more than a grey row anyway. |
| Contrast warnings across list screens | The app replaced the grouped-list background with `Theme.paper` while keeping system-tuned header and footer colours on it | Let the system own its list chrome. |
| Contrast on secondary text | `inkSecondary` at 0.55 alpha | Raised to 0.78. |
| Dynamic Type unsupported, number pad | `Theme.digitFont(size: 24)` is a fixed size | `Theme.padDigitFont`, a semantic style. |
| Dynamic Type + clipping on Learn rows | Row subtitle was the full `rule(for:)` sentence, 80–140 characters | Added `TechniqueContent.summary(for:)`, a few words per row. |
| Hit area too small | Hint button and the banner's dismiss glyph | 44pt minimum targets. |
| "Text clipped" on the home tile labels | Inside a fixed-height tile a `.caption` gets a box exactly one line high, cropping the descender of "Progress" | `.fixedSize(horizontal: false, vertical: true)` plus `lineLimit(2)`. |

**UI tests must reset state.** The audits inherited whatever the previous test
left behind, so adding the "Start a new game?" warning meant every audit that
tapped Play got an alert instead of a board and three of them timed out. They
now launch with `-uiTestResetState`, which `NumeriqoApp` honours by clearing the
persistent domain before any store reads it. After a reset the home screen is
the *first-run* one, which has no Play button, so the audits enter a game via
"Skip, I know Calcudoku".

**Two audits are recorded as expected failures rather than filtered.**

- `testBoard` / `testHintBanner`: board digits are sized to their cell, so they
  cannot scale with Dynamic Type without overflowing the grid. An element-level
  filter was tried and does not work — `performAccessibilityAudit` reports most
  findings with a **nil `element`**, so there is nothing to match on. Widening
  the filter to "ignore all Dynamic Type" would hide real regressions.
- `testLearnMenu`: 34 findings on the technique rows, all with a **nil
  element**, split between "text may be clipped at larger Dynamic Type sizes"
  and "user will not be able to change the font size". Checked by screenshot at
  `AccessibilityXXXL`: the rows grow and wrap, nothing is truncated. The rows
  did genuinely clip until both labels got
  `.fixedSize(horizontal: false, vertical: true)`, which every other multi-line
  body in the app already had. What is left is the audit predicting clipping
  that does not happen.

**An `XCTExpectFailure` absorbs every failure in its test, not the one it
describes.** `testHomeScreen` carried an expectation about the stock segmented
picker and was quietly swallowing a real clipped-text bug in the home tile row;
splitting first-run and returning home into separate audits is what exposed it.
Keep one audit per state, and keep an expectation's scope as small as the thing
it excuses. When an expectation stops firing, delete it: it is strict by
default, so a test that starts passing for the right reason will tell you.

Elsewhere the app announces hint text and wins via
`AccessibilityNotification.Announcement`, and board cells expose a custom action
to move between cells of the same cage — cage membership is what the drawn
outline conveys and speech cannot.

## Feel

Haptics scale with rarity, and only the rarest event that just happened speaks:
a completed line silences the satisfied-cage tap, which silences the placement
tap. `Haptics.enabled` is applied both at launch and when the setting changes;
applying it only on change is how a setting ends up doing nothing.

**Sound is deliberately not implemented.** `docs/DESIGN.md` §6 specifies a
vocabulary including pitch-mapped placements. It is not built because it cannot
be evaluated here — the simulator's audio is not audible to the author of this
code, and shipping audio nobody has heard is worse than shipping none.

## Store and gating

- **No gated control is ever `.disabled()`.** A locked control presents the
  paywall. The Factors lesson shipped with a disabled "Drills come with the full
  game" button and no way to buy — the reported bug, and the same mistake the
  Learn menu had already been fixed for.
- **Restore lives in Settings, unconditionally.** It previously existed only
  inside the paywall sheet, which only opens when you hit a wall, so anyone who
  reinstalled had nowhere to restore from.
- A test walks every source file and asserts each `PaidFeature` has a
  `paywall.present(.case)` somewhere. `.practiceDrills` was advertised on the
  paywall and sold from nowhere.

## Difficulty is real

`PuzzleGenerator.generate(matching:size:seed:)` grades candidates and returns one
in the requested band, falling back to the nearest rather than refusing to start
a game.

Before it existed, `GameView` called plain `generate(size:seed:)`, threw away
`Result.grade`, and stapled the requested label onto whatever board came out — so
a Severe 5x5 was statistically identical to a Gentle one, and best times were
filed under a tier that meant nothing. The whole grading apparatus was built,
calibrated, and then not wired to the picker.

## Design tokens

`Design/Layout.swift` holds the radius scale (control / card / sheet), the 4pt
spacing scale, and the button vocabulary (`.primary`, `.secondary`, `.quiet`).
Before it there were five corner radii and fourteen distinct button treatments,
with primaries rendered in two different fills on screens that can be visible at
once. The board was precise and everything around it was improvised.

## The daily

`DailyPuzzle.today` counts **local calendar days**, not `timeIntervalSince1970 /
86_400`. UTC division rolled the day over at 01:00 in Germany and mid-afternoon
in the US, and streaks broke for reasons nobody could see.

## App icon

`Tools`-free: generated by a PIL script (kept in the repo history, regenerate as
needed) into `Assets.xcassets/AppIcon.appiconset` as light, dark and tinted
1024px PNGs.

The mark is the app's own cage outline, with the stroke starting in the accent
and turning to ink — what the hint's drawn argument does on the board. A stepped
cage rather than an L, because an L reads as a letterform at small sizes. Full
square, no baked corner rounding and no baked lighting: the system masks the
shape and, from iOS 26, owns the glass. Checked at 40pt before committing.

## Driving the simulator

**Resolve the app bundle from build settings, never from `find`.** The legacy
2.x project also builds a `Numeriqo.app` with the same bundle id, so
`find ... | head -1` installs whichever DerivedData directory sorts first. That
happened here: a screenshot showed the 2.x blue-gradient home screen and looked
like a catastrophic regression. Use:

```bash
APP=$(xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -showBuildSettings | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')/Numeriqo.app
```


Unit tests cannot reach view lifecycle, and both of Kakuro's persistence bugs
survived a green suite. To drive the app:

```bash
IDB=/Users/kai/work/areas/ios/kakuro/venv/bin/idb   # fb-idb; idb_companion is on PATH
$IDB connect <udid>
$IDB ui tap --udid <udid> <x> <y>     # coordinates are POINTS, not pixels
```

**Drive from a single Python process, not a shell loop.** Chained `idb ui tap`
calls in one Bash invocation drop taps; the same taps issued via `subprocess`
from one Python script land reliably.

**Check liveness separately** — `xcrun simctl spawn <udid> launchctl list | grep
-i numeriqo`. A dropped tap and a dead app look identical from the outside.

iPhone 16 Pro is 402×874 points at 3× scale, so screenshot pixel coordinates
divide by 3 to give tap points.

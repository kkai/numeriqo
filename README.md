# Numeriqo 3.0

A major update turning Numeriqo into a Calcudoku game that teaches you to
actually get good at it — Good Sudoku's teaching model, applied to a genre
nobody has done it for.

**Status:** engine, board, teaching, progression and store complete and verified
on device. Remaining: feel/accessibility polish (Phase 8) and ship (Phase 9).

| Suite | Result |
|---|---|
| Engine harness (`swiftc`, no simulator) | 9,689 checks, 20,472 differential comparisons |
| App, teaching, persistence, store (`xcodebuild test`) | 38 tests, 5 suites |
| Accessibility audits (`NumeriqoUITests`) | 6 screens, 4 clean, 2 recorded |

16 techniques, 85.6% curriculum solvability, generation 62ms median / 191ms
worst at 9x9. Every shipped puzzle is provably unique **and** provably
finishable by the curriculum.

## Documents

| Doc | What's in it |
|---|---|
| [`docs/PLAN.md`](docs/PLAN.md) | **Start here.** Thesis, shipping shape, 9-phase roadmap, risks. |
| [`docs/RULES.md`](docs/RULES.md) | Authoritative rules spec + the trademark constraint. |
| [`docs/TECHNIQUES.md`](docs/TECHNIQUES.md) | The technique ladder — the spine of the product. |
| [`docs/TEACHING.md`](docs/TEACHING.md) | Hint system, Academy, onboarding, input model. |
| [`docs/DESIGN.md`](docs/DESIGN.md) | Visual and motion direction. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Project shape, engine, generation, testing. |
| [`docs/MONETIZATION.md`](docs/MONETIZATION.md) | The one-time unlock, and the Pro-owner migration. |
| [`docs/ENGINEERING.md`](docs/ENGINEERING.md) | **Build/test commands, invariants, and mistakes already made once.** |

## The five things to remember

1. **Just Kakuro is the template.** `../kakuro/` already ships this exact
   product shape for a different puzzle. Read its `docs/ENGINEERING.md` before
   writing code — it records mistakes already paid for once, including a crash
   that shipped and two bugs that survived a green test suite.
2. **"KenKen" is a registered trademark**, and registration 3941027 covers
   mobile game software specifically. Never in store metadata, never in source
   identifiers. Ship as *Numeriqo*; use *Calcudoku*/*MathDoku* for ASO.
3. **Digits may repeat within a cage** — unlike Kakuro runs and Killer Sudoku —
   as long as they don't share a row or column. So cage *shape* decides:
   straight-line cages can't repeat, dog-legs can. Subtlest rule in the game,
   easiest to get silently wrong, and being wrong corrupts grading, hints and
   generation at once.
4. **The human-technique solver is the product.** Hints, difficulty tiers,
   lessons, and generation are five readings of one technique ordering. Build it
   before any UI.
5. **Existing Numeriqo Pro owners must never be asked to pay again.** The
   `NUMERIQO_PRO` flag becomes a permanent entitlement override; both SKUs ship
   3.0 together.

## Relationship to the shipping app

`../numeriqo/numeriqopro/` is today's Numeriqo. Worth reading; mostly not worth
porting now that Kakuro is the better template. Its `MathMazeSolver` bitmask
propagation and uniqueness backtracker are reusable. Its `DifficultyRater` is
not — it rates by *machine* effort (backtracking guess count), which cannot
express "this puzzle teaches parity," and therefore cannot drive a teaching
game. That gap is why the engine is a rewrite rather than a refactor.

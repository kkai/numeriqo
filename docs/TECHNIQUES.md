# The Technique Ladder

This ordered list is the **spine of the whole product**. As in Just Kakuro, the
`Technique` enum's **declaration order is the source of truth**, driving:

1. the solver loop,
2. difficulty grading,
3. hint escalation,
4. tutorial sequence,
5. the practice menu and the player's visible skill path.

One ordering, five consumers. **If the solver cannot name it, the game cannot
teach it.**

Notation: `N` = grid size, cells written `r3c4`. Bracketed ratings follow the
[billabob KenKen solver](https://billabob.github.io/kenkensolver/) scale, which
grades a puzzle by *the hardest technique required, no matter how many times it
is used* — the model this project adopts.

---

## Tier 0 — Freebies

### T1. Freebie cage `[0]`
A single-cell cage has no operator. The target is the digit.

Generation must **cap** these — excessive freebies trivialise a board. Hard
puzzles get zero.

---

## Tier 1 — Cage arithmetic

### T2. Combination enumeration `[0]` — the workhorse
List every legal multiset for a cage, then filter by the cage's geometry.

**Cage shape decides whether repeats are legal:**

- **Straight-line cage** (all cells in one row or column) → **no repeats**.
- **Dog-leg cage** (a bend — L, S, T, plus) → repeats legal between cells
  sharing neither row nor column.

> 6×6, three-cell `20×`:
> straight line → `1×4×5` only → `{1,4,5}`
> L-shaped → additionally `{2,2,5}`, the 2s in elbow positions

Taught as a lesson; never fires as a standalone hint.

### T3. Min/max bounds `[0]`
A `k`-cell `+` cage's target is bounded by the `k` smallest and `k` largest legal
digits.

> 6×6, three-cell `+` cage → target ∈ `[1+2+3, 4+5+6]` = `[6, 15]`.
> A `7+` three-cell straight-line cage has only one partition: `{1,2,4}`.

### T4. Divisibility and factor arguments `[0–1]`
A digit that doesn't divide a `×` target can't appear in the cage; prime
factorisation forces the rest.

> 6×6 `40×` on three cells: `40 = 2³·5`, and `3 ∤ 40`, `6 ∤ 40` → no 3, no 6.
> The only triple from `{1,2,4,5}` with product 40 is `{2,4,5}` — which also
> places the 6 in the remaining cell of that line.
>
> 6×6 `2÷` can never contain a **5** — no whole-number partner exists.

### T5. Two-cell `−` / `÷` pair sets `[0]`
Order-independent: `|a−b| = t` and `max/min = t`. In an `N×N` grid, `t−` has
exactly `N−t` pairs and `t÷` has exactly `⌊N/t⌋`.

6×6, worth hard-coding:

| Clue | Pairs | Count |
|---|---|---|
| `1−` | {1,2}{2,3}{3,4}{4,5}{5,6} | 5 |
| `3−` | {1,4}{2,5}{3,6} | 3 |
| `5−` | **{1,6}** | **1 — forced** |
| `2÷` | {1,2}{2,4}{3,6} | 3 |
| `4÷` | **{1,4}** | **1** |
| `6÷` | **{1,6}** | **1** |

The forced pairs (`5−`, `4÷`, `5÷`, `6÷`) are the most valuable clues on a
beginner board. Guarantee at least one entry point — a freebie or a forced
cage — on every Easy/Medium puzzle, or beginners stall at move zero.

---

## Tier 2 — Latin square basics

### T6. Naked single `[0]`
A cell whose candidates have collapsed to one digit.

### T7. Hidden single `[1]`
A digit that can legally occupy only one cell of a row or column.

### T8. Last cell in a line `[0]`
`N−1` cells known → the last is forced.

---

## Tier 3 — Subsets

### T9. Naked pair / triple / quad `[0–2.2]`
`k` cells in a line whose candidates union to exactly `k` digits → strip those
digits from the rest of the line.

**Calcudoku-specific:** naked pairs arise *free* from cage arithmetic far more
often than in Sudoku — any two-cell cage with a single legal combination is an
instant naked pair.

### T10. Hidden pair / triple / quad `[2–2.2]`
`k` digits confined to `k` cells → strip all other candidates from those cells.

---

## Tier 4 — Cage–line interaction

### T11. Pointing: cage → line `[1.2]`
Every valid combination of a cage places digit `d`, and all cells that could
hold it lie in one line → eliminate `d` from the rest of that line.

> A two-cell `11+` cage inside row C is `{5,6}` → no other cell in row C is 5 or 6.

### T12. Claiming: line → cage `[1.5]`
If digit `d` in a line can only occur inside one cage's cells, `d` must be in
that cage → kill every combination omitting it.

> A two-cell `14+` cage in a 9×9 admits `{5,9}` and `{6,8}`. If the line's only
> 6s sit in this cage, `{6,8}` is forced.

### T13. Locked candidate `[1.5]`
A digit known to occupy one of two specific cells — without knowing which — still
eliminates elsewhere.

---

## Tier 5 — Rule of N (the signature technique)

### T14. Rule of N — sum form `[3]`
Every row and column sums to `N(N+1)/2`. Cages wholly inside a line leave a
forced remainder.

| N | Row sum | Row product |
|---|---|---|
| 4 | 10 | 24 |
| 6 | **21** | **720** |
| 9 | 45 | 362,880 |

> 6×6 row D: `5+` and `8+` cages sit inside it, so `D3+D4 = 21 − 5 − 8 = 8` →
> `{2,6}` or `{3,5}`. Their cage is `12×`, and `12` isn't divisible by 5 →
> **`{2,6}`**. Cage completion then gives the third cell: `12 ÷ (2×6) = 1`.

That example chains Rule of N → enumeration → divisibility → completion in four
steps. **Build the flagship tutorial around it.**

### T15. Rule of 2N / 3N `[3.1]`
Two lines sum to `2N`, three to `3N`. Sum the cages wholly inside the band;
the remainder belongs to the leftover cells.

**Caveat:** a pseudo-cage assembled across two rows may legally repeat a digit.
Do not assume all-different for multi-line pseudo-cages.

### T16. Rule of n! — product form and divisors `[3.2–3.5]`
Every line has product `N!`. Rather than solving for the residual product, test
its **divisibility**: if the residual isn't divisible by `d`, then `d` appears
nowhere in the band's unknown cells.

> 6×6, rows A+B: `(720 × 720) ÷ (15 × 240) = 144`. `144` is not divisible by
> 5 → **eliminate every 5** from the unknown cells of rows A and B.

Fires most often on 5, which appears once per row and is easily used up.
Genuinely Calcudoku-native — Sudoku has no analogue.

---

## Tier 6 — Innies and outies

### T17. Innie `[3.x]`
Cages cover a line except one cell → that cell `= N − Σcages`.

### T18. Outie `[3.x]`
Cages cover a line and spill over by one cell → the spilled cell `= Σcages − N`.

> 6×6 row B: a `14+` cage (B1–B4) and a `12+` cage (B5, B6, **C6**) cover row B
> plus one extra. `C6 = (14 + 12) − 21 = 5`.

### T19. Pseudo-cages `[3.1]`
The same accounting across bands, producing virtual cages whose sum is known
though no printed cage matches.

---

## Tier 7 — Parity

### T20. Parity `[3.0]`
The technique that feels most like magic, and the strongest differentiator from
a generic Sudoku app.

Each line sums to a fixed parity, and contains exactly `⌈N/2⌉` odd digits (three
for 6×6). Cage parity is often derivable from the clue alone:

| Operator | Parity rule |
|---|---|
| `+` | cell-sum parity = target parity |
| `−` (2-cell) | cell-sum parity = target parity — because `a−b` and `a+b` always share parity. **The non-obvious, useful one.** |
| `×` | odd target ⇒ *every* cell odd |
| `÷` | determinable only in limited cases |

If every cage in a line has known parity except one, that one is forced.

> 6×6 row containing two `1−` cages and a `12×` cage. `1−` is odd, so each of
> those cell-sums is odd; two odds sum to even. The row totals **21, odd** → the
> `12×` cell-sum must be **odd**. `12×` admits `{2,6}` (sum 8, even) and `{3,4}`
> (sum 7, odd) → **`{3,4}` forced**, with no candidate scanning at all.

---

## Tier 8 — Fish

### T21. X-Wing `[2]` · T22. Swordfish `[2.1]` · T23. Jellyfish `[2.2]`
Standard fish. They read cleanly here because rows and columns are the *only*
constraint groups — no box complicates them. Rare below 7×7; implement for the
large grids.

---

## Tier 9 — Expert (implemented, never taught)

### T24. Forcing chains / AIC `[4.0–4.9]`
### T25. Cage-combination brute force `[6+]`

**Product decision: puzzles requiring T24 or T25 are rejected by the generator.**
A puzzle solvable only by guessing cannot be taught, and teaching is the product.
These exist in `BacktrackingSolver` purely to prove uniqueness — never as a hint
source. The player is never shown a hint they could not have reasoned to.

---

## Implementation status (2026-08-01)

**Sixteen techniques ship** in `Numeriqo/Engine/LogicalSolver.swift`, in this
curriculum order — which is also solver order, hint escalation order, and the
Academy's lesson order:

`freebieCage → divisibility → minMaxBounds → pairSets → cageCombination →
nakedSingle → hiddenSingle → lastCellInLine → nakedSubset → hiddenSubset →
pointingCage → claimingLine → ruleOfN → outie → parity → xWing`

Measured over 180 generated puzzles, sizes 4×4–9×9:

| Technique | Steps | Puzzles it tops out |
|---|---|---|
| Only Place (hidden single) | 3805 | 0 |
| Cage Combinations | 3248 | 0 |
| High & Low | 2499 | 0 |
| Last Candidate | 1929 | 0 |
| Difference & Quotient | 1355 | 0 |
| Factors | 1123 | 0 |
| Last Cell | 930 | 17 |
| Matching Sets | 768 | 8 |
| Hidden Sets | 640 | 41 |
| Cage Points (pointing) | 528 | **65** |
| Free Cells | 285 | 0 |
| Line Claims (claiming) | 73 | 17 |
| Rule of N | 20 | 3 |
| Spill Over (outie) | 3 | 1 |
| X-Wing | 7 | 2 |
| **Odd & Even (parity)** | **0** | **0** |

**Curriculum solvability: 85.6%** of unique puzzles, up from 25–62% with the
core ten.

### Parity is unreachable, and that is the correct outcome

Parity fires zero times. By the point a line's odd/even slots are provably
exhausted, the subset and cage/line techniques have already resolved those
cells. Forcing it to fire would mean *withholding* a cheaper, clearer
explanation the player deserves first.

It is recorded in `Technique.unreachableInGeneratedPuzzles` and pinned by the
harness in both directions, so a change in detector precedence fails loudly.
Consequences, the same ones Kakuro documents for its three:

- Its practice drill must be **hand-authored**; no search can find a board for it.
- It can never be credited through play, so mastery comes only from the drill.
- It will never appear on a post-solve technique recap.

Parity still earns its Academy lesson — it is genuinely Calcudoku-native and the
idea transfers to paper. It simply cannot be taught from generated boards.

### Reordering Factors was worth 28×

`divisibility` originally sat after `cageCombination` and fired 0.4% of the time:
full enumeration always reached the same eliminations first, because a
non-divisor is absent from every viable assignment. Moving it ahead took it from
160 to 4,445 steps in the equivalent sample.

The same reordering lifted `minMaxBounds` (2,247 → 10,360) and `pairSets`
(1,079 → 5,791). Running the simplest cage arguments before general enumeration
does not just rebalance statistics — it changes which *explanation the player is
shown* for the same deduction.

## Stage A measurements (superseded, kept for the argument)

Ten techniques are implemented (`Numeriqo/Engine/LogicalSolver.swift`). Measured
over 60 generated puzzles at 5×5–7×7:

| Technique | Share of steps | Puzzles it tops out |
|---|---|---|
| Cage Combinations | 31.0% | 0 |
| Only Place (hidden single) | 29.9% | 0 |
| Last Candidate (naked single) | 12.1% | 0 |
| Last Cell | 7.8% | 5 |
| High & Low (min/max) | 7.1% | 0 |
| Matching Sets (naked subset) | 4.1% | 4 |
| Hidden Sets (hidden subset) | 3.6% | **51** |
| Difference & Quotient | 2.4% | 0 |
| Free Cells | 1.6% | 0 |
| Factors (divisibility) | **0.4%** | 0 |

Three findings that shape Stage B:

**1. Every technique is reachable.** Unlike Kakuro, where 3 of 8 never appear in
a generated trace, all ten fire here. No Stage A technique needs a hand-authored
practice drill, and the negative "unsearchable" test Kakuro needs is unnecessary.

**2. The tier ceiling has collapsed.** 51 of 60 puzzles (85%) top out at Hidden
Sets, rising to ~96% at 7×7 and above. The *weighted score* still separates
puzzles cleanly — calibrated bands spread 16/18/25/21/18% at 9×9 — but
`hardestTechnique` cannot say what a puzzle teaches when almost every puzzle
teaches the same thing. **Stage B must add techniques above hidden subsets**, or
the Academy has nothing to target and the tier names are decoration.

**3. Factors is nearly redundant** at 0.4% of steps. Cage Combinations reaches
the same eliminations first — a non-divisor is absent from every viable
assignment, so T2 removes it before T4 is consulted. It survives because it is
a genuinely distinct *idea* worth teaching, but it needs a hand-authored drill
and should probably move earlier than T2 in the curriculum so it is not shadowed.

## Difficulty tiers

Graded by **hardest technique required**, tie-broken by firing count and by the
secondary signals in [`ARCHITECTURE.md`](ARCHITECTURE.md) §4.

| Tier | Name | Requires up to | Grids |
|------|------|---------------|-------|
| 1 | Gentle | T8 | 3×3 – 5×5 |
| 2 | Steady | T13 | 4×4 – 6×6 |
| 3 | Sharp | T16 | 5×5 – 7×7 |
| 4 | Deep | T20 | 6×6 – 9×9 |
| 5 | Severe | T23, many firings, zero freebies | 7×7 – 9×9 |

This is **technique-based** grading. The legacy Numeriqo rated by *machine*
effort — backtracking guess count and search depth
(`numeriqo/numeriqopro/Numeriqo/Difficulty.swift`). That metric cannot say "this
puzzle teaches parity," so it can drive neither an Academy nor a hint system.
**That gap is why the engine is a rewrite.**

## The `Technique` contract

```swift
nonisolated protocol TechniqueRule {
    static var id: Technique { get }
    static func find(in board: BoardState) -> Deduction?
}

nonisolated struct Deduction {
    let technique: Technique
    let placements: [Placement]
    let eliminations: [Elimination]
    let witness: [Cell]          // the cells the player must look at
    let focus: Region?           // line or cage to spotlight
    let explanation: LocalizedStringResource
}
```

`witness` and `focus` exist so the UI can **draw the argument**. That is what
separates this from a solver bolted onto a game.

## Two implementation warnings

**Apply the lowest-tier applicable technique, never the first found.** Otherwise
grading inflates — a puzzle rates "Deep" because an X-Wing happened to exist
alongside an available naked single that any human would have taken.

**Some techniques will never appear in a generated trace.** Kakuro found three
of its eight unreachable at any size or difficulty, because a cheaper detector
always fires first at those positions. Expect the same here for T1–T5, which
naked singles will usually pre-empt. Their drills need **hand-authored boards**,
and a test must pin the premise so that if detector precedence changes, it fails
and says so.

# Teaching Design

Adapted from Good Sudoku (Zach Gage / Jack Schlesinger), the reference for
"a puzzle app that actually makes you better."

## What Good Sudoku actually does

Verified from its press kit and reviews:

- **AI-powered hints that read your board *and your notes*.** The solver runs
  continuously in the background, updating its path with each entry. When you
  ask for a hint it finds the next technique *you* are positioned to use.
- **It explains the technique, not the answer.** Reviewers repeatedly single
  this out: rather than "put a 4 here", it names the pattern and shows the
  logic, so the skill transfers to any sudoku anywhere.
- **An "Improve" section** — a standalone library where techniques can be
  practised individually, outside of puzzles, with tracking of which you've learned.
- **Five difficulty levels, each defined by the techniques it requires**
  (their tiers go up to XYZ Wings, Hidden Quadruples, Jellyfish, Swordfish).
- **Tools that remove busywork, not thinking** — auto-fill candidates, plus
  *Accent Notes* and *Cross-Out Notes* for marking candidates in/out by hand.
- **Number-first input.** Tapping a digit in the pad highlights every instance
  of it on the board. Tapping an empty cell shows only the digits legal there.
- Three modes (Good, Arcade, Eternal); three dailies escalating through the week
  with global leaderboards; 70,000+ pre-generated puzzles.
- Praised for sound design, music, and haptics as much as for the teaching.

Sources: [press kit](https://www.playgoodsudoku.com/presskit/),
[MacStories review](https://www.macstories.net/reviews/game-day-good-sudoku/),
[App Store](https://apps.apple.com/us/app/good-sudoku-by-zach-gage/id1489118195).

---

## 1. The rules introduction — guided, never a text wall

Fifteen steps on one 3×3, in `Teaching/TutorialScript.swift`. The script is
pure data; `TutorialEngine` runs it and owns the board.

**What the first attempt got wrong.** It was five pages, and only one asked the
player to do anything — and that one accepted any digit in any cell. So it
stated the rules in prose and then left a beginner to solve a Calcudoku alone.
A rules statement is not a lesson. It also had a latent trap: the 3×3 was
trivially completable while poking around, and a solved game sets
`phase == .won`, after which `NumeriqoGame` silently swallows every tap —
including on the later pages that asked the player to touch the board.

**What replaced it.** Five digits are placed *for reasons the player is given
first*, one idea per step, and only then are the last four cells handed over:

1. The grid, and that every cell takes a 1, a 2 or a 3.
2. The single-cell cage: no operator, so the corner number is the answer.
3. **Place it.**
4. No repeats in a row or a column, framed as what that digit just used up.
5. There are no boxes — the error carried over from Sudoku.
6. A `3+` pair can only be 1 and 2, because the pair sits in one row.
7. So the row's third cell is the 3.
8. **Place it.**
9. That 3 sits in a `2−` cage, and `−` doesn't care which way round it reads.
10. **Place the 1.**
11. `4+` down a column is 1 and 3, since 2+2 would repeat.
12–13. **Place both.**
14. `solveFreely` for the last four cells.
15. Celebrate, and point at Learn.

Every required placement is genuinely forced by what has already been taught;
the chain was checked against `LogicalSolver`, and a test asserts each required
digit matches the solution.

### Two rules the shape depends on

- **The engine filters input, the view never touches `game`.** The lock is
  architectural, not a flag someone has to remember to check. Rejections are
  never silent: an error haptic, a shake, and a sentence saying what to do.
- **`solveFreely` is the last interactive step**, so completing the board and
  finishing the script are the same moment. Anything interactive after the win
  would be dead — that is the `.won` trap above.

Notes are hidden for the whole tutorial rather than merely kept switched off:
a board left in notes mode cannot be completed, and a beginner has no way to
work out why.

## 2. The Academy — the "Improve" analogue

A library, one entry per technique in `TECHNIQUES.md`, in ladder order.

Each entry has three parts:

1. **The idea** — two sentences, plain language, no jargon before it's earned.
2. **The worked example** — a mini-grid that animates the argument step by
   step: the witness cells light in sequence, the connecting logic is *drawn*
   as a stroke, then the conclusion lands. Scrubbable; replayable.
3. **Three practice positions** — hand-authored boards where that technique is
   *exactly* the next move. Not a full puzzle. The player finds it themselves.
   Getting all three marks the technique **Learned**.

Entries unlock as the solver observes the player encountering them in real
puzzles, so the library grows with the player rather than presenting 16 locked
doors on day one.

**Naming.** Avoid "Dojo" — the puzzle's Japanese origin makes it tempting and
exactly for that reason it reads as costume. Prefer plain: **Techniques**, or
**Improve**. Decide during Phase 5.

## 3. The hint system — four escalating levels

The signature feature. Hints are computed from the player's **actual board plus
their actual notes**, so the hint is always something reachable from where they
stand. Each level is a separate tap; the player takes only as much as they need.

| Level | Name | Shows |
|-------|------|-------|
| 1 | **Nudge** | The region only. "There's something to find in column 4." No technique named. |
| 2 | **Name it** | "This is a Hidden Single." Technique named, region still highlighted, cells not yet marked. |
| 3 | **Show the argument** | Witness cells spotlight in sequence, the logic is drawn between them, explanation text appears. The player still places the digit. |
| 4 | **Do it** | The placement or elimination is performed, animated. |

Rules:

- **Level 3 is the destination.** The design should make 4 feel like a small
  surrender — available without shame, but not the default path.
- Every hint above level 1 links to its Academy entry.
- If the player's notes are wrong, the hint says so first — "one of your notes
  can't be right" — rather than proceeding on a false footing.
- The hint engine **never** uses T16 (bifurcation). If the only way forward were
  a guess, the puzzle would not have shipped.

## 4. Notes — remove busywork, never thinking

- **Auto-candidates**: fill all legal candidates, toggleable. Removes counting,
  which is bookkeeping, not reasoning.
- **Accent** a candidate (mark it as promising) and **cross out** a candidate
  (mark it as ruled out by hand) — the player's own reasoning, recorded. These
  are also the richest signal the hint engine has about what the player is
  thinking; use them.
- Notes update automatically on placement, with undo.

## 5. Input model

**Number-first**, following Good Sudoku:

- Tap a digit in the pad → every instance of that digit on the board highlights.
  This alone teaches scanning.
- Then tap cells to place it.
- Tapping an empty cell first → the pad dims the digits that are illegal there.
- Long-press or a mode toggle switches to note entry.

Cell-first is offered in Settings for players who prefer it, but number-first is
the default because it *teaches* — it makes the player think in digits and
regions rather than in cells.

## 6. Mistakes — think in feedback *latency*, not strictness

The sharpest published criticism of Good Sudoku is Christian Donlan's in
[Eurogamer](https://www.eurogamer.net/if-you-really-want-to-learn-from-good-sudoku-i-reckon-arcade-mode-is-the-way-to-go)
(Aug 2020), and it is worth taking seriously because it attacks the product's
central claim:

> "Good Sudoku seemed… well, it seemed to automate a little too much. How could
> I learn Sudoku from this game that seemed to be able to play Sudoku so well
> without me? And these handy helpers seemed to enforce their own bad habits —
> their own reliances — which made me feel that the lessons I learned in the app
> would not really come across to Sudoku on paper."

His resolution is that Arcade mode — which signals an error the instant you make
one — is the mode that actually teaches, because **immediate feedback is what
lets you attribute a mistake to a specific inference.** Good Sudoku's default
mode stays quiet until the board becomes unsolvable, by which point the error is
many moves back and unattributable.

So the setting is not a strictness dial, it is a **latency** dial:

| Setting | Error signal | Attribution |
|---|---|---|
| **Off** | none until the board is unsolvable | poor — the mistake is many moves back |
| **Immediate** (default) | the moment a digit is placed | best — you know exactly which inference was wrong |
| **Refuse** | the entry bounces and never lands | best, but removes the experience of being wrong |

**Immediate is the default**, including for new players. Note this inverts Good
Sudoku, whose default mode is the one Donlan says teaches least.

Still: **no lives, no hearts, no fail state.** The pedagogical content of Arcade
mode is the *instant signal*, not the punishment. Take the feedback latency and
leave the three hearts — a teacher does not confiscate the exercise book.

### The Calcudoku-specific problem this exposes

A wrong digit can be **locally legal**: it breaks no Latin constraint and no
cage arithmetic, yet it is not the digit in the unique solution. In Calcudoku
these are common — cages with several valid combinations produce them constantly
— and they are precisely the errors that let a player drift for twenty moves
before anything visibly breaks. Rule-checking alone will not catch them.

We know the unique solution, so we can. **`Immediate` compares against the
solution, not merely against the visible rules.** That is the highest-attribution
feedback available and it is only possible because generation proves uniqueness.

Present it as *"that isn't the digit that goes here"*, never as *"you broke a
rule"* — because no rule was broken, and saying so would teach something false.

### The transfer test

Donlan's real worry is that assists breed reliance that doesn't survive contact
with paper. That is the correct north-star check for every convenience feature
in this app:

- **Auto-candidates** removes counting. Counting is bookkeeping, not reasoning —
  safe.
- **Digit highlighting** removes scanning. Scanning *is* a skill on paper —
  keep it, but make sure the Academy teaches scanning explicitly so the app
  isn't the only place the player can do it.
- **Any feature that makes a deduction for the player** fails the test outright.

The stat that proves the app works is hints-taken-per-tier trending *down*.
Surface it (§7).

## 7. Progression and retention

- **Daily**: three puzzles, escalating in tier through the week
  (Mon = Gentle → Sun = Deep/Severe). Streak tracking.
- **Skill map**: the technique ladder rendered as the player's own progress —
  the honest answer to "am I getting better?" It is the same list as the
  Academy, the difficulty tiers, and the hint vocabulary. One spine, four views.
- **Stats**: hints taken per tier over time is the number that should go *down*.
  Surface it — it is the proof the app works.
- Avoid streak-loss anxiety patterns; a missed day dims, it does not shame.

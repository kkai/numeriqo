# Store copy

Drafts for App Store Connect. Paste as-is or edit, but keep the trademark rules
in `RULES.md` §6: **never** "KenKen" or "KenDoku" in the name, subtitle, keyword
field, description, screenshots or icon. *Calcudoku* and *MathDoku* are the safe
genre terms.

House style from `DESIGN.md` §8 applies here too: no em dashes, no curly quotes,
say *grid* for the thing you fill and *puzzle* for the instance.

---

## Numeriqo (free, with one in-app purchase)

**Name:** Numeriqo

**Subtitle** (30 max) — 26 characters:

```
Calcudoku, taught properly
```

**Keywords** (100 max, comma separated, no spaces after commas) — 99 characters:

```
calcudoku,mathdoku,math puzzle,logic puzzle,latin square,number game,brain,arithmetic,daily,teach
```

**Promotional text** (170 max):

```
Every puzzle is solvable by reasoning alone. When you get stuck, Numeriqo names the technique and draws the argument on the grid instead of filling in the answer.
```

**Description:**

```
Numeriqo is a Calcudoku puzzle: fill the grid so no row or column repeats a
digit, and every outlined cage hits its target using the operator in its corner.

Most number puzzles leave you to work out the technique yourself, or hand you
the answer when you are stuck. Numeriqo does neither.

TAUGHT, NOT ASSUMED

Sixteen techniques, introduced one at a time, from single-cell cages up to
X-Wing. Each lesson is a short explanation followed by a puzzle that needs the
technique you just read about. Your progress on each one is tracked, and counts
only the solves you managed unaided.

HINTS THAT EXPLAIN

Ask for a hint and Numeriqo tells you the region first. Ask again and it names
the technique. Ask again and it draws the reasoning on the grid, cell by cell.
Only the last step will place a digit for you, and taking it is a deliberate
act rather than the default.

NO GUESSING, EVER

Every puzzle has exactly one solution, and every puzzle is checked before you
see it to make sure the techniques in the app are enough to finish it. You will
never be asked to guess and backtrack.

WHAT YOU GET FREE

Grids from 3x3 to 5x5 at all five difficulties, the rules tutorial, the first
lessons, best times for every grid and difficulty, and a daily puzzle that is
the same board for everyone.

ONE PURCHASE UNLOCKS THE REST

Grids up to 9x9, the full technique curriculum, practice drills for each
technique, hints that teach, and your full progress. One purchase, no
subscription, no adverts, and nothing is collected about you.

Inspired by the Japanese arithmetic puzzles popularised by Tetsuya Miyamoto.
```

**What's New:**

```
Numeriqo 3.0 is a rebuild around teaching you the game.

Sixteen techniques with a lesson and a practice drill each. Hints that name the
technique and draw the reasoning on the grid rather than filling in the cell.
A daily puzzle. Grids up to 9x9. A new board that draws cages as ink instead of
tinting them, so colour is left to mean something.

Your best times from earlier versions carry over.
```

---

## Numeriqo Pro (paid, being removed from sale after this release)

Same build, permanently unlocked. Subtitle and keywords as above.

**What's New** — use this paragraph verbatim, it is the one in
`MONETIZATION.md` §3:

```
Numeriqo 3.0 is a complete rebuild around teaching you the game: a full
technique curriculum, hints that explain the reasoning instead of filling in
the answer, and practice drills. As a Pro owner you already have all of it.
Nothing to buy, now or later.
```

---

## App Review notes

Paste into the "Notes" field for **both** apps:

```
Numeriqo Pro (de.kaikunze.numeriqopro) deliberately shows no "Restore
Purchases" button. It is a paid-up-front app that sells no in-app purchases, so
there is nothing to restore. The free app (de.kaikunze.numeriqo) does offer
Restore, unconditionally, in Settings.

Both apps ship the same build. Pro is unlocked by a compile-time flag rather
than by a purchase, so existing Pro owners are never asked to pay again.

No account, no login, no network calls other than StoreKit. The app collects no
data, which matches the privacy manifest.
```

---

## Screenshots

Generated into `build/screenshots/` by `DesignShotTests`, at the two sizes App
Store Connect requires: iPhone 6.9" (1320x2868) and iPad 13" (2064x2752).

`PLAN.md` §5 asks these to lead with the drawn argument, which is the one thing
no competitor does. Suggested order:

1. `shot-03-hint` — the drawn argument on the board. Lead with this.
2. `shot-02-board` — a board mid-solve.
3. `shot-06-lesson` — a technique lesson.
4. `shot-05-learn` — the curriculum, showing the ladder.
5. `shot-12-finish` — a solved grid.

Add captions in the store, not baked into the images, and keep the trademark
out of them.

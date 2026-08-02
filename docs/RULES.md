# Calcudoku (KenKen-style) — Authoritative Rules Reference

This is the spec the engine and the in-game rules tutorial both derive from.
Where sources disagree, the **House Rule** line states what Numeriqo implements.

## 1. The grid

- Square grid of size `N × N`, `N ∈ 3…9`.
- Every cell holds exactly one digit from `1…N`.

## 2. Latin square constraint

- No digit appears more than once in any **row**.
- No digit appears more than once in any **column**.
- **There is no box/region constraint.** This is the single most common
  mistake players carry over from Sudoku. The rules tutorial must call it out
  explicitly.

## 3. Cages

- The grid is partitioned into **cages** (also "blocks"): sets of orthogonally
  connected cells. Every cell belongs to exactly one cage.
- Each cage displays a **target** and, unless it is a single cell, an
  **operator** — one of `+`, `−`, `×`, `÷`.
- The digits in the cage must combine, using that operator, to produce the target.

### 3.1 Digits may repeat inside a cage

> "Digits may be repeated within a cage, as long as they are not in the same
> row or column." — Wikipedia, *KenKen*

**This is the defining difference from Killer Sudoku**, where cage digits must
be distinct. It has a large consequence for the solver: cage combination
enumeration must generate **multisets**, not just sets, and then filter by the
Latin constraint on the cage's actual geometry. An L-shaped 3-cell cage
spanning two rows and two columns can legally contain `{2,2,3}`; a straight
3-in-a-row cage cannot.

**House Rule: repeats allowed.** Standard behaviour, and it makes cages
meaningfully harder to enumerate, which the technique ladder depends on.

### 3.2 Single-cell cages ("freebies")

- No operator. The target *is* the digit.
- These are the player's foothold. Their density is a primary difficulty knob.

### 3.3 Addition and multiplication

- Associative and commutative — any cage size.
- `+`: digits sum to the target.
- `×`: digits multiply to the target.

### 3.4 Subtraction and division

- Non-associative, so order would be ambiguous in cages of 3+ cells.
- **House Rule: `−` and `÷` are restricted to two-cell cages only**, matching
  Will Shortz's published convention.
- `−`: `|a − b| = target`. Order-independent.
- `÷`: `max(a,b) / min(a,b) = target`, and must divide evenly. Order-independent.

Consequence worth teaching: a `÷` cage is extremely constraining. In a 6×6, a
`3÷` cage is only `{1,3}` or `{2,6}`. A `2÷` cage is `{1,2}`, `{2,4}`, or `{3,6}`.

## 4. Win condition

The puzzle is solved when every cell is filled, the Latin constraint holds, and
every cage's arithmetic is satisfied. A well-formed puzzle has **exactly one**
solution — the generator must prove this.

## 5. History and philosophy

Invented in 2004 by **Tetsuya Miyamoto**, a Japanese mathematics teacher, as
"an instruction-free method of training the brain." He gave students puzzles
and deliberately withheld instruction, letting the structure do the teaching —
his stated approach is *the art of teaching without teaching*.

Brought to the West by Robert Fuhrer; debuted in *The Times* (London), March 2008.
The name derives from Japanese *ken* (賢), "cleverness."

**This philosophy is the product's north star and its central tension.** Miyamoto
withheld instruction. Good Sudoku *does* instruct — but only ever names the
technique the player is already staring at, never the answer. Numeriqo follows
Good Sudoku: the player always makes the final placement themselves.

## 6. Naming and trademark — a hard constraint

**"KenKen" is a live registered U.S. trademark**, owned by **KenKen Puzzle LLC**
(Bedford, NY), originally registered to Nextoy, LLC (Robert Fuhrer).

| Mark | Reg. No. | Classes | Status |
|---|---|---|---|
| KENKEN | **3941027** | **009**, 016, 041 | Registered, renewed 2020 |
| KENKEN | 5146563 | 041 | **Incontestable** (§15 accepted 2023) |
| KENDOKU | — | 016 | Held by KenKen Puzzle LLC |

**Reg. 3941027 is the one that matters here.** Its Class 009 recitation
expressly covers *"Downloadable games and puzzles via wireless devices;
Electronic game programs; Electronic game software for cellular telephones"* and
*"computer application software for mobile phones."* It names this exact product
category. Reg. 5146563 being incontestable forecloses most
descriptiveness challenges.

### They enforce

**December 2008:** Conceptis Puzzles publicly renamed its newly launched
"KenDoku" to **"CalcuDoku"** following a request from Nextoy. That rename is the
origin of the name "Calcudoku," which is why it is the safest generic available.

Third-party implementations use unencumbered genre names — **Calcudoku**
(strongest pedigree), **MathDoku**, **Newdoku**, **Rekendoku**. None returned a
registration. **"KenDoku" is trademarked — never use it.**

### Rules for this project

- **Never** use "KenKen" or "KenDoku" in the app name, subtitle, keyword field,
  screenshots, App Store description, marketing site, or icon.
- Ship under the existing owned brand: **Numeriqo**.
- Use **"Calcudoku"** and **"MathDoku"** as the ASO genre terms, plus
  descriptive phrases: "math logic puzzle", "number logic puzzle",
  "Latin square puzzle".
- Internal source identifiers must also avoid the mark — the legacy project's
  `KenKenGame.swift` / `KenKenGameView.swift` names are not carried forward.
  Use `PuzzleEngine`, `BoardView`, etc.
- Safe factual attribution, if desired in an About screen: "Inspired by the
  Japanese arithmetic puzzles popularised by Tetsuya Miyamoto." Do not imply
  affiliation or endorsement.
- The **rules and mechanics are not protected** — game rules aren't
  copyrightable and no relevant patent exists. Only the *name* (trademark) and
  *specific published grids* (copyright, © Gakken) are. Generating our own
  puzzles is entirely clear.

**Not legal advice.** Before shipping, have counsel run a clearance search
confirming "Calcudoku" and "MathDoku" remain unregistered in Class 9.

## Sources

- [KenKen — Wikipedia](https://en.wikipedia.org/wiki/KenKen)
- [KENKEN Trademark, Reg. No. 5146563 — Justia](https://trademarks.justia.com/871/07/kenken-87107903.html)
- [KENKEN PUZZLE LLC trademark portfolio — Justia](https://trademarks.justia.com/owners/kenken-puzzle-llc-3815902)
- [KenKen official site](https://www.kenkenpuzzle.com/)
